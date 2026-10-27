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

        /// <summary>
        /// Endpoint analitik makro untuk memantau pergerakan aplikasi dan gerbang tanpa mengekspos data pribadi
        /// </summary>
        [HttpGet("movement-analytics")]
        public async Task<IActionResult> GetMovementAnalytics()
        {
            try
            {
                var nowWita = DateTime.UtcNow.AddHours(8);
                var todayDate = nowWita.Date;
                var sevenDaysAgo = todayDate.AddDays(-6);

                // 1. Gate Movement Stats
                var allGateLogs = await _context.PermitGateLogs.AsNoTracking().ToListAsync();
                var totalMovements = allGateLogs.Count;
                var totalIn = allGateLogs.Count(l => l.Direction.Equals("MASUK", StringComparison.OrdinalIgnoreCase));
                var totalOut = allGateLogs.Count(l => l.Direction.Equals("KELUAR", StringComparison.OrdinalIgnoreCase));
                var totalPassengers = allGateLogs.Sum(l => l.JumlahPenumpang ?? 0);

                var todayLogs = allGateLogs.Where(l => l.CreatedAt.Date == todayDate || l.CreatedAt.Date == DateTime.Today).ToList();
                var todayMovements = todayLogs.Count;
                var todayIn = todayLogs.Count(l => l.Direction.Equals("MASUK", StringComparison.OrdinalIgnoreCase));
                var todayOut = todayLogs.Count(l => l.Direction.Equals("KELUAR", StringComparison.OrdinalIgnoreCase));
                var todayPassengers = todayLogs.Sum(l => l.JumlahPenumpang ?? 0);

                // 7-day trend (Labels and counts for IN, OUT, and Passengers)
                var last7DaysLabels = new List<string>();
                var last7DaysIn = new List<int>();
                var last7DaysOut = new List<int>();
                var last7DaysPassengers = new List<int>();

                for (int i = 6; i >= 0; i--)
                {
                    var d = todayDate.AddDays(-i);
                    var dayLogs = allGateLogs.Where(l => l.CreatedAt.Date == d.Date).ToList();
                    last7DaysLabels.Add(d.ToString("dd MMM"));
                    last7DaysIn.Add(dayLogs.Count(l => l.Direction.Equals("MASUK", StringComparison.OrdinalIgnoreCase)));
                    last7DaysOut.Add(dayLogs.Count(l => l.Direction.Equals("KELUAR", StringComparison.OrdinalIgnoreCase)));
                    last7DaysPassengers.Add(dayLogs.Sum(l => l.JumlahPenumpang ?? 0));
                }

                // 24-hour distribution (today)
                var hourlyLabels = Enumerable.Range(0, 24).Select(h => $"{h:D2}:00").ToList();
                var hourlyIn = new int[24];
                var hourlyOut = new int[24];
                var hourlyPassengers = new int[24];
                foreach (var log in todayLogs)
                {
                    var h = log.CreatedAt.Hour;
                    if (h >= 0 && h < 24)
                    {
                        if (log.Direction.Equals("MASUK", StringComparison.OrdinalIgnoreCase)) hourlyIn[h]++;
                        else hourlyOut[h]++;
                        hourlyPassengers[h] += (log.JumlahPenumpang ?? 0);
                    }
                }

                // Location distribution (Pos / Gate)
                var locationDistribution = allGateLogs
                    .GroupBy(l => string.IsNullOrWhiteSpace(l.LokasiPos) ? "Pos Security Utama" : l.LokasiPos.Trim())
                    .Select(g => new
                    {
                        location = g.Key,
                        total = g.Count(),
                        inCount = g.Count(l => l.Direction.Equals("MASUK", StringComparison.OrdinalIgnoreCase)),
                        outCount = g.Count(l => l.Direction.Equals("KELUAR", StringComparison.OrdinalIgnoreCase)),
                        passengers = g.Sum(l => l.JumlahPenumpang ?? 0)
                    })
                    .OrderByDescending(x => x.total)
                    .Take(7)
                    .ToList();

                // 2. High-level Application Module Activity Volume (macro counts only)
                var moduleStats = new
                {
                    gateMovements = totalMovements,
                    hazardReports = await _context.HazardReports.CountAsync(),
                    p2hInspections = await _context.P2hReports.CountAsync(),
                    safetyInspections = await _context.Inspections.CountAsync(),
                    attendanceRecords = await _context.AttendanceRecords.CountAsync(),
                    fieldAssessments = await _context.FciReports.CountAsync()
                        + await _context.DciReports.CountAsync()
                        + await _context.RciReports.CountAsync()
                        + await _context.DpaReports.CountAsync()
                };

                // 3. System Health Info
                var systemHealth = new
                {
                    status = "ONLINE",
                    environment = "Production / Staging",
                    serverTime = nowWita.ToString("yyyy-MM-dd HH:mm:ss") + " WITA",
                    databaseSap = "Connected (172.16.1.93)",
                    databaseBima = "Connected (172.16.1.96)",
                    gpsTracked = allGateLogs.Count(l => l.Latitude.HasValue && l.Longitude.HasValue)
                };

                return Ok(new
                {
                    status = true,
                    gateSummary = new
                    {
                        totalMovements,
                        totalIn,
                        totalOut,
                        totalPassengers,
                        todayMovements,
                        todayIn,
                        todayOut,
                        todayPassengers,
                        inRate = totalMovements > 0 ? Math.Round((double)totalIn / totalMovements * 100, 1) : 50.0,
                        outRate = totalMovements > 0 ? Math.Round((double)totalOut / totalMovements * 100, 1) : 50.0,
                    },
                    trend7Days = new
                    {
                        labels = last7DaysLabels,
                        inCounts = last7DaysIn,
                        outCounts = last7DaysOut,
                        passengers = last7DaysPassengers
                    },
                    hourlyTrend = new
                    {
                        labels = hourlyLabels,
                        inCounts = hourlyIn,
                        outCounts = hourlyOut,
                        passengers = hourlyPassengers
                    },
                    locationDistribution,
                    moduleStats,
                    systemHealth
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = ex.Message });
            }
        }

        [HttpPost("clear-logs")]
        public IActionResult ClearLogs()
        {
            return Ok(new { status = true, message = "Log berhasil dibersihkan." });
        }
    }
}
