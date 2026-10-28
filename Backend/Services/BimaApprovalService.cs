using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Indexsafe.Api.DTOs;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace Indexsafe.Api.Services
{
    public class BimaApprovalService
    {
        private readonly ILogger<BimaApprovalService> _logger;
        private readonly IConfiguration _config;
        private readonly string[] _candidateHosts = new[] { "172.16.1.96", "172.16.1.93" };
        private const string User = "postgres";
        private const string Pass = "index.123";

        public BimaApprovalService(ILogger<BimaApprovalService> logger, IConfiguration config)
        {
            _logger = logger;
            _config = config;
        }

        private async Task<NpgsqlConnection?> GetBimaConnectionAsync()
        {
            foreach (var host in _candidateHosts)
            {
                var dbs = new[] { "Bima", "BimaTest", "sysinteg_indexsafe2" };
                foreach (var db in dbs)
                {
                    try
                    {
                        var builder = new NpgsqlConnectionStringBuilder
                        {
                            Host = host,
                            Port = 5432,
                            Database = db,
                            Username = User,
                            Password = Pass,
                            Timeout = 3,
                            CommandTimeout = 6
                        };
                        var conn = new NpgsqlConnection(builder.ConnectionString);
                        await conn.OpenAsync();

                        await using (var checkCmd = new NpgsqlCommand("SELECT to_regclass('public.tb_user')::text;", conn))
                        {
                            var reg = await checkCmd.ExecuteScalarAsync();
                            if (reg != null && reg != DBNull.Value && !string.IsNullOrWhiteSpace(reg.ToString()))
                            {
                                return conn;
                            }
                        }
                        await conn.DisposeAsync();
                    }
                    catch
                    {
                        // try next
                    }
                }
            }
            return null;
        }

        private class BimaUserContext
        {
            public bool IsRegistered { get; set; }
            public int? UserId { get; set; }
            public string? Fullname { get; set; }
            public string? EmployeeId { get; set; }
            public int? RoleId { get; set; }
            public string? RoleName { get; set; }
            public string? Department { get; set; }
            public string? CompanyName { get; set; }
            public int? CompanyId { get; set; }
            public int? DepartmentId { get; set; }
            public List<long> RoleIds { get; set; } = new();
            public List<long> CompanyIds { get; set; } = new();
            public List<long> DepartmentIds { get; set; } = new();
            public List<UserRoleInfoDto> Roles { get; set; } = new();
        }

        private async Task<BimaUserContext> GetUserContextAsync(NpgsqlConnection conn, string nik)
        {
            var ctx = new BimaUserContext { IsRegistered = false };
            if (string.IsNullOrWhiteSpace(nik)) return ctx;

            var nikClean = nik.Trim();
            var nikTrimmed = nikClean.TrimStart('0');

            const string sqlUser = @"
                SELECT u.id, u.fullname, u.employee_id, u.role_id, r.role_name, 
                       u.department, u.company_name, u.company_id, u.department_id, 
                       u.active_company_id, u.active_department_id, u.is_active
                FROM public.tb_user u
                LEFT JOIN public.tb_role r ON u.role_id = r.id
                WHERE (TRIM(u.employee_id) = @nik 
                       OR LTRIM(TRIM(u.employee_id), '0') = @nikTrimmed 
                       OR TRIM(u.username) = @nik)
                  AND u.is_active = true
                LIMIT 1;";

            await using var cmdUser = new NpgsqlCommand(sqlUser, conn);
            cmdUser.Parameters.AddWithValue("@nik", nikClean);
            cmdUser.Parameters.AddWithValue("@nikTrimmed", nikTrimmed);

            await using var rdr = await cmdUser.ExecuteReaderAsync();
            if (!await rdr.ReadAsync())
            {
                return ctx;
            }

            ctx.IsRegistered = true;
            ctx.UserId = rdr.IsDBNull(0) ? null : rdr.GetInt32(0);
            ctx.Fullname = rdr.IsDBNull(1) ? null : rdr.GetString(1);
            ctx.EmployeeId = rdr.IsDBNull(2) ? null : rdr.GetString(2);
            ctx.RoleId = rdr.IsDBNull(3) ? null : Convert.ToInt32(rdr.GetValue(3));
            ctx.RoleName = rdr.IsDBNull(4) ? null : rdr.GetString(4);
            ctx.Department = rdr.IsDBNull(5) ? null : rdr.GetString(5);
            ctx.CompanyName = rdr.IsDBNull(6) ? null : rdr.GetString(6);
            ctx.CompanyId = rdr.IsDBNull(7) ? null : Convert.ToInt32(rdr.GetValue(7));
            ctx.DepartmentId = rdr.IsDBNull(8) ? null : Convert.ToInt32(rdr.GetValue(8));

            long? activeCompId = rdr.IsDBNull(9) ? null : Convert.ToInt64(rdr.GetValue(9));
            long? activeDeptId = rdr.IsDBNull(10) ? null : Convert.ToInt64(rdr.GetValue(10));

            if (ctx.RoleId.HasValue)
            {
                ctx.RoleIds.Add(ctx.RoleId.Value);
                if (!string.IsNullOrEmpty(ctx.RoleName))
                {
                    ctx.Roles.Add(new UserRoleInfoDto { RoleId = ctx.RoleId.Value, RoleName = ctx.RoleName });
                }
            }

            if (ctx.CompanyId.HasValue) ctx.CompanyIds.Add(ctx.CompanyId.Value);
            if (activeCompId.HasValue && !ctx.CompanyIds.Contains(activeCompId.Value)) ctx.CompanyIds.Add(activeCompId.Value);

            if (ctx.DepartmentId.HasValue) ctx.DepartmentIds.Add(ctx.DepartmentId.Value);
            if (activeDeptId.HasValue && !ctx.DepartmentIds.Contains(activeDeptId.Value)) ctx.DepartmentIds.Add(activeDeptId.Value);

            await rdr.CloseAsync();

            if (ctx.UserId.HasValue)
            {
                // 1. Roles tambahan dari tb_user_role
                const string sqlUserRoles = @"
                    SELECT ur.role_id, r.role_name
                    FROM public.tb_user_role ur
                    JOIN public.tb_role r ON ur.role_id = r.id
                    WHERE ur.user_id = @userId;";
                await using var cmdRoles = new NpgsqlCommand(sqlUserRoles, conn);
                cmdRoles.Parameters.AddWithValue("@userId", ctx.UserId.Value);
                await using var rdrRoles = await cmdRoles.ExecuteReaderAsync();
                while (await rdrRoles.ReadAsync())
                {
                    var rid = Convert.ToInt32(rdrRoles.GetValue(0));
                    var rname = rdrRoles.GetString(1);
                    if (!ctx.RoleIds.Contains(rid)) ctx.RoleIds.Add(rid);
                    if (!ctx.Roles.Any(x => x.RoleId == rid))
                    {
                        ctx.Roles.Add(new UserRoleInfoDto { RoleId = rid, RoleName = rname });
                    }
                }
                await rdrRoles.CloseAsync();

                // 2. Akses tambahan dari tb_user_access (company & department)
                const string sqlUserAccess = @"
                    SELECT ua.company_id, ua.department_id
                    FROM public.tb_user_access ua
                    WHERE ua.user_id = @userId AND ua.deleted_at IS NULL;";
                await using var cmdAccess = new NpgsqlCommand(sqlUserAccess, conn);
                cmdAccess.Parameters.AddWithValue("@userId", ctx.UserId.Value);
                await using var rdrAccess = await cmdAccess.ExecuteReaderAsync();
                while (await rdrAccess.ReadAsync())
                {
                    if (!rdrAccess.IsDBNull(0))
                    {
                        var cid = Convert.ToInt64(rdrAccess.GetValue(0));
                        if (!ctx.CompanyIds.Contains(cid)) ctx.CompanyIds.Add(cid);
                    }
                    if (!rdrAccess.IsDBNull(1))
                    {
                        var did = Convert.ToInt64(rdrAccess.GetValue(1));
                        if (!ctx.DepartmentIds.Contains(did)) ctx.DepartmentIds.Add(did);
                    }
                }
                await rdrAccess.CloseAsync();
            }

            // Fallback default jika kosong
            if (!ctx.CompanyIds.Any()) ctx.CompanyIds.Add(1);

            return ctx;
        }

        public async Task<BimaUserStatusDto> CheckUserStatusAsync(string nik)
        {
            var res = new BimaUserStatusDto { IsRegistered = false };
            if (string.IsNullOrWhiteSpace(nik)) return res;

            await using var conn = await GetBimaConnectionAsync();
            if (conn == null)
            {
                _logger.LogWarning("[BimaApprovalService] Cannot connect to Bima PostgreSQL");
                return res;
            }

            try
            {
                var ctx = await GetUserContextAsync(conn, nik);
                if (!ctx.IsRegistered) return res;

                res.IsRegistered = true;
                res.UserId = ctx.UserId;
                res.Fullname = ctx.Fullname;
                res.EmployeeId = ctx.EmployeeId;
                res.RoleId = ctx.RoleId;
                res.RoleName = ctx.RoleName;
                res.Department = ctx.Department;
                res.CompanyName = ctx.CompanyName;
                res.CompanyId = ctx.CompanyId;
                res.DepartmentId = ctx.DepartmentId;
                res.Roles = ctx.Roles;

                // 1. Hitung Dokumen yang benar-benar memerlukan approval dari Role & Dept/Company user
                if (ctx.RoleIds.Any())
                {
                    const string sqlPendingCount = @"
                        SELECT COUNT(DISTINCT ra.id)
                        FROM public.request_approval ra
                        LEFT JOIN public.tb_permit p ON ra.req_id = p.req_id AND ra.module = 'PERMIT'
                        LEFT JOIN public.workflow w ON ra.workflow_id = w.id
                        WHERE ra.is_current_document = true 
                          AND ra.req_status = 'WAITING'
                          AND ra.req_role_id = ANY(@roleIds)
                          AND (ra.created_company_id = ANY(@companyIds) OR p.company_id = ANY(@companyIds))
                          AND (
                            w.is_by_department IS NOT TRUE 
                            OR ra.created_department_id = ANY(@deptIds) 
                            OR p.id_departemen = ANY(@deptIds)
                            OR TRIM(UPPER(p.departemen)) = TRIM(UPPER(@deptName))
                          );";

                    await using var cmdPending = new NpgsqlCommand(sqlPendingCount, conn);
                    cmdPending.Parameters.AddWithValue("@roleIds", ctx.RoleIds.ToArray());
                    cmdPending.Parameters.AddWithValue("@companyIds", ctx.CompanyIds.ToArray());
                    cmdPending.Parameters.AddWithValue("@deptIds", ctx.DepartmentIds.ToArray());
                    cmdPending.Parameters.AddWithValue("@deptName", ctx.Department ?? string.Empty);

                    var pCount = await cmdPending.ExecuteScalarAsync();
                    res.PendingCount = Convert.ToInt32(pCount ?? 0);
                }

                // 2. Hitung Proses Pengajuan di Departemen & Company Pengguna (atau buatan pengguna)
                var nikClean = nik.Trim();
                var nikTrimmed = nikClean.TrimStart('0');

                const string sqlSubCount = @"
                    SELECT COUNT(DISTINCT ra.req_id)
                    FROM public.request_approval ra
                    LEFT JOIN public.tb_permit p ON ra.req_id = p.req_id AND ra.module = 'PERMIT'
                    LEFT JOIN public.special_permit c ON ra.req_id = c.req_id AND ra.module = 'SPECIAL_PERMIT'
                    WHERE (ra.employee_id = @nikClean OR ra.employee_id = @nikTrimmed OR p.nik = @nikClean OR c.applicant_nik = @nikClean OR c.created_by = @nikClean)
                       OR (
                         (ra.created_company_id = ANY(@companyIds) OR p.company_id = ANY(@companyIds))
                         AND (
                           ra.created_department_id = ANY(@deptIds)
                           OR p.id_departemen = ANY(@deptIds)
                           OR TRIM(UPPER(p.departemen)) = TRIM(UPPER(@deptName))
                         )
                       );";

                await using var cmdSub = new NpgsqlCommand(sqlSubCount, conn);
                cmdSub.Parameters.AddWithValue("@nikClean", nikClean);
                cmdSub.Parameters.AddWithValue("@nikTrimmed", nikTrimmed);
                cmdSub.Parameters.AddWithValue("@companyIds", ctx.CompanyIds.ToArray());
                cmdSub.Parameters.AddWithValue("@deptIds", ctx.DepartmentIds.ToArray());
                cmdSub.Parameters.AddWithValue("@deptName", ctx.Department ?? string.Empty);

                var sCount = await cmdSub.ExecuteScalarAsync();
                res.MySubmissionCount = Convert.ToInt32(sCount ?? 0);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[BimaApprovalService] Error checking user status for {Nik}", nik);
            }

            return res;
        }

        public async Task<List<ApprovalItemDto>> GetPendingApprovalsAsync(string nik, string? module = null, int page = 1, int pageSize = 50)
        {
            var list = new List<ApprovalItemDto>();
            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return list;

            try
            {
                var ctx = await GetUserContextAsync(conn, nik);
                if (!ctx.IsRegistered || !ctx.RoleIds.Any()) return list;

                var sql = @"
                    SELECT DISTINCT ON (ra.id)
                           ra.id, ra.nomor, ra.req_id, ra.module, ra.level_approval, ra.req_status, ra.req_time,
                           ra.req_role_id, r.role_name, ra.employee_id,
                           COALESCE(p.nama, c.name_who_allowed, p2.nama, '') as applicant_name,
                           COALESCE(p.perusahaan, c.implementing_contractor, p2.perusahaan, '') as company_name,
                           COALESCE(p.departemen, c.department, p2.departemen, '') as department_name,
                           COALESCE(p.pengajuan, su.jenis_simper, c.activity_type, '') as submission_type,
                           COALESCE(su.kendaraan, c.work_location, p.tipe_pengajuan, '') as sub_detail,
                           ra.notes, ra.action_by, ra.action_by_name, ra.action_time
                    FROM public.request_approval ra
                    LEFT JOIN public.tb_role r ON ra.req_role_id = r.id
                    LEFT JOIN public.workflow w ON ra.workflow_id = w.id
                    LEFT JOIN public.tb_permit p ON ra.req_id = p.req_id AND ra.module = 'PERMIT'
                    LEFT JOIN public.tb_simper_unit su ON ra.req_id = su.req_id AND ra.module = 'SIMPER'
                    LEFT JOIN public.tb_simper s ON su.simper_id = s.id
                    LEFT JOIN public.tb_permit p2 ON s.permit_id = p2.id
                    LEFT JOIN public.special_permit c ON ra.req_id = c.req_id AND ra.module = 'SPECIAL_PERMIT'
                    WHERE ra.is_current_document = true 
                      AND ra.req_status = 'WAITING'
                      AND ra.req_role_id = ANY(@roleIds)
                      AND (ra.created_company_id = ANY(@companyIds) OR p.company_id = ANY(@companyIds))
                      AND (
                        w.is_by_department IS NOT TRUE 
                        OR ra.created_department_id = ANY(@deptIds) 
                        OR p.id_departemen = ANY(@deptIds)
                        OR TRIM(UPPER(p.departemen)) = TRIM(UPPER(@deptName))
                      )
                      " + (!string.IsNullOrWhiteSpace(module) && module != "ALL" ? "AND ra.module = @module" : "") + @"
                    ORDER BY ra.id DESC, ra.req_time DESC
                    OFFSET @offset LIMIT @limit;";

                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@roleIds", ctx.RoleIds.ToArray());
                cmd.Parameters.AddWithValue("@companyIds", ctx.CompanyIds.ToArray());
                cmd.Parameters.AddWithValue("@deptIds", ctx.DepartmentIds.ToArray());
                cmd.Parameters.AddWithValue("@deptName", ctx.Department ?? string.Empty);
                if (!string.IsNullOrWhiteSpace(module) && module != "ALL")
                {
                    cmd.Parameters.AddWithValue("@module", module.ToUpper());
                }
                cmd.Parameters.AddWithValue("@offset", (Math.Max(1, page) - 1) * pageSize);
                cmd.Parameters.AddWithValue("@limit", pageSize);

                await using var rdr = await cmd.ExecuteReaderAsync();
                while (await rdr.ReadAsync())
                {
                    list.Add(new ApprovalItemDto
                    {
                        ApprovalId = Convert.ToInt64(rdr.GetValue(0)),
                        Nomor = rdr.IsDBNull(1) ? string.Empty : rdr.GetString(1),
                        ReqId = rdr.IsDBNull(2) ? string.Empty : rdr.GetString(2),
                        Module = rdr.IsDBNull(3) ? string.Empty : rdr.GetString(3),
                        Level = rdr.IsDBNull(4) ? 1 : Convert.ToInt32(rdr.GetValue(4)),
                        ReqStatus = rdr.IsDBNull(5) ? string.Empty : rdr.GetString(5),
                        ReqTime = rdr.IsDBNull(6) ? null : rdr.GetDateTime(6),
                        RoleId = rdr.IsDBNull(7) ? null : Convert.ToInt32(rdr.GetValue(7)),
                        RoleName = rdr.IsDBNull(8) ? null : rdr.GetString(8),
                        ApplicantNik = rdr.IsDBNull(9) ? string.Empty : rdr.GetString(9),
                        ApplicantName = rdr.IsDBNull(10) ? string.Empty : rdr.GetString(10),
                        CompanyName = rdr.IsDBNull(11) ? string.Empty : rdr.GetString(11),
                        Department = rdr.IsDBNull(12) ? string.Empty : rdr.GetString(12),
                        SubmissionType = rdr.IsDBNull(13) ? string.Empty : rdr.GetString(13),
                        SubDetail = rdr.IsDBNull(14) ? null : rdr.GetString(14),
                        Notes = rdr.IsDBNull(15) ? null : rdr.GetString(15),
                        ActionBy = rdr.IsDBNull(16) ? null : rdr.GetString(16),
                        ActionByName = rdr.IsDBNull(17) ? null : rdr.GetString(17),
                        ActionTime = rdr.IsDBNull(18) ? null : rdr.GetDateTime(18),
                        IsCurrentDocument = true,
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[BimaApprovalService] Error fetching pending approvals for {Nik}", nik);
            }

            return list;
        }

        public async Task<List<ApprovalItemDto>> GetMySubmissionsAsync(string nik, string? module = null, int page = 1, int pageSize = 50)
        {
            var list = new List<ApprovalItemDto>();
            if (string.IsNullOrWhiteSpace(nik)) return list;

            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return list;

            try
            {
                var ctx = await GetUserContextAsync(conn, nik);
                if (!ctx.IsRegistered) return list;

                var nikClean = nik.Trim();
                var nikTrimmed = nikClean.TrimStart('0');

                var sql = @"
                    SELECT DISTINCT ON (ra.req_id)
                           ra.id, ra.nomor, ra.req_id, ra.module, ra.level_approval, ra.req_status, ra.req_time,
                           ra.req_role_id, r.role_name, ra.employee_id,
                           COALESCE(p.nama, c.name_who_allowed, p2.nama, '') as applicant_name,
                           COALESCE(p.perusahaan, c.implementing_contractor, p2.perusahaan, '') as company_name,
                           COALESCE(p.departemen, c.department, p2.departemen, '') as department_name,
                           COALESCE(p.pengajuan, su.jenis_simper, c.activity_type, '') as submission_type,
                           COALESCE(su.kendaraan, c.work_location, p.tipe_pengajuan, '') as sub_detail,
                           ra.notes, ra.action_by, ra.action_by_name, ra.action_time, ra.is_current_document
                    FROM public.request_approval ra
                    LEFT JOIN public.tb_role r ON ra.req_role_id = r.id
                    LEFT JOIN public.tb_permit p ON ra.req_id = p.req_id AND ra.module = 'PERMIT'
                    LEFT JOIN public.tb_simper_unit su ON ra.req_id = su.req_id AND ra.module = 'SIMPER'
                    LEFT JOIN public.tb_simper s ON su.simper_id = s.id
                    LEFT JOIN public.tb_permit p2 ON s.permit_id = p2.id
                    LEFT JOIN public.special_permit c ON ra.req_id = c.req_id AND ra.module = 'SPECIAL_PERMIT'
                    WHERE (
                        (ra.employee_id = @nikClean OR ra.employee_id = @nikTrimmed OR p.nik = @nikClean OR c.applicant_nik = @nikClean OR c.created_by = @nikClean)
                        OR (
                          (ra.created_company_id = ANY(@companyIds) OR p.company_id = ANY(@companyIds))
                          AND (
                            ra.created_department_id = ANY(@deptIds)
                            OR p.id_departemen = ANY(@deptIds)
                            OR TRIM(UPPER(p.departemen)) = TRIM(UPPER(@deptName))
                          )
                        )
                    )
                    " + (!string.IsNullOrWhiteSpace(module) && module != "ALL" ? "AND ra.module = @module" : "") + @"
                    ORDER BY ra.req_id, ra.id DESC
                    OFFSET @offset LIMIT @limit;";

                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@nikClean", nikClean);
                cmd.Parameters.AddWithValue("@nikTrimmed", nikTrimmed);
                cmd.Parameters.AddWithValue("@companyIds", ctx.CompanyIds.ToArray());
                cmd.Parameters.AddWithValue("@deptIds", ctx.DepartmentIds.ToArray());
                cmd.Parameters.AddWithValue("@deptName", ctx.Department ?? string.Empty);
                if (!string.IsNullOrWhiteSpace(module) && module != "ALL")
                {
                    cmd.Parameters.AddWithValue("@module", module.ToUpper());
                }
                cmd.Parameters.AddWithValue("@offset", (Math.Max(1, page) - 1) * pageSize);
                cmd.Parameters.AddWithValue("@limit", pageSize);

                await using var rdr = await cmd.ExecuteReaderAsync();
                while (await rdr.ReadAsync())
                {
                    list.Add(new ApprovalItemDto
                    {
                        ApprovalId = Convert.ToInt64(rdr.GetValue(0)),
                        Nomor = rdr.IsDBNull(1) ? string.Empty : rdr.GetString(1),
                        ReqId = rdr.IsDBNull(2) ? string.Empty : rdr.GetString(2),
                        Module = rdr.IsDBNull(3) ? string.Empty : rdr.GetString(3),
                        Level = rdr.IsDBNull(4) ? 1 : Convert.ToInt32(rdr.GetValue(4)),
                        ReqStatus = rdr.IsDBNull(5) ? string.Empty : rdr.GetString(5),
                        ReqTime = rdr.IsDBNull(6) ? null : rdr.GetDateTime(6),
                        RoleId = rdr.IsDBNull(7) ? null : Convert.ToInt32(rdr.GetValue(7)),
                        RoleName = rdr.IsDBNull(8) ? null : rdr.GetString(8),
                        ApplicantNik = rdr.IsDBNull(9) ? string.Empty : rdr.GetString(9),
                        ApplicantName = rdr.IsDBNull(10) ? string.Empty : rdr.GetString(10),
                        CompanyName = rdr.IsDBNull(11) ? string.Empty : rdr.GetString(11),
                        Department = rdr.IsDBNull(12) ? string.Empty : rdr.GetString(12),
                        SubmissionType = rdr.IsDBNull(13) ? string.Empty : rdr.GetString(13),
                        SubDetail = rdr.IsDBNull(14) ? null : rdr.GetString(14),
                        Notes = rdr.IsDBNull(15) ? null : rdr.GetString(15),
                        ActionBy = rdr.IsDBNull(16) ? null : rdr.GetString(16),
                        ActionByName = rdr.IsDBNull(17) ? null : rdr.GetString(17),
                        ActionTime = rdr.IsDBNull(18) ? null : rdr.GetDateTime(18),
                        IsCurrentDocument = !rdr.IsDBNull(19) && rdr.GetBoolean(19),
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[BimaApprovalService] Error fetching submissions for {Nik}", nik);
            }

            return list;
        }

        public async Task<ApprovalDetailDto?> GetApprovalDetailAsync(long approvalId, string? callerNik = null)
        {
            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return null;

            try
            {
                // 1. Get header
                const string sqlHeader = @"
                    SELECT DISTINCT ON (ra.id)
                           ra.id, ra.nomor, ra.req_id, ra.module, ra.level_approval, ra.req_status, ra.req_time,
                           ra.req_role_id, r.role_name, ra.employee_id,
                           COALESCE(p.nama, c.name_who_allowed, p2.nama, '') as applicant_name,
                           COALESCE(p.perusahaan, c.implementing_contractor, p2.perusahaan, '') as company_name,
                           COALESCE(p.departemen, c.department, p2.departemen, '') as department_name,
                           COALESCE(p.pengajuan, su.jenis_simper, c.activity_type, '') as submission_type,
                           COALESCE(su.kendaraan, c.work_location, p.tipe_pengajuan, '') as sub_detail,
                           ra.notes, ra.action_by, ra.action_by_name, ra.action_time, ra.is_current_document,
                           p.id as permit_id, s.id as simper_id, c.id as special_permit_id,
                           w.is_by_department, ra.created_company_id, ra.created_department_id
                    FROM public.request_approval ra
                    LEFT JOIN public.tb_role r ON ra.req_role_id = r.id
                    LEFT JOIN public.workflow w ON ra.workflow_id = w.id
                    LEFT JOIN public.tb_permit p ON ra.req_id = p.req_id AND ra.module = 'PERMIT'
                    LEFT JOIN public.tb_simper_unit su ON ra.req_id = su.req_id AND ra.module = 'SIMPER'
                    LEFT JOIN public.tb_simper s ON su.simper_id = s.id
                    LEFT JOIN public.tb_permit p2 ON s.permit_id = p2.id
                    LEFT JOIN public.special_permit c ON ra.req_id = c.req_id AND ra.module = 'SPECIAL_PERMIT'
                    WHERE ra.id = @id
                    LIMIT 1;";

                await using var cmdHeader = new NpgsqlCommand(sqlHeader, conn);
                cmdHeader.Parameters.AddWithValue("@id", approvalId);

                await using var rdr = await cmdHeader.ExecuteReaderAsync();
                if (!await rdr.ReadAsync()) return null;

                var detail = new ApprovalDetailDto
                {
                    Header = new ApprovalItemDto
                    {
                        ApprovalId = Convert.ToInt64(rdr.GetValue(0)),
                        Nomor = rdr.IsDBNull(1) ? string.Empty : rdr.GetString(1),
                        ReqId = rdr.IsDBNull(2) ? string.Empty : rdr.GetString(2),
                        Module = rdr.IsDBNull(3) ? string.Empty : rdr.GetString(3),
                        Level = rdr.IsDBNull(4) ? 1 : Convert.ToInt32(rdr.GetValue(4)),
                        ReqStatus = rdr.IsDBNull(5) ? string.Empty : rdr.GetString(5),
                        ReqTime = rdr.IsDBNull(6) ? null : rdr.GetDateTime(6),
                        RoleId = rdr.IsDBNull(7) ? null : Convert.ToInt32(rdr.GetValue(7)),
                        RoleName = rdr.IsDBNull(8) ? null : rdr.GetString(8),
                        ApplicantNik = rdr.IsDBNull(9) ? string.Empty : rdr.GetString(9),
                        ApplicantName = rdr.IsDBNull(10) ? string.Empty : rdr.GetString(10),
                        CompanyName = rdr.IsDBNull(11) ? string.Empty : rdr.GetString(11),
                        Department = rdr.IsDBNull(12) ? string.Empty : rdr.GetString(12),
                        SubmissionType = rdr.IsDBNull(13) ? string.Empty : rdr.GetString(13),
                        SubDetail = rdr.IsDBNull(14) ? null : rdr.GetString(14),
                        Notes = rdr.IsDBNull(15) ? null : rdr.GetString(15),
                        ActionBy = rdr.IsDBNull(16) ? null : rdr.GetString(16),
                        ActionByName = rdr.IsDBNull(17) ? null : rdr.GetString(17),
                        ActionTime = rdr.IsDBNull(18) ? null : rdr.GetDateTime(18),
                        IsCurrentDocument = !rdr.IsDBNull(19) && rdr.GetBoolean(19),
                    }
                };

                long? permitId = rdr.IsDBNull(20) ? null : Convert.ToInt64(rdr.GetValue(20));
                long? simperId = rdr.IsDBNull(21) ? null : Convert.ToInt64(rdr.GetValue(21));
                string? specialPermitId = rdr.IsDBNull(22) ? null : rdr.GetString(22);
                bool? isByDept = rdr.IsDBNull(23) ? null : rdr.GetBoolean(23);
                long? createdCompId = rdr.IsDBNull(24) ? null : Convert.ToInt64(rdr.GetValue(24));
                long? createdDeptId = rdr.IsDBNull(25) ? null : Convert.ToInt64(rdr.GetValue(25));
                await rdr.CloseAsync();

                // Cek apakah pemanggil memiliki hak approval untuk dokumen ini
                if (!string.IsNullOrWhiteSpace(callerNik) && detail.Header.IsCurrentDocument && detail.Header.ReqStatus == "WAITING")
                {
                    var callerCtx = await GetUserContextAsync(conn, callerNik);
                    if (callerCtx.IsRegistered && detail.Header.RoleId.HasValue)
                    {
                        bool roleMatches = callerCtx.RoleIds.Contains(detail.Header.RoleId.Value);
                        bool compMatches = createdCompId == null || callerCtx.CompanyIds.Contains(createdCompId.Value);
                        bool deptMatches = isByDept != true || createdDeptId == null || callerCtx.DepartmentIds.Contains(createdDeptId.Value) || (detail.Header.Department.Equals(callerCtx.Department, StringComparison.OrdinalIgnoreCase));

                        detail.CanApprove = roleMatches && compMatches && deptMatches;
                    }
                }

                // 2. Get History Timeline
                const string sqlHistory = @"
                    SELECT ra.id, ra.level_approval, ra.req_status, ra.req_role_id, r.role_name,
                           ra.action_by, ra.action_by_name, ra.action_time, ra.notes
                    FROM public.request_approval ra
                    LEFT JOIN public.tb_role r ON ra.req_role_id = r.id
                    WHERE ra.req_id = @reqId
                    ORDER BY ra.id ASC;";

                await using var cmdHist = new NpgsqlCommand(sqlHistory, conn);
                cmdHist.Parameters.AddWithValue("@reqId", detail.Header.ReqId);
                await using var rdrHist = await cmdHist.ExecuteReaderAsync();
                while (await rdrHist.ReadAsync())
                {
                    detail.History.Add(new ApprovalHistoryItemDto
                    {
                        Id = Convert.ToInt64(rdrHist.GetValue(0)),
                        LevelApproval = Convert.ToInt32(rdrHist.GetValue(1)),
                        ReqStatus = rdrHist.IsDBNull(2) ? string.Empty : rdrHist.GetString(2),
                        RoleId = rdrHist.IsDBNull(3) ? null : Convert.ToInt32(rdrHist.GetValue(3)),
                        RoleName = rdrHist.IsDBNull(4) ? string.Empty : rdrHist.GetString(4),
                        ActionBy = rdrHist.IsDBNull(5) ? null : rdrHist.GetString(5),
                        ActionByName = rdrHist.IsDBNull(6) ? null : rdrHist.GetString(6),
                        ActionTime = rdrHist.IsDBNull(7) ? null : rdrHist.GetDateTime(7),
                        Notes = rdrHist.IsDBNull(8) ? null : rdrHist.GetString(8),
                    });
                }
                await rdrHist.CloseAsync();

                // 3. Get Documents
                if (detail.Header.Module == "PERMIT" && permitId.HasValue)
                {
                    const string sqlDoc = @"
                        SELECT id, document_name, file_name, file_type, file_path, created_at
                        FROM public.tb_permit_doc
                        WHERE permit_id = @docId AND deleted_at IS NULL;";
                    await using var cmdDoc = new NpgsqlCommand(sqlDoc, conn);
                    cmdDoc.Parameters.AddWithValue("@docId", permitId.Value);
                    await using var rdrDoc = await cmdDoc.ExecuteReaderAsync();
                    while (await rdrDoc.ReadAsync())
                    {
                        detail.Documents.Add(new ApprovalDocItemDto
                        {
                            Id = Convert.ToInt64(rdrDoc.GetValue(0)),
                            DocumentName = rdrDoc.IsDBNull(1) ? string.Empty : rdrDoc.GetString(1),
                            FileName = rdrDoc.IsDBNull(2) ? string.Empty : rdrDoc.GetString(2),
                            FileType = rdrDoc.IsDBNull(3) ? null : rdrDoc.GetString(3),
                            FilePath = rdrDoc.IsDBNull(4) ? null : rdrDoc.GetString(4),
                            CreatedAt = rdrDoc.IsDBNull(5) ? null : rdrDoc.GetDateTime(5),
                        });
                    }
                    await rdrDoc.CloseAsync();
                }
                else if (detail.Header.Module == "SIMPER" && simperId.HasValue)
                {
                    const string sqlDoc = @"
                        SELECT id, document_name, file_name, file_type, file_path, created_at
                        FROM public.tb_simper_doc
                        WHERE simper_id = @docId AND deleted_at IS NULL;";
                    await using var cmdDoc = new NpgsqlCommand(sqlDoc, conn);
                    cmdDoc.Parameters.AddWithValue("@docId", simperId.Value);
                    await using var rdrDoc = await cmdDoc.ExecuteReaderAsync();
                    while (await rdrDoc.ReadAsync())
                    {
                        detail.Documents.Add(new ApprovalDocItemDto
                        {
                            Id = Convert.ToInt64(rdrDoc.GetValue(0)),
                            DocumentName = rdrDoc.IsDBNull(1) ? string.Empty : rdrDoc.GetString(1),
                            FileName = rdrDoc.IsDBNull(2) ? string.Empty : rdrDoc.GetString(2),
                            FileType = rdrDoc.IsDBNull(3) ? null : rdrDoc.GetString(3),
                            FilePath = rdrDoc.IsDBNull(4) ? null : rdrDoc.GetString(4),
                            CreatedAt = rdrDoc.IsDBNull(5) ? null : rdrDoc.GetDateTime(5),
                        });
                    }
                    await rdrDoc.CloseAsync();
                }

                return detail;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[BimaApprovalService] Error fetching detail for approval {Id}", approvalId);
                return null;
            }
        }

        public async Task<ApprovalActionResponseDto> ProcessApprovalActionAsync(ApprovalActionRequestDto req)
        {
            var res = new ApprovalActionResponseDto { Success = false };

            if (req.ApprovalId <= 0)
            {
                res.Message = "Invalid approval ID";
                return res;
            }

            var actionUpper = req.Action.Trim().ToUpper();
            if (actionUpper != "APPROVED" && actionUpper != "REJECTED")
            {
                res.Message = "Action must be APPROVED or REJECTED";
                return res;
            }

            await using var conn = await GetBimaConnectionAsync();
            if (conn == null)
            {
                res.Message = "Database connection failed";
                return res;
            }

            // Validasi hak akses approver
            if (string.IsNullOrWhiteSpace(req.UserNik))
            {
                res.Message = "NIK / NRP approver wajib diisi untuk memproses approval.";
                return res;
            }

            var callerCtx = await GetUserContextAsync(conn, req.UserNik);
            if (!callerCtx.IsRegistered)
            {
                res.Message = "Anda tidak memiliki otorisasi approval di Bima (Akun tidak terdaftar atau tidak aktif).";
                return res;
            }

            await using var tran = await conn.BeginTransactionAsync();
            try
            {
                // 1. Fetch current approval record with lock
                const string sqlCur = @"
                    SELECT ra.id, ra.nomor, ra.req_id, ra.module, ra.level_approval, ra.workflow_id, ra.employee_id,
                           ra.created_company_id, ra.created_department_id, ra.is_current_document, ra.req_status, ra.req_role_id,
                           w.is_by_department, r.role_name,
                           COALESCE(p.departemen, c.department, p2.departemen, '') as applicant_dept
                    FROM public.request_approval ra
                    LEFT JOIN public.workflow w ON ra.workflow_id = w.id
                    LEFT JOIN public.tb_role r ON ra.req_role_id = r.id
                    LEFT JOIN public.tb_permit p ON ra.module = 'PERMIT' AND ra.req_id = p.req_id
                    LEFT JOIN public.tb_simper_unit su ON ra.module = 'SIMPER' AND ra.req_id = su.req_id
                    LEFT JOIN public.tb_simper s ON su.simper_id = s.id
                    LEFT JOIN public.tb_permit p2 ON s.permit_id = p2.id
                    LEFT JOIN public.special_permit c ON ra.req_id = c.req_id AND ra.module = 'SPECIAL_PERMIT'
                    WHERE ra.id = @id
                    FOR UPDATE OF ra;";

                await using var cmdCur = new NpgsqlCommand(sqlCur, conn, tran);
                cmdCur.Parameters.AddWithValue("@id", req.ApprovalId);
                await using var rdrCur = await cmdCur.ExecuteReaderAsync();
                if (!await rdrCur.ReadAsync())
                {
                    res.Message = "Dokumen approval tidak ditemukan";
                    return res;
                }

                var nomor = rdrCur.IsDBNull(1) ? string.Empty : rdrCur.GetString(1);
                var reqId = rdrCur.IsDBNull(2) ? string.Empty : rdrCur.GetString(2);
                var module = rdrCur.IsDBNull(3) ? string.Empty : rdrCur.GetString(3);
                var level = rdrCur.IsDBNull(4) ? 1 : Convert.ToInt32(rdrCur.GetValue(4));
                var workflowId = rdrCur.IsDBNull(5) ? (long?)null : Convert.ToInt64(rdrCur.GetValue(5));
                var empId = rdrCur.IsDBNull(6) ? string.Empty : rdrCur.GetString(6);
                var compId = rdrCur.IsDBNull(7) ? (long?)null : Convert.ToInt64(rdrCur.GetValue(7));
                var deptId = rdrCur.IsDBNull(8) ? (long?)null : Convert.ToInt64(rdrCur.GetValue(8));
                var isCurrent = !rdrCur.IsDBNull(9) && rdrCur.GetBoolean(9);
                var currentStatus = rdrCur.IsDBNull(10) ? string.Empty : rdrCur.GetString(10);
                var reqRoleId = rdrCur.IsDBNull(11) ? (long?)null : Convert.ToInt64(rdrCur.GetValue(11));
                var isByDept = rdrCur.IsDBNull(12) ? (bool?)null : rdrCur.GetBoolean(12);
                var roleName = rdrCur.IsDBNull(13) ? string.Empty : rdrCur.GetString(13);
                var applicantDept = rdrCur.IsDBNull(14) ? string.Empty : rdrCur.GetString(14);
                await rdrCur.CloseAsync();

                if (!isCurrent || currentStatus != "WAITING")
                {
                    res.Message = "Dokumen ini sudah diproses sebelumnya atau bukan tahapan aktif.";
                    return res;
                }

                // VALIDASI KEWENANGAN APPROVER SECARA KETAT
                // 1. Role validation: pastikan approver memiliki role yang disyaratkan oleh level ini
                if (!reqRoleId.HasValue || !callerCtx.RoleIds.Contains(reqRoleId.Value))
                {
                    var neededRole = !string.IsNullOrEmpty(roleName) ? roleName : $"Role ID {reqRoleId}";
                    res.Message = $"Anda tidak memiliki wewenang untuk menyetujui tahap ini. Tahap ini memerlukan peran: {neededRole}.";
                    return res;
                }

                // 2. Company validation
                if (compId.HasValue && !callerCtx.CompanyIds.Contains(compId.Value))
                {
                    res.Message = "Anda tidak memiliki wewenang untuk menyetujui dokumen dari perusahaan ini.";
                    return res;
                }

                // 3. Department validation (jika alur kerja berbasis departemen)
                if (isByDept == true)
                {
                    bool deptMatches = (deptId.HasValue && callerCtx.DepartmentIds.Contains(deptId.Value)) ||
                                       (!string.IsNullOrEmpty(applicantDept) && !string.IsNullOrEmpty(callerCtx.Department) &&
                                        applicantDept.Equals(callerCtx.Department, StringComparison.OrdinalIgnoreCase));
                    if (!deptMatches)
                    {
                        res.Message = "Anda tidak memiliki wewenang untuk menyetujui dokumen dari departemen ini.";
                        return res;
                    }
                }

                // 2. Mark current record as processed
                const string sqlUpdateCur = @"
                    UPDATE public.request_approval
                    SET is_current_document = false,
                        req_status = @action,
                        action_by = @actionBy,
                        action_by_name = @actionByName,
                        action_time = NOW(),
                        notes = @notes
                    WHERE id = @id;";

                await using var cmdUp = new NpgsqlCommand(sqlUpdateCur, conn, tran);
                cmdUp.Parameters.AddWithValue("@action", actionUpper);
                cmdUp.Parameters.AddWithValue("@actionBy", req.UserNik ?? string.Empty);
                cmdUp.Parameters.AddWithValue("@actionByName", req.UserName ?? string.Empty);
                cmdUp.Parameters.AddWithValue("@notes", (object?)req.Notes ?? DBNull.Value);
                cmdUp.Parameters.AddWithValue("@id", req.ApprovalId);
                await cmdUp.ExecuteNonQueryAsync();

                if (actionUpper == "REJECTED")
                {
                    // Update underlying document to REJECTED or CLOSED
                    if (module == "PERMIT")
                    {
                        const string sqlRejPermit = "UPDATE public.tb_permit SET status = 'REJECTED' WHERE req_id = @reqId;";
                        await using var cmd = new NpgsqlCommand(sqlRejPermit, conn, tran);
                        cmd.Parameters.AddWithValue("@reqId", reqId);
                        await cmd.ExecuteNonQueryAsync();
                    }
                    else if (module == "SIMPER")
                    {
                        const string sqlRejSimper = @"
                            UPDATE public.tb_simper SET status = 'REJECTED'
                            WHERE id = (SELECT simper_id FROM public.tb_simper_unit WHERE req_id = @reqId LIMIT 1);";
                        await using var cmd = new NpgsqlCommand(sqlRejSimper, conn, tran);
                        cmd.Parameters.AddWithValue("@reqId", reqId);
                        await cmd.ExecuteNonQueryAsync();
                    }
                    else if (module == "SPECIAL_PERMIT")
                    {
                        const string sqlRejSp = "UPDATE public.special_permit SET status = 'REJECTED' WHERE req_id = @reqId;";
                        await using var cmd = new NpgsqlCommand(sqlRejSp, conn, tran);
                        cmd.Parameters.AddWithValue("@reqId", reqId);
                        await cmd.ExecuteNonQueryAsync();
                    }

                    await tran.CommitAsync();
                    res.Success = true;
                    res.Message = "Pengajuan berhasil ditolak (REJECTED)";
                    res.NextStatus = "REJECTED";
                    return res;
                }

                // If APPROVED: determine next workflow step
                const string sqlWorkflows = @"
                    SELECT id, role_id, step_level, workflow_name, is_by_department, company_id
                    FROM public.workflow
                    WHERE module_name = @module
                      AND (company_id = @compId OR company_id = 1 OR company_id = 0)
                    ORDER BY (CASE WHEN company_id = @compId THEN 0 WHEN company_id = 1 THEN 1 ELSE 2 END) ASC, step_level ASC;";

                await using var cmdWf = new NpgsqlCommand(sqlWorkflows, conn, tran);
                cmdWf.Parameters.AddWithValue("@module", module);
                cmdWf.Parameters.AddWithValue("@compId", compId ?? 1);

                var allWfs = new List<(long Id, long RoleId, long StepLevel, string Name, bool? IsByDept, long CompanyId)>();
                await using var rdrWf = await cmdWf.ExecuteReaderAsync();
                while (await rdrWf.ReadAsync())
                {
                    allWfs.Add((
                        Convert.ToInt64(rdrWf.GetValue(0)),
                        Convert.ToInt64(rdrWf.GetValue(1)),
                        Convert.ToInt64(rdrWf.GetValue(2)),
                        rdrWf.GetString(3),
                        rdrWf.IsDBNull(4) ? null : rdrWf.GetBoolean(4),
                        Convert.ToInt64(rdrWf.GetValue(5))
                    ));
                }
                await rdrWf.CloseAsync();

                // Prioritaskan konfigurasi workflow spesifik milik perusahaan pemohon
                var targetCompId = compId ?? 1;
                var workflows = allWfs.Where(w => w.CompanyId == targetCompId).ToList();
                if (!workflows.Any())
                {
                    workflows = allWfs.Where(w => w.CompanyId == 1).ToList();
                }
                if (!workflows.Any())
                {
                    workflows = allWfs.Where(w => w.CompanyId == 0).ToList();
                }

                var maxStepLevel = workflows.Any() ? workflows.Max(w => w.StepLevel) : 0;
                var nextStepLevel = level + 1;
                var nextWf = workflows.FirstOrDefault(w => w.StepLevel == nextStepLevel);

                if (nextWf.Id > 0)
                {
                    // Create next approval record
                    const string sqlInsertNext = @"
                        INSERT INTO public.request_approval (
                            module, nomor, req_id, req_time, workflow_id,
                            req_status, status_approval, is_current_document,
                            level_approval, employee_id, req_role_id,
                            created_company_id, created_department_id
                        ) VALUES (
                            @module, @nomor, @reqId, NOW(), @wfId,
                            'WAITING', 'APPROVED', true,
                            @nextLevel, @empId, @roleId,
                            @compId, @deptId
                        );";

                    await using var cmdNext = new NpgsqlCommand(sqlInsertNext, conn, tran);
                    cmdNext.Parameters.AddWithValue("@module", module);
                    cmdNext.Parameters.AddWithValue("@nomor", nomor);
                    cmdNext.Parameters.AddWithValue("@reqId", reqId);
                    cmdNext.Parameters.AddWithValue("@wfId", nextWf.Id);
                    cmdNext.Parameters.AddWithValue("@nextLevel", nextStepLevel);
                    cmdNext.Parameters.AddWithValue("@empId", empId);
                    cmdNext.Parameters.AddWithValue("@roleId", nextWf.RoleId);
                    cmdNext.Parameters.AddWithValue("@compId", (object?)compId ?? DBNull.Value);
                    cmdNext.Parameters.AddWithValue("@deptId", (object?)deptId ?? DBNull.Value);
                    await cmdNext.ExecuteNonQueryAsync();

                    await tran.CommitAsync();
                    res.Success = true;
                    res.Message = $"Pengajuan disetujui dan dilanjutkan ke Level {nextStepLevel} ({nextWf.Name})";
                    res.NextLevel = nextStepLevel;
                    res.NextStatus = "WAITING";
                    return res;
                }
                else if (level >= maxStepLevel && maxStepLevel > 0)
                {
                    // Final level reached: document is READY_TO_PRINT
                    if (module == "PERMIT")
                    {
                        const string sqlFinalPermit = "UPDATE public.tb_permit SET status = 'READY_TO_PRINT' WHERE req_id = @reqId;";
                        await using var cmd = new NpgsqlCommand(sqlFinalPermit, conn, tran);
                        cmd.Parameters.AddWithValue("@reqId", reqId);
                        await cmd.ExecuteNonQueryAsync();
                    }
                    else if (module == "SIMPER")
                    {
                        const string sqlFinalSimper = @"
                            UPDATE public.tb_simper SET status = 'READY_TO_PRINT'
                            WHERE id = (SELECT simper_id FROM public.tb_simper_unit WHERE req_id = @reqId LIMIT 1);";
                        await using var cmd = new NpgsqlCommand(sqlFinalSimper, conn, tran);
                        cmd.Parameters.AddWithValue("@reqId", reqId);
                        await cmd.ExecuteNonQueryAsync();
                    }
                    else if (module == "SPECIAL_PERMIT")
                    {
                        const string sqlFinalSp = "UPDATE public.special_permit SET status = 'READY_TO_PRINT' WHERE req_id = @reqId;";
                        await using var cmd = new NpgsqlCommand(sqlFinalSp, conn, tran);
                        cmd.Parameters.AddWithValue("@reqId", reqId);
                        await cmd.ExecuteNonQueryAsync();
                    }

                    await tran.CommitAsync();
                    res.Success = true;
                    res.Message = "Approval selesai (Semua tahap disetujui, siap cetak)";
                    res.NextStatus = "READY_TO_PRINT";
                    return res;
                }
                else
                {
                    await tran.RollbackAsync();
                    res.Success = false;
                    res.Message = $"Tahapan workflow berikutnya (Level {nextStepLevel}) tidak ditemukan untuk modul {module}. Hubungi administrator.";
                    return res;
                }
            }
            catch (Exception ex)
            {
                await tran.RollbackAsync();
                _logger.LogError(ex, "[BimaApprovalService] Error executing approval action for {ApprovalId}", req.ApprovalId);
                res.Message = "Gagal memproses approval: " + ex.Message;
                return res;
            }
        }

        public async Task<BatchApprovalActionResultDto> ProcessBatchApprovalActionAsync(BatchApprovalActionRequestDto req)
        {
            var res = new BatchApprovalActionResultDto
            {
                TotalRequested = req.ApprovalIds?.Count ?? 0
            };

            if (req.ApprovalIds == null || !req.ApprovalIds.Any())
            {
                res.Message = "Tidak ada dokumen approval yang dipilih.";
                return res;
            }

            foreach (var approvalId in req.ApprovalIds)
            {
                try
                {
                    var singleReq = new ApprovalActionRequestDto
                    {
                        ApprovalId = approvalId,
                        Action = req.Action ?? "APPROVED",
                        Notes = req.Notes ?? "Disetujui secara bersamaan (Batch Approval)",
                        UserNik = req.UserNik,
                        UserName = req.UserName
                    };

                    var singleRes = await ProcessApprovalActionAsync(singleReq);
                    if (singleRes.Success)
                    {
                        res.TotalSuccess++;
                    }
                    else
                    {
                        res.TotalFailed++;
                        res.Errors.Add($"Dokumen #{approvalId}: {singleRes.Message}");
                    }
                }
                catch (Exception ex)
                {
                    res.TotalFailed++;
                    res.Errors.Add($"Dokumen #{approvalId}: {ex.Message}");
                }
            }

            res.Success = res.TotalSuccess > 0;
            res.Message = $"Selesai memproses: {res.TotalSuccess} berhasil, {res.TotalFailed} gagal dari {res.TotalRequested} dokumen.";
            return res;
        }
    }
}

