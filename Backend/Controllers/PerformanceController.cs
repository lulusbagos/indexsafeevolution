using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Indexsafe.Api.DTOs;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/performance")]
    [Route("performance")]
    [AllowAnonymous]
    public class PerformanceController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private readonly ImageUploadService _imageUploadService;

        public PerformanceController(AppDbContext context, CompanyHierarchyService companyHierarchyService, ImageUploadService imageUploadService)
        {
            _context = context;
            _companyHierarchyService = companyHierarchyService;
            _imageUploadService = imageUploadService;
        }

        public class GeoSafetyPointDto
        {
            public int Id { get; set; }
            public string Type { get; set; } = "hazard"; // Hazard finding
            public double Lat { get; set; }
            public double Lon { get; set; }
            public string Tanggal { get; set; } = string.Empty;
            public string TanggalIso { get; set; } = string.Empty;
            public string Waktu { get; set; } = string.Empty;
            public string Nama { get; set; } = string.Empty;
            public string Nik { get; set; } = string.Empty;
            public string Departemen { get; set; } = string.Empty;
            public string Area { get; set; } = string.Empty;
            public string Detail { get; set; } = string.Empty;
            public string KategoriBahaya { get; set; } = string.Empty;
            public string JenisBahaya { get; set; } = string.Empty;
            public string Resiko { get; set; } = "Sedang";
            public string Status { get; set; } = "Open";
            public string? PhotoUrl { get; set; }
            public string? Pja { get; set; }
            public string? NikPja { get; set; }
            public string? Perbaikan { get; set; }
            public string? TindakanPerbaikan { get; set; }
        }

        private static bool TryParseCoordinates(string? lokasi, out double lat, out double lon)
        {
            lat = 0;
            lon = 0;
            if (string.IsNullOrWhiteSpace(lokasi)) return false;

            var match = Regex.Match(lokasi, @"(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)");
            if (!match.Success) return false;

            if (double.TryParse(match.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out lat) &&
                double.TryParse(match.Groups[2].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out lon))
            {
                if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 && (Math.Abs(lat) > 0.001 || Math.Abs(lon) > 0.001))
                {
                    return true;
                }
            }
            return false;
        }

        private static readonly Dictionary<string, (double Lat, double Lon)> KnownAreaCoordinates = new(StringComparer.OrdinalIgnoreCase)
        {
            { "PIT - KPP", (1.042599, 117.680257) },
            { "PIT - MGE", (1.095973, 117.712722) },
            { "PIT - Unggul", (0.977340, 117.695135) },
            { "Port/Jetty - Indexim", (0.833812, 117.853334) },
            { "Port", (0.833812, 117.853334) },
            { "Road Coal Hauling (Jl. Nusantara)", (0.918824, 117.773958) },
            { "Coal Road Hauling", (0.918824, 117.773958) },
            { "CPP-33 & ROM - Indexim", (0.973054, 117.693741) },
            { "Coal Processing Plant 33", (0.973054, 117.693741) },
            { "Mess & Fasilitas - Indexim", (0.928804, 117.774446) },
            { "Mess & Fasilitas - KPP", (1.019011, 117.711487) },
            { "Mess & Fasilitas - Unggul", (0.936217, 117.728640) },
            { "Mess & Fasilitas - MGE", (1.178196, 117.792385) },
            { "Kantor - Indexim", (0.936469, 117.751554) },
            { "Kantor - KPP", (1.033713, 117.676107) },
            { "Kantor - MGE", (1.178196, 117.792385) },
            { "Kantor - Unggul", (0.977340, 117.695135) },
            { "Mining", (1.042599, 117.680257) },
            { "Main Support Facility", (0.936469, 117.751554) },
            { "Supporting Area", (0.936469, 117.751554) },
            { "Road PIT Overburden - KPP", (1.040586, 117.669256) },
            { "Road PIT Overburden - Unggul", (0.977340, 117.695135) },
            { "Road Coal Mining (Jl. Mawar)", (1.005588, 117.711325) },
            { "Road Coal Mining (Jl. Anggrek)", (1.025588, 117.701325) },
            { "Settling Pond - Indexim", (0.953054, 117.713741) },
            { "Settling Pond - KPP", (1.045054, 117.683741) },
            { "Settling Pond - Unggul", (0.985054, 117.703741) },
            { "PIT Central", (1.060000, 117.690000) },
            { "Other Area", (1.056431, 117.726522) }
        };

        private static (double Lat, double Lon) ResolveCoordinates(int id, string? area, string? lokasi, string? detilLokasi)
        {
            if (TryParseCoordinates(lokasi, out var lat, out var lon) ||
                TryParseCoordinates(detilLokasi, out lat, out lon))
            {
                return (lat, lon);
            }

            // Fallback ke centroid area tambang Indexim
            var jitterLat = ((id % 50) - 25) * 0.00015;
            var jitterLon = (((id * 7) % 50) - 25) * 0.00015;

            if (!string.IsNullOrWhiteSpace(area) && KnownAreaCoordinates.TryGetValue(area.Trim(), out var centroid))
            {
                return (centroid.Lat + jitterLat, centroid.Lon + jitterLon);
            }

            // Default centroid Indexim Kaliorang jika area tidak terdaftar spesifik
            return (1.056431 + jitterLat, 117.726522 + jitterLon);
        }

        /// <summary>
        /// GET /api/performance/safemap
        /// Returns spatial safety points focused exclusively on Hazard findings.
        /// Filters by unclosed hazards in one active period (30 days / current period).
        /// Sets a default lightweight limit (80 points) so mobile map rendering is super smooth.
        /// </summary>
        [HttpGet("safemap")]
        public async Task<IActionResult> GetSafeMapPoints(
            [FromQuery] int? month,
            [FromQuery] int? year,
            [FromQuery] int? days = 30,
            [FromQuery] bool onlyOpen = true,
            [FromQuery] double? userLat = null,
            [FromQuery] double? userLon = null,
            [FromQuery] int? limit = null)
        {
            // 1 Periode berjalan
            DateTime cutoffDate;
            if (month.HasValue && year.HasValue)
            {
                cutoffDate = new DateTime(year.Value, month.Value, 1);
            }
            else
            {
                cutoffDate = DateTime.Today.AddDays(-(days ?? 30));
            }

            var hazardPoints = new List<GeoSafetyPointDto>();

            try
            {
                // Query Hazard Reports asli: 1 periode berjalan dan status HANYA yang belum Closed
                var query = _context.HazardReports
                    .AsNoTracking()
                    .Where(h => !h.IsDeleted && h.Tanggal >= cutoffDate);

                if (onlyOpen)
                {
                    query = query.Where(h => h.StatusTemuan != "Closed" && 
                                             h.StatusTemuan != "closed" &&
                                             h.StatusTemuan != "Selesai" && 
                                             h.StatusTemuan != "selesai" &&
                                             h.StatusTemuan != "Tutup" &&
                                             h.StatusTemuan != "tutup");
                }

                query = query
                    .OrderByDescending(h => h.Tanggal)
                    .ThenByDescending(h => h.Id);

                // Default limit 80 titik teratas agar rendering di HP sangat cepat dan ringan
                int effectiveLimit = limit.HasValue && limit.Value > 0 ? limit.Value : 80;
                query = query.Take(effectiveLimit);

                var hazards = await query.ToListAsync();

                foreach (var h in hazards)
                {
                    var (lat, lon) = ResolveCoordinates(h.Id, h.Area, h.Lokasi, h.DetilLokasi);

                    hazardPoints.Add(new GeoSafetyPointDto
                    {
                        Id = h.Id,
                        Type = "hazard",
                        Lat = lat,
                        Lon = lon,
                        Tanggal = h.Tanggal.ToString("dd MMM yyyy"),
                        TanggalIso = h.Tanggal.ToString("yyyy-MM-dd"),
                        Waktu = h.Waktu.ToString(@"hh\:mm"),
                        Nama = string.IsNullOrWhiteSpace(h.Nama) ? "Karyawan Lapangan" : h.Nama,
                        Nik = h.Nik ?? "-",
                        Departemen = h.Departemen ?? "Operasional Tambang",
                        Area = string.IsNullOrWhiteSpace(h.Area) ? "Pit Tambang Kaliorang" : h.Area,
                        Detail = string.IsNullOrWhiteSpace(h.Temuan) ? "Temuan bahaya K3 memerlukan tindak lanjut" : h.Temuan,
                        KategoriBahaya = h.KategoriBahaya ?? "Kondisi Tidak Aman (KTA)",
                        JenisBahaya = h.JenisBahaya ?? "Fisik / Mekanikal",
                        Resiko = string.IsNullOrWhiteSpace(h.TingkatResiko) ? "Tinggi" : h.TingkatResiko,
                        Status = string.IsNullOrWhiteSpace(h.StatusTemuan) ? "Open" : h.StatusTemuan,
                        PhotoUrl = h.FotoTemuan,
                        Pja = h.Pja ?? "Foreman / Pengawas Area",
                        NikPja = h.NikPja ?? "-",
                        Perbaikan = h.Perbaikan,
                        TindakanPerbaikan = h.TindakanPerbaikan
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error retrieving SafeMap Hazard points: {ex.Message}");
            }

            var openHazardsCount = hazardPoints.Count(h => !h.Status.Equals("closed", StringComparison.OrdinalIgnoreCase) && !h.Status.Equals("selesai", StringComparison.OrdinalIgnoreCase));

            return Ok(new
            {
                status = true,
                message = "Berhasil memuat lokasi temuan hazard 30 hari terakhir yang belum closed",
                data = new
                {
                    hazardPoints,
                    total = hazardPoints.Count,
                    openHazardsCount
                }
            });
        }

        /// <summary>
        /// GET /api/performance/safemap/hazard/{id}
        /// GET /api/performance/safemap/detail/{id}
        /// Mengambil detail lengkap temuan hazard untuk pop up peta dan bottom sheet detail.
        /// </summary>
        [HttpGet("safemap/hazard/{id}")]
        [HttpGet("safemap/detail/{id}")]
        public async Task<IActionResult> GetHazardDetail(int id)
        {
            var h = await _context.HazardReports
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted);

            if (h != null)
            {
                var (lat, lon) = ResolveCoordinates(h.Id, h.Area, h.Lokasi, h.DetilLokasi);

                return Ok(new
                {
                    status = true,
                    message = "Detail Hazard ditemukan",
                    data = new
                    {
                        id = h.Id,
                        tanggal = h.Tanggal.ToString("dd MMM yyyy"),
                        waktu = h.Waktu.ToString(@"hh\:mm"),
                        nama = h.Nama,
                        nik = h.Nik,
                        departemen = h.Departemen,
                        area = h.Area,
                        lokasi = h.Lokasi,
                        detil_lokasi = h.DetilLokasi,
                        temuan = h.Temuan,
                        detail = h.Temuan,
                        kategori_bahaya = h.KategoriBahaya ?? "Kondisi Tidak Aman (KTA)",
                        jenis_bahaya = h.JenisBahaya ?? "Fisik / Mekanikal",
                        tingkat_resiko = h.TingkatResiko ?? "Tinggi",
                        resiko = h.TingkatResiko ?? "Tinggi",
                        status = h.StatusTemuan ?? "Open",
                        status_temuan = h.StatusTemuan ?? "Open",
                        foto_temuan = h.FotoTemuan,
                        photo_url = h.FotoTemuan,
                        foto_perbaikan = h.FotoPerbaikan,
                        pja = h.Pja,
                        nik_pja = h.NikPja,
                        departemen_pja = h.DepartemenPja,
                        perbaikan = h.Perbaikan,
                        tindakan_perbaikan = h.TindakanPerbaikan,
                        lat = lat,
                        lon = lon,
                        lng = lon,
                        created_at = h.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                });
            }

            return NotFound(new
            {
                status = false,
                message = $"Detail Hazard dengan ID {id} tidak ditemukan."
            });
        }

        /// <summary>
        /// POST /api/performance/safemap/close-hazard
        /// Endpoint langsung untuk menindaklanjuti & me-close temuan hazard dari Safe Map.
        /// </summary>
        [HttpPost("safemap/close-hazard")]
        public async Task<IActionResult> CloseHazard([FromForm] IFormCollection form)
        {
            var idStr = form["id"].FirstOrDefault();
            if (!int.TryParse(idStr, out var id) || id <= 0)
            {
                return BadRequest(new { status = false, message = "ID Hazard tidak valid." });
            }

            var action = form["action"].FirstOrDefault() ?? form["perbaikan"].FirstOrDefault() ?? "Temuan telah ditindaklanjuti dan ditutup.";
            var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == id && !h.IsDeleted);
            if (hazard != null)
            {
                hazard.StatusTemuan = "Closed";
                hazard.Perbaikan = action;
                hazard.TindakanPerbaikan = action;
            }

            // Sync action plan jika ada
            var plan = await _context.ActionPlans.FirstOrDefaultAsync(a => a.ItemSap == $"hazard:{id}" || a.Id == id);
            if (plan != null)
            {
                plan.Status = "Closed";
                plan.Perbaikan = action;
                plan.TanggalPerbaikan = DateTime.Today;
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Temuan Hazard berhasil ditindaklanjuti dan di-close!",
                data = new { id, status = "Closed", perbaikan = action }
            });
        }

        /// <summary>
        /// POST /api/performance/safemap/report-fake
        /// Melaporkan temuan hazard sebagai fake/fiktif/tidak ditemukan di lapangan.
        /// Dicatat ke tbl_t_hazard_fake_report dan diaudit oleh tim K3.
        /// </summary>
        [HttpPost("safemap/report-fake")]
        public async Task<IActionResult> ReportFakeHazard([FromForm] IFormCollection form)
        {
            var idStr = form["id"].FirstOrDefault() ?? form["hazard_id"].FirstOrDefault();
            if (!int.TryParse(idStr, out var hazardId) || hazardId <= 0)
            {
                return BadRequest(new { status = false, message = "ID Hazard tidak valid." });
            }

            var reason = form["reason"].FirstOrDefault() ?? form["alasan"].FirstOrDefault() ?? "Temuan fiktif / tidak ditemukan di lokasi.";
            var userNik = User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value 
                          ?? form["reporter_nik"].FirstOrDefault() 
                          ?? form["nik"].FirstOrDefault() 
                          ?? "0000";
            var userName = User?.Identity?.Name 
                           ?? User?.FindFirst(System.Security.Claims.ClaimTypes.Name)?.Value 
                           ?? form["reporter_name"].FirstOrDefault() 
                           ?? form["nama"].FirstOrDefault() 
                           ?? "Pengguna Mobile";
            var userDept = User?.FindFirst("Department")?.Value 
                           ?? form["reporter_dept"].FirstOrDefault() 
                           ?? form["departemen"].FirstOrDefault() 
                           ?? "GENERAL";
            var userComp = User?.FindFirst("Company")?.Value 
                           ?? form["reporter_company"].FirstOrDefault() 
                           ?? form["perusahaan"].FirstOrDefault() 
                           ?? "PT INDEXIM COALINDO";

            double? lat = double.TryParse(form["latitude"].FirstOrDefault(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var parsedLat) ? parsedLat : null;
            double? lng = double.TryParse(form["longitude"].FirstOrDefault(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var parsedLng) ? parsedLng : null;
            double? distance = double.TryParse(form["distance_meters"].FirstOrDefault(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var parsedDist) ? parsedDist : null;

            string? evidencePhotoUrl = null;
            if (form.Files.Count > 0 && form.Files[0] != null)
            {
                try
                {
                    evidencePhotoUrl = await _imageUploadService.UploadAndCompressImageAsync(form.Files[0], "fake_hazard_reports", "fake_");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[ReportFakeHazard] Gagal simpan foto: {ex.Message}");
                }
            }

            // Simpan ke tbl_t_hazard_fake_report
            var conn = _context.Database.GetDbConnection();
            bool wasClosed = conn.State == System.Data.ConnectionState.Closed;
            if (wasClosed) await conn.OpenAsync();
            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = @"
                    INSERT INTO tbl_t_hazard_fake_report 
                    (hazard_id, reporter_nik, reporter_name, reporter_dept, reporter_company, reason, evidence_photo, latitude, longitude, distance_meters, reported_at, status)
                    VALUES 
                    (@hazard_id, @reporter_nik, @reporter_name, @reporter_dept, @reporter_company, @reason, @evidence_photo, @latitude, @longitude, @distance_meters, GETDATE(), 'PENDING_REVIEW');
                ";
                void AddParam(string name, object? val)
                {
                    var p = cmd.CreateParameter();
                    p.ParameterName = name;
                    p.Value = val ?? DBNull.Value;
                    cmd.Parameters.Add(p);
                }
                AddParam("@hazard_id", hazardId);
                AddParam("@reporter_nik", userNik);
                AddParam("@reporter_name", userName);
                AddParam("@reporter_dept", userDept);
                AddParam("@reporter_company", userComp);
                AddParam("@reason", reason);
                AddParam("@evidence_photo", evidencePhotoUrl);
                AddParam("@latitude", lat);
                AddParam("@longitude", lng);
                AddParam("@distance_meters", distance);

                await cmd.ExecuteNonQueryAsync();
            }
            finally
            {
                if (wasClosed) await conn.CloseAsync();
            }

            // Update status temuan di tbl_t_hazard_report agar tidak muncul lagi sebagai hazard open
            var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == hazardId && !h.IsDeleted);
            if (hazard != null)
            {
                hazard.StatusTemuan = "Fake Reported";
                hazard.Perbaikan = $"[DILAPORKAN FAKE oleh {userName} ({userNik})]: {reason}";
                await _context.SaveChangesAsync();
            }

            return Ok(new
            {
                status = true,
                message = "Laporan Fake Hazard berhasil dikirim dan dicatat untuk diverifikasi oleh tim K3.",
                data = new
                {
                    hazard_id = hazardId,
                    reporter_nik = userNik,
                    reporter_name = userName,
                    reason,
                    status = "PENDING_REVIEW"
                }
            });
        }

        public class DepartmentLeagueItemDto
        {
            public int Rank { get; set; }
            public string DepartmentName { get; set; } = string.Empty;
            public string Initials { get; set; } = string.Empty;
            public string ShieldColor { get; set; } = "#1e3a8a";
            public int EmployeeCount { get; set; }
            public int TotalTarget { get; set; }
            public int TotalActual { get; set; }
            public double MtdAchievementRate { get; set; }
            public double TotalScore { get; set; }
            public double MtdCloseRate { get; set; } = 100.0;
            public double MtdHazardRate { get; set; }
            public double MtdInspeksiRate { get; set; }
            public double MtdSafetyTalkRate { get; set; }
            public double MtdObservasiRate { get; set; }
            public double MtdCoachingRate { get; set; }
            public double MtdP5mRate { get; set; }
            public List<string> Form { get; set; } = new();
            public double PtsClose { get; set; }
            public double PtsKualitas { get; set; }
            public double PtsCapaian { get; set; }
            public double PtsBeban { get; set; }
            public int HazardActual { get; set; }
            public int HazardTarget { get; set; }
            public int InspeksiActual { get; set; }
            public int InspeksiTarget { get; set; }
            public int SafetyTalkActual { get; set; }
            public int SafetyTalkTarget { get; set; }
            public int ObservasiActual { get; set; }
            public int ObservasiTarget { get; set; }
            public int CoachingActual { get; set; }
            public int CoachingTarget { get; set; }
            public int P5mActual { get; set; }
            public int P5mTarget { get; set; }
            public int ApTotal { get; set; }
            public int ApClosed { get; set; }
        }

        private static List<string> CalculateFormDots(double h, double i, double st, double o, double c)
        {
            return new List<string>
            {
                GetDotChar(h),
                GetDotChar(i),
                GetDotChar(st),
                GetDotChar(o),
                GetDotChar(c)
            };
        }

        private static string GetDotChar(double rate)
        {
            if (rate < 0) return "W";
            if (rate >= 80.0) return "W";
            if (rate >= 40.0) return "D";
            return "L";
        }

        private static string GetDeptInitials(string name)
        {
            if (string.IsNullOrEmpty(name)) return "GEN";
            var clean = new string(name.Where(c => char.IsLetterOrDigit(c) || char.IsWhiteSpace(c)).ToArray()).Trim();
            var words = clean.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (words.Length >= 2)
            {
                return (words[0][0].ToString() + words[1][0].ToString()).ToUpper();
            }
            return (clean.Length >= 2 ? clean.Substring(0, 2) : clean).ToUpper();
        }

        private static string GetDeptColor(string name)
        {
            if (string.IsNullOrEmpty(name)) return "#1e3a8a";
            int hash = 0;
            foreach (char c in name)
            {
                hash = c + ((hash << 5) - hash);
            }
            var colors = new[] {
                "#1e3a8a", "#b91c1c", "#047857", "#6d28d9", "#a21caf",
                "#c2410c", "#0369a1", "#15803d", "#be123c", "#4d7c0f"
            };
            int idx = Math.Abs(hash) % colors.Length;
            return colors[idx];
        }

        /// <summary>
        /// GET /api/performance/league
        /// Mengembalikan klasemen departemen SAP dengan 4-Pillar PTS scoring dan 5 Form Dots (W/D/L)
        /// Sesuai rumus & tampilan Web /Performance/League
        /// </summary>
        [HttpGet("league")]
        public async Task<IActionResult> GetDepartmentLeague([FromQuery] int? year = null, [FromQuery] int? month = null, [FromQuery] int? companyId = null)
        {
            var today = DateTime.Today;
            int selYear = year ?? today.Year;
            int selMonth = month ?? today.Month;
            var startOfMonth = new DateTime(selYear, selMonth, 1);
            var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);

            const string monthsIndo = "Januari,Februari,Maret,April,Mei,Juni,Juli,Agustus,September,Oktober,November,Desember";
            var mNames = monthsIndo.Split(',');
            string periodStr = $"{mNames[selMonth - 1]} {selYear}";

            // Resolve effectiveCompanyId (prioritas: query param -> user claims/db -> default 1 PT INDEXIM COALINDO)
            int effectiveCompanyId = companyId ?? 0;
            if (effectiveCompanyId <= 0)
            {
                var claimCid = User.FindFirst("CompanyId")?.Value;
                if (int.TryParse(claimCid, out int parsedCid) && parsedCid > 0)
                {
                    effectiveCompanyId = parsedCid;
                }
                else
                {
                    var userNik = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? User.Identity?.Name;
                    if (!string.IsNullOrEmpty(userNik))
                    {
                        var kUser = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == userNik && k.StatusAktif);
                        if (kUser != null && kUser.IdPerusahaan > 0)
                        {
                            effectiveCompanyId = kUser.IdPerusahaan;
                        }
                    }
                }
            }
            if (effectiveCompanyId <= 0) effectiveCompanyId = 1;

            var companyObj = await _context.Perusahaans.AsNoTracking().FirstOrDefaultAsync(p => p.PerusahaanId == effectiveCompanyId);
            string compName = companyObj?.NamaPerusahaan ?? (effectiveCompanyId == 1 ? "PT INDEXIM COALINDO" : $"PERUSAHAAN #{effectiveCompanyId}");
            var list = await CalculateDynamicDepartmentLeagueAsync(effectiveCompanyId, selYear, selMonth, startOfMonth, endOfMonth);

            return Ok(new
            {
                status = true,
                message = "Berhasil memuat klasemen departemen SAP",
                data = new
                {
                    companyId = effectiveCompanyId,
                    companyName = compName,
                    period = periodStr,
                    totalClubs = list.Count,
                    departments = list
                }
            });
        }
        /// <summary>
        /// Kalkulasi dinamis 100% Real SQL Standings Liga SAP Departemen.
        /// Mengagregasi seluruh target karyawan aktif (roster scaling, MTD transaksi riil, AP close rate, PTS 4-Pillar).
        /// Selaras dengan Web /Performance/League mode=dept.
        /// </summary>
        private async Task<List<DepartmentLeagueItemDto>> CalculateDynamicDepartmentLeagueAsync(
            int effectiveCompanyId, int selectedYear, int selectedMonth, DateTime startOfMonth, DateTime endOfMonth)
        {
            int totalDaysInMonth = DateTime.DaysInMonth(selectedYear, selectedMonth);

            // 1. Ambil seluruh karyawan aktif di perusahaan untuk departemennya
            var companyEmployees = await (from k in _context.Karyawans.AsNoTracking()
                                          join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dGroup
                                          from d in dGroup.DefaultIfEmpty()
                                          where k.StatusAktif == true &&
                                                k.IdPerusahaan == effectiveCompanyId &&
                                                (k.TanggalMasuk == null || k.TanggalMasuk <= endOfMonth)
                                          select new
                                          {
                                              k.IdKaryawan,
                                              NoNik = k.NoNik.Trim(),
                                              k.TanggalMasuk,
                                              Department = (d != null && !string.IsNullOrWhiteSpace(d.NamaDepartemen)) ? d.NamaDepartemen.Trim() : "General"
                                          }).ToListAsync();

            if (!companyEmployees.Any()) return new List<DepartmentLeagueItemDto>();

            // 2. Target mapping dari view KaryawanJabatanMappings
            var mappings = await _context.KaryawanJabatanMappings.AsNoTracking()
                .Where(m => m.PerusahaanId == effectiveCompanyId)
                .ToDictionaryAsync(m => m.KaryawanId);

            // 3. Roster karyawan
            var rosters = await _context.Rosters.AsNoTracking()
                .Where(r => r.AwalDinas <= endOfMonth && (r.AkhirCuti >= startOfMonth || r.AkhirDinas >= startOfMonth))
                .ToListAsync();
            var rostersByNik = rosters
                .GroupBy(r => r.Nik.Trim(), StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.ToList(), StringComparer.OrdinalIgnoreCase);

            // 4. Hitung actual MTD seluruh modul
            var hazards = await _context.HazardReports.AsNoTracking()
                .Where(h => !h.IsDeleted && h.Tanggal >= startOfMonth && h.Tanggal <= endOfMonth && h.Nik != null)
                .Select(h => new { Nik = h.Nik.Trim(), h.Tanggal, h.Waktu, h.Lokasi })
                .Distinct()
                .GroupBy(h => h.Nik)
                .Select(g => new { Nik = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

            var inspections = await _context.Inspections.AsNoTracking()
                .Where(i => !i.IsDeleted && i.Tanggal >= startOfMonth && i.Tanggal <= endOfMonth && i.Nik != null)
                .Select(i => new { Nik = i.Nik.Trim(), i.Tanggal, i.Waktu })
                .Distinct()
                .GroupBy(i => i.Nik)
                .Select(g => new { Nik = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

            var safetyTalks = await _context.SafetyTalks.AsNoTracking()
                .Where(s => !s.IsDeleted && s.Tanggal >= startOfMonth && s.Tanggal <= endOfMonth && s.Nik != null)
                .Select(s => new { Nik = s.Nik.Trim(), s.Tanggal, s.Waktu })
                .Distinct()
                .GroupBy(s => s.Nik)
                .Select(g => new { Nik = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

            var observations = await _context.Observations.AsNoTracking()
                .Where(o => !o.IsDeleted && o.CreatedAt >= startOfMonth && o.CreatedAt <= endOfMonth && o.Nik != null)
                .Select(o => new { Nik = o.Nik.Trim(), o.Date, o.KegiatanYangDiamati })
                .Distinct()
                .GroupBy(o => o.Nik)
                .Select(g => new { Nik = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

            var coachingCreators = await _context.Coachings.AsNoTracking()
                .Where(c => !c.IsDeleted && c.CreatedAt >= startOfMonth && c.CreatedAt <= endOfMonth && c.Nik != null)
                .Select(c => c.Nik.Trim())
                .ToListAsync();
            var coachingParticipants = await _context.CoachingParticipants.AsNoTracking()
                .Where(cp => cp.Coaching != null && !cp.Coaching.IsDeleted && cp.Coaching.CreatedAt >= startOfMonth && cp.Coaching.CreatedAt <= endOfMonth && cp.Nik != null)
                .Select(cp => cp.Nik.Trim())
                .ToListAsync();
            var coachings = coachingCreators.Concat(coachingParticipants)
                .GroupBy(n => n, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

            var p5ms = await _context.P5ms.AsNoTracking()
                .Where(p => !p.IsDeleted && p.CreatedAt >= startOfMonth && p.CreatedAt <= endOfMonth && p.Nik != null)
                .Select(p => new { Nik = p.Nik.Trim(), p.Tanggal, p.Waktu })
                .Distinct()
                .GroupBy(p => p.Nik)
                .Select(g => new { Nik = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

            // 5. Action plan per departemen
            var monthlyActionPlans = await _context.ActionPlans.AsNoTracking()
                .Where(a => !a.IsDeleted && (
                    (a.Tanggal >= startOfMonth && a.Tanggal <= endOfMonth) ||
                    (a.CreatedAt >= startOfMonth && a.CreatedAt <= endOfMonth)
                ))
                .Select(a => new {
                    DepartemenPic = a.DepartemenPic != null ? a.DepartemenPic.Trim() : "",
                    DepartemenPja = a.DepartemenPja != null ? a.DepartemenPja.Trim() : "",
                    a.Status
                })
                .ToListAsync();

            // 6. Kualitas SAP per departemen jika ada
            var deptQualityStats = new Dictionary<string, (int TotalRated, double ScoreKualitas)>(StringComparer.OrdinalIgnoreCase);
            try
            {
                var conn = _context.Database.GetDbConnection();
                if (conn.State != System.Data.ConnectionState.Open) await conn.OpenAsync();
                using var cmd = conn.CreateCommand();
                cmd.CommandText = @"
                    WITH AllRatedDept AS (
                        SELECT LTRIM(RTRIM(h.departemen)) AS dept, q.rating
                        FROM tbl_t_hazard_report h WITH (NOLOCK)
                        JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Hazard' AND q.program_id = h.id
                        WHERE h.is_deleted = 0 AND h.tanggal >= @start AND h.tanggal <= @end AND h.departemen IS NOT NULL
                        UNION ALL
                        SELECT LTRIM(RTRIM(i.departemen)) AS dept, q.rating
                        FROM tbl_t_inspection i WITH (NOLOCK)
                        JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Inspection' AND q.program_id = i.id
                        WHERE i.is_deleted = 0 AND i.tanggal >= @start AND i.tanggal <= @end AND i.departemen IS NOT NULL
                        UNION ALL
                        SELECT LTRIM(RTRIM(s.departemen)) AS dept, q.rating
                        FROM tbl_t_safety_talk s WITH (NOLOCK)
                        JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'SafetyTalk' AND q.program_id = s.id
                        WHERE s.is_deleted = 0 AND s.tanggal >= @start AND s.tanggal <= @end AND s.departemen IS NOT NULL
                        UNION ALL
                        SELECT LTRIM(RTRIM(o.departemen)) AS dept, q.rating
                        FROM tbl_t_observation o WITH (NOLOCK)
                        JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Observation' AND q.program_id = o.id
                        WHERE o.is_deleted = 0 AND o.date >= @start AND o.date <= @end AND o.departemen IS NOT NULL
                        UNION ALL
                        SELECT LTRIM(RTRIM(c.departemen)) AS dept, q.rating
                        FROM tbl_t_coaching c WITH (NOLOCK)
                        JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Coaching' AND q.program_id = c.id
                        WHERE c.is_deleted = 0 AND c.tanggal >= @start AND c.tanggal <= @end AND c.departemen IS NOT NULL
                    )
                    SELECT dept, COUNT(*) AS TotalRated, AVG(CAST(rating AS FLOAT)) AS AvgRating
                    FROM AllRatedDept
                    WHERE dept IS NOT NULL AND dept <> ''
                    GROUP BY dept;";

                var pStart = cmd.CreateParameter();
                pStart.ParameterName = "@start";
                pStart.Value = startOfMonth;
                cmd.Parameters.Add(pStart);

                var pEnd = cmd.CreateParameter();
                pEnd.ParameterName = "@end";
                pEnd.Value = endOfMonth;
                cmd.Parameters.Add(pEnd);

                using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    string dKey = reader.GetString(0).Trim();
                    int totalRated = reader.GetInt32(1);
                    double avgRating = reader.GetDouble(2);
                    double score = Math.Min(100.0, Math.Max(0.0, Math.Round((avgRating / 5.0) * 100.0, 1)));
                    deptQualityStats[dKey] = (totalRated, score);
                }
            }
            catch { }

            // Helper scale target
            static int ScaleTarget(int baseTarget, double ratio, int onsiteDays)
            {
                if (baseTarget == 0 || onsiteDays == 0) return 0;
                int scaled = (int)Math.Round(baseTarget * Math.Min(1.0, ratio), MidpointRounding.AwayFromZero);
                return Math.Min(baseTarget, Math.Max(scaled, 1));
            }

            // 7. Hitung target & actual per karyawan, lalu kumpulkan per departemen
            var deptAggregates = new Dictionary<string, (
                int EmployeeCount,
                int TotalTarget, int TotalActual,
                int HAct, int HTgt,
                int IAct, int ITgt,
                int StAct, int StTgt,
                int OAct, int OTgt,
                int CAct, int CTgt,
                int P5mAct, int P5mTgt
            )>(StringComparer.OrdinalIgnoreCase);

            foreach (var emp in companyEmployees)
            {
                string eNik = emp.NoNik.Trim();
                if (!mappings.TryGetValue(emp.IdKaryawan, out var m) || m == null) continue;

                int hBase = m.TargetHazardReport ?? 0;
                int iBase = m.TargetInspeksi ?? 0;
                int stBase = m.TargetSafetyTalk ?? 0;
                int oBase = m.TargetObservasi ?? 0;
                int cBase = m.TargetCoaching ?? 0;
                int p5mBase = 1;

                bool isTargetSap = (hBase + iBase + stBase + oBase + cBase > 0);
                if (!isTargetSap) continue;

                int onsiteDays = totalDaysInMonth;
                bool hasRoster = false;
                DateTime effStart = (emp.TanggalMasuk.HasValue && emp.TanggalMasuk.Value > startOfMonth)
                    ? emp.TanggalMasuk.Value
                    : startOfMonth;

                if (rostersByNik.TryGetValue(eNik, out var empRosters) && empRosters.Count > 0)
                {
                    hasRoster = true;
                    int computedOnsite = 0;
                    for (var cur = effStart.Date; cur <= endOfMonth.Date; cur = cur.AddDays(1))
                    {
                        bool isTugas = empRosters.Any(r => r.TipeRoster == "TUGAS" && r.AwalDinas.Date <= cur && cur <= r.AkhirDinas.Date);
                        if (!isTugas)
                        {
                            bool isDinas = empRosters.Any(r => r.TipeRoster != "TUGAS" && r.AwalDinas.Date <= cur && cur <= r.AkhirDinas.Date);
                            if (isDinas) computedOnsite++;
                        }
                    }
                    onsiteDays = Math.Min(computedOnsite, totalDaysInMonth);
                }
                else if (effStart > startOfMonth)
                {
                    hasRoster = true;
                    onsiteDays = Math.Min((endOfMonth.Date - effStart.Date).Days + 1, totalDaysInMonth);
                }

                double ratio = hasRoster ? Math.Min(1.0, (double)onsiteDays / totalDaysInMonth) : 1.0;

                int tgtH = hasRoster ? ScaleTarget(hBase, ratio, onsiteDays) : hBase;
                int tgtI = hasRoster ? ScaleTarget(iBase, ratio, onsiteDays) : iBase;
                int tgtSt = hasRoster ? ScaleTarget(stBase, ratio, onsiteDays) : stBase;
                int tgtO = hasRoster ? ScaleTarget(oBase, ratio, onsiteDays) : oBase;
                int tgtC = hasRoster ? ScaleTarget(cBase, ratio, onsiteDays) : cBase;
                int tgtP5m = p5mBase;

                int totalTarget = tgtH + tgtI + tgtSt + tgtO + tgtC;

                int actH = hazards.TryGetValue(eNik, out int hC) ? hC : 0;
                int actI = inspections.TryGetValue(eNik, out int iC) ? iC : 0;
                int actSt = safetyTalks.TryGetValue(eNik, out int stC) ? stC : 0;
                int actO = observations.TryGetValue(eNik, out int oC) ? oC : 0;
                int actC = coachings.TryGetValue(eNik, out int cC) ? cC : 0;
                int actP5m = p5ms.TryGetValue(eNik, out int pC) ? pC : 0;

                int cappedAct = Math.Min(actH, tgtH) + Math.Min(actI, tgtI) + Math.Min(actSt, tgtSt) + Math.Min(actO, tgtO) + Math.Min(actC, tgtC);

                string deptName = emp.Department;
                if (!deptAggregates.TryGetValue(deptName, out var agg))
                {
                    agg = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
                }

                deptAggregates[deptName] = (
                    agg.EmployeeCount + 1,
                    agg.TotalTarget + totalTarget,
                    agg.TotalActual + cappedAct,
                    agg.HAct + Math.Min(actH, tgtH), agg.HTgt + tgtH,
                    agg.IAct + Math.Min(actI, tgtI), agg.ITgt + tgtI,
                    agg.StAct + Math.Min(actSt, tgtSt), agg.StTgt + tgtSt,
                    agg.OAct + Math.Min(actO, tgtO), agg.OTgt + tgtO,
                    agg.CAct + Math.Min(actC, tgtC), agg.CTgt + tgtC,
                    agg.P5mAct + Math.Min(actP5m, tgtP5m), agg.P5mTgt + tgtP5m
                );
            }

            int maxDeptTarget = deptAggregates.Any() ? deptAggregates.Values.Max(d => d.TotalTarget) : 1;
            if (maxDeptTarget <= 0) maxDeptTarget = 1;

            var rawList = new List<DepartmentLeagueItemDto>();

            foreach (var kvp in deptAggregates)
            {
                string deptName = kvp.Key;
                var d = kvp.Value;

                var deptAps = monthlyActionPlans.Where(a =>
                    (!string.IsNullOrEmpty(a.DepartemenPja) && string.Equals(a.DepartemenPja, deptName, StringComparison.OrdinalIgnoreCase)) ||
                    (!string.IsNullOrEmpty(a.DepartemenPic) && string.Equals(a.DepartemenPic, deptName, StringComparison.OrdinalIgnoreCase))
                ).ToList();

                int apTotal = deptAps.Count;
                int apClosed = deptAps.Count(a => IsClosedStatus(a.Status));
                double closeRate = apTotal > 0 ? Math.Round((double)apClosed / apTotal * 100.0, 1) : 100.0;

                double mtdRate = d.TotalTarget > 0 ? Math.Min(100.0, Math.Round((double)d.TotalActual / d.TotalTarget * 100.0, 1)) : 0.0;
                double hRate = d.HTgt > 0 ? Math.Min(100.0, Math.Round((double)d.HAct / d.HTgt * 100.0, 1)) : -1.0;
                double iRate = d.ITgt > 0 ? Math.Min(100.0, Math.Round((double)d.IAct / d.ITgt * 100.0, 1)) : -1.0;
                double stRate = d.StTgt > 0 ? Math.Min(100.0, Math.Round((double)d.StAct / d.StTgt * 100.0, 1)) : -1.0;
                double oRate = d.OTgt > 0 ? Math.Min(100.0, Math.Round((double)d.OAct / d.OTgt * 100.0, 1)) : -1.0;
                double cRate = d.CTgt > 0 ? Math.Min(100.0, Math.Round((double)d.CAct / d.CTgt * 100.0, 1)) : -1.0;
                double p5mRate = d.P5mTgt > 0 ? Math.Min(100.0, Math.Round((double)d.P5mAct / d.P5mTgt * 100.0, 1)) : -1.0;

                double scoreClose = Math.Min(100.0, Math.Max(0.0, closeRate));
                double scoreKualitas = (deptQualityStats.TryGetValue(deptName, out var dQ) && dQ.TotalRated > 0)
                    ? dQ.ScoreKualitas
                    : (d.TotalActual > 0 ? 100.0 : 0.0);
                double scoreCapaian = Math.Min(100.0, Math.Max(0.0, mtdRate));
                double scoreBeban = (d.TotalTarget > 0 && maxDeptTarget > 0)
                    ? (d.TotalTarget >= maxDeptTarget ? 100.0 : Math.Min(100.0, Math.Max(0.0, (Math.Log10(d.TotalTarget + 1) / Math.Log10(maxDeptTarget + 1)) * 100.0)))
                    : 0.0;

                double ptsClose = Math.Round(scoreClose * 0.30, 2);
                double ptsKualitas = Math.Round(scoreKualitas * 0.25, 2);
                double ptsCapaian = Math.Round(scoreCapaian * 0.35, 2);
                double ptsBeban = Math.Round(scoreBeban * 0.10, 2);
                double totalScore = Math.Round(ptsClose + ptsKualitas + ptsCapaian + ptsBeban, 2);

                rawList.Add(new DepartmentLeagueItemDto
                {
                    DepartmentName = deptName,
                    Initials = GetDeptInitials(deptName),
                    ShieldColor = GetDeptColor(deptName),
                    EmployeeCount = d.EmployeeCount,
                    TotalTarget = d.TotalTarget,
                    TotalActual = d.TotalActual,
                    MtdAchievementRate = mtdRate,
                    MtdCloseRate = closeRate,
                    MtdHazardRate = hRate >= 0 ? hRate : 100.0,
                    MtdInspeksiRate = iRate >= 0 ? iRate : 100.0,
                    MtdSafetyTalkRate = stRate >= 0 ? stRate : 100.0,
                    MtdObservasiRate = oRate >= 0 ? oRate : 100.0,
                    MtdCoachingRate = cRate >= 0 ? cRate : 100.0,
                    MtdP5mRate = p5mRate >= 0 ? p5mRate : 100.0,
                    Form = CalculateFormDots(hRate, iRate, stRate, oRate, cRate),
                    PtsClose = ptsClose,
                    PtsKualitas = ptsKualitas,
                    PtsCapaian = ptsCapaian,
                    PtsBeban = ptsBeban,
                    TotalScore = totalScore,
                    HazardActual = d.HAct,
                    HazardTarget = d.HTgt,
                    InspeksiActual = d.IAct,
                    InspeksiTarget = d.ITgt,
                    SafetyTalkActual = d.StAct,
                    SafetyTalkTarget = d.StTgt,
                    ObservasiActual = d.OAct,
                    ObservasiTarget = d.OTgt,
                    CoachingActual = d.CAct,
                    CoachingTarget = d.CTgt,
                    P5mActual = d.P5mAct,
                    P5mTarget = d.P5mTgt,
                    ApTotal = apTotal,
                    ApClosed = apClosed
                });
            }

            var sorted = rawList
                .OrderBy(d => d.TotalTarget == 0 ? 1 : 0)
                .ThenByDescending(d => d.TotalScore)
                .ThenByDescending(d => d.MtdCloseRate)
                .ThenByDescending(d => d.MtdAchievementRate)
                .ToList();

            for (int i = 0; i < sorted.Count; i++)
            {
                sorted[i].Rank = i + 1;
            }

            return sorted;
        }


        [HttpGet("sap-quality-dashboard")]
        [HttpGet("quality-dashboard")]
        public async Task<IActionResult> GetSapQualityDashboard(
            [FromQuery] string? nik = null, 
            [FromQuery] int? year = null, 
            [FromQuery] int? month = null)
        {
            try
            {
                var targetNik = !string.IsNullOrWhiteSpace(nik) 
                    ? nik.Trim() 
                    : (User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? User.Identity?.Name ?? "");

                if (string.IsNullOrEmpty(targetNik))
                {
                    var defaultEmp = await _context.Karyawans.AsNoTracking().Where(k => k.StatusAktif).Select(k => k.NoNik).FirstOrDefaultAsync();
                    targetNik = defaultEmp ?? "0002";
                }

                // Query employee profile info
                string employeeName = targetNik;
                string employeeDept = "GENERAL";
                string employeeCompany = "PT INDEXIM COALINDO";

                var karyawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == targetNik);
                if (karyawan != null)
                {
                    var personal = await _context.Personals.AsNoTracking().FirstOrDefaultAsync(p => p.IdPersonal == karyawan.IdPersonal);
                    if (personal != null) employeeName = personal.NamaLengkap;

                    if (karyawan.IdDepartemen.HasValue)
                    {
                        var dept = await _context.Departemens.AsNoTracking().FirstOrDefaultAsync(d => d.DepartemenId == karyawan.IdDepartemen.Value);
                        if (dept != null) employeeDept = dept.NamaDepartemen;
                    }
                    if (karyawan.IdPerusahaan > 0)
                    {
                        var comp = await _context.Perusahaans.AsNoTracking().FirstOrDefaultAsync(c => c.PerusahaanId == karyawan.IdPerusahaan);
                        if (comp != null) employeeCompany = comp.NamaPerusahaan;
                    }
                }

                // 1. Hazard Reports
                var hazardQuery = _context.HazardReports.AsNoTracking()
                    .Where(h => !h.IsDeleted && h.Nik == targetNik);
                if (year.HasValue) hazardQuery = hazardQuery.Where(h => h.Tanggal.Year == year.Value);
                if (month.HasValue) hazardQuery = hazardQuery.Where(h => h.Tanggal.Month == month.Value);
                var hazards = await hazardQuery.OrderByDescending(h => h.Tanggal).Take(200).ToListAsync();

                // 2. Inspections
                var inspQuery = _context.Inspections.AsNoTracking()
                    .Where(i => !i.IsDeleted && i.Nik == targetNik);
                if (year.HasValue) inspQuery = inspQuery.Where(i => i.Tanggal.Year == year.Value);
                if (month.HasValue) inspQuery = inspQuery.Where(i => i.Tanggal.Month == month.Value);
                var inspections = await inspQuery.OrderByDescending(i => i.Tanggal).Take(200).ToListAsync();

                // 3. Safety Talks
                var stQuery = _context.SafetyTalks.AsNoTracking()
                    .Where(s => !s.IsDeleted && s.Nik == targetNik);
                if (year.HasValue) stQuery = stQuery.Where(s => s.Tanggal.Year == year.Value);
                if (month.HasValue) stQuery = stQuery.Where(s => s.Tanggal.Month == month.Value);
                var safetyTalks = await stQuery.OrderByDescending(s => s.Tanggal).Take(200).ToListAsync();

                // 4. Observations
                var obsQuery = _context.Observations.AsNoTracking()
                    .Where(o => !o.IsDeleted && o.Nik == targetNik);
                if (year.HasValue) obsQuery = obsQuery.Where(o => o.Date.Year == year.Value);
                if (month.HasValue) obsQuery = obsQuery.Where(o => o.Date.Month == month.Value);
                var observations = await obsQuery.OrderByDescending(o => o.Date).Take(200).ToListAsync();

                // 5. Coachings
                var cQuery = _context.Coachings.AsNoTracking()
                    .Where(c => !c.IsDeleted && c.Nik == targetNik);
                if (year.HasValue) cQuery = cQuery.Where(c => c.Tanggal.Year == year.Value);
                if (month.HasValue) cQuery = cQuery.Where(c => c.Tanggal.Month == month.Value);
                var coachings = await cQuery.OrderByDescending(c => c.Tanggal).Take(200).ToListAsync();

                // Target IDs for assessments
                var hazardIds = hazards.Select(h => h.Id).ToList();
                var inspIds = inspections.Select(i => i.Id).ToList();
                var stIds = safetyTalks.Select(s => s.Id).ToList();
                var obsIds = observations.Select(o => o.Id).ToList();
                var cIds = coachings.Select(c => c.Id).ToList();

                var assessments = await _context.SapQualityAssessments.AsNoTracking()
                    .Where(a => 
                        (a.ProgramType == "Hazard" && hazardIds.Contains(a.ProgramId)) ||
                        (a.ProgramType == "Inspection" && inspIds.Contains(a.ProgramId)) ||
                        (a.ProgramType == "SafetyTalk" && stIds.Contains(a.ProgramId)) ||
                        (a.ProgramType == "Observation" && obsIds.Contains(a.ProgramId)) ||
                        (a.ProgramType == "Coaching" && cIds.Contains(a.ProgramId))
                    ).ToListAsync();

                var assessDict = assessments
                    .GroupBy(a => $"{a.ProgramType.ToLowerInvariant()}_{a.ProgramId}")
                    .ToDictionary(g => g.Key, g => g.First());

                var allItems = new List<SapQualityItemDto>();

                foreach (var h in hazards)
                {
                    var key = $"hazard_{h.Id}";
                    int rating;
                    string notes;
                    bool isAudited = false;
                    bool isAi = false;

                    if (assessDict.TryGetValue(key, out var assess))
                    {
                        rating = assess.Rating;
                        notes = assess.Notes ?? "";
                        isAudited = true;
                    }
                    else
                    {
                        var aiResult = SapQualityMlEngine.AnalyzeHazard(
                            h.Temuan, h.KategoriBahaya, h.JenisBahaya, h.TingkatResiko, h.Lokasi, h.DetilLokasi, h.Perbaikan, h.StatusTemuan, h.Tanggal
                        );
                        rating = aiResult.QualityScore;
                        notes = aiResult.QualityScoreNotes;
                        isAi = true;
                    }

                    var aiHazard = SapQualityMlEngine.AnalyzeHazard(
                        h.Temuan, h.KategoriBahaya, h.JenisBahaya, h.TingkatResiko, h.Lokasi, h.DetilLokasi, h.Perbaikan, h.StatusTemuan, h.Tanggal
                    );

                    allItems.Add(new SapQualityItemDto
                    {
                        Id = h.Id,
                        ProgramType = "Hazard",
                        Title = string.IsNullOrWhiteSpace(h.KategoriBahaya) ? "Temuan Hazard" : $"Hazard - {h.KategoriBahaya}",
                        Description = !string.IsNullOrWhiteSpace(h.Temuan) ? h.Temuan : "-",
                        Tanggal = h.Tanggal,
                        TanggalFormatted = h.Tanggal.ToString("dd MMM yyyy"),
                        Lokasi = h.Lokasi,
                        Rating = rating,
                        QualityLabel = GetQualityLabelText(rating),
                        QualityColor = GetQualityColorCode(rating),
                        Notes = notes,
                        IsAuditedBySupervisor = isAudited,
                        IsAiAssessed = isAi,
                        PhotoUrl = h.FotoTemuan,
                        HazardPriority = aiHazard.PriorityLevel,
                        HazardBadgeColor = aiHazard.PriorityBadgeColor,
                        HazardDueDateText = aiHazard.RecommendedDueDateText
                    });
                }

                // 2. Inspections
                foreach (var i in inspections)
                {
                    var key = $"inspection_{i.Id}";
                    int rating;
                    string notes;
                    bool isAudited = false;
                    bool isAi = false;

                    if (assessDict.TryGetValue(key, out var assess))
                    {
                        rating = assess.Rating;
                        notes = assess.Notes ?? "";
                        isAudited = true;
                    }
                    else
                    {
                        var (r, n) = SapQualityMlEngine.AssessQuality("Inspection", i.Area ?? "Inspeksi K3", i.Catatan ?? "");
                        rating = r;
                        notes = n;
                        isAi = true;
                    }

                    allItems.Add(new SapQualityItemDto
                    {
                        Id = i.Id,
                        ProgramType = "Inspection",
                        Title = string.IsNullOrWhiteSpace(i.Area) ? "Inspeksi K3" : $"Inspeksi - {i.Area}",
                        Description = !string.IsNullOrWhiteSpace(i.Catatan) ? i.Catatan : "Pemeriksaan checklist kondisi peralatan & area kerja.",
                        Tanggal = i.Tanggal,
                        TanggalFormatted = i.Tanggal.ToString("dd MMM yyyy"),
                        Lokasi = i.Area,
                        Rating = rating,
                        QualityLabel = GetQualityLabelText(rating),
                        QualityColor = GetQualityColorCode(rating),
                        Notes = notes,
                        IsAuditedBySupervisor = isAudited,
                        IsAiAssessed = isAi,
                        PhotoUrl = null
                    });
                }

                // 3. Safety Talks
                foreach (var s in safetyTalks)
                {
                    var key = $"safetytalk_{s.Id}";
                    int rating;
                    string notes;
                    bool isAudited = false;
                    bool isAi = false;

                    if (assessDict.TryGetValue(key, out var assess))
                    {
                        rating = assess.Rating;
                        notes = assess.Notes ?? "";
                        isAudited = true;
                    }
                    else
                    {
                        var (r, n) = SapQualityMlEngine.AssessQuality("SafetyTalk", s.Judul ?? "Safety Talk", s.Keterangan ?? "");
                        rating = r;
                        notes = n;
                        isAi = true;
                    }

                    allItems.Add(new SapQualityItemDto
                    {
                        Id = s.Id,
                        ProgramType = "SafetyTalk",
                        Title = string.IsNullOrWhiteSpace(s.Judul) ? "Safety Talk" : $"Safety Talk - {s.Judul}",
                        Description = !string.IsNullOrWhiteSpace(s.Keterangan) ? s.Keterangan : (!string.IsNullOrWhiteSpace(s.Judul) ? s.Judul : "-"),
                        Tanggal = s.Tanggal,
                        TanggalFormatted = s.Tanggal.ToString("dd MMM yyyy"),
                        Lokasi = s.Lokasi,
                        Rating = rating,
                        QualityLabel = GetQualityLabelText(rating),
                        QualityColor = GetQualityColorCode(rating),
                        Notes = notes,
                        IsAuditedBySupervisor = isAudited,
                        IsAiAssessed = isAi,
                        PhotoUrl = s.FotoKegiatan ?? s.FotoDiri
                    });
                }

                // 4. Observations
                foreach (var o in observations)
                {
                    var key = $"observation_{o.Id}";
                    int rating;
                    string notes;
                    bool isAudited = false;
                    bool isAi = false;

                    if (assessDict.TryGetValue(key, out var assess))
                    {
                        rating = assess.Rating;
                        notes = assess.Notes ?? "";
                        isAudited = true;
                    }
                    else
                    {
                        var desc = $"Kegiatan: {o.KegiatanYangDiamati} | Perihal: {o.PerihalYangDiamati} | Hasil: {o.HasilObservasi} | Keterangan: {o.Keterangan}";
                        var (r, n) = SapQualityMlEngine.AssessQuality("Observation", o.PerihalYangDiamati ?? "Observasi", desc);
                        rating = r;
                        notes = n;
                        isAi = true;
                    }

                    allItems.Add(new SapQualityItemDto
                    {
                        Id = o.Id,
                        ProgramType = "Observation",
                        Title = string.IsNullOrWhiteSpace(o.PerihalYangDiamati) ? "Observasi K3" : $"Observasi - {o.PerihalYangDiamati}",
                        Description = !string.IsNullOrWhiteSpace(o.Keterangan) ? o.Keterangan : (!string.IsNullOrWhiteSpace(o.KegiatanYangDiamati) ? o.KegiatanYangDiamati : "-"),
                        Tanggal = o.Date,
                        TanggalFormatted = o.Date.ToString("dd MMM yyyy"),
                        Lokasi = o.Lokasi,
                        Rating = rating,
                        QualityLabel = GetQualityLabelText(rating),
                        QualityColor = GetQualityColorCode(rating),
                        Notes = notes,
                        IsAuditedBySupervisor = isAudited,
                        IsAiAssessed = isAi,
                        PhotoUrl = o.FotoUrl
                    });
                }

                // 5. Coachings
                foreach (var c in coachings)
                {
                    var key = $"coaching_{c.Id}";
                    int rating;
                    string notes;
                    bool isAudited = false;
                    bool isAi = false;

                    if (assessDict.TryGetValue(key, out var assess))
                    {
                        rating = assess.Rating;
                        notes = assess.Notes ?? "";
                        isAudited = true;
                    }
                    else
                    {
                        var (r, n) = SapQualityMlEngine.AssessQuality("Coaching", c.Tema ?? "Coaching K3", c.Feedback ?? "");
                        rating = r;
                        notes = n;
                        isAi = true;
                    }

                    allItems.Add(new SapQualityItemDto
                    {
                        Id = c.Id,
                        ProgramType = "Coaching",
                        Title = string.IsNullOrWhiteSpace(c.Tema) ? "Coaching K3" : $"Coaching - {c.Tema}",
                        Description = !string.IsNullOrWhiteSpace(c.Feedback) ? c.Feedback : (!string.IsNullOrWhiteSpace(c.Komitmen) ? $"Komitmen: {c.Komitmen}" : "-"),
                        Tanggal = c.Tanggal,
                        TanggalFormatted = c.Tanggal.ToString("dd MMM yyyy"),
                        Lokasi = c.Lokasi,
                        Rating = rating,
                        QualityLabel = GetQualityLabelText(rating),
                        QualityColor = GetQualityColorCode(rating),
                        Notes = notes,
                        IsAuditedBySupervisor = isAudited,
                        IsAiAssessed = isAi,
                        PhotoUrl = c.Foto
                    });
                }

                // Order items by date descending
                var sortedItems = allItems.OrderByDescending(x => x.Tanggal).ToList();

                // Compute dashboard statistics
                int totalAllSap = sortedItems.Count;
                int totalAssessed = sortedItems.Count;
                int auditedBySupervisor = sortedItems.Count(x => x.IsAuditedBySupervisor);
                int kualitasBaik = sortedItems.Count(x => x.Rating >= 3);
                int kejarTarget = sortedItems.Count(x => x.Rating < 3);

                double goodPct = totalAssessed > 0 ? Math.Round((double)kualitasBaik / totalAssessed * 100.0, 1) : 0;
                double targetPct = totalAssessed > 0 ? Math.Round((double)kejarTarget / totalAssessed * 100.0, 1) : 0;
                double avgRating = totalAssessed > 0 ? Math.Round(sortedItems.Average(x => x.Rating), 2) : 0;
                double scorePercent = Math.Round((avgRating / 5.0) * 100.0, 1);

                int star5 = sortedItems.Count(x => x.Rating == 5);
                int star4 = sortedItems.Count(x => x.Rating == 4);
                int star3 = sortedItems.Count(x => x.Rating == 3);
                int star2 = sortedItems.Count(x => x.Rating == 2);
                int star1 = sortedItems.Count(x => x.Rating == 1);

                // Build module stats
                var moduleConfigs = new[]
                {
                    new { Key = "hazard", Name = "Hazard Report", ProgType = "Hazard", Theme = "#6366f1", Icon = "warning" },
                    new { Key = "inspection", Name = "Inspeksi K3", ProgType = "Inspection", Theme = "#3b82f6", Icon = "inspection" },
                    new { Key = "safetytalk", Name = "Safety Talk", ProgType = "SafetyTalk", Theme = "#f59e0b", Icon = "megaphone" },
                    new { Key = "observation", Name = "Observasi K3", ProgType = "Observation", Theme = "#14b8a6", Icon = "eye" },
                    new { Key = "coaching", Name = "Coaching K3", ProgType = "Coaching", Theme = "#d946ef", Icon = "user_check" }
                };

                var moduleStatsList = new List<SapQualityModuleStatDto>();
                foreach (var mc in moduleConfigs)
                {
                    var mItems = sortedItems.Where(x => string.Equals(x.ProgramType, mc.ProgType, StringComparison.OrdinalIgnoreCase)).ToList();
                    int mTotal = mItems.Count;
                    int mAssessed = mItems.Count;
                    double mAvg = mAssessed > 0 ? Math.Round(mItems.Average(x => x.Rating), 2) : 0.0;

                    moduleStatsList.Add(new SapQualityModuleStatDto
                    {
                        Key = mc.Key,
                        Name = mc.Name,
                        Total = mTotal,
                        Assessed = mAssessed,
                        AverageRating = mAvg,
                        ThemeColor = mc.Theme,
                        Icon = mc.Icon,
                        Star1 = mItems.Count(x => x.Rating == 1),
                        Star2 = mItems.Count(x => x.Rating == 2),
                        Star3 = mItems.Count(x => x.Rating == 3),
                        Star4 = mItems.Count(x => x.Rating == 4),
                        Star5 = mItems.Count(x => x.Rating == 5)
                    });
                }

                var response = new SapQualityDashboardResponseDto
                {
                    Nik = targetNik,
                    Nama = employeeName,
                    Departemen = employeeDept,
                    Perusahaan = employeeCompany,
                    SelectedYear = year,
                    SelectedMonth = month,
                    TotalAllSap = totalAllSap,
                    TotalAssessed = totalAssessed,
                    AuditedBySupervisorCount = auditedBySupervisor,
                    KualitasBaik = kualitasBaik,
                    KejarTarget = kejarTarget,
                    GoodPercentage = goodPct,
                    TargetPercentage = targetPct,
                    AverageRating = avgRating,
                    QualityScorePercent = scorePercent,
                    Star5 = star5,
                    Star4 = star4,
                    Star3 = star3,
                    Star2 = star2,
                    Star1 = star1,
                    ModuleStats = moduleStatsList,
                    Items = sortedItems
                };

                return Ok(response);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal memuat kualitas SAP: {ex.Message}" });
            }
        }

        private static string GetQualityLabelText(int rating)
        {
            return rating switch
            {
                5 => "Sangat Baik (⭐5)",
                4 => "Baik (⭐4)",
                3 => "Cukup (⭐3)",
                2 => "Kurang (⭐2)",
                1 => "Kejar Target (⭐1)",
                _ => "Belum Dinilai"
            };
        }

        private static string GetQualityColorCode(int rating)
        {
            return rating switch
            {
                5 => "#10b981", // Emerald green
                4 => "#34d399", // Light emerald
                3 => "#60a5fa", // Blue
                2 => "#f87171", // Rose
                1 => "#ef4444", // Red
                _ => "#94a3b8"  // Slate
            };
        }

        public class DepartmentSquadMemberDto
        {
            public int Rank { get; set; } // Peringkat internal di departemen (1..N)
            public int Pos { get; set; } // Peringkat global di liga perusahaan (misal Pos 20, 171, 187, 215, 237, 353)
            public int TotalPlayers { get; set; } // Total pemain di liga perusahaan (misal 453)
            public string Name { get; set; } = string.Empty;
            public string Nik { get; set; } = string.Empty;
            public string Jabatan { get; set; } = string.Empty;
            public string Department { get; set; } = string.Empty;
            public string CompanyName { get; set; } = string.Empty;
            public string Photo { get; set; } = string.Empty;
            public bool IsCurrentUser { get; set; }
            public int OnsiteDays { get; set; }
            public bool HasRoster { get; set; }
            public int TotalTarget { get; set; }
            public int TotalActual { get; set; } // Capped actual untuk perhitungan persentase capaian
            public int TotalActualAll { get; set; } // Total riil seluruh laporan safety yang dibuat (misal 8 Lap, 14 Lap)
            public double ComplianceRate { get; set; }
            public double CloseRate { get; set; }
            public double CrCreatorScore { get; set; }
            public double CrPicScore { get; set; }
            public double QualityScore { get; set; }
            public double ScaleBebanScore { get; set; }
            public int MaxTargetPlayer { get; set; }
            public double TotalScore { get; set; }
            public double PtsClose { get; set; }
            public double PtsKualitas { get; set; }
            public double PtsCapaian { get; set; }
            public double PtsBeban { get; set; }
            public List<string> FormDots { get; set; } = new();
            public ModuleActualTargetDto Hazard { get; set; } = new();
            public ModuleActualTargetDto Inspeksi { get; set; } = new();
            public ModuleActualTargetDto SafetyTalk { get; set; } = new();
            public ModuleActualTargetDto Observasi { get; set; } = new();
            public ModuleActualTargetDto Coaching { get; set; } = new();
            public ModuleActualTargetDto P5m { get; set; } = new();
        }

        public class ModuleActualTargetDto
        {
            public int Actual { get; set; }
            public int Target { get; set; }
        }

        private static bool IsClosedStatus(string? status)
        {
            if (string.IsNullOrWhiteSpace(status)) return false;
            var s = status.Trim().ToLowerInvariant();
            return s.Contains("close") || s.Contains("selesai") || s.Contains("tutup") || s.Contains("done");
        }

        /// <summary>
        /// GET /api/performance/department-squad
        /// GET /api/performance/department-employees
        /// Klasemen performa & peringkat kepatuhan karyawan internal di departemen yang login.
        /// Menggunakan formula standar Liga Web 4-Pillar PTS, Roster Scaling, Dual Accountability Close Rate, dan Form Dots 5 Program.
        /// </summary>
        [HttpGet("department-squad")]
        [HttpGet("department-employees")]
        public async Task<IActionResult> GetDepartmentSquad(
            [FromQuery] string? nik = null,
            [FromQuery] string? departmentName = null,
            [FromQuery] int? companyId = null,
            [FromQuery] int? month = null,
            [FromQuery] int? year = null)
        {
            try
            {
                int effectiveYear = year ?? DateTime.Today.Year;
                int effectiveMonth = month ?? DateTime.Today.Month;
                var startOfMonth = new DateTime(effectiveYear, effectiveMonth, 1);
                var endOfMonth = startOfMonth.AddMonths(1).AddTicks(-1);
                int totalDaysInMonth = DateTime.DaysInMonth(effectiveYear, effectiveMonth);
                string periodStr = startOfMonth.ToString("MMMM yyyy", new CultureInfo("id-ID"));

                string userNik = (nik ?? string.Empty).Trim();
                int effectiveCompanyId = companyId ?? 1;
                string resolvedDeptName = (departmentName ?? string.Empty).Trim();

                if (!string.IsNullOrEmpty(userNik))
                {
                    var userKaryawan = await _context.Karyawans.AsNoTracking()
                        .FirstOrDefaultAsync(k => k.NoNik == userNik);

                    if (userKaryawan != null)
                    {
                        if (!companyId.HasValue && userKaryawan.IdPerusahaan > 0)
                        {
                            effectiveCompanyId = userKaryawan.IdPerusahaan;
                        }

                        if (string.IsNullOrEmpty(resolvedDeptName) && userKaryawan.IdDepartemen.HasValue)
                        {
                            var dept = await _context.Departemens.AsNoTracking()
                                .FirstOrDefaultAsync(d => d.DepartemenId == userKaryawan.IdDepartemen.Value);
                            if (dept != null && !string.IsNullOrWhiteSpace(dept.NamaDepartemen))
                            {
                                resolvedDeptName = dept.NamaDepartemen.Trim();
                            }
                        }
                    }
                }

                if (string.IsNullOrWhiteSpace(resolvedDeptName))
                {
                    resolvedDeptName = "SYSTEM INTEGRATIONS";
                }

                string companyName = "PT INDEXIM COALINDO";
                var comp = await _context.Perusahaans.AsNoTracking()
                    .FirstOrDefaultAsync(p => p.PerusahaanId == effectiveCompanyId);
                if (comp != null && !string.IsNullOrWhiteSpace(comp.NamaPerusahaan))
                {
                    companyName = comp.NamaPerusahaan.Trim();
                }

                // 1. Ambil seluruh karyawan aktif di perusahaan untuk menentukan posisi liga global (Pos 1..N)
                var companyEmployees = await (from k in _context.Karyawans.AsNoTracking()
                                              join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal into pGroup
                                              from p in pGroup.DefaultIfEmpty()
                                              join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jGroup
                                              from j in jGroup.DefaultIfEmpty()
                                              join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dGroup
                                              from d in dGroup.DefaultIfEmpty()
                                              where k.StatusAktif == true &&
                                                    k.IdPerusahaan == effectiveCompanyId &&
                                                    (k.TanggalMasuk == null || k.TanggalMasuk <= endOfMonth)
                                              select new
                                              {
                                                  k.IdKaryawan,
                                                  NoNik = k.NoNik.Trim(),
                                                  k.TanggalMasuk,
                                                  Name = p != null ? p.NamaLengkap : k.NoNik,
                                                  Jabatan = j != null ? j.NamaJabatan : "Staff",
                                                  Department = d != null ? d.NamaDepartemen : "General",
                                                  k.PathFoto
                                              }).ToListAsync();

                // 2. Target mapping dari view KaryawanJabatanMappings
                var mappings = await _context.KaryawanJabatanMappings.AsNoTracking()
                    .Where(m => m.PerusahaanId == effectiveCompanyId)
                    .ToDictionaryAsync(m => m.KaryawanId);

                // 3. Roster karyawan
                var rosters = await _context.Rosters.AsNoTracking()
                    .Where(r => r.AwalDinas <= endOfMonth && (r.AkhirCuti >= startOfMonth || r.AkhirDinas >= startOfMonth))
                    .ToListAsync();
                var rostersByNik = rosters
                    .GroupBy(r => r.Nik.Trim(), StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(g => g.Key, g => g.ToList(), StringComparer.OrdinalIgnoreCase);

                // 4. Hitung actual MTD seluruh modul
                var hazards = await _context.HazardReports.AsNoTracking()
                    .Where(h => !h.IsDeleted && h.Tanggal >= startOfMonth && h.Tanggal <= endOfMonth && h.Nik != null)
                    .Select(h => new { Nik = h.Nik.Trim(), h.Tanggal, h.Waktu, h.Lokasi })
                    .Distinct()
                    .GroupBy(h => h.Nik)
                    .Select(g => new { Nik = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

                var inspections = await _context.Inspections.AsNoTracking()
                    .Where(i => !i.IsDeleted && i.Tanggal >= startOfMonth && i.Tanggal <= endOfMonth && i.Nik != null)
                    .Select(i => new { Nik = i.Nik.Trim(), i.Tanggal, i.Waktu })
                    .Distinct()
                    .GroupBy(i => i.Nik)
                    .Select(g => new { Nik = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

                var safetyTalks = await _context.SafetyTalks.AsNoTracking()
                    .Where(s => !s.IsDeleted && s.Tanggal >= startOfMonth && s.Tanggal <= endOfMonth && s.Nik != null)
                    .Select(s => new { Nik = s.Nik.Trim(), s.Tanggal, s.Waktu })
                    .Distinct()
                    .GroupBy(s => s.Nik)
                    .Select(g => new { Nik = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

                var observations = await _context.Observations.AsNoTracking()
                    .Where(o => !o.IsDeleted && o.CreatedAt >= startOfMonth && o.CreatedAt <= endOfMonth && o.Nik != null)
                    .Select(o => new { Nik = o.Nik.Trim(), o.Date, o.KegiatanYangDiamati })
                    .Distinct()
                    .GroupBy(o => o.Nik)
                    .Select(g => new { Nik = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

                var coachingCreators = await _context.Coachings.AsNoTracking()
                    .Where(c => !c.IsDeleted && c.CreatedAt >= startOfMonth && c.CreatedAt <= endOfMonth && c.Nik != null)
                    .Select(c => c.Nik.Trim())
                    .ToListAsync();
                var coachingParticipants = await _context.CoachingParticipants.AsNoTracking()
                    .Where(cp => cp.Coaching != null && !cp.Coaching.IsDeleted && cp.Coaching.CreatedAt >= startOfMonth && cp.Coaching.CreatedAt <= endOfMonth && cp.Nik != null)
                    .Select(cp => cp.Nik.Trim())
                    .ToListAsync();
                var coachings = coachingCreators.Concat(coachingParticipants)
                    .GroupBy(n => n, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

                var p5ms = await _context.P5ms.AsNoTracking()
                    .Where(p => !p.IsDeleted && p.CreatedAt >= startOfMonth && p.CreatedAt <= endOfMonth && p.Nik != null)
                    .Select(p => new { Nik = p.Nik.Trim(), p.Tanggal, p.Waktu })
                    .Distinct()
                    .GroupBy(p => p.Nik)
                    .Select(g => new { Nik = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.Nik, x => x.Count, StringComparer.OrdinalIgnoreCase);

                var actionPlans = await _context.ActionPlans.AsNoTracking()
                    .Where(a => !a.IsDeleted && (
                        (a.Tanggal >= startOfMonth && a.Tanggal <= endOfMonth) ||
                        (a.CreatedAt >= startOfMonth && a.CreatedAt <= endOfMonth)
                    ))
                    .Select(a => new {
                        Nik = a.Nik != null ? a.Nik.Trim() : "",
                        NikPic = a.NikPic != null ? a.NikPic.Trim() : "",
                        NikPja = a.NikPja != null ? a.NikPja.Trim() : "",
                        a.Status
                    })
                    .ToListAsync();

                var creatorAps = actionPlans
                    .Where(a => !string.IsNullOrEmpty(a.Nik))
                    .GroupBy(a => a.Nik, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(g => g.Key, g => g.ToList(), StringComparer.OrdinalIgnoreCase);

                var assignedAps = new Dictionary<string, List<string?>>(StringComparer.OrdinalIgnoreCase);
                foreach (var ap in actionPlans)
                {
                    if (!string.IsNullOrEmpty(ap.NikPic))
                    {
                        if (!assignedAps.TryGetValue(ap.NikPic, out var list))
                        {
                            list = new List<string?>();
                            assignedAps[ap.NikPic] = list;
                        }
                        list.Add(ap.Status);
                    }
                    if (!string.IsNullOrEmpty(ap.NikPja) && !string.Equals(ap.NikPja, ap.NikPic, StringComparison.OrdinalIgnoreCase))
                    {
                        if (!assignedAps.TryGetValue(ap.NikPja, out var list))
                        {
                            list = new List<string?>();
                            assignedAps[ap.NikPja] = list;
                        }
                        list.Add(ap.Status);
                    }
                }

                // Skor mutu kualitas
                var qualityScoresByNik = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
                try
                {
                    var conn = _context.Database.GetDbConnection();
                    if (conn.State != System.Data.ConnectionState.Open) await conn.OpenAsync();
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        WITH AllRatedReports AS (
                            SELECT LTRIM(RTRIM(h.nik)) AS nik, q.rating
                            FROM tbl_t_hazard_report h WITH (NOLOCK)
                            JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Hazard' AND q.program_id = h.id
                            WHERE h.is_deleted = 0 AND h.tanggal >= @start AND h.tanggal <= @end
                            UNION ALL
                            SELECT LTRIM(RTRIM(i.nik)) AS nik, q.rating
                            FROM tbl_t_inspection i WITH (NOLOCK)
                            JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Inspection' AND q.program_id = i.id
                            WHERE i.is_deleted = 0 AND i.tanggal >= @start AND i.tanggal <= @end
                            UNION ALL
                            SELECT LTRIM(RTRIM(s.nik)) AS nik, q.rating
                            FROM tbl_t_safety_talk s WITH (NOLOCK)
                            JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'SafetyTalk' AND q.program_id = s.id
                            WHERE s.is_deleted = 0 AND s.tanggal >= @start AND s.tanggal <= @end
                            UNION ALL
                            SELECT LTRIM(RTRIM(o.nik)) AS nik, q.rating
                            FROM tbl_t_observation o WITH (NOLOCK)
                            JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Observation' AND q.program_id = o.id
                            WHERE o.is_deleted = 0 AND o.date >= @start AND o.date <= @end
                            UNION ALL
                            SELECT LTRIM(RTRIM(c.nik)) AS nik, q.rating
                            FROM tbl_t_coaching c WITH (NOLOCK)
                            JOIN tbl_m_penilaian_kualitas_sap q WITH (NOLOCK) ON q.program_type = 'Coaching' AND q.program_id = c.id
                            WHERE c.is_deleted = 0 AND c.tanggal >= @start AND c.tanggal <= @end
                        )
                        SELECT nik, COUNT(*) AS TotalRated, AVG(CAST(rating AS FLOAT)) AS AvgRating
                        FROM AllRatedReports
                        WHERE nik IS NOT NULL AND nik <> ''
                        GROUP BY nik;";

                    var pStart = cmd.CreateParameter();
                    pStart.ParameterName = "@start";
                    pStart.Value = startOfMonth;
                    cmd.Parameters.Add(pStart);

                    var pEnd = cmd.CreateParameter();
                    pEnd.ParameterName = "@end";
                    pEnd.Value = endOfMonth;
                    cmd.Parameters.Add(pEnd);

                    using var reader = await cmd.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        string eNik = reader.GetString(0).Trim();
                        double avgRating = reader.GetDouble(2);
                        qualityScoresByNik[eNik] = Math.Min(100.0, Math.Max(0.0, Math.Round((avgRating / 5.0) * 100.0, 1)));
                    }
                }
                catch { }

                // 5. Kalkulasi target dan capaian untuk setiap karyawan
                static int ScaleTarget(int baseTarget, double ratio, int onsiteDays)
                {
                    if (baseTarget == 0 || onsiteDays == 0) return 0;
                    int scaled = (int)Math.Round(baseTarget * Math.Min(1.0, ratio), MidpointRounding.AwayFromZero);
                    return Math.Min(baseTarget, Math.Max(scaled, 1));
                }

                var allTargetPlayers = new List<DepartmentSquadMemberDto>();

                foreach (var emp in companyEmployees)
                {
                    string eNik = emp.NoNik.Trim();
                    if (!mappings.TryGetValue(emp.IdKaryawan, out var m) || m == null) continue;

                    int hBase = m.TargetHazardReport ?? 2;
                    int iBase = m.TargetInspeksi ?? 1;
                    int stBase = m.TargetSafetyTalk ?? 1;
                    int oBase = m.TargetObservasi ?? 0;
                    int cBase = m.TargetCoaching ?? 0;
                    int p5mBase = 1;

                    bool isTargetSap = (hBase + iBase + stBase + oBase + cBase > 0);
                    if (!isTargetSap) continue;

                    int onsiteDays = totalDaysInMonth;
                    bool hasRoster = false;
                    DateTime effStart = (emp.TanggalMasuk.HasValue && emp.TanggalMasuk.Value > startOfMonth)
                        ? emp.TanggalMasuk.Value
                        : startOfMonth;

                    if (rostersByNik.TryGetValue(eNik, out var empRosters) && empRosters.Count > 0)
                    {
                        hasRoster = true;
                        int computedOnsite = 0;
                        for (var cur = effStart.Date; cur <= endOfMonth.Date; cur = cur.AddDays(1))
                        {
                            bool isTugas = empRosters.Any(r => r.TipeRoster == "TUGAS" && r.AwalDinas.Date <= cur && cur <= r.AkhirDinas.Date);
                            if (!isTugas)
                            {
                                bool isDinas = empRosters.Any(r => r.TipeRoster != "TUGAS" && r.AwalDinas.Date <= cur && cur <= r.AkhirDinas.Date);
                                if (isDinas) computedOnsite++;
                            }
                        }
                        onsiteDays = Math.Min(computedOnsite, totalDaysInMonth);
                    }
                    else if (effStart > startOfMonth)
                    {
                        hasRoster = true;
                        onsiteDays = Math.Min((endOfMonth.Date - effStart.Date).Days + 1, totalDaysInMonth);
                    }

                    double ratio = hasRoster ? Math.Min(1.0, (double)onsiteDays / totalDaysInMonth) : 1.0;

                    int tgtH = hasRoster ? ScaleTarget(hBase, ratio, onsiteDays) : hBase;
                    int tgtI = hasRoster ? ScaleTarget(iBase, ratio, onsiteDays) : iBase;
                    int tgtSt = hasRoster ? ScaleTarget(stBase, ratio, onsiteDays) : stBase;
                    int tgtO = hasRoster ? ScaleTarget(oBase, ratio, onsiteDays) : oBase;
                    int tgtC = hasRoster ? ScaleTarget(cBase, ratio, onsiteDays) : cBase;
                    int tgtP5m = p5mBase;

                    int totalTarget = tgtH + tgtI + tgtSt + tgtO + tgtC;

                    int actH = hazards.TryGetValue(eNik, out int hC) ? hC : 0;
                    int actI = inspections.TryGetValue(eNik, out int iC) ? iC : 0;
                    int actSt = safetyTalks.TryGetValue(eNik, out int stC) ? stC : 0;
                    int actO = observations.TryGetValue(eNik, out int oC) ? oC : 0;
                    int actC = coachings.TryGetValue(eNik, out int cC) ? cC : 0;
                    int actP5m = p5ms.TryGetValue(eNik, out int pC) ? pC : 0;

                    int cappedAct = Math.Min(actH, tgtH) + Math.Min(actI, tgtI) + Math.Min(actSt, tgtSt) + Math.Min(actO, tgtO) + Math.Min(actC, tgtC);
                    int totalActualAll = actH + actI + actSt + actO + actC + actP5m;

                    double compliance = totalTarget > 0 ? Math.Min(100.0, Math.Round((double)cappedAct / totalTarget * 100.0, 1)) : 0.0;

                    double crCreator = 100.0;
                    if (creatorAps.TryGetValue(eNik, out var cList) && cList.Count > 0)
                    {
                        int cl = cList.Count(a => IsClosedStatus(a.Status));
                        crCreator = Math.Min(100.0, Math.Max(0.0, Math.Round(((double)cl / cList.Count) * 100.0, 1)));
                    }

                    double crPic = 100.0;
                    if (assignedAps.TryGetValue(eNik, out var aList) && aList.Count > 0)
                    {
                        int cl = aList.Count(s => IsClosedStatus(s));
                        crPic = Math.Min(100.0, Math.Max(0.0, Math.Round(((double)cl / aList.Count) * 100.0, 1)));
                    }

                    double closeRate;
                    bool hasCreator = creatorAps.ContainsKey(eNik);
                    bool hasAssigned = assignedAps.ContainsKey(eNik);
                    if (hasCreator || hasAssigned)
                    {
                        closeRate = Math.Round((crCreator * 0.50) + (crPic * 0.50), 1);
                    }
                    else
                    {
                        closeRate = 100.0;
                    }

                    double qualityScore = qualityScoresByNik.TryGetValue(eNik, out double qVal)
                        ? qVal
                        : (totalActualAll > 0 ? 100.0 : 0.0);

                    static string GetFormDot(int act, int tgt)
                    {
                        if (tgt == 0) return act > 0 ? "W" : "-";
                        double r = ((double)act / tgt) * 100.0;
                        if (r >= 80.0) return "W";
                        if (r >= 40.0) return "D";
                        return "L";
                    }

                    var formDots = new List<string>
                    {
                        GetFormDot(actH, tgtH),
                        GetFormDot(actI, tgtI),
                        GetFormDot(actSt, tgtSt),
                        GetFormDot(actO, tgtO),
                        GetFormDot(actC, tgtC)
                    };

                    allTargetPlayers.Add(new DepartmentSquadMemberDto
                    {
                        Name = emp.Name,
                        Nik = eNik,
                        Jabatan = !string.IsNullOrEmpty(m.NamaJabatanExisting) ? m.NamaJabatanExisting : emp.Jabatan,
                        Department = emp.Department,
                        CompanyName = companyName,
                        Photo = emp.PathFoto ?? string.Empty,
                        IsCurrentUser = (!string.IsNullOrEmpty(userNik) && string.Equals(eNik, userNik, StringComparison.OrdinalIgnoreCase)),
                        OnsiteDays = onsiteDays,
                        HasRoster = hasRoster,
                        TotalTarget = totalTarget,
                        TotalActual = cappedAct,
                        TotalActualAll = totalActualAll,
                        ComplianceRate = compliance,
                        CloseRate = closeRate,
                        CrCreatorScore = crCreator,
                        CrPicScore = crPic,
                        QualityScore = qualityScore,
                        FormDots = formDots,
                        Hazard = new ModuleActualTargetDto { Actual = actH, Target = tgtH },
                        Inspeksi = new ModuleActualTargetDto { Actual = actI, Target = tgtI },
                        SafetyTalk = new ModuleActualTargetDto { Actual = actSt, Target = tgtSt },
                        Observasi = new ModuleActualTargetDto { Actual = actO, Target = tgtO },
                        Coaching = new ModuleActualTargetDto { Actual = actC, Target = tgtC },
                        P5m = new ModuleActualTargetDto { Actual = actP5m, Target = tgtP5m }
                    });
                }

                int maxTargetComp = allTargetPlayers.Any() ? allTargetPlayers.Max(e => e.TotalTarget) : 1;
                if (maxTargetComp <= 0) maxTargetComp = 1;

                foreach (var p in allTargetPlayers)
                {
                    double scoreClose = Math.Min(100.0, Math.Max(0.0, p.CloseRate));
                    double scoreCapaian = Math.Min(100.0, Math.Max(0.0, p.ComplianceRate));
                    double scoreBeban = Math.Min(100.0, Math.Max(0.0, ((double)p.TotalTarget / maxTargetComp) * 100.0));

                    double ptsClose = Math.Round(scoreClose * 0.30, 2);
                    double ptsKualitas = Math.Round(p.QualityScore * 0.25, 2);
                    double ptsCapaian = Math.Round(scoreCapaian * 0.35, 2);
                    double ptsBeban = Math.Round(scoreBeban * 0.10, 2);
                    double totalScore = Math.Round(ptsClose + ptsKualitas + ptsCapaian + ptsBeban, 2);

                    p.ScaleBebanScore = Math.Round(scoreBeban, 1);
                    p.MaxTargetPlayer = maxTargetComp;
                    p.PtsClose = ptsClose;
                    p.PtsKualitas = ptsKualitas;
                    p.PtsCapaian = ptsCapaian;
                    p.PtsBeban = ptsBeban;
                    p.TotalScore = totalScore;
                    p.TotalPlayers = allTargetPlayers.Count;
                }

                // 6. Urutkan seluruh pemain di liga perusahaan persis sesuai logika tie-breaker web
                var sortedLeague = allTargetPlayers
                    .OrderBy(e => (e.TotalTarget == 0 && e.TotalActualAll == 0) ? 1 : 0)
                    .ThenByDescending(e => e.ComplianceRate >= 100.0 ? 1 : 0) // Syarat Mutlak Juara/Podium (Capaian 100% / All Green W)
                    .ThenByDescending(e => e.TotalScore)
                    .ThenByDescending(e => e.TotalActualAll) // Nilai tambah laporan safety riil
                    .ThenByDescending(e => e.ComplianceRate)
                    .ThenByDescending(e => e.CloseRate)
                    .ThenByDescending(e => (e.Hazard.Actual + e.Inspeksi.Actual + e.SafetyTalk.Actual + e.Observasi.Actual + e.Coaching.Actual + e.P5m.Actual))
                    .ToList();

                for (int i = 0; i < sortedLeague.Count; i++)
                {
                    sortedLeague[i].Pos = i + 1;
                }

                // 7. Ambil skuad departemen terkait (diurutkan berdasarkan peringkat terbaiknya di liga)
                var deptSquad = sortedLeague
                    .Where(p => string.Equals(p.Department.Trim(), resolvedDeptName.Trim(), StringComparison.OrdinalIgnoreCase))
                    .ToList();

                for (int i = 0; i < deptSquad.Count; i++)
                {
                    deptSquad[i].Rank = i + 1;
                }

                int userRank = 0;
                int userPos = 0;
                var currentMember = deptSquad.FirstOrDefault(m => m.IsCurrentUser) ?? sortedLeague.FirstOrDefault(m => m.IsCurrentUser);
                if (currentMember != null)
                {
                    userRank = currentMember.Rank;
                    userPos = currentMember.Pos;
                }

                var podium = deptSquad.Take(3).ToList();

                return Ok(new
                {
                    status = true,
                    message = "Berhasil memuat klasemen performa karyawan departemen",
                    data = new
                    {
                        companyId = effectiveCompanyId,
                        companyName,
                        departmentName = resolvedDeptName,
                        period = periodStr,
                        userNik,
                        userRank,
                        userPos,
                        totalLeaguePlayers = sortedLeague.Count,
                        totalEmployees = deptSquad.Count,
                        podium,
                        standings = deptSquad
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = $"Gagal memuat klasemen karyawan: {ex.Message}" });
            }
        }

        /// <summary>
        /// GET /api/performance/action-tracker
        /// Action Tracker Temuan K3LH yang 100% identik dengan Web /ActionPlan/Index.
        /// Mendukung 3 KPI cards (Outstanding, In Progress, Closed), filter Penugasan (Saya, Dibuat Saya, Dept Saya, Dibuat Dept),
        /// filter Status (Outstanding, In Progress, Closed), Tipe, Due Date SLA & AI Hazard Analysis.
        /// </summary>
        [HttpGet("action-tracker")]
        public async Task<IActionResult> GetActionTracker(
            [FromQuery] string? nik = null,
            [FromQuery] string? filter = null, // "all", "assigned" (Saya), "created" (Dibuat Saya), "dept_assigned" (Departemen Saya), "dept_created" (Dibuat Dept)
            [FromQuery] string? status = null, // "all", "outstanding", "progress", "closed"
            [FromQuery] string? type = null, // "all", "hazard", "inspection"
            [FromQuery] string? search = null,
            [FromQuery] string? startDate = null,
            [FromQuery] string? endDate = null,
            [FromQuery] int limit = 200)
        {
            try
            {
                var targetNik = !string.IsNullOrWhiteSpace(nik)
                    ? nik.Trim()
                    : (User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? User.Identity?.Name ?? "");

                string userDept = "";
                int? userCompanyId = null;
                string userName = targetNik;

                if (!string.IsNullOrEmpty(targetNik))
                {
                    var userKaryawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == targetNik);
                    if (userKaryawan != null)
                    {
                        userCompanyId = userKaryawan.IdPerusahaan > 0 ? userKaryawan.IdPerusahaan : (int?)null;
                        if (userKaryawan.IdDepartemen.HasValue)
                        {
                            var dept = await _context.Departemens.AsNoTracking().FirstOrDefaultAsync(d => d.DepartemenId == userKaryawan.IdDepartemen.Value);
                            if (dept != null) userDept = dept.NamaDepartemen ?? "";
                        }
                        var p = await _context.Personals.AsNoTracking().FirstOrDefaultAsync(x => x.IdPersonal == userKaryawan.IdPersonal);
                        if (p != null) userName = p.NamaLengkap;
                    }
                }

                // Company hierarchy filter
                List<int>? allowedCompanyIds = null;
                if (userCompanyId.HasValue)
                {
                    allowedCompanyIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(userCompanyId.Value);
                }

                var baseQuery = _context.ActionPlans.AsNoTracking().Where(a => !a.IsDeleted);

                // Filter ketat sesuai instruksi: Hanya yang ditujukan ke saya, dibuat oleh saya,
                // dituju ke departemen saya, atau diarahkan/dibuat oleh departemen saya.
                if (!string.IsNullOrEmpty(targetNik) || !string.IsNullOrEmpty(userDept))
                {
                    baseQuery = baseQuery.Where(r =>
                        (!string.IsNullOrEmpty(targetNik) && (r.Nik == targetNik || r.NikPja == targetNik || r.NikPic == targetNik)) ||
                        (!string.IsNullOrEmpty(userDept) && (
                            r.Departemen == userDept || 
                            r.DepartemenPja == userDept || 
                            r.DepartemenPic == userDept
                        ))
                    );
                }
                else if (allowedCompanyIds != null && allowedCompanyIds.Any())
                {
                    baseQuery = baseQuery.Where(r => r.PerusahaanId.HasValue && allowedCompanyIds.Contains(r.PerusahaanId.Value));
                }

                // Date filtering if provided
                if (!string.IsNullOrEmpty(startDate) && DateTime.TryParse(startDate, out var dtStart))
                {
                    baseQuery = baseQuery.Where(r => r.Tanggal >= dtStart.Date);
                }
                if (!string.IsNullOrEmpty(endDate) && DateTime.TryParse(endDate, out var dtEnd))
                {
                    var dtEndOfDay = dtEnd.Date.AddDays(1).AddTicks(-1);
                    baseQuery = baseQuery.Where(r => r.Tanggal <= dtEndOfDay);
                }

                // Retrieve items for summary calculations
                var allItems = await baseQuery
                    .OrderByDescending(r => r.Status == "Open" || r.Status == "0")
                    .ThenByDescending(r => r.Tanggal)
                    .ThenByDescending(r => r.CreatedAt)
                    .Take(Math.Max(limit, 300))
                    .ToListAsync();

                // Compute Summary KPI Cards (Identical to Web ActionPlan/Index.cshtml)
                int countOutstanding = allItems.Count(r => (string.Equals(r.Status, "Open", StringComparison.OrdinalIgnoreCase) || r.Status == "0") && string.IsNullOrEmpty(r.RencanaPerbaikan));
                int countProgress = allItems.Count(r => (string.Equals(r.Status, "Open", StringComparison.OrdinalIgnoreCase) || r.Status == "0") && !string.IsNullOrEmpty(r.RencanaPerbaikan));
                int countClosed = allItems.Count(r => string.Equals(r.Status, "Closed", StringComparison.OrdinalIgnoreCase) || r.Status == "2");

                // Apply Filters
                var filtered = allItems.AsEnumerable();

                // 1. Penugasan / Ownership Filter
                // Web has: all, assigned (Saya), created (Dibuat Saya), dept_assigned (Departemen Saya), dept_created (Dibuat Dept)
                var normFilter = (filter ?? "all").Trim().ToLowerInvariant();
                if (normFilter == "assigned" || normFilter == "saya")
                {
                    filtered = filtered.Where(r => r.NikPja == targetNik || r.NikPic == targetNik);
                }
                else if (normFilter == "created" || normFilter == "dibuat_saya" || normFilter == "dibuat")
                {
                    filtered = filtered.Where(r => r.Nik == targetNik);
                }
                else if (normFilter == "dept_assigned" || normFilter == "departemen_saya" || normFilter == "dept")
                {
                    if (!string.IsNullOrEmpty(userDept))
                    {
                        filtered = filtered.Where(r => string.Equals(r.DepartemenPja?.Trim(), userDept.Trim(), StringComparison.OrdinalIgnoreCase) || string.Equals(r.DepartemenPic?.Trim(), userDept.Trim(), StringComparison.OrdinalIgnoreCase));
                    }
                }
                else if (normFilter == "dept_created" || normFilter == "dibuat_dept")
                {
                    if (!string.IsNullOrEmpty(userDept))
                    {
                        filtered = filtered.Where(r => string.Equals(r.Departemen?.Trim(), userDept.Trim(), StringComparison.OrdinalIgnoreCase));
                    }
                }

                // 2. Status Filter
                var normStatus = (status ?? "all").Trim().ToLowerInvariant();
                if (normStatus == "outstanding")
                {
                    filtered = filtered.Where(r => (string.Equals(r.Status, "Open", StringComparison.OrdinalIgnoreCase) || r.Status == "0") && string.IsNullOrEmpty(r.RencanaPerbaikan));
                }
                else if (normStatus == "progress" || normStatus == "in_progress")
                {
                    filtered = filtered.Where(r => (string.Equals(r.Status, "Open", StringComparison.OrdinalIgnoreCase) || r.Status == "0") && !string.IsNullOrEmpty(r.RencanaPerbaikan));
                }
                else if (normStatus == "closed")
                {
                    filtered = filtered.Where(r => string.Equals(r.Status, "Closed", StringComparison.OrdinalIgnoreCase) || r.Status == "2");
                }
                else if (normStatus == "open")
                {
                    filtered = filtered.Where(r => string.Equals(r.Status, "Open", StringComparison.OrdinalIgnoreCase) || r.Status == "0");
                }

                // 3. Tipe Filter
                var normType = (type ?? "all").Trim().ToLowerInvariant();
                if (normType == "hazard")
                {
                    filtered = filtered.Where(r => r.ItemSap == null || r.ItemSap.ToLower().StartsWith("hazard"));
                }
                else if (normType == "inspection" || normType == "inspeksi")
                {
                    filtered = filtered.Where(r => r.ItemSap != null && r.ItemSap.ToLower().StartsWith("inspection"));
                }

                // 4. Search Filter
                if (!string.IsNullOrWhiteSpace(search))
                {
                    var s = search.Trim().ToLowerInvariant();
                    filtered = filtered.Where(r =>
                        (r.KategoriTemuan != null && r.KategoriTemuan.ToLower().Contains(s)) ||
                        (r.DetilTemuan != null && r.DetilTemuan.ToLower().Contains(s)) ||
                        (r.Lokasi != null && r.Lokasi.ToLower().Contains(s)) ||
                        (r.Nama != null && r.Nama.ToLower().Contains(s)) ||
                        (r.Nik != null && r.Nik.ToLower().Contains(s)) ||
                        (r.Pja != null && r.Pja.ToLower().Contains(s)) ||
                        (r.Pic != null && r.Pic.ToLower().Contains(s))
                    );
                }

                var filteredList = filtered.Take(limit).ToList();

                // Look up companies for Pelapor, PJA, PIC
                var allNiks = filteredList.Select(r => r.Nik)
                    .Concat(filteredList.Where(r => !string.IsNullOrEmpty(r.NikPja)).Select(r => r.NikPja!))
                    .Concat(filteredList.Where(r => !string.IsNullOrEmpty(r.NikPic)).Select(r => r.NikPic!))
                    .Distinct()
                    .ToList();

                var nikCompanyList = await (from k in _context.Karyawans.AsNoTracking()
                                            join p in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals p.PerusahaanId
                                            where allNiks.Contains(k.NoNik)
                                            select new { k.NoNik, k.StatusAktif, p.NamaPerusahaan })
                                            .ToListAsync();

                var nikCompanyMap = nikCompanyList
                    .OrderByDescending(x => x.StatusAktif)
                    .GroupBy(x => x.NoNik)
                    .ToDictionary(g => g.Key, g => g.First().NamaPerusahaan);

                // Look up TingkatResiko from HazardReports
                var hazardIds = filteredList.Where(r => r.ItemSap != null && r.ItemSap.StartsWith("hazard:"))
                    .Select(r => { int.TryParse(r.ItemSap!.Substring(7), out int id); return id; })
                    .Where(id => id > 0).Distinct().ToList();

                var hazardsRiskMap = await _context.HazardReports.AsNoTracking()
                    .Where(h => hazardIds.Contains(h.Id))
                    .ToDictionaryAsync(h => h.Id, h => h.TingkatResiko);

                var itemsDto = new List<object>();

                foreach (var item in filteredList)
                {
                    var isOpen = string.Equals(item.Status, "Open", StringComparison.OrdinalIgnoreCase) || item.Status == "0";
                    var isProgress = isOpen && !string.IsNullOrEmpty(item.RencanaPerbaikan);
                    var isOutstanding = isOpen && string.IsNullOrEmpty(item.RencanaPerbaikan);
                    var isClosed = !isOpen;

                    var displayType = "HAZARD";
                    if (!string.IsNullOrEmpty(item.ItemSap))
                    {
                        var splitted = item.ItemSap.Split(':');
                        displayType = splitted[0].ToUpperInvariant();
                        if (displayType == "INSPECTION") displayType = "INSPEKSI";
                    }

                    string risk = item.TingkatResiko ?? "Sedang";
                    if (item.ItemSap != null && item.ItemSap.StartsWith("hazard:") && int.TryParse(item.ItemSap.Substring(7), out int hId) && hazardsRiskMap.ContainsKey(hId))
                    {
                        risk = hazardsRiskMap[hId] ?? risk;
                    }

                    var ai = SapQualityMlEngine.AnalyzeHazard(
                        item.DetilTemuan,
                        item.KategoriTemuan,
                        item.ItemSap,
                        risk,
                        item.Lokasi,
                        item.DetilLokasi,
                        item.RencanaPerbaikan ?? item.Perbaikan,
                        item.Status,
                        item.Tanggal
                    );

                    // Ownership Direction Badge
                    bool isOutbound = (item.Nik == targetNik) || (!string.IsNullOrEmpty(userDept) && string.Equals(item.Departemen?.Trim(), userDept.Trim(), StringComparison.OrdinalIgnoreCase));
                    bool isInbound = (item.NikPja == targetNik || item.NikPic == targetNik) || (!string.IsNullOrEmpty(userDept) && (string.Equals(item.DepartemenPja?.Trim(), userDept.Trim(), StringComparison.OrdinalIgnoreCase) || string.Equals(item.DepartemenPic?.Trim(), userDept.Trim(), StringComparison.OrdinalIgnoreCase)));

                    string directionBadge = "UMUM";
                    string directionType = "general";
                    if (isOutbound && isInbound)
                    {
                        directionBadge = "MASUK & KELUAR";
                        directionType = "both";
                    }
                    else if (isInbound)
                    {
                        directionBadge = "LAP. MASUK";
                        directionType = "inbound";
                    }
                    else if (isOutbound)
                    {
                        directionBadge = "LAP. KELUAR";
                        directionType = "outbound";
                    }

                    string statusKey = isClosed ? "closed" : (isProgress ? "progress" : "outstanding");
                    string statusBadge = isClosed ? "CLOSED" : (isProgress ? "IN PROGRESS" : "OUTSTANDING");

                    nikCompanyMap.TryGetValue(item.Nik, out var compPelapor);
                    string? compPja = null;
                    if (!string.IsNullOrEmpty(item.NikPja)) nikCompanyMap.TryGetValue(item.NikPja, out compPja);
                    string? compPic = null;
                    if (!string.IsNullOrEmpty(item.NikPic)) nikCompanyMap.TryGetValue(item.NikPic, out compPic);

                    bool isReassigned = !string.IsNullOrEmpty(item.ReassignedFrom) && !string.IsNullOrEmpty(item.ReassignedTo);

                    itemsDto.Add(new
                    {
                        id = item.Id,
                        itemSap = item.ItemSap ?? "hazard",
                        displayType,
                        kategoriTemuan = item.KategoriTemuan ?? "Temuan K3",
                        detilTemuan = item.DetilTemuan ?? "-",
                        status = item.Status,
                        statusKey,
                        statusBadge,
                        tingkatResiko = risk,
                        lokasi = item.Lokasi ?? item.Area ?? "General Area",
                        area = item.Area ?? "",
                        detilLokasi = item.DetilLokasi ?? "",
                        tanggal = item.Tanggal,
                        tanggalFormatted = item.Tanggal.ToString("dd MMM yyyy"),

                        directionBadge,
                        directionType,

                        // Due Date & SLA
                        calculatedDueDate = ai.RecommendedDeadline,
                        dueDateDisplay = ai.DueDateFormatted,
                        dueDateStatus = ai.DueDateStatus,
                        dueDateStatusColor = ai.DueDateStatusColor,
                        priorityLevel = ai.PriorityLevel,
                        priorityBadgeColor = ai.PriorityBadgeColor,
                        recommendedDays = ai.RecommendedDays,

                        // Photos
                        fotoTemuan = item.FotoTemuan,
                        fotoPerbaikan = item.FotoPerbaikan,

                        // Reassigned
                        isReassigned,
                        reassignedFrom = item.ReassignedFrom,
                        reassignedTo = item.ReassignedTo,
                        reassignedAt = item.ReassignedAt?.ToString("dd MMM yyyy, HH:mm"),
                        reassignNote = item.ReassignNote,

                        // Parties
                        nama = item.Nama,
                        nik = item.Nik,
                        departemen = item.Departemen ?? "-",
                        perusahaanPelapor = compPelapor ?? "PT INDEXIM COALINDO",

                        pja = item.Pja ?? "-",
                        nikPja = item.NikPja ?? "-",
                        departemenPja = item.DepartemenPja ?? "-",
                        perusahaanPja = compPja ?? "",

                        pic = item.Pic ?? "",
                        nikPic = item.NikPic ?? "",
                        departemenPic = item.DepartemenPic ?? "",
                        perusahaanPic = compPic ?? "",

                        // Perbaikan
                        rencanaPerbaikan = item.RencanaPerbaikan,
                        tanggalRencanaPerbaikan = item.TanggalRencanaPerbaikan?.ToString("dd MMM yyyy"),
                        perbaikan = item.Perbaikan,
                        tanggalPerbaikan = item.TanggalPerbaikan?.ToString("dd MMM yyyy"),

                        // AI Analysis
                        aiAnalysis = new
                        {
                            reasoning = ai.AiReasoning,
                            recommendation = ai.ActionRecommendation,
                            isGoldenRule = ai.IsGoldenRuleViolation,
                            goldenRuleTopic = ai.GoldenRuleTopic,
                            qualityScore = ai.QualityScore
                        }
                    });
                }

                return Ok(new
                {
                    status = true,
                    message = "Berhasil memuat Action Tracker",
                    data = new
                    {
                        userNik = targetNik,
                        userName,
                        userDept,
                        summary = new
                        {
                            outstanding = countOutstanding,
                            progress = countProgress,
                            closed = countClosed,
                            total = countOutstanding + countProgress + countClosed
                        },
                        currentFilters = new
                        {
                            filter = normFilter,
                            status = normStatus,
                            type = normType,
                            search = search ?? "",
                            startDate,
                            endDate
                        },
                        totalItems = itemsDto.Count,
                        items = itemsDto
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = $"Gagal memuat Action Tracker: {ex.Message}" });
            }
        }
    }
}

