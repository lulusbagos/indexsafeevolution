using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    public class QrScanRequest
    {
        public string Code { get; set; } = string.Empty;
        public string? ScanType { get; set; } // "Absen Acara", "Mine Permit", "Kendaraan", "Auto"
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public double? Accuracy { get; set; }
    }

    public class QrScanResponse
    {
        public bool Status { get; set; }
        public string ActionType { get; set; } = "Unknown"; // Attendance, MinePermit, Vehicle, General
        public string Message { get; set; } = string.Empty;
        public object? Data { get; set; }
    }

    [ApiController]
    [Route("api/qr")]
    [Authorize]
    public class QrController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly SyncMonitorService _monitor;

        public QrController(AppDbContext context, SyncMonitorService monitor)
        {
            _context = context;
            _monitor = monitor;
        }

        private string GetCurrentNik() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0000";
        private string GetCurrentName() => User.Identity?.Name ?? User.FindFirst(ClaimTypes.Name)?.Value ?? "Pengguna Mobile";
        private string GetCurrentDepartment() => User.FindFirst("Department")?.Value ?? "GENERAL";
        private string GetCurrentJobTitle() => User.FindFirst("JobTitle")?.Value ?? "Staff";
        private string GetCurrentCompany() => User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO";

        /// <summary>
        /// POST /api/qr/scan
        /// Universal QR & Barcode Scanner for Mobile App (Handles Event Attendance, Mine Permit, and Unit P2H)
        /// </summary>
        [HttpPost("scan")]
        public async Task<IActionResult> ProcessQrScan([FromBody] QrScanRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.Code))
            {
                return BadRequest(new QrScanResponse { Status = false, Message = "Kode QR tidak boleh kosong." });
            }

            var rawCode = req.Code.Trim();
            var userNik = GetCurrentNik();
            var userName = GetCurrentName();
            var userDept = GetCurrentDepartment();
            var userJob = GetCurrentJobTitle();
            var userComp = GetCurrentCompany();

            // Extract token if code is a full URL (e.g. http://.../QrAttendance/Scan/{token})
            var token = rawCode;
            if (rawCode.Contains("/QrAttendance/Scan/", StringComparison.OrdinalIgnoreCase))
            {
                var idx = rawCode.IndexOf("/QrAttendance/Scan/", StringComparison.OrdinalIgnoreCase);
                token = rawCode.Substring(idx + "/QrAttendance/Scan/".Length).Trim();
                if (token.Contains('?')) token = token.Substring(0, token.IndexOf('?'));
            }

            // 1. Check if token matches an AttendanceEvent in DB_SAP
            var attendanceEvent = await _context.AttendanceEvents
                .FirstOrDefaultAsync(e => e.QrToken == token && !e.IsDeleted);

            if (attendanceEvent != null)
            {
                if (!attendanceEvent.IsActive)
                {
                    return Ok(new QrScanResponse
                    {
                        Status = false,
                        ActionType = "Attendance",
                        Message = $"Event '{attendanceEvent.EventName}' sedang tidak aktif. Silakan hubungi panitia."
                    });
                }

                var now = DateTime.Now;
                bool isLate = false;

                if (now < attendanceEvent.StartAt)
                {
                    return Ok(new QrScanResponse
                    {
                        Status = false,
                        ActionType = "Attendance",
                        Message = $"Absensi belum dibuka. Jadwal mulai: {attendanceEvent.StartAt:dd MMM yyyy HH:mm} WITA."
                    });
                }

                if (now > attendanceEvent.EndAt)
                {
                    if (now <= attendanceEvent.EndAt.AddHours(12))
                    {
                        isLate = true;
                    }
                    else
                    {
                        return Ok(new QrScanResponse
                        {
                            Status = false,
                            ActionType = "Attendance",
                            Message = "Absensi sudah ditutup (batas toleransi terlambat adalah 12 jam setelah acara selesai)."
                        });
                    }
                }

                // Check existing record
                var existingRecord = await _context.AttendanceRecords
                    .FirstOrDefaultAsync(r => r.AttendanceEventId == attendanceEvent.Id && r.Nik == userNik);

                if (existingRecord != null)
                {
                    return Ok(new QrScanResponse
                    {
                        Status = true,
                        ActionType = "Attendance",
                        Message = $"Absensi sudah pernah terekam pada {existingRecord.ScanAt:dd MMM yyyy HH:mm} WITA.",
                        Data = new
                        {
                            event_id = attendanceEvent.Id,
                            event_name = attendanceEvent.EventName,
                            event_location = attendanceEvent.EventLocation,
                            attendee_nik = userNik,
                            attendee_name = userName,
                            recorded_at = existingRecord.ScanAt.ToString("yyyy-MM-dd HH:mm:ss"),
                            is_duplicate = true
                        }
                    });
                }

                var record = new AttendanceRecord
                {
                    AttendanceEventId = attendanceEvent.Id,
                    Nik = userNik,
                    Nama = userName,
                    Jabatan = userJob,
                    Perusahaan = userComp,
                    ScanAt = DateTime.Now,
                    Source = isLate ? "late" : "mobile_qr",
                    Latitude = req.Latitude,
                    Longitude = req.Longitude
                };

                _context.AttendanceRecords.Add(record);
                await _context.SaveChangesAsync();

                _monitor.RecordTransaction(new TransactionEvent
                {
                    Type = "QR Absensi",
                    Source = "Mobile QR Scanner",
                    ServerId = record.Id,
                    Code = $"ATT-{record.Id}",
                    Nik = userNik,
                    Nama = userName,
                    Perusahaan = userComp,
                    Area = attendanceEvent.EventLocation ?? "HALL / MEETING ROOM",
                    Lokasi = attendanceEvent.EventName,
                    DetilLokasi = (req.Latitude.HasValue && req.Longitude.HasValue) ? $"[GPS: {req.Latitude.Value:F6}, {req.Longitude.Value:F6}]" : "Absensi Acara",
                    Latitude = req.Latitude,
                    Longitude = req.Longitude,
                    GpsAccuracy = req.Accuracy,
                    InspectionDate = DateTime.Today,
                    Status = isLate ? "Terlambat" : "Tepat Waktu",
                    Summary = $"Kehadiran: {attendanceEvent.EventName} ({(isLate ? "Terlambat" : "Tepat Waktu")})"
                });

                return Ok(new QrScanResponse
                {
                    Status = true,
                    ActionType = "Attendance",
                    Message = isLate ? "Kehadiran berhasil dicatat (Terlambat)." : "Kehadiran berhasil dicatat.",
                    Data = new
                    {
                        event_id = attendanceEvent.Id,
                        event_name = attendanceEvent.EventName,
                        event_location = attendanceEvent.EventLocation,
                        attendee_nik = userNik,
                        attendee_name = userName,
                        scan_at = record.ScanAt.ToString("yyyy-MM-dd HH:mm:ss"),
                        is_late = isLate
                    }
                });
            }

            // 2. Check if code matches an Employee NIK / Mine Permit Badge
            var cleanNik = rawCode.Trim();
            if (cleanNik.Contains(':'))
            {
                cleanNik = cleanNik.Split(':').Last().Trim();
            }
            else if (cleanNik.Contains('|'))
            {
                cleanNik = cleanNik.Split('|').Last().Trim();
            }

            if (cleanNik.StartsWith("IC", StringComparison.OrdinalIgnoreCase))
            {
                cleanNik = cleanNik.Substring(2).Trim();
            }

            var employee = await (from k in _context.Karyawans.AsNoTracking()
                                  join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                  join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                                  from c in cg.DefaultIfEmpty()
                                  join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                  from d in dg.DefaultIfEmpty()
                                  join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                                  from j in jg.DefaultIfEmpty()
                                  where k.NoNik == cleanNik || k.NoNik == rawCode
                                  select new
                                  {
                                      k.IdKaryawan,
                                      k.NoNik,
                                      p.NamaLengkap,
                                      Departemen = d != null ? d.NamaDepartemen : "GENERAL",
                                      Jabatan = j != null ? j.NamaJabatan : "Staff",
                                      Perusahaan = c != null ? c.NamaPerusahaan : "PT INDEXIM COALINDO",
                                      k.StatusAktif
                                  }).FirstOrDefaultAsync();

            if (employee != null)
            {
                return Ok(new QrScanResponse
                {
                    Status = true,
                    ActionType = "MinePermit",
                    Message = "Mine Permit / Profil Karyawan ditemukan.",
                    Data = new
                    {
                        nik = employee.NoNik,
                        nama = employee.NamaLengkap,
                        departemen = employee.Departemen,
                        jabatan = employee.Jabatan,
                        perusahaan = employee.Perusahaan,
                        status_aktif = employee.StatusAktif ? "AKTIF" : "NONAKTIF",
                        is_eligible = employee.StatusAktif
                    }
                });
            }

            // 3. Check if code matches a Vehicle Unit / Alat Berat
            var vehicle = await _context.P2hVehicles.AsNoTracking()
                .FirstOrDefaultAsync(v => v.NoLambung.ToLower() == rawCode.ToLower() && !v.IsDeleted);

            if (vehicle != null)
            {
                return Ok(new QrScanResponse
                {
                    Status = true,
                    ActionType = "Vehicle",
                    Message = "Unit Kendaraan / Alat Berat ditemukan.",
                    Data = new
                    {
                        unit_id = vehicle.Id,
                        no_lambung = vehicle.NoLambung,
                        jenis = vehicle.JenisKendaraan,
                        merek = vehicle.Merek
                    }
                });
            }

            // 4. Fallback general QR content
            return Ok(new QrScanResponse
            {
                Status = true,
                ActionType = "General",
                Message = "Kode berhasil dibaca.",
                Data = new
                {
                    raw_content = rawCode,
                    read_at = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }

        /// <summary>
        /// GET /api/qr/events
        /// Retrieves list of active attendance events that can be attended
        /// </summary>
        [HttpGet("events")]
        public async Task<IActionResult> GetActiveEvents()
        {
            var now = DateTime.Now;
            var events = await _context.AttendanceEvents
                .AsNoTracking()
                .Where(e => !e.IsDeleted && e.IsActive && e.EndAt >= now.AddHours(-12))
                .OrderBy(e => e.StartAt)
                .Select(e => new
                {
                    id = e.Id,
                    event_name = e.EventName,
                    event_location = e.EventLocation,
                    start_at = e.StartAt.ToString("yyyy-MM-dd HH:mm:ss"),
                    end_at = e.EndAt.ToString("yyyy-MM-dd HH:mm:ss"),
                    qr_token = e.QrToken
                })
                .ToListAsync();

            return Ok(new { status = true, data = events });
        }

        /// <summary>
        /// GET /api/qr/history
        /// Returns attendance records scanned by the current user
        /// </summary>
        [HttpGet("history")]
        public async Task<IActionResult> GetMyAttendanceHistory([FromQuery] int limit = 30)
        {
            var userNik = GetCurrentNik();
            var history = await (from r in _context.AttendanceRecords.AsNoTracking()
                                 join e in _context.AttendanceEvents.AsNoTracking() on r.AttendanceEventId equals e.Id
                                 where r.Nik == userNik
                                 orderby r.ScanAt descending
                                 select new
                                 {
                                     record_id = r.Id,
                                     event_name = e.EventName,
                                     event_location = e.EventLocation,
                                     scan_at = r.ScanAt.ToString("yyyy-MM-dd HH:mm:ss"),
                                     source = r.Source,
                                     latitude = r.Latitude,
                                     longitude = r.Longitude
                                 })
                                 .Take(limit)
                                 .ToListAsync();

            return Ok(new { status = true, data = history });
        }
    }
}
