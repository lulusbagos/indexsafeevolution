using System;
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
    [Route("api")]
    [AllowAnonymous]
    public class NotificationController : ControllerBase
    {
        private readonly AppDbContext _context;
        private static bool _schemaEnsured = false;

        public NotificationController(AppDbContext context)
        {
            _context = context;
        }

        private string GetCurrentNik()
        {
            var nik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(nik) && Request.Headers.TryGetValue("X-User-Nik", out var headerNik))
            {
                nik = headerNik.FirstOrDefault();
            }
            return nik ?? "0000";
        }

        private async Task EnsureSchemaAsync()
        {
            if (_schemaEnsured) return;
            try
            {
                await _context.Database.ExecuteSqlRawAsync(@"
                    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[tbl_t_notifications]') AND name = 'is_actioned')
                    BEGIN
                        ALTER TABLE [tbl_t_notifications] ADD [is_actioned] BIT NOT NULL CONSTRAINT DF_tbl_t_notifications_is_actioned DEFAULT (0);
                    END
                    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[tbl_t_notifications]') AND name = 'logo')
                    BEGIN
                        ALTER TABLE [tbl_t_notifications] ADD [logo] NVARCHAR(500) NULL;
                    END
                    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[tbl_t_notifications]') AND name = 'category')
                    BEGIN
                        ALTER TABLE [tbl_t_notifications] ADD [category] NVARCHAR(100) NULL;
                    END
                    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[tbl_t_notifications]') AND name = 'sender_name')
                    BEGIN
                        ALTER TABLE [tbl_t_notifications] ADD [sender_name] NVARCHAR(150) NULL;
                    END
                    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[tbl_t_notifications]') AND name = 'priority')
                    BEGIN
                        ALTER TABLE [tbl_t_notifications] ADD [priority] NVARCHAR(50) NULL CONSTRAINT DF_tbl_t_notifications_priority DEFAULT ('normal');
                    END
                    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[tbl_t_notifications]') AND name = 'payload')
                    BEGIN
                        ALTER TABLE [tbl_t_notifications] ADD [payload] NVARCHAR(MAX) NULL;
                    END
                    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[tbl_t_notifications]') AND name = 'action_text')
                    BEGIN
                        ALTER TABLE [tbl_t_notifications] ADD [action_text] NVARCHAR(100) NULL;
                    END
                ");
                _schemaEnsured = true;
            }
            catch
            {
                // Silently fallback if column exists or permission restricted
                _schemaEnsured = true;
            }
        }

        private bool CheckIsActionRequired(string? type, string title, string message)
        {
            var combined = (title + " " + message).ToLower();
            var t = type?.ToLower() ?? "";

            // Coaching / Pembinaan adalah notifikasi informasi penerimaan coaching dari PIC yang TIDAK membutuhkan status / tindak lanjut
            if (combined.Contains("coaching") || combined.Contains("pembinaan") || t.Contains("coaching"))
            {
                return false;
            }

            // Notifikasi jadwal Roster & Periode Tugas adalah notifikasi informasi (bukan temuan yang butuh tindak lanjut mitigasi)
            if (t.StartsWith("roster") || combined.Contains("roster") || combined.Contains("periode tugas"))
            {
                return false;
            }

            if (t.StartsWith("hazard_") || t.StartsWith("inspection_") || t.StartsWith("actionplan_") || t.StartsWith("rci_approval") || t.StartsWith("rci_pic_task"))
            {
                return true;
            }

            return combined.Contains("temuan") ||
                   combined.Contains("penugasan") ||
                   combined.Contains("perlu mitigasi") ||
                   combined.Contains("tindakan perbaikan") ||
                   combined.Contains("action plan") ||
                   combined.Contains("assigned") ||
                   combined.Contains("reassign");
        }

        private async Task EnsurePendingTagNotificationsAsync(string userNik)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(userNik)) return;
                userNik = userNik.Trim();
                bool hasNew = false;

                // 1. Hazard Reports where user is assigned as PJA and not Closed
                var activeHazards = await _context.HazardReports
                    .AsNoTracking()
                    .Where(h => !h.IsDeleted && h.NikPja != null && h.NikPja.Trim() == userNik && h.StatusTemuan != "Closed")
                    .OrderByDescending(h => h.Id)
                    .Take(25)
                    .ToListAsync();

                foreach (var h in activeHazards)
                {
                    bool exists = await _context.Notifications
                        .AnyAsync(n => n.RecipientNik == userNik && !n.IsActioned &&
                            (n.Url == $"/Hazard/Detail/{h.Id}" || n.Message.Contains($"#{h.Id}")));
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Penugasan PJA Temuan Hazard",
                            Message = $"Anda ditunjuk sebagai PJA untuk temuan Hazard #{h.Id} di {h.Lokasi ?? h.Area}. Segera tindaklanjuti (Take Up) atau alihkan ke PJA lain jika salah sasaran.",
                            Url = $"/Hazard/Detail/{h.Id}",
                            NotifType = "hazard_assigned",
                            Category = "hazard",
                            SenderName = h.Nama ?? "Pelapor K3",
                            Priority = "urgent",
                            ActionText = "Tindak Lanjut PJA",
                            IsRead = false,
                            IsActioned = false,
                            CreatedAt = h.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // 2. Action Plans where user is assigned as PIC and not Closed
                var activePics = await _context.ActionPlans
                    .AsNoTracking()
                    .Where(a => !a.IsDeleted && a.NikPic != null && a.NikPic.Trim() == userNik && a.Status != "Closed")
                    .OrderByDescending(a => a.Id)
                    .Take(25)
                    .ToListAsync();

                foreach (var ap in activePics)
                {
                    bool exists = await _context.Notifications
                        .AnyAsync(n => n.RecipientNik == userNik && !n.IsActioned &&
                            (n.Url == $"/ActionPlan/Detail/{ap.Id}" || n.Message.Contains($"AP-#{ap.Id}") || n.Message.Contains($"#{ap.Id}")));
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Penugasan PIC Tindak Lanjut (Action Plan)",
                            Message = $"Anda ditugaskan sebagai PIC untuk tindakan perbaikan di {ap.Lokasi ?? ap.Area} (AP-#{ap.Id}). Segera selesaikan dan laporkan bukti perbaikan.",
                            Url = $"/ActionPlan/Detail/{ap.Id}",
                            NotifType = "actionplan_assigned",
                            Category = "actionplan",
                            SenderName = ap.Pja ?? "PJA Area",
                            Priority = "urgent",
                            ActionText = "Lapor Perbaikan",
                            IsRead = false,
                            IsActioned = false,
                            CreatedAt = ap.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // 3. Action Plans where user is assigned as PJA and not Closed (needs PIC assignment)
                var activePjas = await _context.ActionPlans
                    .AsNoTracking()
                    .Where(a => !a.IsDeleted && a.NikPja != null && a.NikPja.Trim() == userNik && (a.NikPic == null || a.NikPic == "") && a.Status != "Closed")
                    .OrderByDescending(a => a.Id)
                    .Take(25)
                    .ToListAsync();

                foreach (var ap in activePjas)
                {
                    bool exists = await _context.Notifications
                        .AnyAsync(n => n.RecipientNik == userNik && !n.IsActioned &&
                            (n.Url == $"/ActionPlan/Detail/{ap.Id}" || n.Message.Contains($"AP-#{ap.Id}") || n.Message.Contains($"#{ap.Id}")));
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Penugasan PJA Action Plan",
                            Message = $"Anda ditunjuk sebagai PJA untuk temuan K3 di {ap.Lokasi ?? ap.Area} (AP-#{ap.Id}). Silakan tentukan PIC dan rencana perbaikan.",
                            Url = $"/ActionPlan/Detail/{ap.Id}",
                            NotifType = "actionplan_pja_assigned",
                            Category = "actionplan",
                            SenderName = ap.Nama ?? "Pelapor K3",
                            Priority = "urgent",
                            ActionText = "Tentukan PIC",
                            IsRead = false,
                            IsActioned = false,
                            CreatedAt = ap.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // 4. Inspeksi where user is assigned as PJA
                var cutoffInsp = DateTime.Now.AddDays(-30);
                var activeInspections = await _context.Inspections
                    .AsNoTracking()
                    .Where(i => !i.IsDeleted && i.NikPja != null && i.NikPja.Trim() == userNik && i.CreatedAt >= cutoffInsp)
                    .OrderByDescending(i => i.Id)
                    .Take(25)
                    .ToListAsync();

                foreach (var insp in activeInspections)
                {
                    bool exists = await _context.Notifications
                        .AnyAsync(n => n.RecipientNik == userNik && !n.IsActioned &&
                            (n.Url == $"/Inspection/Detail/{insp.Id}" || n.Message.Contains($"INSP-#{insp.Id}") || n.Message.Contains($"#{insp.Id}")));
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Penugasan PJA Temuan Inspeksi",
                            Message = $"Anda ditunjuk sebagai PJA untuk temuan Inspeksi ({insp.JenisInspeksi}) di {insp.Area} - {insp.Lokasi} (INSP-#{insp.Id}).",
                            Url = $"/Inspection/Detail/{insp.Id}",
                            NotifType = "inspection_assigned",
                            Category = "inspection",
                            SenderName = insp.Nama ?? "Auditor Inspeksi",
                            Priority = "urgent",
                            ActionText = "Lihat Inspeksi",
                            IsRead = false,
                            IsActioned = false,
                            CreatedAt = insp.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // 5. Condition Index (CI: FCI, RCI, DCI, SPI, GCI) PIC informational notifications (tidak harus di-followup, hanya pemberitahuan)
                // FCI
                var fciPics = await _context.FciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && r.Pic != null && r.Pic.Contains(userNik))
                    .OrderByDescending(r => r.Id).Take(15).ToListAsync();
                foreach (var r in fciPics)
                {
                    bool exists = await _context.Notifications.AnyAsync(n => n.RecipientNik == userNik && n.Url == $"/Fci/Detail/{r.Id}");
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Informasi Nilai FCI (Front Condition Index)",
                            Message = $"Informasi Nilai FCI: {r.TotalScore}% ({r.KategoriIndex}) di {r.NamaFront ?? r.Lokasi}. Rekomendasi: {r.TindakanPerbaikan ?? "Pemantauan rutin"}. Notifikasi ini bersifat informasi kondisi front dan tidak perlu di-follow up.",
                            Url = $"/Fci/Detail/{r.Id}",
                            NotifType = "ci_pic_info",
                            Category = "info",
                            SenderName = r.Nama ?? "Auditor FCI",
                            Priority = "normal",
                            ActionText = null,
                            IsRead = false,
                            IsActioned = true,
                            CreatedAt = r.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // RCI
                var rciPics = await _context.RciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && r.Pic != null && r.Pic.Contains(userNik))
                    .OrderByDescending(r => r.Id).Take(15).ToListAsync();
                foreach (var r in rciPics)
                {
                    bool exists = await _context.Notifications.AnyAsync(n => n.RecipientNik == userNik && n.Url == $"/Rci/Detail/{r.Id}");
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Pemberitahuan PIC Assessment RCI",
                            Message = $"Anda dicatat sebagai PIC perbaikan Road Condition Index di {r.NamaJalan ?? r.Lokasi} (Skor: {r.TotalScore}% - {r.KategoriIndex}). Pemberitahuan ini bersifat informatif.",
                            Url = $"/Rci/Detail/{r.Id}",
                            NotifType = "ci_pic_info",
                            Category = "info",
                            SenderName = r.Nama ?? "Auditor RCI",
                            Priority = "normal",
                            ActionText = null,
                            IsRead = false,
                            IsActioned = true,
                            CreatedAt = r.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // DCI
                var dciPics = await _context.DciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && r.Pic != null && r.Pic.Contains(userNik))
                    .OrderByDescending(r => r.Id).Take(15).ToListAsync();
                foreach (var r in dciPics)
                {
                    bool exists = await _context.Notifications.AnyAsync(n => n.RecipientNik == userNik && n.Url == $"/Dci/Detail/{r.Id}");
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Pemberitahuan PIC Assessment DCI",
                            Message = $"Anda dicatat sebagai PIC perbaikan Disposal Condition Index di {r.Disposal ?? r.NamaDump ?? r.Lokasi} (Skor: {r.TotalScore}% - {r.KategoriIndex}). Pemberitahuan ini bersifat informatif.",
                            Url = $"/Dci/Detail/{r.Id}",
                            NotifType = "ci_pic_info",
                            Category = "info",
                            SenderName = r.Nama ?? "Auditor DCI",
                            Priority = "normal",
                            ActionText = null,
                            IsRead = false,
                            IsActioned = true,
                            CreatedAt = r.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // SPI
                var spiPics = await _context.SpiReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && r.Pic != null && r.Pic.Contains(userNik))
                    .OrderByDescending(r => r.Id).Take(15).ToListAsync();
                foreach (var r in spiPics)
                {
                    bool exists = await _context.Notifications.AnyAsync(n => n.RecipientNik == userNik && n.Url == $"/Spi/Detail/{r.Id}");
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Pemberitahuan PIC Assessment SPI",
                            Message = $"Anda dicatat sebagai PIC fasilitas Sediment Pond di {r.NamaKolam ?? r.Lokasi} (Skor: {r.TotalScore}% - {r.KategoriIndex}). Pemberitahuan ini bersifat informatif.",
                            Url = $"/Spi/Detail/{r.Id}",
                            NotifType = "ci_pic_info",
                            Category = "info",
                            SenderName = r.Nama ?? "Auditor SPI",
                            Priority = "normal",
                            ActionText = null,
                            IsRead = false,
                            IsActioned = true,
                            CreatedAt = r.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                // GCI
                var gciPics = await _context.GciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && ((r.Pic != null && r.Pic.Contains(userNik)) || (r.PicNik != null && r.PicNik.Contains(userNik))))
                    .OrderByDescending(r => r.Id).Take(15).ToListAsync();
                foreach (var r in gciPics)
                {
                    bool exists = await _context.Notifications.AnyAsync(n => n.RecipientNik == userNik && n.Url == $"/Gci/Detail/{r.Id}");
                    if (!exists)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = userNik,
                            Title = "Pemberitahuan PIC Assessment GCI (Geoteknik)",
                            Message = $"Anda dicatat sebagai PIC penanganan geoteknik di {r.Pit} - {r.NamaLereng ?? r.Lokasi} (TARP: {r.TarpLevel}). Pemberitahuan ini bersifat informatif.",
                            Url = $"/Gci/Detail/{r.Id}",
                            NotifType = "ci_pic_info",
                            Category = "info",
                            SenderName = r.Nama ?? "Geotechnical Engineer",
                            Priority = "normal",
                            ActionText = null,
                            IsRead = false,
                            IsActioned = true,
                            CreatedAt = r.CreatedAt
                        });
                        hasNew = true;
                    }
                }

                if (hasNew)
                {
                    await _context.SaveChangesAsync();
                }
            }
            catch
            {
                // Jangan menggagalkan request jika ada kendala seeding
            }
        }

        [HttpGet("notifications/count")]
        public async Task<IActionResult> GetNotificationCounts()
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik()?.Trim() ?? "";
            if (!string.IsNullOrEmpty(userNik))
            {
                await EnsurePendingTagNotificationsAsync(userNik);
            }
            var coachingCutoff = DateTime.Now.AddDays(-7);

            // Sesuai permintaan pengguna:
            // 1. Notifikasi completed/closed tidak ditampilkan
            // 2. Coaching hanya bertahan 7 hari, setelah itu hilang
            // 3. Coaching tidak memiliki status/tindak lanjut (tidak masuk unactioned)
            int unreadCount = await _context.Notifications
                .CountAsync(n => !string.IsNullOrEmpty(n.RecipientNik) && n.RecipientNik.Trim() == userNik 
                    && !n.IsRead 
                    && !n.IsActioned 
                    && n.NotifType != "hazard_completed" 
                    && n.NotifType != "hazard_closed"
                    && !(
                        (n.Title.Contains("Coaching") || n.Title.Contains("Pembinaan") || n.Message.Contains("Coaching") || n.Message.Contains("Pembinaan") || (n.NotifType != null && n.NotifType.Contains("coaching")) || (n.Url != null && n.Url.Contains("Performance")))
                        && n.CreatedAt < coachingCutoff
                    )
                );

            int unactionedNotifs = await _context.Notifications
                .CountAsync(n => !string.IsNullOrEmpty(n.RecipientNik) && n.RecipientNik.Trim() == userNik 
                    && !n.IsActioned 
                    && n.NotifType != "hazard_completed" 
                    && n.NotifType != "hazard_closed"
                    && !n.Title.Contains("Coaching") 
                    && !n.Title.Contains("Pembinaan") 
                    && !n.Message.Contains("Coaching") 
                    && !n.Message.Contains("Pembinaan")
                    && (n.NotifType == null || !n.NotifType.Contains("coaching"))
                    && (n.Url == null || !n.Url.Contains("Performance"))
                );

            // Periksa temuan aktif di database yang secara spesifik menunjuk user yang login sebagai PJA
            int activeHazardPja = await _context.HazardReports
                .CountAsync(h => !h.IsDeleted && h.NikPja != null && h.NikPja.Trim() == userNik && h.StatusTemuan != "Closed");
            int activeActionPlans = await _context.ActionPlans
                .CountAsync(a => !a.IsDeleted && ((a.NikPic != null && a.NikPic.Trim() == userNik) || (a.NikPja != null && a.NikPja.Trim() == userNik)) && a.Status != "Closed");

            int totalActionPending = Math.Max(unactionedNotifs, activeHazardPja + activeActionPlans);
            int totalPending = Math.Max(unreadCount, totalActionPending);

            return Ok(new
            {
                status = true,
                unread_count = unreadCount,
                unactioned_count = totalActionPending,
                total_pending_count = totalPending,
                active_hazard_count = activeHazardPja,
                active_action_plan_count = activeActionPlans
            });
        }

        [HttpGet("notifications")]
        public async Task<IActionResult> GetNotifications([FromQuery] int limit = 100, [FromQuery] int? sinceId = null, [FromQuery] int months = 3)
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik()?.Trim() ?? "";
            if (!string.IsNullOrEmpty(userNik))
            {
                await EnsurePendingTagNotificationsAsync(userNik);
            }
            var coachingCutoff = DateTime.Now.AddDays(-7);
            var cutoffDate = DateTime.Now.AddMonths(-Math.Max(1, months));

            // Sesuai permintaan pengguna:
            // 1. Tarik data 3 bulan terakhir agar tidak berat
            // 2. Jika ada sinceId, hanya ambil data terbaru di atas sinceId (incremental fetch)
            // 3. Notifikasi yang sudah complete / closed tidak usah ditampilkan
            // 4. Notifikasi Coaching otomatis kadaluarsa & hilang setelah 7 hari
            var query = _context.Notifications
                .Where(n => !string.IsNullOrEmpty(n.RecipientNik) && n.RecipientNik.Trim() == userNik)
                .Where(n => n.CreatedAt >= cutoffDate)
                .Where(n => !n.IsActioned && n.NotifType != "hazard_completed" && n.NotifType != "hazard_closed")
                .Where(n => !(
                    (n.Title.Contains("Coaching") || n.Title.Contains("Pembinaan") || n.Message.Contains("Coaching") || n.Message.Contains("Pembinaan") || (n.NotifType != null && n.NotifType.Contains("coaching")) || (n.Url != null && n.Url.Contains("Performance")))
                    && n.CreatedAt < coachingCutoff
                ));

            if (sinceId.HasValue && sinceId.Value > 0)
            {
                query = query.Where(n => n.Id > sinceId.Value);
            }

            var notifs = await query
                .OrderByDescending(n => n.CreatedAt)
                .Take(limit)
                .ToListAsync();

            var result = notifs.Select(n =>
            {
                bool actionRequired = CheckIsActionRequired(n.NotifType, n.Title, n.Message);
                bool isCoaching = (n.NotifType != null && n.NotifType.ToLower().Contains("coaching")) ||
                                  n.Title.ToLower().Contains("coaching") ||
                                  n.Title.ToLower().Contains("pembinaan") ||
                                  n.Message.ToLower().Contains("coaching") ||
                                  n.Message.ToLower().Contains("pembinaan") ||
                                  (n.Url != null && n.Url.ToLower().Contains("performance"));

                return new
                {
                    id = n.Id,
                    title = n.Title,
                    message = n.Message,
                    url = n.Url,
                    is_read = n.IsRead,
                    is_actioned = n.IsActioned,
                    is_action_required = actionRequired,
                    notif_type = isCoaching ? "coaching" : (n.NotifType ?? "general"),
                    logo = n.Logo,
                    category = n.Category ?? (isCoaching ? "coaching" : (n.NotifType ?? "general")),
                    sender_name = n.SenderName,
                    priority = n.Priority ?? "normal",
                    payload = n.Payload,
                    action_text = n.ActionText,
                    created_at = n.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                };
            }).ToList();

            // Hitung secara presisi di seluruh database untuk user yang sedang login (hanya yang aktif/belum complete)
            int unreadCount = await _context.Notifications
                .CountAsync(n => !string.IsNullOrEmpty(n.RecipientNik) && n.RecipientNik.Trim() == userNik 
                    && !n.IsRead 
                    && !n.IsActioned 
                    && n.NotifType != "hazard_completed" 
                    && n.NotifType != "hazard_closed"
                    && !(
                        (n.Title.Contains("Coaching") || n.Title.Contains("Pembinaan") || n.Message.Contains("Coaching") || n.Message.Contains("Pembinaan") || (n.NotifType != null && n.NotifType.Contains("coaching")) || (n.Url != null && n.Url.Contains("Performance")))
                        && n.CreatedAt < coachingCutoff
                    )
                );

            int unactionedNotifs = await _context.Notifications
                .CountAsync(n => !string.IsNullOrEmpty(n.RecipientNik) && n.RecipientNik.Trim() == userNik 
                    && !n.IsActioned 
                    && n.NotifType != "hazard_completed" 
                    && n.NotifType != "hazard_closed"
                    && !n.Title.Contains("Coaching") 
                    && !n.Title.Contains("Pembinaan") 
                    && !n.Message.Contains("Coaching") 
                    && !n.Message.Contains("Pembinaan")
                    && (n.NotifType == null || !n.NotifType.Contains("coaching"))
                    && (n.Url == null || !n.Url.Contains("Performance"))
                );

            int activeHazardFindings = await _context.HazardReports
                .CountAsync(h => !h.IsDeleted && h.NikPja != null && h.NikPja.Trim() == userNik && h.StatusTemuan != "Closed");
            int activeActionPlans = await _context.ActionPlans
                .CountAsync(a => !a.IsDeleted && ((a.NikPic != null && a.NikPic.Trim() == userNik) || (a.NikPja != null && a.NikPja.Trim() == userNik)) && a.Status != "Closed");

            int totalActionPending = Math.Max(unactionedNotifs, activeHazardFindings + activeActionPlans);
            int totalPending = Math.Max(unreadCount, totalActionPending);

            return Ok(new
            {
                status = true,
                unread_count = unreadCount,
                unactioned_count = totalActionPending,
                total_pending_count = totalPending,
                active_hazard_count = activeHazardFindings,
                active_action_plan_count = activeActionPlans,
                data = result
            });
        }

        [HttpPost("notifications/test")]
        public async Task<IActionResult> CreateTestNotification([FromBody] dynamic? payload)
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik();
            var newNotif = new Indexsafe.Api.Models.Notification
            {
                RecipientNik = userNik,
                Title = "Penugasan Temuan Hazard K3 (Kritis)",
                Message = $"Notifikasi K3 Darurat: Temuan bahaya K3 baru dialihkan ke Anda pada {DateTime.Now:HH:mm}. Segera ambil tindakan perbaikan!",
                Url = "/Hazard/Index",
                NotifType = "hazard_new",
                IsRead = false,
                IsActioned = false,
                CreatedAt = DateTime.Now
            };

            _context.Notifications.Add(newNotif);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Notifikasi uji coba temuan K3 berhasil dibuat.",
                data = new
                {
                    id = newNotif.Id,
                    title = newNotif.Title,
                    message = newNotif.Message,
                    url = newNotif.Url,
                    is_read = newNotif.IsRead,
                    is_actioned = false,
                    is_action_required = true,
                    notif_type = newNotif.NotifType,
                    created_at = newNotif.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }

        [HttpPost("notifications/{id}/read")]
        public async Task<IActionResult> MarkAsRead(int id)
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik();
            var notif = await _context.Notifications
                .FirstOrDefaultAsync(n => n.Id == id && n.RecipientNik == userNik);

            if (notif != null)
            {
                notif.IsRead = true;
                await _context.SaveChangesAsync();
                return Ok(new { status = true, message = "Notifikasi ditandai sudah dibaca." });
            }

            return NotFound(new { status = false, message = "Notifikasi tidak ditemukan." });
        }

        [HttpPost("notifications/{id}/action")]
        public async Task<IActionResult> MarkAsActioned(int id)
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik();
            var notif = await _context.Notifications
                .FirstOrDefaultAsync(n => n.Id == id && n.RecipientNik == userNik);

            if (notif != null)
            {
                notif.IsActioned = true;
                notif.IsRead = true; // Otomatis terbaca ketika di-action
                await _context.SaveChangesAsync();
                return Ok(new { status = true, message = "Tindakan atas temuan berhasil ditandai selesai." });
            }

            return NotFound(new { status = false, message = "Notifikasi tidak ditemukan." });
        }

        [HttpPost("notifications/read-all")]
        public async Task<IActionResult> MarkAllAsRead()
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik();
            var unread = await _context.Notifications
                .Where(n => n.RecipientNik == userNik && !n.IsRead)
                .ToListAsync();

            foreach (var n in unread)
            {
                n.IsRead = true;
            }

            await _context.SaveChangesAsync();
            return Ok(new { status = true, message = "Semua notifikasi ditandai sudah dibaca." });
        }

        [HttpPost("notifications/action-all")]
        public async Task<IActionResult> MarkAllAsActioned()
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik();
            var unactioned = await _context.Notifications
                .Where(n => n.RecipientNik == userNik && !n.IsActioned)
                .ToListAsync();

            foreach (var n in unactioned)
            {
                n.IsActioned = true;
                n.IsRead = true;
            }

            await _context.SaveChangesAsync();
            return Ok(new { status = true, message = "Semua tindakan temuan berhasil ditandai selesai." });
        }

        [AllowAnonymous]
        [HttpPost("notifications/send")]
        public async Task<IActionResult> SendNotification([FromBody] SendNotificationDto dto)
        {
            await EnsureSchemaAsync();
            if (string.IsNullOrWhiteSpace(dto.Title) || string.IsNullOrWhiteSpace(dto.Message))
            {
                return BadRequest(new { status = false, message = "Judul (Title) dan Pesan (Message) wajib diisi." });
            }

            var notificationsToAdd = new System.Collections.Generic.List<Indexsafe.Api.Models.Notification>();

            if (dto.IsBroadcast || (dto.RecipientNiks == null || dto.RecipientNiks.Count == 0))
            {
                // Kirim broadcast ke semua karyawan aktif
                var allActiveNiks = await _context.Karyawans
                    .Where(k => k.StatusAktif && !string.IsNullOrEmpty(k.NoNik))
                    .Select(k => k.NoNik)
                    .Distinct()
                    .ToListAsync();

                foreach (var nik in allActiveNiks)
                {
                    notificationsToAdd.Add(new Indexsafe.Api.Models.Notification
                    {
                        RecipientNik = nik.Trim(),
                        Title = dto.Title,
                        Message = dto.Message,
                        Url = dto.Url,
                        NotifType = dto.NotifType ?? "announcement",
                        Logo = dto.Logo,
                        Category = dto.Category ?? "broadcast",
                        SenderName = dto.SenderName ?? "Pusat Informasi K3",
                        Priority = dto.Priority ?? "normal",
                        Payload = dto.Payload,
                        ActionText = dto.ActionText,
                        CreatedAt = DateTime.Now
                    });
                }
            }
            else
            {
                foreach (var nik in dto.RecipientNiks)
                {
                    if (string.IsNullOrWhiteSpace(nik)) continue;
                    notificationsToAdd.Add(new Indexsafe.Api.Models.Notification
                    {
                        RecipientNik = nik.Trim(),
                        Title = dto.Title,
                        Message = dto.Message,
                        Url = dto.Url,
                        NotifType = dto.NotifType ?? "general",
                        Logo = dto.Logo,
                        Category = dto.Category ?? "direct",
                        SenderName = dto.SenderName ?? "Pusat Informasi K3",
                        Priority = dto.Priority ?? "normal",
                        Payload = dto.Payload,
                        ActionText = dto.ActionText,
                        CreatedAt = DateTime.Now
                    });
                }
            }

            if (notificationsToAdd.Count > 0)
            {
                await _context.Notifications.AddRangeAsync(notificationsToAdd);
                await _context.SaveChangesAsync();
            }

            return Ok(new
            {
                status = true,
                message = $"Berhasil mengirim notifikasi ke {notificationsToAdd.Count} penerima.",
                total_sent = notificationsToAdd.Count
            });
        }
    }

    public class SendNotificationDto
    {
        public System.Collections.Generic.List<string>? RecipientNiks { get; set; }
        public bool IsBroadcast { get; set; } = false;
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string? Url { get; set; }
        public string? NotifType { get; set; }
        public string? Logo { get; set; }
        public string? Category { get; set; }
        public string? SenderName { get; set; }
        public string? Priority { get; set; }
        public string? Payload { get; set; }
        public string? ActionText { get; set; }
    }
}
