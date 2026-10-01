using System;
using System.IO;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    public class ImageController : ControllerBase
    {
        private readonly ImageUploadService _uploadService;

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

            var cleanPath = path.TrimStart('/', '\\');
            if (cleanPath.StartsWith("uploads/", StringComparison.OrdinalIgnoreCase))
            {
                cleanPath = cleanPath.Substring(8);
            }

            // Candidate search locations
            var searchPaths = new[]
            {
                Path.Combine(_uploadService.BasePath, cleanPath),
                Path.Combine(@"C:\MinePermitFiles\MBS", cleanPath),
                Path.Combine(@"C:\MinePermitFiles\ONEDBEV", cleanPath),
                Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", cleanPath),
                Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", cleanPath)
            };

            foreach (var sp in searchPaths)
            {
                if (System.IO.File.Exists(sp))
                {
                    var ext = Path.GetExtension(sp).ToLower();
                    var contentType = ext switch
                    {
                        ".jpg" or ".jpeg" => "image/jpeg",
                        ".png" => "image/png",
                        ".webp" => "image/webp",
                        ".gif" => "image/gif",
                        _ => "application/octet-stream"
                    };
                    return PhysicalFile(sp, contentType);
                }
            }

            return NotFound(new { message = "Image file not found on server." });
        }
    }
}
