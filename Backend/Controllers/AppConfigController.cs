using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    public class AppConfigController : ControllerBase
    {
        private readonly IConfiguration _configuration;
        private static string? _overrideDisplayUrl = null;

        public AppConfigController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        private string GetDisplayUrl()
        {
            return _overrideDisplayUrl 
                ?? _configuration["WebEmbedSettings:DisplayUrl"] 
                ?? "https://mbssap.indexim.id/displaymobile";
        }

        private string GetSapReportUrl()
        {
            return _overrideDisplayUrl 
                ?? _configuration["WebEmbedSettings:SapReportUrl"] 
                ?? GetDisplayUrl();
        }

        private string GetGlobalReportUrl()
        {
            return _overrideDisplayUrl 
                ?? _configuration["WebEmbedSettings:GlobalReportUrl"] 
                ?? GetDisplayUrl();
        }

        /// <summary>
        /// GET /api/config/embed-web
        /// Returns dynamic web embed configuration for mobile and web clients.
        /// </summary>
        [AllowAnonymous]
        [HttpGet("api/config/embed-web")]
        [HttpGet("api/settings/embed-web")]
        public IActionResult GetEmbedWebConfig()
        {
            var displayUrl = GetDisplayUrl();
            var sapReportUrl = GetSapReportUrl();
            var globalReportUrl = GetGlobalReportUrl();
            var title = _configuration["WebEmbedSettings:Title"] ?? "Klasemen Liga & F1 Safety Display Mobile";
            var description = _configuration["WebEmbedSettings:Description"] ?? "Embed Web Safety Display Mobile MBS SAP";

            return Ok(new
            {
                status = true,
                display_url = displayUrl,
                sap_report_url = sapReportUrl,
                global_report_url = globalReportUrl,
                embed_url = displayUrl,
                title = title,
                description = description,
                timestamp = DateTime.UtcNow
            });
        }

        /// <summary>
        /// POST /api/config/embed-web
        /// Allows dynamically updating the embed URL in runtime.
        /// </summary>
        [HttpPost("api/config/embed-web")]
        [Authorize]
        public IActionResult UpdateEmbedWebConfig([FromBody] JsonElement payload)
        {
            if (payload.TryGetProperty("display_url", out var displayProp) && !string.IsNullOrWhiteSpace(displayProp.GetString()))
            {
                _overrideDisplayUrl = displayProp.GetString();
            }
            else if (payload.TryGetProperty("embed_url", out var embedProp) && !string.IsNullOrWhiteSpace(embedProp.GetString()))
            {
                _overrideDisplayUrl = embedProp.GetString();
            }

            return Ok(new
            {
                status = true,
                message = "Embed Web URL berhasil diperbarui",
                display_url = GetDisplayUrl()
            });
        }

        /// <summary>
        /// Seamless redirect routes for legacy endpoints (/dashboard/..., /reports/..., /display)
        /// Directly redirects WebViews or browsers to the configured embed URL.
        /// </summary>
        [AllowAnonymous]
        [HttpGet("dashboard/{id?}/{userId?}")]
        [HttpGet("reports/{id?}/{userId?}")]
        [HttpGet("display")]
        public IActionResult RedirectToEmbedWeb()
        {
            var url = GetDisplayUrl();
            return Redirect(url);
        }
    }
}
