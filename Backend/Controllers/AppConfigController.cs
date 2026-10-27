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

        private static string? _overrideLatestVersion = null;
        private static int? _overrideLatestBuild = null;
        private static string? _overrideMinVersion = null;
        private static int? _overrideMinBuild = null;
        private static bool? _overrideForceUpdate = null;
        private static string? _overridePlayStoreUrl = null;

        /// <summary>
        /// GET /api/config/app-version
        /// Checks the minimum and latest mobile app version for mandatory/force update.
        /// </summary>
        [AllowAnonymous]
        [HttpGet("api/config/app-version")]
        [HttpGet("api/app/version")]
        [HttpGet("api/system/app-version")]
        public IActionResult GetAppVersionConfig()
        {
            var latestVersion = _overrideLatestVersion 
                ?? _configuration["AppVersionSettings:LatestVersion"] 
                ?? "1.0.1";
            var latestBuild = _overrideLatestBuild 
                ?? _configuration.GetValue<int?>("AppVersionSettings:LatestBuild") 
                ?? 101;
            var minVersion = _overrideMinVersion 
                ?? _configuration["AppVersionSettings:MinVersion"] 
                ?? "1.0.1";
            var minBuild = _overrideMinBuild 
                ?? _configuration.GetValue<int?>("AppVersionSettings:MinBuild") 
                ?? 101;
            var forceUpdate = _overrideForceUpdate 
                ?? _configuration.GetValue<bool?>("AppVersionSettings:ForceUpdate") 
                ?? true;
            var playStoreUrl = _overridePlayStoreUrl 
                ?? _configuration["AppVersionSettings:PlayStoreUrl"] 
                ?? "https://play.google.com/store/apps/details?id=id.indexim.mbs";
            var title = _configuration["AppVersionSettings:Title"] ?? "Update Aplikasi Diperlukan";
            var message = _configuration["AppVersionSettings:Message"] ?? "Versi aplikasi Anda sudah usang. Harap perbarui ke versi terbaru di Google Play Store untuk dapat melanjutkan penggunaan MBS SAP.";
            var releaseNotes = _configuration["AppVersionSettings:ReleaseNotes"] ?? "Integrasi Firebase Cloud Messaging, pembaruan performa, dan sinkronisasi real-time.";

            return Ok(new
            {
                status = true,
                package_name = "id.indexim.mbs",
                latest_version = latestVersion,
                latest_build = latestBuild,
                min_version = minVersion,
                min_build = minBuild,
                force_update = forceUpdate,
                playstore_url = playStoreUrl,
                title = title,
                message = message,
                release_notes = releaseNotes,
                checked_at = DateTime.UtcNow
            });
        }

        /// <summary>
        /// POST /api/config/app-version
        /// Dynamically update latest/minimum app version requirements.
        /// </summary>
        [HttpPost("api/config/app-version")]
        [Authorize]
        public IActionResult UpdateAppVersionConfig([FromBody] JsonElement payload)
        {
            if (payload.TryGetProperty("latest_version", out var lv)) _overrideLatestVersion = lv.GetString();
            if (payload.TryGetProperty("latest_build", out var lb) && lb.TryGetInt32(out var lbi)) _overrideLatestBuild = lbi;
            if (payload.TryGetProperty("min_version", out var mv)) _overrideMinVersion = mv.GetString();
            if (payload.TryGetProperty("min_build", out var mb) && mb.TryGetInt32(out var mbi)) _overrideMinBuild = mbi;
            if (payload.TryGetProperty("force_update", out var fu)) _overrideForceUpdate = fu.GetBoolean();
            if (payload.TryGetProperty("playstore_url", out var ps)) _overridePlayStoreUrl = ps.GetString();

            return Ok(new
            {
                status = true,
                message = "Pengaturan versi aplikasi berhasil diperbarui",
                latest_version = _overrideLatestVersion ?? _configuration["AppVersionSettings:LatestVersion"] ?? "1.0.1",
                min_version = _overrideMinVersion ?? _configuration["AppVersionSettings:MinVersion"] ?? "1.0.1",
                force_update = _overrideForceUpdate ?? _configuration.GetValue<bool?>("AppVersionSettings:ForceUpdate") ?? true
            });
        }
    }
}
