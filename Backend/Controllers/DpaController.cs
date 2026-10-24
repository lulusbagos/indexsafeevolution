using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/dpa")]
    [Route("dpa")]
    [AllowAnonymous]
    public class DpaController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ILogger<DpaController> _logger;
        private static bool _schemaEnsured = false;
        private static readonly object _schemaLock = new();

        public DpaController(AppDbContext context, ILogger<DpaController> logger)
        {
            _context = context;
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
                        IF OBJECT_ID('tbl_t_dpa_report', 'U') IS NULL
                        BEGIN
                            CREATE TABLE tbl_t_dpa_report (
                                Id INT IDENTITY(1,1) PRIMARY KEY,
                                AssessorNik NVARCHAR(50) NOT NULL,
                                AssessorNama NVARCHAR(150) NOT NULL,
                                AssessorDepartemen NVARCHAR(150) NULL,
                                DriverNik NVARCHAR(50) NOT NULL,
                                DriverNama NVARCHAR(150) NOT NULL,
                                DriverDepartemen NVARCHAR(150) NULL,
                                TanggalPenilaian DATETIME2 NOT NULL,
                                JenisPerjalanan NVARCHAR(100) NOT NULL,
                                Rute NVARCHAR(200) NULL,
                                NoLambung NVARCHAR(100) NULL,
                                SafetyDrivingJson NVARCHAR(MAX) NULL,
                                DrivingSkillJson NVARCHAR(MAX) NULL,
                                BehaviorJson NVARCHAR(MAX) NULL,
                                ServiceQualityJson NVARCHAR(MAX) NULL,
                                ScorePenumpang FLOAT NOT NULL DEFAULT 0,
                                ScoreGps FLOAT NOT NULL DEFAULT 0,
                                ScoreLenzguard FLOAT NOT NULL DEFAULT 0,
                                ScoreFinal FLOAT NOT NULL DEFAULT 0,
                                Kategori NVARCHAR(50) NULL,
                                Keterangan NVARCHAR(1000) NULL,
                                PerusahaanId INT NULL,
                                is_deleted BIT NOT NULL DEFAULT 0,
                                CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
                            );
                        END

                        IF OBJECT_ID('tbl_m_dpa_driver', 'U') IS NULL
                        BEGIN
                            CREATE TABLE tbl_m_dpa_driver (
                                Id INT IDENTITY(1,1) PRIMARY KEY,
                                DriverNama NVARCHAR(150) NOT NULL,
                                DriverNamaNormalized NVARCHAR(150) NOT NULL,
                                PerusahaanId INT NULL,
                                CreatedByNik NVARCHAR(50) NULL,
                                CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
                            );
                            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tbl_m_dpa_driver_DriverNamaNormalized' AND object_id = OBJECT_ID('tbl_m_dpa_driver'))
                            BEGIN
                                CREATE UNIQUE INDEX IX_tbl_m_dpa_driver_DriverNamaNormalized ON tbl_m_dpa_driver(DriverNamaNormalized);
                            END
                        END";
                    _context.Database.ExecuteSqlRaw(sql);
                    _schemaEnsured = true;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error ensuring DPA schema");
                    _schemaEnsured = true; // prevent tight loop
                }
            }
        }

        public static readonly string[] SafetyDriving = new[]
        {
            "Bagaimana kemampuan driver menjaga kecepatan yang aman selama perjalanan?",
            "Bagaimana kemampuan driver mengantisipasi kondisi jalan dan potensi bahaya?",
            "Bagaimana kemampuan driver melakukan pengereman dan akselerasi secara halus?"
        };

        public static readonly string[] DrivingSkill = new[]
        {
            "Bagaimana kemampuan driver menjaga fokus dan konsentrasi selama perjalanan?",
            "Bagaimana kemampuan driver mengendalikan kendaraan dalam berbagai kondisi jalan?"
        };

        public static readonly string[] Behavior = new[]
        {
            "Bagaimana sikap dan keramahan driver terhadap penumpang?",
            "Bagaimana kemampuan komunikasi driver selama perjalanan?"
        };

        public static readonly string[] ServiceQuality = new[]
        {
            "Bagaimana tingkat kebersihan dan kerapihan kendaraan?",
            "Bagaimana ketepatan waktu driver dalam penjemputan dan pengantaran?",
            "Bagaimana penilaian Anda terhadap performa driver secara keseluruhan?"
        };

        public class AssessmentItem
        {
            public int Id { get; set; }
            public string Question { get; set; } = string.Empty;
            public int Score { get; set; } = 5; // 1-5
            public string Label { get; set; } = "Sangat Baik";
        }

        private static string NormalizeDriverName(string input)
        {
            return string.Join(" ", input.Trim().ToUpperInvariant().Split(' ', StringSplitOptions.RemoveEmptyEntries));
        }

        private static string GetScoreLabel(int score) => score switch
        {
            5 => "Sangat Baik",
            4 => "Baik",
            3 => "Cukup",
            2 => "Kurang",
            1 => "Sangat Kurang",
            _ => "Sangat Baik"
        };

        private string ResolveNik(string? nik)
        {
            if (!string.IsNullOrWhiteSpace(nik)) return nik.Trim();
            return User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                ?? User.Identity?.Name 
                ?? "";
        }

        [HttpGet("questions")]
        public IActionResult GetQuestions()
        {
            var safety = SafetyDriving.Select((q, i) => new { id = i + 1, question = q, defaultScore = 5 }).ToList();
            var skill = DrivingSkill.Select((q, i) => new { id = i + 1, question = q, defaultScore = 5 }).ToList();
            var behavior = Behavior.Select((q, i) => new { id = i + 1, question = q, defaultScore = 5 }).ToList();
            var service = ServiceQuality.Select((q, i) => new { id = i + 1, question = q, defaultScore = 5 }).ToList();

            var sections = new object[]
            {
                new
                {
                    number = 1,
                    title = "Safety & Skill Driving",
                    totalQuestions = safety.Count + skill.Count,
                    safety = safety,
                    skill = skill
                },
                new
                {
                    number = 2,
                    title = "Behavior & Servis",
                    totalQuestions = behavior.Count + service.Count,
                    behavior = behavior,
                    service = service
                }
            };

            return Ok(new
            {
                totalQuestions = 10,
                scale = new[]
                {
                    new { score = 5, label = "Sangat Baik" },
                    new { score = 4, label = "Baik" },
                    new { score = 3, label = "Cukup" },
                    new { score = 2, label = "Kurang" },
                    new { score = 1, label = "Sangat Kurang" }
                },
                sections = sections
            });
        }

        [HttpGet]
        public async Task<IActionResult> GetList(
            [FromQuery] string? nik = null, 
            [FromQuery] string? search = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var targetNik = ResolveNik(nik);
                var query = _context.DpaReports.AsNoTracking().Where(r => !r.IsDeleted);

                if (!string.IsNullOrEmpty(targetNik) && !string.Equals(targetNik, "all", StringComparison.OrdinalIgnoreCase))
                {
                    query = query.Where(r => r.AssessorNik == targetNik);
                }

                if (!string.IsNullOrWhiteSpace(search))
                {
                    var q = search.Trim().ToLower();
                    query = query.Where(r => 
                        r.DriverNama.ToLower().Contains(q) || 
                        r.DriverNik.ToLower().Contains(q) ||
                        (r.Rute != null && r.Rute.ToLower().Contains(q)) ||
                        (r.NoLambung != null && r.NoLambung.ToLower().Contains(q)) ||
                        r.JenisPerjalanan.ToLower().Contains(q) ||
                        (r.Keterangan != null && r.Keterangan.ToLower().Contains(q)));
                }

                var totalCount = await query.CountAsync();

                var list = await query
                    .OrderByDescending(r => r.TanggalPenilaian)
                    .ThenByDescending(r => r.CreatedAt)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                static double ParseAvg(string? json)
                {
                    if (string.IsNullOrWhiteSpace(json)) return 5.0;
                    try
                    {
                        using var doc = JsonDocument.Parse(json);
                        if (doc.RootElement.ValueKind == JsonValueKind.Array)
                        {
                            double total = 0;
                            int cnt = 0;
                            foreach (var el in doc.RootElement.EnumerateArray())
                            {
                                if (el.TryGetProperty("score", out var sProp) && sProp.TryGetDouble(out var s))
                                {
                                    total += s;
                                    cnt++;
                                }
                            }
                            if (cnt > 0) return Math.Round(total / cnt, 1);
                        }
                    }
                    catch { }
                    return 5.0;
                }

                var result = list.Select(r => new
                {
                    id = r.Id,
                    assessorNik = r.AssessorNik,
                    assessorNama = r.AssessorNama,
                    assessorDepartemen = r.AssessorDepartemen,
                    driverNik = r.DriverNik,
                    driverNama = r.DriverNama,
                    driverDepartemen = r.DriverDepartemen,
                    tanggalPenilaian = r.TanggalPenilaian.ToString("yyyy-MM-dd"),
                    tanggalPenilaianFormatted = r.TanggalPenilaian.ToString("dd MMM yyyy"),
                    createdAt = r.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss"),
                    jenisPerjalanan = r.JenisPerjalanan,
                    rute = r.Rute ?? "-",
                    noLambung = r.NoLambung ?? "-",
                    scorePenumpang = r.ScorePenumpang,
                    scoreGps = r.ScoreGps,
                    scoreLenzguard = r.ScoreLenzguard,
                    scoreFinal = r.ScoreFinal,
                    safetyAvg = ParseAvg(r.SafetyDrivingJson),
                    skillAvg = ParseAvg(r.DrivingSkillJson),
                    behaviorAvg = ParseAvg(r.BehaviorJson),
                    serviceAvg = ParseAvg(r.ServiceQualityJson),
                    kategori = r.Kategori ?? "-",
                    keterangan = r.Keterangan,
                    perusahaanId = r.PerusahaanId
                }).ToList();

                return Ok(new
                {
                    success = true,
                    total = totalCount,
                    page = page,
                    pageSize = pageSize,
                    data = result
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting DPA list");
                return StatusCode(500, new { success = false, message = "Gagal memuat histori penilaian DPA: " + ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDetail(int id)
        {
            try
            {
                var report = await _context.DpaReports.FindAsync(id);
                if (report == null || report.IsDeleted)
                {
                    return NotFound(new { success = false, message = "Data penilaian driver tidak ditemukan." });
                }

                var safety = string.IsNullOrEmpty(report.SafetyDrivingJson) 
                    ? new List<AssessmentItem>() 
                    : JsonSerializer.Deserialize<List<AssessmentItem>>(report.SafetyDrivingJson) ?? new List<AssessmentItem>();
                var skill = string.IsNullOrEmpty(report.DrivingSkillJson) 
                    ? new List<AssessmentItem>() 
                    : JsonSerializer.Deserialize<List<AssessmentItem>>(report.DrivingSkillJson) ?? new List<AssessmentItem>();
                var behavior = string.IsNullOrEmpty(report.BehaviorJson) 
                    ? new List<AssessmentItem>() 
                    : JsonSerializer.Deserialize<List<AssessmentItem>>(report.BehaviorJson) ?? new List<AssessmentItem>();
                var service = string.IsNullOrEmpty(report.ServiceQualityJson) 
                    ? new List<AssessmentItem>() 
                    : JsonSerializer.Deserialize<List<AssessmentItem>>(report.ServiceQualityJson) ?? new List<AssessmentItem>();

                return Ok(new
                {
                    success = true,
                    data = new
                    {
                        id = report.Id,
                        assessorNik = report.AssessorNik,
                        assessorNama = report.AssessorNama,
                        assessorDepartemen = report.AssessorDepartemen,
                        driverNik = report.DriverNik,
                        driverNama = report.DriverNama,
                        driverDepartemen = report.DriverDepartemen,
                        tanggalPenilaian = report.TanggalPenilaian.ToString("yyyy-MM-dd"),
                        tanggalPenilaianFormatted = report.TanggalPenilaian.ToString("dd MMM yyyy"),
                        jenisPerjalanan = report.JenisPerjalanan,
                        rute = report.Rute,
                        noLambung = report.NoLambung,
                        keterangan = report.Keterangan,
                        scorePenumpang = report.ScorePenumpang,
                        scoreGps = report.ScoreGps,
                        scoreLenzguard = report.ScoreLenzguard,
                        scoreFinal = report.ScoreFinal,
                        kategori = report.Kategori,
                        perusahaanId = report.PerusahaanId,
                        createdAt = report.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss"),
                        safety = safety,
                        skill = skill,
                        behavior = behavior,
                        service = service
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting DPA detail {Id}", id);
                return StatusCode(500, new { success = false, message = "Gagal memuat rincian DPA: " + ex.Message });
            }
        }

        [HttpGet("search-driver")]
        public async Task<IActionResult> SearchDriver([FromQuery] string query)
        {
            try
            {
                if (string.IsNullOrEmpty(query) || query.Length < 2)
                    return Ok(new List<object>());

                var q = query.Trim().ToLower();

                var sapResults = await (from k in _context.Karyawans.AsNoTracking()
                                        join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                        join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                        from dept in dg.DefaultIfEmpty()
                                        where k.IdPerusahaan == 1 &&
                                              k.StatusAktif == true &&
                                              (k.NoNik.ToLower().Contains(q) ||
                                               p.NamaLengkap.ToLower().Contains(q))
                                        select new
                                        {
                                            nik = k.NoNik,
                                            nama = p.NamaLengkap,
                                            departemen = dept != null ? dept.NamaDepartemen : "General"
                                        })
                                       .Take(15)
                                       .ToListAsync();

                var manualResults = await _context.DpaDrivers.AsNoTracking()
                    .Where(d => (d.PerusahaanId == null || d.PerusahaanId == 1) && d.DriverNamaNormalized.ToLower().Contains(q))
                    .Select(d => new
                    {
                        nik = "MANUAL",
                        nama = d.DriverNama,
                        departemen = "MASTER DRIVER"
                    })
                    .Take(15)
                    .ToListAsync();

                var combined = sapResults
                    .Concat(manualResults)
                    .GroupBy(x => NormalizeDriverName(x.nama))
                    .Select(g => g.OrderBy(x => x.nik == "MANUAL" ? 1 : 0).First())
                    .Take(15)
                    .ToList();

                return Ok(combined);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error searching driver for DPA");
                return StatusCode(500, new { success = false, message = "Gagal mencari driver: " + ex.Message });
            }
        }

        public class AddDriverDto
        {
            public string DriverNama { get; set; } = string.Empty;
            public string? CreatedByNik { get; set; }
        }

        [HttpPost("add-driver")]
        public async Task<IActionResult> AddDriver([FromBody] AddDriverDto req)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(req.DriverNama))
                {
                    return BadRequest(new { success = false, message = "Nama driver wajib diisi." });
                }

                var normalizedName = NormalizeDriverName(req.DriverNama);
                if (normalizedName.Length < 2)
                {
                    return BadRequest(new { success = false, message = "Nama driver minimal 2 karakter." });
                }

                var exists = await _context.DpaDrivers.AnyAsync(d =>
                    d.DriverNamaNormalized == normalizedName &&
                    (d.PerusahaanId == null || d.PerusahaanId == 1));

                if (exists)
                {
                    return Ok(new
                    {
                        success = true,
                        message = "Driver sudah terdaftar di master.",
                        data = new
                        {
                            nik = "MANUAL",
                            nama = normalizedName,
                            departemen = "MASTER DRIVER"
                        }
                    });
                }

                var userNik = ResolveNik(req.CreatedByNik);

                var newDriver = new DpaDriver
                {
                    DriverNama = normalizedName,
                    DriverNamaNormalized = normalizedName,
                    PerusahaanId = 1,
                    CreatedByNik = userNik,
                    CreatedAt = DateTime.Now
                };

                _context.DpaDrivers.Add(newDriver);
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    success = true,
                    message = "Driver berhasil ditambahkan ke master.",
                    data = new
                    {
                        nik = "MANUAL",
                        nama = newDriver.DriverNama,
                        departemen = "MASTER DRIVER"
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error adding manual driver");
                return StatusCode(500, new { success = false, message = "Gagal menambahkan driver: " + ex.Message });
            }
        }

        public class QuestionScoreInput
        {
            public int Id { get; set; }
            public string? Question { get; set; }
            public int Score { get; set; } = 5;
            public string? Label { get; set; }
        }

        public class DpaFormRequest
        {
            public int? Id { get; set; }
            public string? AssessorNik { get; set; }
            public string? AssessorNama { get; set; }
            public string? AssessorDepartemen { get; set; }
            public string DriverNik { get; set; } = string.Empty;
            public string DriverNama { get; set; } = string.Empty;
            public string? DriverDepartemen { get; set; }
            public DateTime TanggalPenilaian { get; set; } = DateTime.Today;
            public string JenisPerjalanan { get; set; } = "Perjalanan Dinas";
            public string? Rute { get; set; }
            public string? NoLambung { get; set; }
            public string? Keterangan { get; set; }
            public List<QuestionScoreInput>? SafetyScores { get; set; }
            public List<QuestionScoreInput>? SkillScores { get; set; }
            public List<QuestionScoreInput>? BehaviorScores { get; set; }
            public List<QuestionScoreInput>? ServiceScores { get; set; }
        }

        [HttpPost]
        public async Task<IActionResult> Save([FromBody] DpaFormRequest req)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(req.DriverNik) || string.IsNullOrWhiteSpace(req.DriverNama))
                {
                    return BadRequest(new { success = false, message = "Data driver (NIK dan Nama) wajib diisi." });
                }

                if (string.IsNullOrWhiteSpace(req.JenisPerjalanan))
                {
                    return BadRequest(new { success = false, message = "Jenis perjalanan wajib dipilih." });
                }

                var userNik = ResolveNik(req.AssessorNik);
                var userName = !string.IsNullOrWhiteSpace(req.AssessorNama) ? req.AssessorNama.Trim() : userNik;
                var userDept = req.AssessorDepartemen ?? "General";

                DpaReport? report;
                bool isNew = true;

                if (req.Id.HasValue && req.Id.Value > 0)
                {
                    report = await _context.DpaReports.FindAsync(req.Id.Value);
                    if (report == null || report.IsDeleted)
                    {
                        return NotFound(new { success = false, message = "Penilaian driver tidak ditemukan." });
                    }
                    isNew = false;
                }
                else
                {
                    report = new DpaReport
                    {
                        AssessorNik = userNik,
                        AssessorNama = userName,
                        AssessorDepartemen = userDept,
                        PerusahaanId = 1,
                        CreatedAt = DateTime.Now
                    };
                }

                if (isNew && req.TanggalPenilaian.Date < DateTime.Today)
                {
                    return BadRequest(new { success = false, message = "Tanggal Penilaian DPA tidak boleh backdate (kurang dari hari ini)." });
                }

                report.DriverNik = req.DriverNik.Trim();
                report.DriverNama = NormalizeDriverName(req.DriverNama);
                report.DriverDepartemen = req.DriverDepartemen?.Trim();
                report.TanggalPenilaian = req.TanggalPenilaian.Date;
                report.JenisPerjalanan = req.JenisPerjalanan.Trim();
                report.Rute = req.Rute?.Trim();
                report.NoLambung = req.NoLambung?.Trim().ToUpperInvariant();
                report.Keterangan = req.Keterangan?.Trim();

                // If MANUAL driver, ensure saved in DpaDrivers
                if (report.DriverNik.Equals("MANUAL", StringComparison.OrdinalIgnoreCase))
                {
                    var normalizedName = NormalizeDriverName(report.DriverNama);
                    var manualExists = await _context.DpaDrivers.AnyAsync(d =>
                        d.DriverNamaNormalized == normalizedName &&
                        (d.PerusahaanId == null || d.PerusahaanId == 1));

                    if (!manualExists)
                    {
                        _context.DpaDrivers.Add(new DpaDriver
                        {
                            DriverNama = normalizedName,
                            DriverNamaNormalized = normalizedName,
                            PerusahaanId = 1,
                            CreatedByNik = userNik,
                            CreatedAt = DateTime.Now
                        });
                    }
                }

                // Process questions
                var safetyList = BuildCategoryList(req.SafetyScores, SafetyDriving);
                var skillList = BuildCategoryList(req.SkillScores, DrivingSkill);
                var behaviorList = BuildCategoryList(req.BehaviorScores, Behavior);
                var serviceList = BuildCategoryList(req.ServiceScores, ServiceQuality);

                report.SafetyDrivingJson = JsonSerializer.Serialize(safetyList);
                report.DrivingSkillJson = JsonSerializer.Serialize(skillList);
                report.BehaviorJson = JsonSerializer.Serialize(behaviorList);
                report.ServiceQualityJson = JsonSerializer.Serialize(serviceList);

                // Passenger score calculation
                var allScores = safetyList.Concat(skillList).Concat(behaviorList).Concat(serviceList).ToList();
                double avgScore = allScores.Count > 0 ? allScores.Average(x => x.Score) : 5.0;
                report.ScorePenumpang = Math.Round((avgScore / 5.0) * 100, 1);

                if (report.ScoreGps > 0 || report.ScoreLenzguard > 0)
                {
                    report.ScoreFinal = Math.Round(
                        (report.ScorePenumpang * 0.4) +
                        (report.ScoreGps * 0.3) +
                        (report.ScoreLenzguard * 0.3), 1);
                }
                else
                {
                    report.ScoreFinal = report.ScorePenumpang;
                }

                report.Kategori = report.ScoreFinal switch
                {
                    >= 90 => "Excellent Driver",
                    >= 80 => "Good Driver",
                    >= 70 => "Satisfactory Driver",
                    >= 60 => "Need Improvement",
                    _ => "Corrective Action Required"
                };

                if (isNew)
                    _context.DpaReports.Add(report);
                else
                    _context.DpaReports.Update(report);

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    success = true,
                    message = isNew ? "Penilaian Driver berhasil dikirim!" : "Penilaian Driver berhasil diperbarui!",
                    id = report.Id,
                    scoreFinal = report.ScoreFinal,
                    kategori = report.Kategori
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving DPA report");
                return StatusCode(500, new { success = false, message = "Gagal menyimpan penilaian driver: " + ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var report = await _context.DpaReports.FindAsync(id);
                if (report == null || report.IsDeleted)
                {
                    return NotFound(new { success = false, message = "Data penilaian driver tidak ditemukan." });
                }

                report.IsDeleted = true;
                _context.DpaReports.Update(report);
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    success = true,
                    message = "Penilaian driver berhasil dihapus."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting DPA report {Id}", id);
                return StatusCode(500, new { success = false, message = "Gagal menghapus penilaian: " + ex.Message });
            }
        }

        private List<AssessmentItem> BuildCategoryList(List<QuestionScoreInput>? inputs, string[] defaultQuestions)
        {
            var list = new List<AssessmentItem>();
            for (int i = 0; i < defaultQuestions.Length; i++)
            {
                int score = 5;
                if (inputs != null && i < inputs.Count && inputs[i].Score >= 1 && inputs[i].Score <= 5)
                {
                    score = inputs[i].Score;
                }

                list.Add(new AssessmentItem
                {
                    Id = i + 1,
                    Question = defaultQuestions[i],
                    Score = score,
                    Label = GetScoreLabel(score)
                });
            }
            return list;
        }
    }
}
