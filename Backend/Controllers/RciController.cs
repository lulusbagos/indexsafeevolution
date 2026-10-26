using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
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
                var isIndeximOwner = !string.IsNullOrWhiteSpace(effectiveCompanyName) && effectiveCompanyName.ToLower().Contains("indexim");

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
                    // Pastikan bagian semua jalan tampilkan inspeksi perusahaan yang sesuai atau seluruh hirarki
                    if (!isIndeximOwner)
                    {
                        List<int>? allowedIds = null;
                        if (effectiveCompanyId.HasValue && effectiveCompanyId.Value > 0)
                        {
                            allowedIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(effectiveCompanyId.Value);
                        }

                        if (allowedIds != null && allowedIds.Count > 0)
                        {
                            query = query.Where(r => r.PerusahaanId.HasValue && allowedIds.Contains(r.PerusahaanId.Value));
                        }
                        else if (!string.IsNullOrWhiteSpace(effectiveCompanyName))
                        {
                            var cleanComp = effectiveCompanyName.Trim().ToLower();
                            query = query.Where(r => r.Perusahaan != null && r.Perusahaan.ToLower() == cleanComp);
                        }
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
                    else if (statusFilter == "Approved" || statusFilter == "Closed")
                    {
                        query = query.Where(r => r.Status == "Approved" || r.Status == "Closed");
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

                if (!isIndeximOwner)
                {
                    List<int>? allowedIds = null;
                    if (effectiveCompanyId.HasValue && effectiveCompanyId.Value > 0)
                    {
                        allowedIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(effectiveCompanyId.Value);
                    }

                    if (allowedIds != null && allowedIds.Count > 0)
                    {
                        statsQuery = statsQuery.Where(r => r.PerusahaanId.HasValue && allowedIds.Contains(r.PerusahaanId.Value));
                    }
                    else if (!string.IsNullOrWhiteSpace(effectiveCompanyName))
                    {
                        var cleanComp = effectiveCompanyName.Trim().ToLower();
                        statsQuery = statsQuery.Where(r => r.Perusahaan != null && r.Perusahaan.ToLower() == cleanComp);
                    }
                }

                var recentReports = await statsQuery.ToListAsync();

                var totalMtd = recentReports.Count;
                var avgScore = recentReports.Any() ? Math.Round(recentReports.Average(r => r.ActualRoadScore), 2) : 4.0;
                var avgAch = recentReports.Any() ? Math.Round(recentReports.Average(r => r.Achievement), 1) : 100.0;
                var goodCount = recentReports.Count(r => r.KategoriIndex == "Baik");
                var fairCount = recentReports.Count(r => r.KategoriIndex == "Sedang");
                var poorCount = recentReports.Count(r => r.KategoriIndex == "Kurang");
                var pendingCount = recentReports.Count(r => r.Status == "Pending");
                var approvedCount = recentReports.Count(r => r.Status == "Approved" || r.Status == "Closed");
                var closedCount = recentReports.Count(r => r.Status == "Closed");
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
        public async Task<IActionResult> SearchEmployees([FromQuery] string? q, [FromQuery] int? companyId, [FromQuery] string? companyName, [FromQuery] int limit = 60)
        {
            try
            {
                var qEmp = from k in _context.MitraKaryawanAktifs.AsNoTracking()
                           join m in _context.KaryawanJabatanMappings.AsNoTracking() on k.IdKaryawan equals m.KaryawanId
                           where k.StatusAktifEfektif
                                 && ((m.TargetInspeksi ?? 0) > 0 
                                     || (m.TargetObservasi ?? 0) > 0 
                                     || (m.TargetHazardReport ?? 0) > 0 
                                     || (m.TargetCoaching ?? 0) > 0 
                                     || (m.TargetSafetyTalk ?? 0) > 0 
                                     || (m.KategoriPengawas != null 
                                         && m.KategoriPengawas != "NON SAP" 
                                         && m.KategoriPengawas != "NON SAP (Target 0 / Jabatan Tidak Masuk)" 
                                         && m.KategoriPengawas != "-"))
                           select new
                           {
                               nik = k.NoNik,
                               nama = k.NamaLengkap ?? "",
                               departemen = k.NamaDepartemen ?? "",
                               jabatan = k.NamaJabatan ?? k.NamaPosisi ?? "Staff",
                               perusahaan = k.NamaPerusahaan ?? "",
                               perusahaanId = k.IdPerusahaan,
                               foto = k.PathFoto ?? "",
                               kategoriPengawas = m.KategoriPengawas ?? ""
                           };

                var cleanQ = (q ?? string.Empty).Trim().ToLower();
                var terms = cleanQ.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                var hasQuery = terms.Length > 0;

                if (hasQuery)
                {
                    foreach (var term in terms)
                    {
                        var t = term;
                        qEmp = qEmp.Where(x => x.nama.ToLower().Contains(t) || x.nik.ToLower().Contains(t) || x.perusahaan.ToLower().Contains(t));
                    }
                }

                int? compIdVal = companyId;
                if (!compIdVal.HasValue || compIdVal <= 0)
                {
                    if (int.TryParse(User.FindFirst("CompanyId")?.Value, out var cid) && cid > 0)
                    {
                        compIdVal = cid;
                    }
                }
                var effectiveCompanyId = compIdVal;
                var cleanCompName = (companyName ?? User.FindFirst("Company")?.Value ?? Request.Headers["company"].FirstOrDefault() ?? string.Empty).Trim().ToLower();

                var list = await qEmp.OrderBy(x => (
                                         (effectiveCompanyId.HasValue && x.perusahaanId == effectiveCompanyId.Value) ||
                                         (!string.IsNullOrEmpty(cleanCompName) && (x.perusahaan.ToLower() == cleanCompName || x.perusahaan.ToLower().Contains(cleanCompName)))
                                      ) ? 0 : 1)
                                     .ThenBy(x => hasQuery 
                                         ? (x.nama.ToLower().StartsWith(cleanQ) ? 0 
                                            : (x.nama.ToLower().StartsWith(terms[0]) ? 1 
                                            : (x.nama.ToLower().Contains(" " + cleanQ) ? 2 : 3)))
                                         : 0)
                                     .ThenBy(x => x.nama)
                                     .Take(limit)
                                     .ToListAsync();

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

                    // Kirim notifikasi ke seluruh Penyetuju (Approver) & PIC Tindakan Perbaikan
                    try
                    {
                        var picNik = await ExtractPicNikAsync(report.Pic);

                        // 1. Notifikasi Permintaan Persetujuan ke setiap Penyetuju
                        foreach (var aNik in approverNiks.Distinct())
                        {
                            AddNotification(
                                recipientNik: aNik,
                                title: $"Permintaan Persetujuan RCI: {report.NamaJalan}",
                                message: $"{report.Nama} mengajukan inspeksi RCI {report.NamaJalan} ({report.SegmentJalan}) dengan nilai {actualRoadScore:0.00} / 4.00 ({achievement}%). Menunggu persetujuan Anda.",
                                url: $"/Rci/Detail/{report.Id}",
                                notifType: "rci_approval_request",
                                senderName: report.Nama,
                                priority: "high",
                                actionText: "Setujui Sekarang"
                            );
                        }

                        // 2. Notifikasi Tugas ke PIC Tindakan Perbaikan
                        if (!string.IsNullOrEmpty(picNik))
                        {
                            AddNotification(
                                recipientNik: picNik,
                                title: $"Tugas Tindakan Perbaikan RCI: {report.NamaJalan}",
                                message: $"Anda ditugaskan sebagai PIC Tindakan Perbaikan RCI {report.NamaJalan} ({report.SegmentJalan}) oleh {report.Nama}. Tindakan: {report.TindakanPerbaikan ?? "Perbaikan jalan hauling sesuai standar"}. Menunggu persetujuan tim penyetuju.",
                                url: $"/Rci/Detail/{report.Id}",
                                notifType: "rci_pic_task",
                                senderName: report.Nama,
                                priority: "normal",
                                actionText: "Lihat Rincian"
                            );
                        }

                        await _context.SaveChangesAsync();
                    }
                    catch { }

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
        public async Task<IActionResult> Approve(int id)
        {
            try
            {
                string? userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value?.Trim();
                string? catatan = null;

                if (Request.HasJsonContentType())
                {
                    try
                    {
                        using var reader = new StreamReader(Request.Body);
                        var json = await reader.ReadToEndAsync();
                        if (!string.IsNullOrWhiteSpace(json))
                        {
                            using var doc = JsonDocument.Parse(json);
                            var root = doc.RootElement;
                            if (string.IsNullOrWhiteSpace(userNik))
                            {
                                if (root.TryGetProperty("approverNik", out var anProp)) userNik = anProp.GetString();
                                else if (root.TryGetProperty("nik", out var nProp)) userNik = nProp.GetString();
                            }
                            if (root.TryGetProperty("catatan", out var cProp)) catatan = cProp.GetString();
                            else if (root.TryGetProperty("notes", out var notProp)) catatan = notProp.GetString();
                        }
                    }
                    catch { }
                }
                else if (Request.HasFormContentType)
                {
                    var form = await Request.ReadFormAsync();
                    if (string.IsNullOrWhiteSpace(userNik))
                    {
                        userNik = form["approverNik"].FirstOrDefault()?.Trim() ?? form["nik"].FirstOrDefault()?.Trim();
                    }
                    catatan ??= form["catatan"].FirstOrDefault() ?? form["notes"].FirstOrDefault();
                }

                if (string.IsNullOrWhiteSpace(userNik))
                {
                    userNik = Request.Query["approverNik"].FirstOrDefault()?.Trim() ?? Request.Query["nik"].FirstOrDefault()?.Trim();
                }

                if (string.IsNullOrWhiteSpace(userNik))
                {
                    return BadRequest(new { status = false, message = "NIK Approver wajib diisi." });
                }

                var report = await _context.RciReports.Include(r => r.Members).FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);
                if (report == null) return NotFound(new { status = false, message = "Laporan RCI tidak ditemukan." });

                var member = report.Members.FirstOrDefault(m => m.Role == "Approver" && m.Nik == userNik);
                if (member == null)
                {
                    // Fallback: match by trimmed NIK or name
                    member = report.Members.FirstOrDefault(m => m.Role == "Approver" && m.Nik.Trim() == userNik.Trim());
                }

                if (member == null)
                {
                    return BadRequest(new { status = false, message = "Anda tidak terdaftar sebagai penyetuju pada laporan RCI ini." });
                }

                member.Status = "Approved";
                member.Catatan = catatan;
                member.ActionAt = DateTime.Now;
                _context.RciMembers.Update(member);

                // Tandai notifikasi permintaan persetujuan untuk penyetuju ini sudah ditindaklanjuti & dibaca
                try
                {
                    var pendingNotifs = await _context.Notifications
                        .Where(n => n.RecipientNik == userNik && n.Url == $"/Rci/Detail/{report.Id}" && !n.IsActioned)
                        .ToListAsync();
                    foreach (var pn in pendingNotifs)
                    {
                        pn.IsActioned = true;
                        pn.IsRead = true;
                    }
                }
                catch { }

                // Periksa apakah seluruh penyetuju telah menyetujui
                bool allApproved = report.Members.Where(m => m.Role == "Approver").All(m => m.Status == "Approved");
                var picNik = await ExtractPicNikAsync(report.Pic);

                if (allApproved)
                {
                    // Persyaratan user: "samapai semua di setujui dinyatakan RCI akan close"
                    report.Status = "Closed";
                    report.ApprovedAt = DateTime.Now;
                    _context.RciReports.Update(report);

                    // 1. Notifikasi ke PIC Perbaikan: Laporan RCI Disetujui Penuh & Resmi CLOSED
                    if (!string.IsNullOrEmpty(picNik))
                    {
                        AddNotification(
                            recipientNik: picNik,
                            title: $"RCI Closed & Disetujui Penuh: {report.NamaJalan}",
                            message: $"Laporan RCI {report.NamaJalan} ({report.SegmentJalan}) telah disetujui oleh {member.Nama} dan seluruh tim penyetuju. Status laporan resmi dinyatakan CLOSED. Silakan laksanakan tindakan perbaikan: {report.TindakanPerbaikan ?? "Perbaikan jalan hauling sesuai standar"}.",
                            url: $"/Rci/Detail/{report.Id}",
                            notifType: "rci_closed",
                            senderName: member.Nama,
                            priority: "high",
                            actionText: "Lihat Rincian"
                        );
                    }

                    // 2. Notifikasi ke seluruh Penyetuju (Approvers): RCI dinyatakan CLOSED
                    foreach (var app in report.Members.Where(m => m.Role == "Approver"))
                    {
                        AddNotification(
                            recipientNik: app.Nik,
                            title: $"RCI Selesai Disetujui (Closed): {report.NamaJalan}",
                            message: $"Laporan RCI {report.NamaJalan} ({report.SegmentJalan}) telah selesai disetujui oleh seluruh tim penyetuju dan status resmi dinyatakan CLOSED.",
                            url: $"/Rci/Detail/{report.Id}",
                            notifType: "rci_closed",
                            senderName: member.Nama,
                            priority: "normal",
                            actionText: "Lihat Rincian"
                        );
                    }

                    // 3. Notifikasi ke Pembuat / Pelapor (Creator): RCI dinyatakan CLOSED
                    if (!string.IsNullOrWhiteSpace(report.Nik))
                    {
                        AddNotification(
                            recipientNik: report.Nik,
                            title: $"Laporan RCI Closed & Disetujui Penuh: {report.NamaJalan}",
                            message: $"Kabar baik! Laporan inspeksi RCI {report.NamaJalan} ({report.SegmentJalan}) Anda telah disetujui seluruh penyetuju dan resmi dinyatakan CLOSED.",
                            url: $"/Rci/Detail/{report.Id}",
                            notifType: "rci_closed",
                            senderName: member.Nama,
                            priority: "high",
                            actionText: "Lihat Rincian"
                        );
                    }
                }
                else
                {
                    // Persetujuan Parsial (Masih ada penyetuju lain yang belum menyetujui)
                    // 1. Notifikasi ke PIC Perbaikan: disetujui oleh member (Dian / approver terkait)
                    if (!string.IsNullOrEmpty(picNik))
                    {
                        AddNotification(
                            recipientNik: picNik,
                            title: $"Persetujuan RCI: {report.NamaJalan}",
                            message: $"Laporan RCI {report.NamaJalan} ({report.SegmentJalan}) telah disetujui oleh {member.Nama} ({member.Jabatan ?? "Penyetuju"}). Menunggu persetujuan penyetuju lainnya.",
                            url: $"/Rci/Detail/{report.Id}",
                            notifType: "rci_partial_approval",
                            senderName: member.Nama,
                            priority: "normal",
                            actionText: "Lihat Rincian"
                        );
                    }

                    // 2. Notifikasi ke Penyetuju lain yang belum menyetujui (Pengingat)
                    var pendingApprovers = report.Members.Where(m => m.Role == "Approver" && m.Status == "Pending" && m.Nik != userNik);
                    foreach (var pApp in pendingApprovers)
                    {
                        AddNotification(
                            recipientNik: pApp.Nik,
                            title: $"Pengingat Persetujuan RCI: {report.NamaJalan}",
                            message: $"{member.Nama} telah menyetujui laporan RCI {report.NamaJalan} ({report.SegmentJalan}). Mohon segera meninjau dan memberikan persetujuan Anda.",
                            url: $"/Rci/Detail/{report.Id}",
                            notifType: "rci_approval_request",
                            senderName: member.Nama,
                            priority: "high",
                            actionText: "Setujui Sekarang"
                        );
                    }

                    // 3. Notifikasi progres ke Pembuat / Pelapor
                    if (!string.IsNullOrWhiteSpace(report.Nik) && report.Nik != userNik)
                    {
                        AddNotification(
                            recipientNik: report.Nik,
                            title: $"Progres Persetujuan RCI: {report.NamaJalan}",
                            message: $"Laporan RCI {report.NamaJalan} ({report.SegmentJalan}) Anda telah disetujui oleh {member.Nama} ({member.Jabatan ?? "Penyetuju"}). Menunggu persetujuan penyetuju lainnya.",
                            url: $"/Rci/Detail/{report.Id}",
                            notifType: "rci_partial_approval",
                            senderName: member.Nama,
                            priority: "normal",
                            actionText: "Lihat Rincian"
                        );
                    }
                }

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    status = true,
                    message = allApproved
                        ? $"Laporan RCI berhasil disetujui penuh oleh seluruh penyetuju dan dinyatakan CLOSED!"
                        : $"Laporan RCI berhasil disetujui oleh {member.Nama}!",
                    data = report
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal memproses persetujuan: " + ex.Message });
            }
        }

        private async Task<string?> ExtractPicNikAsync(string? pic)
        {
            if (string.IsNullOrWhiteSpace(pic)) return null;

            var match = Regex.Match(pic, @"\(([^)]+)\)");
            if (match.Success)
            {
                var inside = match.Groups[1].Value.Trim();
                var numInParentheses = Regex.Match(inside, @"\b\d{5,15}\b");
                if (numInParentheses.Success) return numInParentheses.Value;
                if (!string.IsNullOrEmpty(inside)) return inside;
            }

            var numMatch = Regex.Match(pic, @"\b\d{5,15}\b");
            if (numMatch.Success) return numMatch.Value;

            try
            {
                var cleanName = pic.Trim().ToLower();
                var empNik = await _context.MitraKaryawanAktifs.AsNoTracking()
                    .Where(k => k.NamaLengkap != null && k.NamaLengkap.ToLower().Contains(cleanName))
                    .Select(k => k.NoNik)
                    .FirstOrDefaultAsync();
                if (!string.IsNullOrEmpty(empNik)) return empNik;
            }
            catch { }

            return null;
        }

        private void AddNotification(string recipientNik, string title, string message, string url, string notifType, string senderName, string priority = "normal", string? actionText = null)
        {
            if (string.IsNullOrWhiteSpace(recipientNik)) return;
            try
            {
                _context.Notifications.Add(new Notification
                {
                    RecipientNik = recipientNik.Trim(),
                    Title = title,
                    Message = message,
                    Url = url,
                    NotifType = notifType,
                    Category = "rci",
                    SenderName = senderName,
                    Priority = priority,
                    ActionText = actionText,
                    IsRead = false,
                    IsActioned = false,
                    CreatedAt = DateTime.Now
                });
            }
            catch { }
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
