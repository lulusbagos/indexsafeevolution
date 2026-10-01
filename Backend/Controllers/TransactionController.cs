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
                            RecipientNik = nikPja,
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

                // 2. INSPECTION
                if (targetName == "inspection")
                {
                    var jenisInspeksi = form["jenis_inspeksi"].FirstOrDefault() ?? form["category"].FirstOrDefault() ?? "Inspeksi K3 Lapangan";
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
                    var jenisKendaraan = form["jenis_kendaraan"].FirstOrDefault() ?? form["unit"].FirstOrDefault() ?? "LV";
                    var noLambung = form["no_lambung"].FirstOrDefault() ?? "LV-001";
                    var merek = form["merek"].FirstOrDefault() ?? form["brand"].FirstOrDefault() ?? "Toyota";
                    var kmStr = form["kilometer"].FirstOrDefault() ?? form["km"].FirstOrDefault() ?? form["hm"].FirstOrDefault() ?? "0";
                    var simper = form["simper_kimper"].FirstOrDefault() ?? (form["simper"].FirstOrDefault() == "1" ? "YA" : "TIDAK");

                    double.TryParse(kmStr, NumberStyles.Any, CultureInfo.InvariantCulture, out var kmVal);

                    var fotoSpeedo = form.Files["foto_speedometer"] ?? form.Files["image"];
                    string? fotoSpeedoUrl = null;
                    if (fotoSpeedo != null)
                    {
                        fotoSpeedoUrl = await _imageUploadService.UploadAndCompressImageAsync(fotoSpeedo, "p2h", "p2h");
                    }

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
                        GolA_Json = form["gol_a_json"].FirstOrDefault(),
                        GolB_Json = form["gol_b_json"].FirstOrDefault(),
                        GolC_Json = form["gol_c_json"].FirstOrDefault(),
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
                        PerusahaanId = companyId,
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

                // 7. P5M
                if (targetName == "p5m")
                {
                    var topik = form["topik"].FirstOrDefault() ?? form["topic_id"].FirstOrDefault() ?? "K3 Operasional";
                    var judul = form["judul"].FirstOrDefault() ?? form["title"].FirstOrDefault() ?? "P5M Awal Shift";
                    var keterangan = form["keterangan"].FirstOrDefault() ?? form["remark"].FirstOrDefault();

                    var fotoKegiatan = form.Files["foto_kegiatan"] ?? form.Files["image"];
                    string? fotoKegiatanUrl = null;
                    if (fotoKegiatan != null)
                    {
                        fotoKegiatanUrl = await _imageUploadService.UploadAndCompressImageAsync(fotoKegiatan, "p5m", "p5m");
                    }

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
                        PerusahaanId = companyId,
                        IsDeleted = false,
                        CreatedAt = DateTime.Now
                    };

                    _context.P5ms.Add(p5m);
                    await _context.SaveChangesAsync();

                    sw.Stop();
                    _monitor.RecordTransaction(new TransactionEvent
                    {
                        Type = "P5M",
                        Source = "Offline Outbox Sync",
                        ServerId = p5m.Id,
                        Code = $"P5M-{p5m.Id}",
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
                        Summary = $"[{topik}] {judul}"
                    });

                    return Ok(new
                    {
                        status = true,
                        data = new SyncResultDto
                        {
                            Id = p5m.Id,
                            Code = $"P5M-{p5m.Id}",
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
                return Ok(new { status = true, data = list });
            }

            if (targetName == "inspection")
            {
                var query = _context.Inspections
                    .AsNoTracking()
                    .Where(i => !i.IsDeleted && (i.Nik == userNik || (i.PerusahaanId.HasValue && allowedCompanyIds.Contains(i.PerusahaanId.Value))))
                    .OrderByDescending(i => i.CreatedAt)
                    .Take(limit);

                var list = await query.ToListAsync();
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
                var list = await _context.Coachings
                    .AsNoTracking()
                    .Where(c => !c.IsDeleted && (c.Nik == userNik || (c.PerusahaanId.HasValue && allowedCompanyIds.Contains(c.PerusahaanId.Value))))
                    .OrderByDescending(c => c.CreatedAt)
                    .Take(limit)
                    .ToListAsync();
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
                    .Take(limit)
                    .ToListAsync();
                return Ok(new { status = true, data = list });
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
                plan.Status = status;

                // Sync status with parent Hazard report if linked
                if (plan.ItemSap != null && plan.ItemSap.StartsWith("hazard:"))
                {
                    var hIdStr = plan.ItemSap["hazard:".Length..];
                    if (int.TryParse(hIdStr, out var hId))
                    {
                        var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == hId);
                        if (hazard != null)
                        {
                            hazard.StatusTemuan = status;
                            if (!string.IsNullOrEmpty(plan.FotoPerbaikan))
                            {
                                hazard.Perbaikan = plan.Perbaikan;
                            }
                        }
                    }
                }
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

            var plans = await _context.ActionPlans
                .AsNoTracking()
                .Where(a => !a.IsDeleted && (a.Nik == userNik || a.NikPic == userNik || a.NikPja == userNik || (a.PerusahaanId.HasValue && allowedCompanyIds.Contains(a.PerusahaanId.Value))))
                .OrderByDescending(a => a.CreatedAt)
                .Take(limit)
                .ToListAsync();

            return Ok(new { status = true, data = plans });
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
    }
}
