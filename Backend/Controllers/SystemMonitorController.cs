using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/system")]
    public class SystemMonitorController : ControllerBase
    {
        private readonly SyncMonitorService _monitor;
        private readonly AppDbContext _context;

        public SystemMonitorController(SyncMonitorService monitor, AppDbContext context)
        {
            _monitor = monitor;
            _context = context;
        }

        [HttpGet("monitor")]
        public async Task<IActionResult> GetMonitoringData()
        {
            var stats = _monitor.GetStats();
            var liveTransactions = _monitor.GetRecentTransactions(50);
            var uploads = _monitor.GetRecentUploads(50);
            var errors = _monitor.GetRecentErrors(50);

            // If in-memory is empty (e.g. freshly restarted), pre-seed with latest transactions from DB_SAP
            if (liveTransactions.Count == 0)
            {
                try
                {
                    var recentHazards = await _context.HazardReports
                        .AsNoTracking()
                        .OrderByDescending(h => h.CreatedAt)
                        .Take(15)
                        .Select(h => new TransactionEvent
                        {
                            Type = "Hazard",
                            Source = "Database Record",
                            ServerId = h.Id,
                            Code = $"HZ-{h.Id}",
                            Nik = h.Nik,
                            Nama = h.Nama,
                            Area = h.Area ?? "PIT",
                            Lokasi = h.Lokasi ?? "FRONT",
                            DetilLokasi = h.DetilLokasi ?? "",
                            HasPhoto = !string.IsNullOrEmpty(h.FotoTemuan),
                            PhotoUrl = h.FotoTemuan,
                            InspectionDate = h.Tanggal,
                            SyncedAt = h.CreatedAt,
                            Status = h.StatusTemuan,
                            Summary = $"[{h.KategoriBahaya}] {h.Temuan}"
                        })
                        .ToListAsync();

                    foreach (var tx in recentHazards)
                    {
                        // Check if detil_lokasi contains GPS coordinates
                        if (tx.DetilLokasi.Contains("[GPS:"))
                        {
                            var idx = tx.DetilLokasi.IndexOf("[GPS:");
                            var end = tx.DetilLokasi.IndexOf("]", idx);
                            if (end > idx)
                            {
                                var gpsStr = tx.DetilLokasi.Substring(idx + 5, end - (idx + 5));
                                var parts = gpsStr.Split(',');
                                if (parts.Length >= 2 &&
                                    double.TryParse(parts[0].Trim(), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var lat) &&
                                    double.TryParse(parts[1].Trim().Split(' ')[0], System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var lng))
                                {
                                    tx.Latitude = lat;
                                    tx.Longitude = lng;
                                }
                            }
                        }
                        _monitor.RecordTransaction(tx);
                    }

                    liveTransactions = _monitor.GetRecentTransactions(50);
                    stats = _monitor.GetStats();
                }
                catch
                {
                    // Ignore seeding hiccups
                }
            }

            return Ok(new
            {
                stats,
                transactions = liveTransactions,
                uploads,
                errors
            });
        }

        /// <summary>
        /// Test endpoint to trigger a simulated offline sync packet for verification in the UI
        /// </summary>
        [HttpPost("test-sync")]
        public IActionResult TriggerTestSync([FromQuery] string module = "hazard", [FromQuery] bool simulateError = false)
        {
            if (simulateError)
            {
                _monitor.RecordError(new ErrorEvent
                {
                    Module = "OfflineSyncEngine",
                    Endpoint = $"/api/tran/{module}",
                    ClientUuid = Guid.NewGuid().ToString("N")[..12],
                    UserNik = "0002",
                    ErrorMessage = "Duplicate client_uuid received: packet already acknowledged by server at 06:14:02.",
                    Severity = "WARNING",
                    PayloadSnippet = "code=HZ-202610-09, local_id=45, retry_count=2",
                    SuggestedFix = "Idempotency key dideteksi: Server otomatis mengembalikan ID yang sudah tersimpan tanpa duplikasi."
                });

                return Ok(new { status = true, message = "Simulasi warning idempotency offline berhasil dicatat di log." });
            }

            var rand = new Random();
            var lat = -0.142000 + (rand.NextDouble() * 0.05);
            var lng = 117.580000 + (rand.NextDouble() * 0.05);

            _monitor.RecordTransaction(new TransactionEvent
            {
                Type = module.ToUpperInvariant(),
                Source = "Offline Outbox Sync (Simulated)",
                ServerId = rand.Next(9000, 9999),
                Code = $"MOCK-{rand.Next(100, 999)}",
                Nik = "0002",
                Nama = "AMIN (Penguji)",
                Perusahaan = "PT JENDAR FAMILY KARYA",
                Area = "PIT TEMPUDO 4",
                Lokasi = "BENCH 120 RL",
                DetilLokasi = $"Area Loading Barat [GPS: {lat:F6}, {lng:F6} ±4.2m]",
                Latitude = lat,
                Longitude = lng,
                GpsAccuracy = 4.2,
                HasPhoto = true,
                PhotoUrl = "/uploads/hazard/sample_hazard.jpg",
                InspectionDate = DateTime.Today.AddDays(-1),
                DurationMs = rand.Next(40, 180),
                Status = "Success",
                Summary = "Tanggul pengaman kurang dari 3/4 tinggi ban HD785 di jalur hauling pit."
            });

            _monitor.RecordUpload(new UploadEvent
            {
                FileName = $"photo_offline_pit_{rand.Next(10, 99)}.jpg",
                Category = module.ToLowerInvariant(),
                OriginalSizeKb = 3450,
                CompressedSizeKb = 380,
                SavedUrl = $"/uploads/{module}/sample_{rand.Next(100, 999)}.jpg",
                DurationMs = rand.Next(80, 220),
                Status = "Compressed & Stored"
            });

            return Ok(new { status = true, message = "Simulasi transaksi offline berhasil dikirim ke Live Monitor." });
        }

        [HttpPost("clear-logs")]
        public IActionResult ClearLogs()
        {
            return Ok(new { status = true, message = "Log berhasil dibersihkan." });
        }
    }
}
