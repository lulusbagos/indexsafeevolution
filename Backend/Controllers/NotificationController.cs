using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api")]
    [Authorize]
    public class NotificationController : ControllerBase
    {
        private readonly AppDbContext _context;
        private static bool _schemaEnsured = false;

        public NotificationController(AppDbContext context)
        {
            _context = context;
        }

        private string GetCurrentNik() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0000";

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

            if (t.StartsWith("hazard_") || t.StartsWith("inspection_") || t.StartsWith("actionplan_"))
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

        [HttpGet("notifications/count")]
        public async Task<IActionResult> GetNotificationCounts()
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik()?.Trim() ?? "";
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
        public async Task<IActionResult> GetNotifications([FromQuery] int limit = 50)
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik()?.Trim() ?? "";
            var coachingCutoff = DateTime.Now.AddDays(-7);

            // Sesuai permintaan pengguna:
            // 1. Notifikasi yang sudah complete / closed tidak usah ditampilkan
            // 2. Notifikasi Coaching otomatis kadaluarsa & hilang setelah 7 hari
            var notifs = await _context.Notifications
                .Where(n => !string.IsNullOrEmpty(n.RecipientNik) && n.RecipientNik.Trim() == userNik)
                .Where(n => !n.IsActioned && n.NotifType != "hazard_completed" && n.NotifType != "hazard_closed")
                .Where(n => !(
                    (n.Title.Contains("Coaching") || n.Title.Contains("Pembinaan") || n.Message.Contains("Coaching") || n.Message.Contains("Pembinaan") || (n.NotifType != null && n.NotifType.Contains("coaching")) || (n.Url != null && n.Url.Contains("Performance")))
                    && n.CreatedAt < coachingCutoff
                ))
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
    }
}
