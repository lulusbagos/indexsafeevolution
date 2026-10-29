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
    [Route("api")]
    [AllowAnonymous]
    public class WebCampaignController : ControllerBase
    {
        private readonly AppDbContext _context;
        private static bool _schemaEnsured = false;

        public WebCampaignController(AppDbContext context)
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
            if (string.IsNullOrEmpty(nik) && Request.Query.ContainsKey("nik"))
            {
                nik = Request.Query["nik"].ToString();
            }
            return nik?.Trim() ?? "0000";
        }

        private async Task EnsureSchemaAsync()
        {
            if (_schemaEnsured) return;
            try
            {
                await _context.Database.ExecuteSqlRawAsync(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tbl_m_web_campaign')
                    BEGIN
                        CREATE TABLE [tbl_m_web_campaign] (
                            [id] INT IDENTITY(1,1) PRIMARY KEY,
                            [title] NVARCHAR(200) NOT NULL,
                            [url] NVARCHAR(1000) NOT NULL,
                            [is_active] BIT NOT NULL CONSTRAINT DF_tbl_m_web_campaign_is_active DEFAULT (0),
                            [target_type] NVARCHAR(50) NOT NULL CONSTRAINT DF_tbl_m_web_campaign_target_type DEFAULT ('ALL'),
                            [target_niks] NVARCHAR(MAX) NULL,
                            [frequency] NVARCHAR(50) NOT NULL CONSTRAINT DF_tbl_m_web_campaign_frequency DEFAULT ('once_per_day'),
                            [is_dismissible] BIT NOT NULL CONSTRAINT DF_tbl_m_web_campaign_is_dismissible DEFAULT (1),
                            [created_at] DATETIME NOT NULL CONSTRAINT DF_tbl_m_web_campaign_created_at DEFAULT (GETDATE()),
                            [updated_at] DATETIME NULL CONSTRAINT DF_tbl_m_web_campaign_updated_at DEFAULT (GETDATE())
                        );
                    END
                ");
                _schemaEnsured = true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[WebCampaign] EnsureSchemaAsync note: {ex.Message}");
                _schemaEnsured = true;
            }
        }

        /// <summary>
        /// Endpoint yang dicek oleh Mobile App saat membuka Home:
        /// Memeriksa apakah ada pop-up web yang sedang aktif dan apakah NIK pengguna termasuk dalam target.
        /// </summary>
        [HttpGet("web-campaign/active")]
        public async Task<IActionResult> GetActiveCampaign()
        {
            await EnsureSchemaAsync();
            var userNik = GetCurrentNik();

            var campaign = await _context.WebCampaigns
                .Where(w => w.IsActive)
                .OrderByDescending(w => w.Id)
                .FirstOrDefaultAsync();

            if (campaign == null || string.IsNullOrWhiteSpace(campaign.Url))
            {
                return Ok(new
                {
                    active = false,
                    message = "Tidak ada kampanye web aktif saat ini."
                });
            }

            // Pengecekan Target Penerima (Targeting by NIK)
            if (string.Equals(campaign.TargetType, "SPECIFIC_USERS", StringComparison.OrdinalIgnoreCase))
            {
                if (string.IsNullOrEmpty(userNik) || userNik == "0000")
                {
                    return Ok(new
                    {
                        active = false,
                        message = "NIK pengguna tidak terdeteksi untuk target spesifik."
                    });
                }

                var allowedNiks = (campaign.TargetNiks ?? "")
                    .Split(new[] { ',', ';', '\r', '\n', ' ' }, StringSplitOptions.RemoveEmptyEntries)
                    .Select(n => n.Trim())
                    .ToHashSet(StringComparer.OrdinalIgnoreCase);

                if (!allowedNiks.Contains(userNik))
                {
                    return Ok(new
                    {
                        active = false,
                        message = $"NIK {userNik} tidak termasuk dalam daftar target kampanye ini."
                    });
                }
            }

            return Ok(new
            {
                active = true,
                id = campaign.Id,
                title = campaign.Title,
                url = campaign.Url,
                frequency = campaign.Frequency,
                is_dismissible = campaign.IsDismissible,
                target_type = campaign.TargetType
            });
        }

        /// <summary>
        /// Mengambil konfigurasi web campaign saat ini untuk ditinjau / diubah
        /// </summary>
        [HttpGet("web-campaign/config")]
        public async Task<IActionResult> GetConfig()
        {
            await EnsureSchemaAsync();
            var campaign = await _context.WebCampaigns
                .OrderByDescending(w => w.Id)
                .FirstOrDefaultAsync();

            if (campaign == null)
            {
                return Ok(new
                {
                    status = true,
                    data = new
                    {
                        isActive = false,
                        title = "Kuis & Game K3 Interaktif",
                        url = "",
                        targetType = "ALL",
                        targetNiks = new List<string>(),
                        frequency = "once_per_day",
                        isDismissible = true
                    }
                });
            }

            var nikList = (campaign.TargetNiks ?? "")
                .Split(new[] { ',', ';', '\r', '\n', ' ' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(n => n.Trim())
                .ToList();

            return Ok(new
            {
                status = true,
                data = new
                {
                    id = campaign.Id,
                    isActive = campaign.IsActive,
                    title = campaign.Title,
                    url = campaign.Url,
                    targetType = campaign.TargetType,
                    targetNiks = nikList,
                    frequency = campaign.Frequency,
                    isDismissible = campaign.IsDismissible,
                    updatedAt = campaign.UpdatedAt ?? campaign.CreatedAt
                }
            });
        }

        /// <summary>
        /// Mengaktifkan, mematikan, atau memperbarui URL dan target pengguna
        /// </summary>
        [HttpPost("web-campaign/config")]
        public async Task<IActionResult> SaveConfig([FromBody] WebCampaignConfigDto dto)
        {
            await EnsureSchemaAsync();

            var campaign = await _context.WebCampaigns
                .OrderByDescending(w => w.Id)
                .FirstOrDefaultAsync();

            if (campaign == null)
            {
                campaign = new WebCampaign
                {
                    CreatedAt = DateTime.Now
                };
                await _context.WebCampaigns.AddAsync(campaign);
            }

            campaign.Title = string.IsNullOrWhiteSpace(dto.Title) ? "Kuis & Game K3" : dto.Title.Trim();
            campaign.Url = (dto.Url ?? "").Trim();
            campaign.IsActive = dto.IsActive;
            campaign.TargetType = string.Equals(dto.TargetType, "SPECIFIC_USERS", StringComparison.OrdinalIgnoreCase)
                ? "SPECIFIC_USERS"
                : "ALL";

            // Gabungkan NIK jika dikirim sebagai array atau string
            if (dto.TargetNiks != null && dto.TargetNiks.Count > 0)
            {
                campaign.TargetNiks = string.Join(",", dto.TargetNiks.Select(n => n.Trim()).Where(n => !string.IsNullOrEmpty(n)));
            }
            else if (!string.IsNullOrWhiteSpace(dto.TargetNiksRaw))
            {
                campaign.TargetNiks = dto.TargetNiksRaw.Trim();
            }
            else if (campaign.TargetType == "SPECIFIC_USERS")
            {
                // jika target spesifik tapi kosong, biarkan string kosong
                campaign.TargetNiks = "";
            }

            campaign.Frequency = string.IsNullOrWhiteSpace(dto.Frequency) ? "once_per_day" : dto.Frequency.Trim();
            campaign.IsDismissible = dto.IsDismissible;
            campaign.UpdatedAt = DateTime.Now;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = campaign.IsActive
                    ? $"Pop-up Web Interaktif AKTIF ({campaign.TargetType}) mengarah ke: {campaign.Url}"
                    : "Pop-up Web Interaktif telah DIMATIKAN (Nonaktif).",
                data = new
                {
                    id = campaign.Id,
                    isActive = campaign.IsActive,
                    title = campaign.Title,
                    url = campaign.Url,
                    targetType = campaign.TargetType,
                    targetNiks = campaign.TargetNiks,
                    frequency = campaign.Frequency,
                    isDismissible = campaign.IsDismissible
                }
            });
        }

        /// <summary>
        /// Shortcut cepat untuk Toggle On / Off
        /// </summary>
        [HttpPost("web-campaign/toggle")]
        public async Task<IActionResult> ToggleActive([FromQuery] bool? active)
        {
            await EnsureSchemaAsync();
            var campaign = await _context.WebCampaigns
                .OrderByDescending(w => w.Id)
                .FirstOrDefaultAsync();

            if (campaign == null)
            {
                return BadRequest(new { status = false, message = "Belum ada kampanye yang dikonfigurasi. Buat konfigurasi terlebih dahulu melalui POST /api/web-campaign/config." });
            }

            campaign.IsActive = active ?? !campaign.IsActive;
            campaign.UpdatedAt = DateTime.Now;
            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                isActive = campaign.IsActive,
                message = campaign.IsActive
                    ? "Pop-up Web Interaktif berhasil DIAKTIFKAN."
                    : "Pop-up Web Interaktif berhasil DINONAKTIFKAN."
            });
        }
    }

    public class WebCampaignConfigDto
    {
        public bool IsActive { get; set; } = true;
        public string Title { get; set; } = "Kuis & Game K3";
        public string Url { get; set; } = string.Empty;
        /// <summary>"ALL" atau "SPECIFIC_USERS"</summary>
        public string TargetType { get; set; } = "ALL";
        public List<string>? TargetNiks { get; set; }
        public string? TargetNiksRaw { get; set; }
        /// <summary>"once_per_day", "every_open", "once_forever"</summary>
        public string Frequency { get; set; } = "once_per_day";
        public bool IsDismissible { get; set; } = true;
    }
}
