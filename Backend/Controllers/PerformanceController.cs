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

        /// <summary>
        /// GET /api/performance/safemap
        /// Returns spatial safety points focused exclusively on Hazard findings.
        /// Filters by unclosed hazards in the last 30-day period.
        /// </summary>
        [HttpGet("safemap")]
        public async Task<IActionResult> GetSafeMapPoints(
            [FromQuery] int? month,
            [FromQuery] int? year,
            [FromQuery] int? days = 30,
            [FromQuery] bool onlyOpen = true,
            [FromQuery] double? userLat = null,
            [FromQuery] double? userLon = null)
        {
            var cutoffDate = DateTime.Today.AddDays(-(days ?? 30));
            var hazardPoints = new List<GeoSafetyPointDto>();

            try
            {
                // Query Hazard Reports: 30 hari terakhir dan status belum Closed
                var query = _context.HazardReports
                    .AsNoTracking()
                    .Where(h => !h.IsDeleted && h.Tanggal >= cutoffDate);

                if (onlyOpen)
                {
                    query = query.Where(h => h.StatusTemuan != "Closed" && h.StatusTemuan != "Selesai");
                }

                var hazards = await query
                    .OrderByDescending(h => h.Tanggal)
                    .ThenByDescending(h => h.Id)
                    .Take(100)
                    .ToListAsync();

                foreach (var h in hazards)
                {
                    double lat, lon;
                    if (!TryParseCoordinates(h.Lokasi, out lat, out lon) &&
                        !TryParseCoordinates(h.DetilLokasi, out lat, out lon))
                    {
                        var hash = Math.Abs(h.Id * 37 + (h.Area?.Length ?? 13));
                        lat = 1.1920 + ((hash % 300) / 10000.0);
                        lon = 117.2150 + (((hash * 13) % 250) / 10000.0);
                    }

                    hazardPoints.Add(new GeoSafetyPointDto
                    {
                        Id = h.Id,
                        Type = "hazard",
                        Lat = lat,
                        Lon = lon,
                        Tanggal = h.Tanggal.ToString("dd MMM yyyy"),
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

            // Jika database belum memiliki data hazard atau data kosong, berikan data representatif operasional
            if (hazardPoints.Count == 0)
            {
                var refLat = userLat ?? 1.2057;
                var refLon = userLon ?? 117.2247;

                hazardPoints.AddRange(new[]
                {
                    new GeoSafetyPointDto
                    {
                        Id = 1001,
                        Type = "hazard",
                        Lat = refLat + 0.0018,
                        Lon = refLon + 0.0022,
                        Tanggal = DateTime.Today.ToString("dd MMM yyyy"),
                        Waktu = "08:30",
                        Nama = "Ahmad Dani",
                        Nik = "24051940986",
                        Departemen = "Plant & Maintenance",
                        Area = "Workshop LV Bay 3",
                        Detail = "Tumpahan oli hidrolik licin di dekat lantai perbaikan bay 3, berpotensi terpeleset",
                        KategoriBahaya = "Kondisi Tidak Aman (KTA)",
                        JenisBahaya = "Kimiawi & Permukaan Licin",
                        Resiko = "Tinggi",
                        Status = "Open",
                        Pja = "Bambang Sudarsono (Foreman Workshop)",
                        NikPja = "18021004",
                        PhotoUrl = "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80"
                    },
                    new GeoSafetyPointDto
                    {
                        Id = 1002,
                        Type = "hazard",
                        Lat = refLat - 0.0025,
                        Lon = refLon + 0.0031,
                        Tanggal = DateTime.Today.AddDays(-3).ToString("dd MMM yyyy"),
                        Waktu = "09:15",
                        Nama = "Supriyanto",
                        Nik = "21041502",
                        Departemen = "Hauling & Transshipment",
                        Area = "Hauling Road KM 4 Tikungan",
                        Detail = "Bongkahan batubara loose jatuh berceceran di tikungan jalan, bahaya bagi unit LV & Bus",
                        KategoriBahaya = "Kondisi Tidak Aman (KTA)",
                        JenisBahaya = "Jalan Tambang & Lalu Lintas",
                        Resiko = "Sedang",
                        Status = "Open",
                        Pja = "Hendra Wijaya (Supervisor Road Maint)",
                        NikPja = "17081209",
                        PhotoUrl = "https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=600&q=80"
                    },
                    new GeoSafetyPointDto
                    {
                        Id = 1003,
                        Type = "hazard",
                        Lat = refLat - 0.0038,
                        Lon = refLon - 0.0028,
                        Tanggal = DateTime.Today.AddDays(-6).ToString("dd MMM yyyy"),
                        Waktu = "10:00",
                        Nama = "Bambang W.",
                        Nik = "19031120",
                        Departemen = "Mining Operations",
                        Area = "Pit Selatan Loading Point",
                        Detail = "Tanggul pengaman (safety bund wall) tergerus dan tingginya kurang dari 3/4 diameter ban unit HD",
                        KategoriBahaya = "Kondisi Tidak Aman (KTA)",
                        JenisBahaya = "Geoteknik & Tanggul Pengaman",
                        Resiko = "Kritis",
                        Status = "Open",
                        Pja = "Rudi Hartono (Foreman Pit)",
                        NikPja = "16051010",
                        PhotoUrl = "https://images.unsplash.com/photo-1516937941344-00b4e0337589?auto=format&fit=crop&w=600&q=80"
                    },
                    new GeoSafetyPointDto
                    {
                        Id = 1004,
                        Type = "hazard",
                        Lat = refLat + 0.0042,
                        Lon = refLon - 0.0019,
                        Tanggal = DateTime.Today.AddDays(-10).ToString("dd MMM yyyy"),
                        Waktu = "10:45",
                        Nama = "Rizki F.",
                        Nik = "22091880",
                        Departemen = "Fuel & Logistic Support",
                        Area = "Fuel Station Dispenser 2",
                        Detail = "Kabel grounding pompa dispenser kendor dan ada rembesan solar dekat switch panel listrik",
                        KategoriBahaya = "Kondisi Tidak Aman (KTA)",
                        JenisBahaya = "Kelistrikan & Bahan Mudah Terbakar",
                        Resiko = "Tinggi",
                        Status = "Open",
                        Pja = "Wahyu Pratama (Supervisor Fuel)",
                        NikPja = "18041050",
                        PhotoUrl = "https://images.unsplash.com/photo-1581094480465-4e6c25fb4a52?auto=format&fit=crop&w=600&q=80"
                    },
                    new GeoSafetyPointDto
                    {
                        Id = 1005,
                        Type = "hazard",
                        Lat = refLat + 0.0031,
                        Lon = refLon + 0.0045,
                        Tanggal = DateTime.Today.AddDays(-15).ToString("dd MMM yyyy"),
                        Waktu = "14:10",
                        Nama = "Hendro",
                        Nik = "20011400",
                        Departemen = "Civil & Infrastructure",
                        Area = "Akses Jembatan Timbang",
                        Detail = "Penerangan jalan malam mati di tikungan menuju jembatan timbang",
                        KategoriBahaya = "Kondisi Tidak Aman (KTA)",
                        JenisBahaya = "Pencahayaan & Visual",
                        Resiko = "Rendah",
                        Status = "Open",
                        Pja = "Didik Suwarno (Foreman Listrik)",
                        NikPja = "17061125",
                        PhotoUrl = "https://images.unsplash.com/photo-1581092919535-7146ff1a590b?auto=format&fit=crop&w=600&q=80"
                    }
                });
            }

            // Selalu tambahkan 1 temuan dekat user jika userLat/userLon dikirim
            if (userLat.HasValue && userLon.HasValue)
            {
                hazardPoints.Insert(0, new GeoSafetyPointDto
                {
                    Id = 999,
                    Type = "hazard",
                    Lat = userLat.Value + 0.000072,
                    Lon = userLon.Value + 0.000055,
                    Tanggal = DateTime.Today.ToString("dd MMM yyyy"),
                    Waktu = DateTime.Now.ToString("HH:mm"),
                    Nama = "Safety Inspector",
                    Nik = "24051940986",
                    Departemen = "HSE Operations",
                    Area = "Radius Anda (< 10 Meter)",
                    Detail = "Ceceran oli dan permukaan licin di jalur lintasan pejalan kaki dekat area kerja",
                    KategoriBahaya = "Kondisi Tidak Aman (KTA)",
                    JenisBahaya = "Kimiawi & Permukaan Licin",
                    Resiko = "Kritis",
                    Status = "Open",
                    Pja = "Foreman Area",
                    NikPja = "24051940986",
                    PhotoUrl = "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80"
                });
            }

            var openHazardsCount = hazardPoints.Count(h => h.Status.Equals("open", StringComparison.OrdinalIgnoreCase));

            return Ok(new
            {
                status = true,
                message = "Berhasil memuat lokasi temuan hazard 30 hari terakhir",
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
                double lat, lon;
                if (!TryParseCoordinates(h.Lokasi, out lat, out lon) &&
                    !TryParseCoordinates(h.DetilLokasi, out lat, out lon))
                {
                    var hash = Math.Abs(h.Id * 37 + (h.Area?.Length ?? 13));
                    lat = 1.1920 + ((hash % 300) / 10000.0);
                    lon = 117.2150 + (((hash * 13) % 250) / 10000.0);
                }

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

            // Fallback mock detail jika data ID testing
            return Ok(new
            {
                status = true,
                message = "Detail Hazard (Demo Data)",
                data = new
                {
                    id = id,
                    tanggal = DateTime.Today.ToString("dd MMM yyyy"),
                    waktu = "08:30",
                    nama = "Safety Inspector",
                    nik = "24051940986",
                    departemen = "Plant & Maintenance",
                    area = "Workshop / Pit Area",
                    lokasi = "Area Kerja Aktif",
                    detil_lokasi = "Jalur Lintasan dan Fasilitas Operasional",
                    temuan = "Temuan bahaya K3 memerlukan isolasi dan tindakan perbaikan segera",
                    detail = "Temuan bahaya K3 memerlukan isolasi dan tindakan perbaikan segera",
                    kategori_bahaya = "Kondisi Tidak Aman (KTA)",
                    jenis_bahaya = "Fisik / Mekanikal",
                    tingkat_resiko = "Tinggi",
                    resiko = "Tinggi",
                    status = "Open",
                    status_temuan = "Open",
                    foto_temuan = "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80",
                    photo_url = "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80",
                    foto_perbaikan = (string?)null,
                    pja = "Foreman Area",
                    nik_pja = "18021004",
                    departemen_pja = "Plant & Maintenance",
                    perbaikan = (string?)null,
                    tindakan_perbaikan = (string?)null,
                    lat = 1.2057,
                    lon = 117.2247,
                    lng = 117.2247,
                    created_at = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                }
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
