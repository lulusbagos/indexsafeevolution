using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/rci")]
    [Route("rci")]
    [AllowAnonymous]
    public class RciController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ImageUploadService _imageUploadService;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private static bool _schemaEnsured = false;

        public RciController(AppDbContext context, ImageUploadService imageUploadService, CompanyHierarchyService companyHierarchyService)
        {
            _context = context;
            _imageUploadService = imageUploadService;
            _companyHierarchyService = companyHierarchyService;
            EnsureSchemaAsync().GetAwaiter().GetResult();
        }

        private async Task EnsureSchemaAsync()
        {
            if (_schemaEnsured) return;
            try
            {
                var sql = @"
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tbl_t_rci_report')
BEGIN
    CREATE TABLE [tbl_t_rci_report] (
        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [Tanggal] DATETIME2 NOT NULL,
        [Waktu] TIME NOT NULL,
        [Nik] NVARCHAR(50) NOT NULL,
        [Nama] NVARCHAR(150) NOT NULL,
        [Departemen] NVARCHAR(100) NULL,
        [Perusahaan] NVARCHAR(200) NULL,
        [PerusahaanId] INT NULL,
        [Area] NVARCHAR(100) NOT NULL,
        [Lokasi] NVARCHAR(200) NOT NULL,
        [DetilLokasi] NVARCHAR(250) NULL,
        [NamaJalan] NVARCHAR(100) NULL,
        [SegmentJalan] NVARCHAR(100) NULL,
        [Shift] NVARCHAR(20) NULL,
        [Latitude] NVARCHAR(50) NULL,
        [Longitude] NVARCHAR(50) NULL,
        [PanjangSegment] FLOAT NULL DEFAULT 100,
        [DefisitSurfacing] FLOAT NULL DEFAULT 0,
        [DefisitUndulation] FLOAT NULL DEFAULT 0,
        [DefisitSpoil] FLOAT NULL DEFAULT 0,
        [DefisitSafetyBerm] FLOAT NULL DEFAULT 0,
        [DefisitCrossfall] FLOAT NULL DEFAULT 0,
        [DefisitDust] FLOAT NULL DEFAULT 0,
        [DefisitDrainage] FLOAT NULL DEFAULT 0,
        [DefisitRoadAttachment] FLOAT NULL DEFAULT 0,
        [SkorSurfacing] FLOAT NOT NULL DEFAULT 4.0,
        [SkorUndulation] FLOAT NOT NULL DEFAULT 4.0,
        [SkorSpoil] FLOAT NOT NULL DEFAULT 4.0,
        [SkorSafetyBerm] FLOAT NOT NULL DEFAULT 4.0,
        [SkorCrossfall] FLOAT NOT NULL DEFAULT 4.0,
        [SkorDust] FLOAT NOT NULL DEFAULT 4.0,
        [SkorDrainage] FLOAT NOT NULL DEFAULT 4.0,
        [SkorRoadAttachment] FLOAT NOT NULL DEFAULT 4.0,
        [SkorPermukaanGroup] FLOAT NOT NULL DEFAULT 4.0,
        [SkorSafetyBermGroup] FLOAT NOT NULL DEFAULT 4.0,
        [SkorDrainageGroup] FLOAT NOT NULL DEFAULT 4.0,
        [ActualRoadScore] FLOAT NOT NULL DEFAULT 4.0,
        [TargetScore] FLOAT NOT NULL DEFAULT 4.0,
        [Achievement] FLOAT NOT NULL DEFAULT 100.0,
        [SkorLebarJalan] INT NOT NULL DEFAULT 100,
        [SkorGradeJalan] INT NOT NULL DEFAULT 100,
        [SkorPermukaanJalan] INT NOT NULL DEFAULT 100,
        [SkorDrainaseParit] INT NOT NULL DEFAULT 100,
        [SkorSuperelevasiTikungan] INT NOT NULL DEFAULT 100,
        [SkorBebasSpillage] INT NOT NULL DEFAULT 100,
        [SkorRambuDebu] INT NOT NULL DEFAULT 100,
        [TotalScore] FLOAT NOT NULL DEFAULT 100,
        [KategoriIndex] NVARCHAR(50) NOT NULL DEFAULT 'Baik',
        [Catatan] NVARCHAR(2000) NULL,
        [TindakanPerbaikan] NVARCHAR(2000) NULL,
        [Pic] NVARCHAR(100) NULL,
        [FotoUrl] NVARCHAR(500) NULL,
        [status] NVARCHAR(50) NOT NULL DEFAULT 'Pending',
        [approved_at] DATETIME2 NULL,
        [creators_summary] NVARCHAR(500) NULL,
        [approvers_summary] NVARCHAR(500) NULL,
        [is_deleted] BIT NOT NULL DEFAULT 0,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETDATE(),
        [UpdatedAt] DATETIME2 NULL
    );
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tbl_t_rci_member')
BEGIN
    CREATE TABLE [tbl_t_rci_member] (
        [id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [rci_report_id] INT NOT NULL,
        [role] NVARCHAR(30) NOT NULL,
        [nik] NVARCHAR(50) NOT NULL,
        [nama] NVARCHAR(150) NOT NULL,
        [jabatan] NVARCHAR(150) NULL,
        [perusahaan] NVARCHAR(150) NULL,
        [perusahaan_id] INT NULL,
        [status] NVARCHAR(50) NOT NULL DEFAULT 'Pending',
        [catatan] NVARCHAR(500) NULL,
        [action_at] DATETIME2 NULL,
        [created_at] DATETIME2 NOT NULL DEFAULT GETDATE()
    );
END";
                await _context.Database.ExecuteSqlRawAsync(sql);
                _schemaEnsured = true;
            }
            catch
            {
                _schemaEnsured = true;
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetList(
            [FromQuery] string? userNik,
            [FromQuery] string? userNama,
            [FromQuery] int? companyId,
            [FromQuery] string? companyName,
            [FromQuery] string? scope,
            [FromQuery] string? statusFilter,
            [FromQuery] string? search,
            [FromQuery] string? namaJalan,
            [FromQuery] string? kategori,
            [FromQuery] DateTime? startDate,
            [FromQuery] DateTime? endDate,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var query = _context.RciReports
                    .Include(r => r.Members)
                    .AsNoTracking()
                    .Where(r => !r.IsDeleted);

                int? effectiveCompanyId = companyId.HasValue && companyId.Value > 0
                    ? companyId.Value
                    : (int.TryParse(User.FindFirst("CompanyId")?.Value, out var cid) ? cid : null);
                string? effectiveCompanyName = !string.IsNullOrWhiteSpace(companyName)
                    ? companyName.Trim()
                    : User.FindFirst("Company")?.Value;

                // Auto-resolve company from employee master if missing
                if ((!effectiveCompanyId.HasValue || effectiveCompanyId.Value <= 0 || string.IsNullOrWhiteSpace(effectiveCompanyName)) && !string.IsNullOrWhiteSpace(userNik))
                {
                    var cNik = userNik.Trim();
                    var emp = await (from k in _context.Karyawans.AsNoTracking()
                                     join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                                     from c in cg.DefaultIfEmpty()
                                     where k.NoNik == cNik
                                     select new { k.IdPerusahaan, c.NamaPerusahaan }
                                    ).FirstOrDefaultAsync();
                    if (emp != null)
                    {
                        if ((!effectiveCompanyId.HasValue || effectiveCompanyId.Value <= 0) && emp.IdPerusahaan > 0)
                            effectiveCompanyId = emp.IdPerusahaan;
                        if (string.IsNullOrWhiteSpace(effectiveCompanyName) && !string.IsNullOrWhiteSpace(emp.NamaPerusahaan))
                            effectiveCompanyName = emp.NamaPerusahaan;
                    }
                }

                var cleanNik = !string.IsNullOrWhiteSpace(userNik) ? userNik.Trim() : "";
                var cleanNama = !string.IsNullOrWhiteSpace(userNama) ? userNama.Trim().ToLower() : "";

                // Scope / History filter:
                // User requirement: "history adalah history yang saya buat kecuali saya dijadikan pic"
                // Dan untuk "Semua Front / Semua Jalan" (scope == "all"): tampilkan inspeksi perusahaan yang sama dengan login
                if (!string.IsNullOrWhiteSpace(cleanNik) && scope != "all")
                {
                    if (scope == "created")
                    {
                        query = query.Where(r => r.Nik == cleanNik || r.Members.Any(m => m.Role == "Creator" && m.Nik == cleanNik));
                    }
                    else if (scope == "approvals")
                    {
                        query = query.Where(r => r.Members.Any(m => m.Role == "Approver" && m.Nik == cleanNik));
                    }
                    else if (scope == "pic")
                    {
                        query = query.Where(r => r.Pic != null && (r.Pic.Contains(cleanNik) || (cleanNama != "" && r.Pic.ToLower().Contains(cleanNama))));
                    }
                    else
                    {
                        // Default "my_history": dibuat saya, tim sidak creator, penyetuju approver, ATAU ditunjuk sebagai PIC perbaikan
                        query = query.Where(r => r.Nik == cleanNik ||
                                                 r.Members.Any(m => m.Nik == cleanNik) ||
                                                 (r.Pic != null && (r.Pic.Contains(cleanNik) || (cleanNama != "" && r.Pic.ToLower().Contains(cleanNama)))));
                    }
                }
                else if (scope == "all")
                {
                    // Pastikan bagian semua jalan HANYA tampilkan inspeksi perusahaan yang sama persis dengan login
                    if (effectiveCompanyId.HasValue && effectiveCompanyId.Value > 0 && !string.IsNullOrWhiteSpace(effectiveCompanyName))
                    {
                        var cleanComp = effectiveCompanyName.Trim().ToLower();
                        query = query.Where(r =>
                            (r.PerusahaanId.HasValue && r.PerusahaanId.Value == effectiveCompanyId.Value) ||
                            (r.Perusahaan != null && r.Perusahaan.ToLower() == cleanComp)
                        );
                    }
                    else if (effectiveCompanyId.HasValue && effectiveCompanyId.Value > 0)
                    {
                        query = query.Where(r => r.PerusahaanId.HasValue && r.PerusahaanId.Value == effectiveCompanyId.Value);
                    }
                    else if (!string.IsNullOrWhiteSpace(effectiveCompanyName))
                    {
                        var cleanComp = effectiveCompanyName.Trim().ToLower();
                        query = query.Where(r => r.Perusahaan != null && r.Perusahaan.ToLower() == cleanComp);
                    }
                }

                // Status Filter
                if (!string.IsNullOrWhiteSpace(statusFilter))
                {
                    if (statusFilter == "MyApprovals" && !string.IsNullOrWhiteSpace(cleanNik))
                    {
                        query = query.Where(r => r.Members.Any(m => m.Role == "Approver" && m.Nik == cleanNik && m.Status == "Pending"));
                    }
                    else if (statusFilter == "MyJoints" && !string.IsNullOrWhiteSpace(cleanNik))
                    {
                        query = query.Where(r => r.Nik == cleanNik || r.Members.Any(m => m.Role == "Creator" && m.Nik == cleanNik));
                    }
                    else if (statusFilter == "Pending")
                    {
                        query = query.Where(r => r.Status == "Pending");
                    }
                    else if (statusFilter == "Approved")
                    {
                        query = query.Where(r => r.Status == "Approved");
                    }
                }

                if (startDate.HasValue)
                {
                    query = query.Where(r => r.Tanggal >= startDate.Value.Date);
                }
                if (endDate.HasValue)
                {
                    var end = endDate.Value.Date.AddDays(1).AddTicks(-1);
                    query = query.Where(r => r.Tanggal <= end);
                }

                if (!string.IsNullOrWhiteSpace(search))
                {
                    var s = search.Trim().ToLower();
                    query = query.Where(r => r.Nama.ToLower().Contains(s) ||
                                             r.Nik.ToLower().Contains(s) ||
                                             r.Lokasi.ToLower().Contains(s) ||
                                             (r.NamaJalan != null && r.NamaJalan.ToLower().Contains(s)) ||
                                             (r.SegmentJalan != null && r.SegmentJalan.ToLower().Contains(s)) ||
                                             (r.Pic != null && r.Pic.ToLower().Contains(s)) ||
                                             (r.CreatorsSummary != null && r.CreatorsSummary.ToLower().Contains(s)) ||
                                             (r.ApproversSummary != null && r.ApproversSummary.ToLower().Contains(s)));
                }

                if (!string.IsNullOrWhiteSpace(namaJalan))
                {
                    query = query.Where(r => r.NamaJalan == namaJalan);
                }

                if (!string.IsNullOrWhiteSpace(kategori))
                {
                    query = query.Where(r => r.KategoriIndex == kategori);
                }

                var totalCount = await query.CountAsync();
                var items = await query
                    .OrderByDescending(r => r.Tanggal)
                    .ThenByDescending(r => r.CreatedAt)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                // Compute summary metrics (30 days) filtered by company
                var thirtyDaysAgo = DateTime.Today.AddDays(-30);
                var statsQuery = _context.RciReports
                    .Include(r => r.Members)
                    .AsNoTracking()
                    .Where(r => !r.IsDeleted && r.Tanggal >= thirtyDaysAgo);

                if (effectiveCompanyId.HasValue && effectiveCompanyId.Value > 0 && !string.IsNullOrWhiteSpace(effectiveCompanyName))
                {
                    var cleanComp = effectiveCompanyName.Trim().ToLower();
                    statsQuery = statsQuery.Where(r =>
                        (r.PerusahaanId.HasValue && r.PerusahaanId.Value == effectiveCompanyId.Value) ||
                        (r.Perusahaan != null && r.Perusahaan.ToLower() == cleanComp)
                    );
                }
                else if (effectiveCompanyId.HasValue && effectiveCompanyId.Value > 0)
                {
                    statsQuery = statsQuery.Where(r => r.PerusahaanId.HasValue && r.PerusahaanId.Value == effectiveCompanyId.Value);
                }
                else if (!string.IsNullOrWhiteSpace(effectiveCompanyName))
                {
                    var cleanComp = effectiveCompanyName.Trim().ToLower();
                    statsQuery = statsQuery.Where(r => r.Perusahaan != null && r.Perusahaan.ToLower() == cleanComp);
                }

                var recentReports = await statsQuery.ToListAsync();

                var totalMtd = recentReports.Count;
                var avgScore = recentReports.Any() ? Math.Round(recentReports.Average(r => r.ActualRoadScore), 2) : 4.0;
                var avgAch = recentReports.Any() ? Math.Round(recentReports.Average(r => r.Achievement), 1) : 100.0;
                var goodCount = recentReports.Count(r => r.KategoriIndex == "Baik");
                var fairCount = recentReports.Count(r => r.KategoriIndex == "Sedang");
                var poorCount = recentReports.Count(r => r.KategoriIndex == "Kurang");
                var pendingCount = recentReports.Count(r => r.Status == "Pending");
                var approvedCount = recentReports.Count(r => r.Status == "Approved");
                var myPendingApprovalsCount = cleanNik != "" ? recentReports.Count(r => r.Members.Any(m => m.Role == "Approver" && m.Nik == cleanNik && m.Status == "Pending")) : 0;
                var myJointCount = cleanNik != "" ? recentReports.Count(r => r.Nik == cleanNik || r.Members.Any(m => m.Role == "Creator" && m.Nik == cleanNik)) : 0;

                // Distinct roads
                var jalanList = await statsQuery
                    .Where(r => !string.IsNullOrEmpty(r.NamaJalan))
                    .Select(r => r.NamaJalan!)
                    .Distinct()
                    .ToListAsync();

                return Ok(new
                {
                    status = true,
                    total = totalCount,
                    data = items,
                    stats = new
                    {
                        totalReports = totalMtd,
                        avgScore,
                        avgAchievement = avgAch,
                        goodCount,
                        fairCount,
                        poorCount,
                        pendingCount,
                        approvedCount,
                        myPendingApprovalsCount,
                        myJointCount
                    },
                    roads = jalanList
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal mengambil data RCI: " + ex.Message });
            }
        }

        [HttpGet("search-employees")]
        public async Task<IActionResult> SearchEmployees([FromQuery] string? q)
        {
            if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 2)
                return Ok(new { status = true, data = new List<object>() });

            var term = q.Trim().ToLower();

            try
            {
                var empQuery = from k in _context.Karyawans.AsNoTracking()
                               join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                               join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                               from c in cg.DefaultIfEmpty()
                               join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                               from j in jg.DefaultIfEmpty()
                               where k.StatusAktif
                                     && (p.NamaLengkap.ToLower().Contains(term) || (k.NoNik != null && k.NoNik.ToLower().Contains(term)))
                               select new
                               {
                                   nik = k.NoNik ?? "",
                                   nama = p.NamaLengkap ?? "",
                                   jabatan = j != null ? j.NamaJabatan : "Staff",
                                   perusahaan = c != null ? c.NamaPerusahaan : "PT MEGA GLOBAL ENERGY",
                                   perusahaanId = (int?)k.IdPerusahaan
                               };

                var list = await empQuery.Take(30).ToListAsync();
                return Ok(new { status = true, data = list });
            }
            catch (Exception ex)
            {
                return Ok(new { status = false, message = ex.Message, data = new List<object>() });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDetail(int id)
        {
            var item = await _context.RciReports
                .Include(r => r.Members)
                .AsNoTracking()
                .FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);

            if (item == null) return NotFound(new { status = false, message = "Laporan RCI tidak ditemukan." });

            return Ok(new
            {
                status = true,
                data = item
            });
        }

        [HttpPost]
        public async Task<IActionResult> Save([FromForm] IFormCollection form)
        {
            try
            {
                var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value?.Trim()
                    ?? form["nik"].FirstOrDefault()
                    ?? "00000";
                var userName = User.Identity?.Name
                    ?? User.FindFirst("Name")?.Value
                    ?? form["nama"].FirstOrDefault()
                    ?? "Anonymous";
                var userDept = User.FindFirst("Department")?.Value
                    ?? form["departemen"].FirstOrDefault()
                    ?? "Operations";
                var userComp = User.FindFirst("Company")?.Value
                    ?? form["perusahaan"].FirstOrDefault()
                    ?? "PT MEGA GLOBAL ENERGY";
                int.TryParse(User.FindFirst("CompanyId")?.Value ?? form["perusahaan_id"].FirstOrDefault() ?? form["perusahaanId"].FirstOrDefault() ?? form["companyId"].FirstOrDefault(), out int compId);

                int? id = int.TryParse(form["id"].FirstOrDefault(), out var parsedId) && parsedId > 0 ? parsedId : null;
                var isNew = !id.HasValue || id.Value <= 0;

                // Parse Date & Anti-Backdate Validation
                var tanggal = DateTime.TryParse(form["tanggal"].FirstOrDefault() ?? form["date"].FirstOrDefault(), out var tgl)
                    ? tgl.Date
                    : DateTime.Today;

                if (isNew && tanggal < DateTime.Today)
                {
                    return BadRequest(new { status = false, message = "Tanggal inspeksi RCI tidak boleh backdate (kurang dari hari ini)." });
                }

                var waktuStr = form["waktu"].FirstOrDefault() ?? form["time"].FirstOrDefault() ?? DateTime.Now.ToString(@"hh\:mm");
                var waktu = TimeSpan.TryParse(waktuStr, out var ts) ? ts : DateTime.Now.TimeOfDay;

                var area = form["area"].FirstOrDefault() ?? "CPP33 - Exit Pit";
                var lokasi = form["lokasi"].FirstOrDefault() ?? area;
                var detilLokasi = form["detil_lokasi"].FirstOrDefault() ?? form["detilLokasi"].FirstOrDefault();
                var namaJalan = form["nama_jalan"].FirstOrDefault() ?? form["namaJalan"].FirstOrDefault() ?? "Jalan Hauling Utama";
                var segmentJalan = form["segment_jalan"].FirstOrDefault() ?? form["segmentJalan"].FirstOrDefault() ?? "KM 00 - KM 01";
                var shift = form["shift"].FirstOrDefault() ?? "Shift 1 (Siang)";
                var latitude = form["latitude"].FirstOrDefault() ?? form["lat"].FirstOrDefault();
                var longitude = form["longitude"].FirstOrDefault() ?? form["lng"].FirstOrDefault();

                // Standard Segment Parameters
                double.TryParse(form["panjang_segment"].FirstOrDefault() ?? form["panjangSegment"].FirstOrDefault(), out var panjangSegment);
                if (panjangSegment <= 0) panjangSegment = 100;

                double.TryParse(form["defisit_surfacing"].FirstOrDefault() ?? form["defisitSurfacing"].FirstOrDefault(), out var defisitSurfacing);
                double.TryParse(form["defisit_undulation"].FirstOrDefault() ?? form["defisitUndulation"].FirstOrDefault(), out var defisitUndulation);
                double.TryParse(form["defisit_spoil"].FirstOrDefault() ?? form["defisitSpoil"].FirstOrDefault(), out var defisitSpoil);
                double.TryParse(form["defisit_safety_berm"].FirstOrDefault() ?? form["defisitSafetyBerm"].FirstOrDefault(), out var defisitSafetyBerm);
                double.TryParse(form["defisit_crossfall"].FirstOrDefault() ?? form["defisitCrossfall"].FirstOrDefault(), out var defisitCrossfall);
                double.TryParse(form["defisit_dust"].FirstOrDefault() ?? form["defisitDust"].FirstOrDefault(), out var defisitDust);
                double.TryParse(form["defisit_drainage"].FirstOrDefault() ?? form["defisitDrainage"].FirstOrDefault(), out var defisitDrainage);
                double.TryParse(form["defisit_road_attachment"].FirstOrDefault() ?? form["defisitRoadAttachment"].FirstOrDefault(), out var defisitRoadAttachment);

                double skorSurfacing = double.TryParse(form["skor_surfacing"].FirstOrDefault() ?? form["skorSurfacing"].FirstOrDefault(), out var s1) ? s1 : 4.0;
                double skorUndulation = double.TryParse(form["skor_undulation"].FirstOrDefault() ?? form["skorUndulation"].FirstOrDefault(), out var s2) ? s2 : 4.0;
                double skorSpoil = double.TryParse(form["skor_spoil"].FirstOrDefault() ?? form["skorSpoil"].FirstOrDefault(), out var s3) ? s3 : 4.0;
                double skorSafetyBerm = double.TryParse(form["skor_safety_berm"].FirstOrDefault() ?? form["skorSafetyBerm"].FirstOrDefault(), out var s4) ? s4 : 4.0;
                double skorCrossfall = double.TryParse(form["skor_crossfall"].FirstOrDefault() ?? form["skorCrossfall"].FirstOrDefault(), out var s5) ? s5 : 4.0;
                double skorDust = double.TryParse(form["skor_dust"].FirstOrDefault() ?? form["skorDust"].FirstOrDefault(), out var s6) ? s6 : 4.0;
                double skorDrainage = double.TryParse(form["skor_drainage"].FirstOrDefault() ?? form["skorDrainage"].FirstOrDefault(), out var s7) ? s7 : 4.0;
                double skorRoadAttachment = double.TryParse(form["skor_road_attachment"].FirstOrDefault() ?? form["skorRoadAttachment"].FirstOrDefault(), out var s8) ? s8 : 4.0;

                // Formulasi SP3 Berbasis 3 Pilar:
                // Pilar 1: Permukaan Jalan (Bobot 60%) -> Surfacing 20%, Undulation 35%, Spoil 5%
                double skorPermukaanGroup = ((skorSurfacing * 0.20) + (skorUndulation * 0.35) + (skorSpoil * 0.05)) / 0.60;
                // Pilar 2: Safety Berm & Fasilitas (Bobot 20%) -> Safety Berm 10%, Road Attachment 5%, Dust 5%
                double skorSafetyBermGroup = ((skorSafetyBerm * 0.10) + (skorRoadAttachment * 0.05) + (skorDust * 0.05)) / 0.20;
                // Pilar 3: Drainage & Penirisan (Bobot 20%) -> Crossfall 10%, Drainage 10%
                double skorDrainageGroup = ((skorCrossfall * 0.10) + (skorDrainage * 0.10)) / 0.20;

                // Total Road Score (Skala 1.00 - 4.00, Target 4.00):
                double actualRoadScore = (skorPermukaanGroup * 0.60) + (skorSafetyBermGroup * 0.20) + (skorDrainageGroup * 0.20);
                actualRoadScore = Math.Round(actualRoadScore, 2);

                double targetScore = 4.00;
                double achievement = Math.Round((actualRoadScore / targetScore) * 100.0, 1);
                string kategoriIndex = achievement >= 85 ? "Baik" : (achievement >= 70 ? "Sedang" : "Kurang");

                var catatan = form["catatan"].FirstOrDefault() ?? form["notes"].FirstOrDefault();
                var tindakanPerbaikan = form["tindakan_perbaikan"].FirstOrDefault() ?? form["tindakanPerbaikan"].FirstOrDefault() ?? form["action"].FirstOrDefault();
                var pic = form["pic"].FirstOrDefault();

                // Handle Photo Upload
                var imageFile = form.Files["foto"] ?? form.Files["image"] ?? form.Files["foto_url"];
                string? fotoUrl = null;
                if (imageFile != null && imageFile.Length > 0)
                {
                    fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(imageFile, "rci", "rci");
                }

                // Parse Creators & Approvers
                var creatorNiks = ParseStringList(form["creator_niks"].FirstOrDefault() ?? form["creatorNiks"].FirstOrDefault() ?? form["creators"].FirstOrDefault());
                var approverNiks = ParseStringList(form["approver_niks"].FirstOrDefault() ?? form["approverNiks"].FirstOrDefault() ?? form["approvers"].FirstOrDefault());

                if (!creatorNiks.Contains(userNik))
                {
                    creatorNiks.Insert(0, userNik);
                }

                // Validasi Penyetuju: Wajib minimal 1 orang
                if (approverNiks.Count == 0)
                {
                    return BadRequest(new { status = false, message = "Wajib memilih minimal 1 orang Penyetuju (Approver)!" });
                }

                RciReport report;
                if (!isNew)
                {
                    report = await _context.RciReports.Include(r => r.Members).FirstOrDefaultAsync(r => r.Id == id!.Value);
                    if (report == null || report.IsDeleted) return NotFound(new { status = false, message = "Laporan RCI tidak ditemukan atau telah dihapus." });

                    report.Tanggal = tanggal;
                    report.Waktu = waktu;
                    report.Area = area;
                    report.Lokasi = lokasi;
                    report.DetilLokasi = detilLokasi;
                    report.NamaJalan = namaJalan;
                    report.SegmentJalan = segmentJalan;
                    report.Shift = shift;
                    report.Latitude = latitude;
                    report.Longitude = longitude;

                    report.PanjangSegment = panjangSegment;
                    report.DefisitSurfacing = defisitSurfacing;
                    report.DefisitUndulation = defisitUndulation;
                    report.DefisitSpoil = defisitSpoil;
                    report.DefisitSafetyBerm = defisitSafetyBerm;
                    report.DefisitCrossfall = defisitCrossfall;
                    report.DefisitDust = defisitDust;
                    report.DefisitDrainage = defisitDrainage;
                    report.DefisitRoadAttachment = defisitRoadAttachment;

                    report.SkorSurfacing = skorSurfacing;
                    report.SkorUndulation = skorUndulation;
                    report.SkorSpoil = skorSpoil;
                    report.SkorSafetyBerm = skorSafetyBerm;
                    report.SkorCrossfall = skorCrossfall;
                    report.SkorDust = skorDust;
                    report.SkorDrainage = skorDrainage;
                    report.SkorRoadAttachment = skorRoadAttachment;

                    report.SkorPermukaanGroup = Math.Round(skorPermukaanGroup, 2);
                    report.SkorSafetyBermGroup = Math.Round(skorSafetyBermGroup, 2);
                    report.SkorDrainageGroup = Math.Round(skorDrainageGroup, 2);

                    report.ActualRoadScore = actualRoadScore;
                    report.TargetScore = targetScore;
                    report.Achievement = achievement;
                    report.TotalScore = achievement;
                    report.KategoriIndex = kategoriIndex;

                    report.Catatan = catatan;
                    report.TindakanPerbaikan = tindakanPerbaikan;
                    report.Pic = pic;
                    report.UpdatedAt = DateTime.Now;

                    if (!string.IsNullOrEmpty(fotoUrl))
                    {
                        report.FotoUrl = fotoUrl;
                    }

                    // Remove existing members for clean update
                    var oldMembers = await _context.RciMembers.Where(m => m.RciReportId == report.Id).ToListAsync();
                    _context.RciMembers.RemoveRange(oldMembers);

                    await RebuildMembersAsync(report, creatorNiks, approverNiks, userNik, userName, userComp, compId);

                    _context.RciReports.Update(report);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan RCI {namaJalan} ({segmentJalan}) berhasil diperbarui! Skor: {actualRoadScore} / 4.00 ({achievement}%)",
                        data = report
                    });
                }
                else
                {
                    report = new RciReport
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nik = userNik,
                        Nama = userName,
                        Departemen = userDept,
                        Perusahaan = userComp,
                        PerusahaanId = compId > 0 ? compId : null,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        NamaJalan = namaJalan,
                        SegmentJalan = segmentJalan,
                        Shift = shift,
                        Latitude = latitude,
                        Longitude = longitude,

                        PanjangSegment = panjangSegment,
                        DefisitSurfacing = defisitSurfacing,
                        DefisitUndulation = defisitUndulation,
                        DefisitSpoil = defisitSpoil,
                        DefisitSafetyBerm = defisitSafetyBerm,
                        DefisitCrossfall = defisitCrossfall,
                        DefisitDust = defisitDust,
                        DefisitDrainage = defisitDrainage,
                        DefisitRoadAttachment = defisitRoadAttachment,

                        SkorSurfacing = skorSurfacing,
                        SkorUndulation = skorUndulation,
                        SkorSpoil = skorSpoil,
                        SkorSafetyBerm = skorSafetyBerm,
                        SkorCrossfall = skorCrossfall,
                        SkorDust = skorDust,
                        SkorDrainage = skorDrainage,
                        SkorRoadAttachment = skorRoadAttachment,

                        SkorPermukaanGroup = Math.Round(skorPermukaanGroup, 2),
                        SkorSafetyBermGroup = Math.Round(skorSafetyBermGroup, 2),
                        SkorDrainageGroup = Math.Round(skorDrainageGroup, 2),

                        ActualRoadScore = actualRoadScore,
                        TargetScore = targetScore,
                        Achievement = achievement,
                        TotalScore = achievement,
                        KategoriIndex = kategoriIndex,

                        Catatan = catatan,
                        TindakanPerbaikan = tindakanPerbaikan,
                        Pic = pic,
                        FotoUrl = fotoUrl,
                        Status = "Pending",
                        CreatedAt = DateTime.Now
                    };

                    _context.RciReports.Add(report);
                    await _context.SaveChangesAsync();

                    await RebuildMembersAsync(report, creatorNiks, approverNiks, userNik, userName, userComp, compId);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Inspeksi RCI berhasil disimpan! Skor: {actualRoadScore} / 4.00 ({achievement}%)",
                        data = report
                    });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal menyimpan laporan RCI: " + ex.Message });
            }
        }

        private async Task RebuildMembersAsync(RciReport report, List<string> creatorNiks, List<string> approverNiks, string userNik, string userName, string userComp, int compId)
        {
            var creatorSummaries = new List<string>();
            var approverSummaries = new List<string>();

            // 1. Add Creators
            foreach (var cNik in creatorNiks.Distinct())
            {
                var emp = await LookupEmployeeAsync(cNik);
                var member = new RciMember
                {
                    RciReportId = report.Id,
                    Role = "Creator",
                    Nik = emp.nik,
                    Nama = emp.nama,
                    Jabatan = emp.jabatan,
                    Perusahaan = emp.perusahaan,
                    PerusahaanId = emp.perusahaanId,
                    Status = "Confirmed",
                    ActionAt = DateTime.Now
                };
                _context.RciMembers.Add(member);
                creatorSummaries.Add($"{emp.nama} ({emp.perusahaan ?? "Mitra"})");
            }

            // 2. Add Approvers
            foreach (var aNik in approverNiks.Distinct())
            {
                var emp = await LookupEmployeeAsync(aNik);
                var member = new RciMember
                {
                    RciReportId = report.Id,
                    Role = "Approver",
                    Nik = emp.nik,
                    Nama = emp.nama,
                    Jabatan = emp.jabatan,
                    Perusahaan = emp.perusahaan,
                    PerusahaanId = emp.perusahaanId,
                    Status = "Pending"
                };
                _context.RciMembers.Add(member);
                approverSummaries.Add($"{emp.nama} ({emp.perusahaan ?? "Mitra"})");
            }

            report.CreatorsSummary = string.Join("; ", creatorSummaries);
            report.ApproversSummary = string.Join("; ", approverSummaries);
            _context.RciReports.Update(report);
        }

        private async Task<(string nik, string nama, string jabatan, string perusahaan, int? perusahaanId)> LookupEmployeeAsync(string cleanNik)
        {
            try
            {
                var emp = await (from k in _context.Karyawans
                                 where k.NoNik == cleanNik
                                 join p in _context.Personals on k.IdPersonal equals p.IdPersonal into pG
                                 from p in pG.DefaultIfEmpty()
                                 join j in _context.Jabatans on k.IdJabatan equals j.JabatanId into jG
                                 from j in jG.DefaultIfEmpty()
                                 join c in _context.Perusahaans on k.IdPerusahaan equals c.PerusahaanId into cG
                                 from c in cG.DefaultIfEmpty()
                                 select new
                                 {
                                     nik = k.NoNik,
                                     nama = p != null ? p.NamaLengkap : k.NoNik,
                                     jabatan = j != null ? j.NamaJabatan : "Staff",
                                     perusahaan = c != null ? c.NamaPerusahaan : "PT MEGA GLOBAL ENERGY",
                                     perusahaanId = (int?)k.IdPerusahaan
                                 }).FirstOrDefaultAsync();

                if (emp != null)
                {
                    return (emp.nik, emp.nama, emp.jabatan, emp.perusahaan, emp.perusahaanId);
                }
            }
            catch { }

            return (cleanNik, cleanNik, "Staff", "PT MEGA GLOBAL ENERGY", null);
        }

        private List<string> ParseStringList(string? raw)
        {
            var list = new List<string>();
            if (string.IsNullOrWhiteSpace(raw)) return list;

            var trimmed = raw.Trim();
            if (trimmed.StartsWith("[") && trimmed.EndsWith("]"))
            {
                try
                {
                    var parsed = JsonSerializer.Deserialize<List<string>>(trimmed);
                    if (parsed != null)
                    {
                        list.AddRange(parsed.Where(s => !string.IsNullOrWhiteSpace(s)).Select(s => s.Trim()));
                        return list;
                    }
                }
                catch { }
            }

            var parts = trimmed.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (var p in parts)
            {
                if (!string.IsNullOrWhiteSpace(p)) list.Add(p.Trim());
            }

            return list;
        }

        [HttpPost("{id}/approve")]
        public async Task<IActionResult> Approve(int id, [FromForm] string? catatan, [FromForm] string? approverNik)
        {
            try
            {
                var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value?.Trim()
                    ?? approverNik?.Trim()
                    ?? "";

                if (string.IsNullOrWhiteSpace(userNik))
                {
                    return BadRequest(new { status = false, message = "NIK Approver wajib diisi." });
                }

                var report = await _context.RciReports.Include(r => r.Members).FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);
                if (report == null) return NotFound(new { status = false, message = "Laporan RCI tidak ditemukan." });

                var member = report.Members.FirstOrDefault(m => m.Role == "Approver" && m.Nik == userNik);
                if (member == null)
                {
                    return BadRequest(new { status = false, message = "Anda tidak terdaftar sebagai penyetuju pada laporan RCI ini." });
                }

                member.Status = "Approved";
                member.Catatan = catatan;
                member.ActionAt = DateTime.Now;
                _context.RciMembers.Update(member);

                // If all approvers have approved, mark report as Approved
                bool allApproved = report.Members.Where(m => m.Role == "Approver").All(m => m.Status == "Approved");
                if (allApproved)
                {
                    report.Status = "Approved";
                    report.ApprovedAt = DateTime.Now;
                    _context.RciReports.Update(report);
                }

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    status = true,
                    message = $"Laporan RCI berhasil disetujui oleh {member.Nama}!",
                    data = report
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal memproses persetujuan: " + ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var item = await _context.RciReports.FindAsync(id);
            if (item == null || item.IsDeleted) return NotFound(new { status = false, message = "Laporan RCI tidak ditemukan." });

            item.IsDeleted = true;
            item.UpdatedAt = DateTime.Now;
            _context.RciReports.Update(item);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Laporan RCI berhasil dihapus."
            });
        }
    }
}
