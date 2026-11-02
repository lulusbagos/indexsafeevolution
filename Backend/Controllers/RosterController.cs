using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
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

        public RosterController(AppDbContext context)
        {
            _context = context;
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

            // Roster dinyatakan sudah disetting jika memiliki roster aktif atau jadwal terkini belum kadaluarsa
            bool hasConfiguredRoster = activeRoster != null || (latestRoster != null && latestRoster.AkhirCuti >= today);

            // Cek Re-Induksi terkini
            var latestReinduksi = await _context.Reinduksis.AsNoTracking()
                .Where(x => x.Nik == userNik && !x.IsDeleted)
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync();

            return Ok(new
            {
                success = true,
                hasConfiguredRoster,
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

            // Check active status for current month target
            bool isTugasExempt = false;
            int computedOnsiteDays = 0;
            bool hasRoster = false;

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
                    if (overlapStart <= overlapEnd)
                    {
                        computedOnsiteDays += (overlapEnd - overlapStart).Days + 1;
                        hasRoster = true;
                    }
                }
            }

            var activeRoster = historyRaw.FirstOrDefault(r => today >= r.AwalDinas.Date && today <= r.AkhirCuti.Date && r.Status != "REJECTED");
            var latestRoster = historyRaw.FirstOrDefault(r => r.Status != "REJECTED");

            bool hasConfiguredRoster = activeRoster != null || (latestRoster != null && latestRoster.AkhirCuti >= today);

            double ratio = 1.0;
            if (isTugasExempt)
            {
                ratio = 0.0;
            }
            else if (hasRoster)
            {
                ratio = Math.Min(1.0, (double)computedOnsiteDays / totalDaysInMonth);
            }

            return Ok(new
            {
                success = true,
                hasConfiguredRoster,
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

            bool isTugas = string.Equals(req.TipeRoster, "TUGAS", StringComparison.OrdinalIgnoreCase);
            DateTime awalDinas, akhirDinas, awalCuti, akhirCuti;

            if (isTugas)
            {
                if (!DateTime.TryParse(req.AwalDinas, out awalDinas) || !DateTime.TryParse(req.AkhirDinas, out akhirDinas))
                {
                    return BadRequest(new { message = "Format tanggal periode tugas tidak valid." });
                }
                if (awalDinas > akhirDinas)
                {
                    return BadRequest(new { message = "Tanggal mulai tugas tidak boleh lebih besar dari akhir tugas." });
                }
                awalCuti = akhirDinas;
                akhirCuti = akhirDinas;
            }
            else
            {
                if (!DateTime.TryParse(req.AwalDinas, out awalDinas) ||
                    !DateTime.TryParse(req.AkhirDinas, out akhirDinas) ||
                    !DateTime.TryParse(req.AwalCuti, out awalCuti) ||
                    !DateTime.TryParse(req.AkhirCuti, out akhirCuti))
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
            }

            // Cek jabatan & pengecualian approval pengawas
            string userJabatan = req.Jabatan ?? "";
            var userDb = await _context.AppUsers.FirstOrDefaultAsync(u => u.Nik == userNik);
            if (string.IsNullOrWhiteSpace(userJabatan) && userDb != null)
            {
                // Cek karyawan view jika ada
                var kw = await _context.Karyawans.FirstOrDefaultAsync(k => k.NoNik == userNik);
                if (kw?.IdJabatan != null)
                {
                    var jb = await _context.Jabatans.FirstOrDefaultAsync(j => j.JabatanId == kw.IdJabatan.Value);
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
            string cleanPerusahaan = !string.IsNullOrWhiteSpace(req.Perusahaan) ? req.Perusahaan : (userDb?.Perusahaan ?? "-");
            string cleanDepartemen = !string.IsNullOrWhiteSpace(req.Departemen) ? req.Departemen : (userDb?.Departemen ?? "-");
            string? cleanNikPengawas = isExempt ? null : req.NikPengawas?.Trim();
            string? cleanNamaPengawas = isExempt ? null : req.NamaPengawas?.Trim();

            string finalStatus = isExempt ? "APPROVED" : "PENDING_APPROVAL";

            // Simpan / Perbarui Roster
            var newRoster = new Roster
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
            _context.Rosters.Add(newRoster);
            await _context.SaveChangesAsync();

            DateTime? tglOffsite = null;
            if (DateTime.TryParse(req.TanggalMulaiOffsite, out DateTime dtOff)) tglOffsite = dtOff;
            else if (awalCuti != DateTime.MinValue) tglOffsite = awalCuti;

            DateTime? tglOnsite = null;
            if (DateTime.TryParse(req.TanggalMulaiOnsite, out DateTime dtOn)) tglOnsite = dtOn;
            else if (awalDinas != DateTime.MinValue) tglOnsite = awalDinas;

            // Simpan Form Re-Induksi
            var reinduksi = new Reinduksi
            {
                RosterId = newRoster.Id,
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

            newRoster.IdReinduksi = reinduksi.Id;
            _context.Rosters.Update(newRoster);

            // Buat Notifikasi
            if (isExempt)
            {
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = userNik,
                    Title = "Roster & Re-Induksi Disetujui Otomatis",
                    Message = $"Pengaturan roster ({awalDinas:dd MMM} - {akhirDinas:dd MMM}) dan Form Re-Induksi telah disetujui otomatis sesuai jabatan {userJabatan}.",
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
                    Message = $"{cleanNama} ({userNik}) telah melengkapi Form Re-Induksi & Pengaturan Roster ({awalDinas:dd MMM} - {akhirDinas:dd MMM}). Harap periksa dan berikan persetujuan.",
                    Url = "/reinduksi-approval",
                    NotifType = "reinduksi_approval",
                    Category = "approval",
                    Payload = $"{{\"reinduksiId\": {reinduksi.Id}, \"rosterId\": {newRoster.Id}, \"nik\": \"{userNik}\"}}",
                    IsRead = false,
                    CreatedAt = DateTime.Now
                });

                // Notifikasi konfirmasi ke karyawan
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = userNik,
                    Title = "Form Re-Induksi Terkirim ke Pengawas",
                    Message = $"Pengaturan roster & Form Re-Induksi berhasil dikirim. Menunggu persetujuan Pengawas ({cleanNamaPengawas}).",
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
                    ? "Pengaturan roster dan Form Re-Induksi berhasil disimpan & disetujui otomatis."
                    : $"Form Re-Induksi & Pengaturan Roster berhasil dikirim dan menanti persetujuan dari Pengawas ({cleanNamaPengawas}).",
                rosterId = newRoster.Id,
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
}
