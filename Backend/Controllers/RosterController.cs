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
    [Authorize]
    public class RosterController : ControllerBase
    {
        private readonly AppDbContext _context;

        public RosterController(AppDbContext context)
        {
            _context = context;
        }

        private string GetCurrentNik() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0000";

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

            var activeRoster = historyRaw.FirstOrDefault(r => today >= r.AwalDinas.Date && today <= r.AkhirCuti.Date);
            var latestRoster = historyRaw.FirstOrDefault();

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
                history,
                activeRoster = activeRoster != null ? new
                {
                    activeRoster.Id,
                    AwalDinas = activeRoster.AwalDinas.ToString("yyyy-MM-dd"),
                    AkhirDinas = activeRoster.AkhirDinas.ToString("yyyy-MM-dd"),
                    AwalCuti = activeRoster.AwalCuti.ToString("yyyy-MM-dd"),
                    AkhirCuti = activeRoster.AkhirCuti.ToString("yyyy-MM-dd"),
                    TipeRoster = activeRoster.TipeRoster ?? "REGULER",
                    activeRoster.Keterangan
                } : null,
                latestRoster = latestRoster != null ? new
                {
                    latestRoster.Id,
                    AwalDinas = latestRoster.AwalDinas.ToString("yyyy-MM-dd"),
                    AkhirDinas = latestRoster.AkhirDinas.ToString("yyyy-MM-dd"),
                    AwalCuti = latestRoster.AwalCuti.ToString("yyyy-MM-dd"),
                    AkhirCuti = latestRoster.AkhirCuti.ToString("yyyy-MM-dd"),
                    TipeRoster = latestRoster.TipeRoster ?? "REGULER",
                    latestRoster.Keterangan
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
}
