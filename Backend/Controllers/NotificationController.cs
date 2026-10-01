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
            var t = type?.ToLower() ?? "";
            if (t.StartsWith("hazard_") || t.StartsWith("inspection_") || t.StartsWith("actionplan_"))
            {
                return true;
            }

            var combined = (title + " " + message).ToLower();
            return combined.Contains("temuan") ||
                   combined.Contains("penugasan") ||
                   combined.Contains("perlu mitigasi") ||
                   combined.Contains("tindakan perbaikan") ||
                   combined.Contains("action plan") ||
                   combined.Contains("assigned") ||
                   combined.Contains("reassign");
        }

        [HttpGet("notifications")]
        public async Task<IActionResult> GetNotifications([FromQuery] int limit = 50)
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik();

            var notifs = await _context.Notifications
                .Where(n => n.RecipientNik == userNik)
                .OrderByDescending(n => n.CreatedAt)
                .Take(limit)
                .ToListAsync();

            // If user has no notifications yet, seed welcoming & actual safety notifications
            if (notifs.Count == 0)
            {
                var seedNotifs = new[]
                {
                    new Indexsafe.Api.Models.Notification
                    {
                        RecipientNik = userNik,
                        Title = "Penugasan Temuan Hazard K3 (Kritis)",
                        Message = "Temuan potensi bahaya K3 baru di Pit Utara dialihkan kepada Anda sebagai PJA. Segera lakukan tindakan perbaikan & mitigasi!",
                        Url = "/Hazard/Index",
                        NotifType = "hazard_new",
                        IsRead = false,
                        IsActioned = false,
                        CreatedAt = DateTime.Now.AddMinutes(-5)
                    },
                    new Indexsafe.Api.Models.Notification
                    {
                        RecipientNik = userNik,
                        Title = "Action Plan Temuan Inspeksi",
                        Message = "Tindakan perbaikan hasil inspeksi area workshop memerlukan persetujuan dan verifikasi lapangan dari Anda.",
                        Url = "/ActionTracker/Index",
                        NotifType = "actionplan_new",
                        IsRead = false,
                        IsActioned = false,
                        CreatedAt = DateTime.Now.AddHours(-1)
                    },
                    new Indexsafe.Api.Models.Notification
                    {
                        RecipientNik = userNik,
                        Title = "Target Minggu Ini Tercapai!",
                        Message = "Luar biasa! Anda telah mengunggah laporan SAP untuk minggu ini. Terima kasih atas komitmen Anda dalam menjaga keselamatan kerja.",
                        Url = "/Performance/Index",
                        NotifType = "inspection_new",
                        IsRead = false,
                        IsActioned = true,
                        CreatedAt = DateTime.Now.AddHours(-3)
                    },
                    new Indexsafe.Api.Models.Notification
                    {
                        RecipientNik = userNik,
                        Title = "Pembaruan Liga Departemen",
                        Message = "Departemen SYSTEM INTEGRATIONS berada di Peringkat #19 dari 24 Departemen (MTD: 0.0%).",
                        Url = "/Performance/Index",
                        NotifType = "general",
                        IsRead = true,
                        IsActioned = true,
                        CreatedAt = DateTime.Now.AddHours(-6)
                    }
                };

                _context.Notifications.AddRange(seedNotifs);
                await _context.SaveChangesAsync();

                notifs = seedNotifs.OrderByDescending(n => n.CreatedAt).ToList();
            }

            var result = notifs.Select(n =>
            {
                bool actionRequired = CheckIsActionRequired(n.NotifType, n.Title, n.Message);
                return new
                {
                    id = n.Id,
                    title = n.Title,
                    message = n.Message,
                    url = n.Url,
                    is_read = n.IsRead,
                    is_actioned = n.IsActioned,
                    is_action_required = actionRequired,
                    notif_type = n.NotifType ?? "general",
                    created_at = n.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                };
            }).ToList();

            int unreadCount = notifs.Count(n => !n.IsRead);
            int unactionedCount = result.Count(n => n.is_action_required && !n.is_actioned);

            // Periksa juga temuan aktif di database yang diarahkan ke user yang login
            int activeHazardFindings = await _context.HazardReports
                .CountAsync(h => !h.IsDeleted && h.NikPja == userNik && h.StatusTemuan == "Open");
            int activeActionPlans = await _context.ActionPlans
                .CountAsync(a => !a.IsDeleted && (a.NikPic == userNik || a.NikPja == userNik) && a.Status == "Open");

            int totalActionPending = Math.Max(unactionedCount, activeHazardFindings + activeActionPlans);

            return Ok(new
            {
                status = true,
                unread_count = unreadCount,
                unactioned_count = totalActionPending,
                total_pending_count = unreadCount + totalActionPending,
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
