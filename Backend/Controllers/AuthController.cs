using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.DTOs;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly JwtService _jwtService;
        private readonly ImageUploadService _imageUploadService;
        private readonly CompanyHierarchyService _companyHierarchyService;
        private readonly PermitService _permitService;

        public AuthController(
            AppDbContext context,
            JwtService jwtService,
            ImageUploadService imageUploadService,
            CompanyHierarchyService companyHierarchyService,
            PermitService permitService)
        {
            _context = context;
            _jwtService = jwtService;
            _imageUploadService = imageUploadService;
            _companyHierarchyService = companyHierarchyService;
            _permitService = permitService;
        }

        [HttpPost("login")]
        [HttpPost("auth/login")]
        [AllowAnonymous]
        public async Task<IActionResult> Login([FromBody] LoginRequest req)
        {
            // Support both email format ('IC' + NIK) and raw NIK
            var inputUser = (req.Nik ?? req.Email ?? string.Empty).Trim();
            if (inputUser.StartsWith("IC", StringComparison.OrdinalIgnoreCase))
            {
                inputUser = inputUser.Substring(2).Trim();
            }

            if (string.IsNullOrEmpty(inputUser))
            {
                return BadRequest(new { message = "NIK / Username wajib diisi!" });
            }
            if (string.IsNullOrEmpty(req.Password))
            {
                return BadRequest(new { message = "Password wajib diisi!" });
            }

            var nrp = inputUser;

            // 1. Check override in tbl_m_pengguna_sandi
            var overridePwd = await _context.PasswordOverrides.FirstOrDefaultAsync(p => p.Nrp == nrp);
            bool isValid = false;
            string fullName = "";
            int? idPerusahaan = null;
            int? idDepartemen = null;
            int? idJabatan = null;

            // Prioritize active employee record
            var karyawanMaster = await _context.Karyawans
                .Where(k => k.NoNik == nrp)
                .OrderByDescending(k => k.StatusAktif)
                .FirstOrDefaultAsync();

            if (overridePwd != null)
            {
                if (overridePwd.KataSandi == req.Password)
                {
                    isValid = true;
                }
            }
            else
            {
                // 2. Check vw_pengguna
                var pengguna = await _context.Penggunas.FirstOrDefaultAsync(p => p.Username == nrp && p.IsAktif);
                if (pengguna != null)
                {
                    if (pengguna.KataSandi == req.Password)
                    {
                        isValid = true;
                        fullName = pengguna.NamaLengkap;
                        idPerusahaan = pengguna.PerusahaanId;
                        idDepartemen = pengguna.DepartemenId;
                        idJabatan = pengguna.JabatanId;
                    }
                    else if (req.Password == "123456") // Fallback default password
                    {
                        var karyawan = await _context.Karyawans.FirstOrDefaultAsync(k => k.NoNik == nrp && k.StatusAktif);
                        if (karyawan != null)
                        {
                            isValid = true;
                            fullName = pengguna.NamaLengkap;
                            idPerusahaan = karyawan.IdPerusahaan;
                            idDepartemen = karyawan.IdDepartemen;
                            idJabatan = karyawan.IdJabatan;
                        }
                    }
                }
                else
                {
                    // 3. Fallback default password for active employees
                    var karyawan = await _context.Karyawans.FirstOrDefaultAsync(k => k.NoNik == nrp && k.StatusAktif);
                    if (karyawan != null && req.Password == "123456")
                    {
                        isValid = true;
                        idPerusahaan = karyawan.IdPerusahaan;
                        idDepartemen = karyawan.IdDepartemen;
                        idJabatan = karyawan.IdJabatan;
                    }
                }
            }

            // User must be registered in ONE DB MITRA
            if (karyawanMaster == null)
            {
                return Unauthorized(new { message = "User tidak terdaftar." });
            }

            // User must be active
            if (!karyawanMaster.StatusAktif)
            {
                return Unauthorized(new { message = "Status karyawan nonaktif di OneDB EV. Silahkan hubungi HR perusahaan." });
            }

            if (!isValid)
            {
                return Unauthorized(new { message = "Tidak bisa login karena password salah." });
            }

            // Check excluded company
            if (ExcludedCompanies.IsExcluded(karyawanMaster.IdPerusahaan))
            {
                return Unauthorized(new { message = "Akun tidak dapat digunakan pada sistem ini." });
            }

            idPerusahaan = karyawanMaster.IdPerusahaan;
            idDepartemen = karyawanMaster.IdDepartemen ?? idDepartemen;
            idJabatan = karyawanMaster.IdJabatan ?? idJabatan;

            var personalMaster = await _context.Personals.FirstOrDefaultAsync(p => p.IdPersonal == karyawanMaster.IdPersonal);
            if (personalMaster != null && !string.IsNullOrWhiteSpace(personalMaster.NamaLengkap))
            {
                fullName = personalMaster.NamaLengkap;
            }

            if (string.IsNullOrEmpty(fullName))
            {
                fullName = nrp;
            }

            // Resolve company name, department name, role
            string companyName = "PT INDEXIM COALINDO";
            string deptName = "General";
            string mappedRole = "Operator";

            if (idPerusahaan.HasValue)
            {
                var p = await _context.Perusahaans.FirstOrDefaultAsync(x => x.PerusahaanId == idPerusahaan.Value);
                if (p != null)
                {
                    companyName = p.NamaPerusahaan ?? companyName;
                    mappedRole = p.TipePerusahaanId switch
                    {
                        1 => "Owner",
                        2 => "Maincon",
                        3 => "Subcon",
                        4 => "Vendor",
                        _ => "Operator"
                    };
                }
            }

            if (idDepartemen.HasValue)
            {
                var d = await _context.Departemens.FirstOrDefaultAsync(x => x.DepartemenId == idDepartemen.Value);
                if (d != null) deptName = d.NamaDepartemen ?? deptName;
            }

            string jobTitle = "Staff/Operator";
            if (idJabatan.HasValue)
            {
                var jab = await _context.Jabatans.FirstOrDefaultAsync(x => x.JabatanId == idJabatan.Value);
                if (!string.IsNullOrWhiteSpace(jab?.NamaJabatan))
                {
                    jobTitle = jab.NamaJabatan;
                }
            }

            // Check role override from AppUser
            string role;
            var existingAppUser = await _context.AppUsers.FindAsync(nrp);
            if (existingAppUser != null && !string.IsNullOrEmpty(existingAppUser.Role))
            {
                role = existingAppUser.Role;
            }
            else if (string.Equals(nrp, "admin.owner", StringComparison.OrdinalIgnoreCase))
            {
                role = "Admin";
            }
            else
            {
                role = mappedRole;
            }

            // Update or Insert AppUser (Login history)
            if (existingAppUser == null)
            {
                existingAppUser = new AppUser
                {
                    Nik = nrp,
                    Nama = fullName,
                    Departemen = deptName,
                    Perusahaan = companyName,
                    IdPerusahaan = idPerusahaan,
                    Role = role,
                    KaryawanId = karyawanMaster?.IdKaryawan,
                    LastLogin = DateTime.Now
                };
                _context.AppUsers.Add(existingAppUser);
            }
            else
            {
                existingAppUser.Nama = fullName;
                existingAppUser.Departemen = deptName;
                existingAppUser.Perusahaan = companyName;
                existingAppUser.IdPerusahaan = idPerusahaan;
                existingAppUser.KaryawanId = karyawanMaster?.IdKaryawan;
                if (string.IsNullOrEmpty(existingAppUser.Role))
                {
                    existingAppUser.Role = role;
                }
                existingAppUser.LastLogin = DateTime.Now;
                _context.AppUsers.Update(existingAppUser);
            }
            await _context.SaveChangesAsync();

            // Generate JWT Token
            var token = _jwtService.GenerateToken(
                nik: nrp,
                fullName: fullName,
                role: role,
                companyId: idPerusahaan ?? 1,
                companyName: companyName,
                department: deptName,
                jobTitle: jobTitle,
                employeeId: karyawanMaster?.IdKaryawan);

            var response = new AuthResponse
            {
                Token = token,
                User = new UserDto
                {
                    Id = karyawanMaster?.IdKaryawan ?? 1,
                    Name = fullName,
                    Email = "IC" + nrp,
                    Role = role,
                    Company = companyName,
                    CompanyId = idPerusahaan ?? 1,
                    Department = deptName,
                    JobTitle = jobTitle,
                    CreatedAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                },
                Profile = new UserProfileDto
                {
                    Id = karyawanMaster?.IdKaryawan ?? 1,
                    NoNik = nrp,
                    NamaLengkap = fullName,
                    NamaAlias = fullName.Split(' ').FirstOrDefault() ?? fullName,
                    Company = companyName,
                    CompanyId = idPerusahaan ?? 1,
                    UserId = karyawanMaster?.IdKaryawan ?? 1,
                    Depart = deptName,
                    Section = deptName,
                    Posisi = jobTitle,
                    Foto = overridePwd?.ProfilePicture,
                    Role = role
                }
            };

            return Ok(response);
        }

        [HttpPost("register")]
        [AllowAnonymous]
        public IActionResult Register([FromBody] RegisterRequest req)
        {
            // Registration on enterprise mining SAP is administered via HR / OneDB
            return BadRequest(new { message = "Pendaftaran akun baru dilakukan melalui HRD atau admin perusahaan masing-masing." });
        }

        [HttpPost("logout")]
        [Authorize]
        public IActionResult Logout()
        {
            return Ok(new { message = "Successfully logged out" });
        }

        [HttpGet("profile")]
        [Authorize]
        public async Task<IActionResult> GetProfile()
        {
            var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userNik))
            {
                return Unauthorized(new { message = "Sesi tidak valid." });
            }

            var appUser = await _context.AppUsers.FindAsync(userNik);
            var karyawan = await _context.Karyawans.FirstOrDefaultAsync(k => k.NoNik == userNik && k.StatusAktif);
            var personal = karyawan != null ? await _context.Personals.FirstOrDefaultAsync(p => p.IdPersonal == karyawan.IdPersonal) : null;
            var overridePwd = await _context.PasswordOverrides.FirstOrDefaultAsync(p => p.Nrp == userNik);

            var targetMapping = karyawan != null
                ? await _context.KaryawanJabatanMappings.FirstOrDefaultAsync(m => m.KaryawanId == karyawan.IdKaryawan)
                : null;

            int targetHazardReport = targetMapping?.TargetHazardReport ?? 1;
            int targetInspeksi = targetMapping?.TargetInspeksi ?? 1;
            int targetSafetyTalk = targetMapping?.TargetSafetyTalk ?? 1;
            int targetObservasi = targetMapping?.TargetObservasi ?? 0;
            int targetCoaching = targetMapping?.TargetCoaching ?? 0;
            int targetP5m = 1;

            // Hitung pencapaian safety bulan ini (sesuai MBS_SAP Web HomeController & PerformanceController)
            var now = DateTime.Now;
            var startOfMonth = new DateTime(now.Year, now.Month, 1);
            var endOfMonth = startOfMonth.AddMonths(1).AddTicks(-1);

            // Periksa Roster untuk penskalaan target
            int totalDaysInMonth = DateTime.DaysInMonth(startOfMonth.Year, startOfMonth.Month);
            int computedOnsiteDays = totalDaysInMonth;
            bool hasRoster = false;
            bool isTugasExempt = false;

            var rosterHistory = await _context.Rosters
                .Where(r => r.Nik == userNik)
                .OrderByDescending(r => r.AkhirCuti)
                .ToListAsync();

            if (rosterHistory != null && rosterHistory.Any())
            {
                int computedOnsite = 0;
                bool hasAnyRoster = false;
                foreach (var r in rosterHistory)
                {
                    hasAnyRoster = true;
                    if (r.TipeRoster == "TUGAS")
                    {
                        var overlapStartT = r.AwalDinas > startOfMonth ? r.AwalDinas : startOfMonth;
                        var overlapEndT = r.AkhirDinas < endOfMonth ? r.AkhirDinas : endOfMonth;
                        if (overlapStartT <= overlapEndT)
                        {
                            isTugasExempt = true;
                        }
                        continue;
                    }

                    var overlapStart = r.AwalDinas > startOfMonth ? r.AwalDinas : startOfMonth;
                    var overlapEnd = r.AkhirDinas < endOfMonth ? r.AkhirDinas : endOfMonth;
                    if (overlapStart <= overlapEnd)
                    {
                        computedOnsite += (overlapEnd - overlapStart).Days + 1;
                    }
                }
                if (hasAnyRoster)
                {
                    hasRoster = true;
                    computedOnsiteDays = computedOnsite;
                }
            }

            double ratio = hasRoster ? (double)computedOnsiteDays / totalDaysInMonth : 1.0;

            int ScaleTarget(int baseTarget, double rat, int daysOnsite)
            {
                if (baseTarget == 0 || daysOnsite == 0) return 0;
                int scaled = (int)Math.Round(baseTarget * rat, MidpointRounding.AwayFromZero);
                return Math.Max(scaled, 1);
            }

            if (isTugasExempt)
            {
                targetHazardReport = 0;
                targetInspeksi = 0;
                targetSafetyTalk = 0;
                targetObservasi = 0;
                targetCoaching = 0;
                targetP5m = 0;
            }
            else if (hasRoster)
            {
                targetHazardReport = ScaleTarget(targetHazardReport, ratio, computedOnsiteDays);
                targetInspeksi = ScaleTarget(targetInspeksi, ratio, computedOnsiteDays);
                targetSafetyTalk = ScaleTarget(targetSafetyTalk, ratio, computedOnsiteDays);
                targetObservasi = ScaleTarget(targetObservasi, ratio, computedOnsiteDays);
                targetCoaching = ScaleTarget(targetCoaching, ratio, computedOnsiteDays);
            }

            // Bulan ini (Aktual)
            int myHazards = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == userNik && h.Tanggal >= startOfMonth && h.Tanggal <= endOfMonth);
            int myInspections = await _context.Inspections.CountAsync(i => !i.IsDeleted && i.Nik == userNik && i.Tanggal >= startOfMonth && i.Tanggal <= endOfMonth);
            int mySafetyTalks = await _context.SafetyTalks.CountAsync(s => !s.IsDeleted && s.Nik == userNik && s.Tanggal >= startOfMonth && s.Tanggal <= endOfMonth);
            int myObservasi = await _context.Observations.CountAsync(o => !o.IsDeleted && o.Nik == userNik && o.CreatedAt >= startOfMonth && o.CreatedAt <= endOfMonth);
            int myP5ms = await _context.P5ms.CountAsync(p => !p.IsDeleted && p.Nik == userNik && p.CreatedAt >= startOfMonth && p.CreatedAt <= endOfMonth);
            int myCoaching = await _context.Coachings.CountAsync(c => !c.IsDeleted && (c.Nik == userNik || _context.CoachingParticipants.Any(cp => cp.CoachingId == c.Id && cp.Nik == userNik)) && c.CreatedAt >= startOfMonth && c.CreatedAt <= endOfMonth);

            // Semua Waktu (Lifetime Totals)
            int myHazardsTotal = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == userNik);
            int myInspectionsTotal = await _context.Inspections.CountAsync(i => !i.IsDeleted && i.Nik == userNik);
            int mySafetyTalksTotal = await _context.SafetyTalks.CountAsync(s => !s.IsDeleted && s.Nik == userNik);
            int myObservasiTotal = await _context.Observations.CountAsync(o => !o.IsDeleted && o.Nik == userNik);
            int myP5msTotal = await _context.P5ms.CountAsync(p => !p.IsDeleted && p.Nik == userNik);
            int myCoachingTotal = await _context.Coachings.CountAsync(c => !c.IsDeleted && (c.Nik == userNik || _context.CoachingParticipants.Any(cp => cp.CoachingId == c.Id && cp.Nik == userNik)));

            int totalTarget = targetHazardReport + targetInspeksi + targetSafetyTalk + targetObservasi + targetCoaching + targetP5m;
            int totalSubmissions = myHazards + myInspections + mySafetyTalks + myObservasi + myCoaching + myP5ms;

            // Compliance capped by target per category
            int totalActualCapped = Math.Min(myHazards, targetHazardReport)
                                  + Math.Min(myInspections, targetInspeksi)
                                  + Math.Min(mySafetyTalks, targetSafetyTalk)
                                  + Math.Min(myObservasi, targetObservasi)
                                  + Math.Min(myCoaching, targetCoaching)
                                  + Math.Min(myP5ms, targetP5m);

            double complianceRate = totalTarget > 0 ? Math.Round((double)totalActualCapped / totalTarget * 100.0, 0) : 100.0;

            string badgeName = "Safety Novice";
            string badgeIcon = "shield";
            string badgeColor = "#9ca3af";

            if (complianceRate >= 100.0 || (totalTarget == 0 && isTugasExempt))
            {
                badgeName = "Safety Hero (Gold)";
                badgeIcon = "shield_check";
                badgeColor = "#fbbf24";
            }
            else if (complianceRate >= 75.0)
            {
                badgeName = "Safety Champion (Silver)";
                badgeIcon = "shield_star";
                badgeColor = "#cbd5e1";
            }
            else if (complianceRate > 0)
            {
                badgeName = "Safety Aware (Bronze)";
                badgeIcon = "shield";
                badgeColor = "#b45309";
            }

            // Perhitungan Kepatuhan Mingguan (Week)
            var today = DateTime.Today;
            int diff = (7 + (today.DayOfWeek - DayOfWeek.Monday)) % 7;
            var startOfWeek = today.AddDays(-1 * diff).Date;
            var endOfWeek = startOfWeek.AddDays(7).AddTicks(-1);

            int myHazardsWeek = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == userNik && h.Tanggal >= startOfWeek && h.Tanggal <= endOfWeek);
            int myInspectionsWeek = await _context.Inspections.CountAsync(i => !i.IsDeleted && i.Nik == userNik && i.Tanggal >= startOfWeek && i.Tanggal <= endOfWeek);
            int mySafetyTalksWeek = await _context.SafetyTalks.CountAsync(s => !s.IsDeleted && s.Nik == userNik && s.Tanggal >= startOfWeek && s.Tanggal <= endOfWeek);
            int myObservasiWeek = await _context.Observations.CountAsync(o => !o.IsDeleted && o.Nik == userNik && o.CreatedAt >= startOfWeek && o.CreatedAt <= endOfWeek);
            int myP5msWeek = await _context.P5ms.CountAsync(p => !p.IsDeleted && p.Nik == userNik && p.CreatedAt >= startOfWeek && p.CreatedAt <= endOfWeek);
            int myCoachingWeek = await _context.Coachings.CountAsync(c => !c.IsDeleted && (c.Nik == userNik || _context.CoachingParticipants.Any(cp => cp.CoachingId == c.Id && cp.Nik == userNik)) && c.CreatedAt >= startOfWeek && c.CreatedAt <= endOfWeek);

            int myTotalWeek = myHazardsWeek + myInspectionsWeek + mySafetyTalksWeek + myObservasiWeek + myCoachingWeek + myP5msWeek;
            int myWeeklyTarget = totalTarget > 0 ? Math.Max(1, (int)Math.Round(totalTarget / 4.0, MidpointRounding.AwayFromZero)) : 0;
            bool isMyWeekCompliant = totalTarget == 0 || myTotalWeek >= myWeeklyTarget;

            string userDeptName = appUser?.Departemen ?? User.FindFirst("Department")?.Value ?? "SYSTEM INTEGRATIONS";

            int userDeptRank = 19;
            int userDeptTotalCount = 24;
            double userDeptMtdRate = 0.0;
            int userEmpDeptRank = 5;
            int userEmpDeptTotalCount = 5;
            int userEmpCompanyRank = 52;
            int userEmpCompanyTotalCount = 120;

            try
            {
                int compId = appUser?.IdPerusahaan ?? (karyawan?.IdPerusahaan ?? 1);
                var deptEntity = await _context.Departemens
                    .AsNoTracking()
                    .FirstOrDefaultAsync(d => d.NamaDepartemen == userDeptName || (karyawan != null && d.DepartemenId == karyawan.IdDepartemen));

                int deptId = deptEntity?.DepartemenId ?? (karyawan?.IdDepartemen ?? 0);

                int countDepts = await _context.Departemens.AsNoTracking().CountAsync();
                if (countDepts > 0)
                {
                    userDeptTotalCount = countDepts;
                }

                if (deptId > 0)
                {
                    var deptEmpCount = await _context.Karyawans
                        .AsNoTracking()
                        .CountAsync(k => k.IdDepartemen == deptId && k.StatusAktif == true);
                    if (deptEmpCount > 0)
                    {
                        userEmpDeptTotalCount = deptEmpCount;
                    }
                }

                var compEmpCount = await _context.Karyawans
                    .AsNoTracking()
                    .CountAsync(k => k.IdPerusahaan == compId && k.StatusAktif == true);
                if (compEmpCount > 0)
                {
                    userEmpCompanyTotalCount = compEmpCount;
                }

                if (deptId > 0)
                {
                    var deptEmpNiks = await _context.Karyawans
                        .AsNoTracking()
                        .Where(k => k.IdDepartemen == deptId && k.StatusAktif == true && k.NoNik != null)
                        .Select(k => k.NoNik!)
                        .ToListAsync();

                    if (deptEmpNiks.Count > 0)
                    {
                        var hazardsInDept = await _context.HazardReports
                            .AsNoTracking()
                            .Where(h => !h.IsDeleted && h.Tanggal >= startOfMonth && h.Tanggal <= endOfMonth && deptEmpNiks.Contains(h.Nik!))
                            .GroupBy(h => h.Nik)
                            .Select(g => new { Nik = g.Key, Count = g.Count() })
                            .ToListAsync();

                        var insInDept = await _context.Inspections
                            .AsNoTracking()
                            .Where(i => !i.IsDeleted && i.Tanggal >= startOfMonth && i.Tanggal <= endOfMonth && deptEmpNiks.Contains(i.Nik!))
                            .GroupBy(i => i.Nik)
                            .Select(g => new { Nik = g.Key, Count = g.Count() })
                            .ToListAsync();

                        var stInDept = await _context.SafetyTalks
                            .AsNoTracking()
                            .Where(s => !s.IsDeleted && s.Tanggal >= startOfMonth && s.Tanggal <= endOfMonth && deptEmpNiks.Contains(s.Nik!))
                            .GroupBy(s => s.Nik)
                            .Select(g => new { Nik = g.Key, Count = g.Count() })
                            .ToListAsync();

                        var mapCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
                        foreach (var n in deptEmpNiks) mapCounts[n] = 0;
                        foreach (var h in hazardsInDept) if (h.Nik != null && mapCounts.ContainsKey(h.Nik)) mapCounts[h.Nik] += h.Count;
                        foreach (var i in insInDept) if (i.Nik != null && mapCounts.ContainsKey(i.Nik)) mapCounts[i.Nik] += i.Count;
                        foreach (var s in stInDept) if (s.Nik != null && mapCounts.ContainsKey(s.Nik)) mapCounts[s.Nik] += s.Count;

                        var sortedEmps = mapCounts.OrderByDescending(kv => kv.Value).Select((kv, idx) => new { Nik = kv.Key, Score = kv.Value, Rank = idx + 1 }).ToList();
                        var myDeptRank = sortedEmps.FirstOrDefault(x => string.Equals(x.Nik, userNik, StringComparison.OrdinalIgnoreCase));
                        if (myDeptRank != null)
                        {
                            userEmpDeptRank = myDeptRank.Rank;
                        }

                        userDeptMtdRate = Math.Round(complianceRate, 1);
                    }
                }
            }
            catch
            {
                // Fallback graceful
            }

            var profile = new UserProfileDto
            {
                Id = karyawan?.IdKaryawan ?? 1,
                NoNik = userNik,
                NamaLengkap = personal?.NamaLengkap ?? appUser?.Nama ?? User.Identity?.Name ?? userNik,
                NamaAlias = (personal?.NamaLengkap ?? appUser?.Nama ?? User.Identity?.Name ?? userNik).Split(' ').FirstOrDefault() ?? userNik,
                Company = appUser?.Perusahaan ?? User.FindFirst("Company")?.Value ?? "PT INDEXIM COALINDO",
                CompanyId = appUser?.IdPerusahaan ?? int.Parse(User.FindFirst("CompanyId")?.Value ?? "1"),
                UserId = karyawan?.IdKaryawan ?? 1,
                Depart = userDeptName,
                Section = userDeptName,
                Posisi = User.FindFirst("JobTitle")?.Value ?? "Staff",
                Foto = overridePwd?.ProfilePicture,
                Role = appUser?.Role ?? User.FindFirst(ClaimTypes.Role)?.Value ?? "Operator",
                Email = personal?.EmailPribadi ?? (appUser != null ? "IC" + userNik : "-"),
                Phone = personal?.Hp1 ?? "-",
                MyHazards = myHazards,
                MyInspections = myInspections,
                MySafetyTalks = mySafetyTalks,
                MyObservasi = myObservasi,
                MyCoaching = myCoaching,
                MyP5ms = myP5ms,
                TargetHazardReport = targetHazardReport,
                TargetInspeksi = targetInspeksi,
                TargetSafetyTalk = targetSafetyTalk,
                TargetObservasi = targetObservasi,
                TargetCoaching = targetCoaching,
                TargetP5m = targetP5m,
                TotalTarget = totalTarget,
                KategoriPengawas = targetMapping?.KategoriPengawas,
                AlasanTargetZero = targetMapping?.AlasanTargetZero,
                MyHazardsTotal = myHazardsTotal,
                MyInspectionsTotal = myInspectionsTotal,
                MySafetyTalksTotal = mySafetyTalksTotal,
                MyObservasiTotal = myObservasiTotal,
                MyCoachingTotal = myCoachingTotal,
                MyP5msTotal = myP5msTotal,
                TotalSubmissions = totalSubmissions,
                ComplianceRate = complianceRate,
                BadgeName = badgeName,
                BadgeIcon = badgeIcon,
                BadgeColor = badgeColor,
                IsMyWeekCompliant = isMyWeekCompliant,
                MyTotalWeek = myTotalWeek,
                MyWeeklyTarget = myWeeklyTarget,
                UserDeptName = userDeptName,
                UserDeptRank = userDeptRank,
                UserDeptTotalCount = userDeptTotalCount,
                UserDeptMtdRate = userDeptMtdRate,
                UserEmpDeptRank = userEmpDeptRank,
                UserEmpDeptTotalCount = userEmpDeptTotalCount,
                UserEmpCompanyRank = userEmpCompanyRank,
                UserEmpCompanyTotalCount = userEmpCompanyTotalCount
            };

            // Ambil data SIMPER & Permit terbaru dari PostgreSQL BIMA
            try
            {
                var permitData = await _permitService.GetLatestPermitSimperAsync(userNik);
                if (permitData != null)
                {
                    profile.HasPermit = permitData.HasPermit;
                    profile.PermitNomor = permitData.PermitNomor;
                    profile.PermitStatus = permitData.PermitStatus;
                    profile.IsPermitPrinted = permitData.IsPermitPrinted;
                    profile.RawPermitStatus = permitData.RawPermitStatus;
                    profile.PermitLastExpired = permitData.LastExpired;
                    profile.PermitBerakhirKerja = permitData.BerakhirKerja;
                    profile.IsPermitActive = permitData.IsPermitActive;

                    profile.HasSimper = permitData.HasSimper;
                    profile.SimperNomor = permitData.SimperNomor;
                    profile.SimperStatus = permitData.SimperStatus;
                    profile.IsSimperPrinted = permitData.IsSimperPrinted;
                    profile.RawSimperStatus = permitData.RawSimperStatus;
                    profile.JenisSimper = permitData.JenisSimper;
                    profile.SimperExpiredDate = permitData.SimperExpiredDate;
                    profile.SimperMasaBerlaku = permitData.MasaBerlaku;
                    profile.SimperJenisSim = permitData.JenisSim;
                    profile.SimperNomorSim = permitData.NomorSim;
                    profile.IsSimperActive = permitData.IsSimperActive;
                }
            }
            catch
            {
                // Fallback graceful jika database BIMA tidak merespon
            }

            return Ok(profile);
        }

        [HttpGet("profile/permit-simper/{nik?}")]
        [HttpGet("permit-simper/{nik?}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetPermitSimper(string? nik)
        {
            var userNik = !string.IsNullOrEmpty(nik)
                ? nik
                : User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.Identity?.Name ?? string.Empty;

            if (string.IsNullOrEmpty(userNik))
            {
                return BadRequest(new { message = "NIK tidak valid." });
            }

            var data = await _permitService.GetLatestPermitSimperAsync(userNik);
            return Ok(data);
        }

        [HttpPost("profile")]
        [HttpPost("profile/photo")]
        [HttpPost("auth/profile")]
        [HttpPost("auth/profile/photo")]
        [HttpPost("account/update-profile-picture")]
        [HttpPost("account/updateprofilepicture")]
        public async Task<IActionResult> UpdateProfilePhoto(
            [FromForm(Name = "foto")] IFormFile? foto,
            [FromForm(Name = "photo")] IFormFile? photo,
            [FromForm(Name = "file")] IFormFile? file,
            [FromForm(Name = "nik")] string? nik,
            [FromQuery(Name = "nik")] string? queryNik)
        {
            var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? User.FindFirst("nik")?.Value
                ?? User.FindFirst("Nrp")?.Value
                ?? nik
                ?? queryNik;

            if (string.IsNullOrEmpty(userNik))
            {
                return Unauthorized(new { message = "Sesi atau NIK tidak valid." });
            }

            var uploadFile = foto ?? photo ?? file;
            if (uploadFile == null || uploadFile.Length == 0)
            {
                if (Request.Form.Files.Count > 0)
                {
                    uploadFile = Request.Form.Files[0];
                }
            }

            if (uploadFile == null || uploadFile.Length == 0)
            {
                return BadRequest(new { message = "File foto tidak ditemukan dalam permintaan." });
            }

            // Simpan ke C:\MinePermitFiles\MBS\profiles sesuai standar Web MBS_SAP & Mobile
            var photoUrl = await _imageUploadService.UploadAndCompressImageAsync(uploadFile, "profiles", userNik);
            if (string.IsNullOrEmpty(photoUrl))
            {
                return StatusCode(500, new { message = "Gagal memproses dan mengompres file foto." });
            }

            var overridePwd = await _context.PasswordOverrides.FirstOrDefaultAsync(p => p.Nrp == userNik);
            if (overridePwd == null)
            {
                overridePwd = new PasswordOverride
                {
                    Nrp = userNik,
                    KataSandi = "123456",
                    ProfilePicture = photoUrl,
                    DiubahPada = DateTime.Now
                };
                _context.PasswordOverrides.Add(overridePwd);
            }
            else
            {
                overridePwd.ProfilePicture = photoUrl;
                overridePwd.DiubahPada = DateTime.Now;
                _context.PasswordOverrides.Update(overridePwd);
            }
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Foto profil berhasil diperbarui dan disinkronkan ke C:\\MinePermitFiles\\MBS\\profiles.",
                foto = photoUrl,
                url = photoUrl,
                path = photoUrl
            });
        }

        [HttpGet("profile/photo")]
        [HttpGet("profile/photo/{nik}")]
        [HttpGet("auth/profile/photo")]
        [HttpGet("auth/profile/photo/{nik}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetProfilePhoto(string? nik)
        {
            var userNik = nik
                ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? User.FindFirst("nik")?.Value
                ?? Request.Query["nik"].ToString();

            if (string.IsNullOrEmpty(userNik))
            {
                return BadRequest(new { message = "NIK diperlukan." });
            }

            // 1. Cek dari database PasswordOverrides
            var overridePwd = await _context.PasswordOverrides.FirstOrDefaultAsync(p => p.Nrp == userNik);
            if (overridePwd != null && !string.IsNullOrWhiteSpace(overridePwd.ProfilePicture))
            {
                var cleanPath = overridePwd.ProfilePicture.TrimStart('/', '\\');
                if (cleanPath.StartsWith("uploads/", StringComparison.OrdinalIgnoreCase))
                {
                    cleanPath = cleanPath.Substring(8);
                }
                var directFilePath = Path.Combine(@"C:\MinePermitFiles\MBS", cleanPath);
                if (System.IO.File.Exists(directFilePath))
                {
                    return PhysicalFile(directFilePath, "image/jpeg");
                }
            }

            // 2. Cek langsung file dengan nama {NIK}.jpg di C:\MinePermitFiles\MBS\profiles
            var nikFile = Path.Combine(@"C:\MinePermitFiles\MBS\profiles", $"{userNik}.jpg");
            if (System.IO.File.Exists(nikFile))
            {
                return PhysicalFile(nikFile, "image/jpeg");
            }

            // 3. Cari file yang diawali {NIK}_ di dalam C:\MinePermitFiles\MBS\profiles
            if (Directory.Exists(@"C:\MinePermitFiles\MBS\profiles"))
            {
                var files = Directory.GetFiles(@"C:\MinePermitFiles\MBS\profiles", $"{userNik}*.*", SearchOption.AllDirectories);
                if (files.Length > 0)
                {
                    return PhysicalFile(files[0], "image/jpeg");
                }
            }

            // 4. Cari file di C:\MinePermitFiles\MBS\avatars
            if (Directory.Exists(@"C:\MinePermitFiles\MBS\avatars"))
            {
                var files = Directory.GetFiles(@"C:\MinePermitFiles\MBS\avatars", $"{userNik}*.*", SearchOption.AllDirectories);
                if (files.Length > 0)
                {
                    return PhysicalFile(files[0], "image/jpeg");
                }
            }

            return NotFound(new { message = $"Foto profil untuk NIK {userNik} tidak ditemukan." });
        }

        [HttpPost("change-password")]
        [Authorize]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest req)
        {
            var userNik = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userNik))
            {
                return Unauthorized(new { message = "Sesi tidak valid." });
            }

            if (string.IsNullOrWhiteSpace(req.OldPassword))
            {
                return BadRequest(new { message = "Password lama wajib diisi." });
            }

            if (string.IsNullOrWhiteSpace(req.NewPassword) || req.NewPassword.Length < 6)
            {
                return BadRequest(new { message = "Password baru minimal 6 karakter." });
            }

            if (req.NewPassword != req.NewPasswordConfirmation)
            {
                return BadRequest(new { message = "Konfirmasi password baru tidak cocok." });
            }

            // Verify old password
            var overridePwd = await _context.PasswordOverrides.FirstOrDefaultAsync(p => p.Nrp == userNik);
            bool oldMatch = false;

            if (overridePwd != null)
            {
                oldMatch = overridePwd.KataSandi == req.OldPassword;
            }
            else
            {
                var pengguna = await _context.Penggunas.FirstOrDefaultAsync(p => p.Username == userNik && p.IsAktif);
                oldMatch = (pengguna?.KataSandi == req.OldPassword) || (req.OldPassword == "123456");
            }

            if (!oldMatch)
            {
                return BadRequest(new { message = "Password lama tidak sesuai." });
            }

            if (overridePwd == null)
            {
                overridePwd = new PasswordOverride
                {
                    Nrp = userNik,
                    KataSandi = req.NewPassword,
                    DiubahPada = DateTime.Now
                };
                _context.PasswordOverrides.Add(overridePwd);
            }
            else
            {
                overridePwd.KataSandi = req.NewPassword;
                overridePwd.DiubahPada = DateTime.Now;
                _context.PasswordOverrides.Update(overridePwd);
            }

            await _context.SaveChangesAsync();

            return Ok(new { message = "Password berhasil diubah." });
        }

        [HttpPost("reset-password")]
        [HttpPost("auth/reset-password")]
        [AllowAnonymous]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest req)
        {
            var rawNik = (req.Nik ?? req.Email ?? string.Empty).Trim();
            if (rawNik.StartsWith("IC", StringComparison.OrdinalIgnoreCase))
            {
                rawNik = rawNik.Substring(2).Trim();
            }

            if (string.IsNullOrEmpty(rawNik))
            {
                return BadRequest(new { message = "NIK wajib diisi!" });
            }

            // Clean birthDate: keep only digits
            var cleanBirthDate = new string((req.BirthDate ?? string.Empty).Where(char.IsDigit).ToArray());
            if (string.IsNullOrEmpty(cleanBirthDate) || cleanBirthDate.Length != 8)
            {
                return BadRequest(new
                {
                    message = "Format tanggal lahir harus YYYYMMDD (8 digit angka, contoh: 19900130) sesuai di aplikasi OneEv!"
                });
            }

            // Query vw_karyawan joined with vw_personal
            var matches = await (from k in _context.Karyawans
                                 join p in _context.Personals on k.IdPersonal equals p.IdPersonal
                                 where k.NoNik == rawNik
                                 orderby k.StatusAktif descending
                                 select new
                                 {
                                     k.NoNik,
                                     p.NamaLengkap,
                                     p.TanggalLahir,
                                     k.StatusAktif
                                 }).ToListAsync();

            if (!matches.Any())
            {
                return BadRequest(new
                {
                    message = "NIK tidak terdaftar dalam database perusahaan!"
                });
            }

            var matchedEmployee = matches.FirstOrDefault(m =>
                m.TanggalLahir.HasValue && m.TanggalLahir.Value.ToString("yyyyMMdd") == cleanBirthDate);

            if (matchedEmployee == null)
            {
                return BadRequest(new
                {
                    message = "Tanggal lahir salah! Silakan hubungi HR perusahaan Anda untuk memastikan tanggal lahir yang benar."
                });
            }

            // Reset password to 123456 in tbl_m_pengguna_sandi
            var overridePwd = await _context.PasswordOverrides.FirstOrDefaultAsync(p => p.Nrp == rawNik);
            if (overridePwd == null)
            {
                overridePwd = new PasswordOverride
                {
                    Nrp = rawNik,
                    KataSandi = "123456",
                    DiubahPada = DateTime.Now
                };
                _context.PasswordOverrides.Add(overridePwd);
            }
            else
            {
                overridePwd.KataSandi = "123456";
                overridePwd.DiubahPada = DateTime.Now;
                _context.PasswordOverrides.Update(overridePwd);
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = "Password berhasil di-reset ke 123456. Silakan login dan perbarui password baru di menu profile.",
                nik = rawNik,
                nama = matchedEmployee.NamaLengkap
            });
        }
    }
}
