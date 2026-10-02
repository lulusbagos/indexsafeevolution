using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/ads")]
    [Route("api/iklan")]
    [Route("ads")]
    [Route("iklan")]
    [AllowAnonymous]
    public class PopupAdController : ControllerBase
    {
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<PopupAdController> _logger;

        private static readonly string[] ValidExtensions = { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
        private const string PrimaryFolder = @"C:\MinePermitFiles\MBS\iklan";

        public PopupAdController(IWebHostEnvironment env, ILogger<PopupAdController> logger)
        {
            _env = env;
            _logger = logger;
            EnsureAdDirectory();
        }

        private string GetAdDirectory()
        {
            if (Directory.Exists(@"C:\MinePermitFiles\MBS"))
            {
                if (!Directory.Exists(PrimaryFolder))
                {
                    try { Directory.CreateDirectory(PrimaryFolder); } catch { }
                }
                return PrimaryFolder;
            }

            var localFolder = Path.Combine(_env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot"), "uploads", "iklan");
            if (!Directory.Exists(localFolder))
            {
                try { Directory.CreateDirectory(localFolder); } catch { }
            }
            return localFolder;
        }

        private void EnsureAdDirectory()
        {
            try
            {
                var dir = GetAdDirectory();
                if (!Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("[PopupAd] Failed to ensure ad directory: {Msg}", ex.Message);
            }
        }

        /// <summary>
        /// GET /api/ads/popup or GET /api/iklan
        /// Mengembalikan iklan popup aktif paling baru jika ada file JPG/PNG di folder iklan.
        /// Jika folder kosong atau tidak ada file gambar, has_ad = false.
        /// </summary>
        [HttpGet]
        [HttpGet("popup")]
        public IActionResult GetActivePopupAd()
        {
            var adDir = GetAdDirectory();
            if (!Directory.Exists(adDir))
            {
                return Ok(new
                {
                    status = true,
                    has_ad = false,
                    message = "Folder iklan belum tersedia.",
                    data = (object?)null
                });
            }

            var dirInfo = new DirectoryInfo(adDir);
            var imageFiles = dirInfo.GetFiles()
                .Where(f => ValidExtensions.Contains(f.Extension.ToLowerInvariant()) && f.Length > 0)
                .OrderByDescending(f => f.LastWriteTimeUtc)
                .ToList();

            if (imageFiles.Count == 0)
            {
                return Ok(new
                {
                    status = true,
                    has_ad = false,
                    message = "Folder iklan kosong. Tidak ada popup yang ditampilkan.",
                    data = (object?)null
                });
            }

            var latest = imageFiles.First();
            var relativeUrl = $"/uploads/iklan/{latest.Name}";

            return Ok(new
            {
                status = true,
                has_ad = true,
                message = "Iklan aktif berhasil dimuat.",
                data = new
                {
                    fileName = latest.Name,
                    imageUrl = relativeUrl,
                    fileSizeBytes = latest.Length,
                    updatedAt = latest.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                },
                total_ads = imageFiles.Count
            });
        }

        /// <summary>
        /// GET /api/ads/list
        /// Mengambil seluruh daftar file iklan yang ada di folder
        /// </summary>
        [HttpGet("list")]
        public IActionResult GetAllAds()
        {
            var adDir = GetAdDirectory();
            if (!Directory.Exists(adDir))
            {
                return Ok(new { status = true, total = 0, data = Array.Empty<object>() });
            }

            var dirInfo = new DirectoryInfo(adDir);
            var imageFiles = dirInfo.GetFiles()
                .Where(f => ValidExtensions.Contains(f.Extension.ToLowerInvariant()) && f.Length > 0)
                .OrderByDescending(f => f.LastWriteTimeUtc)
                .Select(f => new
                {
                    fileName = f.Name,
                    imageUrl = $"/uploads/iklan/{f.Name}",
                    fileSizeBytes = f.Length,
                    updatedAt = f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                })
                .ToList();

            return Ok(new
            {
                status = true,
                total = imageFiles.Count,
                data = imageFiles
            });
        }

        /// <summary>
        /// POST /api/ads/upload
        /// Upload gambar iklan baru langsung ke folder iklan
        /// </summary>
        [HttpPost("upload")]
        public async Task<IActionResult> UploadAd(IFormFile? file)
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest(new { status = false, message = "File gambar iklan wajib diunggah." });
            }

            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (!ValidExtensions.Contains(ext))
            {
                return BadRequest(new { status = false, message = "Format file harus JPG, PNG, atau WEBP." });
            }

            var adDir = GetAdDirectory();
            var safeName = $"ad_{DateTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid():N[..6]}{ext}";
            var targetPath = Path.Combine(adDir, safeName);

            await using (var stream = new FileStream(targetPath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            return Ok(new
            {
                status = true,
                message = "Iklan berhasil diunggah ke folder.",
                data = new
                {
                    fileName = safeName,
                    imageUrl = $"/uploads/iklan/{safeName}"
                }
            });
        }
    }
}
