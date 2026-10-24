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
    [Route("api/fci")]
    [Route("fci")]
    [AllowAnonymous]
    public class FciController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ImageUploadService _imageUploadService;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private static bool _schemaEnsured = false;

        public FciController(AppDbContext context, ImageUploadService imageUploadService, CompanyHierarchyService companyHierarchyService)
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
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tbl_t_fci_report')
BEGIN
    CREATE TABLE [tbl_t_fci_report] (
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
        [Pit] NVARCHAR(100) NULL,
        [NamaFront] NVARCHAR(100) NULL,
        [Shift] NVARCHAR(20) NULL,
        [Latitude] NVARCHAR(50) NULL,
        [Longitude] NVARCHAR(50) NULL,
        [SkorLantaiFront] INT NOT NULL DEFAULT 100,
        [SkorRuangManuver] INT NOT NULL DEFAULT 100,
        [SkorSafetyBerm] INT NOT NULL DEFAULT 100,
        [SkorKondisiDinding] INT NOT NULL DEFAULT 100,
        [SkorDrainaseSump] INT NOT NULL DEFAULT 100,
        [SkorKebersihanSpillage] INT NOT NULL DEFAULT 100,
        [SkorPosisiAlat] INT NOT NULL DEFAULT 100,
        [SkorRambuPenerangan] INT NOT NULL DEFAULT 100,
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
            [FromQuery] string? pit,
            [FromQuery] string? kategori,
            [FromQuery] DateTime? startDate,
            [FromQuery] DateTime? endDate,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var query = _context.FciReports.AsNoTracking().Where(r => !r.IsDeleted);

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
                // User requirement: "history FCI adalah history yang saya buat kecuali saya dijadikan pic"
                // Dan "Semua Front" (scope == "all"): tampilkan inspeksi perusahaan yang sama dengan login
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
                        // Default "my_history": laporan yang saya buat ATAU saya ditunjuk sebagai PIC
                        query = query.Where(r => r.Nik == cleanNik || (r.Pic != null && (r.Pic.Contains(cleanNik) || (cleanNama != "" && r.Pic.ToLower().Contains(cleanNama)))));
                    }
                }
                else if (scope == "all")
                {
                    // Pastikan bagian semua front HANYA tampilkan inspeksi perusahaan yang sama persis dengan login
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
                                             (r.NamaFront != null && r.NamaFront.ToLower().Contains(s)) ||
                                             (r.Pit != null && r.Pit.ToLower().Contains(s)) ||
                                             (r.Pic != null && r.Pic.ToLower().Contains(s)));
                }

                if (!string.IsNullOrWhiteSpace(pit))
                {
                    query = query.Where(r => r.Pit == pit);
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
                var statsQuery = _context.FciReports.AsNoTracking().Where(r => !r.IsDeleted && r.Tanggal >= thirtyDaysAgo);
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

                // Distinct pits
                var pitList = await statsQuery
                    .Where(r => !string.IsNullOrEmpty(r.Pit))
                    .Select(r => r.Pit!)
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
                        goodCount,
                        fairCount,
                        poorCount
                    },
                    pits = pitList
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal mengambil data FCI: " + ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDetail(int id)
        {
            var item = await _context.FciReports.AsNoTracking().FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);
            if (item == null) return NotFound(new { status = false, message = "Laporan FCI tidak ditemukan." });

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
                int.TryParse(User.FindFirst("CompanyId")?.Value ?? form["perusahaan_id"].FirstOrDefault() ?? form["perusahaanId"].FirstOrDefault(), out int compId);

                int? id = int.TryParse(form["id"].FirstOrDefault(), out var parsedId) && parsedId > 0 ? parsedId : null;
                var isNew = !id.HasValue || id.Value <= 0;

                // Parse Date & Anti-Backdate Validation
                var tanggal = DateTime.TryParse(form["tanggal"].FirstOrDefault() ?? form["date"].FirstOrDefault(), out var tgl)
                    ? tgl.Date
                    : DateTime.Today;

                if (isNew && tanggal < DateTime.Today)
                {
                    return BadRequest(new { status = false, message = "Tanggal inspeksi FCI tidak boleh backdate (kurang dari hari ini)." });
                }

                var waktuStr = form["waktu"].FirstOrDefault() ?? form["time"].FirstOrDefault() ?? DateTime.Now.ToString(@"hh\:mm");
                var waktu = TimeSpan.TryParse(waktuStr, out var ts) ? ts : DateTime.Now.TimeOfDay;

                var area = form["area"].FirstOrDefault() ?? "Pit Area";
                var lokasi = form["lokasi"].FirstOrDefault() ?? area;
                var detilLokasi = form["detil_lokasi"].FirstOrDefault() ?? form["detilLokasi"].FirstOrDefault();
                var pit = form["pit"].FirstOrDefault() ?? "Pit 1";
                var namaFront = form["nama_front"].FirstOrDefault() ?? form["namaFront"].FirstOrDefault() ?? "Front Loading";
                var shift = form["shift"].FirstOrDefault() ?? "Shift 1 (Siang)";
                var latitude = form["latitude"].FirstOrDefault() ?? form["lat"].FirstOrDefault();
                var longitude = form["longitude"].FirstOrDefault() ?? form["lng"].FirstOrDefault() ?? form["long"].FirstOrDefault();

                // Parameter scores (default 100)
                int skorLantaiFront = int.TryParse(form["skor_lantai_front"].FirstOrDefault() ?? form["skorLantaiFront"].FirstOrDefault(), out var s1) ? s1 : 100;
                int skorRuangManuver = int.TryParse(form["skor_ruang_manuver"].FirstOrDefault() ?? form["skorRuangManuver"].FirstOrDefault(), out var s2) ? s2 : 100;
                int skorSafetyBerm = int.TryParse(form["skor_safety_berm"].FirstOrDefault() ?? form["skorSafetyBerm"].FirstOrDefault(), out var s3) ? s3 : 100;
                int skorKondisiDinding = int.TryParse(form["skor_kondisi_dinding"].FirstOrDefault() ?? form["skorKondisiDinding"].FirstOrDefault(), out var s4) ? s4 : 100;
                int skorDrainaseSump = int.TryParse(form["skor_drainase_sump"].FirstOrDefault() ?? form["skorDrainaseSump"].FirstOrDefault(), out var s5) ? s5 : 100;
                int skorKebersihanSpillage = int.TryParse(form["skor_kebersihan_spillage"].FirstOrDefault() ?? form["skorKebersihanSpillage"].FirstOrDefault(), out var s6) ? s6 : 100;
                int skorPosisiAlat = int.TryParse(form["skor_posisi_alat"].FirstOrDefault() ?? form["skorPosisiAlat"].FirstOrDefault(), out var s7) ? s7 : 100;
                int skorRambuPenerangan = int.TryParse(form["skor_rambu_penerangan"].FirstOrDefault() ?? form["skorRambuPenerangan"].FirstOrDefault(), out var s8) ? s8 : 100;

                var catatan = form["catatan"].FirstOrDefault() ?? form["notes"].FirstOrDefault();
                var tindakanPerbaikan = form["tindakan_perbaikan"].FirstOrDefault() ?? form["tindakanPerbaikan"].FirstOrDefault() ?? form["action"].FirstOrDefault();
                var pic = form["pic"].FirstOrDefault();

                // Weighted calculation:
                // Lantai Front (15%), Ruang Manuver (15%), Safety Berm (15%), Kondisi Dinding (15%),
                // Drainase Sump (10%), Kebersihan Spillage (10%), Posisi Alat (10%), Rambu Penerangan (10%)
                double totalScore = (skorLantaiFront * 0.15) +
                                    (skorRuangManuver * 0.15) +
                                    (skorSafetyBerm * 0.15) +
                                    (skorKondisiDinding * 0.15) +
                                    (skorDrainaseSump * 0.10) +
                                    (skorKebersihanSpillage * 0.10) +
                                    (skorPosisiAlat * 0.10) +
                                    (skorRambuPenerangan * 0.10);
                totalScore = Math.Round(totalScore, 1);
                string kategoriIndex = totalScore >= 85 ? "Baik" : (totalScore >= 70 ? "Sedang" : "Kurang");

                // Handle Photo Upload
                var imageFile = form.Files["foto"] ?? form.Files["image"] ?? form.Files["foto_url"];
                string? fotoUrl = null;
                if (imageFile != null && imageFile.Length > 0)
                {
                    fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(imageFile, "fci", "fci");
                }

                FciReport report;
                if (!isNew)
                {
                    report = await _context.FciReports.FindAsync(id!.Value) ?? throw new KeyNotFoundException();
                    if (report.IsDeleted) return NotFound(new { status = false, message = "Data telah dihapus." });

                    report.Tanggal = tanggal;
                    report.Waktu = waktu;
                    report.Area = area;
                    report.Lokasi = lokasi;
                    report.DetilLokasi = detilLokasi;
                    report.Pit = pit;
                    report.NamaFront = namaFront;
                    report.Shift = shift;
                    report.Latitude = latitude;
                    report.Longitude = longitude;
                    report.SkorLantaiFront = skorLantaiFront;
                    report.SkorRuangManuver = skorRuangManuver;
                    report.SkorSafetyBerm = skorSafetyBerm;
                    report.SkorKondisiDinding = skorKondisiDinding;
                    report.SkorDrainaseSump = skorDrainaseSump;
                    report.SkorKebersihanSpillage = skorKebersihanSpillage;
                    report.SkorPosisiAlat = skorPosisiAlat;
                    report.SkorRambuPenerangan = skorRambuPenerangan;
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

                    _context.FciReports.Update(report);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan FCI di {namaFront} berhasil diperbarui! Skor Index: {totalScore}% ({kategoriIndex})",
                        data = report
                    });
                }
                else
                {
                    report = new FciReport
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
                        Pit = pit,
                        NamaFront = namaFront,
                        Shift = shift,
                        Latitude = latitude,
                        Longitude = longitude,
                        SkorLantaiFront = skorLantaiFront,
                        SkorRuangManuver = skorRuangManuver,
                        SkorSafetyBerm = skorSafetyBerm,
                        SkorKondisiDinding = skorKondisiDinding,
                        SkorDrainaseSump = skorDrainaseSump,
                        SkorKebersihanSpillage = skorKebersihanSpillage,
                        SkorPosisiAlat = skorPosisiAlat,
                        SkorRambuPenerangan = skorRambuPenerangan,
                        TotalScore = totalScore,
                        KategoriIndex = kategoriIndex,
                        Catatan = catatan,
                        TindakanPerbaikan = tindakanPerbaikan,
                        Pic = pic,
                        FotoUrl = fotoUrl,
                        CreatedAt = DateTime.Now
                    };

                    _context.FciReports.Add(report);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Inspeksi FCI berhasil disimpan! Skor Index: {totalScore}% ({kategoriIndex})",
                        data = report
                    });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = "Gagal menyimpan laporan FCI: " + ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var item = await _context.FciReports.FindAsync(id);
            if (item == null || item.IsDeleted) return NotFound(new { status = false, message = "Laporan FCI tidak ditemukan." });

            item.IsDeleted = true;
            item.UpdatedAt = DateTime.Now;
            _context.FciReports.Update(item);
            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Laporan FCI berhasil dihapus."
            });
        }
    }
}
