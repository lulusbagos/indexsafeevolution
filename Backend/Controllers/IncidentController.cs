using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api")]
    [Route("")]
    [AllowAnonymous]
    public class IncidentController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IWebHostEnvironment _env;
        private readonly ILogger<IncidentController> _logger;
        private static bool _schemaEnsured = false;
        private static readonly object _schemaLock = new();

        public IncidentController(AppDbContext context, IWebHostEnvironment env, ILogger<IncidentController> logger)
        {
            _context = context;
            _env = env;
            _logger = logger;
            EnsureSchema();
        }

        private void EnsureSchema()
        {
            if (_schemaEnsured) return;
            lock (_schemaLock)
            {
                if (_schemaEnsured) return;
                try
                {
                    const string sql = @"
                        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('tbl_t_incident_news') AND name = 'is_banner')
                        BEGIN
                            ALTER TABLE tbl_t_incident_news ADD is_banner BIT NOT NULL DEFAULT 0;
                        END
                        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('tbl_t_incident_news') AND name = 'is_update')
                        BEGIN
                            ALTER TABLE tbl_t_incident_news ADD is_update BIT NOT NULL DEFAULT 1;
                        END
                        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('tbl_t_incident_news') AND name = 'banner_urutan')
                        BEGIN
                            ALTER TABLE tbl_t_incident_news ADD banner_urutan INT NOT NULL DEFAULT 0;
                        END
                        IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('tbl_t_incident_news') AND name = 'tags')
                        BEGIN
                            ALTER TABLE tbl_t_incident_news ADD tags NVARCHAR(250) NULL;
                        END";
                    _context.Database.ExecuteSqlRaw(sql);
                    _schemaEnsured = true;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("[IncidentController] Schema check warning: {Msg}", ex.Message);
                }
            }
        }

        // GET /api/incidents & GET /incidents
        [HttpGet("incidents")]
        public async Task<IActionResult> GetIncidents(
            [FromQuery] int limit = 30,
            [FromQuery] string? category = null,
            [FromQuery] string? search = null,
            [FromQuery] bool? is_banner = null,
            [FromQuery] bool? is_update = null)
        {
            var query = _context.IncidentNewsList.Where(i => i.IsPublished);

            if (is_banner.HasValue)
            {
                query = query.Where(i => i.IsBanner == is_banner.Value);
            }

            if (is_update.HasValue)
            {
                query = query.Where(i => i.IsUpdate == is_update.Value);
            }

            if (!string.IsNullOrWhiteSpace(category) && !string.Equals(category, "Semua", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(i => i.Kategori != null && i.Kategori.ToLower() == category.ToLower());
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim().ToLower();
                query = query.Where(i => i.Judul.ToLower().Contains(s) || i.Konten.ToLower().Contains(s) || (i.Lokasi != null && i.Lokasi.ToLower().Contains(s)));
            }

            var incidents = await query
                .OrderByDescending(i => i.TanggalKejadian ?? i.CreatedAt)
                .ThenByDescending(i => i.Id)
                .Take(limit)
                .ToListAsync();

            var result = incidents.Select(MapDto).ToList();
            return Ok(new { status = true, total = result.Count, data = result });
        }

        // GET /api/incidents/banners & GET /incidents/banners
        [HttpGet("incidents/banners")]
        public async Task<IActionResult> GetHomeBanners([FromQuery] int limit = 5)
        {
            // 1. Coba ambil yang explicitly is_banner = true
            var banners = await _context.IncidentNewsList
                .Where(i => i.IsPublished && i.IsBanner)
                .OrderBy(i => i.BannerUrutan)
                .ThenByDescending(i => i.TanggalKejadian ?? i.CreatedAt)
                .Take(limit)
                .ToListAsync();

            // 2. Jika belum ada yang di-flag banner, fallback ke insiden terbaru yang memiliki foto
            if (banners.Count == 0)
            {
                banners = await _context.IncidentNewsList
                    .Where(i => i.IsPublished)
                    .OrderByDescending(i => i.TanggalKejadian ?? i.CreatedAt)
                    .Take(limit)
                    .ToListAsync();
            }

            var result = banners.Select(MapDto).ToList();
            return Ok(new { status = true, total = result.Count, data = result });
        }

        // GET /api/incidents/latest & GET /incidents/latest
        [HttpGet("incidents/latest")]
        public async Task<IActionResult> GetLatestIncident()
        {
            var latest = await _context.IncidentNewsList
                .Where(i => i.IsPublished)
                .OrderByDescending(i => i.TanggalKejadian ?? i.CreatedAt)
                .FirstOrDefaultAsync();

            if (latest == null)
            {
                return NotFound(new { status = false, message = "Belum ada laporan insiden." });
            }

            return Ok(new { status = true, data = MapDto(latest) });
        }

        // GET /api/incidents/{id} & GET /incidents/{id}
        [HttpGet("incidents/{id:int}")]
        public async Task<IActionResult> GetIncidentDetail(int id)
        {
            var incident = await _context.IncidentNewsList.FindAsync(id);
            if (incident == null)
            {
                return NotFound(new { status = false, message = $"Insiden ID {id} tidak ditemukan." });
            }

            return Ok(new { status = true, data = MapDto(incident) });
        }

        // POST /api/incidents & POST /incidents (Endpoint untuk Web UI / Admin / Mobile)
        [HttpPost("incidents")]
        public async Task<IActionResult> CreateIncident(
            [FromForm] IncidentCreateRequest form,
            IFormFile? foto,
            IFormFile? image,
            IFormFile? file)
        {
            if (string.IsNullOrWhiteSpace(form.Judul) || string.IsNullOrWhiteSpace(form.Konten))
            {
                return BadRequest(new { status = false, message = "Judul dan konten insiden wajib diisi." });
            }

            var uploadFile = foto ?? image ?? file;
            string? savedImageUrl = form.GambarUrl;

            if (uploadFile != null && uploadFile.Length > 0)
            {
                savedImageUrl = await SaveIncidentImageAsync(uploadFile);
            }

            DateTime? tglKejadian = null;
            if (!string.IsNullOrWhiteSpace(form.TanggalKejadian))
            {
                if (DateTime.TryParse(form.TanggalKejadian, out var parsed))
                {
                    tglKejadian = parsed;
                }
            }

            var incident = new IncidentNews
            {
                Judul = form.Judul.Trim(),
                Konten = form.Konten.Trim(),
                GambarUrl = savedImageUrl,
                Lokasi = string.IsNullOrWhiteSpace(form.Lokasi) ? "Area Tambang" : form.Lokasi.Trim(),
                TanggalKejadian = tglKejadian ?? DateTime.Now,
                Kategori = string.IsNullOrWhiteSpace(form.Kategori) ? "Near Miss" : form.Kategori.Trim(),
                PerusahaanId = form.PerusahaanId,
                DibuatOleh = string.IsNullOrWhiteSpace(form.DibuatOleh) ? "HSE Team" : form.DibuatOleh.Trim(),
                NikPembuat = string.IsNullOrWhiteSpace(form.NikPembuat) ? "HSE001" : form.NikPembuat.Trim(),
                IsPublished = form.IsPublished ?? true,
                IsBanner = form.IsBanner ?? false,
                IsUpdate = form.IsUpdate ?? true,
                BannerUrutan = form.BannerUrutan ?? 0,
                Tags = form.Tags,
                CreatedAt = DateTime.Now
            };

            _context.IncidentNewsList.Add(incident);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Berita insiden berhasil ditambahkan.",
                data = MapDto(incident)
            });
        }

        // PUT /api/incidents/{id} & PUT /incidents/{id} (Endpoint untuk Web UI Update)
        [HttpPut("incidents/{id:int}")]
        public async Task<IActionResult> UpdateIncident(
            int id,
            [FromForm] IncidentCreateRequest form,
            IFormFile? foto,
            IFormFile? image,
            IFormFile? file)
        {
            var incident = await _context.IncidentNewsList.FindAsync(id);
            if (incident == null)
            {
                return NotFound(new { status = false, message = $"Insiden ID {id} tidak ditemukan." });
            }

            if (!string.IsNullOrWhiteSpace(form.Judul)) incident.Judul = form.Judul.Trim();
            if (!string.IsNullOrWhiteSpace(form.Konten)) incident.Konten = form.Konten.Trim();
            if (!string.IsNullOrWhiteSpace(form.Lokasi)) incident.Lokasi = form.Lokasi.Trim();
            if (!string.IsNullOrWhiteSpace(form.Kategori)) incident.Kategori = form.Kategori.Trim();
            if (!string.IsNullOrWhiteSpace(form.DibuatOleh)) incident.DibuatOleh = form.DibuatOleh.Trim();
            if (form.PerusahaanId.HasValue) incident.PerusahaanId = form.PerusahaanId.Value;
            if (form.IsPublished.HasValue) incident.IsPublished = form.IsPublished.Value;
            if (form.IsBanner.HasValue) incident.IsBanner = form.IsBanner.Value;
            if (form.IsUpdate.HasValue) incident.IsUpdate = form.IsUpdate.Value;
            if (form.BannerUrutan.HasValue) incident.BannerUrutan = form.BannerUrutan.Value;
            if (form.Tags != null) incident.Tags = form.Tags;

            if (!string.IsNullOrWhiteSpace(form.TanggalKejadian) && DateTime.TryParse(form.TanggalKejadian, out var parsed))
            {
                incident.TanggalKejadian = parsed;
            }

            var uploadFile = foto ?? image ?? file;
            if (uploadFile != null && uploadFile.Length > 0)
            {
                incident.GambarUrl = await SaveIncidentImageAsync(uploadFile);
            }
            else if (!string.IsNullOrWhiteSpace(form.GambarUrl))
            {
                incident.GambarUrl = form.GambarUrl;
            }

            incident.UpdatedAt = DateTime.Now;
            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Berita insiden berhasil diperbarui.",
                data = MapDto(incident)
            });
        }

        // DELETE /api/incidents/{id} & DELETE /incidents/{id}
        [HttpDelete("incidents/{id:int}")]
        public async Task<IActionResult> DeleteIncident(int id)
        {
            var incident = await _context.IncidentNewsList.FindAsync(id);
            if (incident == null)
            {
                return NotFound(new { status = false, message = $"Insiden ID {id} tidak ditemukan." });
            }

            _context.IncidentNewsList.Remove(incident);
            await _context.SaveChangesAsync();

            return Ok(new { status = true, message = $"Insiden ID {id} berhasil dihapus." });
        }

        // POST /api/incidents/{id}/toggle-banner
        [HttpPost("incidents/{id:int}/toggle-banner")]
        public async Task<IActionResult> ToggleBanner(int id)
        {
            var incident = await _context.IncidentNewsList.FindAsync(id);
            if (incident == null)
            {
                return NotFound(new { status = false, message = $"Insiden ID {id} tidak ditemukan." });
            }

            incident.IsBanner = !incident.IsBanner;
            incident.UpdatedAt = DateTime.Now;
            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = incident.IsBanner ? "Insiden dijadikan banner di Home." : "Insiden dicabut dari banner Home.",
                is_banner = incident.IsBanner
            });
        }

        private async Task<string> SaveIncidentImageAsync(IFormFile file)
        {
            var monthFolder = DateTime.Now.ToString("yyyy-MM");
            var primaryBasePath = @"C:\MinePermitFiles\MBS";
            string targetFolder;

            if (Directory.Exists(primaryBasePath))
            {
                targetFolder = Path.Combine(primaryBasePath, "incidents", monthFolder);
            }
            else
            {
                var webRoot = _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
                targetFolder = Path.Combine(webRoot, "uploads", "incidents", monthFolder);
            }

            if (!Directory.Exists(targetFolder))
            {
                Directory.CreateDirectory(targetFolder);
            }

            var ext = Path.GetExtension(file.FileName);
            if (string.IsNullOrEmpty(ext)) ext = ".jpg";
            var fileName = $"inc_{DateTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid():N[..8]}{ext}";
            var fullPath = Path.Combine(targetFolder, fileName);

            await using (var stream = new FileStream(fullPath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            return $"/uploads/incidents/{monthFolder}/{fileName}";
        }

        private static object MapDto(IncidentNews i)
        {
            return new
            {
                id = i.Id,
                judul = i.Judul,
                konten = i.Konten,
                gambar_url = i.GambarUrl,
                lokasi = i.Lokasi ?? "Area Operasional",
                tanggal_kejadian = (i.TanggalKejadian ?? i.CreatedAt).ToString("yyyy-MM-dd HH:mm:ss"),
                kategori = i.Kategori ?? "Near Miss",
                dibuat_oleh = i.DibuatOleh,
                nik_pembuat = i.NikPembuat,
                is_published = i.IsPublished,
                is_banner = i.IsBanner,
                is_update = i.IsUpdate,
                banner_urutan = i.BannerUrutan,
                tags = i.Tags,
                created_at = i.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
            };
        }
    }

    public class IncidentCreateRequest
    {
        public string? Judul { get; set; }
        public string? Konten { get; set; }
        public string? GambarUrl { get; set; }
        public string? Lokasi { get; set; }
        public string? TanggalKejadian { get; set; }
        public string? Kategori { get; set; }
        public int? PerusahaanId { get; set; }
        public string? DibuatOleh { get; set; }
        public string? NikPembuat { get; set; }
        public bool? IsPublished { get; set; }
        public bool? IsBanner { get; set; }
        public bool? IsUpdate { get; set; }
        public int? BannerUrutan { get; set; }
        public string? Tags { get; set; }
    }
}
