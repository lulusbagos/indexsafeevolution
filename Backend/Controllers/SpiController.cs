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
    [Route("api/spi")]
    [Route("spi")]
    [AllowAnonymous]
    public class SpiController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ImageUploadService _imageUploadService;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private static bool _schemaEnsured = false;

        public SpiController(AppDbContext context, ImageUploadService imageUploadService, CompanyHierarchyService companyHierarchyService)
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
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tbl_t_spi_report')
BEGIN
    CREATE TABLE [tbl_t_spi_report] (
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
        [NamaKolam] NVARCHAR(100) NULL,
        [TitikPenaatan] NVARCHAR(100) NULL,
        [Shift] NVARCHAR(20) NULL,
        [Latitude] NVARCHAR(50) NULL,
        [Longitude] NVARCHAR(50) NULL,
        [SkorKapasitasEndapan] INT NOT NULL DEFAULT 100,
        [SkorKondisiTanggul] INT NOT NULL DEFAULT 100,
        [SkorSekatBaffle] INT NOT NULL DEFAULT 100,
        [SkorPelimpahSpillway] INT NOT NULL DEFAULT 100,
        [SkorFasilitasDosing] INT NOT NULL DEFAULT 100,
        [SkorKualitasAirFisik] INT NOT NULL DEFAULT 100,
        [SkorTitikPenaatanDebit] INT NOT NULL DEFAULT 100,
        [SkorRambuPengaman] INT NOT NULL DEFAULT 100,
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
            [FromQuery] string? kolam,
            [FromQuery] string? kategori,
            [FromQuery] DateTime? startDate,
            [FromQuery] DateTime? endDate,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var query = _context.SpiReports.AsNoTracking().Where(r => !r.IsDeleted);

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
                        (r.NamaKolam != null && r.NamaKolam.ToLower().Contains(s)) ||
                        (r.TitikPenaatan != null && r.TitikPenaatan.ToLower().Contains(s)) ||
                        (r.Area != null && r.Area.ToLower().Contains(s)));
                }

                if (!string.IsNullOrWhiteSpace(kolam))
                {
                    var k = kolam.Trim();
                    query = query.Where(r => r.NamaKolam == k);
                }

                if (!string.IsNullOrWhiteSpace(kategori))
                {
                    var kat = kategori.Trim();
                    query = query.Where(r => r.KategoriIndex == kat);
                }

                var totalCount = await query.CountAsync();

                var allMtdReports = await _context.SpiReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && r.Tanggal >= DateTime.Today.AddDays(-30))
                    .ToListAsync();

                var totalReports = allMtdReports.Count;
                var avgScore = allMtdReports.Any() ? Math.Round(allMtdReports.Average(r => r.TotalScore), 1) : 100.0;
                var goodCount = allMtdReports.Count(r => r.KategoriIndex == "Baik");
                var fairCount = allMtdReports.Count(r => r.KategoriIndex == "Sedang");
                var poorCount = allMtdReports.Count(r => r.KategoriIndex == "Kurang");

                var kolamList = await _context.SpiReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.NamaKolam))
                    .Select(r => r.NamaKolam!)
                    .Distinct()
                    .OrderBy(r => r)
                    .ToListAsync();

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
                        poorCount
                    },
                    kolamList,
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
            var item = await _context.SpiReports.AsNoTracking().FirstOrDefaultAsync(r => r.Id == id && !r.IsDeleted);
            if (item == null) return NotFound(new { status = false, message = "Laporan SPI tidak ditemukan" });
            return Ok(new { status = true, data = item });
        }

        [HttpGet("suggestions")]
        public async Task<IActionResult> GetSuggestions()
        {
            try
            {
                var kolams = await _context.SpiReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.NamaKolam))
                    .Select(r => r.NamaKolam!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                var titikPenaatans = await _context.SpiReports.AsNoTracking()
                    .Where(r => !r.IsDeleted && !string.IsNullOrEmpty(r.TitikPenaatan))
                    .Select(r => r.TitikPenaatan!)
                    .Distinct()
                    .OrderBy(x => x)
                    .ToListAsync();

                return Ok(new
                {
                    status = true,
                    kolams,
                    titikPenaatans
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
                if (string.IsNullOrEmpty(userDept)) userDept = "Environment";

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
                string? namaKolam = form["nama_kolam"].ToString().Trim();
                string? titikPenaatan = form["titik_penaatan"].ToString().Trim();
                string? shift = form["shift"].ToString().Trim();
                string? lat = form["latitude"].ToString().Trim();
                string? lng = form["longitude"].ToString().Trim();

                int.TryParse(form["skor_kapasitas_endapan"], out int skorKapasitasEndapan);
                int.TryParse(form["skor_kondisi_tanggul"], out int skorKondisiTanggul);
                int.TryParse(form["skor_sekat_baffle"], out int skorSekatBaffle);
                int.TryParse(form["skor_pelimpah_spillway"], out int skorPelimpahSpillway);
                int.TryParse(form["skor_fasilitas_dosing"], out int skorFasilitasDosing);
                int.TryParse(form["skor_kualitas_air_fisik"], out int skorKualitasAirFisik);
                int.TryParse(form["skor_titik_penaatan_debit"], out int skorTitikPenaatanDebit);
                int.TryParse(form["skor_rambu_pengaman"], out int skorRambuPengaman);

                if (skorKapasitasEndapan == 0 && !form.ContainsKey("skor_kapasitas_endapan")) skorKapasitasEndapan = 100;
                if (skorKondisiTanggul == 0 && !form.ContainsKey("skor_kondisi_tanggul")) skorKondisiTanggul = 100;
                if (skorSekatBaffle == 0 && !form.ContainsKey("skor_sekat_baffle")) skorSekatBaffle = 100;
                if (skorPelimpahSpillway == 0 && !form.ContainsKey("skor_pelimpah_spillway")) skorPelimpahSpillway = 100;
                if (skorFasilitasDosing == 0 && !form.ContainsKey("skor_fasilitas_dosing")) skorFasilitasDosing = 100;
                if (skorKualitasAirFisik == 0 && !form.ContainsKey("skor_kualitas_air_fisik")) skorKualitasAirFisik = 100;
                if (skorTitikPenaatanDebit == 0 && !form.ContainsKey("skor_titik_penaatan_debit")) skorTitikPenaatanDebit = 100;
                if (skorRambuPengaman == 0 && !form.ContainsKey("skor_rambu_pengaman")) skorRambuPengaman = 100;

                // Bobot 8 Parameter SPI:
                // Endapan (15%), Tanggul (15%), Baffle (15%), Spillway (15%),
                // Dosing (10%), Kualitas Air (10%), Titik Pantau (10%), Rambu (10%)
                double totalScore = (skorKapasitasEndapan * 0.15) +
                                    (skorKondisiTanggul * 0.15) +
                                    (skorSekatBaffle * 0.15) +
                                    (skorPelimpahSpillway * 0.15) +
                                    (skorFasilitasDosing * 0.10) +
                                    (skorKualitasAirFisik * 0.10) +
                                    (skorTitikPenaatanDebit * 0.10) +
                                    (skorRambuPengaman * 0.10);
                totalScore = Math.Round(totalScore, 1);

                string kategoriIndex = totalScore >= 85 ? "Baik" : (totalScore >= 70 ? "Sedang" : "Kurang");

                string? catatan = form["catatan"].ToString().Trim();
                string? tindakan = form["tindakan_perbaikan"].ToString().Trim();
                string? pic = form["pic"].ToString().Trim();

                string? fotoUrl = null;
                if (foto != null && foto.Length > 0)
                {
                    fotoUrl = await _imageUploadService.UploadAndCompressImageAsync(foto, "spi");
                }

                if (id > 0)
                {
                    var existing = await _context.SpiReports.FindAsync(id);
                    if (existing == null || existing.IsDeleted)
                        return NotFound(new { status = false, message = "Laporan tidak ditemukan" });

                    existing.Tanggal = tanggal;
                    existing.Waktu = waktu;
                    existing.Area = area;
                    existing.Lokasi = lokasi;
                    existing.DetilLokasi = detilLokasi;
                    existing.NamaKolam = namaKolam;
                    existing.TitikPenaatan = titikPenaatan;
                    existing.Shift = shift;
                    if (!string.IsNullOrEmpty(lat)) existing.Latitude = lat;
                    if (!string.IsNullOrEmpty(lng)) existing.Longitude = lng;
                    existing.Perusahaan = userComp;
                    existing.PerusahaanId = compId > 0 ? compId : existing.PerusahaanId;

                    existing.SkorKapasitasEndapan = skorKapasitasEndapan;
                    existing.SkorKondisiTanggul = skorKondisiTanggul;
                    existing.SkorSekatBaffle = skorSekatBaffle;
                    existing.SkorPelimpahSpillway = skorPelimpahSpillway;
                    existing.SkorFasilitasDosing = skorFasilitasDosing;
                    existing.SkorKualitasAirFisik = skorKualitasAirFisik;
                    existing.SkorTitikPenaatanDebit = skorTitikPenaatanDebit;
                    existing.SkorRambuPengaman = skorRambuPengaman;

                    existing.TotalScore = totalScore;
                    existing.KategoriIndex = kategoriIndex;
                    existing.Catatan = catatan;
                    existing.TindakanPerbaikan = tindakan;
                    existing.Pic = pic;
                    if (!string.IsNullOrEmpty(fotoUrl)) existing.FotoUrl = fotoUrl;
                    existing.UpdatedAt = DateTime.Now;

                    _context.SpiReports.Update(existing);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan SPI di {namaKolam ?? lokasi} berhasil diperbarui!",
                        data = existing
                    });
                }
                else
                {
                    var report = new SpiReport
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
                        NamaKolam = namaKolam,
                        TitikPenaatan = titikPenaatan,
                        Shift = shift,
                        Latitude = lat,
                        Longitude = lng,
                        SkorKapasitasEndapan = skorKapasitasEndapan,
                        SkorKondisiTanggul = skorKondisiTanggul,
                        SkorSekatBaffle = skorSekatBaffle,
                        SkorPelimpahSpillway = skorPelimpahSpillway,
                        SkorFasilitasDosing = skorFasilitasDosing,
                        SkorKualitasAirFisik = skorKualitasAirFisik,
                        SkorTitikPenaatanDebit = skorTitikPenaatanDebit,
                        SkorRambuPengaman = skorRambuPengaman,
                        TotalScore = totalScore,
                        KategoriIndex = kategoriIndex,
                        Catatan = catatan,
                        TindakanPerbaikan = tindakan,
                        Pic = pic,
                        FotoUrl = fotoUrl,
                        CreatedAt = DateTime.Now
                    };

                    _context.SpiReports.Add(report);
                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        status = true,
                        message = $"Laporan SPI di {namaKolam ?? lokasi} berhasil dibuat!",
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
                var report = await _context.SpiReports.FindAsync(id);
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
