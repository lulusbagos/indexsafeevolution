using System;
using System.Collections.Generic;
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
    [ApiController]
    [Route("api/roster")]
    [Route("roster")]
    [AllowAnonymous]
    public class RosterController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IndeximRosterService _indeximRosterService;

        public RosterController(AppDbContext context, IndeximRosterService indeximRosterService)
        {
            _context = context;
            _indeximRosterService = indeximRosterService;
        }

        private string GetCurrentNik()
        {
            var claimNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrEmpty(claimNik) && claimNik != "0000") return claimNik;
            var headerNik = Request.Headers["X-User-Nik"].FirstOrDefault();
            if (!string.IsNullOrEmpty(headerNik)) return headerNik;
            var queryNik = Request.Query["nik"].FirstOrDefault();
            if (!string.IsNullOrEmpty(queryNik)) return queryNik;
            return "0000";
        }

        public static bool CheckIsExempt(string? jabatan)
        {
            if (string.IsNullOrWhiteSpace(jabatan)) return false;
            var j = jabatan.Trim().ToLowerInvariant();
            return j.Contains("manager") ||
                   j.Contains("direktur") ||
                   j.Contains("director") ||
                   j.Contains("kepala teknik tambang") ||
                   j.Contains("ktt") ||
                   j.Contains("depthead") ||
                   j.Contains("dept head") ||
                   j.Contains("department head") ||
                   j.Contains("pjo") ||
                   j.Contains("project manager") ||
                   j.Contains("project mmanager") ||
                   j == "pm";
        }

        [HttpGet("status")]
        public async Task<IActionResult> GetRosterStatus()
        {
            var userNik = GetCurrentNik();
            var today = DateTime.Today;

            var historyRaw = await _context.Rosters.AsNoTracking()
                .Where(r => r.Nik == userNik)
                .OrderByDescending(r => r.AkhirCuti)
                .ThenByDescending(r => r.CreatedAt)
                .ToListAsync();

            var activeRoster = historyRaw.FirstOrDefault(r => today >= r.AwalDinas.Date && today <= r.AkhirCuti.Date && r.Status != "REJECTED");
            var latestRoster = historyRaw.FirstOrDefault(r => r.Status != "REJECTED");

            var userDb = await _context.AppUsers.AsNoTracking().FirstOrDefaultAsync(u => u.Nik == userNik);
            var empKaryawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == userNik && k.StatusAktif);
            bool isIndexim = (empKaryawan != null && empKaryawan.IdPerusahaan == IndeximRosterService.IndeximCompanyId)
                || (!string.IsNullOrEmpty(userDb?.Perusahaan) && userDb.Perusahaan.Contains("INDEXIM", StringComparison.OrdinalIgnoreCase));

            IndeximRosterMonthSummary? oneSum = null;
            if (isIndexim)
            {
                oneSum = await _indeximRosterService.GetEmployeeIndeximRosterAsync(userNik, today.Year, today.Month);
            }
            bool hasOneData = oneSum != null && oneSum.HasOneRoster;

            // Roster dinyatakan sudah disetting jika:
            // 1. Karyawan PT Indexim Coalindo (roster dikelola di ONE DB)
            // 2. Karyawan memiliki data ONE DB aktif
            // 3. Karyawan memiliki roster aktif di tbl_m_roster atau roster terakhir belum kadaluarsa
            bool hasConfiguredRoster = isIndexim || hasOneData || activeRoster != null || (latestRoster != null && latestRoster.AkhirCuti >= today);

            // Cek Re-Induksi bulan berjalan (current month)
            var startOfMonth = new DateTime(today.Year, today.Month, 1);
            var endOfMonth = startOfMonth.AddMonths(1);

            var currentMonthReinduksi = await _context.Reinduksis.AsNoTracking()
                .Where(x => x.Nik == userNik && !x.IsDeleted && x.CreatedAt >= startOfMonth && x.CreatedAt < endOfMonth)
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync();

            bool hasFilledReinduksiThisMonth = currentMonthReinduksi != null;

            // Cek Re-Induksi terkini (kapanpun)
            var latestReinduksi = await _context.Reinduksis.AsNoTracking()
                .Where(x => x.Nik == userNik && !x.IsDeleted)
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync();

            return Ok(new
            {
                success = true,
                hasConfiguredRoster,
                isOneSync = hasOneData,
                isIndexim,
                hasFilledReinduksiThisMonth,
                currentMonthReinduksi = currentMonthReinduksi != null ? new
                {
                    currentMonthReinduksi.Id,
                    currentMonthReinduksi.Status,
                    currentMonthReinduksi.NikPengawas,
                    currentMonthReinduksi.NamaPengawas,
                    currentMonthReinduksi.IsExempt,
                    CreatedAt = currentMonthReinduksi.CreatedAt.ToString("yyyy-MM-dd HH:mm")
                } : null,
                activeRoster = activeRoster != null ? new
                {
                    activeRoster.Id,
                    AwalDinas = activeRoster.AwalDinas.ToString("yyyy-MM-dd"),
                    AkhirDinas = activeRoster.AkhirDinas.ToString("yyyy-MM-dd"),
                    AwalCuti = activeRoster.AwalCuti.ToString("yyyy-MM-dd"),
                    AkhirCuti = activeRoster.AkhirCuti.ToString("yyyy-MM-dd"),
                    Status = activeRoster.Status ?? "APPROVED",
                    activeRoster.NikPengawas,
                    activeRoster.NamaPengawas
                } : null,
                reinduksi = latestReinduksi != null ? new
                {
                    latestReinduksi.Id,
                    latestReinduksi.Status,
                    latestReinduksi.NikPengawas,
                    latestReinduksi.NamaPengawas,
                    latestReinduksi.IsExempt,
                    CreatedAt = latestReinduksi.CreatedAt.ToString("yyyy-MM-dd HH:mm")
                } : null,
                lastSupervisor = latestReinduksi != null && !string.IsNullOrEmpty(latestReinduksi.NikPengawas) ? new
                {
                    nik = latestReinduksi.NikPengawas,
                    nama = latestReinduksi.NamaPengawas
                } : null
            });
        }

        [HttpGet]
        public async Task<IActionResult> GetRosterInfo()
        {
            var userNik = GetCurrentNik();
            var today = DateTime.Today;
            var now = DateTime.Now;
            var startOfMonth = new DateTime(now.Year, now.Month, 1);
            var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);
            int totalDaysInMonth = (endOfMonth - startOfMonth).Days + 1;

            var historyRaw = await _context.Rosters.AsNoTracking()
                .Where(r => r.Nik == userNik)
                .OrderByDescending(r => r.AkhirCuti)
                .ThenByDescending(r => r.CreatedAt)
                .ToListAsync();

            var history = historyRaw.Select(r =>
            {
                int daysDinas = (r.AkhirDinas - r.AwalDinas).Days + 1;
                int daysCuti = (r.AkhirCuti - r.AwalCuti).Days + 1;
                string status;

                if (r.TipeRoster == "TUGAS")
                {
                    if (today >= r.AwalDinas.Date && today <= r.AkhirDinas.Date)
                        status = "Aktif (Tugas)";
                    else if (today < r.AwalDinas.Date)
                        status = "Akan Datang";
                    else
                        status = "Selesai";
                }
                else
                {
                    if (today >= r.AwalDinas.Date && today <= r.AkhirDinas.Date)
                        status = "Dinas (Onsite)";
                    else if (today >= r.AwalCuti.Date && today <= r.AkhirCuti.Date)
                        status = "Cuti (Offsite)";
                    else if (today < r.AwalDinas.Date)
                        status = "Akan Datang";
                    else
                        status = "Selesai";
                }

                return new
                {
                    r.Id,
                    r.Nik,
                    AwalDinas = r.AwalDinas.ToString("yyyy-MM-dd"),
                    AkhirDinas = r.AkhirDinas.ToString("yyyy-MM-dd"),
                    AwalCuti = r.AwalCuti.ToString("yyyy-MM-dd"),
                    AkhirCuti = r.AkhirCuti.ToString("yyyy-MM-dd"),
                    AwalDinasFormatted = r.AwalDinas.ToString("dd MMM yyyy"),
                    AkhirDinasFormatted = r.AkhirDinas.ToString("dd MMM yyyy"),
                    AwalCutiFormatted = r.AwalCuti.ToString("dd MMM yyyy"),
                    AkhirCutiFormatted = r.AkhirCuti.ToString("dd MMM yyyy"),
                    TipeRoster = r.TipeRoster ?? "REGULER",
                    r.Keterangan,
                    ApprovalStatus = r.Status ?? "APPROVED",
                    r.IdReinduksi,
                    r.NikPengawas,
                    r.NamaPengawas,
                    CreatedAt = r.CreatedAt.ToString("dd/MM/yyyy HH:mm"),
                    HariDinas = daysDinas,
                    HariCuti = daysCuti,
                    Status = status
                };
            }).ToList();

            // Check active status for current month target (menggunakan HashSet tanggal unik agar anti multi-counting overlap)
            bool isTugasExempt = false;
            int computedOnsiteDays = 0;
            bool hasRoster = false;
            var onsiteDaysSet = new HashSet<DateTime>();

            foreach (var r in historyRaw)
            {
                if (r.Status == "REJECTED") continue;

                if (r.TipeRoster == "TUGAS")
                {
                    if (r.AwalDinas.Date <= endOfMonth.Date && r.AkhirDinas.Date >= startOfMonth.Date)
                    {
                        isTugasExempt = true;
                    }
                    continue;
                }

                if (r.AwalDinas.Date <= endOfMonth.Date && r.AkhirDinas.Date >= startOfMonth.Date)
                {
                    var overlapStart = r.AwalDinas.Date > startOfMonth.Date ? r.AwalDinas.Date : startOfMonth.Date;
                    var overlapEnd = r.AkhirDinas.Date < endOfMonth.Date ? r.AkhirDinas.Date : endOfMonth.Date;
                    for (var d = overlapStart.Date; d <= overlapEnd.Date; d = d.AddDays(1))
                    {
                        onsiteDaysSet.Add(d);
                    }
                }
            }

            computedOnsiteDays = onsiteDaysSet.Count;
            hasRoster = computedOnsiteDays > 0;

            var activeRoster = historyRaw.FirstOrDefault(r => today >= r.AwalDinas.Date && today <= r.AkhirCuti.Date && r.Status != "REJECTED");
            var latestRoster = historyRaw.FirstOrDefault(r => r.Status != "REJECTED");

            var userDb = await _context.AppUsers.AsNoTracking().FirstOrDefaultAsync(u => u.Nik == userNik);
            var empKaryawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == userNik && k.StatusAktif);
            bool isIndexim = (empKaryawan != null && empKaryawan.IdPerusahaan == IndeximRosterService.IndeximCompanyId)
                || (!string.IsNullOrEmpty(userDb?.Perusahaan) && userDb.Perusahaan.Contains("INDEXIM", StringComparison.OrdinalIgnoreCase));

            IndeximRosterMonthSummary? oneSum = null;
            if (isIndexim)
            {
                oneSum = await _indeximRosterService.GetEmployeeIndeximRosterAsync(userNik, today.Year, today.Month);
            }
            bool hasOneData = oneSum != null && oneSum.HasOneRoster;

            double ratio = 1.0;
            if (hasOneData && !hasRoster && !isTugasExempt)
            {
                hasRoster = true;
                computedOnsiteDays = oneSum!.WorkDays;
                ratio = Math.Min(1.0, (double)computedOnsiteDays / totalDaysInMonth);
            }
            else if (isTugasExempt)
            {
                ratio = 0.0;
            }
            else if (hasRoster)
            {
                ratio = Math.Min(1.0, (double)computedOnsiteDays / totalDaysInMonth);
            }

            // Roster dinyatakan sudah disetting jika:
            // 1. Karyawan PT Indexim Coalindo (roster dikelola di ONE DB)
            // 2. Karyawan memiliki data ONE DB aktif
            // 3. Karyawan memiliki roster aktif di tbl_m_roster atau roster terakhir belum kadaluarsa
            bool hasConfiguredRoster = isIndexim || hasOneData || activeRoster != null || (latestRoster != null && latestRoster.AkhirCuti >= today);

            // Cek Re-Induksi bulan berjalan
            var startOfMonthRe = new DateTime(today.Year, today.Month, 1);
            var endOfMonthRe = startOfMonthRe.AddMonths(1);
            var currentMonthReinduksi = await _context.Reinduksis.AsNoTracking()
                .Where(x => x.Nik == userNik && !x.IsDeleted && x.CreatedAt >= startOfMonthRe && x.CreatedAt < endOfMonthRe)
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync();
            bool hasFilledReinduksiThisMonth = currentMonthReinduksi != null;

            var latestReinduksi = await _context.Reinduksis.AsNoTracking()
                .Where(x => x.Nik == userNik && !x.IsDeleted)
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync();

            return Ok(new
            {
                success = true,
                hasConfiguredRoster,
                isOneSync = hasOneData,
                isIndexim,
                hasFilledReinduksiThisMonth,
                history,
                activeRoster = activeRoster != null ? new
                {
                    activeRoster.Id,
                    AwalDinas = activeRoster.AwalDinas.ToString("yyyy-MM-dd"),
                    AkhirDinas = activeRoster.AkhirDinas.ToString("yyyy-MM-dd"),
                    AwalCuti = activeRoster.AwalCuti.ToString("yyyy-MM-dd"),
                    AkhirCuti = activeRoster.AkhirCuti.ToString("yyyy-MM-dd"),
                    TipeRoster = activeRoster.TipeRoster ?? "REGULER",
                    activeRoster.Keterangan,
                    ApprovalStatus = activeRoster.Status ?? "APPROVED",
                    activeRoster.IdReinduksi,
                    activeRoster.NikPengawas,
                    activeRoster.NamaPengawas
                } : null,
                latestRoster = latestRoster != null ? new
                {
                    latestRoster.Id,
                    AwalDinas = latestRoster.AwalDinas.ToString("yyyy-MM-dd"),
                    AkhirDinas = latestRoster.AkhirDinas.ToString("yyyy-MM-dd"),
                    AwalCuti = latestRoster.AwalCuti.ToString("yyyy-MM-dd"),
                    AkhirCuti = latestRoster.AkhirCuti.ToString("yyyy-MM-dd"),
                    TipeRoster = latestRoster.TipeRoster ?? "REGULER",
                    latestRoster.Keterangan,
                    ApprovalStatus = latestRoster.Status ?? "APPROVED"
                } : null,
                lastSupervisor = latestReinduksi != null && !string.IsNullOrEmpty(latestReinduksi.NikPengawas) ? new
                {
                    nik = latestReinduksi.NikPengawas,
                    nama = latestReinduksi.NamaPengawas
                } : null,
                reinduksi = latestReinduksi != null ? new
                {
                    latestReinduksi.Id,
                    latestReinduksi.Status,
                    latestReinduksi.NikPengawas,
                    latestReinduksi.NamaPengawas,
                    latestReinduksi.IsExempt,
                    CreatedAt = latestReinduksi.CreatedAt.ToString("yyyy-MM-dd HH:mm")
                } : null,
                isTugasExempt,
                computedOnsiteDays,
                totalDaysInMonth,
                ratio,
                defaultOnsite = 42
            });
        }

        [HttpPost]
        public async Task<IActionResult> SaveRoster([FromBody] RosterSaveModel req)
        {
            var userNik = GetCurrentNik();
            if (string.IsNullOrWhiteSpace(userNik))
            {
                return Unauthorized(new { message = "NIK tidak ditemukan." });
            }

            bool isTugas = string.Equals(req?.TipeRoster, "TUGAS", StringComparison.OrdinalIgnoreCase);

            if (isTugas)
            {
                if (req == null ||
                    !DateTime.TryParse(req.AwalDinas, out DateTime awalTugas) ||
                    !DateTime.TryParse(req.AkhirDinas, out DateTime akhirTugas))
                {
                    return BadRequest(new { message = "Format tanggal periode tugas tidak valid." });
                }

                if (awalTugas > akhirTugas)
                {
                    return BadRequest(new { message = "Tanggal mulai tugas tidak boleh lebih besar dari akhir tugas." });
                }

                int durasiTugas = (akhirTugas - awalTugas).Days + 1;
                bool isEdit = req.Id.HasValue && req.Id.Value > 0;
                Roster? rosterTugasToUpdate = null;

                if (isEdit)
                {
                    rosterTugasToUpdate = await _context.Rosters
                        .FirstOrDefaultAsync(r => r.Id == req.Id!.Value && r.Nik == userNik);

                    if (rosterTugasToUpdate == null)
                    {
                        return NotFound(new { message = "Data periode tugas tidak ditemukan atau bukan milik Anda." });
                    }
                }

                if (rosterTugasToUpdate != null)
                {
                    rosterTugasToUpdate.AwalDinas = awalTugas;
                    rosterTugasToUpdate.AkhirDinas = akhirTugas;
                    rosterTugasToUpdate.AwalCuti = akhirTugas;
                    rosterTugasToUpdate.AkhirCuti = akhirTugas;
                    rosterTugasToUpdate.TipeRoster = "TUGAS";
                    rosterTugasToUpdate.Keterangan = req.Keterangan;
                    rosterTugasToUpdate.UpdatedAt = DateTime.Now;
                    _context.Rosters.Update(rosterTugasToUpdate);
                }
                else
                {
                    var newRosterTugas = new Roster
                    {
                        Nik = userNik,
                        AwalDinas = awalTugas,
                        AkhirDinas = akhirTugas,
                        AwalCuti = akhirTugas,
                        AkhirCuti = akhirTugas,
                        TipeRoster = "TUGAS",
                        Keterangan = req.Keterangan,
                        Status = "APPROVED",
                        CreatedAt = DateTime.Now,
                        UpdatedAt = DateTime.Now
                    };
                    _context.Rosters.Add(newRosterTugas);
                }

                // Kirim notifikasi sistem ke user
                var notifTugas = new Notification
                {
                    RecipientNik = userNik,
                    Title = isEdit ? "Perubahan Periode Tugas Khusus" : "Periode Tugas Baru Berhasil Disimpan",
                    Message = $"Periode tugas {durasiTugas} hari ({awalTugas:dd MMM yyyy} - {akhirTugas:dd MMM yyyy}) aktif. Bebas target SAP: Kewajiban laporan K3 ditiadakan selama masa tugas.",
                    Url = "/roster",
                    NotifType = "roster_tugas",
                    IsRead = false,
                    IsActioned = false,
                    CreatedAt = DateTime.Now
                };
                _context.Notifications.Add(notifTugas);

                await _context.SaveChangesAsync();
                return Ok(new { success = true, message = "Periode Tugas berhasil disimpan. Anda dibebaskan dari kewajiban target SAP selama masa penugasan." });
            }

            // REGULER ROSTER
            var userDb = await _context.AppUsers.AsNoTracking().FirstOrDefaultAsync(u => u.Nik == userNik);
            var empKaryawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == userNik && k.StatusAktif);
            bool isIndexim = (empKaryawan != null && empKaryawan.IdPerusahaan == IndeximRosterService.IndeximCompanyId)
                || (!string.IsNullOrEmpty(userDb?.Perusahaan) && userDb.Perusahaan.Contains("INDEXIM", StringComparison.OrdinalIgnoreCase));

            if (isIndexim)
            {
                return BadRequest(new { success = false, message = "Roster kerja untuk PT Indexim Coalindo dikelola secara terpusat melalui aplikasi ONE DB. Jika terdapat kesalahan roster, silakan perbarui jadwal di aplikasi ONE DB." });
            }

            if (req == null ||
                !DateTime.TryParse(req.AwalDinas, out DateTime awalDinas) ||
                !DateTime.TryParse(req.AkhirDinas, out DateTime akhirDinas) ||
                !DateTime.TryParse(req.AwalCuti, out DateTime awalCuti) ||
                !DateTime.TryParse(req.AkhirCuti, out DateTime akhirCuti))
            {
                return BadRequest(new { message = "Format tanggal roster reguler tidak valid." });
            }

            if (awalDinas > akhirDinas)
            {
                return BadRequest(new { message = "Tanggal awal dinas tidak boleh lebih besar dari akhir dinas." });
            }
            if (akhirDinas >= awalCuti)
            {
                return BadRequest(new { message = "Tanggal akhir dinas harus lebih kecil dari awal cuti." });
            }
            if (awalCuti > akhirCuti)
            {
                return BadRequest(new { message = "Tanggal awal cuti tidak boleh lebih besar dari akhir cuti." });
            }

            int actualOnsite = (akhirDinas - awalDinas).Days + 1;
            int actualOffsite = (akhirCuti - awalCuti).Days + 1;

            if (actualOnsite < 1 || actualOnsite > 365)
            {
                return BadRequest(new { message = "Durasi dinas (onsite) harus antara 1 sampai 365 hari." });
            }
            if (actualOffsite < 1 || actualOffsite > 180)
            {
                return BadRequest(new { message = "Durasi cuti (offsite) harus antara 1 sampai 180 hari." });
            }

            bool isEditReguler = req.Id.HasValue && req.Id.Value > 0;
            Roster? rosterRegulerToUpdate = null;

            if (isEditReguler)
            {
                rosterRegulerToUpdate = await _context.Rosters
                    .FirstOrDefaultAsync(r => r.Id == req.Id!.Value && r.Nik == userNik);

                if (rosterRegulerToUpdate == null)
                {
                    return NotFound(new { message = "Data roster tidak ditemukan atau bukan milik Anda." });
                }
            }

            if (rosterRegulerToUpdate != null)
            {
                rosterRegulerToUpdate.AwalDinas = awalDinas;
                rosterRegulerToUpdate.AkhirDinas = akhirDinas;
                rosterRegulerToUpdate.AwalCuti = awalCuti;
                rosterRegulerToUpdate.AkhirCuti = akhirCuti;
                rosterRegulerToUpdate.TipeRoster = "REGULER";
                rosterRegulerToUpdate.Keterangan = null;
                rosterRegulerToUpdate.UpdatedAt = DateTime.Now;
                _context.Rosters.Update(rosterRegulerToUpdate);
            }
            else
            {
                var newRoster = new Roster
                {
                    Nik = userNik,
                    AwalDinas = awalDinas,
                    AkhirDinas = akhirDinas,
                    AwalCuti = awalCuti,
                    AkhirCuti = akhirCuti,
                    TipeRoster = "REGULER",
                    Keterangan = null,
                    Status = "APPROVED",
                    CreatedAt = DateTime.Now,
                    UpdatedAt = DateTime.Now
                };
                _context.Rosters.Add(newRoster);
            }

            // Kirim notifikasi sistem ke user
            var notifReguler = new Notification
            {
                RecipientNik = userNik,
                Title = isEditReguler ? "Perubahan Pengaturan Roster" : "Pengaturan Roster Baru Berhasil Disimpan",
                Message = $"Jadwal roster dinas {actualOnsite} hari ({awalDinas:dd MMM yyyy} - {akhirDinas:dd MMM yyyy}) & cuti {actualOffsite} hari ({awalCuti:dd MMM yyyy} - {akhirCuti:dd MMM yyyy}) aktif. Target SAP disesuaikan proporsional.",
                Url = "/roster",
                NotifType = "roster_reguler",
                IsRead = false,
                IsActioned = false,
                CreatedAt = DateTime.Now
            };
            _context.Notifications.Add(notifReguler);

            await _context.SaveChangesAsync();
            return Ok(new { success = true, message = "Roster kerja berhasil disimpan dan target SAP diperbarui." });
        }

        [HttpPost("save-with-reinduksi")]
        public async Task<IActionResult> SaveRosterWithReinduksi([FromBody] RosterWithReinduksiSaveModel req)
        {
            var userNik = GetCurrentNik();
            if (string.IsNullOrWhiteSpace(userNik) || userNik == "0000")
            {
                return Unauthorized(new { message = "NIK tidak ditemukan." });
            }

            if (req == null)
            {
                return BadRequest(new { message = "Payload tidak valid." });
            }

            var userDb = await _context.AppUsers.FirstOrDefaultAsync(u => u.Nik == userNik);
            var empKaryawan = await _context.Karyawans.AsNoTracking().FirstOrDefaultAsync(k => k.NoNik == userNik && k.StatusAktif);
            bool isIndexim = (empKaryawan != null && empKaryawan.IdPerusahaan == IndeximRosterService.IndeximCompanyId)
                || (!string.IsNullOrEmpty(userDb?.Perusahaan) && userDb.Perusahaan.Contains("INDEXIM", StringComparison.OrdinalIgnoreCase));

            bool isTugas = string.Equals(req.TipeRoster, "TUGAS", StringComparison.OrdinalIgnoreCase);
            DateTime awalDinas = DateTime.MinValue, akhirDinas = DateTime.MinValue, awalCuti = DateTime.MinValue, akhirCuti = DateTime.MinValue;
            bool hasValidDates = DateTime.TryParse(req.AwalDinas, out awalDinas) && DateTime.TryParse(req.AkhirDinas, out akhirDinas);

            var existingActiveRoster = await _context.Rosters
                .Where(r => r.Nik == userNik && r.Status != "REJECTED")
                .OrderByDescending(r => r.AkhirCuti)
                .FirstOrDefaultAsync();

            int? targetRosterId = req.Id ?? existingActiveRoster?.Id;

            if (!hasValidDates && existingActiveRoster != null)
            {
                awalDinas = existingActiveRoster.AwalDinas;
                akhirDinas = existingActiveRoster.AkhirDinas;
                awalCuti = existingActiveRoster.AwalCuti;
                akhirCuti = existingActiveRoster.AkhirCuti;
            }
            else if (!hasValidDates)
            {
                var now = DateTime.Now;
                awalDinas = new DateTime(now.Year, now.Month, 1);
                akhirDinas = awalDinas.AddMonths(1).AddDays(-1);
                awalCuti = akhirDinas;
                akhirCuti = akhirDinas;
            }
            else
            {
                if (isTugas)
                {
                    awalCuti = akhirDinas;
                    akhirCuti = akhirDinas;
                }
                else
                {
                    DateTime.TryParse(req.AwalCuti, out awalCuti);
                    DateTime.TryParse(req.AkhirCuti, out akhirCuti);
                    if (awalCuti == DateTime.MinValue) awalCuti = akhirDinas;
                    if (akhirCuti == DateTime.MinValue) akhirCuti = awalCuti;
                }
            }

            // Cek jabatan & pengecualian approval pengawas
            string userJabatan = req.Jabatan ?? "";
            if (string.IsNullOrWhiteSpace(userJabatan) && userDb != null)
            {
                if (empKaryawan?.IdJabatan != null)
                {
                    var jb = await _context.Jabatans.FirstOrDefaultAsync(j => j.JabatanId == empKaryawan.IdJabatan.Value);
                    if (jb != null && !string.IsNullOrWhiteSpace(jb.NamaJabatan))
                    {
                        userJabatan = jb.NamaJabatan;
                    }
                }
            }

            bool isExempt = CheckIsExempt(userJabatan) || req.IsExempt == true;

            // Jika BUKAN jabatan yang dikecualikan, WAJIB ada nama pengawas
            if (!isExempt && string.IsNullOrWhiteSpace(req.NikPengawas))
            {
                return BadRequest(new { message = "Nama Pengawas wajib ditag/dipilih untuk persetujuan Form Re-Induksi." });
            }

            string cleanNama = !string.IsNullOrWhiteSpace(req.Nama) ? req.Nama : (userDb?.Nama ?? userNik);
            string cleanPerusahaan = !string.IsNullOrWhiteSpace(req.Perusahaan) ? req.Perusahaan : (userDb?.Perusahaan ?? (isIndexim ? "PT INDEXIM COALINDO" : "-"));
            string cleanDepartemen = !string.IsNullOrWhiteSpace(req.Departemen) ? req.Departemen : (userDb?.Departemen ?? "-");
            string? cleanNikPengawas = isExempt ? null : req.NikPengawas?.Trim();
            string? cleanNamaPengawas = isExempt ? null : req.NamaPengawas?.Trim();

            string finalStatus = isExempt ? "APPROVED" : "PENDING_APPROVAL";

            // Simpan / Perbarui Roster HANYA jika bukan PT Indexim reguler dan user meminta buat/update roster
            Roster? savedRoster = null;
            if (isTugas || (!isIndexim && hasValidDates))
            {
                if (req.Id.HasValue && req.Id.Value > 0)
                {
                    savedRoster = await _context.Rosters.FirstOrDefaultAsync(r => r.Id == req.Id.Value && r.Nik == userNik);
                }
                else if (existingActiveRoster != null)
                {
                    savedRoster = existingActiveRoster;
                }

                if (savedRoster != null)
                {
                    savedRoster.AwalDinas = awalDinas;
                    savedRoster.AkhirDinas = akhirDinas;
                    savedRoster.AwalCuti = awalCuti;
                    savedRoster.AkhirCuti = akhirCuti;
                    savedRoster.TipeRoster = req.TipeRoster ?? "REGULER";
                    savedRoster.Keterangan = req.Keterangan;
                    savedRoster.Status = finalStatus;
                    savedRoster.NikPengawas = cleanNikPengawas;
                    savedRoster.NamaPengawas = cleanNamaPengawas;
                    savedRoster.UpdatedAt = DateTime.Now;
                    _context.Rosters.Update(savedRoster);
                }
                else if (!isIndexim && hasValidDates)
                {
                    savedRoster = new Roster
                    {
                        Nik = userNik,
                        AwalDinas = awalDinas,
                        AkhirDinas = akhirDinas,
                        AwalCuti = awalCuti,
                        AkhirCuti = akhirCuti,
                        TipeRoster = req.TipeRoster ?? "REGULER",
                        Keterangan = req.Keterangan,
                        Status = finalStatus,
                        NikPengawas = cleanNikPengawas,
                        NamaPengawas = cleanNamaPengawas,
                        CreatedAt = DateTime.Now,
                        UpdatedAt = DateTime.Now
                    };
                    _context.Rosters.Add(savedRoster);
                }
            }

            if (savedRoster != null)
            {
                await _context.SaveChangesAsync();
                targetRosterId = savedRoster.Id;
            }

            DateTime? tglOffsite = null;
            if (DateTime.TryParse(req.TanggalMulaiOffsite, out DateTime dtOff)) tglOffsite = dtOff;
            else if (awalCuti != DateTime.MinValue) tglOffsite = awalCuti;

            DateTime? tglOnsite = null;
            if (DateTime.TryParse(req.TanggalMulaiOnsite, out DateTime dtOn)) tglOnsite = dtOn;
            else if (awalDinas != DateTime.MinValue) tglOnsite = awalDinas;

            // Simpan Form Re-Induksi
            var reinduksi = new Reinduksi
            {
                RosterId = targetRosterId,
                Nik = userNik,
                Nama = cleanNama,
                Perusahaan = cleanPerusahaan,
                Jabatan = userJabatan,
                Departemen = cleanDepartemen,
                NikPengawas = cleanNikPengawas,
                NamaPengawas = cleanNamaPengawas,
                TanggalMulaiOffsite = tglOffsite,
                TanggalMulaiOnsite = tglOnsite,
                AwalDinas = awalDinas,
                AkhirDinas = akhirDinas,
                AwalCuti = awalCuti,
                AkhirCuti = akhirCuti,
                TipeRoster = req.TipeRoster ?? "REGULER",
                IsExempt = isExempt,
                Status = finalStatus,
                Q1Answer = req.Q1Answer ?? "Ya",
                Q1Notes = req.Q1Notes,
                Q2Answer = req.Q2Answer ?? "Ya",
                Q2Notes = req.Q2Notes,
                Q3Answer = req.Q3Answer ?? "Ya",
                Q3Notes = req.Q3Notes,
                Q4Answer = req.Q4Answer ?? "Ya",
                Q4Notes = req.Q4Notes,
                Q5Answer = req.Q5Answer ?? "Ya",
                Q5Notes = req.Q5Notes,
                Q6Answer = req.Q6Answer ?? "Ya",
                Q6Notes = req.Q6Notes,
                Q7Answer = req.Q7Answer ?? "Ya",
                Q7Notes = req.Q7Notes,
                SignatureKaryawan = req.SignatureKaryawan,
                ApprovedAt = isExempt ? DateTime.Now : null,
                CreatedAt = DateTime.Now,
                UpdatedAt = DateTime.Now
            };
            _context.Reinduksis.Add(reinduksi);
            await _context.SaveChangesAsync();

            if (savedRoster != null)
            {
                savedRoster.IdReinduksi = reinduksi.Id;
                _context.Rosters.Update(savedRoster);
            }

            // Buat Notifikasi
            if (isExempt)
            {
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = userNik,
                    Title = "Re-Induksi Disetujui Otomatis",
                    Message = $"Form Re-Induksi K3LH periode ini telah disetujui otomatis sesuai jabatan {userJabatan}.",
                    Url = "/roster",
                    NotifType = "roster_reinduksi_approved",
                    Category = "info",
                    IsRead = false,
                    CreatedAt = DateTime.Now
                });
            }
            else if (!string.IsNullOrEmpty(cleanNikPengawas))
            {
                // Notifikasi ke Pengawas
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = cleanNikPengawas,
                    Title = $"Persetujuan Re-Induksi: {cleanNama}",
                    Message = $"{cleanNama} ({userNik}) telah melengkapi Form Re-Induksi K3LH. Harap periksa dan berikan persetujuan.",
                    Url = "/reinduksi-approval",
                    NotifType = "reinduksi_approval",
                    Category = "approval",
                    Payload = $"{{\"reinduksiId\": {reinduksi.Id}, \"rosterId\": {(targetRosterId ?? 0)}, \"nik\": \"{userNik}\"}}",
                    IsRead = false,
                    CreatedAt = DateTime.Now
                });

                // Notifikasi konfirmasi ke karyawan
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = userNik,
                    Title = "Form Re-Induksi Terkirim ke Pengawas",
                    Message = $"Form Re-Induksi K3LH berhasil dikirim. Menunggu persetujuan Pengawas ({cleanNamaPengawas}).",
                    Url = "/roster",
                    NotifType = "roster_reinduksi_pending",
                    Category = "info",
                    IsRead = false,
                    CreatedAt = DateTime.Now
                });
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                isExempt,
                status = finalStatus,
                message = isExempt
                    ? "Form Re-Induksi berhasil disimpan & disetujui otomatis."
                    : $"Form Re-Induksi berhasil dikirim dan menanti persetujuan dari Pengawas ({cleanNamaPengawas}).",
                rosterId = targetRosterId,
                reinduksiId = reinduksi.Id
            });
        }

        [HttpGet("reinduksi/pending-approvals")]
        public async Task<IActionResult> GetPendingReinduksiApprovals()
        {
            var userNik = GetCurrentNik();
            var items = await _context.Reinduksis.AsNoTracking()
                .Where(r => r.NikPengawas == userNik && r.Status == "PENDING_APPROVAL" && !r.IsDeleted)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            return Ok(new { success = true, data = items });
        }

        [HttpGet("reinduksi/{id}")]
        public async Task<IActionResult> GetReinduksiDetail(int id)
        {
            var userNik = GetCurrentNik();
            var item = await _context.Reinduksis.AsNoTracking()
                .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

            if (item == null)
            {
                return NotFound(new { success = false, message = "Data Re-Induksi tidak ditemukan." });
            }

            bool canApprove = item.NikPengawas == userNik && item.Status == "PENDING_APPROVAL";

            return Ok(new { success = true, data = item, canApprove });
        }

        [HttpPost("reinduksi/action")]
        public async Task<IActionResult> ActionReinduksi([FromBody] ReinduksiActionModel req)
        {
            var userNik = GetCurrentNik();
            if (req == null || req.ReinduksiId <= 0)
            {
                return BadRequest(new { success = false, message = "Parameter tidak valid." });
            }

            var reinduksi = await _context.Reinduksis
                .FirstOrDefaultAsync(r => r.Id == req.ReinduksiId && !r.IsDeleted);

            if (reinduksi == null)
            {
                return NotFound(new { success = false, message = "Data Re-Induksi tidak ditemukan." });
            }

            if (reinduksi.NikPengawas != userNik && !User.IsInRole("Admin"))
            {
                return StatusCode(403, new { success = false, message = "Anda tidak berwenang memberikan persetujuan untuk form ini." });
            }

            if (reinduksi.Status != "PENDING_APPROVAL")
            {
                return BadRequest(new { success = false, message = $"Form Re-Induksi ini sudah diproses sebelumnya ({reinduksi.Status})." });
            }

            bool isApproved = string.Equals(req.Action, "APPROVE", StringComparison.OrdinalIgnoreCase);

            var supervisorUser = await _context.AppUsers.FirstOrDefaultAsync(u => u.Nik == userNik);
            string supervisorNama = supervisorUser?.Nama ?? userNik;

            if (isApproved)
            {
                reinduksi.Status = "APPROVED";
                reinduksi.ApprovedAt = DateTime.Now;
                reinduksi.SupervisorNotes = req.Notes;
                reinduksi.SignaturePengawas = req.SignaturePengawas;
                reinduksi.UpdatedAt = DateTime.Now;

                if (reinduksi.RosterId.HasValue)
                {
                    var roster = await _context.Rosters.FirstOrDefaultAsync(r => r.Id == reinduksi.RosterId.Value);
                    if (roster != null)
                    {
                        roster.Status = "APPROVED";
                        roster.UpdatedAt = DateTime.Now;
                        _context.Rosters.Update(roster);
                    }
                }

                // Notifikasi ke karyawan
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = reinduksi.Nik,
                    Title = "Re-Induksi & Roster Disetujui Pengawas",
                    Message = $"Selamat! Form Re-Induksi dan Jadwal Roster Anda telah disetujui oleh {supervisorNama}. Jadwal dinas Anda resmi aktif.",
                    Url = "/roster",
                    NotifType = "reinduksi_approved",
                    Category = "approval",
                    IsRead = false,
                    CreatedAt = DateTime.Now
                });
            }
            else
            {
                reinduksi.Status = "REJECTED";
                reinduksi.SupervisorNotes = req.Notes;
                reinduksi.UpdatedAt = DateTime.Now;

                if (reinduksi.RosterId.HasValue)
                {
                    var roster = await _context.Rosters.FirstOrDefaultAsync(r => r.Id == reinduksi.RosterId.Value);
                    if (roster != null)
                    {
                        roster.Status = "REJECTED";
                        roster.UpdatedAt = DateTime.Now;
                        _context.Rosters.Update(roster);
                    }
                }

                // Notifikasi penolakan ke karyawan
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = reinduksi.Nik,
                    Title = "Re-Induksi & Roster Ditolak Pengawas",
                    Message = $"Form Re-Induksi Anda ditolak oleh {supervisorNama}. Catatan: {req.Notes ?? "Periksa kembali jawaban atau jadwal Anda"}. Harap lakukan pengaturan ulang.",
                    Url = "/roster",
                    NotifType = "reinduksi_rejected",
                    Category = "approval",
                    IsRead = false,
                    CreatedAt = DateTime.Now
                });
            }

            _context.Reinduksis.Update(reinduksi);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = isApproved ? "Form Re-Induksi dan Roster berhasil disetujui." : "Form Re-Induksi ditolak."
            });
        }

        [HttpPost("reinduksi/batch-action")]
        public async Task<IActionResult> BatchActionReinduksi([FromBody] ReinduksiBatchActionModel req)
        {
            var userNik = GetCurrentNik();
            if (req == null || req.ReinduksiIds == null || req.ReinduksiIds.Count == 0)
            {
                return BadRequest(new { success = false, message = "Pilih minimal satu form Re-Induksi." });
            }

            var items = await _context.Reinduksis
                .Where(r => req.ReinduksiIds.Contains(r.Id) && r.NikPengawas == userNik && r.Status == "PENDING_APPROVAL" && !r.IsDeleted)
                .ToListAsync();

            if (items.Count == 0)
            {
                return BadRequest(new { success = false, message = "Tidak ada form Re-Induksi yang dapat diproses." });
            }

            bool isApprove = string.Equals(req.Action, "APPROVE", StringComparison.OrdinalIgnoreCase);
            var supervisorUser = await _context.AppUsers.FirstOrDefaultAsync(u => u.Nik == userNik);
            string supervisorNama = supervisorUser?.Nama ?? userNik;

            var rosterIds = items.Where(i => i.RosterId.HasValue).Select(i => i.RosterId!.Value).Distinct().ToList();
            var rosters = await _context.Rosters.Where(r => rosterIds.Contains(r.Id)).ToListAsync();
            var rosterDict = rosters.ToDictionary(r => r.Id);

            foreach (var item in items)
            {
                item.Status = isApprove ? "APPROVED" : "REJECTED";
                item.ApprovedAt = isApprove ? DateTime.Now : null;
                item.SupervisorNotes = req.Notes;
                item.SignaturePengawas = req.SignaturePengawas;
                item.UpdatedAt = DateTime.Now;

                if (item.RosterId.HasValue && rosterDict.TryGetValue(item.RosterId.Value, out var ros))
                {
                    ros.Status = item.Status;
                    ros.UpdatedAt = DateTime.Now;
                }

                _context.Notifications.Add(new Notification
                {
                    RecipientNik = item.Nik,
                    Title = isApprove ? "Re-Induksi Disetujui Pengawas" : "Re-Induksi Ditolak Pengawas",
                    Message = isApprove
                        ? $"Form Re-Induksi K3LH Anda telah diverifikasi dan disetujui oleh {supervisorNama}."
                        : $"Form Re-Induksi Anda ditolak oleh {supervisorNama}. Catatan: {req.Notes ?? "Periksa kembali data Anda."}",
                    Url = "/roster",
                    NotifType = isApprove ? "reinduksi_approved" : "reinduksi_rejected",
                    Category = "approval",
                    IsRead = false,
                    CreatedAt = DateTime.Now
                });
            }

            await _context.SaveChangesAsync();
            return Ok(new
            {
                success = true,
                count = items.Count,
                message = $"{items.Count} formulir Re-Induksi berhasil {(isApprove ? "disetujui" : "ditolak")}."
            });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteRoster(int id)
        {
            var userNik = GetCurrentNik();
            var roster = await _context.Rosters
                .FirstOrDefaultAsync(r => r.Id == id && r.Nik == userNik);

            if (roster == null)
            {
                return NotFound(new { message = "Data roster tidak ditemukan atau bukan milik Anda." });
            }

            string tipeLabel = roster.TipeRoster == "TUGAS" ? "Periode Tugas" : "Roster Reguler";
            string rentang = $"{roster.AwalDinas:dd MMM yyyy} - {roster.AkhirDinas:dd MMM yyyy}";

            _context.Rosters.Remove(roster);

            // Simpan notifikasi penghapusan
            var notifDelete = new Notification
            {
                RecipientNik = userNik,
                Title = $"{tipeLabel} Dihapus",
                Message = $"Data jadwal {tipeLabel.ToLower()} ({rentang}) telah berhasil dihapus dari sistem.",
                Url = "/roster",
                NotifType = "roster_deleted",
                IsRead = false,
                IsActioned = false,
                CreatedAt = DateTime.Now
            };
            _context.Notifications.Add(notifDelete);

            await _context.SaveChangesAsync();

            return Ok(new { success = true, message = $"{tipeLabel} berhasil dihapus." });
        }
    }

    public class RosterSaveModel
    {
        public int? Id { get; set; }
        public string? TipeRoster { get; set; } = "REGULER"; // "REGULER" or "TUGAS"
        public string? Keterangan { get; set; }
        public string AwalDinas { get; set; } = string.Empty;
        public string AkhirDinas { get; set; } = string.Empty;
        public string? AwalCuti { get; set; }
        public string? AkhirCuti { get; set; }
    }

    public class RosterWithReinduksiSaveModel
    {
        public int? Id { get; set; }
        public string? TipeRoster { get; set; } = "REGULER";
        public string? Keterangan { get; set; }
        public string AwalDinas { get; set; } = string.Empty;
        public string AkhirDinas { get; set; } = string.Empty;
        public string? AwalCuti { get; set; }
        public string? AkhirCuti { get; set; }

        public string? Nama { get; set; }
        public string? Perusahaan { get; set; }
        public string? Jabatan { get; set; }
        public string? Departemen { get; set; }
        public string? NikPengawas { get; set; }
        public string? NamaPengawas { get; set; }
        public string? TanggalMulaiOffsite { get; set; }
        public string? TanggalMulaiOnsite { get; set; }

        public string? Q1Answer { get; set; }
        public string? Q1Notes { get; set; }
        public string? Q2Answer { get; set; }
        public string? Q2Notes { get; set; }
        public string? Q3Answer { get; set; }
        public string? Q3Notes { get; set; }
        public string? Q4Answer { get; set; }
        public string? Q4Notes { get; set; }
        public string? Q5Answer { get; set; }
        public string? Q5Notes { get; set; }
        public string? Q6Answer { get; set; }
        public string? Q6Notes { get; set; }
        public string? Q7Answer { get; set; }
        public string? Q7Notes { get; set; }

        public string? SignatureKaryawan { get; set; }
        public bool? IsExempt { get; set; }
    }

    public class ReinduksiActionModel
    {
        public int ReinduksiId { get; set; }
        public string Action { get; set; } = string.Empty; // "APPROVE" or "REJECT"
        public string? Notes { get; set; }
        public string? SignaturePengawas { get; set; }
    }

    public class ReinduksiBatchActionModel
    {
        public List<int>? ReinduksiIds { get; set; }
        public string Action { get; set; } = string.Empty; // "APPROVE" or "REJECT"
        public string? Notes { get; set; }
        public string? SignaturePengawas { get; set; }
    }
}
