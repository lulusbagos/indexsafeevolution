using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class P2hController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ILogger<P2hController> _logger;
        private readonly ImageUploadService _imageUploadService;

        public P2hController(AppDbContext context, ILogger<P2hController> logger, ImageUploadService imageUploadService)
        {
            _context = context;
            _logger = logger;
            _imageUploadService = imageUploadService;
        }

        public class ChecklistItem
        {
            public int Id { get; set; }
            public string Name { get; set; } = string.Empty;
            public string Status { get; set; } = "GOOD"; // GOOD / NOT_GOOD
            public string? PhotoUrl { get; set; }
        }

        // Standard Checklist Items matching Web MBS_SAP
        public static readonly string[] GolA = new string[]
        {
            "Klakson/Horn",
            "Rem Tangan/Park Brake",
            "Masa Berlaku Stiker Komisioning/Commissioning Sticker Expired Date",
            "APAR",
            "Lampu Mundur Dan Alarm Mundur",
            "Radio Komunikasi",
            "Lampu Rotary",
            "Level Oli Kemudi/Level Oil Steering",
            "Sabuk Pengaman/Safety Belt",
            "Rem Kaki/Foot Brake",
            "Tebal Ban/Tyre Tread",
            "Lampu Depan/Head Light",
            "Baut Roda/Wheel Stud",
            "Lampu Belok Dan Lampu Belakang/Sign And Tail Lights",
            "Lampu Rem/Brake Light",
            "Kemudi/Steering"
        };

        public static readonly string[] GolB = new string[]
        {
            "Kaca Depan/Windscreen",
            "Bendera Dan Bugywhip",
            "Level Oli Mesin/Engine Oil Level",
            "Level Oli Persneling/Clutch Oil Level",
            "Panel Gauge Dan Indikator",
            "Level Air/Water Level",
            "Level Minyak Rem/Brake Fluids Level",
            "Masa Servis/Service Due",
            "Level Air Radiator/Radiator Water Level",
            "Kotak P3K/First Aid Kit"
        };

        public static readonly string[] GolC = new string[]
        {
            "Cairan Wiper/Windscreen Washer",
            "Rangka Pengaman Kabin",
            "Kerusakan Lain",
            "Kebersihan Luar Mobil/Exterior Clean",
            "Pintu-pintu/Doors",
            "Aki/Battery Pack",
            "Ban Serep/Spare Tyre",
            "Kebersihan Dalam Mobil/Interior Clean",
            "Segitiga Pengaman/Triangle Safety Cone",
            "Dongkrak/Jack",
            "Kaca/Mirror"
        };

        /// <summary>
        /// GET /api/p2h/vehicles
        /// Returns active vehicle master list for offline caching & dropdown search
        /// </summary>
        [HttpGet("vehicles")]
        [AllowAnonymous]
        public async Task<IActionResult> GetVehicles()
        {
            var vehicles = await _context.P2hVehicles
                .AsNoTracking()
                .Where(v => !v.IsDeleted)
                .OrderBy(v => v.NoLambung)
                .Select(v => new
                {
                    id = v.Id,
                    noLambung = v.NoLambung,
                    jenisKendaraan = v.JenisKendaraan,
                    merek = v.Merek
                })
                .ToListAsync();

            // Retrieve latest KM for each vehicle
            var lastKms = await _context.P2hReports
                .AsNoTracking()
                .Where(r => !r.IsDeleted)
                .GroupBy(r => r.NoLambung.ToLower())
                .Select(g => new
                {
                    NoLambung = g.Key,
                    LastKm = g.OrderByDescending(r => r.Tanggal).ThenByDescending(r => r.Waktu).ThenByDescending(r => r.Id).Select(r => r.Kilometer).FirstOrDefault()
                })
                .ToDictionaryAsync(x => x.NoLambung, x => x.LastKm);

            var result = vehicles.Select(v => new
            {
                v.id,
                v.noLambung,
                v.jenisKendaraan,
                v.merek,
                lastKm = lastKms.TryGetValue(v.noLambung.ToLower(), out var km) ? km : 0.0
            });

            return Ok(new { success = true, data = result });
        }

        /// <summary>
        /// GET /api/p2h/last-km?noLambung={noLambung}
        /// Returns the latest recorded Kilometer for a given vehicle
        /// </summary>
        [HttpGet("last-km")]
        [AllowAnonymous]
        public async Task<IActionResult> GetLastKm([FromQuery] string noLambung)
        {
            if (string.IsNullOrWhiteSpace(noLambung))
            {
                return Ok(new { success = true, lastKm = 0.0 });
            }

            var cleanNl = noLambung.Trim().ToLower();
            var lastReport = await _context.P2hReports
                .AsNoTracking()
                .Where(r => !r.IsDeleted && r.NoLambung.ToLower() == cleanNl)
                .OrderByDescending(r => r.Tanggal)
                .ThenByDescending(r => r.Waktu)
                .ThenByDescending(r => r.Id)
                .Select(r => new { r.Kilometer, r.Tanggal, r.Waktu })
                .FirstOrDefaultAsync();

            return Ok(new
            {
                success = true,
                noLambung = noLambung.Trim().ToUpper(),
                lastKm = lastReport?.Kilometer ?? 0.0,
                lastDate = lastReport?.Tanggal.ToString("yyyy-MM-dd"),
                lastTime = lastReport?.Waktu.ToString(@"hh\:mm")
            });
        }

        /// <summary>
        /// GET /api/p2h
        /// Returns P2H reports history for current user
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetReports([FromQuery] int limit = 50, [FromQuery] string? search = null)
        {
            var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value?.Trim() ?? "";
            var query = _context.P2hReports
                .AsNoTracking()
                .Where(r => !r.IsDeleted);

            if (!string.IsNullOrEmpty(userNik) && !User.IsInRole("Admin"))
            {
                query = query.Where(r => r.Nik == userNik);
            }

            if (!string.IsNullOrEmpty(search))
            {
                var s = search.Trim().ToLower();
                query = query.Where(r => r.NoLambung.ToLower().Contains(s) || r.Merek.ToLower().Contains(s) || r.JenisKendaraan.ToLower().Contains(s));
            }

            var list = await query
                .OrderByDescending(r => r.Tanggal)
                .ThenByDescending(r => r.Waktu)
                .Take(limit)
                .Select(r => new
                {
                    id = r.Id,
                    code = $"P2H-{r.Id}",
                    nik = r.Nik,
                    nama = r.Nama,
                    tanggal = r.Tanggal.ToString("yyyy-MM-dd"),
                    waktu = r.Waktu.ToString(@"hh\:mm"),
                    noLambung = r.NoLambung,
                    jenisKendaraan = r.JenisKendaraan,
                    merek = r.Merek,
                    kilometer = r.Kilometer,
                    simperKimper = r.SimperKimper,
                    fotoSpeedometer = r.FotoSpeedometer,
                    golA = r.GolA_Json,
                    golB = r.GolB_Json,
                    golC = r.GolC_Json,
                    createdAt = r.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                })
                .ToListAsync();

            return Ok(new { success = true, data = list });
        }

        /// <summary>
        /// GET /api/p2h/{id}
        /// Returns single P2H report detail
        /// </summary>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var report = await _context.P2hReports.FindAsync(id);
            if (report == null || report.IsDeleted) return NotFound(new { success = false, message = "Laporan P2H tidak ditemukan." });

            return Ok(new
            {
                success = true,
                data = new
                {
                    id = report.Id,
                    code = $"P2H-{report.Id}",
                    nik = report.Nik,
                    nama = report.Nama,
                    tanggal = report.Tanggal.ToString("yyyy-MM-dd"),
                    waktu = report.Waktu.ToString(@"hh\:mm"),
                    noLambung = report.NoLambung,
                    jenisKendaraan = report.JenisKendaraan,
                    merek = report.Merek,
                    kilometer = report.Kilometer,
                    simperKimper = report.SimperKimper,
                    fotoSpeedometer = report.FotoSpeedometer,
                    golA = string.IsNullOrEmpty(report.GolA_Json) ? new List<ChecklistItem>() : JsonSerializer.Deserialize<List<ChecklistItem>>(report.GolA_Json),
                    golB = string.IsNullOrEmpty(report.GolB_Json) ? new List<ChecklistItem>() : JsonSerializer.Deserialize<List<ChecklistItem>>(report.GolB_Json),
                    golC = string.IsNullOrEmpty(report.GolC_Json) ? new List<ChecklistItem>() : JsonSerializer.Deserialize<List<ChecklistItem>>(report.GolC_Json),
                    createdAt = report.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }

        /// <summary>
        /// POST /api/p2h
        /// Creates or updates P2H report (supports multipart/form-data with file uploads)
        /// </summary>
        [HttpPost]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> CreateOrUpdate([FromForm] IFormCollection form)
        {
            try
            {
                var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value?.Trim() ?? form["nik"].FirstOrDefault() ?? "00000";
                var userName = User.Identity?.Name ?? form["nama"].FirstOrDefault() ?? "Anonymous";

                var noLambung = form["no_lambung"].FirstOrDefault()?.Trim().ToUpper() ?? form["noLambung"].FirstOrDefault()?.Trim().ToUpper();
                if (string.IsNullOrEmpty(noLambung))
                {
                    return BadRequest(new { success = false, message = "No Lambung Kendaraan wajib diisi." });
                }

                var jenisKendaraan = form["jenis_kendaraan"].FirstOrDefault() ?? form["jenisKendaraan"].FirstOrDefault() ?? "LIGHT VEHICLE";
                var merek = form["merek"].FirstOrDefault() ?? form["brand"].FirstOrDefault() ?? "TOYOTA";
                var kmStr = form["kilometer"].FirstOrDefault() ?? form["km"].FirstOrDefault() ?? "0";
                double.TryParse(kmStr, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var kilometer);
                var simperKimper = form["simper_kimper"].FirstOrDefault() ?? form["simperKimper"].FirstOrDefault() ?? (form["simper"].FirstOrDefault() == "1" ? "YA" : "TIDAK");

                DateTime tanggal = DateTime.Today;
                var tanggalStr = form["tanggal"].FirstOrDefault() ?? form["date"].FirstOrDefault();
                if (!string.IsNullOrEmpty(tanggalStr) && DateTime.TryParse(tanggalStr, out var parsedDate))
                {
                    tanggal = parsedDate.Date;
                }

                TimeSpan waktu = DateTime.Now.TimeOfDay;
                var waktuStr = form["waktu"].FirstOrDefault() ?? form["time"].FirstOrDefault() ?? form["waktuStr"].FirstOrDefault();
                if (!string.IsNullOrEmpty(waktuStr) && TimeSpan.TryParse(waktuStr, out var parsedWaktu))
                {
                    waktu = parsedWaktu;
                }

                // 0. Validate Back-Date (Tidak boleh mengisi tanggal lampau)
                if (tanggal.Date < DateTime.Today)
                {
                    return BadRequest(new { success = false, message = "Pengisian P2H tidak boleh back-date (tanggal lampau). Silakan pilih tanggal hari ini." });
                }

                // 0. Validate Odometer (Pengisian berikutnya harus lebih besar dari sebelumnya)
                var lastReport = await _context.P2hReports
                    .AsNoTracking()
                    .Where(r => !r.IsDeleted && r.NoLambung.ToLower() == noLambung.ToLower())
                    .OrderByDescending(r => r.Tanggal)
                    .ThenByDescending(r => r.Waktu)
                    .ThenByDescending(r => r.Id)
                    .FirstOrDefaultAsync();

                if (lastReport != null && lastReport.Kilometer > 0 && kilometer <= lastReport.Kilometer)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = $"Odometer baru ({kilometer} KM) harus lebih besar dari KM sebelumnya ({lastReport.Kilometer} KM). Pastikan angka kilometer tidak salah!"
                    });
                }

                // 1. Manage Vehicle Master (Add or Update)
                var existingVehicle = await _context.P2hVehicles
                    .FirstOrDefaultAsync(v => v.NoLambung.ToLower() == noLambung.ToLower() && !v.IsDeleted);

                if (existingVehicle == null)
                {
                    existingVehicle = new P2hVehicle
                    {
                        NoLambung = noLambung,
                        JenisKendaraan = jenisKendaraan,
                        Merek = merek,
                        CreatedAt = DateTime.Now
                    };
                    _context.P2hVehicles.Add(existingVehicle);
                    await _context.SaveChangesAsync();
                }
                else
                {
                    bool changed = false;
                    if (!string.IsNullOrEmpty(jenisKendaraan) && existingVehicle.JenisKendaraan != jenisKendaraan)
                    {
                        existingVehicle.JenisKendaraan = jenisKendaraan;
                        changed = true;
                    }
                    if (!string.IsNullOrEmpty(merek) && existingVehicle.Merek != merek)
                    {
                        existingVehicle.Merek = merek;
                        changed = true;
                    }
                    if (changed)
                    {
                        _context.P2hVehicles.Update(existingVehicle);
                        await _context.SaveChangesAsync();
                    }
                }

                // 2. Fetch or Init Report
                int? idVal = null;
                var idStr = form["id"].FirstOrDefault();
                if (!string.IsNullOrEmpty(idStr) && int.TryParse(idStr, out var parsedId) && parsedId > 0)
                {
                    idVal = parsedId;
                }

                P2hReport report;
                bool isNew = true;
                if (idVal.HasValue)
                {
                    var found = await _context.P2hReports.FindAsync(idVal.Value);
                    if (found == null || found.IsDeleted) return NotFound(new { success = false, message = "Data P2H tidak ditemukan." });
                    report = found;
                    isNew = false;
                }
                else
                {
                    report = new P2hReport
                    {
                        Nik = userNik,
                        Nama = userName,
                        CreatedAt = DateTime.Now
                    };
                }

                report.Tanggal = tanggal;
                report.Waktu = waktu;
                report.NoLambung = noLambung;
                report.JenisKendaraan = jenisKendaraan;
                report.Merek = merek;
                report.Kilometer = kilometer;
                report.SimperKimper = simperKimper;

                // 3. Handle Foto Speedometer
                var fotoSpeedo = form.Files["foto_speedometer"] ?? form.Files["image"];
                if (fotoSpeedo != null && fotoSpeedo.Length > 0)
                {
                    var uploaded = await _imageUploadService.UploadAndCompressImageAsync(fotoSpeedo, "p2h", "speedo");
                    if (uploaded != null)
                    {
                        report.FotoSpeedometer = uploaded;
                    }
                }

                // 4. Process Checklist JSON & Defect Photos
                report.GolA_Json = await ProcessGroupAsync("golA", form["gol_a_json"].FirstOrDefault() ?? form["golA_json"].FirstOrDefault(), GolA, form);
                report.GolB_Json = await ProcessGroupAsync("golB", form["gol_b_json"].FirstOrDefault() ?? form["golB_json"].FirstOrDefault(), GolB, form);
                report.GolC_Json = await ProcessGroupAsync("golC", form["gol_c_json"].FirstOrDefault() ?? form["golC_json"].FirstOrDefault(), GolC, form);

                if (isNew)
                {
                    _context.P2hReports.Add(report);
                }
                else
                {
                    _context.P2hReports.Update(report);
                }

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    success = true,
                    status = true,
                    message = isNew ? "Laporan P2H berhasil disimpan!" : "Laporan P2H berhasil diperbarui!",
                    data = new
                    {
                        id = report.Id,
                        code = $"P2H-{report.Id}",
                        updatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating/updating P2H report");
                return StatusCode(500, new { success = false, message = "Terjadi kesalahan saat memproses laporan P2H." });
            }
        }

        private async Task<string> ProcessGroupAsync(string groupKey, string? jsonInput, string[] standardQuestions, IFormCollection form)
        {
            List<ChecklistItem> list;
            if (!string.IsNullOrEmpty(jsonInput))
            {
                try
                {
                    list = JsonSerializer.Deserialize<List<ChecklistItem>>(jsonInput, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new List<ChecklistItem>();
                }
                catch
                {
                    list = new List<ChecklistItem>();
                }
            }
            else
            {
                list = new List<ChecklistItem>();
            }

            // Ensure all standard items are represented
            for (int i = 0; i < standardQuestions.Length; i++)
            {
                var qName = standardQuestions[i];
                var existing = list.FirstOrDefault(x => x.Id == i + 1 || string.Equals(x.Name, qName, StringComparison.OrdinalIgnoreCase));
                if (existing == null)
                {
                    existing = new ChecklistItem
                    {
                        Id = i + 1,
                        Name = qName,
                        Status = form[$"{groupKey}_status_{i}"].FirstOrDefault() ?? "GOOD"
                    };
                    list.Add(existing);
                }

                // Check if a file was uploaded for this item (e.g. golA_photo_0 or photo_golA_0)
                var file = form.Files[$"{groupKey}_photo_{i}"] ?? form.Files[$"photo_{groupKey}_{i}"];
                if (file != null && file.Length > 0)
                {
                    var uploaded = await _imageUploadService.UploadAndCompressImageAsync(file, "p2h", $"{groupKey}_{i}");
                    if (uploaded != null)
                    {
                        existing.PhotoUrl = uploaded;
                    }
                }
            }

            // Order by Id
            list = list.OrderBy(x => x.Id).ToList();
            return JsonSerializer.Serialize(list);
        }

        /// <summary>
        /// DELETE /api/p2h/{id}
        /// Soft delete P2H report
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var report = await _context.P2hReports.FindAsync(id);
            if (report == null || report.IsDeleted) return NotFound(new { success = false, message = "Data tidak ditemukan." });

            var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value?.Trim() ?? "";
            if (!User.IsInRole("Admin") && !string.Equals(report.Nik?.Trim(), userNik, StringComparison.OrdinalIgnoreCase))
            {
                return Forbid();
            }

            report.IsDeleted = true;
            _context.P2hReports.Update(report);
            await _context.SaveChangesAsync();

            return Ok(new { success = true, message = "Laporan P2H berhasil dihapus." });
        }
    }
}
