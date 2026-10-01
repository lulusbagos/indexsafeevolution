using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Processing;

namespace Indexsafe.Api.Services
{
    public class ImageUploadService
    {
        private readonly string _basePath;
        private readonly SyncMonitorService _monitor;

        public ImageUploadService(IWebHostEnvironment env, IConfiguration config, SyncMonitorService monitor)
        {
            _monitor = monitor;
            var configuredPath = config["UploadSettings:StoragePath"];
            if (!string.IsNullOrEmpty(configuredPath) && Directory.Exists(Path.GetPathRoot(configuredPath)))
            {
                _basePath = configuredPath;
            }
            else if (Directory.Exists(@"C:\MinePermitFiles\MBS"))
            {
                _basePath = @"C:\MinePermitFiles\MBS";
            }
            else
            {
                _basePath = Path.Combine(env.ContentRootPath, "wwwroot", "uploads");
            }

            if (!Directory.Exists(_basePath))
            {
                Directory.CreateDirectory(_basePath);
            }
        }

        public string BasePath => _basePath;

        public async Task<string?> UploadAndCompressImageAsync(IFormFile? file, string category, string prefix = "")
        {
            if (file == null || file.Length == 0) return null;

            var sw = Stopwatch.StartNew();
            long originalSizeKb = file.Length / 1024;
            long compressedSizeKb = originalSizeKb;

            var monthFolder = DateTime.Now.ToString("yyyy-MM");
            var uploadsFolder = Path.Combine(_basePath, category, monthFolder);

            if (!Directory.Exists(uploadsFolder))
            {
                Directory.CreateDirectory(uploadsFolder);
            }

            var extension = Path.GetExtension(file.FileName).ToLower();
            bool isImage = extension == ".jpg" || extension == ".jpeg" || extension == ".png" || extension == ".webp" || extension == ".bmp";

            var uniqueFileName = (string.IsNullOrEmpty(prefix) ? "" : prefix + "_") + Guid.NewGuid().ToString()[..8];
            string savedUrl;

            if (isImage)
            {
                uniqueFileName += ".jpg";
                var filePath = Path.Combine(uploadsFolder, uniqueFileName);

                try
                {
                    using (var stream = file.OpenReadStream())
                    {
                        using (var image = await Image.LoadAsync(stream))
                        {
                            if (image.Width > 1280)
                            {
                                var ratio = 1280.0 / image.Width;
                                var newHeight = (int)(image.Height * ratio);
                                image.Mutate(x => x.Resize(1280, newHeight));
                            }

                            var encoder = new JpegEncoder { Quality = 75 };
                            await image.SaveAsync(filePath, encoder);
                        }
                    }

                    var fi = new FileInfo(filePath);
                    compressedSizeKb = fi.Exists ? fi.Length / 1024 : originalSizeKb;
                }
                catch (Exception)
                {
                    uniqueFileName = uniqueFileName.Replace(".jpg", extension);
                    var fallbackPath = Path.Combine(uploadsFolder, uniqueFileName);
                    using (var fileStream = new FileStream(fallbackPath, FileMode.Create))
                    {
                        await file.CopyToAsync(fileStream);
                    }
                    var fi = new FileInfo(fallbackPath);
                    compressedSizeKb = fi.Exists ? fi.Length / 1024 : originalSizeKb;
                }
            }
            else
            {
                uniqueFileName += extension;
                var filePath = Path.Combine(uploadsFolder, uniqueFileName);
                using (var fileStream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(fileStream);
                }
                compressedSizeKb = originalSizeKb;
            }

            savedUrl = $"/uploads/{category}/{monthFolder}/{uniqueFileName}";

            // Mirror file to MBS_SAP web directory & C:\MinePermitFiles\MBS\profiles to keep both systems perfectly synchronized
            try
            {
                var sourceFile = Path.Combine(uploadsFolder, uniqueFileName);
                if (File.Exists(sourceFile))
                {
                    // If profiles category, ensure copies in C:\MinePermitFiles\MBS\profiles directly as well
                    if (string.Equals(category, "profiles", StringComparison.OrdinalIgnoreCase))
                    {
                        var profilesRoot = @"C:\MinePermitFiles\MBS\profiles";
                        if (!Directory.Exists(profilesRoot)) Directory.CreateDirectory(profilesRoot);

                        var directProfilesFile = Path.Combine(profilesRoot, uniqueFileName);
                        File.Copy(sourceFile, directProfilesFile, true);

                        if (!string.IsNullOrEmpty(prefix))
                        {
                            var nikProfilesFile = Path.Combine(profilesRoot, $"{prefix}.jpg");
                            File.Copy(sourceFile, nikProfilesFile, true);
                        }
                    }

                    // Mirror to MBS_SAP Web wwwroot/uploads
                    var mbsRoot = @"D:\4. PROJECT\2. Web\MBS_SAP\wwwroot\uploads";
                    var mbsCategoryFolder = Path.Combine(mbsRoot, category, monthFolder);
                    if (!Directory.Exists(mbsCategoryFolder))
                    {
                        Directory.CreateDirectory(mbsCategoryFolder);
                    }
                    var destFile = Path.Combine(mbsCategoryFolder, uniqueFileName);
                    File.Copy(sourceFile, destFile, true);

                    if (string.Equals(category, "profiles", StringComparison.OrdinalIgnoreCase))
                    {
                        var mbsDirectProfiles = Path.Combine(mbsRoot, "profiles");
                        if (!Directory.Exists(mbsDirectProfiles)) Directory.CreateDirectory(mbsDirectProfiles);

                        File.Copy(sourceFile, Path.Combine(mbsDirectProfiles, uniqueFileName), true);
                        if (!string.IsNullOrEmpty(prefix))
                        {
                            File.Copy(sourceFile, Path.Combine(mbsDirectProfiles, $"{prefix}.jpg"), true);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ImageUploadService] Mirror to MBS_SAP/Profiles error: {ex.Message}");
            }

            sw.Stop();

            _monitor.RecordUpload(new UploadEvent
            {
                FileName = file.FileName,
                Category = category,
                OriginalSizeKb = Math.Max(1, originalSizeKb),
                CompressedSizeKb = Math.Max(1, compressedSizeKb),
                SavedUrl = savedUrl,
                Timestamp = DateTime.Now,
                DurationMs = sw.ElapsedMilliseconds,
                Status = "Compressed & Stored"
            });

            return savedUrl;
        }

        public async Task<string?> SaveBase64ImageAsync(string? base64Data, string category, string prefix = "")
        {
            if (string.IsNullOrWhiteSpace(base64Data)) return null;

            try
            {
                var cleanBase64 = base64Data;
                if (base64Data.Contains(","))
                {
                    cleanBase64 = base64Data[(base64Data.IndexOf(",") + 1)..];
                }

                var bytes = Convert.FromBase64String(cleanBase64);
                if (bytes.Length == 0) return null;

                var monthFolder = DateTime.Now.ToString("yyyy-MM");
                var uploadsFolder = Path.Combine(_basePath, category, monthFolder);

                if (!Directory.Exists(uploadsFolder))
                {
                    Directory.CreateDirectory(uploadsFolder);
                }

                var uniqueFileName = (string.IsNullOrEmpty(prefix) ? "" : prefix + "_") + Guid.NewGuid().ToString()[..8] + ".jpg";
                var filePath = Path.Combine(uploadsFolder, uniqueFileName);

                using (var image = Image.Load(bytes))
                {
                    if (image.Width > 1280)
                    {
                        var ratio = 1280.0 / image.Width;
                        var newHeight = (int)(image.Height * ratio);
                        image.Mutate(x => x.Resize(1280, newHeight));
                    }

                    var encoder = new JpegEncoder { Quality = 75 };
                    await image.SaveAsync(filePath, encoder);
                }

                var savedUrl = $"/uploads/{category}/{monthFolder}/{uniqueFileName}";
                return savedUrl;
            }
            catch
            {
                return null;
            }
        }
    }
}
