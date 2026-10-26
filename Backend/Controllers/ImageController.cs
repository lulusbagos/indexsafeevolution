using System;
using System.IO;
using System.Text.RegularExpressions;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    public class ImageController : ControllerBase
    {
        private readonly ImageUploadService _uploadService;

        private static readonly string[] BaseSearchDirs = new[]
        {
            @"C:\MinePermitFiles\MBS",
            @"C:\MinePermitFiles\MBS\avatars",
            @"C:\MinePermitFiles\MBS\profiles",
            @"C:\MinePermitFiles\ONEDBEV",
            @"C:\MinePermitFiles\ONEDBEV\uploads",
            @"D:\Publish\One_db\wwwroot\karyawan",
            @"D:\Publish\one db mitra\wwwroot\uploads\karyawan",
            @"D:\4. PROJECT\6. Android\API\shiftcornerAPI\uploads",
            @"D:\4. PROJECT\6. Android\API\gtime\gtime\gtime\uploads",
            @"D:\4. PROJECT\18. Backup\one_db\wwwroot\karyawan"
        };

        public ImageController(ImageUploadService uploadService)
        {
            _uploadService = uploadService;
        }

        [HttpGet("image/{**path}")]
        [HttpGet("api/image/{**path}")]
        [AllowAnonymous]
        public IActionResult GetImage(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) return NotFound();

            var cleanPath = Uri.UnescapeDataString(path).TrimStart('/', '\\');
            if (cleanPath.StartsWith("uploads/", StringComparison.OrdinalIgnoreCase))
            {
                cleanPath = cleanPath.Substring(8);
            }

            var dirs = new List<string> { _uploadService.BasePath };
            dirs.AddRange(BaseSearchDirs);
            dirs.Add(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads"));
            dirs.Add(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"));

            // 1. Direct path check
            foreach (var dir in dirs)
            {
                if (!Directory.Exists(dir)) continue;
                var direct = Path.Combine(dir, cleanPath);
                if (System.IO.File.Exists(direct)) return ServeFile(direct);
            }

            // 2. Exact filename in candidate dirs
            var fileName = Path.GetFileName(cleanPath);
            var nameWithoutExt = Path.GetFileNameWithoutExtension(cleanPath);
            foreach (var dir in dirs)
            {
                if (!Directory.Exists(dir)) continue;
                try
                {
                    var directFile = Path.Combine(dir, fileName);
                    if (System.IO.File.Exists(directFile)) return ServeFile(directFile);

                    // Case-insensitive / extension check
                    var matches = Directory.GetFiles(dir, $"{nameWithoutExt}.*", SearchOption.TopDirectoryOnly);
                    if (matches.Length > 0) return ServeFile(matches[0]);

                    // Partial match (e.g. filename has suffix or prefix)
                    if (nameWithoutExt.Length >= 4)
                    {
                        var partialMatches = Directory.GetFiles(dir, $"*{nameWithoutExt}*", SearchOption.TopDirectoryOnly);
                        if (partialMatches.Length > 0) return ServeFile(partialMatches[0]);
                    }

                    // Check subfolders (e.g. avatars/2026-10/)
                    foreach (var sub in Directory.GetDirectories(dir))
                    {
                        var subMatches = Directory.GetFiles(sub, $"{nameWithoutExt}.*", SearchOption.TopDirectoryOnly);
                        if (subMatches.Length > 0) return ServeFile(subMatches[0]);

                        if (nameWithoutExt.Length >= 4)
                        {
                            var subPartial = Directory.GetFiles(sub, $"*{nameWithoutExt}*", SearchOption.TopDirectoryOnly);
                            if (subPartial.Length > 0) return ServeFile(subPartial[0]);
                        }
                    }
                }
                catch { }
            }

            // 3. Search by NIK if present in cleanPath
            var mNik = Regex.Match(cleanPath, @"\d{6,15}");
            if (mNik.Success)
            {
                var nik = mNik.Value;
                foreach (var dir in dirs)
                {
                    if (!Directory.Exists(dir)) continue;
                    try
                    {
                        var nikMatches = Directory.GetFiles(dir, $"*{nik}*", SearchOption.TopDirectoryOnly);
                        if (nikMatches.Length > 0) return ServeFile(nikMatches[0]);

                        foreach (var sub in Directory.GetDirectories(dir))
                        {
                            var subNikMatches = Directory.GetFiles(sub, $"*{nik}*", SearchOption.TopDirectoryOnly);
                            if (subNikMatches.Length > 0) return ServeFile(subNikMatches[0]);
                        }
                    }
                    catch { }
                }
            }

            return NotFound(new { message = "Image file not found on server." });
        }

        private IActionResult ServeFile(string filePath)
        {
            var ext = Path.GetExtension(filePath).ToLower();
            var contentType = ext switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".webp" => "image/webp",
                ".gif" => "image/gif",
                _ => "application/octet-stream"
            };
            return PhysicalFile(filePath, contentType);
        }
    }
}
