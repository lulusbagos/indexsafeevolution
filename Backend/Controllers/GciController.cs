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
    [Route("api/gci")]
    [Route("gci")]
    [AllowAnonymous]
    public class GciController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ImageUploadService _imageUploadService;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private static bool _schemaEnsured = false;

        public GciController(AppDbContext context, ImageUploadService imageUploadService, CompanyHierarchyService companyHierarchyService)
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
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tbl_t_gci_report')
BEGIN
    CREATE TABLE [tbl_t_gci_report] (
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
        [NamaLereng] NVARCHAR(100) NULL,
        [AreaType] NVARCHAR(50) NULL DEFAULT 'Highwall',
        [Shift] NVARCHAR(20) NULL,
        [Latitude] NVARCHAR(50) NULL,
        [Longitude] NVARCHAR(50) NULL,
        [SkorGeometriLereng] INT NOT NULL DEFAULT 100,
        [SkorKondisiCrestToe] INT NOT NULL DEFAULT 100,
        [SkorTensionCrack] INT NOT NULL DEFAULT 100,
        [SkorKestabilanBatuan] INT NOT NULL DEFAULT 100,
        [SkorRembesanDrainase] INT NOT NULL DEFAULT 100,
        [SkorPemantauanSensor] INT NOT NULL DEFAULT 100,
        [SkorDemarkasiZona] INT NOT NULL DEFAULT 100,
        [SkorKepatuhanRekomendasi] INT NOT NULL DEFAULT 100,
        [TotalScore] FLOAT NOT NULL DEFAULT 100,
        [KategoriIndex] NVARCHAR(50) NOT NULL DEFAULT 'Baik',
        [TarpLevel] NVARCHAR(50) NOT NULL DEFAULT 'GREEN',
        [Catatan] NVARCHAR(2000) NULL,
        [TindakanPerbaikan] NVARCHAR(2000) NULL,
        [Pic] NVARCHAR(100) NULL,
        [PicNik] NVARCHAR(50) NULL,
        [JudulTemuan] NVARCHAR(250) NULL,
        [DueDate] DATETIME2 NULL,
        [FotoUrl] NVARCHAR(500) NULL,
        [JenisInspeksi] NVARCHAR(50) NULL DEFAULT 'Inspeksi Rutin',
        [PjaNama] NVARCHAR(100) NULL,
        [PjaNik] NVARCHAR(50) NULL,
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
            [FromQuery] string? areaType,
            [FromQuery] string? kategori,
            [FromQuery] string? tarpLevel,
            [FromQuery] DateTime? startDate,
            [FromQuery] DateTime? endDate,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var query = _context.GciReports.AsNoTracking().Where(r => !r.IsDeleted);

                int? effectiveCompanyId = companyId.HasValue && companyId.Value > 0
                    ? companyId.Value
                    : (int.TryParse(User.FindFirst("CompanyId")?.Value, out var cid) ? cid : null);
                string? effectiveCompanyName = !string.IsNullOrWhiteSpace(companyName)
                    ? companyName.Trim()
                    : User.FindFirst("Company")?.Value;

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
                    var start = startDate.Value.Date;
                    query = query.Where(r => r.Tanggal >= start);
                }
                if (endDate.HasValue)
                {
                    var end = endDate.Value.Date.AddDays(1).AddTicks(-1);
                    query = query.Where(r => r.Tanggal <= end);
                }

                if (!string.IsNullOrWhiteSpace(search))
                {
                    var s = search.Trim().ToLower();
                    query = query.Where(r =>
                        r.Nama.ToLower().Contains(s) ||
                        r.Nik.ToLower().Contains(s) ||
                        r.Lokasi.ToLower().Contains(s) ||
                        (r.NamaLereng != null && r.NamaLereng.ToLower().Contains(s)) ||
                        (r.Pit != null && r.Pit.ToLower().Contains(s)) ||
                        (r.JudulTemuan != null && r.JudulTemuan.ToLower().Contains(s)) ||
                        (r.AreaType != null && r.AreaType.ToLower().Contains(s)));
                }

                if (!string.IsNullOrWhiteSpace(pit))
                {
                    var p = pit.Trim();
                    query = query.Where(r => r.Pit == p);
                }

                if (!string.IsNullOrWhiteSpace(areaType))
                {
                    var at = areaType.Trim();
                    query = query.Where(r => r.AreaType == at);
                }

                if (!string.IsNullOrWhiteSpace(kategori))
                {
                    var kat = kategori.Trim();
                    query = query.Where(r => r.KategoriIndex == kat);
                }

                if (!string.IsNullOrWhiteSpace(tarpLevel))
                {
                    var tl = tarpLevel.Trim().ToUpper();
                    query = query.Where(r => r.TarpLevel == tl);
                }

                var totalCount = await query.CountAsync();

                var allMtdReports = await _context.GciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && r.Tanggal >= DateTime.Today.AddDays(-30))
                    .ToListAsync();

                var totalReports = allMtdReports.Count;
                var avgScore = allMtdReports.Any() ? Math.Round(allMtdReports.Average(r => r.TotalScore), 1) : 100.0;
                var goodCount = allMtdReports.Count(r => r.KategoriIndex == "Baik");
                var fairCount = allMtdReports.Count(r => r.KategoriIndex == "Sedang");
                var poorCount = allMtdReports.Count(r => r.KategoriIndex == "Kurang");

                var tarpGreenCount = allMtdReports.Count(r => r.TarpLevel == "GREEN");
                var tarpYellowCount = allMtdReports.Count(r => r.TarpLevel == "YELLOW");
                var tarpOrangeCount = allMtdReports.Count(r => r.TarpLevel == "ORANGE");
                var tarpRedCount = allMtdReports.Count(r => r.TarpLevel == "RED");

                var pitList = await _context.GciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.Pit))
                    .Select(r => r.Pit!)
                    .Distinct()
                    .OrderBy(r => r)
                    .ToListAsync();

                var areaTypeList = new List<string>
                {
                    "Highwall", "Lowwall", "Sidewall", "Bench/Jenjang",
                    "Disposal Slope", "In-Pit Dump", "Stockpile Embankment", "Sump Slope"
                };

                var items = await query
                    .OrderByDescending(r => r.Tanggal)
                    .ThenByDescending(r => r.CreatedAt)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                return Ok(new
                {
                    status = true,
                    total = totalCount,
                    page,
                    pageSize,
                    stats = new
                    {
                        totalReports,
                        avgScore,
                        goodCount,
                        fairCount,
                        poorCount,
                        tarpGreenCount,
                        tarpYellowCount,
                        tarpOrangeCount,
                        tarpRedCount
                    },
                    pitList,
                    areaTypeList,
                    data = items
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDetail(int id)
        {
            var item = await _context.GciReports.AsNoTracking().FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);
            if (item == null) return NotFound(new { status = false, message = "Laporan GCI tidak ditemukan" });
            return Ok(new { status = true, data = item });
        }

        [HttpGet("suggestions")]
        public async Task<IActionResult> GetSuggestions()
        {
            try
            {
                var pits = await _context.GciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.Pit))
                    .Select(r => r.Pit!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                var namaLerengs = await _context.GciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.NamaLereng))
                    .Select(r => r.NamaLereng!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                var areas = await _context.GciReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.Area))
                    .Select(r => r.Area)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                return Ok(new
                {
                    status = true,
                    pits,
                    namaLerengs,
                    areas
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = ex.Message });
            }
        }

        [HttpPost("save")]
        [HttpPost]
        public async Task<IActionResult> Save([FromForm] IFormCollection form, [FromForm] IFormFile? foto)
        {
            try
            {
                int.TryParse(form["id"], out int id);

                var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value?.Trim();
                if (string.IsNullOrEmpty(userNik)) userNik = form["nik"].ToString().Trim();
                if (string.IsNullOrEmpty(userNik)) userNik = "00000";

                var userName = User.Identity?.Name;
                if (string.IsNullOrEmpty(userName)) userName = form["nama"].ToString().Trim();
                if (string.IsNullOrEmpty(userName)) userName = "Anonymous";

                var userDept = User.FindFirst("Department")?.Value;
                if (string.IsNullOrEmpty(userDept)) userDept = form["departemen"].ToString().Trim();
                if (string.IsNullOrEmpty(userDept)) userDept = "Geotechnical Engineering";

                string? userComp = null;
                if (form.ContainsKey("perusahaan") && !string.IsNullOrWhiteSpace(form["perusahaan"]))
                {
                    userComp = form["perusahaan"].ToString().Trim();
                }
                else
                {
                    userComp = User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO";
                }

                int compId = 0;
                if (form.ContainsKey("perusahaan_id") && int.TryParse(form["perusahaan_id"], out var pid) && pid > 0)
                {
                    compId = pid;
                }
                else if (int.TryParse(User.FindFirst("CompanyId")?.Value, out int cid))
                {
                    compId = cid;
                }

                DateTime tanggal = DateTime.Today;
                if (DateTime.TryParse(form["tanggal"], out var dt)) tanggal = dt.Date;

                TimeSpan waktu = DateTime.Now.TimeOfDay;
                if (TimeSpan.TryParse(form["waktu"], out var ts)) waktu = ts;

                string area = form["area"].ToString().Trim();
                string lokasi = form["lokasi"].ToString().Trim();
                string? detilLokasi = form["detil_lokasi"].ToString().Trim();
                string? pit = form["pit"].ToString().Trim();
                string? namaLereng = form["nama_lereng"].ToString().Trim();
                string? areaType = form.ContainsKey("area_type") ? form["area_type"].ToString().Trim() : "Highwall";
                string? shift = form["shift"].ToString().Trim();
                string? lat = form["latitude"].ToString().Trim();
                string? lng = form["longitude"].ToString().Trim();
                string? judulTemuan = form["judul_temuan"].ToString().Trim();
                string? jenisInspeksi = form.ContainsKey("jenis_inspeksi") ? form["jenis_inspeksi"].ToString().Trim() : "Inspeksi Rutin";
                string? pjaNama = form["pja_nama"].ToString().Trim();
                string? pjaNik = form["pja_nik"].ToString().Trim();

                DateTime? dueDate = null;
                if (DateTime.TryParse(form["due_date"], out var dd)) dueDate = dd.Date;

                int.TryParse(form["skor_geometri_lereng"], out int skorGeometriLereng);
                int.TryParse(form["skor_kondisi_crest_toe"], out int skorKondisiCrestToe);
                int.TryParse(form["skor_tension_crack"], out int skorTensionCrack);
                int.TryParse(form["skor_kestabilan_batuan"], out int skorKestabilanBatuan);
                int.TryParse(form["skor_rembesan_drainase"], out int skorRembesanDrainase);
                int.TryParse(form["skor_pemantauan_sensor"], out int skorPemantauanSensor);
                int.TryParse(form["skor_demarkasi_zona"], out int skorDemarkasiZona);
                int.TryParse(form["skor_kepatuhan_rekomendasi"], out int skorKepatuhanRekomendasi);

                if (skorGeometriLereng == 0 && !form.ContainsKey("skor_geometri_lereng")) skorGeometriLereng = 100;
                if (skorKondisiCrestToe == 0 && !form.ContainsKey("skor_kondisi_crest_toe")) skorKondisiCrestToe = 100;
                if (skorTensionCrack == 0 && !form.ContainsKey("skor_tension_crack")) skorTensionCrack = 100;
                if (skorKestabilanBatuan == 0 && !form.ContainsKey("skor_kestabilan_batuan")) skorKestabilanBatuan = 100;
                if (skorRembesanDrainase == 0 && !form.ContainsKey("skor_rembesan_drainase")) skorRembesanDrainase = 100;
                if (skorPemantauanSensor == 0 && !form.ContainsKey("skor_pemantauan_sensor")) skorPemantauanSensor = 100;
                if (skorDemarkasiZona == 0 && !form.ContainsKey("skor_demarkasi_zona")) skorDemarkasiZona = 100;
                if (skorKepatuhanRekomendasi == 0 && !form.ContainsKey("skor_kepatuhan_rekomendasi")) skorKepatuhanRekomendasi = 100;

                // Bobot 8 Parameter GCI:
                // Geometri (15%), Crest/Toe (15%), Tension Crack (15%), Kestabilan Batuan (15%),
                // Rembesan (10%), Sensor (10%), Demarkasi (10%), Kepatuhan (10%)
                double totalScore = (skorGeometriLereng * 0.15) +
                                    (skorKondisiCrestToe * 0.15) +
                                    (skorTensionCrack * 0.15) +
                                    (skorKestabilanBatuan * 0.15) +
                                    (skorRembesanDrainase * 0.10) +
                                    (skorPemantauanSensor * 0.10) +
                                    (skorDemarkasiZona * 0.10) +
                                    (skorKepatuhanRekomendasi * 0.10);
                totalScore = Math.Round(totalScore, 1);

                string kategoriIndex = totalScore >= 80 ? "Baik" : (totalScore >= 65 ? "Sedang" : "Kurang");

                // Auto TARP Level
                int minParam = Math.Min(skorGeometriLereng,
                               Math.Min(skorKondisiCrestToe,
                               Math.Min(skorTensionCrack,
                               Math.Min(skorKestabilanBatuan,
                               Math.Min(skorRembesanDrainase,
                               Math.Min(skorPemantauanSensor,
                               Math.Min(skorDemarkasiZona, skorKepatuhanRekomendasi)))))));

                string tarpLevel = "GREEN";
                if (minParam <= 40 || totalScore < 50)
                {
                    tarpLevel = "RED";
                }
                else if (minParam <= 60 || totalScore < 70)
                {
                    tarpLevel = "ORANGE";
                }
                else if (minParam <= 75 || totalScore < 85)
                {
                    tarpLevel = "YELLOW";
                }

                if (form.ContainsKey("manual_tarp_level") && !string.IsNullOrWhiteSpace(form["manual_tarp_level"]))
                {
                    tarpLevel = form["manual_tarp_level"].ToString().Trim().ToUpper();
                }

                string? catatan = form["catatan"].ToString().Trim();
                string? tindakan = form["tindakan_perbaikan"].ToString().Trim();
                string? pic = form["pic"].ToString().Trim();
                string? picNik = form["pic_nik"].ToString().Trim();

                string? fotoUrl = null;
                if (foto != null && foto.Length > 0)
                {
                    fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(foto, "gci");
                }

                if (id > 0)
                {
                    var existing = await _context.GciReports.FindAsync(id);
                    if (existing == null || existing.IsDeleted)
                        return NotFound(new { status = false, message = "Laporan tidak ditemukan" });

                    existing.Tanggal = tanggal;
                    existing.Waktu = waktu;
                    existing.Area = area;
                    existing.Lokasi = lokasi;
                    existing.DetilLokasi = detilLokasi;
                    existing.Pit = pit;
                    existing.NamaLereng = namaLereng;
                    existing.AreaType = areaType;
                    existing.Shift = shift;
                    if (!string.IsNullOrEmpty(lat)) existing.Latitude = lat;
                    if (!string.IsNullOrEmpty(lng)) existing.Longitude = lng;
                    existing.Perusahaan = userComp;
                    existing.PerusahaanId = compId > 0 ? compId : existing.PerusahaanId;

                    existing.JudulTemuan = judulTemuan;
                    existing.DueDate = dueDate;
                    existing.JenisInspeksi = jenisInspeksi;
                    existing.PjaNama = pjaNama;
                    existing.PjaNik = pjaNik;

                    existing.SkorGeometriLereng = skorGeometriLereng;
                    existing.SkorKondisiCrestToe = skorKondisiCrestToe;
                    existing.SkorTensionCrack = skorTensionCrack;
                    existing.SkorKestabilanBatuan = skorKestabilanBatuan;
                    existing.SkorRembesanDrainase = skorRembesanDrainase;
                    existing.SkorPemantauanSensor = skorPemantauanSensor;
                    existing.SkorDemarkasiZona = skorDemarkasiZona;
                    existing.SkorKepatuhanRekomendasi = skorKepatuhanRekomendasi;

                    existing.TotalScore = totalScore;
                    existing.KategoriIndex = kategoriIndex;
                    existing.TarpLevel = tarpLevel;
                    existing.Catatan = catatan;
                    existing.TindakanPerbaikan = tindakan;
                    existing.Pic = pic;
                    existing.PicNik = picNik;
                    if (!string.IsNullOrEmpty(fotoUrl)) existing.FotoUrl = fotoUrl;
                    existing.UpdatedAt = DateTime.Now;

                    _context.GciReports.Update(existing);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan GCI di {pit ?? area} berhasil diperbarui!",
                        data = existing
                    });
                }
                else
                {
                    var report = new GciReport
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
                        NamaLereng = namaLereng,
                        AreaType = areaType,
                        Shift = shift,
                        Latitude = lat,
                        Longitude = lng,
                        JudulTemuan = judulTemuan,
                        DueDate = dueDate,
                        JenisInspeksi = jenisInspeksi,
                        PjaNama = pjaNama,
                        PjaNik = pjaNik,
                        SkorGeometriLereng = skorGeometriLereng,
                        SkorKondisiCrestToe = skorKondisiCrestToe,
                        SkorTensionCrack = skorTensionCrack,
                        SkorKestabilanBatuan = skorKestabilanBatuan,
                        SkorRembesanDrainase = skorRembesanDrainase,
                        SkorPemantauanSensor = skorPemantauanSensor,
                        SkorDemarkasiZona = skorDemarkasiZona,
                        SkorKepatuhanRekomendasi = skorKepatuhanRekomendasi,
                        TotalScore = totalScore,
                        KategoriIndex = kategoriIndex,
                        TarpLevel = tarpLevel,
                        Catatan = catatan,
                        TindakanPerbaikan = tindakan,
                        Pic = pic,
                        PicNik = picNik,
                        FotoUrl = fotoUrl,
                        CreatedAt = DateTime.Now
                    };

                    _context.GciReports.Add(report);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan GCI di {pit ?? area} berhasil dibuat!",
                        data = report
                    });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var report = await _context.GciReports.FindAsync(id);
                if (report == null || report.IsDeleted)
                    return NotFound(new { status = false, message = "Laporan tidak ditemukan" });

                report.IsDeleted = true;
                report.UpdatedAt = DateTime.Now;
                await _context.SaveChangesAsync();

                return Ok(new { status = true, message = "Laporan berhasil dihapus" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = false, message = ex.Message });
            }
        }
    }
}
