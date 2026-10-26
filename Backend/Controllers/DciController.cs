using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
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
    [Route("api/dci")]
    [Route("dci")]
    [AllowAnonymous]
    public class DciController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ImageUploadService _imageUploadService;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private static bool _schemaEnsured = false;

        public DciController(AppDbContext context, ImageUploadService imageUploadService, CompanyHierarchyService companyHierarchyService)
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
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tbl_t_dci_report')
BEGIN
    CREATE TABLE [tbl_t_dci_report] (
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
        [Disposal] NVARCHAR(100) NULL,
        [NamaDump] NVARCHAR(100) NULL,
        [Pad] NVARCHAR(100) NULL,
        [Shift] NVARCHAR(20) NULL,
        [Latitude] NVARCHAR(50) NULL,
        [Longitude] NVARCHAR(50) NULL,
        [SkorLantaiDump] INT NOT NULL DEFAULT 100,
        [SkorSafetyBerm] INT NOT NULL DEFAULT 100,
        [SkorKondisiCrest] INT NOT NULL DEFAULT 100,
        [SkorGradeDumping] INT NOT NULL DEFAULT 100,
        [SkorDrainaseDump] INT NOT NULL DEFAULT 100,
        [SkorPenataanSpillage] INT NOT NULL DEFAULT 100,
        [SkorRambuPenerangan] INT NOT NULL DEFAULT 100,
        [SkorSpotterManuver] INT NOT NULL DEFAULT 100,
        [TotalScore] FLOAT NOT NULL DEFAULT 100,
        [KategoriIndex] NVARCHAR(50) NOT NULL DEFAULT 'Baik',
        [Catatan] NVARCHAR(2000) NULL,
        [TindakanPerbaikan] NVARCHAR(2000) NULL,
        [Pic] NVARCHAR(100) NULL,
        [FotoUrl] NVARCHAR(500) NULL,
        [is_deleted] BIT NOT NULL DEFAULT 0,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETDATE(),
        [UpdatedAt] DATETIME2 NULL
    );
END
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('tbl_t_dci_report') AND name = 'Pad')
BEGIN
    ALTER TABLE [tbl_t_dci_report] ADD [Pad] NVARCHAR(100) NULL;
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
            [FromQuery] string? search,
            [FromQuery] string? disposal,
            [FromQuery] string? kategori,
            [FromQuery] DateTime? startDate,
            [FromQuery] DateTime? endDate,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var query = _context.DciReports.AsNoTracking().Where(r => !r.IsDeleted);

                int? effectiveCompanyId = companyId.HasValue && companyId.Value > 0
                    ? companyId.Value
                    : (int.TryParse(User.FindFirst("CompanyId")?.Value, out var cid) ? cid : null);
                string? effectiveCompanyName = !string.IsNullOrWhiteSpace(companyName)
                    ? companyName.Trim()
                    : User.FindFirst("Company")?.Value;

                // Auto-resolve company from employee master if missing
                if ((!effectiveCompanyId.HasValue || effectiveCompanyId.Value <= 0 || string.IsNullOrWhiteSpace(effectiveCompanyName)) && !string.IsNullOrWhiteSpace(userNik))
                {
                    var cleanNik = userNik.Trim();
                    var emp = await (from k in _context.Karyawans.AsNoTracking()
                                     join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                                     from c in cg.DefaultIfEmpty()
                                     where k.NoNik == cleanNik
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

                // Scope / History filter:
                // 'my_history': laporan yang saya buat ATAU saya ditunjuk sebagai PIC
                // 'created': laporan yang dibuat oleh saya sendiri
                // 'pic': laporan di mana saya ditugaskan sebagai PIC
                // 'all': semua disposal (difilter per perusahaan bila ada)
                if (!string.IsNullOrWhiteSpace(userNik) && scope != "all")
                {
                    var cleanNik = userNik.Trim();
                    var cleanNama = !string.IsNullOrWhiteSpace(userNama) ? userNama.Trim().ToLower() : "";

                    if (scope == "created")
                    {
                        query = query.Where(r => r.Nik == cleanNik);
                    }
                    else if (scope == "pic")
                    {
                        query = query.Where(r => r.Pic != null && (r.Pic.Contains(cleanNik) || (cleanNama != "" && r.Pic.ToLower().Contains(cleanNama))));
                    }
                    else
                    {
                        query = query.Where(r => r.Nik == cleanNik || (r.Pic != null && (r.Pic.Contains(cleanNik) || (cleanNama != "" && r.Pic.ToLower().Contains(cleanNama)))));
                    }
                }
                else if (scope == "all")
                {
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
                                             (r.NamaDump != null && r.NamaDump.ToLower().Contains(s)) ||
                                             (r.Disposal != null && r.Disposal.ToLower().Contains(s)) ||
                                             (r.Pic != null && r.Pic.ToLower().Contains(s)));
                }

                if (!string.IsNullOrWhiteSpace(disposal))
                {
                    query = query.Where(r => r.Disposal == disposal);
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

                // Compute summary metrics (30 days) filtered by company as well
                var thirtyDaysAgo = DateTime.Today.AddDays(-30);
                var statsQuery = _context.DciReports.AsNoTracking().Where(r => !r.IsDeleted && r.Tanggal >= thirtyDaysAgo);
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
                var avgScore = recentReports.Any() ? Math.Round(recentReports.Average(r => r.TotalScore), 1) : 100.0;
                var goodCount = recentReports.Count(r => r.KategoriIndex == "Baik");
                var fairCount = recentReports.Count(r => r.KategoriIndex == "Sedang");
                var poorCount = recentReports.Count(r => r.KategoriIndex == "Kurang");

                // Distinct disposals, dump names, and pad names
                var disposalList = await _context.DciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.Disposal))
                    .Select(r => r.Disposal!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                var dumpNameList = await _context.DciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.NamaDump))
                    .Select(r => r.NamaDump!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                var padNameList = await _context.DciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.Pad))
                    .Select(r => r.Pad!)
                    .Distinct()
                    .OrderBy(x => x)
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
                        goodCount,
                        fairCount,
                        poorCount
                    },
                    disposals = disposalList,
                    dumpNames = dumpNameList,
                    padNames = padNameList
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal mengambil data DCI: " + ex.Message });
            }
        }

        [HttpGet("suggestions")]
        public async Task<IActionResult> GetSuggestions([FromQuery] string? disposal)
        {
            try
            {
                var dQuery = _context.DciReports.AsNoTracking().Where(r => !r.IsDeleted);

                var disposals = await dQuery
                    .Where(r => !string.IsNullOrEmpty(r.Disposal))
                    .Select(r => r.Disposal!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                var dumpQuery = dQuery.Where(r => !string.IsNullOrEmpty(r.NamaDump));
                if (!string.IsNullOrWhiteSpace(disposal))
                {
                    dumpQuery = dumpQuery.Where(r => r.Disposal == disposal);
                }

                var dumpNames = await dumpQuery
                    .Select(r => r.NamaDump!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                var padNames = await dQuery
                    .Where(r => !string.IsNullOrEmpty(r.Pad))
                    .Select(r => r.Pad!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                return Ok(new
                {
                    status = true,
                    disposals,
                    dumpNames,
                    padNames
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal mengambil saran DCI: " + ex.Message });
            }
        }

        [HttpGet("search-employees")]
        [HttpGet("pic-employees")]
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
                                            : x.nama.ToLower().Contains(cleanQ) ? 1 : 2)
                                         : 0)
                                     .ThenBy(x => x.nama)
                                     .Take(limit > 0 ? limit : 60)
                                     .ToListAsync();

                return Ok(new
                {
                    status = true,
                    total = list.Count,
                    data = list
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal mencari pengawas SAP: " + ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDetail(int id)
        {
            var item = await _context.DciReports.AsNoTracking().FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);
            if (item == null) return NotFound(new { status = false, message = "Laporan DCI tidak ditemukan." });

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
                var formComp = form["perusahaan"].FirstOrDefault();
                var userComp = !string.IsNullOrWhiteSpace(formComp)
                    ? formComp.Trim()
                    : (User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO");

                var formCompIdStr = form["perusahaan_id"].FirstOrDefault() ?? form["perusahaanId"].FirstOrDefault();
                int compId = 0;
                if (!int.TryParse(formCompIdStr, out compId) || compId <= 0)
                {
                    int.TryParse(User.FindFirst("CompanyId")?.Value, out compId);
                }

                int? id = int.TryParse(form["id"].FirstOrDefault(), out var parsedId) && parsedId > 0 ? parsedId : null;
                var isNew = !id.HasValue || id.Value <= 0;

                // Parse Date & Anti-Backdate Validation
                var tanggal = DateTime.TryParse(form["tanggal"].FirstOrDefault() ?? form["date"].FirstOrDefault(), out var tgl)
                    ? tgl.Date
                    : DateTime.Today;

                if (isNew && tanggal < DateTime.Today)
                {
                    return BadRequest(new { status = false, message = "Tanggal inspeksi DCI tidak boleh backdate (kurang dari hari ini)." });
                }

                var waktuStr = form["waktu"].FirstOrDefault() ?? form["time"].FirstOrDefault() ?? DateTime.Now.ToString(@"hh\:mm");
                var waktu = TimeSpan.TryParse(waktuStr, out var ts) ? ts : DateTime.Now.TimeOfDay;

                var area = form["area"].FirstOrDefault() ?? "Area Tambang";
                var lokasi = form["lokasi"].FirstOrDefault() ?? area;
                var detilLokasi = form["detil_lokasi"].FirstOrDefault() ?? form["detilLokasi"].FirstOrDefault();
                var disposal = form["disposal"].FirstOrDefault() ?? "Disposal Utama";
                var namaDump = form["nama_dump"].FirstOrDefault() ?? form["namaDump"].FirstOrDefault() ?? disposal;
                var pad = form["pad"].FirstOrDefault() ?? form["nama_pad"].FirstOrDefault() ?? form["namaPad"].FirstOrDefault();
                var shift = form["shift"].FirstOrDefault() ?? "Shift 1 (Siang)";
                var latitude = form["latitude"].FirstOrDefault() ?? form["lat"].FirstOrDefault();
                var longitude = form["longitude"].FirstOrDefault() ?? form["lng"].FirstOrDefault() ?? form["long"].FirstOrDefault();

                // Parameter scores (default 100)
                int skorLantaiDump = int.TryParse(form["skor_lantai_dump"].FirstOrDefault() ?? form["skorLantaiDump"].FirstOrDefault(), out var s1) ? s1 : 100;
                int skorSafetyBerm = int.TryParse(form["skor_safety_berm"].FirstOrDefault() ?? form["skorSafetyBerm"].FirstOrDefault(), out var s2) ? s2 : 100;
                int skorKondisiCrest = int.TryParse(form["skor_kondisi_crest"].FirstOrDefault() ?? form["skorKondisiCrest"].FirstOrDefault(), out var s3) ? s3 : 100;
                int skorGradeDumping = int.TryParse(form["skor_grade_dumping"].FirstOrDefault() ?? form["skorGradeDumping"].FirstOrDefault(), out var s4) ? s4 : 100;
                int skorDrainaseDump = int.TryParse(form["skor_drainase_dump"].FirstOrDefault() ?? form["skorDrainaseDump"].FirstOrDefault(), out var s5) ? s5 : 100;
                int skorPenataanSpillage = int.TryParse(form["skor_penataan_spillage"].FirstOrDefault() ?? form["skorPenataanSpillage"].FirstOrDefault(), out var s6) ? s6 : 100;
                int skorRambuPenerangan = int.TryParse(form["skor_rambu_penerangan"].FirstOrDefault() ?? form["skorRambuPenerangan"].FirstOrDefault(), out var s7) ? s7 : 100;
                int skorSpotterManuver = int.TryParse(form["skor_spotter_manuver"].FirstOrDefault() ?? form["skorSpotterManuver"].FirstOrDefault(), out var s8) ? s8 : 100;

                var catatan = form["catatan"].FirstOrDefault() ?? form["notes"].FirstOrDefault();
                var tindakanPerbaikan = form["tindakan_perbaikan"].FirstOrDefault() ?? form["tindakanPerbaikan"].FirstOrDefault() ?? form["action"].FirstOrDefault();
                var pic = form["pic"].FirstOrDefault();

                // Weighted calculation:
                // Lantai Dump (15%), Safety Berm (15%), Kondisi Crest (15%), Grade Dumping (15%),
                // Drainase Dump (10%), Penataan Spillage (10%), Rambu & Penerangan (10%), Spotter & Manuver (10%)
                double totalScore = (skorLantaiDump * 0.15) +
                                    (skorSafetyBerm * 0.15) +
                                    (skorKondisiCrest * 0.15) +
                                    (skorGradeDumping * 0.15) +
                                    (skorDrainaseDump * 0.10) +
                                    (skorPenataanSpillage * 0.10) +
                                    (skorRambuPenerangan * 0.10) +
                                    (skorSpotterManuver * 0.10);
                totalScore = Math.Round(totalScore, 1);

                string kategoriIndex = totalScore >= 85 ? "Baik" : (totalScore >= 70 ? "Sedang" : "Kurang");

                // Photo upload
                string? fotoUrl = null;
                var fotoFile = form.Files.GetFile("foto") ?? form.Files.GetFile("image") ?? form.Files.FirstOrDefault();
                if (fotoFile != null && fotoFile.Length > 0)
                {
                    fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(fotoFile, "dci", "dci");
                }

                DciReport report;

                if (!isNew)
                {
                    report = await _context.DciReports.FirstOrDefaultAsync(r => r.Id == id!.Value && !r.IsDeleted);
                    if (report == null)
                    {
                        return NotFound(new { status = false, message = "Laporan DCI tidak ditemukan untuk diperbarui." });
                    }

                    report.Tanggal = tanggal;
                    report.Waktu = waktu;
                    if (!string.IsNullOrWhiteSpace(userComp)) report.Perusahaan = userComp;
                    if (compId > 0) report.PerusahaanId = compId;
                    report.Area = area;
                    report.Lokasi = lokasi;
                    report.DetilLokasi = detilLokasi;
                    report.Disposal = disposal;
                    report.NamaDump = namaDump;
                    report.Pad = pad;
                    report.Shift = shift;
                    report.Latitude = latitude;
                    report.Longitude = longitude;
                    report.SkorLantaiDump = skorLantaiDump;
                    report.SkorSafetyBerm = skorSafetyBerm;
                    report.SkorKondisiCrest = skorKondisiCrest;
                    report.SkorGradeDumping = skorGradeDumping;
                    report.SkorDrainaseDump = skorDrainaseDump;
                    report.SkorPenataanSpillage = skorPenataanSpillage;
                    report.SkorRambuPenerangan = skorRambuPenerangan;
                    report.SkorSpotterManuver = skorSpotterManuver;
                    report.TotalScore = totalScore;
                    report.KategoriIndex = kategoriIndex;
                    report.Catatan = catatan;
                    report.TindakanPerbaikan = tindakanPerbaikan;
                    report.Pic = pic;
                    report.UpdatedAt = DateTime.Now;

                    if (!string.IsNullOrEmpty(fotoUrl))
                    {
                        report.FotoUrl = fotoUrl;
                    }

                    _context.DciReports.Update(report);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan DCI di {namaDump ?? lokasi} berhasil diperbarui!",
                        id = report.Id,
                        data = report
                    });
                }
                else
                {
                    report = new DciReport
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nik = userNik,
                        Nama = userName,
                        Departemen = userDept,
                        Perusahaan = userComp,
                        PerusahaanId = compId > 0 ? compId : (int?)null,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        Disposal = disposal,
                        NamaDump = namaDump,
                        Pad = pad,
                        Shift = shift,
                        Latitude = latitude,
                        Longitude = longitude,
                        SkorLantaiDump = skorLantaiDump,
                        SkorSafetyBerm = skorSafetyBerm,
                        SkorKondisiCrest = skorKondisiCrest,
                        SkorGradeDumping = skorGradeDumping,
                        SkorDrainaseDump = skorDrainaseDump,
                        SkorPenataanSpillage = skorPenataanSpillage,
                        SkorRambuPenerangan = skorRambuPenerangan,
                        SkorSpotterManuver = skorSpotterManuver,
                        TotalScore = totalScore,
                        KategoriIndex = kategoriIndex,
                        Catatan = catatan,
                        TindakanPerbaikan = tindakanPerbaikan,
                        Pic = pic,
                        FotoUrl = fotoUrl,
                        CreatedAt = DateTime.Now
                    };

                    _context.DciReports.Add(report);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan DCI berhasil disimpan! Skor Index: {totalScore}% ({kategoriIndex})",
                        id = report.Id,
                        data = report
                    });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal memproses laporan DCI: " + ex.Message });
            }
        }

        [HttpDelete("{id}")]
        [HttpPost("delete/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var report = await _context.DciReports.FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);
                if (report == null) return NotFound(new { status = false, message = "Laporan DCI tidak ditemukan." });

                report.IsDeleted = true;
                report.UpdatedAt = DateTime.Now;
                _context.DciReports.Update(report);
                await _context.SaveChangesAsync();

                return Ok(new { status = true, message = "Laporan DCI berhasil dihapus." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal menghapus laporan DCI: " + ex.Message });
            }
        }
    }
}
