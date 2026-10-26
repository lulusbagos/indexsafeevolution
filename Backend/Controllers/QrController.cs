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
        private readonly PermitService _permitService;

        public QrController(AppDbContext context, SyncMonitorService monitor, PermitService permitService)
        {
            _context = context;
            _monitor = monitor;
            _permitService = permitService;
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

            // Check User Scan Permissions in tbl_m_user_scan_permission
            var userPerm = await _context.UserScanPermissions
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Nik == userNik);

            bool canAcara = userPerm?.CanScanAcara ?? true; // Default: Semua orang bisa scan acara
            bool canMine = userPerm?.CanScanMinePermit ?? false; // Scan Detail Permit
            bool canPelanggaran = userPerm?.CanScanPermitPelanggaran ?? false; // Scan Pelanggaran Permit
            bool canKeluarMasuk = userPerm?.CanScanPermitKeluarMasuk ?? false; // Scan Keluar Masuk Permit
            bool canSimper = userPerm?.CanScanSimper ?? false;
            bool canComm = userPerm?.CanScanCommissioning ?? false;
            bool canSpecial = userPerm?.CanScanSpecialPermit ?? false;
            bool canOther = userPerm?.CanScanOther ?? false;

            var scanTarget = (req.ScanType ?? "Auto").Trim();
            bool isExplicitPermit = scanTarget.Equals("Mine Permit", StringComparison.OrdinalIgnoreCase) || scanTarget.Equals("Permit", StringComparison.OrdinalIgnoreCase);
            bool isExplicitEvent = scanTarget.Equals("Absen Acara", StringComparison.OrdinalIgnoreCase) || scanTarget.Equals("Attendance", StringComparison.OrdinalIgnoreCase) || scanTarget.Equals("Acara K3", StringComparison.OrdinalIgnoreCase);
            bool isExplicitVehicle = scanTarget.Equals("Vehicle", StringComparison.OrdinalIgnoreCase) || scanTarget.Equals("Kendaraan", StringComparison.OrdinalIgnoreCase);
            bool isExplicitPelanggaran = scanTarget.Equals("Pelanggaran", StringComparison.OrdinalIgnoreCase) || scanTarget.Equals("Pelanggaran K3", StringComparison.OrdinalIgnoreCase);

            // Extract token if code is a full URL (e.g. http://.../QrAttendance/Scan/{token})
            var token = rawCode;
            if (rawCode.Contains("/QrAttendance/Scan/", StringComparison.OrdinalIgnoreCase))
            {
                var idx = rawCode.IndexOf("/QrAttendance/Scan/", StringComparison.OrdinalIgnoreCase);
                token = rawCode.Substring(idx + "/QrAttendance/Scan/".Length).Trim();
                if (token.Contains('?')) token = token.Substring(0, token.IndexOf('?'));
            }

            // 1. Check if token matches an AttendanceEvent in DB_SAP (only if not explicitly Permit or Vehicle)
            if (!isExplicitPermit && !isExplicitVehicle)
            {
                var attendanceEvent = await _context.AttendanceEvents
                    .FirstOrDefaultAsync(e => e.QrToken == token && !e.IsDeleted);

                if (attendanceEvent != null)
                {
                    if (!canAcara)
                    {
                        return Ok(new QrScanResponse
                        {
                            Status = false,
                            ActionType = "Denied",
                            Message = "Otorisasi Terbatas: Akun Anda belum memiliki izin untuk memindai presensi Acara K3. Silakan hubungi Administrator K3 melalui menu Manajemen User Scan.",
                            Data = new
                            {
                                required_permission = "can_scan_acara",
                                module = "Presensi Acara K3",
                                is_authorized = false
                            }
                        });
                    }

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
            } // Close if (!isExplicitPermit && !isExplicitVehicle)

            if (isExplicitEvent)
            {
                return Ok(new QrScanResponse
                {
                    Status = false,
                    ActionType = "Attendance",
                    Message = "QR yang dipindai bukan merupakan kode presensi Acara K3 yang terdaftar."
                });
            }
            var cleanNik = rawCode.Trim();

            // 1b. Check if scanned code matches a SIMPER (by qr_encrypt, qr_decrypt, nomor, req_id, or NIK)
            bool isExplicitSimper = scanTarget.Equals("Simper", StringComparison.OrdinalIgnoreCase) || scanTarget.Equals("SIMPER", StringComparison.OrdinalIgnoreCase);
            SimperFullDetailDto? simperDetail = null;
            try
            {
                simperDetail = await _permitService.GetFullSimperDetailAsync(rawCode.Trim());
                if (simperDetail == null && (rawCode.Contains("SP/") || rawCode.Contains("/SP") || isExplicitSimper))
                {
                    simperDetail = await _permitService.GetFullSimperDetailAsync(cleanNik);
                }
            }
            catch (Exception exSimper)
            {
                Console.WriteLine($"[QrController] Error checking SIMPER: {exSimper.Message}");
            }

            if (simperDetail != null && (isExplicitSimper || simperDetail.QrEncrypt == rawCode.Trim() || simperDetail.QrDecrypt == rawCode.Trim() || simperDetail.Nomor == rawCode.Trim() || rawCode.Contains("==") || rawCode.Length >= 18 || rawCode.Contains("SP/")))
            {
                if (!canSimper && !canMine && !canPelanggaran && !canKeluarMasuk)
                {
                    return Ok(new QrScanResponse
                    {
                        Status = false,
                        ActionType = "Denied",
                        Message = "Otorisasi Terbatas: Anda belum memiliki wewenang verifikasi untuk modul SIMPER / Mine Permit. Hubungi Administrator K3 untuk aktivasi hak akses di menu Manajemen User Scan.",
                        Data = new
                        {
                            required_permission = "can_scan_simper",
                            module = "Verifikasi SIMPER",
                            is_authorized = false
                        }
                    });
                }

                var finalNik = simperDetail.EmployeeId;
                var simperEmp = await (from k in _context.Karyawans.AsNoTracking()
                                      join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                      join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                                      from c in cg.DefaultIfEmpty()
                                      join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                      from d in dg.DefaultIfEmpty()
                                      join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                                      from j in jg.DefaultIfEmpty()
                                      where k.NoNik == finalNik
                                      select new
                                      {
                                          k.IdKaryawan,
                                          k.NoNik,
                                          p.NamaLengkap,
                                          Departemen = d != null ? d.NamaDepartemen : "GENERAL",
                                          Jabatan = j != null ? j.NamaJabatan : "Staff",
                                          Perusahaan = c != null ? c.NamaPerusahaan : "PT INDEXIM COALINDO",
                                          k.StatusAktif,
                                          p.Hp1,
                                          p.EmailPribadi,
                                          p.JenisKelamin
                                      }).FirstOrDefaultAsync();

                var finalNama = simperEmp?.NamaLengkap ?? "Karyawan Tambang";
                var finalDept = !string.IsNullOrEmpty(simperDetail.Departemen) ? simperDetail.Departemen : (simperEmp?.Departemen ?? "-");
                var finalPerusahaan = simperEmp?.Perusahaan ?? "PT INDEXIM COALINDO";
                var finalJabatan = simperEmp?.Jabatan ?? "-";
                string photoUrl = $"/api/qr/permit/photo/{finalNik}";

                simperDetail.Nama = finalNama;
                simperDetail.Nik = finalNik;
                simperDetail.Departemen = finalDept;
                simperDetail.Perusahaan = finalPerusahaan;
                simperDetail.Jabatan = finalJabatan;
                simperDetail.Posisi = finalJabatan;
                simperDetail.Email = simperEmp?.EmailPribadi ?? "-";
                simperDetail.NoHp = simperEmp?.Hp1 ?? "-";
                simperDetail.JenisKelamin = simperEmp?.JenisKelamin ?? "-";
                simperDetail.Foto = photoUrl;
                simperDetail.PhotoUrl = photoUrl;
                simperDetail.CanInputPelanggaran = canPelanggaran;
                simperDetail.CanInputKeluarMasuk = canKeluarMasuk;

                return Ok(new QrScanResponse
                {
                    Status = true,
                    ActionType = "Simper",
                    Message = simperDetail.IsExpired ? "SIMPER telah habis masa berlaku!" : "Data SIMPER berhasil diverifikasi.",
                    Data = simperDetail
                });
            }

            // Extract last segment if code is a URL (e.g. http://.../permit/detail/24010091)
            if (cleanNik.Contains('/') && !cleanNik.Contains("/QrAttendance/Scan/", StringComparison.OrdinalIgnoreCase))
            {
                var segments = cleanNik.Split('/', StringSplitOptions.RemoveEmptyEntries);
                if (segments.Length > 0)
                {
                    var lastSeg = segments.Last().Trim();
                    if (lastSeg.Contains('?')) lastSeg = lastSeg.Substring(0, lastSeg.IndexOf('?')).Trim();
                    if (!string.IsNullOrEmpty(lastSeg))
                    {
                        cleanNik = lastSeg;
                    }
                }
            }

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

            string? matchedNikFromQr = null;
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State == System.Data.ConnectionState.Closed;
                if (wasClosed) await conn.OpenAsync();
                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT TOP 1 ttk.no_nik 
                        FROM [ONE_DB_MITRA].dbo.tbl_m_personal tmp 
                        JOIN [ONE_DB_MITRA].dbo.tbl_t_karyawan ttk on tmp.id_personal = ttk.id_personal 
                        JOIN [ONE_DB_MITRA].dbo.tbl_m_departemen tmd on ttk.id_departemen = tmd.id 
                        JOIN [ONE_DB_MITRA].dbo.tbl_m_perusahaan tmp2 on tmp2.id = ttk.id_perusahaan   
                        WHERE (CONCAT(tmp2.id, FORMAT(tmp.tanggal_lahir , 'yyyyMMdd'), FORMAT(ttk.date_of_hire , 'ddMMyyyy'), left(tmp.nama_lengkap, 3)) = @qrCode OR ttk.no_nik = @qrCode)
                          AND ttk.status_aktif = 1 AND tmp2.status_aktif = 1;
                    ";
                    var p = cmd.CreateParameter();
                    p.ParameterName = "@qrCode";
                    p.Value = rawCode.Trim();
                    cmd.Parameters.Add(p);

                    var res = await cmd.ExecuteScalarAsync();
                    if (res != null && res != DBNull.Value)
                    {
                        matchedNikFromQr = res.ToString();
                    }
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[QrController] Error checking ONE_DB_MITRA QR: {ex.Message}");
            }

            var targetNik = matchedNikFromQr ?? cleanNik;

            // 2. Query Mine Permit dari PostgreSQL Bima (tb_permit)
            var permit = await _permitService.GetFullPermitDetailAsync(targetNik)
                      ?? await _permitService.GetFullPermitDetailAsync(cleanNik)
                      ?? await _permitService.GetFullPermitDetailAsync(rawCode);

            // Cari data karyawan dari SQL Server (ONE_DB_MITRA / DB_SAP) sebagai fallback / pelengkap
            var employee = await (from k in _context.Karyawans.AsNoTracking()
                                  join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                  join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                                  from c in cg.DefaultIfEmpty()
                                  join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                  from d in dg.DefaultIfEmpty()
                                  join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                                  from j in jg.DefaultIfEmpty()
                                  where k.NoNik == targetNik || k.NoNik == cleanNik || k.NoNik == rawCode
                                  select new
                                  {
                                      k.IdKaryawan,
                                      k.NoNik,
                                      k.IdPerusahaan,
                                      p.NamaLengkap,
                                      Departemen = d != null ? d.NamaDepartemen : "GENERAL",
                                      Jabatan = j != null ? j.NamaJabatan : "Staff",
                                      Perusahaan = c != null ? c.NamaPerusahaan : "PT INDEXIM COALINDO",
                                      k.StatusAktif,
                                      p.Hp1,
                                      p.EmailPribadi,
                                      p.JenisKelamin
                                  }).FirstOrDefaultAsync();

            if (permit != null || employee != null)
            {
                if (!canMine && !canPelanggaran && !canKeluarMasuk && !canSimper)
                {
                    return Ok(new QrScanResponse
                    {
                        Status = false,
                        ActionType = "Denied",
                        Message = "Otorisasi Terbatas: Anda belum memiliki hak akses untuk memverifikasi Mine Permit maupun mencatat tindakan operasional (Keluar-Masuk / Pelanggaran). Silakan hubungi Administrator K3 untuk otorisasi di menu Manajemen User Scan.",
                        Data = new
                        {
                            required_permission = "can_scan_minepermit",
                            module = "Pemeriksaan Mine Permit",
                            is_authorized = false
                        }
                    });
                }

                var finalNik = permit?.Nik ?? employee?.NoNik ?? targetNik;
                var finalNama = permit?.Nama ?? employee?.NamaLengkap ?? "Karyawan Tambang";
                var finalDept = permit?.Departemen ?? employee?.Departemen ?? "-";
                var finalPerusahaan = permit?.Perusahaan ?? employee?.Perusahaan ?? "PT INDEXIM COALINDO";
                var finalJabatan = permit?.Jabatan ?? employee?.Jabatan ?? "-";
                var finalPosisi = permit?.Posisi ?? "-";
                var finalNomor = permit?.Nomor ?? "-";
                var finalTanggal = permit?.Tanggal ?? "-";
                var finalMasaAktif = permit?.MasaAktifPermit ?? "-";
                var finalAksesLokasi = permit?.AksesLokasi ?? "GNR";
                var finalStatus = permit?.Status ?? (employee?.StatusAktif == true ? "PRINTED" : "INACTIVE");
                var isExpired = permit?.IsExpired ?? false;
                var daysLeft = permit?.DaysLeft ?? 0;

                // Ambil foto karyawan dari vw_m_karyawan_aktif dan password overrides
                var kaView = await _context.MitraKaryawanAktifs.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == finalNik);
                var overridePwd = await _context.PasswordOverrides.AsNoTracking().FirstOrDefaultAsync(po => po.Nrp == finalNik);
                string photoUrl = $"/api/qr/permit/photo/{finalNik}";

                // Ambil data SIMPER yang terhubung
                PermitSimperDto? simperInfo = null;
                try
                {
                    simperInfo = await _permitService.GetLatestPermitSimperAsync(finalNik);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[QrController] Error fetching SIMPER for {finalNik}: {ex.Message}");
                }

                // Cek hierarki perusahaan untuk wewenang input pelanggaran:
                // Pengawas TIDAK BISA mencatat pelanggaran terhadap karyawan perusahaan Parent (atau Owner jika pengawas bukan Owner).
                // Hanya bisa mencatat untuk karyawan setara (perusahaan sendiri/selevel) atau perusahaan child-nya.
                var hierarchyCheck = await CheckViolationHierarchyPermissionAsync(userNik, finalNik, employee?.IdPerusahaan);
                bool canInputPelanggaranFinal = canPelanggaran && hierarchyCheck.CanViolate;

                if (isExplicitPelanggaran && !hierarchyCheck.CanViolate)
                {
                    return Ok(new QrScanResponse
                    {
                        Status = false,
                        ActionType = "Denied",
                        Message = hierarchyCheck.Reason,
                        Data = new
                        {
                            required_permission = "hierarchy_restriction",
                            module = "Pencatatan Pelanggaran K3",
                            relation = hierarchyCheck.Relation,
                            is_authorized = false
                        }
                    });
                }

                return Ok(new QrScanResponse
                {
                    Status = true,
                    ActionType = "MinePermit",
                    Message = isExpired ? "Mine Permit telah habis masa aktif!" : "Data Mine Permit berhasil diverifikasi.",
                    Data = new
                    {
                        nik = finalNik,
                        nama = finalNama,
                        nomor = finalNomor,
                        tanggal = finalTanggal,
                        masa_aktif_permit = finalMasaAktif,
                        days_left = daysLeft,
                        is_expired = isExpired,
                        status = finalStatus,
                        pengajuan = permit?.Pengajuan ?? "REGULER",
                        berakhir_kerja = permit?.BerakhirKerja ?? "-",
                        perusahaan = finalPerusahaan,
                        departemen = finalDept,
                        jabatan = finalJabatan,
                        posisi = finalPosisi,
                        email = permit?.Email ?? employee?.EmailPribadi ?? "-",
                        no_hp = employee?.Hp1 ?? "-",
                        jenis_kelamin = employee?.JenisKelamin ?? "-",
                        akses_lokasi = finalAksesLokasi,
                        foto = photoUrl,
                        photo_url = photoUrl,
                        has_simper = simperInfo?.HasSimper ?? false,
                        simper_nomor = simperInfo?.SimperNomor ?? "-",
                        jenis_simper = simperInfo?.JenisSimper ?? "-",
                        jenis_sim = simperInfo?.JenisSim ?? "-",
                        nomor_sim = simperInfo?.NomorSim ?? "-",
                        simper_masa_berlaku = simperInfo?.MasaBerlaku ?? simperInfo?.SimperExpiredDate ?? "-",
                        is_simper_active = simperInfo?.IsSimperActive ?? false,
                        simper_units = simperInfo?.Units ?? new List<SimperUnitDto>(),
                        can_input_pelanggaran = canInputPelanggaranFinal,
                        can_input_keluar_masuk = canKeluarMasuk,
                        can_view_detail = canMine,
                        hierarchy_violation_allowed = hierarchyCheck.CanViolate,
                        hierarchy_relation = hierarchyCheck.Relation,
                        hierarchy_restriction_reason = hierarchyCheck.CanViolate ? null : hierarchyCheck.Reason
                    }
                });
            }

            if (isExplicitPermit)
            {
                return Ok(new QrScanResponse
                {
                    Status = false,
                    ActionType = "MinePermit",
                    Message = $"Data Mine Permit atau Karyawan dengan kode '{rawCode}' tidak ditemukan di database."
                });
            }

            // 3. Check if code matches a Vehicle Unit / Alat Berat
            var vehicle = await _context.P2hVehicles.AsNoTracking()
                .FirstOrDefaultAsync(v => v.NoLambung.ToLower() == rawCode.ToLower() && !v.IsDeleted);

            if (vehicle != null)
            {
                if (!canComm)
                {
                    return Ok(new QrScanResponse
                    {
                        Status = false,
                        ActionType = "Denied",
                        Message = "Otorisasi Terbatas: Akun Anda belum diberi wewenang untuk inspeksi Commissioning Unit Kendaraan / Alat Berat. Hubungi Administrator K3 untuk pengajuan akses.",
                        Data = new
                        {
                            required_permission = "can_scan_commissioning",
                            module = "Commissioning Unit",
                            is_authorized = false
                        }
                    });
                }

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

            // 4. Fallback intelligent classification for unrecognized or external QR content
            bool isUrl = Uri.TryCreate(rawCode, UriKind.Absolute, out var uriResult) 
                         && (uriResult?.Scheme == Uri.UriSchemeHttp || uriResult?.Scheme == Uri.UriSchemeHttps);
            bool isInternalDomain = isUrl && uriResult != null && 
                (uriResult.Host.EndsWith("indexim.id", StringComparison.OrdinalIgnoreCase) || uriResult.Host.Contains("192.168.") || uriResult.Host.Contains("127.0.0.1"));

            string scanCategory;
            string smartMessage;
            string previewSnippet = rawCode.Length > 200 ? rawCode.Substring(0, 197) + "..." : rawCode;

            if (isUrl)
            {
                scanCategory = isInternalDomain ? "Tautan Internal Indexim" : "Tautan Web Eksternal (Luar Sistem)";
                smartMessage = isInternalDomain
                    ? "Kode QR terdeteksi sebagai tautan portal web Indexim, namun bukan merupakan token registrasi QR scanner operasional (Mine Permit, SIMPER, Presensi, atau Stiker Unit)."
                    : "Kode QR terdeteksi sebagai tautan publik eksternal yang berada di luar ekosistem operasional PT Indexim Coalindo.";
            }
            else
            {
                scanCategory = "Kode Non-Sistem";
                smartMessage = "Kode yang dipindai tidak terdaftar dalam database operasional Indexsafe (Bukan format resmi Mine Permit, SIMPER karyawan, Presensi Acara K3, atau Stiker Unit Commissioning).";
            }

            return Ok(new QrScanResponse
            {
                Status = false,
                ActionType = "UnrecognizedQr",
                Message = smartMessage,
                Data = new
                {
                    raw_content = rawCode,
                    snippet = previewSnippet,
                    is_url = isUrl,
                    url = isUrl ? rawCode : null,
                    category = scanCategory,
                    hint = "Pastikan Anda memindai QR resmi Mine Permit, SIMPER karyawan, barcode Presensi Acara K3, atau Stiker QR Unit Commissioning PT Indexim Coalindo.",
                    scanned_at = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
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
            var today = DateTime.Today;
            var userNik = GetCurrentNik();

            // Ambil semua event asli dari tbl_t_attendance_event
            var events = await _context.AttendanceEvents
                .AsNoTracking()
                .Where(e => !e.IsDeleted)
                .OrderByDescending(e => e.StartAt)
                .Select(e => new
                {
                    id = e.Id,
                    event_name = e.EventName,
                    event_location = e.EventLocation,
                    event_description = e.EventDescription,
                    start_at = e.StartAt.ToString("yyyy-MM-dd HH:mm:ss"),
                    end_at = e.EndAt.ToString("yyyy-MM-dd HH:mm:ss"),
                    qr_token = e.QrToken,
                    is_active = e.IsActive,
                    total_attendees = e.AttendanceRecords.Count,
                    is_attended = e.AttendanceRecords.Any(r => r.Nik == userNik),
                    attended_at = e.AttendanceRecords
                        .Where(r => r.Nik == userNik)
                        .OrderByDescending(r => r.ScanAt)
                        .Select(r => r.ScanAt.ToString("yyyy-MM-dd HH:mm:ss"))
                        .FirstOrDefault(),
                    is_today = e.StartAt.Date == today || e.EndAt.Date == today || (today >= e.StartAt.Date && today <= e.EndAt.Date),
                    is_ongoing = now >= e.StartAt && now <= e.EndAt,
                    status_state = (now >= e.StartAt && now <= e.EndAt) ? "ongoing" :
                                   (now < e.StartAt) ? "upcoming" :
                                   (now <= e.EndAt.AddHours(12)) ? "late_allowed" : "closed"
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

        /// <summary>
        /// GET /api/qr/my-permissions
        /// Returns scanning permissions for currently logged-in user
        /// </summary>
        [HttpGet("my-permissions")]
        public async Task<IActionResult> GetMyPermissions()
        {
            var userNik = GetCurrentNik();
            if (string.IsNullOrWhiteSpace(userNik))
            {
                return Unauthorized(new { status = false, message = "Sesi tidak valid." });
            }

            var perm = await _context.UserScanPermissions
                .FirstOrDefaultAsync(p => p.Nik == userNik);

            // Jika belum ada di tbl_m_user_scan_permission, otomatis create record default (CanScanAcara = true)
            // Menjamin user pertama kali buka modul scan otomatis dapat izin scan acara
            if (perm == null)
            {
                try
                {
                    var userName = GetCurrentName();
                    var userDept = GetCurrentDepartment();
                    var userComp = GetCurrentCompany();

                    perm = new UserScanPermission
                    {
                        Nik = userNik,
                        Nama = userName,
                        Departemen = userDept,
                        Perusahaan = userComp,
                        CanScanAcara = true, // Default: Semua user otomatis mendapat modul scan acara
                        CanScanMinePermit = false,
                        CanScanPermitPelanggaran = false,
                        CanScanPermitKeluarMasuk = false,
                        CanScanSimper = false,
                        CanScanCommissioning = false,
                        CanScanSpecialPermit = false,
                        CanScanOther = false,
                        UpdatedAt = DateTime.Now,
                        UpdatedBy = "System (Auto Provision)"
                    };
                    _context.UserScanPermissions.Add(perm);
                    await _context.SaveChangesAsync();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[QrController] Error auto-creating UserScanPermission: {ex.Message}");
                }
            }

            return Ok(new
            {
                status = true,
                data = new
                {
                    nik = userNik,
                    can_scan_acara = perm?.CanScanAcara ?? true, // Default: Semua orang bisa scan acara
                    can_scan_minepermit = perm?.CanScanMinePermit ?? false, // Scan Detail Permit
                    can_scan_permit_pelanggaran = perm?.CanScanPermitPelanggaran ?? false, // Scan Pelanggaran Permit
                    can_scan_permit_keluar_masuk = perm?.CanScanPermitKeluarMasuk ?? false, // Scan Keluar Masuk Permit
                    can_scan_simper = perm?.CanScanSimper ?? false,
                    can_scan_commissioning = perm?.CanScanCommissioning ?? false,
                    can_scan_special_permit = perm?.CanScanSpecialPermit ?? false,
                    can_scan_other = perm?.CanScanOther ?? false
                }
            });
        }

        /// <summary>
        /// GET /api/qr/permit/violation-master
        /// Returns Safety criteria (tbl_m_pelanggaran_kriteria) and Safety sanction types (tbl_m_pelanggaran_jenis where jenis='SAFETY')
        /// </summary>
        [HttpGet("permit/violation-master")]
        public async Task<IActionResult> GetViolationMaster()
        {
            var kriteriaList = new List<object>();
            var sanksiList = new List<object>();

            try
            {
                var conn = _context.Database.GetDbConnection();
                if (conn.State != System.Data.ConnectionState.Open)
                {
                    await conn.OpenAsync();
                }

                // 1. Get Kriteria
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = @"
                        SELECT id, urutan, kode, nama, kategori 
                        FROM [ONE_DB_MITRA].[dbo].[tbl_m_pelanggaran_kriteria]
                        WHERE is_active = 1
                        ORDER BY urutan ASC, id ASC;";

                    using (var reader = await cmd.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            kriteriaList.Add(new
                            {
                                id = reader.GetInt32(0),
                                urutan = reader.GetInt32(1),
                                kode = reader.IsDBNull(2) ? "" : reader.GetString(2),
                                nama = reader.GetString(3),
                                kategori = reader.GetString(4)
                            });
                        }
                    }
                }

                // 2. Get Jenis Pelanggaran (SAFETY only)
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = @"
                        SELECT id, kode_pelanggaran, nama, jenis, keterangan, durasi, jenis_durasi 
                        FROM [ONE_DB_MITRA].[dbo].[tbl_m_pelanggaran_jenis]
                        WHERE UPPER(jenis) = 'SAFETY' AND deleted_at IS NULL
                        ORDER BY id ASC;";

                    using (var reader = await cmd.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            sanksiList.Add(new
                            {
                                id = reader.GetInt32(0),
                                kode = reader.IsDBNull(1) ? "" : reader.GetString(1),
                                nama = reader.GetString(2),
                                jenis = reader.GetString(3),
                                keterangan = reader.IsDBNull(4) ? "" : reader.GetString(4),
                                durasi = reader.IsDBNull(5) ? (int?)null : reader.GetInt32(5),
                                jenis_durasi = reader.IsDBNull(6) ? "" : reader.GetString(6)
                            });
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GetViolationMaster] Error: {ex.Message}");
            }

            return Ok(new
            {
                status = true,
                data = new
                {
                    kriteria = kriteriaList,
                    jenis_sanksi = sanksiList
                }
            });
        }

        /// <summary>
        /// POST /api/qr/permit/violation
        /// Records a safety violation against an employee into [ONE_DB_MITRA].[dbo].[tbl_t_karyawan_pelanggaran]
        /// </summary>
        [HttpPost("permit/violation")]
        public async Task<IActionResult> RecordPermitViolation([FromBody] CreatePermitViolationRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.ViolatorNik) || string.IsNullOrWhiteSpace(req.ViolationDescription))
            {
                return BadRequest(new { status = false, message = "NIK Pelanggar dan Deskripsi Pelanggaran wajib diisi." });
            }

            var userNik = GetCurrentNik();
            var userName = GetCurrentName();

            var userPerm = await _context.UserScanPermissions
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Nik == userNik);

            bool canPelanggaran = userPerm?.CanScanPermitPelanggaran ?? false;
            if (!canPelanggaran)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    status = false,
                    message = "Otorisasi Terbatas: Anda belum memiliki wewenang untuk mencatat pelanggaran K3 Mine Permit. Silakan hubungi Administrator K3 untuk pengajuan otorisasi."
                });
            }

            // Validasi Hierarki Perusahaan: Pemeriksa dilarang mencatat pelanggaran terhadap Parent Company
            var hierCheck = await CheckViolationHierarchyPermissionAsync(userNik, req.ViolatorNik);
            if (!hierCheck.CanViolate)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    status = false,
                    message = hierCheck.Reason
                });
            }

            int? newMitraPelanggaranId = null;
            DateTime tglKejadian = req.TanggalKejadian ?? DateTime.Today;
            DateTime? tglKadaluarsa = null;
            int idPelanggaranJenis = req.IdPelanggaranJenis ?? 6; // default Lubang 1 / SP-1 (6)

            try
            {
                var conn = _context.Database.GetDbConnection();
                if (conn.State != System.Data.ConnectionState.Open)
                {
                    await conn.OpenAsync();
                }

                // 1. Resolve id_karyawan from ONE_DB_MITRA
                int? idKaryawan = null;
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = @"
                        SELECT TOP 1 id_karyawan 
                        FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan 
                        WHERE no_nik = @nik 
                        ORDER BY status_aktif DESC, id_karyawan DESC;";
                    var pNik = cmd.CreateParameter();
                    pNik.ParameterName = "@nik";
                    pNik.Value = req.ViolatorNik.Trim();
                    cmd.Parameters.Add(pNik);

                    var scalar = await cmd.ExecuteScalarAsync();
                    if (scalar != null && scalar != DBNull.Value)
                    {
                        idKaryawan = Convert.ToInt32(scalar);
                    }
                }

                if (!idKaryawan.HasValue)
                {
                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = @"
                            SELECT TOP 1 id_karyawan 
                            FROM [ONE_DB_MITRA].dbo.vw_m_karyawan_aktif 
                            WHERE no_nik = @nik;";
                        var pNik = cmd.CreateParameter();
                        pNik.ParameterName = "@nik";
                        pNik.Value = req.ViolatorNik.Trim();
                        cmd.Parameters.Add(pNik);

                        var scalar = await cmd.ExecuteScalarAsync();
                        if (scalar != null && scalar != DBNull.Value)
                        {
                            idKaryawan = Convert.ToInt32(scalar);
                        }
                    }
                }

                // 2. Resolve id_pelanggaran_jenis duration & calculate tanggal_kadaluarsa
                int durasiBulan = 0;
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = @"
                        SELECT TOP 1 id, durasi, jenis_durasi 
                        FROM [ONE_DB_MITRA].dbo.tbl_m_pelanggaran_jenis 
                        WHERE id = @idJenis;";
                    var pId = cmd.CreateParameter();
                    pId.ParameterName = "@idJenis";
                    pId.Value = idPelanggaranJenis;
                    cmd.Parameters.Add(pId);

                    using (var r = await cmd.ExecuteReaderAsync())
                    {
                        if (await r.ReadAsync())
                        {
                            idPelanggaranJenis = r.GetInt32(0);
                            if (!r.IsDBNull(1))
                            {
                                int d = r.GetInt32(1);
                                string jd = r.IsDBNull(2) ? "" : r.GetString(2);
                                if (jd.ToLower().Contains("month"))
                                    durasiBulan = d;
                                else if (jd.ToLower().Contains("year"))
                                    durasiBulan = d * 12;
                            }
                        }
                    }
                }

                if (durasiBulan > 0)
                {
                    tglKadaluarsa = tglKejadian.AddMonths(durasiBulan);
                }

                // 3. Format keterangan
                var kriteria = !string.IsNullOrWhiteSpace(req.KriteriaNama)
                    ? req.KriteriaNama.Trim()
                    : (!string.IsNullOrWhiteSpace(req.ViolationType) ? req.ViolationType.Trim() : "Pelanggaran Safety");

                var sbKet = new System.Text.StringBuilder();
                sbKet.Append($"Kriteria: {kriteria}");
                if (!string.IsNullOrWhiteSpace(req.ViolationLocation))
                    sbKet.Append($" | Lokasi: {req.ViolationLocation.Trim()}");
                if (!string.IsNullOrWhiteSpace(req.ViolationDescription))
                    sbKet.Append($" | Remark: {req.ViolationDescription.Trim()}");
                if (!string.IsNullOrWhiteSpace(req.ActionTaken))
                    sbKet.Append($" | Penindakan: {req.ActionTaken.Trim()}");
                if (!string.IsNullOrWhiteSpace(req.PermitNumber))
                    sbKet.Append($" | No Permit: {req.PermitNumber.Trim()}");

                var createdBy = $"{userNik} | mobile";
                var createdAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");

                // 4. Insert into [ONE_DB_MITRA].[dbo].[tbl_t_karyawan_pelanggaran]
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = @"
                        INSERT INTO [ONE_DB_MITRA].[dbo].[tbl_t_karyawan_pelanggaran] (
                            id_karyawan,
                            tanggal_kejadian,
                            tanggal_surat,
                            tanggal_kadaluarsa,
                            id_pelanggaran_jenis,
                            keterangan,
                            file_pendukung,
                            created_by,
                            created_at
                        ) VALUES (
                            @id_karyawan,
                            @tanggal_kejadian,
                            @tanggal_surat,
                            @tanggal_kadaluarsa,
                            @id_pelanggaran_jenis,
                            @keterangan,
                            @file_pendukung,
                            @created_by,
                            @created_at
                        );
                        SELECT SCOPE_IDENTITY();";

                    var p1 = cmd.CreateParameter(); p1.ParameterName = "@id_karyawan"; p1.Value = (object?)idKaryawan ?? DBNull.Value; cmd.Parameters.Add(p1);
                    var p2 = cmd.CreateParameter(); p2.ParameterName = "@tanggal_kejadian"; p2.Value = tglKejadian.Date; cmd.Parameters.Add(p2);
                    var p3 = cmd.CreateParameter(); p3.ParameterName = "@tanggal_surat"; p3.Value = tglKejadian.Date; cmd.Parameters.Add(p3);
                    var p4 = cmd.CreateParameter(); p4.ParameterName = "@tanggal_kadaluarsa"; p4.Value = (object?)tglKadaluarsa?.Date ?? DBNull.Value; cmd.Parameters.Add(p4);
                    var p5 = cmd.CreateParameter(); p5.ParameterName = "@id_pelanggaran_jenis"; p5.Value = idPelanggaranJenis; cmd.Parameters.Add(p5);
                    var p6 = cmd.CreateParameter(); p6.ParameterName = "@keterangan"; p6.Value = sbKet.ToString(); cmd.Parameters.Add(p6);
                    var p7 = cmd.CreateParameter(); p7.ParameterName = "@file_pendukung"; p7.Value = (object?)req.PhotoUrl ?? DBNull.Value; cmd.Parameters.Add(p7);
                    var p8 = cmd.CreateParameter(); p8.ParameterName = "@created_by"; p8.Value = createdBy; cmd.Parameters.Add(p8);
                    var p9 = cmd.CreateParameter(); p9.ParameterName = "@created_at"; p9.Value = createdAt; cmd.Parameters.Add(p9);

                    var idScalar = await cmd.ExecuteScalarAsync();
                    if (idScalar != null && idScalar != DBNull.Value)
                    {
                        newMitraPelanggaranId = Convert.ToInt32(idScalar);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[RecordPermitViolation] Error writing to ONE_DB_MITRA: {ex.Message}");
            }

            // Also keep local audit log
            var violation = new PermitViolation
            {
                ViolatorNik = req.ViolatorNik.Trim(),
                ViolatorName = req.ViolatorName,
                ViolatorCompany = req.ViolatorCompany,
                ViolatorDepartment = req.ViolatorDepartment,
                PermitNumber = req.PermitNumber,
                ViolationType = string.IsNullOrWhiteSpace(req.KriteriaNama) ? req.ViolationType : req.KriteriaNama,
                ViolationDescription = req.ViolationDescription,
                ViolationLocation = req.ViolationLocation,
                PhotoUrl = req.PhotoUrl,
                Severity = string.IsNullOrWhiteSpace(req.Severity) ? "Medium" : req.Severity,
                ActionTaken = req.ActionTaken,
                ReportedByNik = $"{userNik} | mobile",
                ReportedByName = userName,
                CreatedAt = DateTime.Now
            };

            _context.PermitViolations.Add(violation);
            await _context.SaveChangesAsync();

            // Create in-app notification for the scanned employee
            try
            {
                var notifViolation = new Notification
                {
                    RecipientNik = req.ViolatorNik.Trim(),
                    Title = "Peringatan Catatan Pelanggaran K3",
                    Message = $"Anda tercatat melakukan pelanggaran K3: '{violation.ViolationType}' di {violation.ViolationLocation ?? "Area Operasional"}. Tindakan: {violation.ActionTaken ?? "Teguran & Pencatatan"}. Dicatat oleh Petugas {violation.ReportedByName} ({violation.ReportedByNik}).",
                    Url = $"/Permit/Violation/{violation.Id}",
                    NotifType = "permit_violation",
                    Category = "violation",
                    SenderName = violation.ReportedByName ?? "Petugas K3 / Security",
                    Priority = "urgent",
                    ActionText = "Lihat Detail",
                    IsRead = false,
                    IsActioned = false,
                    CreatedAt = DateTime.Now
                };
                _context.Notifications.Add(notifViolation);
                await _context.SaveChangesAsync();
            }
            catch (Exception notifEx)
            {
                Console.WriteLine($"[RecordPermitViolation] Failed to create notification: {notifEx.Message}");
            }

            return Ok(new
            {
                status = true,
                message = "Pelanggaran K3 berhasil dicatat resmi ke database karyawan.",
                data = new
                {
                    id = newMitraPelanggaranId ?? violation.Id,
                    mitra_pelanggaran_id = newMitraPelanggaranId,
                    violator_nik = violation.ViolatorNik,
                    violator_name = violation.ViolatorName,
                    violation_type = violation.ViolationType,
                    severity = violation.Severity,
                    created_by = $"{userNik} | mobile",
                    created_at = violation.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }

        /// <summary>
        /// POST /api/qr/permit/movement
        /// Records employee gate check-in / check-out with vehicle unit and purpose
        /// </summary>
        [HttpPost("permit/movement")]
        public async Task<IActionResult> RecordPermitMovement([FromBody] CreatePermitMovementRequest req)
        {
            if (string.IsNullOrWhiteSpace(req.Nik) || string.IsNullOrWhiteSpace(req.Keperluan))
            {
                return BadRequest(new { status = false, message = "NIK Karyawan dan Keperluan Keluar/Masuk wajib diisi." });
            }

            var userNik = GetCurrentNik();
            var userName = GetCurrentName();

            var userPerm = await _context.UserScanPermissions
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Nik == userNik);

            bool canKeluarMasuk = userPerm?.CanScanPermitKeluarMasuk ?? false;
            if (!canKeluarMasuk)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    status = false,
                    message = "Otorisasi Terbatas: Anda belum memiliki wewenang untuk mencatat lalu lintas keluar/masuk pos permit. Silakan hubungi Administrator K3 untuk pengajuan otorisasi."
                });
            }

            var log = new PermitGateLog
            {
                Nik = req.Nik.Trim(),
                Nama = req.Nama,
                Perusahaan = req.Perusahaan,
                Departemen = req.Departemen,
                NomorPermit = req.NomorPermit,
                Direction = string.Equals(req.Direction, "KELUAR", StringComparison.OrdinalIgnoreCase) ? "KELUAR" : "MASUK",
                NomorUnit = req.NomorUnit?.Trim(),
                Keperluan = req.Keperluan.Trim(),
                LokasiPos = string.IsNullOrWhiteSpace(req.LokasiPos) ? "Pos Security Utama" : req.LokasiPos.Trim(),
                Latitude = req.Latitude,
                Longitude = req.Longitude,
                DetilLokasi = req.DetilLokasi ?? ((req.Latitude.HasValue && req.Longitude.HasValue) ? $"[GPS: {req.Latitude.Value:F6}, {req.Longitude.Value:F6}]" : null),
                CreatedByNik = userNik,
                CreatedByName = userName,
                CreatedAt = DateTime.Now
            };

            _context.PermitGateLogs.Add(log);
            await _context.SaveChangesAsync();

            _monitor.RecordTransaction(new TransactionEvent
            {
                Type = "Permit In/Out",
                Source = "Mobile QR Gate Scanner",
                ServerId = log.Id,
                Code = $"GATE-{log.Id}",
                Nik = log.Nik,
                Nama = log.Nama ?? log.Nik,
                Perusahaan = log.Perusahaan ?? "MITRA KERJA",
                Area = log.LokasiPos ?? "POS SECURITY",
                Lokasi = log.LokasiPos ?? "Pintu Masuk/Keluar",
                DetilLokasi = log.DetilLokasi ?? $"Arah: {log.Direction} | Unit: {log.NomorUnit ?? "-"}",
                Latitude = log.Latitude,
                Longitude = log.Longitude,
                InspectionDate = DateTime.Today,
                Status = log.Direction,
                Summary = $"Lalu Lintas {log.Direction}: {log.Nama} ({log.Nik}) - Pos {log.LokasiPos}"
            });

            // Create in-app notification for the scanned employee
            try
            {
                var notifMovement = new Notification
                {
                    RecipientNik = req.Nik.Trim(),
                    Title = $"Pencatatan Gerbang: {log.Direction} Tambang",
                    Message = $"Anda tercatat {log.Direction} melalui {log.LokasiPos} pada {log.CreatedAt:dd/MM/yyyy HH:mm} WITA. Keperluan: {log.Keperluan}{(string.IsNullOrWhiteSpace(log.NomorUnit) ? "" : $" | Unit: {log.NomorUnit}")}. Dicatat oleh Petugas {log.CreatedByName}.",
                    Url = $"/Permit/Movement/{log.Id}",
                    NotifType = "permit_gate_movement",
                    Category = "movement",
                    SenderName = log.CreatedByName ?? "Petugas Security Gate",
                    Priority = "normal",
                    ActionText = "Lihat Riwayat",
                    IsRead = false,
                    IsActioned = false,
                    CreatedAt = DateTime.Now
                };
                _context.Notifications.Add(notifMovement);
                await _context.SaveChangesAsync();
            }
            catch (Exception notifEx)
            {
                Console.WriteLine($"[RecordPermitMovement] Failed to create notification: {notifEx.Message}");
            }

            return Ok(new
            {
                status = true,
                message = $"Pergerakan {log.Direction} karyawan berhasil dicatat.",
                data = new
                {
                    id = log.Id,
                    nik = log.Nik,
                    nama = log.Nama,
                    direction = log.Direction,
                    nomor_unit = log.NomorUnit,
                    keperluan = log.Keperluan,
                    lokasi_pos = log.LokasiPos,
                    latitude = log.Latitude,
                    longitude = log.Longitude,
                    detil_lokasi = log.DetilLokasi,
                    created_at = log.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }

        /// <summary>
        /// GET /api/qr/permit/photo/{nik}
        /// Returns official Mine Permit / Employee photo from Indexsafemission / Bima database
        /// </summary>
        [HttpGet("permit/photo/{nik}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetPermitPhoto(string nik)
        {
            if (string.IsNullOrWhiteSpace(nik))
            {
                return NotFound("NIK is required");
            }

            var nikClean = nik.Trim();
            var permit = await _permitService.GetLatestPermitSimperAsync(nikClean);

            var candidatePaths = new List<string>();
            if (permit != null)
            {
                if (!string.IsNullOrWhiteSpace(permit.CardPhotoPath)) candidatePaths.Add(permit.CardPhotoPath);
                if (!string.IsNullOrWhiteSpace(permit.CardPhotoScanPath)) candidatePaths.Add(permit.CardPhotoScanPath);
                if (!string.IsNullOrWhiteSpace(permit.PermitDocPhotoPath)) candidatePaths.Add(permit.PermitDocPhotoPath);
            }

            // Juga coba dari ONE_DB_MITRA (vw_m_karyawan_aktif)
            var kaView = await _context.MitraKaryawanAktifs.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == nikClean);
            if (kaView != null && !string.IsNullOrWhiteSpace(kaView.PathFoto))
            {
                candidatePaths.Add(kaView.PathFoto);
            }

            var rootDrives = new[]
            {
                @"C:\MinePermitFiles",
                @"D:\MinePermitFiles",
                @"C:\MinePermitFiles\ONEDBEV",
                @"D:\4. PROJECT\2. Web\Indexsavemission\indexsafemission"
            };

            foreach (var rawPath in candidatePaths)
            {
                if (string.IsNullOrWhiteSpace(rawPath)) continue;

                var clean = rawPath.Replace("~", "\\").Trim();

                // 1. Cek langsung file path fisik
                if (System.IO.File.Exists(clean))
                {
                    return PhysicalFile(clean, GetMimeType(clean));
                }

                // 2. Cek drive swap D: <-> C:
                if (clean.Length > 2 && clean[1] == ':')
                {
                    var altDrive = clean.StartsWith("D:", StringComparison.OrdinalIgnoreCase)
                        ? "C:" + clean.Substring(2)
                        : "D:" + clean.Substring(2);
                    if (System.IO.File.Exists(altDrive))
                    {
                        return PhysicalFile(altDrive, GetMimeType(altDrive));
                    }
                }

                // 3. Cek kombinasi dengan rootDrives
                var arr = clean.Split(new[] { '\\', '/' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var root in rootDrives)
                {
                    var testPath = Path.Combine(root, clean.TrimStart('\\', '/'));
                    if (System.IO.File.Exists(testPath))
                    {
                        return PhysicalFile(testPath, GetMimeType(testPath));
                    }

                    // Slicing arr[2..] seperti di ApiIndexsafemission
                    if (arr.Length >= 3)
                    {
                        var sliced = Path.Combine(root, string.Join("\\", arr.Skip(2)));
                        if (System.IO.File.Exists(sliced))
                        {
                            return PhysicalFile(sliced, GetMimeType(sliced));
                        }
                    }

                    // Filename saja
                    var fn = Path.GetFileName(clean);
                    var testFn = Path.Combine(root, fn);
                    if (System.IO.File.Exists(testFn))
                    {
                        return PhysicalFile(testFn, GetMimeType(testFn));
                    }
                }

                // 4. Jika file berada di API Indexsafemission (remote/local port)
                if (clean.Contains("IDCARD_PHOTO") || clean.Contains("CARD") || clean.Contains("FOTO"))
                {
                    var remoteUrls = new[]
                    {
                        $"http://localhost:5266/api/Attachment/file/byfilename/{clean.Replace("\\", "~")}",
                        $"http://172.16.1.96:5266/api/Attachment/file/byfilename/{clean.Replace("\\", "~")}",
                        $"https://localhost:7274/api/Attachment/file/byfilename/{clean.Replace("\\", "~")}"
                    };
                    using var httpClient = new System.Net.Http.HttpClient { Timeout = TimeSpan.FromSeconds(3) };
                    foreach (var url in remoteUrls)
                    {
                        try
                        {
                            var resp = await httpClient.GetAsync(url);
                            if (resp.IsSuccessStatusCode)
                            {
                                var bytes = await resp.Content.ReadAsByteArrayAsync();
                                var cType = resp.Content.Headers.ContentType?.MediaType ?? "image/jpeg";
                                return File(bytes, cType);
                            }
                        }
                        catch { }
                    }
                }
            }

            // 5. Cek via FTP repository (Indexsafemission source)
            var ftpCachedFile = await TryFetchPhotoFromFtpAsync(nikClean);
            if (!string.IsNullOrEmpty(ftpCachedFile) && System.IO.File.Exists(ftpCachedFile))
            {
                return PhysicalFile(ftpCachedFile, GetMimeType(ftpCachedFile));
            }

            // 6. Cek file karyawan di ONEDBEV jika ada
            try
            {
                if (Directory.Exists(@"C:\MinePermitFiles\ONEDBEV"))
                {
                    var matches = Directory.GetFiles(@"C:\MinePermitFiles\ONEDBEV", $"*{nikClean}*.*", SearchOption.AllDirectories)
                        .Where(f => f.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase) || f.EndsWith(".png", StringComparison.OrdinalIgnoreCase) || f.EndsWith(".jpeg", StringComparison.OrdinalIgnoreCase))
                        .ToList();
                    if (matches.Any())
                    {
                        return PhysicalFile(matches.First(), GetMimeType(matches.First()));
                    }
                }
            }
            catch { }

            // 7. Jika tidak ada foto resmi Mine Permit dari Indexsafemission, kembalikan 404 (jangan pakai foto avatar pemandangan)
            return NotFound("Foto Mine Permit resmi karyawan tidak ditemukan di sistem Indexsafemission.");
        }

        private async Task<string?> TryFetchPhotoFromFtpAsync(string nikClean)
        {
            try
            {
                var cacheDir = @"C:\MinePermitFiles\CARD\Cache";
                if (!Directory.Exists(cacheDir))
                {
                    Directory.CreateDirectory(cacheDir);
                }

                var localCachedPath = Path.Combine(cacheDir, $"{nikClean}_permit.jpg");
                if (System.IO.File.Exists(localCachedPath))
                {
                    return localCachedPath;
                }

                int? idPersonal = null;
                int? idPerusahaan = null;
                string? pathFoto = null;

                var kaView = await _context.MitraKaryawanAktifs.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == nikClean);
                if (kaView != null)
                {
                    idPersonal = kaView.IdPersonal;
                    idPerusahaan = kaView.IdPerusahaan;
                    pathFoto = kaView.PathFoto;
                }

                const string ftpUser = "onedb_kary";
                const string ftpPass = "x0r4ngIDC#apps@2023";

                // A. Cek /karyawan/{md5(idPersonal)}/
                if (idPersonal.HasValue && idPersonal.Value > 0)
                {
                    string hash;
                    using (var md5 = System.Security.Cryptography.MD5.Create())
                    {
                        var bytes = System.Text.Encoding.UTF8.GetBytes(idPersonal.Value.ToString());
                        hash = string.Concat(md5.ComputeHash(bytes).Select(b => b.ToString("x2")));
                    }

                    var dirUrl = $"ftp://192.168.125.234/karyawan/{hash}/";
                    var listReq = (System.Net.FtpWebRequest)System.Net.WebRequest.Create(dirUrl);
                    listReq.Credentials = new System.Net.NetworkCredential(ftpUser, ftpPass);
                    listReq.Method = System.Net.WebRequestMethods.Ftp.ListDirectory;
                    listReq.Timeout = 4000;

                    string[] fileList = Array.Empty<string>();
                    try
                    {
                        using var listResp = (System.Net.FtpWebResponse)await listReq.GetResponseAsync();
                        using var reader = new StreamReader(listResp.GetResponseStream());
                        var content = await reader.ReadToEndAsync();
                        fileList = content.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries);
                    }
                    catch { }

                    var photoFile = fileList.FirstOrDefault(f => f.Contains("FOTO", StringComparison.OrdinalIgnoreCase)
                                                             || f.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase)
                                                             || f.EndsWith(".png", StringComparison.OrdinalIgnoreCase)
                                                             || f.EndsWith(".jpeg", StringComparison.OrdinalIgnoreCase));

                    if (!string.IsNullOrEmpty(photoFile))
                    {
                        var fileUrl = $"{dirUrl}{photoFile}";
                        var fileReq = (System.Net.FtpWebRequest)System.Net.WebRequest.Create(fileUrl);
                        fileReq.Credentials = new System.Net.NetworkCredential(ftpUser, ftpPass);
                        fileReq.Method = System.Net.WebRequestMethods.Ftp.DownloadFile;
                        fileReq.Timeout = 8000;

                        using var fileResp = (System.Net.FtpWebResponse)await fileReq.GetResponseAsync();
                        using var stream = fileResp.GetResponseStream();
                        using var outStream = System.IO.File.Create(localCachedPath);
                        await stream.CopyToAsync(outStream);

                        return localCachedPath;
                    }
                }

                // B. Cek /foto/{idPerusahaan}/{filename}
                if (idPerusahaan.HasValue && !string.IsNullOrWhiteSpace(pathFoto))
                {
                    var fileName = Path.GetFileName(pathFoto);
                    var fileUrl = $"ftp://192.168.125.234/foto/{idPerusahaan.Value}/{fileName}";
                    try
                    {
                        var fileReq = (System.Net.FtpWebRequest)System.Net.WebRequest.Create(fileUrl);
                        fileReq.Credentials = new System.Net.NetworkCredential(ftpUser, ftpPass);
                        fileReq.Method = System.Net.WebRequestMethods.Ftp.DownloadFile;
                        fileReq.Timeout = 8000;

                        using var fileResp = (System.Net.FtpWebResponse)await fileReq.GetResponseAsync();
                        using var stream = fileResp.GetResponseStream();
                        using var outStream = System.IO.File.Create(localCachedPath);
                        await stream.CopyToAsync(outStream);

                        return localCachedPath;
                    }
                    catch { }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[TryFetchPhotoFromFtpAsync] Error: {ex.Message}");
            }

            return null;
        }

        private static string GetMimeType(string path)
        {
            var ext = Path.GetExtension(path).ToLowerInvariant();
            return ext switch
            {
                ".png" => "image/png",
                ".gif" => "image/gif",
                ".webp" => "image/webp",
                _ => "image/jpeg"
            };
        }

        /// <summary>
        /// Validates company hierarchy for safety violation recording:
        /// - Scanner CANNOT record violation against employees of their PARENT company (or Owner if scanner is not Owner).
        /// - Scanner CAN ONLY record violation against employees of their SAME company (Setara) or CHILD company (perusahaan turunan).
        /// - PT INDEXIM COALINDO (id_perusahaan = 1) is the highest Root / Owner and can audit all companies.
        /// </summary>
        private async Task<(bool CanViolate, string Reason, string Relation, int ScannerCompId, int TargetCompId)> CheckViolationHierarchyPermissionAsync(
            string scannerNik, 
            string targetNik, 
            int? explicitTargetCompanyId = null)
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State == System.Data.ConnectionState.Closed;
                if (wasClosed) await conn.OpenAsync();
                try
                {
                    // 1. Resolve Scanner Company & Tier Level from tbl_t_karyawan & vw_hirarki_perusahaan_jenis
                    int scannerCompId = 1;
                    string scannerCompName = "PT INDEXIM COALINDO";
                    int scannerLevel = 4; // Default Owner level (4=Owner, 3=Main Contractor, 2=Sub Contractor, 1=Vendor)

                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = @"
                            SELECT TOP 1 
                                k.id_perusahaan, 
                                pr.nama_perusahaan,
                                ISNULL(MAX(tp.level_urut), 1) as max_level
                            FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan k
                            JOIN [ONE_DB_MITRA].dbo.tbl_m_perusahaan pr ON k.id_perusahaan = pr.id
                            LEFT JOIN [ONE_DB_MITRA].dbo.vw_hirarki_perusahaan_jenis hj ON hj.id_perusahaan = k.id_perusahaan
                            LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_tipe_perusahaan tp ON tp.tipe_perusahaan_id = hj.id_jenis_perusahaan
                            WHERE (k.no_nik = @nik OR k.no_nik = @cleanNik) AND k.status_aktif = 1
                            GROUP BY k.id_perusahaan, pr.nama_perusahaan
                            ORDER BY k.id_perusahaan ASC;";
                        var p1 = cmd.CreateParameter(); p1.ParameterName = "@nik"; p1.Value = scannerNik.Trim(); cmd.Parameters.Add(p1);
                        var p2 = cmd.CreateParameter(); p2.ParameterName = "@cleanNik"; p2.Value = scannerNik.Trim().Replace("IC", ""); cmd.Parameters.Add(p2);

                        using var r = await cmd.ExecuteReaderAsync();
                        if (await r.ReadAsync())
                        {
                            scannerCompId = r.GetInt32(0);
                            scannerCompName = r.IsDBNull(1) ? "Perusahaan Pemeriksa" : r.GetString(1);
                            scannerLevel = r.IsDBNull(2) ? 1 : Convert.ToInt32(r.GetValue(2));
                        }
                    }

                    // 2. Resolve Target Company & Tier Level
                    int targetCompId = explicitTargetCompanyId ?? 1;
                    string targetCompName = "PT INDEXIM COALINDO";
                    int targetLevel = 4;

                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = @"
                            SELECT TOP 1 
                                k.id_perusahaan, 
                                pr.nama_perusahaan,
                                ISNULL(MAX(tp.level_urut), 1) as max_level
                            FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan k
                            JOIN [ONE_DB_MITRA].dbo.tbl_m_perusahaan pr ON k.id_perusahaan = pr.id
                            LEFT JOIN [ONE_DB_MITRA].dbo.vw_hirarki_perusahaan_jenis hj ON hj.id_perusahaan = k.id_perusahaan
                            LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_tipe_perusahaan tp ON tp.tipe_perusahaan_id = hj.id_jenis_perusahaan
                            WHERE (k.no_nik = @nik OR k.no_nik = @cleanNik OR k.id_perusahaan = @explicitId) AND k.status_aktif = 1
                            GROUP BY k.id_perusahaan, pr.nama_perusahaan
                            ORDER BY k.id_perusahaan ASC;";
                        var p1 = cmd.CreateParameter(); p1.ParameterName = "@nik"; p1.Value = targetNik.Trim(); cmd.Parameters.Add(p1);
                        var p2 = cmd.CreateParameter(); p2.ParameterName = "@cleanNik"; p2.Value = targetNik.Trim().Replace("IC", ""); cmd.Parameters.Add(p2);
                        var p3 = cmd.CreateParameter(); p3.ParameterName = "@explicitId"; p3.Value = explicitTargetCompanyId.HasValue ? explicitTargetCompanyId.Value : -1; cmd.Parameters.Add(p3);

                        using var r = await cmd.ExecuteReaderAsync();
                        if (await r.ReadAsync())
                        {
                            targetCompId = r.GetInt32(0);
                            targetCompName = r.IsDBNull(1) ? "Perusahaan Target" : r.GetString(1);
                            targetLevel = r.IsDBNull(2) ? 1 : Convert.ToInt32(r.GetValue(2));
                        }
                    }

                    // 3. Jika pemeriksa adalah PT INDEXIM COALINDO (Owner tertinggi, id = 1) -> Selalu diizinkan
                    if (scannerCompId == 1)
                    {
                        return (true, "Otoritas Owner PT Indexim Coalindo (Akses Pengawasan Penuh).", "ROOT_OWNER", scannerCompId, targetCompId);
                    }

                    // 4. Jika target adalah PT INDEXIM COALINDO (Owner, id = 1) dan scanner BUKAN Indexim -> Ditolak
                    if (targetCompId == 1 && scannerCompId != 1)
                    {
                        return (false, $"Otorisasi Terbatas: Anda ({scannerCompName}) tidak dapat mencatat pelanggaran terhadap karyawan {targetCompName} (Perusahaan Induk / Owner).", "PARENT_OWNER", scannerCompId, targetCompId);
                    }

                    // 5. Jika perusahaan sama -> Setara -> Diizinkan
                    if (scannerCompId == targetCompId)
                    {
                        return (true, "Perusahaan yang sama (Internal Perusahaan).", "SAME_COMPANY", scannerCompId, targetCompId);
                    }

                    // 6. Cek relasi Tree (Ancestors & Descendants) di tbl_r_perusahaan dan tingkat hierarki
                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = @"
                            WITH Ancestors AS (
                                SELECT TRY_CAST(r.id_parent AS INT) AS parent_id, 1 AS depth
                                FROM [ONE_DB_MITRA].dbo.tbl_r_perusahaan r
                                WHERE r.id_perusahaan = @scannerCompId AND r.status_aktif = 'aktif' AND TRY_CAST(r.id_parent AS INT) > 0
                                UNION ALL
                                SELECT TRY_CAST(r.id_parent AS INT), a.depth + 1
                                FROM [ONE_DB_MITRA].dbo.tbl_r_perusahaan r
                                JOIN Ancestors a ON r.id_perusahaan = a.parent_id
                                WHERE r.status_aktif = 'aktif' AND TRY_CAST(r.id_parent AS INT) > 0 AND a.depth < 10
                            ),
                            Descendants AS (
                                SELECT r.id_perusahaan AS child_id, 1 AS depth
                                FROM [ONE_DB_MITRA].dbo.tbl_r_perusahaan r
                                WHERE TRY_CAST(r.id_parent AS INT) = @scannerCompId AND r.status_aktif = 'aktif'
                                UNION ALL
                                SELECT r.id_perusahaan, d.depth + 1
                                FROM [ONE_DB_MITRA].dbo.tbl_r_perusahaan r
                                JOIN Descendants d ON TRY_CAST(r.id_parent AS INT) = d.child_id
                                WHERE r.status_aktif = 'aktif' AND d.depth < 10
                            )
                            SELECT 
                                CASE 
                                    WHEN EXISTS (SELECT 1 FROM Ancestors WHERE parent_id = @targetCompId) THEN 'PARENT_COMPANY'
                                    WHEN EXISTS (SELECT 1 FROM Descendants WHERE child_id = @targetCompId) THEN 'CHILD_COMPANY'
                                    WHEN @targetLevel > @scannerLevel THEN 'PARENT_TIER'
                                    WHEN @targetLevel = @scannerLevel THEN 'PEER_COMPANY'
                                    WHEN @targetLevel < @scannerLevel THEN 'CHILD_TIER'
                                    ELSE 'PEER_COMPANY'
                                END AS relation_result;";

                        var pS = cmd.CreateParameter(); pS.ParameterName = "@scannerCompId"; pS.Value = scannerCompId; cmd.Parameters.Add(pS);
                        var pT = cmd.CreateParameter(); pT.ParameterName = "@targetCompId"; pT.Value = targetCompId; cmd.Parameters.Add(pT);
                        var pSL = cmd.CreateParameter(); pSL.ParameterName = "@scannerLevel"; pSL.Value = scannerLevel; cmd.Parameters.Add(pSL);
                        var pTL = cmd.CreateParameter(); pTL.ParameterName = "@targetLevel"; pTL.Value = targetLevel; cmd.Parameters.Add(pTL);

                        var relScalar = await cmd.ExecuteScalarAsync();
                        string rel = relScalar?.ToString() ?? "PEER_COMPANY";

                        if (rel == "PARENT_COMPANY" || rel == "PARENT_TIER" || rel == "PARENT_OWNER")
                        {
                            return (false, $"Otorisasi Terbatas: Anda ({scannerCompName}) tidak dapat mencatat pelanggaran terhadap karyawan {targetCompName} (Perusahaan Induk / Parent Company).", rel, scannerCompId, targetCompId);
                        }

                        // Relasi CHILD_COMPANY, PEER_COMPANY (Setara), CHILD_TIER -> Diizinkan
                        return (true, $"Diizinkan: Hubungan hierarki ({rel}) memenuhi otorisasi pengawasan K3.", rel, scannerCompId, targetCompId);
                    }
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CheckViolationHierarchyPermissionAsync] Error: {ex.Message}");
                return (true, "Validasi hierarki selesai (Default).", "FALLBACK_ALLOWED", 1, 1);
            }
        }
    }

    public class CreatePermitMovementRequest
    {
        public string Nik { get; set; } = string.Empty;
        public string? Nama { get; set; }
        public string? Perusahaan { get; set; }
        public string? Departemen { get; set; }
        public string? NomorPermit { get; set; }
        public string Direction { get; set; } = "MASUK"; // 'MASUK' / 'KELUAR'
        public string? NomorUnit { get; set; }
        public string Keperluan { get; set; } = string.Empty;
        public string? LokasiPos { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string? DetilLokasi { get; set; }
    }

    public class CreatePermitViolationRequest
    {
        public string ViolatorNik { get; set; } = string.Empty;
        public string? ViolatorName { get; set; }
        public string? ViolatorCompany { get; set; }
        public string? ViolatorDepartment { get; set; }
        public string? PermitNumber { get; set; }
        public int? IdPelanggaranJenis { get; set; }
        public string? JenisPelanggaranNama { get; set; }
        public int? IdKriteria { get; set; }
        public string? KriteriaNama { get; set; }
        public string ViolationType { get; set; } = string.Empty;
        public string ViolationDescription { get; set; } = string.Empty;
        public string? ViolationLocation { get; set; }
        public string? PhotoUrl { get; set; }
        public string Severity { get; set; } = "Medium";
        public string? ActionTaken { get; set; }
        public DateTime? TanggalKejadian { get; set; }
    }
}
