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
            @"C:\MinePermitFiles\ONEDBEV\uploads"
        };

        public ImageController(ImageUploadService uploadService)
        {
            _uploadService = uploadService;
        }

        private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
        {
            ".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"
        };

        [HttpGet("image/{**path}")]
        [HttpGet("api/image/{**path}")]
        [AllowAnonymous]
        public IActionResult GetImage(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) return NotFound();

            var cleanPath = Uri.UnescapeDataString(path).TrimStart('/', '\\');

            // Security: Prevent path traversal attacks (CWE-22)
            if (cleanPath.Contains("..") || cleanPath.Contains(':') || cleanPath.IndexOfAny(Path.GetInvalidPathChars()) >= 0)
            {
                return NotFound(new { message = "Invalid image path." });
            }

            if (cleanPath.StartsWith("uploads/", StringComparison.OrdinalIgnoreCase))
            {
                cleanPath = cleanPath.Substring(8);
            }

            // Security: If a file extension is specified in the path, it must be an allowed image extension
            var ext = Path.GetExtension(cleanPath);
            if (!string.IsNullOrEmpty(ext) && !AllowedExtensions.Contains(ext))
            {
                return NotFound(new { message = "File format not supported." });
            }

            var dirs = new List<string> { _uploadService.BasePath };
            dirs.AddRange(BaseSearchDirs);
            dirs.Add(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads"));
            dirs.Add(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"));

            // 1. Direct path check with canonical path verification
            foreach (var dir in dirs)
            {
                if (!Directory.Exists(dir)) continue;
                try
                {
                    var direct = Path.Combine(dir, cleanPath);
                    var fullDirect = Path.GetFullPath(direct);
                    var fullDir = Path.GetFullPath(dir);

                    // Ensure file stays strictly within the intended directory
                    if (fullDirect.StartsWith(fullDir, StringComparison.OrdinalIgnoreCase) && System.IO.File.Exists(fullDirect))
                    {
                        return ServeFile(fullDirect);
                    }
                }
                catch
                {
                    // Ignore path errors
                }
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
            if (!AllowedExtensions.Contains(ext))
            {
                return NotFound(new { message = "Unsupported file type." });
            }

            var contentType = ext switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".webp" => "image/webp",
                ".gif" => "image/gif",
                ".bmp" => "image/bmp",
                _ => "image/jpeg"
            };
            return PhysicalFile(filePath, contentType);
        }
    }
}
