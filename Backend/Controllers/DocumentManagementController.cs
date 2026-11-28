using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Indexsafe.Api.Controllers
{
    public class UserDocScope
    {
        public string Username { get; set; } = "";
        public string FullName { get; set; } = "";
        public int PenggunaId { get; set; }
        public int PerusahaanId { get; set; } = 1;
        public string PerusahaanName { get; set; } = "PT INDEXIM COALINDO";
        public int? DepartemenId { get; set; }
        public string DepartemenName { get; set; } = "";
        public HashSet<int> RoleIds { get; set; } = new HashSet<int>();
        public string RoleName { get; set; } = "Owner";
        public bool IsOwner { get; set; } = true;
        public bool IsOwnerNoDepartment { get; set; } = true;
    }

    [ApiController]
    [Route("api/document-management")]
    public class DocumentManagementController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IWebHostEnvironment _env;
        private readonly IConfiguration _config;
        private static readonly HttpClient _httpClient = new HttpClient();

        private const string BaseStorageUrl = "https://oneev.indexim.id/uploads/document_management/company_1";
        private const string LocalStorageRoot = @"C:\MinePermitFiles\ONEDBEV\uploads\document_management\company_1";

        public DocumentManagementController(AppDbContext context, IWebHostEnvironment env, IConfiguration config)
        {
            _context = context;
            _env = env;
            _config = config;
        }

        #region User Scope & Permission Resolvers (One EV Integration)

        private async Task<UserDocScope> ResolveUserDocScopeAsync(string? explicitNik = null)
        {
            // 1. Ambil identitas NIK / username dari berbagai sumber (Query, Header, Claim JWT)
            string userNik = explicitNik?.Trim() ?? "";
            if (string.IsNullOrWhiteSpace(userNik))
            {
                userNik = Request.Query["nik"].FirstOrDefault()?.Trim() ?? "";
            }
            if (string.IsNullOrWhiteSpace(userNik))
            {
                userNik = Request.Headers["X-User-Nik"].FirstOrDefault()?.Trim() ?? "";
            }
            if (string.IsNullOrWhiteSpace(userNik))
            {
                userNik = User.FindFirstValue("nik") 
                       ?? User.FindFirstValue(ClaimTypes.NameIdentifier) 
                       ?? User.FindFirstValue("username")
                       ?? User.FindFirstValue(ClaimTypes.Name)
                       ?? "";
            }
            if (string.IsNullOrWhiteSpace(userNik))
            {
                userNik = Request.Headers["X-User-Name"].FirstOrDefault()?.Trim() ?? "";
            }
            if (string.IsNullOrWhiteSpace(userNik))
            {
                userNik = "24051940986"; // Fallback default
            }

            string cleanNik = userNik.TrimStart('0');
            var scope = new UserDocScope
            {
                Username = userNik,
                FullName = Request.Headers["X-User-Name"].FirstOrDefault()?.Trim() ?? userNik
            };

            var conn = _context.Database.GetDbConnection();
            bool wasClosed = conn.State != ConnectionState.Open;
            if (wasClosed) await conn.OpenAsync();

            try
            {
                // Langkah 0: Periksa profil & role di DB_SAP.dbo.tbl_t_app_user (Pengguna Indexsafe Mobile)
                try
                {
                    using var cmdAppUser = conn.CreateCommand();
                    cmdAppUser.CommandText = @"
                        SELECT TOP 1 role, perusahaan, id_perusahaan, nama, departemen
                        FROM [DB_SAP].dbo.tbl_t_app_user
                        WHERE nik = @nik OR nik = @cleanNik;
                    ";
                    var pU = cmdAppUser.CreateParameter();
                    pU.ParameterName = "@nik";
                    pU.Value = userNik;
                    cmdAppUser.Parameters.Add(pU);

                    var pCleanU = cmdAppUser.CreateParameter();
                    pCleanU.ParameterName = "@cleanNik";
                    pCleanU.Value = cleanNik;
                    cmdAppUser.Parameters.Add(pCleanU);

                    using var rApp = await cmdAppUser.ExecuteReaderAsync();
                    if (await rApp.ReadAsync())
                    {
                        var appRole = rApp["role"]?.ToString() ?? "";
                        var appPerusahaan = rApp["perusahaan"]?.ToString() ?? "";
                        var appNama = rApp["nama"]?.ToString() ?? "";
                        if (!string.IsNullOrWhiteSpace(appNama) && (scope.FullName == userNik || string.IsNullOrWhiteSpace(scope.FullName)))
                        {
                            scope.FullName = appNama;
                        }

                        if (appRole.Contains("Admin", StringComparison.OrdinalIgnoreCase)
                            || appRole.Contains("Super", StringComparison.OrdinalIgnoreCase)
                            || appRole.Contains("Owner", StringComparison.OrdinalIgnoreCase)
                            || appRole.Contains("Management", StringComparison.OrdinalIgnoreCase))
                        {
                            scope.IsOwner = true;
                            scope.RoleIds.Add(1);
                        }

                        if (appPerusahaan.Contains("Indexim", StringComparison.OrdinalIgnoreCase))
                        {
                            scope.PerusahaanId = 1;
                            scope.RoleIds.Add(1);
                        }
                    }
                }
                catch { }

                // Langkah A: Cek apakah user terdaftar resmi di [ONE_DB_MITRA].[dbo].[tbl_m_pengguna]
                try
                {
                    using var cmdUser = conn.CreateCommand();
                    cmdUser.CommandText = @"
                        SELECT TOP 1 
                            p.pengguna_id, p.username, p.nama_lengkap, p.peran_id, p.perusahaan_id, p.departemen_id,
                            pr.nama_peran, pr.level_akses
                        FROM [ONE_DB_MITRA].dbo.tbl_m_pengguna p
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_peran pr ON p.peran_id = pr.peran_id
                        WHERE p.is_aktif = 1 
                          AND (p.username = @nik OR p.username = @cleanNik OR p.email = @nik);
                    ";
                    var pNik = cmdUser.CreateParameter();
                    pNik.ParameterName = "@nik";
                    pNik.Value = userNik;
                    cmdUser.Parameters.Add(pNik);

                    var pClean = cmdUser.CreateParameter();
                    pClean.ParameterName = "@cleanNik";
                    pClean.Value = cleanNik;
                    cmdUser.Parameters.Add(pClean);

                    using (var reader = await cmdUser.ExecuteReaderAsync())
                    {
                        if (await reader.ReadAsync())
                        {
                            scope.PenggunaId = Convert.ToInt32(reader["pengguna_id"]);
                            scope.Username = reader["username"]?.ToString() ?? userNik;
                            scope.FullName = reader["nama_lengkap"]?.ToString() ?? scope.FullName;
                            scope.PerusahaanId = reader["perusahaan_id"] != DBNull.Value ? Convert.ToInt32(reader["perusahaan_id"]) : 1;
                            scope.DepartemenId = reader["departemen_id"] != DBNull.Value ? Convert.ToInt32(reader["departemen_id"]) : (int?)null;

                            int peranId = reader["peran_id"] != DBNull.Value ? Convert.ToInt32(reader["peran_id"]) : 1;
                            int levelAkses = reader["level_akses"] != DBNull.Value ? Convert.ToInt32(reader["level_akses"]) : 4;
                            string namaPeran = reader["nama_peran"]?.ToString() ?? "Owner";

                            scope.RoleIds.Add(peranId);
                            scope.RoleName = namaPeran;
                            scope.IsOwner = (peranId == 1 || levelAkses >= 4 || namaPeran.Contains("Owner", StringComparison.OrdinalIgnoreCase) || scope.Username.Equals("admin.owner", StringComparison.OrdinalIgnoreCase));
                        }
                    }
                }
                catch { }

                // Langkah B: Ambil / lengkapi nama departemen & perusahaan dari [ONE_DB_MITRA].[dbo].[vw_m_karyawan_aktif]
                try
                {
                    using var cmdKaryawan = conn.CreateCommand();
                    cmdKaryawan.CommandText = @"
                        SELECT TOP 1 
                            id_karyawan, no_nik, nama_lengkap, id_perusahaan, nama_perusahaan, id_departemen, nama_departemen, status_aktif_efektif
                        FROM [ONE_DB_MITRA].dbo.vw_m_karyawan_aktif
                        WHERE no_nik = @nik OR no_nik = @cleanNik;
                    ";
                    var pkNik = cmdKaryawan.CreateParameter();
                    pkNik.ParameterName = "@nik";
                    pkNik.Value = userNik;
                    cmdKaryawan.Parameters.Add(pkNik);

                    var pkClean = cmdKaryawan.CreateParameter();
                    pkClean.ParameterName = "@cleanNik";
                    pkClean.Value = cleanNik;
                    cmdKaryawan.Parameters.Add(pkClean);

                    using var readerK = await cmdKaryawan.ExecuteReaderAsync();
                    if (await readerK.ReadAsync())
                    {
                        scope.FullName = readerK["nama_lengkap"]?.ToString() ?? scope.FullName;
                        scope.PerusahaanName = readerK["nama_perusahaan"]?.ToString() ?? "PT INDEXIM COALINDO";
                        scope.DepartemenName = readerK["nama_departemen"]?.ToString() ?? "";

                        if (scope.PenggunaId == 0)
                        {
                            scope.PerusahaanId = readerK["id_perusahaan"] != DBNull.Value ? Convert.ToInt32(readerK["id_perusahaan"]) : 1;
                            scope.DepartemenId = readerK["id_departemen"] != DBNull.Value ? Convert.ToInt32(readerK["id_departemen"]) : (int?)null;

                            // Perusahaan 1 = Owner (peran_id 1), selain itu Contractor (peran_id 2 / 3)
                            int peranId = (scope.PerusahaanId == 1) ? 1 : 2;
                            scope.RoleIds.Add(peranId);
                            scope.RoleName = (scope.PerusahaanId == 1) ? "Owner" : "Main Contractor";
                            scope.IsOwner = (scope.PerusahaanId == 1);
                        }
                    }
                    else if (scope.PenggunaId == 0)
                    {
                        // Fallback default: anggap Owner jika NIK Indexim atau admin
                        scope.PerusahaanId = 1;
                        scope.RoleIds.Add(1);
                        scope.RoleName = "Owner";
                        scope.IsOwner = true;
                    }
                }
                catch
                {
                    if (scope.PenggunaId == 0)
                    {
                        scope.PerusahaanId = 1;
                        scope.RoleIds.Add(1);
                        scope.RoleName = "Owner";
                        scope.IsOwner = true;
                    }
                }

                // Langkah C: Ambil mapped roles tambahan dari [ONE_DB_MITRA].[dbo].[tbl_r_pengguna_peran]
                if (scope.PenggunaId > 0)
                {
                    using var cmdRoles = conn.CreateCommand();
                    cmdRoles.CommandText = @"
                        SELECT peran_id FROM [ONE_DB_MITRA].dbo.tbl_r_pengguna_peran
                        WHERE pengguna_id = @pid AND is_aktif = 1;
                    ";
                    var pPid = cmdRoles.CreateParameter();
                    pPid.ParameterName = "@pid";
                    pPid.Value = scope.PenggunaId;
                    cmdRoles.Parameters.Add(pPid);

                    using var readerR = await cmdRoles.ExecuteReaderAsync();
                    while (await readerR.ReadAsync())
                    {
                        int rId = Convert.ToInt32(readerR["peran_id"]);
                        if (rId > 0)
                        {
                            scope.RoleIds.Add(rId);
                            if (rId == 1) scope.IsOwner = true;
                        }
                    }
                }

                // Pastikan karyawan PT Indexim Coalindo selalu mendapatkan role Owner (peran_id = 1)
                if (scope.PerusahaanId == 1 || (scope.PerusahaanName != null && scope.PerusahaanName.Contains("Indexim", StringComparison.OrdinalIgnoreCase)))
                {
                    scope.RoleIds.Add(1);
                    scope.IsOwner = true;
                }

                // Sesuai One EV: Owner/Admin memiliki akses universal ke seluruh folder repositori
                if (scope.IsOwner && (scope.RoleIds.Contains(1) || scope.RoleName.Contains("Owner", StringComparison.OrdinalIgnoreCase) || scope.RoleName.Contains("Admin", StringComparison.OrdinalIgnoreCase)))
                {
                    scope.IsOwnerNoDepartment = true;
                }
                else
                {
                    scope.IsOwnerNoDepartment = scope.IsOwner && (!scope.DepartemenId.HasValue || scope.DepartemenId.Value <= 0);
                }
            }
            finally
            {
                if (wasClosed) await conn.CloseAsync();
            }

            return scope;
        }

        private async Task<Dictionary<string, HashSet<int>>> LoadRoleRulesByPathAsync(int companyId = 1)
        {
            var dict = new Dictionary<string, HashSet<int>>(StringComparer.OrdinalIgnoreCase);
            var conn = _context.Database.GetDbConnection();
            bool wasClosed = conn.State != ConnectionState.Open;
            if (wasClosed) await conn.OpenAsync();

            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = @"
                    SELECT f.path_key, rr.peran_id
                    FROM [ONE_DB_MITRA].dbo.tbl_r_dokumen_folder_role rr
                    JOIN [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder f ON rr.folder_id = f.folder_id
                    WHERE f.perusahaan_id = @cid AND f.is_deleted = 0 AND rr.can_view = 1;
                ";
                var pC = cmd.CreateParameter();
                pC.ParameterName = "@cid";
                pC.Value = companyId;
                cmd.Parameters.Add(pC);

                using var r = await cmd.ExecuteReaderAsync();
                while (await r.ReadAsync())
                {
                    var path = r["path_key"]?.ToString() ?? "";
                    int peranId = Convert.ToInt32(r["peran_id"]);
                    if (!dict.ContainsKey(path)) dict[path] = new HashSet<int>();
                    dict[path].Add(peranId);
                }
            }
            finally
            {
                if (wasClosed) await conn.CloseAsync();
            }
            return dict;
        }

        private sealed class FolderScopeRule
        {
            public int FolderId { get; set; }
            public int? PerusahaanId { get; set; }
            public int? DepartemenId { get; set; }
            public string? NoNik { get; set; }
            public int? PeranId { get; set; }
            public bool CanView { get; set; }
            public bool CanUpload { get; set; }
        }

        private async Task<Dictionary<string, List<FolderScopeRule>>> LoadScopeRulesByPathAsync(int companyId = 1)
        {
            var dict = new Dictionary<string, List<FolderScopeRule>>(StringComparer.OrdinalIgnoreCase);
            var conn = _context.Database.GetDbConnection();
            bool wasClosed = conn.State != ConnectionState.Open;
            if (wasClosed) await conn.OpenAsync();

            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = @"
                    SELECT f.path_key, fs.folder_id, fs.perusahaan_id, fs.departemen_id, fs.no_nik, fs.peran_id, fs.can_view, fs.can_upload
                    FROM [ONE_DB_MITRA].dbo.tbl_r_dokumen_folder_scope fs
                    JOIN [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder f ON fs.folder_id = f.folder_id
                    WHERE f.is_deleted = 0 AND (fs.perusahaan_id IS NULL OR fs.perusahaan_id = @cid);
                ";
                var pC = cmd.CreateParameter();
                pC.ParameterName = "@cid";
                pC.Value = companyId;
                cmd.Parameters.Add(pC);

                using var r = await cmd.ExecuteReaderAsync();
                while (await r.ReadAsync())
                {
                    var path = r["path_key"]?.ToString() ?? "";
                    var rule = new FolderScopeRule
                    {
                        FolderId = Convert.ToInt32(r["folder_id"]),
                        PerusahaanId = r["perusahaan_id"] != DBNull.Value ? Convert.ToInt32(r["perusahaan_id"]) : (int?)null,
                        DepartemenId = r["departemen_id"] != DBNull.Value ? Convert.ToInt32(r["departemen_id"]) : (int?)null,
                        NoNik = r["no_nik"]?.ToString()?.Trim(),
                        PeranId = r["peran_id"] != DBNull.Value ? Convert.ToInt32(r["peran_id"]) : (int?)null,
                        CanView = r["can_view"] != DBNull.Value && Convert.ToBoolean(r["can_view"]),
                        CanUpload = r["can_upload"] != DBNull.Value && Convert.ToBoolean(r["can_upload"])
                    };
                    if (!dict.ContainsKey(path)) dict[path] = new List<FolderScopeRule>();
                    dict[path].Add(rule);
                }
            }
            catch
            {
                // Table might not exist or transient connection error; return empty
            }
            finally
            {
                if (wasClosed) await conn.CloseAsync();
            }
            return dict;
        }

        private static bool IsFolderAllowed(
            string path,
            IReadOnlySet<int> userRoleIds,
            Dictionary<string, HashSet<int>> rulesByPath,
            Dictionary<string, List<FolderScopeRule>>? scopeRulesByPath,
            bool isOwnerNoDepartment,
            int? userCompanyId = null,
            int? userDeptId = null,
            string? userNik = null)
        {
            if (isOwnerNoDepartment) return true;

            var probe = NormalizeRelativePath(path);
            var cleanNik = (userNik ?? string.Empty).Trim();

            while (true)
            {
                // 1. Cek Granular Scope Rule (One EV: NIK -> Departemen -> Perusahaan -> Peran)
                if (scopeRulesByPath != null && scopeRulesByPath.TryGetValue(probe, out var scopes) && scopes.Count > 0)
                {
                    // A. Rule khusus spesifik NIK
                    var nikRule = scopes.FirstOrDefault(s => !string.IsNullOrWhiteSpace(s.NoNik)
                        && string.Equals(s.NoNik.Trim(), cleanNik, StringComparison.OrdinalIgnoreCase));
                    if (nikRule != null)
                    {
                        return nikRule.CanView;
                    }

                    // B. Rule departemen untuk perusahaan pengguna
                    if (userDeptId.HasValue && userCompanyId.HasValue)
                    {
                        var deptScopes = scopes.Where(s => s.PerusahaanId == userCompanyId && s.DepartemenId.HasValue).ToList();
                        if (deptScopes.Count > 0)
                        {
                            var matchingDept = deptScopes.FirstOrDefault(s => s.DepartemenId == userDeptId.Value);
                            if (matchingDept != null)
                            {
                                return matchingDept.CanView;
                            }
                            return false; // Ada rule departemen dan departemen user tidak cocok -> ditolak
                        }
                    }

                    // C. Rule perusahaan
                    if (userCompanyId.HasValue)
                    {
                        var compScopes = scopes.Where(s => s.PerusahaanId.HasValue && !s.DepartemenId.HasValue && string.IsNullOrWhiteSpace(s.NoNik)).ToList();
                        if (compScopes.Count > 0)
                        {
                            var matchingComp = compScopes.FirstOrDefault(s => s.PerusahaanId == userCompanyId.Value);
                            if (matchingComp != null)
                            {
                                return matchingComp.CanView;
                            }
                        }
                    }

                    // D. Rule peran / role
                    var roleScopes = scopes.Where(s => s.PeranId.HasValue).ToList();
                    if (roleScopes.Count > 0)
                    {
                        var matchingRole = roleScopes.FirstOrDefault(s => userRoleIds.Contains(s.PeranId!.Value));
                        if (matchingRole != null)
                        {
                            return matchingRole.CanView;
                        }
                    }
                }

                // 2. Rule legacy folder role (tbl_r_dokumen_folder_role)
                if (rulesByPath != null && rulesByPath.TryGetValue(probe, out var allowedRoles))
                {
                    return allowedRoles.Overlaps(userRoleIds);
                }

                if (string.IsNullOrWhiteSpace(probe)) break;

                // Naik ke parent folder (inheritance)
                var lastSlash = probe.LastIndexOf('/');
                probe = lastSlash < 0 ? string.Empty : probe.Substring(0, lastSlash);
            }

            return true;
        }

        private async Task<HashSet<int>> LoadBlockedFileIdsAsync(IReadOnlySet<int> userRoleIds, bool isOwnerNoDepartment)
        {
            var blocked = new HashSet<int>();
            if (isOwnerNoDepartment || userRoleIds == null || userRoleIds.Count == 0) return blocked;

            var conn = _context.Database.GetDbConnection();
            bool wasClosed = conn.State != ConnectionState.Open;
            if (wasClosed) await conn.OpenAsync();

            try
            {
                using var cmd = conn.CreateCommand();
                var rolesIn = string.Join(",", userRoleIds);
                cmd.CommandText = $@"
                    SELECT DISTINCT file_id
                    FROM [ONE_DB_MITRA].dbo.tbl_r_dokumen_file_role
                    WHERE can_view = 0 AND peran_id IN ({rolesIn});
                ";

                using var r = await cmd.ExecuteReaderAsync();
                while (await r.ReadAsync())
                {
                    blocked.Add(Convert.ToInt32(r["file_id"]));
                }
            }
            finally
            {
                if (wasClosed) await conn.CloseAsync();
            }
            return blocked;
        }

        private static string NormalizeRelativePath(string? path)
        {
            if (string.IsNullOrWhiteSpace(path)) return string.Empty;
            var normalized = path.Trim().Replace('\\', '/');
            while (normalized.Contains("//", StringComparison.Ordinal))
            {
                normalized = normalized.Replace("//", "/", StringComparison.Ordinal);
            }
            normalized = normalized.Trim('/');
            if (normalized.Contains("..", StringComparison.Ordinal)) return string.Empty;
            return normalized;
        }

        #endregion

        /// <summary>
        /// Ringkasan statistik dokumen tambang dari ONE_DB_MITRA (difilter sesuai hak akses pengguna).
        /// </summary>
        [HttpGet("summary")]
        [AllowAnonymous]
        public async Task<IActionResult> GetSummary([FromQuery] string? department = null, [FromQuery] string? nik = null)
        {
            try
            {
                var scope = await ResolveUserDocScopeAsync(nik);
                var roleRules = await LoadRoleRulesByPathAsync(scope.PerusahaanId);
                var scopeRules = await LoadScopeRulesByPathAsync(scope.PerusahaanId);
                var blockedFiles = await LoadBlockedFileIdsAsync(scope.RoleIds, scope.IsOwnerNoDepartment);

                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT 
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file WHERE is_deleted = 0) AS total_files,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder WHERE perusahaan_id = 1 AND is_deleted = 0) AS total_folders,
                            (SELECT ISNULL(SUM(CAST(size_bytes AS BIGINT)), 0) FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file WHERE is_deleted = 0) AS total_storage,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file WHERE is_deleted = 0 AND file_path LIKE '%04 SOP%') AS sop_count,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file WHERE is_deleted = 0 AND file_path LIKE '%06 JSA%') AS jsa_count,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file WHERE is_deleted = 0 AND file_path LIKE '%07 Form%') AS form_count,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file WHERE is_deleted = 0 AND file_path LIKE '%01 Kebijakan%') AS policy_count;

                        SELECT TOP 20 
                            f.file_id, f.folder_id, f.nama_dokumen, f.nama_file_stored, f.file_path, f.content_type, f.size_bytes,
                            f.is_read_only, f.is_bold, f.created_at, f.created_by, fo.path_key
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file f
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder fo ON f.folder_id = fo.folder_id
                        WHERE f.is_deleted = 0
                        ORDER BY f.file_id DESC;
                    ";

                    long totalFiles = 0;
                    long totalFolders = 0;
                    long totalStorage = 0;
                    int sopCount = 0;
                    int jsaCount = 0;
                    int formCount = 0;
                    int policyCount = 0;

                    using var reader = await cmd.ExecuteReaderAsync();
                    if (await reader.ReadAsync())
                    {
                        totalFiles = reader["total_files"] != DBNull.Value ? Convert.ToInt64(reader["total_files"]) : 0;
                        totalFolders = reader["total_folders"] != DBNull.Value ? Convert.ToInt64(reader["total_folders"]) : 0;
                        totalStorage = reader["total_storage"] != DBNull.Value ? Convert.ToInt64(reader["total_storage"]) : 0;
                        sopCount = reader["sop_count"] != DBNull.Value ? Convert.ToInt32(reader["sop_count"]) : 0;
                        jsaCount = reader["jsa_count"] != DBNull.Value ? Convert.ToInt32(reader["jsa_count"]) : 0;
                        formCount = reader["form_count"] != DBNull.Value ? Convert.ToInt32(reader["form_count"]) : 0;
                        policyCount = reader["policy_count"] != DBNull.Value ? Convert.ToInt32(reader["policy_count"]) : 0;
                    }

                    var recentDocs = new List<object>();
                    if (await reader.NextResultAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            int fId = Convert.ToInt32(reader["file_id"]);
                            var folderPath = reader["path_key"]?.ToString() ?? "";

                            // Terapkan filtering One EV
                            if (blockedFiles.Contains(fId)) continue;
                            if (!IsFolderAllowed(folderPath, scope.RoleIds, roleRules, scopeRules, scope.IsOwnerNoDepartment, scope.PerusahaanId, scope.DepartemenId, scope.Username)) continue;

                            var filePath = reader["file_path"]?.ToString() ?? "";
                            var docName = reader["nama_dokumen"]?.ToString() ?? "";
                            var size = reader["size_bytes"] != DBNull.Value ? Convert.ToInt64(reader["size_bytes"]) : 0;
                            var ext = Path.GetExtension(docName).TrimStart('.').ToLower();
                            if (string.IsNullOrEmpty(ext)) ext = Path.GetExtension(filePath).TrimStart('.').ToLower();
                            if (string.IsNullOrEmpty(ext)) ext = "pdf";

                            recentDocs.Add(new
                            {
                                id = fId,
                                folderId = reader["folder_id"] != DBNull.Value ? Convert.ToInt32(reader["folder_id"]) : (int?)null,
                                title = docName,
                                fileName = reader["nama_file_stored"]?.ToString() ?? docName,
                                filePath = filePath,
                                fileUrl = BuildDownloadUrl(filePath),
                                fileType = ext,
                                fileSize = size,
                                formattedSize = FormatStorage(size),
                                isReadOnly = reader["is_read_only"] != DBNull.Value && Convert.ToBoolean(reader["is_read_only"]),
                                createdAt = reader["created_at"] != DBNull.Value ? Convert.ToDateTime(reader["created_at"]).ToString("yyyy-MM-dd HH:mm") : null,
                                createdBy = reader["created_by"]?.ToString() ?? "-"
                            });

                            if (recentDocs.Count >= 8) break;
                        }
                    }

                    return Ok(new
                    {
                        status = 200,
                        success = true,
                        userScope = new
                        {
                            username = scope.Username,
                            fullName = scope.FullName,
                            roleName = scope.RoleName,
                            companyName = scope.PerusahaanName,
                            departmentName = scope.DepartemenName,
                            isOwner = scope.IsOwner,
                            hasAccess = true
                        },
                        data = new
                        {
                            totalDocuments = totalFiles,
                            totalFolders = totalFolders,
                            totalStorageBytes = totalStorage,
                            storageFormatted = FormatStorage(totalStorage),
                            activeSopCount = sopCount,
                            jsaCount = jsaCount,
                            formCount = formCount,
                            policyCount = policyCount,
                            recentDocuments = recentDocs
                        }
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Mengambil daftar subfolder dalam folder tertentu (difilter 100% sesuai hak akses One EV).
        /// </summary>
        [HttpGet("folders")]
        [AllowAnonymous]
        public async Task<IActionResult> GetFolders([FromQuery] int? parentId = null, [FromQuery] string? nik = null)
        {
            try
            {
                var scope = await ResolveUserDocScopeAsync(nik);
                var roleRules = await LoadRoleRulesByPathAsync(scope.PerusahaanId);
                var scopeRules = await LoadScopeRulesByPathAsync(scope.PerusahaanId);

                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    int targetParent = parentId.HasValue && parentId.Value > 0 ? parentId.Value : 9;

                    // Verifikasi hak akses parent folder jika bukan root utama (ID 9)
                    if (targetParent != 9)
                    {
                        using var cmdParentCheck = conn.CreateCommand();
                        cmdParentCheck.CommandText = @"
                            SELECT path_key FROM [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder 
                            WHERE folder_id = @pid AND is_deleted = 0;
                        ";
                        var pPid = cmdParentCheck.CreateParameter();
                        pPid.ParameterName = "@pid";
                        pPid.Value = targetParent;
                        cmdParentCheck.Parameters.Add(pPid);

                        var parentPath = (await cmdParentCheck.ExecuteScalarAsync())?.ToString() ?? "";
                        if (!IsFolderAllowed(parentPath, scope.RoleIds, roleRules, scopeRules, scope.IsOwnerNoDepartment, scope.PerusahaanId, scope.DepartemenId, scope.Username))
                        {
                            return StatusCode(StatusCodes.Status403Forbidden, new
                            {
                                status = 403,
                                success = false,
                                message = "Anda tidak memiliki hak akses untuk membuka folder ini sesuai pengaturan One Evolution."
                            });
                        }
                    }

                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT 
                            f.folder_id,
                            f.parent_folder_id,
                            f.nama_folder,
                            f.path_key,
                            f.folder_color,
                            f.is_bold,
                            f.created_at,
                            f.created_by,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder c WHERE c.parent_folder_id = f.folder_id AND c.is_deleted = 0) AS subfolder_count,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file fl WHERE fl.folder_id = f.folder_id AND fl.is_deleted = 0) AS file_count
                        FROM [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder f
                        WHERE f.perusahaan_id = 1 
                          AND f.is_deleted = 0 
                          AND f.parent_folder_id = @parentId
                        ORDER BY f.nama_folder ASC;
                    ";

                    var p = cmd.CreateParameter();
                    p.ParameterName = "@parentId";
                    p.Value = targetParent;
                    cmd.Parameters.Add(p);

                    var folders = new List<object>();
                    using var reader = await cmd.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        var folderPath = reader["path_key"]?.ToString() ?? "";

                        // Filter hak akses sesuai One EV
                        if (!IsFolderAllowed(folderPath, scope.RoleIds, roleRules, scopeRules, scope.IsOwnerNoDepartment, scope.PerusahaanId, scope.DepartemenId, scope.Username))
                        {
                            continue;
                        }

                        var folderId = Convert.ToInt32(reader["folder_id"]);
                        var color = reader["folder_color"]?.ToString();
                        if (string.IsNullOrWhiteSpace(color)) color = "#0284C7";

                        folders.Add(new
                        {
                            id = folderId,
                            parentId = reader["parent_folder_id"] != DBNull.Value ? Convert.ToInt32(reader["parent_folder_id"]) : (int?)null,
                            name = reader["nama_folder"]?.ToString() ?? "Folder",
                            path = folderPath,
                            color = color,
                            isBold = reader["is_bold"] != DBNull.Value && Convert.ToBoolean(reader["is_bold"]),
                            subfolderCount = Convert.ToInt32(reader["subfolder_count"]),
                            fileCount = Convert.ToInt32(reader["file_count"]),
                            filesCount = Convert.ToInt32(reader["file_count"]),
                            createdAt = reader["created_at"] != DBNull.Value ? Convert.ToDateTime(reader["created_at"]).ToString("yyyy-MM-dd") : null,
                            createdBy = reader["created_by"]?.ToString() ?? "-"
                        });
                    }

                    return Ok(new
                    {
                        status = 200,
                        success = true,
                        parentFolderId = targetParent,
                        userScope = new
                        {
                            username = scope.Username,
                            roleName = scope.RoleName,
                            isOwner = scope.IsOwner
                        },
                        data = folders
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Mengambil daftar file dokumen dalam folder terpilih (difilter 100% sesuai hak akses One EV).
        /// </summary>
        [HttpGet("files")]
        [AllowAnonymous]
        public async Task<IActionResult> GetFiles(
            [FromQuery] int folderId,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 100,
            [FromQuery] string? nik = null)
        {
            try
            {
                if (folderId <= 0)
                {
                    return BadRequest(new { status = 400, success = false, message = "folderId wajib diisi" });
                }

                var scope = await ResolveUserDocScopeAsync(nik);
                var roleRules = await LoadRoleRulesByPathAsync(scope.PerusahaanId);
                var scopeRules = await LoadScopeRulesByPathAsync(scope.PerusahaanId);
                var blockedFiles = await LoadBlockedFileIdsAsync(scope.RoleIds, scope.IsOwnerNoDepartment);

                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    // 1. Verifikasi hak akses folder
                    using var cmdFolderCheck = conn.CreateCommand();
                    cmdFolderCheck.CommandText = @"
                        SELECT path_key FROM [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder 
                        WHERE folder_id = @fid AND is_deleted = 0;
                    ";
                    var pFid = cmdFolderCheck.CreateParameter();
                    pFid.ParameterName = "@fid";
                    pFid.Value = folderId;
                    cmdFolderCheck.Parameters.Add(pFid);

                    var folderPath = (await cmdFolderCheck.ExecuteScalarAsync())?.ToString() ?? "";
                    if (!IsFolderAllowed(folderPath, scope.RoleIds, roleRules, scopeRules, scope.IsOwnerNoDepartment, scope.PerusahaanId, scope.DepartemenId, scope.Username))
                    {
                        return StatusCode(StatusCodes.Status403Forbidden, new
                        {
                            status = 403,
                            success = false,
                            message = "Anda tidak memiliki izin akses untuk melihat file dalam folder ini sesuai hak akses One Evolution."
                        });
                    }

                    // 2. Query file dokumen dalam folder
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT 
                            file_id, folder_id, nama_dokumen, nama_file_stored, file_path, content_type, size_bytes,
                            is_read_only, is_bold, expired_at, created_at, created_by
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file
                        WHERE folder_id = @folderId AND is_deleted = 0
                        ORDER BY nama_dokumen ASC;
                    ";

                    var pFolder = cmd.CreateParameter();
                    pFolder.ParameterName = "@folderId";
                    pFolder.Value = folderId;
                    cmd.Parameters.Add(pFolder);

                    var allAllowedFiles = new List<object>();

                    using var reader = await cmd.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        int fId = Convert.ToInt32(reader["file_id"]);
                        if (blockedFiles.Contains(fId)) continue; // Filter role exclude file

                        var filePath = reader["file_path"]?.ToString() ?? "";
                        var docName = reader["nama_dokumen"]?.ToString() ?? "";
                        var size = reader["size_bytes"] != DBNull.Value ? Convert.ToInt64(reader["size_bytes"]) : 0;
                        var ext = Path.GetExtension(docName).TrimStart('.').ToLower();
                        if (string.IsNullOrEmpty(ext)) ext = Path.GetExtension(filePath).TrimStart('.').ToLower();
                        if (string.IsNullOrEmpty(ext)) ext = "pdf";

                        allAllowedFiles.Add(new
                        {
                            id = fId,
                            folderId = Convert.ToInt32(reader["folder_id"]),
                            title = docName,
                            fileName = reader["nama_file_stored"]?.ToString() ?? docName,
                            filePath = filePath,
                            fileUrl = BuildDownloadUrl(filePath),
                            fileType = ext,
                            fileSize = size,
                            formattedSize = FormatStorage(size),
                            isReadOnly = reader["is_read_only"] != DBNull.Value && Convert.ToBoolean(reader["is_read_only"]),
                            isBold = reader["is_bold"] != DBNull.Value && Convert.ToBoolean(reader["is_bold"]),
                            expiredAt = reader["expired_at"] != DBNull.Value ? Convert.ToDateTime(reader["expired_at"]).ToString("yyyy-MM-dd") : null,
                            createdAt = reader["created_at"] != DBNull.Value ? Convert.ToDateTime(reader["created_at"]).ToString("yyyy-MM-dd HH:mm") : null,
                            createdBy = reader["created_by"]?.ToString() ?? "-"
                        });
                    }

                    int total = allAllowedFiles.Count;
                    int skip = Math.Max(0, (page - 1) * pageSize);
                    var pagedFiles = allAllowedFiles.Skip(skip).Take(pageSize).ToList();

                    return Ok(new
                    {
                        status = 200,
                        success = true,
                        folderId = folderId,
                        total = total,
                        page = page,
                        pageSize = pageSize,
                        data = pagedFiles
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Pencarian cepat (instant search) pada koleksi dokumen dengan proteksi hak akses One EV.
        /// </summary>
        [HttpGet("search")]
        [AllowAnonymous]
        public async Task<IActionResult> SearchDocuments([FromQuery] string q, [FromQuery] int limit = 40, [FromQuery] string? nik = null)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 2)
                {
                    return Ok(new { status = 200, success = true, data = new List<object>() });
                }

                var scope = await ResolveUserDocScopeAsync(nik);
                var roleRules = await LoadRoleRulesByPathAsync(scope.PerusahaanId);
                var scopeRules = await LoadScopeRulesByPathAsync(scope.PerusahaanId);
                var blockedFiles = await LoadBlockedFileIdsAsync(scope.RoleIds, scope.IsOwnerNoDepartment);

                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT TOP (@limit) 
                            f.file_id, f.folder_id, f.nama_dokumen, f.nama_file_stored, f.file_path, 
                            f.content_type, f.size_bytes, f.is_read_only, f.is_bold, f.created_at, f.created_by,
                            fo.nama_folder, fo.path_key
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file f
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder fo ON f.folder_id = fo.folder_id
                        WHERE f.is_deleted = 0 
                          AND (f.nama_dokumen LIKE @term OR f.file_path LIKE @term)
                        ORDER BY f.file_id DESC;
                    ";

                    var pTerm = cmd.CreateParameter();
                    pTerm.ParameterName = "@term";
                    pTerm.Value = $"%{q.Trim()}%";
                    cmd.Parameters.Add(pTerm);

                    var pLimit = cmd.CreateParameter();
                    pLimit.ParameterName = "@limit";
                    pLimit.Value = Math.Clamp(limit * 3, 30, 200); // Ambil lebih banyak untuk kompensasi filter role
                    cmd.Parameters.Add(pLimit);

                    var results = new List<object>();
                    using var reader = await cmd.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        int fId = Convert.ToInt32(reader["file_id"]);
                        if (blockedFiles.Contains(fId)) continue;

                        var folderPath = reader["path_key"]?.ToString() ?? "";
                        if (!IsFolderAllowed(folderPath, scope.RoleIds, roleRules, scopeRules, scope.IsOwnerNoDepartment, scope.PerusahaanId, scope.DepartemenId, scope.Username)) continue;

                        var filePath = reader["file_path"]?.ToString() ?? "";
                        var docName = reader["nama_dokumen"]?.ToString() ?? "";
                        var size = reader["size_bytes"] != DBNull.Value ? Convert.ToInt64(reader["size_bytes"]) : 0;
                        var ext = Path.GetExtension(docName).TrimStart('.').ToLower();
                        if (string.IsNullOrEmpty(ext)) ext = Path.GetExtension(filePath).TrimStart('.').ToLower();
                        if (string.IsNullOrEmpty(ext)) ext = "pdf";

                        results.Add(new
                        {
                            id = fId,
                            folderId = reader["folder_id"] != DBNull.Value ? Convert.ToInt32(reader["folder_id"]) : (int?)null,
                            folderName = reader["nama_folder"]?.ToString() ?? "",
                            folderPath = folderPath,
                            title = docName,
                            fileName = reader["nama_file_stored"]?.ToString() ?? docName,
                            filePath = filePath,
                            fileUrl = BuildDownloadUrl(filePath),
                            fileType = ext,
                            fileSize = size,
                            formattedSize = FormatStorage(size),
                            isReadOnly = reader["is_read_only"] != DBNull.Value && Convert.ToBoolean(reader["is_read_only"]),
                            createdAt = reader["created_at"] != DBNull.Value ? Convert.ToDateTime(reader["created_at"]).ToString("yyyy-MM-dd HH:mm") : null,
                            createdBy = reader["created_by"]?.ToString() ?? "-"
                        });

                        if (results.Count >= limit) break;
                    }

                    return Ok(new
                    {
                        status = 200,
                        success = true,
                        query = q.Trim(),
                        count = results.Count,
                        data = results
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Mengambil breadcrumb hierarki folder (jalur dari root hingga folder ini).
        /// </summary>
        [HttpGet("breadcrumbs")]
        [AllowAnonymous]
        public async Task<IActionResult> GetBreadcrumbs([FromQuery] int folderId)
        {
            try
            {
                if (folderId <= 0)
                {
                    return Ok(new { status = 200, success = true, data = new List<object>() });
                }

                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        WITH FolderHierarchy AS (
                            SELECT folder_id, parent_folder_id, nama_folder, path_key, 0 AS level
                            FROM [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder
                            WHERE folder_id = @folderId AND is_deleted = 0
                            
                            UNION ALL
                            
                            SELECT p.folder_id, p.parent_folder_id, p.nama_folder, p.path_key, fh.level + 1
                            FROM [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder p
                            INNER JOIN FolderHierarchy fh ON fh.parent_folder_id = p.folder_id
                            WHERE p.is_deleted = 0
                        )
                        SELECT folder_id, parent_folder_id, nama_folder, path_key
                        FROM FolderHierarchy
                        ORDER BY level DESC;
                    ";

                    var p = cmd.CreateParameter();
                    p.ParameterName = "@folderId";
                    p.Value = folderId;
                    cmd.Parameters.Add(p);

                    var breadcrumbs = new List<object>();
                    using var reader = await cmd.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        breadcrumbs.Add(new
                        {
                            id = Convert.ToInt32(reader["folder_id"]),
                            parentId = reader["parent_folder_id"] != DBNull.Value ? Convert.ToInt32(reader["parent_folder_id"]) : (int?)null,
                            name = reader["nama_folder"]?.ToString() ?? "",
                            path = reader["path_key"]?.ToString() ?? ""
                        });
                    }

                    return Ok(new
                    {
                        status = 200,
                        success = true,
                        data = breadcrumbs
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Download / streaming file dokumen on-demand dengan proteksi hak akses One EV.
        /// </summary>
        [HttpGet("download/{fileId}")]
        [AllowAnonymous]
        public async Task<IActionResult> DownloadFile(int fileId, [FromQuery] string? nik = null)
        {
            try
            {
                var scope = await ResolveUserDocScopeAsync(nik);
                var roleRules = await LoadRoleRulesByPathAsync(scope.PerusahaanId);
                var scopeRules = await LoadScopeRulesByPathAsync(scope.PerusahaanId);
                var blockedFiles = await LoadBlockedFileIdsAsync(scope.RoleIds, scope.IsOwnerNoDepartment);

                // Cek apakah file ini di-exclude untuk role user
                if (blockedFiles.Contains(fileId))
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new
                    {
                        status = 403,
                        success = false,
                        message = "Anda tidak memiliki izin akses untuk mengunduh dokumen ini sesuai pengaturan One Evolution."
                    });
                }

                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                string filePath = "";
                string docName = "";
                string contentType = "application/pdf";
                string folderPath = "";

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT f.file_id, f.nama_dokumen, f.file_path, f.content_type, fo.path_key
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file f
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_dokumen_folder fo ON f.folder_id = fo.folder_id
                        WHERE f.file_id = @id AND f.is_deleted = 0;
                    ";
                    var p = cmd.CreateParameter();
                    p.ParameterName = "@id";
                    p.Value = fileId;
                    cmd.Parameters.Add(p);

                    using var reader = await cmd.ExecuteReaderAsync();
                    if (await reader.ReadAsync())
                    {
                        docName = reader["nama_dokumen"]?.ToString() ?? "dokumen.pdf";
                        filePath = reader["file_path"]?.ToString() ?? "";
                        contentType = reader["content_type"]?.ToString() ?? "application/pdf";
                        folderPath = reader["path_key"]?.ToString() ?? "";
                    }
                    else
                    {
                        return NotFound(new { status = 404, success = false, message = "File tidak ditemukan" });
                    }
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }

                // Cek izin folder
                if (!IsFolderAllowed(folderPath, scope.RoleIds, roleRules, scopeRules, scope.IsOwnerNoDepartment, scope.PerusahaanId, scope.DepartemenId, scope.Username))
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new
                    {
                        status = 403,
                        success = false,
                        message = "Folder dokumen ini dibatasi dan tidak dapat diakses oleh akun Anda."
                    });
                }

                // 1. Cek apakah file ada di storage disk lokal
                var localPath = Path.Combine(LocalStorageRoot, filePath.Replace('/', Path.DirectorySeparatorChar));
                if (System.IO.File.Exists(localPath))
                {
                    return PhysicalFile(localPath, contentType, docName);
                }

                // 2. Jika tidak ada di lokal, streaming dari remoteUrl dan simpan ke disk lokal untuk caching
                var remoteUrl = BuildDownloadUrl(filePath);
                try
                {
                    var response = await _httpClient.GetAsync(remoteUrl, HttpCompletionOption.ResponseHeadersRead);
                    if (response.IsSuccessStatusCode)
                    {
                        var dir = Path.GetDirectoryName(localPath);
                        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);

                        await using (var fileStream = new FileStream(localPath, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            await response.Content.CopyToAsync(fileStream);
                        }

                        if (System.IO.File.Exists(localPath))
                        {
                            return PhysicalFile(localPath, contentType, docName);
                        }
                    }
                }
                catch
                {
                    // Fallback redirect jika download gagal
                    return Redirect(remoteUrl);
                }

                return Redirect(remoteUrl);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        private static string BuildDownloadUrl(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath)) return "";
            var normalized = filePath.Trim().Replace('\\', '/');
            var segments = normalized.Split('/', StringSplitOptions.RemoveEmptyEntries);
            var encodedSegments = new List<string>();
            foreach (var seg in segments)
            {
                encodedSegments.Add(Uri.EscapeDataString(seg));
            }
            return $"{BaseStorageUrl}/{string.Join("/", encodedSegments)}";
        }

        private static string FormatStorage(long bytes)
        {
            if (bytes <= 0) return "0 MB";
            if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
            if (bytes < 1024L * 1024 * 1024) return $"{bytes / (1024.0 * 1024):F1} MB";
            return $"{bytes / (1024.0 * 1024 * 1024):F2} GB";
        }
    }
}
