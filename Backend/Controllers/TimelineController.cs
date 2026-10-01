using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api")]
    [Authorize]
    public class TimelineController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly CompanyHierarchyService _companyHierarchyService;

        public TimelineController(AppDbContext context, CompanyHierarchyService companyHierarchyService)
        {
            _context = context;
            _companyHierarchyService = companyHierarchyService;
        }

        private string GetCurrentNik() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0000";
        private string GetCurrentName() => User.Identity?.Name ?? User.FindFirst(ClaimTypes.Name)?.Value ?? "Pengguna Mobile";
        private int GetCurrentCompanyId() => int.TryParse(User.FindFirst("CompanyId")?.Value, out var cid) ? cid : 1;

        [HttpGet("timeline")]
        public async Task<IActionResult> GetTimeline([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
        {
            var cid = GetCurrentCompanyId();
            var allowedCompanyIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(cid);

            // Fetch recent hazards and inspections for the feed
            var hazards = await _context.HazardReports
                .AsNoTracking()
                .Where(h => !h.IsDeleted && (h.PerusahaanId == null || allowedCompanyIds.Contains(h.PerusahaanId.Value)))
                .OrderByDescending(h => h.CreatedAt)
                .Take(pageSize)
                .Select(h => new
                {
                    id = h.Id,
                    type = "Hazard",
                    title = $"Temuan Hazard: {h.KategoriBahaya}",
                    content = h.Temuan,
                    author_name = h.Nama,
                    author_nik = h.Nik,
                    department = h.Departemen,
                    area = h.Area,
                    location = h.Lokasi,
                    image_url = h.FotoTemuan,
                    status = h.StatusTemuan,
                    created_at = h.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                })
                .ToListAsync();

            var inspections = await _context.Inspections
                .AsNoTracking()
                .Where(i => !i.IsDeleted && (i.PerusahaanId == null || allowedCompanyIds.Contains(i.PerusahaanId.Value)))
                .OrderByDescending(i => i.CreatedAt)
                .Take(pageSize)
                .Select(i => new
                {
                    id = i.Id,
                    type = "Inspection",
                    title = $"Inspeksi K3: {i.JenisInspeksi}",
                    content = i.Catatan ?? "Inspeksi K3 area kerja selesai dilaksanakan.",
                    author_name = i.Nama,
                    author_nik = i.Nik,
                    department = i.Departemen,
                    area = i.Area,
                    location = i.Lokasi,
                    image_url = i.LampiranJson,
                    status = "Completed",
                    created_at = i.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                })
                .ToListAsync();

            var feed = hazards.Concat(inspections)
                .OrderByDescending(x => x.created_at)
                .Take(pageSize)
                .ToList();

            return Ok(new { status = true, data = feed });
        }

        [HttpPost("timeline/{id}/like")]
        public async Task<IActionResult> ToggleLike(int id, [FromQuery] string type = "Hazard")
        {
            var userNik = GetCurrentNik();
            var existingLike = await _context.TimelineLikes
                .FirstOrDefaultAsync(l => l.ItemId == id && l.ItemType == type && l.Nik == userNik);

            if (existingLike != null)
            {
                _context.TimelineLikes.Remove(existingLike);
                await _context.SaveChangesAsync();
                return Ok(new { status = true, liked = false });
            }

            _context.TimelineLikes.Add(new TimelineLike
            {
                ItemId = id,
                ItemType = type,
                Nik = userNik,
                CreatedAt = DateTime.Now
            });
            await _context.SaveChangesAsync();
            return Ok(new { status = true, liked = true });
        }
    }
}
