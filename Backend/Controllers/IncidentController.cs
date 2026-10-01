using System;
using System.Linq;
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
    [Authorize]
    public class IncidentController : ControllerBase
    {
        private readonly AppDbContext _context;

        public IncidentController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("incidents")]
        public async Task<IActionResult> GetIncidents([FromQuery] int limit = 20, [FromQuery] string? category = null)
        {
            var query = _context.IncidentNewsList
                .Where(i => i.IsPublished);

            if (!string.IsNullOrWhiteSpace(category) && !string.Equals(category, "Semua", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(i => i.Kategori != null && i.Kategori.ToLower() == category.ToLower());
            }

            var incidents = await query
                .OrderByDescending(i => i.TanggalKejadian ?? i.CreatedAt)
                .Take(limit)
                .ToListAsync();

            // Auto-seed if empty
            if (incidents.Count == 0 && string.IsNullOrWhiteSpace(category))
            {
                var seedData = new[]
                {
                    new IncidentNews
                    {
                        Judul = "Material Loose Ditemukan di Hauling Road KM 4",
                        Konten = "Pada pemeriksaan awal shift pagi, tim operasi menemukan material loose di sisi kiri hauling road KM 4. Tim operasi segera memasang rambu peringatan sementara dan melakukan pembersihan jalur agar tidak membahayakan armada unit yang melintas.",
                        GambarUrl = "/uploads/incidents/incident_hauling_km4.jpg",
                        Lokasi = "Hauling Road KM 4",
                        Kategori = "Near Miss",
                        TanggalKejadian = DateTime.Today.AddDays(-1),
                        DibuatOleh = "Safety Patrol Team",
                        NikPembuat = "HSE001",
                        IsPublished = true,
                        CreatedAt = DateTime.Now.AddDays(-1)
                    },
                    new IncidentNews
                    {
                        Judul = "Kontak Ringan Unit LV dengan Pembatas Area Workshop",
                        Konten = "Satu unit Light Vehicle mengalami kontak minor dengan pembatas area workshop saat melakukan manuver mundur akibat blind spot. Tidak ada korban cedera. Refreshment defensive driving dijadwalkan pekan ini.",
                        GambarUrl = "/uploads/incidents/incident_workshop_lv.jpg",
                        Lokasi = "Workshop Light Vehicle",
                        Kategori = "Property Damage",
                        TanggalKejadian = DateTime.Today.AddDays(-3),
                        DibuatOleh = "Plant Safety Team",
                        NikPembuat = "HSE002",
                        IsPublished = true,
                        CreatedAt = DateTime.Now.AddDays(-3)
                    },
                    new IncidentNews
                    {
                        Judul = "Peningkatan Paparan Debu pada Area Crusher Shift Siang",
                        Konten = "Pengendalian debu segera dilakukan melalui penambahan frekuensi water spray dan penyesuaian respirator saat aktivitas dumping meningkat di area crusher.",
                        GambarUrl = "/uploads/incidents/incident_crusher_dust.jpg",
                        Lokasi = "Area Crusher Port",
                        Kategori = "First Aid Injury",
                        TanggalKejadian = DateTime.Today.AddDays(-5),
                        DibuatOleh = "HSE Inspector",
                        NikPembuat = "HSE003",
                        IsPublished = true,
                        CreatedAt = DateTime.Now.AddDays(-5)
                    }
                };

                _context.IncidentNewsList.AddRange(seedData);
                await _context.SaveChangesAsync();

                incidents = seedData.ToList();
            }

            var result = incidents.Select(i => new
            {
                id = i.Id,
                judul = i.Judul,
                konten = i.Konten,
                gambar_url = i.GambarUrl,
                lokasi = i.Lokasi ?? "Umum",
                tanggal_kejadian = (i.TanggalKejadian ?? i.CreatedAt).ToString("yyyy-MM-dd HH:mm:ss"),
                kategori = i.Kategori ?? "Safety Alert",
                dibuat_oleh = i.DibuatOleh,
                created_at = i.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
            }).ToList();

            return Ok(new { status = true, data = result });
        }

        [HttpGet("incidents/latest")]
        public async Task<IActionResult> GetLatestIncident()
        {
            var latest = await _context.IncidentNewsList
                .Where(i => i.IsPublished)
                .OrderByDescending(i => i.TanggalKejadian ?? i.CreatedAt)
                .FirstOrDefaultAsync();

            if (latest == null)
            {
                var seed = new IncidentNews
                {
                    Judul = "Material Loose Ditemukan di Hauling Road KM 4",
                    Konten = "Pada pemeriksaan awal shift pagi, tim operasi menemukan material loose di sisi kiri hauling road KM 4. Tim operasi segera memasang rambu peringatan sementara dan pembersihan jalur.",
                    GambarUrl = "/uploads/incidents/incident_hauling_km4.jpg",
                    Lokasi = "Hauling Road KM 4",
                    Kategori = "Near Miss",
                    TanggalKejadian = DateTime.Today.AddDays(-1),
                    DibuatOleh = "Safety Patrol Team",
                    NikPembuat = "HSE001",
                    IsPublished = true,
                    CreatedAt = DateTime.Now.AddDays(-1)
                };
                _context.IncidentNewsList.Add(seed);
                await _context.SaveChangesAsync();
                latest = seed;
            }

            return Ok(new
            {
                status = true,
                data = new
                {
                    id = latest.Id,
                    judul = latest.Judul,
                    konten = latest.Konten,
                    gambar_url = latest.GambarUrl,
                    lokasi = latest.Lokasi ?? "Umum",
                    tanggal_kejadian = (latest.TanggalKejadian ?? latest.CreatedAt).ToString("yyyy-MM-dd HH:mm:ss"),
                    kategori = latest.Kategori ?? "Safety Alert",
                    dibuat_oleh = latest.DibuatOleh,
                    created_at = latest.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }
    }
}
