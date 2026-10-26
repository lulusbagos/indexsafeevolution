using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.DTOs;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Primitives;
using System.Text.Json;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api")]
    [Authorize]
    public class TransactionController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ImageUploadService _imageUploadService;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private readonly SyncMonitorService _monitor;

        public TransactionController(
            AppDbContext context,
            ImageUploadService imageUploadService,
            CompanyHierarchyService companyHierarchyService,
            SyncMonitorService monitor)
        {
            _context = context;
            _imageUploadService = imageUploadService;
            _companyHierarchyService = companyHierarchyService;
            _monitor = monitor;
        }

        private string GetCurrentNik() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0000";
        private string GetCurrentName() => User.Identity?.Name ?? User.FindFirst(ClaimTypes.Name)?.Value ?? "Pengguna Mobile";
        private string GetCurrentDepartment() => User.FindFirst("Department")?.Value ?? "GENERAL";
        private int GetCurrentCompanyId() => int.TryParse(User.FindFirst("CompanyId")?.Value, out var cid) ? cid : 1;

        private static string FormatGpsDetail(string? detilLokasi, double? lat, double? lng, double? accuracy)
        {
            var baseDetail = (detilLokasi ?? string.Empty).Trim();
            if (lat.HasValue && lng.HasValue)
            {
                var accText = accuracy.HasValue ? $" ±{accuracy.Value:F1}m" : "";
                var gpsTag = $"[GPS: {lat.Value.ToString("F6", CultureInfo.InvariantCulture)}, {lng.Value.ToString("F6", CultureInfo.InvariantCulture)}{accText}]";
                if (!baseDetail.Contains("[GPS:"))
                {
                    baseDetail = string.IsNullOrEmpty(baseDetail) ? gpsTag : $"{baseDetail} {gpsTag}";
                }
            }
            return baseDetail;
        }

        private async Task<(string AreaName, string LocationName)> ResolveAreaAndLocationAsync(string? areaStr, string? areaIdStr, string? locStr, string? locIdStr, int companyId)
        {
            var area = (areaStr ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(area) && int.TryParse(areaIdStr, out var aId) && aId > 0)
            {
                var foundArea = await _context.MasterAreas.AsNoTracking().FirstOrDefaultAsync(a => a.Id == aId);
                if (foundArea != null) area = foundArea.NamaArea;
            }
            if (string.IsNullOrEmpty(area)) area = "PIT AREA";

            var lokasi = (locStr ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(lokasi) && int.TryParse(locIdStr, out var lId) && lId > 0)
            {
                var foundLoc = await _context.Benchmarks.AsNoTracking().FirstOrDefaultAsync(b => b.Id == lId);
                if (foundLoc != null) lokasi = foundLoc.NamaBenchmark ?? "LOKASI KERJA";
            }
            if (string.IsNullOrEmpty(lokasi)) lokasi = "FRONT LOADING";

            return (area, lokasi);
        }

        private async Task<(string? PjaName, string? PjaNik, string? PjaDept)> ResolvePjaAsync(string? pjaStr, string? pjaNikStr, string? pjaIdStr, string? deptPjaStr)
        {
            var pja = pjaStr?.Trim();
            var nik = pjaNikStr?.Trim();
            var dept = deptPjaStr?.Trim();

            if (string.IsNullOrEmpty(nik) && int.TryParse(pjaIdStr, out var empId) && empId > 0)
            {
                var emp = await (from k in _context.Karyawans.AsNoTracking()
                                 join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                 join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                 from d in dg.DefaultIfEmpty()
                                 where k.IdKaryawan == empId
                                 select new { k.NoNik, p.NamaLengkap, Dept = d != null ? d.NamaDepartemen : "GENERAL" })
                                 .FirstOrDefaultAsync();

                if (emp != null)
                {
                    nik = emp.NoNik;
                    pja ??= emp.NamaLengkap;
                    dept ??= emp.Dept;
                }
            }

            return (pja, nik, dept);
        }

        /// <summary>
        /// POST /api/tran/{name}
        /// Offline-to-online transaction sync endpoint (Hazard, Inspection, P2H, Coaching, etc.)
        /// </summary>
        [HttpPost("tran/{name}")]
        public async Task<IActionResult> SubmitTransaction(string name)
        {
            var sw = Stopwatch.StartNew();
            var targetName = (name ?? string.Empty).ToLowerInvariant().Trim();
            var userNik = GetCurrentNik();
            var userName = GetCurrentName();
            var dept = GetCurrentDepartment();
            var companyId = GetCurrentCompanyId();

            IFormCollection form;
            if (Request.HasFormContentType)
            {
                form = await Request.ReadFormAsync();
            }
            else
            {
                var fields = new Dictionary<string, StringValues>(StringComparer.OrdinalIgnoreCase);
                using var reader = new StreamReader(Request.Body);
                var rawBody = await reader.ReadToEndAsync();
                if (!string.IsNullOrWhiteSpace(rawBody))
                {
                    try
                    {
                        var json = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(rawBody);
                        if (json != null)
                        {
                            foreach (var kvp in json)
                            {
                                var val = kvp.Value.ValueKind switch
                                {
                                    JsonValueKind.String => kvp.Value.GetString() ?? string.Empty,
                                    JsonValueKind.Null => string.Empty,
                                    _ => kvp.Value.GetRawText().Trim('"')
                                };
                                fields[kvp.Key] = new StringValues(val);
                            }
                        }
                    }
                    catch { }
                }
                form = new FormCollection(fields);
            }

            var clientUuid = form["client_uuid"].FirstOrDefault() ?? form["local_id"].FirstOrDefault() ?? form["code"].FirstOrDefault();

            try
            {
                // Parse date & time preserving the original offline inspection timestamp
                var tanggal = DateTime.TryParse(form["tanggal"].FirstOrDefault() ?? form["date"].FirstOrDefault(), out var tgl) 
                    ? tgl.Date 
                    : DateTime.Today;

                var waktuStr = form["waktu"].FirstOrDefault() ?? form["time"].FirstOrDefault() ?? DateTime.Now.ToString("HH:mm:ss");
                var waktu = TimeSpan.TryParse(waktuStr, out var ts) ? ts : DateTime.Now.TimeOfDay;

                // Parse GPS Coordinates
                double? lat = double.TryParse(form["latitude"].FirstOrDefault() ?? form["lat"].FirstOrDefault(), NumberStyles.Any, CultureInfo.InvariantCulture, out var pLat) ? pLat : null;
                double? lng = double.TryParse(form["longitude"].FirstOrDefault() ?? form["lng"].FirstOrDefault() ?? form["long"].FirstOrDefault(), NumberStyles.Any, CultureInfo.InvariantCulture, out var pLng) ? pLng : null;
                double? acc = double.TryParse(form["gps_accuracy"].FirstOrDefault() ?? form["accuracy"].FirstOrDefault(), NumberStyles.Any, CultureInfo.InvariantCulture, out var pAcc) ? pAcc : null;

                var (area, lokasi) = await ResolveAreaAndLocationAsync(
                    form["area"].FirstOrDefault(),
                    form["area_id"].FirstOrDefault(),
                    form["lokasi"].FirstOrDefault(),
                    form["location_id"].FirstOrDefault(),
                    companyId);

                var detilLokasiRaw = form["detil_lokasi"].FirstOrDefault() ?? form["location_detail"].FirstOrDefault();
                var detilLokasi = FormatGpsDetail(detilLokasiRaw, lat, lng, acc);

                // 1. HAZARD REPORT
                if (targetName == "hazard" || targetName == "hazard_report")
                {
                    var temuan = form["temuan"].FirstOrDefault() ?? form["remark"].FirstOrDefault() ?? form["description"].FirstOrDefault() ?? form["title"].FirstOrDefault() ?? "Temuan Hazard";
                    var kategori = form["kategori_bahaya"].FirstOrDefault() ?? form["category"].FirstOrDefault() ?? "Kondisi Tidak Aman";
                    var jenis = form["jenis_bahaya"].FirstOrDefault();
                    var jenisKetidaksesuaian = form["jenis_ketidaksesuaian"].FirstOrDefault();
                    var tingkatResiko = form["tingkat_resiko"].FirstOrDefault() ?? form["danger_level"].FirstOrDefault() ?? "Medium";
                    var perbaikan = form["perbaikan"].FirstOrDefault() ?? form["repair_remark"].FirstOrDefault();
                    var tindakanPerbaikan = form["tindakan_perbaikan"].FirstOrDefault();
                    var statusTemuan = form["status_temuan"].FirstOrDefault() ?? form["status"].FirstOrDefault() ?? "Open";

                    var (pja, nikPja, deptPja) = await ResolvePjaAsync(
                        form["pja"].FirstOrDefault(),
                        form["nik_pja"].FirstOrDefault(),
                        form["pja_id"].FirstOrDefault(),
                        form["departemen_pja"].FirstOrDefault());

                    // Check for duplicate / idempotency retry from mobile
                    var existingHazard = await _context.HazardReports
                        .FirstOrDefaultAsync(h => !h.IsDeleted && h.Nik == userNik && h.Tanggal == tanggal && h.Area == area && h.Lokasi == lokasi && h.Temuan == temuan);

                    if (existingHazard != null)
                    {
                        sw.Stop();
                        _monitor.RecordTransaction(new TransactionEvent
                        {
                            Type = "Hazard",
                            Source = "Idempotent Retry (Already Synced)",
                            ServerId = existingHazard.Id,
                            Code = $"HZ-{existingHazard.Id}",
                            Nik = userNik,
                            Nama = userName,
                            Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                            Area = area,
                            Lokasi = lokasi,
                            DetilLokasi = detilLokasi,
                            Latitude = lat,
                            Longitude = lng,
                            GpsAccuracy = acc,
                            HasPhoto = !string.IsNullOrEmpty(existingHazard.FotoTemuan),
                            PhotoUrl = existingHazard.FotoTemuan,
                            InspectionDate = tanggal,
                            DurationMs = sw.ElapsedMilliseconds,
                            Status = "Conflict Resolved",
                            Summary = $"Temuan duplikat dicegah: {temuan}"
                        });

                        return Ok(new
                        {
                            status = true,
                            data = new SyncResultDto
                            {
                                Id = existingHazard.Id,
                                Code = $"HZ-{existingHazard.Id}",
                                UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                            }
                        });
                    }

                    // Handle photo uploads
                    var imageFile = form.Files["image"] ?? form.Files["foto_temuan"] ?? form.Files["foto"];
                    var repairFile = form.Files["repair_image"] ?? form.Files["foto_perbaikan"];

                    string? fotoTemuanUrl = null;
                    if (imageFile != null)
                    {
                        fotoTemuanUrl = await _imageUploadService.UploadAndCompressImageAsync(imageFile, "hazard", "hz");
                    }

                    string? fotoPerbaikanUrl = null;
                    if (repairFile != null)
                    {
                        fotoPerbaikanUrl = await _imageUploadService.UploadAndCompressImageAsync(repairFile, "actionplan", "ap");
                    }

                    var hazard = new HazardReport
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nama = userName,
                        Nik = userNik,
                        Departemen = dept,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Temuan = temuan,
                        KategoriBahaya = kategori,
                        JenisBahaya = jenis,
                        JenisKetidaksesuaian = jenisKetidaksesuaian,
                        TingkatResiko = tingkatResiko,
                        Perbaikan = perbaikan,
                        TindakanPerbaikan = tindakanPerbaikan,
                        Pja = pja,
                        NikPja = nikPja,
                        DepartemenPja = deptPja,
                        StatusTemuan = statusTemuan,
                        FotoTemuan = fotoTemuanUrl,
                        PerusahaanId = companyId,
                        IsDeleted = false,
                        CreatedAt = DateTime.Now
                    };

                    _context.HazardReports.Add(hazard);
                    await _context.SaveChangesAsync();

                    // If status Open, auto-create ActionPlan matching MBS_SAP web flow
                    if (string.Equals(statusTemuan, "Open", StringComparison.OrdinalIgnoreCase))
                    {
                        var actionPlan = new ActionPlan
                        {
                            Tanggal = tanggal,
                            Waktu = waktu,
                            Nama = userName,
                            Nik = userNik,
                            Departemen = dept,
                            Area = area,
                            Lokasi = lokasi,
                            DetilLokasi = detilLokasi,
                            ItemSap = $"hazard:{hazard.Id}",
                            KategoriTemuan = kategori,
                            DetilTemuan = temuan,
                            Status = "Open",
                            Pja = pja,
                            NikPja = nikPja,
                            DepartemenPja = deptPja,
                            PerusahaanId = companyId,
                            FotoTemuan = fotoTemuanUrl,
                            CreatedAt = DateTime.Now,
                            IsDeleted = false
                        };
                        _context.ActionPlans.Add(actionPlan);
                        await _context.SaveChangesAsync();
                    }

                    // Route notification to assigned PJA
                    if (!string.IsNullOrWhiteSpace(nikPja))
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = nikPja.Trim(),
                            Title = "Penugasan Temuan Hazard",
                            Message = $"{userName} telah menetapkan Anda sebagai PJA untuk temuan hazard di {area} - {lokasi}.",
                            Url = $"/Hazard/Detail/{hazard.Id}",
                            NotifType = "hazard_new",
                            CreatedAt = DateTime.Now
                        });
                        await _context.SaveChangesAsync();
                    }

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "Hazard",
                        Source = "Offline Outbox Sync",
                        ServerId = hazard.Id,
                        Code = $"HZ-{hazard.Id}",
                        Nik = userNik,
                        Nama = userName,
                        Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Latitude = lat,
                        Longitude = lng,
                        GpsAccuracy = acc,
                        HasPhoto = !string.IsNullOrEmpty(fotoTemuanUrl),
                        PhotoUrl = fotoTemuanUrl,
                        InspectionDate = tanggal,
                        DurationMs = sw.ElapsedMilliseconds,
                        Status = "Success",
                        Summary = $"[{kategori}] {temuan}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = hazard.Id,
                            Code = $"HZ-{hazard.Id}",
                            UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    });
                }

                // 2. INSPECTION & SIMAMA
                if (targetName == "inspection" || targetName == "simama")
                {
                    if (targetName == "simama" && tanggal < DateTime.Today)
                    {
                        return BadRequest(new { status = false, message = "Tanggal SiMaMa tidak boleh backdate (kurang dari hari ini)." });
                    }

                    var defaultJenis = targetName == "simama" ? "Sidak Malam Management (SiMaMa)" : "Inspeksi K3 Lapangan";
                    var jenisInspeksi = form["jenis_inspeksi"].FirstOrDefault() ?? form["category"].FirstOrDefault() ?? form["title"].FirstOrDefault() ?? defaultJenis;
                    var catatan = form["catatan"].FirstOrDefault() ?? form["remark"].FirstOrDefault();

                    var (pja, nikPja, deptPja) = await ResolvePjaAsync(
                        form["pja"].FirstOrDefault(),
                        form["nik_pja"].FirstOrDefault(),
                        form["pja_id"].FirstOrDefault(),
                        form["departemen_pja"].FirstOrDefault());

                    var imageFile = form.Files["image"] ?? form.Files["foto"];
                    string? fotoUrl = null;
                    if (imageFile != null)
                    {
                        fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(imageFile, "inspection", "insp");
                    }

                    var inspection = new Inspection
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nama = userName,
                        Nik = userNik,
                        Departemen = dept,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        JenisInspeksi = jenisInspeksi,
                        Pja = pja,
                        NikPja = nikPja,
                        DepartemenPja = deptPja,
                        Catatan = catatan,
                        LampiranJson = fotoUrl,
                        PerusahaanId = companyId,
                        Q1_1 = int.TryParse(form["q1_1"], out var q11) ? q11 : 1,
                        Q1_2 = int.TryParse(form["q1_2"], out var q12) ? q12 : 1,
                        Q1_3 = int.TryParse(form["q1_3"], out var q13) ? q13 : 1,
                        Q2_1 = int.TryParse(form["q2_1"], out var q21) ? q21 : 1,
                        Q2_2 = int.TryParse(form["q2_2"], out var q22) ? q22 : 1,
                        Q2_3 = int.TryParse(form["q2_3"], out var q23) ? q23 : 1,
                        Q3_1 = int.TryParse(form["q3_1"], out var q31) ? q31 : 1,
                        Q3_2 = int.TryParse(form["q3_2"], out var q32) ? q32 : 1,
                        Q3_3 = int.TryParse(form["q3_3"], out var q33) ? q33 : 1,
                        Q4_1 = int.TryParse(form["q4_1"], out var q41) ? q41 : 1,
                        Q4_2 = int.TryParse(form["q4_2"], out var q42) ? q42 : 1,
                        Q4_3 = int.TryParse(form["q4_3"], out var q43) ? q43 : 1,
                        Q5_1 = int.TryParse(form["q5_1"], out var q51) ? q51 : 1,
                        Q5_2 = int.TryParse(form["q5_2"], out var q52) ? q52 : 1,
                        Q5_3 = int.TryParse(form["q5_3"], out var q53) ? q53 : 1,
                        IsDeleted = false,
                        CreatedAt = DateTime.Now
                    };

                    _context.Inspections.Add(inspection);
                    await _context.SaveChangesAsync();

                    // Route notification to assigned PJA
                    if (!string.IsNullOrWhiteSpace(nikPja))
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = nikPja.Trim(),
                            Title = "Penugasan PJA Temuan Inspeksi",
                            Message = $"{userName} telah menetapkan Anda sebagai PJA untuk temuan Inspeksi ({jenisInspeksi}) di {area} - {lokasi}.",
                            Url = $"/Inspection/Detail/{inspection.Id}",
                            NotifType = "inspection_assigned",
                            Category = "inspection",
                            SenderName = userName,
                            Priority = "urgent",
                            ActionText = "Lihat Inspeksi",
                            IsRead = false,
                            IsActioned = false,
                            CreatedAt = DateTime.Now
                        });
                        await _context.SaveChangesAsync();
                    }

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "Inspection",
                        Source = "Offline Outbox Sync",
                        ServerId = inspection.Id,
                        Code = $"INSP-{inspection.Id}",
                        Nik = userNik,
                        Nama = userName,
                        Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Latitude = lat,
                        Longitude = lng,
                        GpsAccuracy = acc,
                        HasPhoto = !string.IsNullOrEmpty(fotoUrl),
                        PhotoUrl = fotoUrl,
                        InspectionDate = tanggal,
                        DurationMs = sw.ElapsedMilliseconds,
                        Status = "Success",
                        Summary = $"[{jenisInspeksi}] Catatan: {catatan ?? "Pemeriksaan Selesai"}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = inspection.Id,
                            Code = $"INSP-{inspection.Id}",
                            UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    });
                }

                // 3. P2H ALAT / KENDARAAN
                if (targetName == "p2h")
                {
                    if (tanggal < DateTime.Today)
                    {
                        return BadRequest(new { status = false, message = "Tanggal P2H tidak boleh backdate (kurang dari hari ini)." });
                    }

                    var jenisKendaraan = form["jenis_kendaraan"].FirstOrDefault() ?? form["unit"].FirstOrDefault() ?? "LV";
                    var noLambung = form["no_lambung"].FirstOrDefault() ?? "LV-001";
                    var merek = form["merek"].FirstOrDefault() ?? form["brand"].FirstOrDefault() ?? "Toyota";
                    var kmStr = form["kilometer"].FirstOrDefault() ?? form["km"].FirstOrDefault() ?? form["hm"].FirstOrDefault() ?? "0";
                    double.TryParse(kmStr, NumberStyles.Any, CultureInfo.InvariantCulture, out var kmVal);
                    var simper = form["simper_kimper"].FirstOrDefault() ?? (form["simper"].FirstOrDefault() == "1" ? "YA" : "TIDAK");

                    noLambung = noLambung.Trim().ToUpper();

                    // Manage Vehicle Master
                    var existingVeh = await _context.P2hVehicles
                        .FirstOrDefaultAsync(v => v.NoLambung.ToLower() == noLambung.ToLower() && !v.IsDeleted);
                    if (existingVeh == null)
                    {
                        existingVeh = new P2hVehicle
                        {
                            NoLambung = noLambung,
                            JenisKendaraan = jenisKendaraan,
                            Merek = merek,
                            CreatedAt = DateTime.Now
                        };
                        _context.P2hVehicles.Add(existingVeh);
                        await _context.SaveChangesAsync();
                    }

                    var fotoSpeedo = form.Files["foto_speedometer"] ?? form.Files["image"];
                    string? fotoSpeedoUrl = null;
                    if (fotoSpeedo != null)
                    {
                        fotoSpeedoUrl = await _imageUploadService.UploadAndCompressImageAsync(fotoSpeedo, "p2h", "speedo");
                    }

                    var golAJson = form["gol_a_json"].FirstOrDefault();
                    var golBJson = form["gol_b_json"].FirstOrDefault();
                    var golCJson = form["gol_c_json"].FirstOrDefault();

                    // Upload defect photos if files are attached
                    golAJson = await ProcessSyncGroupPhotosAsync("golA", golAJson, form);
                    golBJson = await ProcessSyncGroupPhotosAsync("golB", golBJson, form);
                    golCJson = await ProcessSyncGroupPhotosAsync("golC", golCJson, form);

                    var p2h = new P2hReport
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nama = userName,
                        Nik = userNik,
                        JenisKendaraan = jenisKendaraan,
                        NoLambung = noLambung,
                        Merek = merek,
                        Kilometer = kmVal,
                        SimperKimper = simper,
                        FotoSpeedometer = fotoSpeedoUrl,
                        GolA_Json = golAJson,
                        GolB_Json = golBJson,
                        GolC_Json = golCJson,
                        IsDeleted = false,
                        CreatedAt = DateTime.Now
                    };

                    _context.P2hReports.Add(p2h);
                    await _context.SaveChangesAsync();

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "P2H",
                        Source = "Offline Outbox Sync",
                        ServerId = p2h.Id,
                        Code = $"P2H-{p2h.Id}",
                        Nik = userNik,
                        Nama = userName,
                        Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Latitude = lat,
                        Longitude = lng,
                        GpsAccuracy = acc,
                        HasPhoto = !string.IsNullOrEmpty(fotoSpeedoUrl),
                        PhotoUrl = fotoSpeedoUrl,
                        InspectionDate = tanggal,
                        DurationMs = sw.ElapsedMilliseconds,
                        Status = "Success",
                        Summary = $"[{noLambung}] {jenisKendaraan} - KM: {kmVal:N0}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = p2h.Id,
                            Code = $"P2H-{p2h.Id}",
                            UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    });
                }

                // 4. OBSERVATION
                if (targetName == "observation")
                {
                    var kegiatan = form["kegiatan_yang_diamati"].FirstOrDefault() ?? form["activity"].FirstOrDefault() ?? "Observasi Prosedur Kerja";
                    var deptDiamati = form["departemen_yang_diamati"].FirstOrDefault() ?? "OPERASI";
                    var perusahaanDiamati = form["perusahaan_yang_diamati"].FirstOrDefault();
                    var dokumenPendukung = form["dokumen_pendukung"].FirstOrDefault();
                    var perusahaanDiamatiId = int.TryParse(form["perusahaan_id"].FirstOrDefault(), out var observedCompanyId)
                        ? observedCompanyId
                        : companyId;
                    var resikoKritis = form["resiko_kritis"].FirstOrDefault();
                    var tingkatResiko = form["tingkat_resiko"].FirstOrDefault() ?? "Medium";
                    var perihal = form["perihal_yang_diamati"].FirstOrDefault() ?? form["subject"].FirstOrDefault() ?? "Kepatuhan SOP";
                    var hasil = form["hasil_observasi"].FirstOrDefault() ?? "Sesuai Prosedur";
                    var keterangan = form["keterangan"].FirstOrDefault() ?? form["remark"].FirstOrDefault();

                    var imageFile = form.Files["image"] ?? form.Files["foto"];
                    string? fotoUrl = null;
                    if (imageFile != null)
                    {
                        fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(imageFile, "observation", "obs");
                    }

                    var obs = new Observation
                    {
                        Date = tanggal,
                        Nama = userName,
                        Nik = userNik,
                        Departemen = dept,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        KegiatanYangDiamati = kegiatan,
                        DepartemenYangDiamati = deptDiamati,
                        ResikoKritis = resikoKritis,
                        TingkatResiko = tingkatResiko,
                        PerihalYangDiamati = perihal,
                        HasilObservasi = hasil,
                        Keterangan = keterangan,
                        FotoUrl = fotoUrl,
                        PerusahaanId = perusahaanDiamatiId,
                        PerusahaanYangDiamati = perusahaanDiamati,
                        DokumenPendukung = dokumenPendukung,
                        IsDeleted = false,
                        CreatedAt = DateTime.Now
                    };

                    _context.Observations.Add(obs);
                    await _context.SaveChangesAsync();

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "Observation",
                        Source = "Offline Outbox Sync",
                        ServerId = obs.Id,
                        Code = $"OBS-{obs.Id}",
                        Nik = userNik,
                        Nama = userName,
                        Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Latitude = lat,
                        Longitude = lng,
                        GpsAccuracy = acc,
                        HasPhoto = !string.IsNullOrEmpty(fotoUrl),
                        PhotoUrl = fotoUrl,
                        InspectionDate = tanggal,
                        DurationMs = sw.ElapsedMilliseconds,
                        Status = "Success",
                        Summary = $"[{kegiatan}] Hasil: {hasil}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = obs.Id,
                            Code = $"OBS-{obs.Id}",
                            UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    });
                }

                // 5. COACHING
                if (targetName == "coaching")
                {
                    var tema = form["tema"].FirstOrDefault() ?? form["purpose"].FirstOrDefault() ?? "Safety Coaching";
                    var feedback = form["feedback"].FirstOrDefault();
                    var komitmen = form["komitmen"].FirstOrDefault();

                    var imageFile = form.Files["image"] ?? form.Files["foto"];
                    string? fotoUrl = null;
                    if (imageFile != null)
                    {
                        fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(imageFile, "coaching", "coach");
                    }

                    var coaching = new Coaching
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nama = userName,
                        Nik = userNik,
                        Departemen = dept,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Tema = tema,
                        Feedback = feedback,
                        Komitmen = komitmen,
                        Foto = fotoUrl,
                        PerusahaanId = companyId,
                        IsDeleted = false,
                        CreatedAt = DateTime.Now
                    };

                    _context.Coachings.Add(coaching);
                    await _context.SaveChangesAsync();

                    var participantsJson = form["participants_json"].FirstOrDefault() ?? form["trainees_json"].FirstOrDefault() ?? form["details_json"].FirstOrDefault();
                    if (!string.IsNullOrEmpty(participantsJson))
                    {
                        try
                        {
                            using var doc = JsonDocument.Parse(participantsJson);
                            if (doc.RootElement.ValueKind == JsonValueKind.Array)
                            {
                                foreach (var elem in doc.RootElement.EnumerateArray())
                                {
                                    string pNik = string.Empty;
                                    string pNama = string.Empty;
                                    if (elem.ValueKind == JsonValueKind.Object)
                                    {
                                        if (elem.TryGetProperty("no_nik", out var p1) || elem.TryGetProperty("nik", out p1))
                                            pNik = p1.GetString() ?? string.Empty;
                                        if (elem.TryGetProperty("nama_lengkap", out var p2) || elem.TryGetProperty("nama", out p2) || elem.TryGetProperty("name", out p2))
                                            pNama = p2.GetString() ?? string.Empty;
                                    }
                                    else if (elem.ValueKind == JsonValueKind.String)
                                    {
                                        var str = elem.GetString() ?? string.Empty;
                                        var parts = str.Split('-', 2);
                                        pNik = parts[0].Trim();
                                        pNama = parts.Length > 1 ? parts[1].Trim() : pNik;
                                    }

                                    if (!string.IsNullOrWhiteSpace(pNik) || !string.IsNullOrWhiteSpace(pNama))
                                    {
                                        _context.CoachingParticipants.Add(new CoachingParticipant
                                        {
                                            CoachingId = coaching.Id,
                                            Nik = string.IsNullOrWhiteSpace(pNik) ? "NON-NIK" : pNik,
                                            Nama = string.IsNullOrWhiteSpace(pNama) ? pNik : pNama
                                        });
                                    }
                                }
                                await _context.SaveChangesAsync();
                            }
                        }
                        catch
                        {
                            // ignore malformed participants JSON
                        }
                    }

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "Coaching",
                        Source = "Offline Outbox Sync",
                        ServerId = coaching.Id,
                        Code = $"COACH-{coaching.Id}",
                        Nik = userNik,
                        Nama = userName,
                        Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Latitude = lat,
                        Longitude = lng,
                        GpsAccuracy = acc,
                        HasPhoto = !string.IsNullOrEmpty(fotoUrl),
                        PhotoUrl = fotoUrl,
                        InspectionDate = tanggal,
                        DurationMs = sw.ElapsedMilliseconds,
                        Status = "Success",
                        Summary = $"[{tema}] Feedback: {feedback}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = coaching.Id,
                            Code = $"COACH-{coaching.Id}",
                            UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    });
                }

                // 6. SAFETY TALK
                if (targetName == "safety" || targetName == "safety_talk")
                {
                    var judul = form["judul"].FirstOrDefault() ?? form["title"].FirstOrDefault() ?? "Safety Talk Rutin";
                    var keterangan = form["keterangan"].FirstOrDefault() ?? form["remark"].FirstOrDefault();

                    var fotoDiri = form.Files["foto_diri"] ?? form.Files["image"];
                    var fotoKegiatan = form.Files["foto_kegiatan"] ?? form.Files["repair_image"];

                    string? fotoDiriUrl = null;
                    if (fotoDiri != null)
                    {
                        fotoDiriUrl = await _imageUploadService.UploadAndCompressImageAsync(fotoDiri, "safetytalk", "std");
                    }

                    string? fotoKegiatanUrl = null;
                    if (fotoKegiatan != null)
                    {
                        fotoKegiatanUrl = await _imageUploadService.UploadAndCompressImageAsync(fotoKegiatan, "safetytalk", "stk");
                    }

                    var st = new SafetyTalk
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nama = userName,
                        Nik = userNik,
                        Departemen = dept,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Judul = judul,
                        Keterangan = keterangan,
                        FotoDiri = fotoDiriUrl,
                        FotoKegiatan = fotoKegiatanUrl,
                        PerusahaanId = companyId,
                        IsDeleted = false,
                        CreatedAt = DateTime.Now
                    };

                    _context.SafetyTalks.Add(st);
                    await _context.SaveChangesAsync();

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "SafetyTalk",
                        Source = "Offline Outbox Sync",
                        ServerId = st.Id,
                        Code = $"ST-{st.Id}",
                        Nik = userNik,
                        Nama = userName,
                        Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Latitude = lat,
                        Longitude = lng,
                        GpsAccuracy = acc,
                        HasPhoto = !string.IsNullOrEmpty(fotoDiriUrl) || !string.IsNullOrEmpty(fotoKegiatanUrl),
                        PhotoUrl = fotoKegiatanUrl ?? fotoDiriUrl,
                        InspectionDate = tanggal,
                        DurationMs = sw.ElapsedMilliseconds,
                        Status = "Success",
                        Summary = $"Judul: {judul}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = st.Id,
                            Code = $"ST-{st.Id}",
                            UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    });
                }

                // 7. P5M (Fit to Work & Kelayakan Kerja)
                if (targetName == "p5m")
                {
                    if (tanggal < DateTime.Today)
                    {
                        return BadRequest(new { status = false, message = "Tanggal P5M tidak boleh backdate (kurang dari hari ini)." });
                    }

                    var topik = form["topik"].FirstOrDefault() ?? form["topic_id"].FirstOrDefault() ?? "K3 Operasional";
                    var judul = form["judul"].FirstOrDefault() ?? form["title"].FirstOrDefault() ?? "P5M Awal Shift - Siap Bekerja";
                    var keterangan = form["keterangan"].FirstOrDefault() ?? form["remark"].FirstOrDefault();
                    var catatan = form["catatan"].FirstOrDefault() ?? keterangan;

                    var fotoKegiatan = form.Files["foto_kegiatan"] ?? form.Files["image"];
                    string? fotoKegiatanUrl = null;
                    if (fotoKegiatan != null)
                    {
                        fotoKegiatanUrl = await _imageUploadService.UploadAndCompressImageAsync(fotoKegiatan, "p5m", "p5m");
                    }

                    // Parse Fit to Work questions & answers if provided
                    var questionsJson = form["questions_json"].FirstOrDefault();
                    var answersJson = form["answers_json"].FirstOrDefault();
                    List<string>? questionsList = null;
                    List<string>? answersList = null;

                    if (!string.IsNullOrEmpty(questionsJson))
                    {
                        try { questionsList = JsonSerializer.Deserialize<List<string>>(questionsJson); } catch {}
                    }
                    if (!string.IsNullOrEmpty(answersJson))
                    {
                        try { answersList = JsonSerializer.Deserialize<List<string>>(answersJson); } catch {}
                    }

                    // Also check form indexed keys (e.g. questions[0], answers[0])
                    if (questionsList == null || questionsList.Count == 0)
                    {
                        var qKeys = form.Keys.Where(k => k.StartsWith("questions[", StringComparison.OrdinalIgnoreCase)).OrderBy(k => k).ToList();
                        if (qKeys.Count > 0)
                        {
                            questionsList = qKeys.Select(k => form[k].FirstOrDefault() ?? "").ToList();
                            var aKeys = form.Keys.Where(k => k.StartsWith("answers[", StringComparison.OrdinalIgnoreCase)).OrderBy(k => k).ToList();
                            answersList = aKeys.Select(k => form[k].FirstOrDefault() ?? "No").ToList();
                        }
                    }

                    int primaryId = 0;
                    bool hasUnfit = false;

                    if (questionsList != null && questionsList.Count > 0)
                    {
                        for (int i = 0; i < questionsList.Count; i++)
                        {
                            var q = questionsList[i];
                            var a = (answersList != null && i < answersList.Count) ? answersList[i] : "No";

                            if (a.Equals("No", StringComparison.OrdinalIgnoreCase) || a.Equals("Tidak", StringComparison.OrdinalIgnoreCase) || a == "0")
                            {
                                hasUnfit = true;
                            }

                            var p5mRecord = new P5m
                            {
                                FotoKegiatan = fotoKegiatanUrl,
                                Tanggal = tanggal,
                                Waktu = waktu,
                                Nama = userName,
                                Nik = userNik,
                                Departemen = dept,
                                Area = area,
                                Lokasi = lokasi,
                                DetilLokasi = detilLokasi,
                                Topik = topik,
                                Judul = judul,
                                Keterangan = keterangan,
                                ListPertanyaan = q,
                                Jawaban = a,
                                Catatan = catatan,
                                PerusahaanId = companyId,
                                IsDeleted = false,
                                CreatedAt = DateTime.Now
                            };

                            _context.P5ms.Add(p5mRecord);
                            await _context.SaveChangesAsync();
                            if (i == 0) primaryId = p5mRecord.Id;
                        }
                    }
                    else
                    {
                        var p5m = new P5m
                        {
                            Tanggal = tanggal,
                            Waktu = waktu,
                            Nama = userName,
                            Nik = userNik,
                            Departemen = dept,
                            Area = area,
                            Lokasi = lokasi,
                            DetilLokasi = detilLokasi,
                            Topik = topik,
                            Judul = judul,
                            Keterangan = keterangan,
                            FotoKegiatan = fotoKegiatanUrl,
                            ListPertanyaan = "Fit to Work",
                            Jawaban = "Yes",
                            Catatan = catatan,
                            PerusahaanId = companyId,
                            IsDeleted = false,
                            CreatedAt = DateTime.Now
                        };

                        _context.P5ms.Add(p5m);
                        await _context.SaveChangesAsync();
                        primaryId = p5m.Id;
                    }

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "P5M",
                        Source = "Offline Outbox Sync",
                        ServerId = primaryId,
                        Code = $"P5M-{primaryId}",
                        Nik = userNik,
                        Nama = userName,
                        Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Latitude = lat,
                        Longitude = lng,
                        GpsAccuracy = acc,
                        HasPhoto = !string.IsNullOrEmpty(fotoKegiatanUrl),
                        PhotoUrl = fotoKegiatanUrl,
                        InspectionDate = tanggal,
                        DurationMs = sw.ElapsedMilliseconds,
                        Status = "Success",
                        Summary = $"[{topik}] {judul} - {(hasUnfit ? "UNFIT" : "FIT TO WORK")}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = primaryId,
                            Code = $"P5M-{primaryId}",
                            UpdatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    });
                }

                return BadRequest(new { message = $"Tipe transaksi '{name}' tidak dikenal." });
            }
            catch (Exception ex)
            {
                sw.Stop();
                _monitor.RecordError(new ErrorEvent
                {
                    Module = "TransactionSync",
                    Endpoint = $"/api/tran/{name}",
                    ClientUuid = clientUuid,
                    UserNik = userNik,
                    ErrorMessage = ex.Message,
                    StackTrace = ex.StackTrace,
                    Severity = "ERROR",
                    PayloadSnippet = $"Area={form["area"]}, Lokasi={form["lokasi"]}, Lat={form["latitude"]}, Lng={form["longitude"]}",
                    SuggestedFix = "Pastikan format tanggal, lokasi, dan koneksi database SQL Server DB_SAP stabil."
                });

                return StatusCode(500, new
                {
                    message = "Gagal memproses sinkronisasi data transaksi.",
                    detail = ex.Message
                });
            }
        }

        /// <summary>
        /// GET /api/tran/{name}?limit=10000
        /// Downloads transactions scoped by user and company hierarchy.
        /// </summary>
        [HttpGet("tran/{name}")]
        public async Task<IActionResult> GetTransactions(string name, [FromQuery] int limit = 50)
        {
            var targetName = (name ?? string.Empty).ToLowerInvariant().Trim();
            var userNik = GetCurrentNik();
            var companyId = GetCurrentCompanyId();
            var allowedCompanyIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(companyId);

            if (targetName == "hazard")
            {
                var query = _context.HazardReports
                    .AsNoTracking()
                    .Where(h => !h.IsDeleted && (h.Nik == userNik || h.NikPja == userNik || (h.PerusahaanId.HasValue && allowedCompanyIds.Contains(h.PerusahaanId.Value))))
                    .OrderByDescending(h => h.CreatedAt)
                    .Take(limit);

                var list = await query.ToListAsync();

                var niks = list.SelectMany(h => new[] { h.Nik, h.NikPja })
                    .Where(n => !string.IsNullOrEmpty(n))
                    .Distinct()
                    .ToList();

                var empList = await (from k in _context.Karyawans.AsNoTracking()
                                    join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                    where niks.Contains(k.NoNik)
                                    select new { k.IdKaryawan, k.NoNik, p.NamaLengkap, k.StatusAktif })
                                    .ToListAsync();

                var empMap = empList
                    .Where(x => !string.IsNullOrEmpty(x.NoNik))
                    .GroupBy(x => x.NoNik)
                    .ToDictionary(g => g.Key, g => g.OrderByDescending(x => x.StatusAktif).First());

                var currentKaryawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == userNik);
                int currentEmpId = currentKaryawan?.IdKaryawan ?? 0;

                var mapped = list.Select(h =>
                {
                    int pjaId = (!string.IsNullOrEmpty(h.NikPja) && empMap.TryGetValue(h.NikPja, out var pInfo)) ? pInfo.IdKaryawan : (h.NikPja == userNik ? currentEmpId : 0);
                    int empId = (!string.IsNullOrEmpty(h.Nik) && empMap.TryGetValue(h.Nik, out var eInfo)) ? eInfo.IdKaryawan : (h.Nik == userNik ? currentEmpId : 0);
                    string pjaName = (!string.IsNullOrEmpty(h.NikPja) && empMap.TryGetValue(h.NikPja, out var pInfo2)) ? pInfo2.NamaLengkap : h.Pja ?? "";

                    int statusCode = 0;
                    if (string.Equals(h.StatusTemuan, "Closed", StringComparison.OrdinalIgnoreCase)) statusCode = 2;
                    else if (string.Equals(h.StatusTemuan, "In Progress", StringComparison.OrdinalIgnoreCase)) statusCode = 1;

                    return new
                    {
                        id = h.Id,
                        code = $"HZ-{h.Id}",
                        title = h.Temuan ?? "Laporan Bahaya",
                        area_id = (int?)null,
                        location_id = (int?)null,
                        location_detail = h.DetilLokasi ?? h.Lokasi ?? h.Area ?? "",
                        date = h.Tanggal.ToString("yyyy-MM-dd"),
                        time = $"{h.Waktu.Hours:D2}:{h.Waktu.Minutes:D2}",
                        hazard_id = (int?)null,
                        hazard_type_id = (int?)null,
                        hazard_subtype_id = (int?)null,
                        hazard_danger_id = (int?)null,
                        remark = h.Temuan,
                        image = h.FotoTemuan,
                        video = (string?)null,
                        status = statusCode,
                        repair = !string.IsNullOrEmpty(h.FotoPerbaikan) ? 1 : 0,
                        repair_remark = h.Perbaikan,
                        repair_image = h.FotoPerbaikan,
                        repair_video = (string?)null,
                        repair_date = (string?)null,
                        repair_time = (string?)null,
                        pja_id = pjaId,
                        company_id = h.PerusahaanId,
                        employee_id = empId,
                        ref_id = (int?)null,
                        sync_id = h.Id,
                        created_at = h.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss"),
                        updated_at = (string?)null,
                        deleted_at = (string?)null,

                        // SQLite join fields
                        area_name = h.Area ?? "-",
                        location_name = h.Lokasi ?? "-",
                        pja_name = pjaName,

                        // Web/DTO fields
                        nik = h.Nik,
                        nama = h.Nama,
                        nik_pja = h.NikPja,
                        pja = h.Pja,
                        area = h.Area,
                        lokasi = h.Lokasi,
                        tingkat_resiko = h.TingkatResiko ?? "Rendah",
                        kategori_bahaya = h.KategoriBahaya,
                        jenis_bahaya = h.JenisBahaya,
                        jenis_ketidaksesuaian = h.JenisKetidaksesuaian,
                        status_temuan = h.StatusTemuan,
                        foto_temuan = h.FotoTemuan,
                        foto_perbaikan = h.FotoPerbaikan
                    };
                }).ToList();

                return Ok(new { status = true, data = mapped });
            }

            if (targetName == "inspection" || targetName == "simama")
            {
                var query = _context.Inspections
                    .AsNoTracking()
                    .Where(i => !i.IsDeleted && (i.Nik == userNik || (i.PerusahaanId.HasValue && allowedCompanyIds.Contains(i.PerusahaanId.Value))));

                if (targetName == "simama")
                {
                    query = query.Where(i => i.JenisInspeksi.Contains("SIMAMA") || i.JenisInspeksi.Contains("Sidak") || i.JenisInspeksi.Contains("Malam"));
                }

                var list = await query.OrderByDescending(i => i.CreatedAt).Take(limit).ToListAsync();
                return Ok(new { status = true, data = list });
            }

            if (targetName == "action" || targetName == "action_plan")
            {
                var query = _context.ActionPlans
                    .AsNoTracking()
                    .Where(a => !a.IsDeleted && (a.Nik == userNik || a.NikPic == userNik || a.NikPja == userNik || (a.PerusahaanId.HasValue && allowedCompanyIds.Contains(a.PerusahaanId.Value))))
                    .OrderByDescending(a => a.CreatedAt)
                    .Take(limit);

                var list = await query.ToListAsync();
                return Ok(new { status = true, data = list });
            }

            if (targetName == "coaching")
            {
                var coachings = await _context.Coachings
                    .AsNoTracking()
                    .Include(c => c.Participants)
                    .Where(c => !c.IsDeleted && (c.Nik == userNik || _context.CoachingParticipants.Any(cp => cp.CoachingId == c.Id && cp.Nik == userNik) || (c.PerusahaanId.HasValue && allowedCompanyIds.Contains(c.PerusahaanId.Value))))
                    .OrderByDescending(c => c.CreatedAt)
                    .Take(limit)
                    .ToListAsync();

                var list = coachings.Select(c => new
                {
                    id = c.Id,
                    code = $"COACH-{c.Id}",
                    title = c.Tema ?? "Safety Coaching",
                    tema = c.Tema ?? "Safety Coaching",
                    purpose = c.Tema,
                    feedback = c.Feedback,
                    komitmen = c.Komitmen,
                    remark = c.Feedback,
                    date = c.Tanggal.ToString("yyyy-MM-dd"),
                    time = c.Waktu.ToString(@"hh\:mm"),
                    area = c.Area,
                    lokasi = c.Lokasi,
                    detil_lokasi = c.DetilLokasi,
                    location_detail = c.DetilLokasi,
                    area_name = c.Area ?? "-",
                    location_name = c.Lokasi ?? "-",
                    nik = c.Nik,
                    nama = c.Nama,
                    coach_name = c.Nama,
                    coach_nik = c.Nik,
                    foto = c.Foto,
                    image = c.Foto,
                    participants = c.Participants.Select(p => new
                    {
                        id = p.Id,
                        coaching_id = p.CoachingId,
                        no_nik = p.Nik,
                        nik = p.Nik,
                        nama_lengkap = p.Nama,
                        nama = p.Nama
                    }).ToList(),
                    created_at = c.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                }).ToList();

                return Ok(new { status = true, data = list });
            }

            if (targetName == "observation")
            {
                var list = await _context.Observations
                    .AsNoTracking()
                    .Where(o => !o.IsDeleted && (o.Nik == userNik || (o.PerusahaanId.HasValue && allowedCompanyIds.Contains(o.PerusahaanId.Value))))
                    .OrderByDescending(o => o.CreatedAt)
                    .Take(limit)
                    .ToListAsync();
                return Ok(new { status = true, data = list });
            }

            if (targetName == "safety" || targetName == "safety_talk")
            {
                var list = await _context.SafetyTalks
                    .AsNoTracking()
                    .Where(s => !s.IsDeleted && (s.Nik == userNik || (s.PerusahaanId.HasValue && allowedCompanyIds.Contains(s.PerusahaanId.Value))))
                    .OrderByDescending(s => s.CreatedAt)
                    .Take(limit)
                    .ToListAsync();
                return Ok(new { status = true, data = list });
            }

            if (targetName == "p5m")
            {
                var list = await _context.P5ms
                    .AsNoTracking()
                    .Where(p => !p.IsDeleted && (p.Nik == userNik || (p.PerusahaanId.HasValue && allowedCompanyIds.Contains(p.PerusahaanId.Value))))
                    .OrderByDescending(p => p.CreatedAt)
                    .Take(limit * 4)
                    .ToListAsync();

                // Group by session (Tanggal, Waktu, Nik, Judul) matching web P5M grouping
                var grouped = list
                    .GroupBy(p => new { p.Tanggal.Date, p.Waktu.Hours, p.Waktu.Minutes, p.Nik, p.Judul, p.Area, p.Lokasi })
                    .Select(g =>
                    {
                        var first = g.First();
                        var hasUnfit = g.Any(q => q.Jawaban != null && (q.Jawaban.Equals("No", StringComparison.OrdinalIgnoreCase) || q.Jawaban.Equals("Tidak", StringComparison.OrdinalIgnoreCase) || q.Jawaban == "0"));
                        return new
                        {
                            id = first.Id,
                            code = $"P5M-{first.Id}",
                            title = first.Judul ?? "P5M & Fit to Work",
                            date = first.Tanggal.ToString("yyyy-MM-dd"),
                            time = first.Waktu.ToString(@"hh\:mm"),
                            nik = first.Nik,
                            nama = first.Nama,
                            departemen = first.Departemen,
                            area = first.Area,
                            lokasi = first.Lokasi,
                            detil_lokasi = first.DetilLokasi,
                            area_name = first.Area ?? "-",
                            location_name = first.Lokasi ?? "-",
                            topik = first.Topik,
                            judul = first.Judul,
                            keterangan = first.Keterangan,
                            catatan = first.Catatan,
                            foto_kegiatan = first.FotoKegiatan,
                            image = first.FotoKegiatan,
                            is_fit = !hasUnfit,
                            fit_status = hasUnfit ? "UNFIT" : "FIT TO WORK",
                            checklist = g.Select(x => new { question = x.ListPertanyaan, answer = x.Jawaban }).ToList(),
                            created_at = first.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                        };
                    })
                    .Take(limit)
                    .ToList();

                return Ok(new { status = true, data = grouped });
            }

            if (targetName == "p2h")
            {
                var list = await _context.P2hReports
                    .AsNoTracking()
                    .Where(p => !p.IsDeleted && p.Nik == userNik)
                    .OrderByDescending(p => p.CreatedAt)
                    .Take(limit)
                    .ToListAsync();
                return Ok(new { status = true, data = list });
            }

            return Ok(new { status = true, data = new List<object>() });
        }

        [HttpDelete("tran/coaching/{id:int}")]
        public async Task<IActionResult> DeleteCoaching(int id)
        {
            var userNik = GetCurrentNik();
            var coaching = await _context.Coachings
                .FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted && (c.Nik == userNik || _context.CoachingParticipants.Any(cp => cp.CoachingId == c.Id && cp.Nik == userNik)));
            if (coaching == null)
                return NotFound(new { message = "Coaching tidak ditemukan atau bukan milik pengguna." });
            coaching.IsDeleted = true;
            await _context.SaveChangesAsync();
            return Ok(new { status = true });
        }

        [HttpDelete("tran/safety/{id:int}")]
        public async Task<IActionResult> DeleteSafety(int id)
        {
            var userNik = GetCurrentNik();
            var safety = await _context.SafetyTalks
                .FirstOrDefaultAsync(s => s.Id == id && !s.IsDeleted && s.Nik == userNik);
            if (safety == null)
                return NotFound(new { message = "Safety Talk tidak ditemukan atau bukan milik pengguna." });
            safety.IsDeleted = true;
            await _context.SaveChangesAsync();
            return Ok(new { status = true });
        }

        [HttpDelete("tran/observation/{id:int}")]
        public async Task<IActionResult> DeleteObservation(int id)
        {
            var observation = await _context.Observations
                .FirstOrDefaultAsync(o => o.Id == id && !o.IsDeleted && o.Nik == GetCurrentNik());
            if (observation == null)
                return NotFound(new { message = "Observasi tidak ditemukan atau bukan milik pengguna." });
            observation.IsDeleted = true;
            await _context.SaveChangesAsync();
            return Ok(new { status = true });
        }

        [HttpPut("tran/observation/{id:int}")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> UpdateObservation(int id, [FromForm] IFormCollection form)
        {
            var observation = await _context.Observations
                .FirstOrDefaultAsync(o => o.Id == id && !o.IsDeleted && o.Nik == GetCurrentNik());
            if (observation == null)
                return NotFound(new { message = "Observasi tidak ditemukan atau bukan milik pengguna." });

            string? Value(string key) => form[key].FirstOrDefault()?.Trim();
            observation.KegiatanYangDiamati = Value("kegiatan_yang_diamati") ?? observation.KegiatanYangDiamati;
            observation.Area = Value("area") ?? observation.Area;
            observation.Lokasi = Value("lokasi") ?? observation.Lokasi;
            observation.DetilLokasi = Value("detil_lokasi") ?? observation.DetilLokasi;
            observation.PerihalYangDiamati = Value("perihal_yang_diamati") ?? observation.PerihalYangDiamati;
            observation.HasilObservasi = Value("hasil_observasi") ?? observation.HasilObservasi;
            observation.Keterangan = Value("keterangan") ?? observation.Keterangan;
            observation.DepartemenYangDiamati = Value("departemen_yang_diamati") ?? observation.DepartemenYangDiamati;
            observation.DokumenPendukung = Value("dokumen_pendukung") ?? observation.DokumenPendukung;
            observation.ResikoKritis = Value("resiko_kritis") ?? observation.ResikoKritis;
            observation.TingkatResiko = Value("tingkat_resiko") ?? observation.TingkatResiko;
            observation.PerusahaanYangDiamati = Value("perusahaan_yang_diamati") ?? observation.PerusahaanYangDiamati;
            if (int.TryParse(Value("perusahaan_id"), out var companyId)) observation.PerusahaanId = companyId;
            if (DateTime.TryParse(Value("tanggal"), out var date)) observation.Date = date;
            var photo = form.Files["image"];
            if (photo != null)
                observation.FotoUrl = await _imageUploadService.UploadAndCompressImageAsync(photo, "observation", "obs");
            await _context.SaveChangesAsync();
            return Ok(new { status = true, data = new { id = observation.Id } });
        }

        /// <summary>
        /// POST /api/detail/{name}
        /// Detail checklist sync (for multi-step inspection questions or P2H items)
        /// </summary>
        [HttpPost("detail/{name}")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> SubmitDetail(string name, [FromForm] IFormCollection form)
        {
            var refIdStr = form["ref_id"].FirstOrDefault() ?? form["tran_id"].FirstOrDefault();
            int.TryParse(refIdStr, out var refId);

            if (name == "coaching" && refId > 0)
            {
                var nameVal = form["name"].FirstOrDefault() ?? string.Empty;
                var nikVal = form["no_nik"].FirstOrDefault() ?? form["nik"].FirstOrDefault() ?? string.Empty;
                if (string.IsNullOrEmpty(nikVal) && nameVal.Contains('-'))
                {
                    var spl = nameVal.Split('-', 2);
                    nikVal = spl[0].Trim();
                    nameVal = spl.Length > 1 ? spl[1].Trim() : nikVal;
                }
                if (!string.IsNullOrWhiteSpace(nikVal) || !string.IsNullOrWhiteSpace(nameVal))
                {
                    var exists = await _context.CoachingParticipants.AnyAsync(cp => cp.CoachingId == refId && (cp.Nik == nikVal || cp.Nama == nameVal));
                    if (!exists)
                    {
                        _context.CoachingParticipants.Add(new CoachingParticipant
                        {
                            CoachingId = refId,
                            Nik = string.IsNullOrWhiteSpace(nikVal) ? "NON-NIK" : nikVal,
                            Nama = string.IsNullOrWhiteSpace(nameVal) ? nikVal : nameVal
                        });
                        await _context.SaveChangesAsync();
                    }
                }
            }

            var photoFile = form.Files["image"] ?? form.Files["repair_image"];
            string? photoUrl = null;
            if (photoFile != null)
            {
                photoUrl = await _imageUploadService.UploadAndCompressImageAsync(photoFile, name, "detail");
            }

            return Ok(new
            {
                status = true,
                data = new
                {
                    id = refId > 0 ? refId : 1,
                    image_url = photoUrl
                }
            });
        }

        /// <summary>
        /// POST /api/action/{name}
        /// Updates an Action Plan (e.g. PIC uploads repair photo & description, PJA approves & closes)
        /// </summary>
        [HttpPost("action/{name}")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> UpdateActionPlan(string name, [FromForm] IFormCollection form)
        {
            var userNik = GetCurrentNik();
            var userName = GetCurrentName();

            var actionIdStr = form["id"].FirstOrDefault() ?? form["action_id"].FirstOrDefault();
            if (!int.TryParse(actionIdStr, out var actionId) || actionId <= 0)
            {
                return BadRequest(new { message = "ID Action Plan tidak valid." });
            }

            var plan = await _context.ActionPlans.FirstOrDefaultAsync(a => a.Id == actionId && !a.IsDeleted);
            if (plan == null)
            {
                return NotFound(new { message = "Action Plan tidak ditemukan." });
            }

            // Upload repair image if provided
            var repairFile = form.Files["repair_image"] ?? form.Files["action_image"] ?? form.Files["foto_perbaikan"];
            if (repairFile != null)
            {
                var repairUrl = await _imageUploadService.UploadAndCompressImageAsync(repairFile, "actionplan", "rep");
                if (!string.IsNullOrEmpty(repairUrl))
                {
                    plan.FotoPerbaikan = repairUrl;
                }
            }

            var perbaikan = form["perbaikan"].FirstOrDefault() ?? form["action"].FirstOrDefault();
            if (!string.IsNullOrEmpty(perbaikan))
            {
                plan.Perbaikan = perbaikan;
                plan.TanggalPerbaikan = DateTime.Today;
            }

            var rencanaPerbaikan = form["rencana_perbaikan"].FirstOrDefault() ?? form["plan"].FirstOrDefault();
            if (!string.IsNullOrEmpty(rencanaPerbaikan))
            {
                plan.RencanaPerbaikan = rencanaPerbaikan;
            }

            var status = form["status"].FirstOrDefault();
            if (!string.IsNullOrEmpty(status))
            {
                var normalizedStatus = status switch
                {
                    "2" => "Closed",
                    "1" => "In Progress",
                    "0" => "Open",
                    _ => status
                };
                plan.Status = normalizedStatus;

                // Sync status with parent Hazard report if linked
                if (plan.ItemSap != null && plan.ItemSap.StartsWith("hazard:"))
                {
                    var hIdStr = plan.ItemSap["hazard:".Length..];
                    if (int.TryParse(hIdStr, out var hId))
                    {
                        var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == hId);
                        if (hazard != null)
                        {
                            hazard.StatusTemuan = normalizedStatus;
                            if (!string.IsNullOrEmpty(plan.FotoPerbaikan))
                            {
                                hazard.FotoPerbaikan = plan.FotoPerbaikan;
                            }
                            if (!string.IsNullOrEmpty(plan.Perbaikan))
                            {
                                hazard.Perbaikan = plan.Perbaikan;
                                hazard.TindakanPerbaikan = plan.Perbaikan;
                            }
                        }
                    }
                }
            }

            // Sync PIC & Departemen PIC if provided
            var picForm = form["pic"].FirstOrDefault()?.Trim() ?? form["pic_perbaikan"].FirstOrDefault()?.Trim();
            if (!string.IsNullOrEmpty(picForm))
            {
                plan.Pic = picForm;
            }

            var deptPicForm = form["departemen_pic"].FirstOrDefault()?.Trim() ?? form["departemenPic"].FirstOrDefault()?.Trim() ?? form["dept_pic"].FirstOrDefault()?.Trim();
            if (!string.IsNullOrEmpty(deptPicForm))
            {
                plan.DepartemenPic = deptPicForm;
            }

            var picIdStr = form["pic_id"].FirstOrDefault();
            if (!string.IsNullOrEmpty(picIdStr) && int.TryParse(picIdStr, out var picIdInt) && picIdInt > 0)
            {
                var picKaryawan = await (from k in _context.Karyawans.AsNoTracking()
                                         join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                         join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                         from d in dg.DefaultIfEmpty()
                                         where k.IdKaryawan == picIdInt
                                         select new { k.NoNik, p.NamaLengkap, NamaDept = d != null ? d.NamaDepartemen : null }).FirstOrDefaultAsync();
                if (picKaryawan != null)
                {
                    plan.NikPic = picKaryawan.NoNik;
                    plan.Pic = picKaryawan.NamaLengkap;
                    if (string.IsNullOrEmpty(plan.DepartemenPic) && !string.IsNullOrEmpty(picKaryawan.NamaDept))
                    {
                        plan.DepartemenPic = picKaryawan.NamaDept;
                    }
                }
            }

            var nikPicForm = form["nik_pic"].FirstOrDefault()?.Trim() ?? form["nikPic"].FirstOrDefault()?.Trim();
            if (!string.IsNullOrEmpty(nikPicForm))
            {
                plan.NikPic = nikPicForm;
                var picInfo = await (from k in _context.Karyawans.AsNoTracking()
                                     join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                     join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                     from d in dg.DefaultIfEmpty()
                                     where k.NoNik != null && k.NoNik.Trim() == nikPicForm
                                     select new { p.NamaLengkap, NamaDept = d != null ? d.NamaDepartemen : null }).FirstOrDefaultAsync();
                if (picInfo != null)
                {
                    if (string.IsNullOrEmpty(plan.Pic))
                    {
                        plan.Pic = picInfo.NamaLengkap;
                    }
                    if (string.IsNullOrEmpty(plan.DepartemenPic) && !string.IsNullOrEmpty(picInfo.NamaDept))
                    {
                        plan.DepartemenPic = picInfo.NamaDept;
                    }
                }
            }

            // Notifikasi ke PIC yang ditunjuk
            if (!string.IsNullOrWhiteSpace(plan.NikPic) && plan.NikPic.Trim() != userNik.Trim())
            {
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = plan.NikPic.Trim(),
                    Title = "Penugasan PIC Tindak Lanjut (Action Plan)",
                    Message = $"Anda ditugaskan sebagai PIC untuk tindakan perbaikan di {plan.Lokasi ?? plan.Area} (AP-#{plan.Id}) oleh {userName}. Segera selesaikan dan laporkan bukti perbaikan.",
                    Url = $"/ActionPlan/Detail/{plan.Id}",
                    NotifType = "actionplan_assigned",
                    Category = "actionplan",
                    SenderName = userName,
                    Priority = "urgent",
                    ActionText = "Lapor Perbaikan",
                    IsRead = false,
                    IsActioned = false,
                    CreatedAt = DateTime.Now
                });
            }

            await _context.SaveChangesAsync();

            _monitor.RecordTransaction(new TransactionEvent
            {
                Type = "ActionPlan",
                Source = "Mobile Follow-Up",
                ServerId = plan.Id,
                Code = $"AP-{plan.Id}",
                Nik = userNik,
                Nama = userName,
                Perusahaan = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                Area = plan.Area ?? "PIT",
                Lokasi = plan.Lokasi ?? "FRONT",
                DetilLokasi = plan.DetilLokasi ?? "",
                HasPhoto = !string.IsNullOrEmpty(plan.FotoPerbaikan),
                PhotoUrl = plan.FotoPerbaikan,
                InspectionDate = DateTime.Today,
                Status = "Updated",
                Summary = $"Status: {plan.Status} | Tindakan: {plan.Perbaikan ?? "Update Tindak Lanjut"}"
            });

            return Ok(new
            {
                status = true,
                data = new
                {
                    id = plan.Id,
                    updated_at = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }

        /// <summary>
        /// GET /api/action/{name}
        /// Retrieves active action plans assigned to the user or their company
        /// </summary>
        [HttpGet("action/{name}")]
        public async Task<IActionResult> GetActionPlans(string name, [FromQuery] int limit = 100)
        {
            var userNik = GetCurrentNik();
            var companyId = GetCurrentCompanyId();
            var allowedCompanyIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(companyId);

            var targetName = (name ?? string.Empty).ToLowerInvariant().Trim();

            var query = _context.ActionPlans
                .AsNoTracking()
                .Where(a => !a.IsDeleted && (a.Nik == userNik || a.NikPic == userNik || a.NikPja == userNik));

            if (targetName == "hazard")
            {
                query = query.Where(a => a.ItemSap == null || a.ItemSap == "hazard" || a.ItemSap.StartsWith("hazard:"));
            }
            else if (!string.IsNullOrEmpty(targetName) && targetName != "all")
            {
                query = query.Where(a => a.ItemSap != null && a.ItemSap.ToLower().StartsWith(targetName));
            }

            var plans = await query
                .OrderByDescending(a => a.CreatedAt)
                .Take(limit)
                .ToListAsync();

            var niks = plans.SelectMany(p => new[] { p.Nik, p.NikPja, p.NikPic })
                .Where(n => !string.IsNullOrEmpty(n))
                .Distinct()
                .ToList();

            var empList = await (from k in _context.Karyawans.AsNoTracking()
                                join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                where niks.Contains(k.NoNik)
                                select new { k.IdKaryawan, k.NoNik, p.NamaLengkap, k.StatusAktif })
                                .ToListAsync();

            var empMap = empList
                .Where(x => !string.IsNullOrEmpty(x.NoNik))
                .GroupBy(x => x.NoNik)
                .ToDictionary(g => g.Key, g => g.OrderByDescending(x => x.StatusAktif).First());

            var currentKaryawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik != null && k.NoNik.Trim() == userNik.Trim());
            int currentEmpId = currentKaryawan?.IdKaryawan ?? 0;

            var mappedData = plans.Select(a =>
            {
                int pjaId = (!string.IsNullOrEmpty(a.NikPja) && empMap.TryGetValue(a.NikPja.Trim(), out var pInfo)) ? pInfo.IdKaryawan : (string.Equals(a.NikPja?.Trim(), userNik.Trim(), StringComparison.OrdinalIgnoreCase) ? (currentEmpId > 0 ? currentEmpId : 1) : 0);
                int picId = (!string.IsNullOrEmpty(a.NikPic) && empMap.TryGetValue(a.NikPic.Trim(), out var cInfo)) ? cInfo.IdKaryawan : (string.Equals(a.NikPic?.Trim(), userNik.Trim(), StringComparison.OrdinalIgnoreCase) ? (currentEmpId > 0 ? currentEmpId : 1) : 0);
                int empId = (!string.IsNullOrEmpty(a.Nik) && empMap.TryGetValue(a.Nik.Trim(), out var eInfo)) ? eInfo.IdKaryawan : (string.Equals(a.Nik?.Trim(), userNik.Trim(), StringComparison.OrdinalIgnoreCase) ? (currentEmpId > 0 ? currentEmpId : 1) : 0);

                string pjaName = (!string.IsNullOrEmpty(a.NikPja) && empMap.TryGetValue(a.NikPja, out var pInfo2)) ? pInfo2.NamaLengkap : a.Pja ?? "";
                string picName = (!string.IsNullOrEmpty(a.NikPic) && empMap.TryGetValue(a.NikPic, out var cInfo2)) ? cInfo2.NamaLengkap : a.Pic ?? "";

                int statusCode = 0;
                if (string.Equals(a.Status, "Closed", StringComparison.OrdinalIgnoreCase) || a.Status == "2") statusCode = 2;
                else if (string.Equals(a.Status, "In Progress", StringComparison.OrdinalIgnoreCase) || a.Status == "1") statusCode = 1;
                else statusCode = 0;

                int tranId = 0;
                if (a.ItemSap != null && a.ItemSap.StartsWith("hazard:"))
                {
                    int.TryParse(a.ItemSap["hazard:".Length..], out tranId);
                }

                return new
                {
                    id = a.Id,
                    code = $"AP-{a.Id}",
                    title = a.DetilTemuan ?? a.KategoriTemuan ?? "Hazard Action",
                    area_id = (int?)null,
                    location_id = (int?)null,
                    location_detail = a.DetilLokasi ?? a.Lokasi ?? a.Area ?? "",
                    date = a.Tanggal.ToString("yyyy-MM-dd"),
                    time = $"{a.Waktu.Hours:D2}:{a.Waktu.Minutes:D2}",
                    remark = a.DetilTemuan ?? a.KategoriTemuan ?? "",
                    image = a.FotoTemuan,
                    video = (string?)null,
                    status = statusCode,
                    pja_id = pjaId,
                    pic_id = picId,
                    nik_pja = a.NikPja,
                    nik_pic = a.NikPic,
                    employee_id = empId,
                    plan = a.RencanaPerbaikan,
                    plan_date = a.TanggalRencanaPerbaikan?.ToString("yyyy-MM-dd"),
                    overdue = (int?)null,
                    reason = a.AlasanOverdue,
                    action = a.Perbaikan,
                    action_date = a.TanggalPerbaikan?.ToString("yyyy-MM-dd"),
                    action_image = a.FotoPerbaikan,
                    action_video = (string?)null,
                    table = "hazard",
                    category = "hazard",
                    tran_id = tranId,
                    detail_id = (int?)null,
                    company_id = a.PerusahaanId,
                    created_at = a.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss"),
                    updated_at = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                    deleted_at = (string?)null,

                    // UI labels for cards
                    area_name = a.Area ?? "-",
                    location_name = a.Lokasi ?? "-",
                    pja_name = pjaName,
                    pic_name = picName,

                    // Web DTO compatibility
                    nik = a.Nik,
                    nama = a.Nama,
                    nikPja = a.NikPja,
                    pja = a.Pja,
                    nikPic = a.NikPic,
                    pic = a.Pic,
                    statusName = a.Status,
                    fotoTemuan = a.FotoTemuan,
                    fotoPerbaikan = a.FotoPerbaikan,
                    area = a.Area,
                    lokasi = a.Lokasi,
                    detilTemuan = a.DetilTemuan
                };
            }).ToList();

            return Ok(new { status = true, data = mappedData });
        }

        /// <summary>
        /// POST /api/files
        /// Multipart file attachment upload
        /// </summary>
        [HttpPost("files")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> UploadAttachment([FromForm] IFormCollection form)
        {
            var file = form.Files["name"] ?? form.Files["file"] ?? form.Files.FirstOrDefault();
            if (file == null)
            {
                return BadRequest(new { message = "File tidak ditemukan." });
            }

            var category = form["category"].FirstOrDefault() ?? form["table"].FirstOrDefault() ?? "attachments";
            var url = await _imageUploadService.UploadAndCompressImageAsync(file, category, "att");

            return Ok(new
            {
                status = true,
                data = new
                {
                    id = new Random().Next(1000, 9999),
                    url = url
                }
            });
        }

        private async Task<string?> ProcessSyncGroupPhotosAsync(string groupKey, string? jsonInput, IFormCollection form)
        {
            if (string.IsNullOrEmpty(jsonInput)) return jsonInput;
            try
            {
                var list = JsonSerializer.Deserialize<List<P2hController.ChecklistItem>>(jsonInput, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (list == null) return jsonInput;

                for (int i = 0; i < list.Count; i++)
                {
                    var file = form.Files[$"{groupKey}_photo_{i}"] ?? form.Files[$"photo_{groupKey}_{i}"] ?? form.Files[$"{groupKey}_photo_{list[i].Id - 1}"];
                    if (file != null && file.Length > 0)
                    {
                        var url = await _imageUploadService.UploadAndCompressImageAsync(file, "p2h", $"{groupKey}_{i}");
                        if (url != null)
                        {
                            list[i].PhotoUrl = url;
                        }
                    }
                }
                return JsonSerializer.Serialize(list);
            }
            catch
            {
                return jsonInput;
            }
        }
        [HttpDelete("tran/{name}/{id:int}")]
        [HttpDelete("api/tran/{name}/{id:int}")]
        public async Task<IActionResult> DeleteTransaction(string name, int id)
        {
            var targetName = (name ?? string.Empty).ToLowerInvariant().Trim();
            if (targetName == "inspection" || targetName == "simama")
            {
                var item = await _context.Inspections.FindAsync(id);
                if (item != null)
                {
                    item.IsDeleted = true;
                    await _context.SaveChangesAsync();
                    return Ok(new { status = true, message = "Inspeksi berhasil dihapus" });
                }
            }
            else if (targetName == "hazard" || targetName == "hazard_report")
            {
                var item = await _context.HazardReports.FindAsync(id);
                if (item != null)
                {
                    item.IsDeleted = true;
                    await _context.SaveChangesAsync();
                    return Ok(new { status = true, message = "Hazard berhasil dihapus" });
                }
            }
            else if (targetName == "p2h")
            {
                var item = await _context.P2hReports.FindAsync(id);
                if (item != null)
                {
                    item.IsDeleted = true;
                    await _context.SaveChangesAsync();
                    return Ok(new { status = true, message = "P2H berhasil dihapus" });
                }
            }
            else if (targetName == "p5m")
            {
                var item = await _context.P5ms.FindAsync(id);
                if (item != null)
                {
                    item.IsDeleted = true;
                    await _context.SaveChangesAsync();
                    return Ok(new { status = true, message = "P5M berhasil dihapus" });
                }
            }
            return Ok(new { status = true, message = "Data berhasil dihapus" });
        }
    }
}
