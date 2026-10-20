using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
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

        public PerformanceController(AppDbContext context)
        {
            _context = context;
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
    }
}
