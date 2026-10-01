using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.DTOs;
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
    public class MasterController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly CompanyHierarchyService _companyHierarchyService;

        public MasterController(AppDbContext context, CompanyHierarchyService companyHierarchyService)
        {
            _context = context;
            _companyHierarchyService = companyHierarchyService;
        }

        private int GetCurrentCompanyId()
        {
            var compIdClaim = User.FindFirst("CompanyId")?.Value;
            return int.TryParse(compIdClaim, out var cid) ? cid : 1;
        }

        /// <summary>
        /// Master data download endpoint used by Flutter Mobile sync service:
        /// GET /api/master/{name}?limit=10000
        /// </summary>
        [AllowAnonymous]
        [HttpGet("master/{name}")]
        public async Task<IActionResult> GetMasterByName(string name, [FromQuery] int limit = 10000)
        {
            var cid = GetCurrentCompanyId();
            var accessibleCompanyIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(cid);

            var key = (name ?? string.Empty).ToLowerInvariant().Trim();

            switch (key)
            {
                case "area":
                case "areas":
                    var areas = await _context.MasterAreas
                        .AsNoTracking()
                        .Where(a => accessibleCompanyIds.Contains(a.PerusahaanId) || a.PerusahaanId == 1)
                        .OrderBy(a => a.NamaArea)
                        .Take(limit)
                        .Select(a => new
                        {
                            id = a.Id,
                            code = $"AR{a.Id:D4}",
                            name = a.NamaArea,
                            type = "area",
                            company_id = a.PerusahaanId,
                            created_at = a.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                        })
                        .ToListAsync();
                    return Ok(new { data = areas });

                case "location":
                case "locations":
                case "benchmark":
                case "benchmarks":
                    var benchmarks = await _context.Benchmarks
                        .AsNoTracking()
                        .Where(b => (b.PerusahaanId.HasValue && accessibleCompanyIds.Contains(b.PerusahaanId.Value)) || b.PerusahaanId == 1)
                        .OrderBy(b => b.NamaBenchmark)
                        .Take(limit)
                        .Select(b => new
                        {
                            id = b.Id,
                            code = $"LOC{b.Id:D4}",
                            name = b.NamaBenchmark,
                            area = b.AreaUtama,
                            type = "location",
                            company_id = b.PerusahaanId,
                            created_at = (b.CreatedAt ?? DateTime.Now).ToString("yyyy-MM-dd HH:mm:ss")
                        })
                        .ToListAsync();
                    return Ok(new { data = benchmarks });

                case "employee":
                case "employees":
                    var employees = await (from k in _context.Karyawans.AsNoTracking()
                                           join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                           join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                                           from j in jg.DefaultIfEmpty()
                                           join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                           from d in dg.DefaultIfEmpty()
                                           join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                                           from c in cg.DefaultIfEmpty()
                                           where k.StatusAktif && (accessibleCompanyIds.Contains(k.IdPerusahaan) || k.IdPerusahaan == 1)
                                           select new
                                           {
                                               id = k.IdKaryawan,
                                               no_nik = k.NoNik,
                                               nama_lengkap = p.NamaLengkap,
                                               departemen = d != null ? d.NamaDepartemen : "GENERAL",
                                               jabatan = j != null ? j.NamaJabatan : "Staff",
                                               perusahaan = c != null ? c.NamaPerusahaan : "PT INDEXIM COALINDO",
                                               company_id = k.IdPerusahaan
                                           })
                                           .Take(limit)
                                           .ToListAsync();
                    return Ok(new { data = employees });

                case "vehicle":
                case "vehicles":
                    var vehicles = await _context.P2hVehicles
                        .AsNoTracking()
                        .OrderBy(v => v.NoLambung)
                        .Take(limit)
                        .Select(v => new
                        {
                            id = v.Id,
                            code = v.NoLambung,
                            name = v.Merek ?? v.JenisKendaraan,
                            type = v.JenisKendaraan,
                            unit = v.NoLambung,
                            brand = v.Merek,
                            company = "PT JENDAR FAMILY KARYA",
                            chassis_no = "-",
                            engine_no = "-",
                            license_plate = v.NoLambung,
                            year = 2023,
                            remark = "",
                            employee_id = (int?)null,
                            created_at = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"),
                            updated_at = (string?)null,
                            deleted_at = v.IsDeleted ? DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss") : null
                        })
                        .ToListAsync();
                    return Ok(new { data = vehicles });

                case "hazard":
                    var hazardCategories = new List<object>
                    {
                        new { id = 1, code = "KTA", name = "Kondisi Tidak Aman", type = "kategori_bahaya", flag = "active", level = 1, ref_id = (int?)null },
                        new { id = 2, code = "TTA", name = "Tindakan Tidak Aman", type = "kategori_bahaya", flag = "active", level = 1, ref_id = (int?)null },
                        new { id = 3, code = "LOW", name = "Low Risk", type = "tingkat_resiko", flag = "active", level = 1, ref_id = (int?)null },
                        new { id = 4, code = "MEDIUM", name = "Medium Risk", type = "tingkat_resiko", flag = "active", level = 2, ref_id = (int?)null },
                        new { id = 5, code = "HIGH", name = "High Risk", type = "tingkat_resiko", flag = "active", level = 3, ref_id = (int?)null },
                        new { id = 6, code = "CRITICAL", name = "Critical Risk", type = "tingkat_resiko", flag = "active", level = 4, ref_id = (int?)null }
                    };
                    return Ok(new { data = hazardCategories });

                case "inspection":
                    var inspectionTypes = new List<object>
                    {
                        new { id = 1, code = "HAUL_ROAD", name = "Inspeksi Haul Road & Traffic", type = "Operasional", flag = "active", level = 1, yesno = 1, categories = "Operasional", ref_id = (int?)null },
                        new { id = 2, code = "PIT_DISPOSAL", name = "Inspeksi Pit & Disposal", type = "Operasional", flag = "active", level = 1, yesno = 1, categories = "Operasional", ref_id = (int?)null },
                        new { id = 3, code = "WORKSHOP", name = "Inspeksi Workshop & Fasilitas", type = "Sarana", flag = "active", level = 1, yesno = 1, categories = "Sarana", ref_id = (int?)null },
                        new { id = 4, code = "KAMP", name = "Inspeksi Mess / Camp Pekerja", type = "Fasilitas", flag = "active", level = 1, yesno = 1, categories = "Fasilitas", ref_id = (int?)null },
                        new { id = 5, code = "GENSET_TOWER", name = "Inspeksi Tower Lampu & Kelistrikan", type = "Utilitas", flag = "active", level = 1, yesno = 1, categories = "Utilitas", ref_id = (int?)null },
                        new { id = 6, code = "SIMAMA", name = "Inspeksi SIMAMA & K3 Lapangan", type = "K3", flag = "active", level = 1, yesno = 1, categories = "K3", ref_id = (int?)null }
                    };
                    return Ok(new { data = inspectionTypes });

                case "enum":
                    var enums = new List<object>
                    {
                        new { id = 1, code = "HAZ_KTA", name = "Kondisi Tidak Aman", type = "hazard_type", flag = "active", ref_id = (int?)null },
                        new { id = 2, code = "HAZ_TTA", name = "Tindakan Tidak Aman", type = "hazard_type", flag = "active", ref_id = (int?)null },
                        new { id = 3, code = "LV", name = "Light Vehicle", type = "vehicle_type", flag = "active", ref_id = (int?)null },
                        new { id = 4, code = "HE", name = "Heavy Equipment", type = "vehicle_type", flag = "active", ref_id = (int?)null }
                    };
                    return Ok(new { data = enums });

                case "bridges":
                    var bridges = new List<object>
                    {
                        new { id = 1, flag = "hazard", primary_id = 1, secondary_id = 1 }
                    };
                    return Ok(new { data = bridges });

                case "coaching":
                    var coaching = new List<object>
                    {
                        new { id = 1, code = "COACH_1", name = "Safety Briefing Coaching", type = "Safety", flag = "active", level = 1, ref_id = (int?)null },
                        new { id = 2, code = "COACH_2", name = "Prosedur Kerja Standar", type = "SOP", flag = "active", level = 1, ref_id = (int?)null }
                    };
                    return Ok(new { data = coaching });

                case "k3":
                    var k3 = new List<object>
                    {
                        new { id = 1, code = "APD", name = "Kelengkapan APD Wajib", type = "K3", flag = "active", level = 1, yesno = 1, ref_id = (int?)null },
                        new { id = 2, code = "SIM", name = "Mine Permit & Simper Aktif", type = "K3", flag = "active", level = 1, yesno = 1, ref_id = (int?)null }
                    };
                    return Ok(new { data = k3 });

                case "observation":
                    var obs = new List<object>
                    {
                        new { id = 1, code = "OBS_BEHAVIOR", name = "Observasi Perilaku Kerja", type = "Behavior", flag = "active", level = 1, ref_id = (int?)null },
                        new { id = 2, code = "OBS_ENV", name = "Observasi Lingkungan Kerja", type = "Environment", flag = "active", level = 1, ref_id = (int?)null }
                    };
                    return Ok(new { data = obs });

                case "p2h":
                    var p2h = new List<object>
                    {
                        new { id = 1, code = "REM", name = "Pemeriksaan Sistem Rem & Handbrake", type = "p2h_item", flag = "active", level = 1, yesno = 1, ref_id = (int?)null },
                        new { id = 2, code = "BAN", name = "Pemeriksaan Kondisi & Tekanan Ban", type = "p2h_item", flag = "active", level = 1, yesno = 1, ref_id = (int?)null },
                        new { id = 3, code = "LAMPU", name = "Lampu Utama & Rotary / Hazard", type = "p2h_item", flag = "active", level = 1, yesno = 1, ref_id = (int?)null },
                        new { id = 4, code = "SEATBELT", name = "Sabuk Pengaman (Seatbelt)", type = "p2h_item", flag = "active", level = 1, yesno = 1, ref_id = (int?)null },
                        new { id = 5, code = "KLAKSON", name = "Klakson & Alarm Mundur", type = "p2h_item", flag = "active", level = 1, yesno = 1, ref_id = (int?)null }
                    };
                    return Ok(new { data = p2h });

                case "p5m":
                    var p5m = new List<object>
                    {
                        new { id = 1, code = "P5M_PAGI", name = "P5M Shift Pagi Operasional", type = "p5m", flag = "active", level = 1, yesno = 1, ref_id = (int?)null },
                        new { id = 2, code = "P5M_MALAM", name = "P5M Shift Malam Operasional", type = "p5m", flag = "active", level = 1, yesno = 1, ref_id = (int?)null }
                    };
                    return Ok(new { data = p5m });

                case "safety":
                    var safety = new List<object>
                    {
                        new { id = 1, code = "TALK_FATIGUE", name = "Safety Talk - Pengendalian Fatigue", type = "safety_talk", flag = "active", level = 1, yesno = 1, ref_id = (int?)null },
                        new { id = 2, code = "TALK_BLINDSPOT", name = "Safety Talk - Blind Spot Alat Berat", type = "safety_talk", flag = "active", level = 1, yesno = 1, ref_id = (int?)null }
                    };
                    return Ok(new { data = safety });

                default:
                    return Ok(new { data = new List<object>() });
            }
        }

        /// <summary>
        /// GET /api/hierarchy/companies
        /// Returns company hierarchy accessible to current user.
        /// </summary>
        [HttpGet("hierarchy/companies")]
        public async Task<IActionResult> GetHierarchyCompanies()
        {
            var cid = GetCurrentCompanyId();
            var allowedIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(cid);

            var companies = await _context.Perusahaans
                .AsNoTracking()
                .Where(p => allowedIds.Contains(p.PerusahaanId) && p.StatusAktif)
                .OrderBy(p => p.NamaPerusahaan)
                .Select(p => new
                {
                    id = p.PerusahaanId,
                    kode = p.KodePerusahaan,
                    nama = p.NamaPerusahaan,
                    tipe_id = p.TipePerusahaanId,
                    induk_id = p.PerusahaanIndukId
                })
                .ToListAsync();

            return Ok(new { status = true, data = companies });
        }

        /// <summary>
        /// Search employees / PJAs across companies
        /// </summary>
        [HttpGet("master/employees")]
        public async Task<IActionResult> SearchEmployees([FromQuery] string? query, [FromQuery] bool lintasPerusahaan = true)
        {
            var cid = GetCurrentCompanyId();
            var allowedIds = lintasPerusahaan ? null : await _companyHierarchyService.GetAccessibleCompanyIdsAsync(cid);

            var cleanQuery = (query ?? string.Empty).Trim().ToLowerInvariant();

            var q = from k in _context.Karyawans.AsNoTracking()
                    join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                    join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                    from j in jg.DefaultIfEmpty()
                    join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                    from d in dg.DefaultIfEmpty()
                    join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                    from c in cg.DefaultIfEmpty()
                    where k.StatusAktif
                    select new
                    {
                        nik = k.NoNik,
                        nama = p.NamaLengkap,
                        departemen = d != null ? d.NamaDepartemen : "GENERAL",
                        jabatan = j != null ? j.NamaJabatan : "Staff",
                        perusahaan = c != null ? c.NamaPerusahaan : "PT INDEXIM COALINDO",
                        companyId = k.IdPerusahaan
                    };

            if (allowedIds != null && allowedIds.Count > 0)
            {
                q = q.Where(e => allowedIds.Contains(e.companyId));
            }

            if (!string.IsNullOrEmpty(cleanQuery))
            {
                q = q.Where(e => e.nama.ToLower().Contains(cleanQuery) ||
                                 e.nik.ToLower().Contains(cleanQuery) ||
                                 e.perusahaan.ToLower().Contains(cleanQuery));
            }

            var list = await q.Take(50).ToListAsync();
            return Ok(list);
        }

        [HttpGet("master/areas")]
        public async Task<IActionResult> GetAreas()
        {
            var cid = GetCurrentCompanyId();
            var allowedIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(cid);

            var areas = await _context.MasterAreas
                .AsNoTracking()
                .Where(a => allowedIds.Contains(a.PerusahaanId) || a.PerusahaanId == 1)
                .OrderBy(a => a.NamaArea)
                .Select(a => new { id = a.Id, namaArea = a.NamaArea })
                .ToListAsync();

            return Ok(areas);
        }

        [HttpGet("master/benchmarks")]
        public async Task<IActionResult> GetBenchmarks([FromQuery] string? areaUtama)
        {
            var cid = GetCurrentCompanyId();
            var allowedIds = await _companyHierarchyService.GetAccessibleCompanyIdsAsync(cid);

            var query = _context.Benchmarks
                .AsNoTracking()
                .Where(b => (b.PerusahaanId.HasValue && allowedIds.Contains(b.PerusahaanId.Value)) || b.PerusahaanId == 1);

            if (!string.IsNullOrWhiteSpace(areaUtama))
            {
                query = query.Where(b => b.AreaUtama == areaUtama);
            }

            var list = await query
                .OrderBy(b => b.NamaBenchmark)
                .Select(b => new { id = b.Id, namaBenchmark = b.NamaBenchmark, areaUtama = b.AreaUtama })
                .ToListAsync();

            return Ok(list);
        }
    }
}
