using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Indexsafe.Api.DTOs;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace Indexsafe.Api.Services
{
    public class SpecialPermitService
    {
        private readonly ILogger<SpecialPermitService> _logger;
        private readonly IConfiguration _config;
        private readonly IWebHostEnvironment _env;
        private readonly string[] _candidateHosts = new[] { "172.16.1.96", "172.16.1.93" };
        private const string User = "postgres";
        private const string Pass = "index.123";

        public SpecialPermitService(
            ILogger<SpecialPermitService> logger,
            IConfiguration config,
            IWebHostEnvironment env)
        {
            _logger = logger;
            _config = config;
            _env = env;
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

                        await using var checkCmd = new NpgsqlCommand("SELECT to_regclass('public.special_permit')::text;", conn);
                        var reg = await checkCmd.ExecuteScalarAsync();
                        if (reg != null && reg != DBNull.Value && !string.IsNullOrWhiteSpace(reg.ToString()))
                        {
                            return conn;
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

        public async Task<List<SpecialPermitItemDto>> GetSpecialPermitsAsync(string? nik, string? status = null, string? search = null)
        {
            var list = new List<SpecialPermitItemDto>();
            if (string.IsNullOrWhiteSpace(nik)) return list;

            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return list;

            try
            {
                var nikClean = nik.Trim();
                var nikTrimmed = nikClean.TrimStart('0');

                var sql = @"
                    SELECT sp.id, sp.req_id, sp.activity_type, sp.status, sp.issue_date, sp.issue_time::text,
                           sp.pjo_nik, sp.pjo_name, sp.inspector_nik, sp.inspector_name,
                           sp.department_id, sp.department, sp.company_id, sp.company_name,
                           sp.implementing_contractor, sp.applicant_nik, sp.applicant_name,
                           sp.work_location, sp.phone, sp.responsible_person_nik, sp.responsible_person_name,
                           sp.start_date, sp.end_date, sp.job_description, sp.special_equipment, sp.work_related_hazard,
                           COALESCE(f.followup_count, 0) AS total_followups,
                           f.latest_status,
                           f.latest_time,
                           f.latest_inspector_nik,
                           f.latest_inspector_name,
                           f.latest_inspector_role
                    FROM public.special_permit sp
                    LEFT JOIN (
                        SELECT special_permit_id,
                               COUNT(*) AS followup_count,
                               MAX(inspection_time) AS latest_time,
                               (ARRAY_AGG(inspection_status ORDER BY id DESC))[1] AS latest_status,
                               (ARRAY_AGG(inspector_nik ORDER BY id DESC))[1] AS latest_inspector_nik,
                               (ARRAY_AGG(inspector_name ORDER BY id DESC))[1] AS latest_inspector_name,
                               (ARRAY_AGG(inspector_role ORDER BY id DESC))[1] AS latest_inspector_role
                        FROM public.tbl_m_folloup_special_permit
                        GROUP BY special_permit_id
                    ) f ON sp.id = f.special_permit_id
                    WHERE (
                        (NULLIF(TRIM(sp.pjo_nik), '') = @nikClean OR NULLIF(TRIM(sp.pjo_nik), '') = @nikTrimmed) OR
                        (NULLIF(TRIM(sp.inspector_nik), '') = @nikClean OR NULLIF(TRIM(sp.inspector_nik), '') = @nikTrimmed)
                    ) ";

                var parameters = new List<NpgsqlParameter>
                {
                    new NpgsqlParameter("@nikClean", nikClean),
                    new NpgsqlParameter("@nikTrimmed", nikTrimmed)
                };

                if (!string.IsNullOrWhiteSpace(status) && status.ToUpper() != "ALL")
                {
                    sql += " AND UPPER(sp.status) = @status ";
                    parameters.Add(new NpgsqlParameter("@status", status.ToUpper()));
                }

                if (!string.IsNullOrWhiteSpace(search))
                {
                    sql += @" AND (
                        sp.req_id ILIKE @search OR
                        sp.activity_type ILIKE @search OR
                        sp.work_location ILIKE @search OR
                        sp.implementing_contractor ILIKE @search OR
                        sp.applicant_name ILIKE @search
                    ) ";
                    parameters.Add(new NpgsqlParameter("@search", $"%{search.Trim()}%"));
                }

                sql += " ORDER BY sp.created_at DESC NULLS LAST LIMIT 100;";

                await using var cmd = new NpgsqlCommand(sql, conn);
                foreach (var p in parameters) cmd.Parameters.Add(p);

                await using var rdr = await cmd.ExecuteReaderAsync();
                while (await rdr.ReadAsync())
                {
                    var item = new SpecialPermitItemDto
                    {
                        Id = rdr.IsDBNull(0) ? string.Empty : rdr.GetString(0),
                        ReqId = rdr.IsDBNull(1) ? string.Empty : rdr.GetString(1),
                        ActivityType = rdr.IsDBNull(2) ? string.Empty : rdr.GetString(2),
                        Status = rdr.IsDBNull(3) ? string.Empty : rdr.GetString(3),
                        IssueDate = rdr.IsDBNull(4) ? (DateTime?)null : rdr.GetDateTime(4),
                        IssueTime = rdr.IsDBNull(5) ? null : rdr.GetString(5),
                        PjoNik = rdr.IsDBNull(6) ? null : rdr.GetString(6),
                        PjoName = rdr.IsDBNull(7) ? null : rdr.GetString(7),
                        InspectorNik = rdr.IsDBNull(8) ? null : rdr.GetString(8),
                        InspectorName = rdr.IsDBNull(9) ? null : rdr.GetString(9),
                        DepartmentId = rdr.IsDBNull(10) ? null : Convert.ToInt32(rdr.GetValue(10)),
                        Department = rdr.IsDBNull(11) ? null : rdr.GetString(11),
                        CompanyId = rdr.IsDBNull(12) ? null : Convert.ToInt32(rdr.GetValue(12)),
                        CompanyName = rdr.IsDBNull(13) ? null : rdr.GetString(13),
                        ImplementingContractor = rdr.IsDBNull(14) ? null : rdr.GetString(14),
                        ApplicantNik = rdr.IsDBNull(15) ? null : rdr.GetString(15),
                        ApplicantName = rdr.IsDBNull(16) ? null : rdr.GetString(16),
                        WorkLocation = rdr.IsDBNull(17) ? null : rdr.GetString(17),
                        Phone = rdr.IsDBNull(18) ? null : rdr.GetString(18),
                        ResponsiblePersonNik = rdr.IsDBNull(19) ? null : rdr.GetString(19),
                        ResponsiblePersonName = rdr.IsDBNull(20) ? null : rdr.GetString(20),
                        StartDate = rdr.IsDBNull(21) ? (DateTime?)null : rdr.GetDateTime(21),
                        EndDate = rdr.IsDBNull(22) ? (DateTime?)null : rdr.GetDateTime(22),
                        JobDescription = rdr.IsDBNull(23) ? null : rdr.GetString(23),
                        SpecialEquipment = rdr.IsDBNull(24) ? null : rdr.GetString(24),
                        WorkRelatedHazard = rdr.IsDBNull(25) ? null : rdr.GetString(25),
                        TotalFollowups = rdr.IsDBNull(26) ? 0 : Convert.ToInt32(rdr.GetValue(26)),
                        LatestInspectionStatus = rdr.IsDBNull(27) ? null : rdr.GetString(27),
                        LatestInspectionTime = rdr.IsDBNull(28) ? (DateTime?)null : rdr.GetDateTime(28),
                        LatestInspectorNik = rdr.IsDBNull(29) ? null : rdr.GetString(29),
                        LatestInspectorName = rdr.IsDBNull(30) ? null : rdr.GetString(30),
                        LatestInspectorRole = rdr.IsDBNull(31) ? null : rdr.GetString(31),
                    };
                    item.HasFollowup = item.TotalFollowups > 0;
                    list.Add(item);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[SpecialPermitService] Error getting special permits");
            }

            return list;
        }

        public async Task<bool> ReassignInspectorAsync(string permitId, string newInspectorNik, string newInspectorName, string? assignedByNik, string? assignedByName, string? reason)
        {
            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return false;

            try
            {
                const string sql = @"
                    UPDATE public.special_permit
                    SET inspector_nik = @newNik,
                        inspector_name = @newName
                    WHERE id::text = @id OR req_id = @id;";

                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@newNik", newInspectorNik.Trim());
                cmd.Parameters.AddWithValue("@newName", newInspectorName.Trim());
                cmd.Parameters.AddWithValue("@id", permitId.Trim());

                var rows = await cmd.ExecuteNonQueryAsync();
                return rows > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[SpecialPermitService] Error reassigning inspector for permit {Id}", permitId);
                return false;
            }
        }

        public async Task<List<object>> SearchInspectorsAsync(string? query)
        {
            var list = new List<object>();
            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return list;

            try
            {
                var sql = @"
                    SELECT u.employee_id, u.fullname, COALESCE(u.department, '-'), COALESCE(u.company_name, '-')
                    FROM public.tb_user u
                    WHERE u.is_active = true AND u.employee_id IS NOT NULL AND u.employee_id <> '' ";

                if (!string.IsNullOrWhiteSpace(query))
                {
                    sql += " AND (u.fullname ILIKE @q OR u.employee_id ILIKE @q OR u.username ILIKE @q) ";
                }

                sql += " ORDER BY u.fullname ASC LIMIT 40;";

                await using var cmd = new NpgsqlCommand(sql, conn);
                if (!string.IsNullOrWhiteSpace(query))
                {
                    cmd.Parameters.AddWithValue("@q", $"%{query.Trim()}%");
                }

                await using var rdr = await cmd.ExecuteReaderAsync();
                while (await rdr.ReadAsync())
                {
                    list.Add(new
                    {
                        nik = rdr.GetString(0),
                        nama = rdr.GetString(1),
                        departemen = rdr.GetString(2),
                        perusahaan = rdr.GetString(3)
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[SpecialPermitService] Error searching inspectors");
            }

            return list;
        }

        public async Task<SpecialPermitDetailDto?> GetSpecialPermitDetailAsync(string permitId)
        {
            if (string.IsNullOrWhiteSpace(permitId)) return null;

            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return null;

            try
            {
                const string sqlSp = @"
                    SELECT sp.id, sp.req_id, sp.activity_type, sp.status, sp.issue_date, sp.issue_time::text,
                           sp.pjo_nik, sp.pjo_name, sp.inspector_nik, sp.inspector_name,
                           sp.department_id, sp.department, sp.company_id, sp.company_name,
                           sp.implementing_contractor, sp.applicant_nik, sp.applicant_name,
                           sp.work_location, sp.phone, sp.responsible_person_nik, sp.responsible_person_name,
                           sp.start_date, sp.end_date, sp.job_description, sp.special_equipment, sp.work_related_hazard
                    FROM public.special_permit sp
                    WHERE sp.id = @id OR sp.req_id = @id
                    LIMIT 1;";

                await using var cmdSp = new NpgsqlCommand(sqlSp, conn);
                cmdSp.Parameters.AddWithValue("@id", permitId.Trim());
                await using var rdrSp = await cmdSp.ExecuteReaderAsync();
                if (!await rdrSp.ReadAsync()) return null;

                var permit = new SpecialPermitItemDto
                {
                    Id = rdrSp.IsDBNull(0) ? string.Empty : rdrSp.GetString(0),
                    ReqId = rdrSp.IsDBNull(1) ? string.Empty : rdrSp.GetString(1),
                    ActivityType = rdrSp.IsDBNull(2) ? string.Empty : rdrSp.GetString(2),
                    Status = rdrSp.IsDBNull(3) ? string.Empty : rdrSp.GetString(3),
                    IssueDate = rdrSp.IsDBNull(4) ? (DateTime?)null : rdrSp.GetDateTime(4),
                    IssueTime = rdrSp.IsDBNull(5) ? null : rdrSp.GetString(5),
                    PjoNik = rdrSp.IsDBNull(6) ? null : rdrSp.GetString(6),
                    PjoName = rdrSp.IsDBNull(7) ? null : rdrSp.GetString(7),
                    InspectorNik = rdrSp.IsDBNull(8) ? null : rdrSp.GetString(8),
                    InspectorName = rdrSp.IsDBNull(9) ? null : rdrSp.GetString(9),
                    DepartmentId = rdrSp.IsDBNull(10) ? null : Convert.ToInt32(rdrSp.GetValue(10)),
                    Department = rdrSp.IsDBNull(11) ? null : rdrSp.GetString(11),
                    CompanyId = rdrSp.IsDBNull(12) ? null : Convert.ToInt32(rdrSp.GetValue(12)),
                    CompanyName = rdrSp.IsDBNull(13) ? null : rdrSp.GetString(13),
                    ImplementingContractor = rdrSp.IsDBNull(14) ? null : rdrSp.GetString(14),
                    ApplicantNik = rdrSp.IsDBNull(15) ? null : rdrSp.GetString(15),
                    ApplicantName = rdrSp.IsDBNull(16) ? null : rdrSp.GetString(16),
                    WorkLocation = rdrSp.IsDBNull(17) ? null : rdrSp.GetString(17),
                    Phone = rdrSp.IsDBNull(18) ? null : rdrSp.GetString(18),
                    ResponsiblePersonNik = rdrSp.IsDBNull(19) ? null : rdrSp.GetString(19),
                    ResponsiblePersonName = rdrSp.IsDBNull(20) ? null : rdrSp.GetString(20),
                    StartDate = rdrSp.IsDBNull(21) ? (DateTime?)null : rdrSp.GetDateTime(21),
                    EndDate = rdrSp.IsDBNull(22) ? (DateTime?)null : rdrSp.GetDateTime(22),
                    JobDescription = rdrSp.IsDBNull(23) ? null : rdrSp.GetString(23),
                    SpecialEquipment = rdrSp.IsDBNull(24) ? null : rdrSp.GetString(24),
                    WorkRelatedHazard = rdrSp.IsDBNull(25) ? null : rdrSp.GetString(25),
                };
                await rdrSp.CloseAsync();

                var detail = new SpecialPermitDetailDto { Permit = permit };

                // Get follow-ups
                const string sqlFollow = @"
                    SELECT f.id, f.special_permit_id, f.req_id, f.activity_type, f.work_location,
                           f.inspector_nik, f.inspector_name, f.inspector_role, f.inspection_status,
                           f.inspection_notes, f.corrective_action, f.is_safe, f.work_condition_rating,
                           f.latitude, f.longitude, f.inspection_time
                    FROM public.tbl_m_folloup_special_permit f
                    WHERE f.special_permit_id = @id OR f.req_id = @reqId
                    ORDER BY f.inspection_time DESC;";

                await using var cmdFollow = new NpgsqlCommand(sqlFollow, conn);
                cmdFollow.Parameters.AddWithValue("@id", permit.Id);
                cmdFollow.Parameters.AddWithValue("@reqId", permit.ReqId);
                await using var rdrFollow = await cmdFollow.ExecuteReaderAsync();
                while (await rdrFollow.ReadAsync())
                {
                    detail.Followups.Add(new SpecialPermitFollowupItemDto
                    {
                        Id = rdrFollow.GetInt64(0),
                        SpecialPermitId = rdrFollow.GetString(1),
                        ReqId = rdrFollow.IsDBNull(2) ? null : rdrFollow.GetString(2),
                        ActivityType = rdrFollow.IsDBNull(3) ? null : rdrFollow.GetString(3),
                        WorkLocation = rdrFollow.IsDBNull(4) ? null : rdrFollow.GetString(4),
                        InspectorNik = rdrFollow.GetString(5),
                        InspectorName = rdrFollow.IsDBNull(6) ? null : rdrFollow.GetString(6),
                        InspectorRole = rdrFollow.IsDBNull(7) ? null : rdrFollow.GetString(7),
                        InspectionStatus = rdrFollow.GetString(8),
                        InspectionNotes = rdrFollow.IsDBNull(9) ? null : rdrFollow.GetString(9),
                        CorrectiveAction = rdrFollow.IsDBNull(10) ? null : rdrFollow.GetString(10),
                        IsSafe = !rdrFollow.IsDBNull(11) && rdrFollow.GetBoolean(11),
                        WorkConditionRating = rdrFollow.IsDBNull(12) ? 5 : Convert.ToInt32(rdrFollow.GetValue(12)),
                        Latitude = rdrFollow.IsDBNull(13) ? (double?)null : rdrFollow.GetDouble(13),
                        Longitude = rdrFollow.IsDBNull(14) ? (double?)null : rdrFollow.GetDouble(14),
                        InspectionTime = rdrFollow.GetDateTime(15)
                    });
                }
                await rdrFollow.CloseAsync();

                // Get photos for all followups
                if (detail.Followups.Any())
                {
                    var fIds = detail.Followups.Select(x => x.Id).ToArray();
                    const string sqlPhotos = @"
                        SELECT id, followup_id, photo_url, caption, created_at
                        FROM public.tbl_t_folloup_special_permit_photo
                        WHERE followup_id = ANY(@fIds)
                        ORDER BY id ASC;";

                    await using var cmdPhotos = new NpgsqlCommand(sqlPhotos, conn);
                    cmdPhotos.Parameters.AddWithValue("@fIds", fIds);
                    await using var rdrPhotos = await cmdPhotos.ExecuteReaderAsync();
                    while (await rdrPhotos.ReadAsync())
                    {
                        var fid = rdrPhotos.GetInt64(1);
                        var f = detail.Followups.FirstOrDefault(x => x.Id == fid);
                        if (f != null)
                        {
                            f.Photos.Add(new SpecialPermitPhotoDto
                            {
                                Id = rdrPhotos.GetInt64(0),
                                FollowupId = fid,
                                PhotoUrl = rdrPhotos.GetString(2),
                                Caption = rdrPhotos.IsDBNull(3) ? null : rdrPhotos.GetString(3),
                                CreatedAt = rdrPhotos.GetDateTime(4)
                            });
                        }
                    }
                    await rdrPhotos.CloseAsync();
                }

                permit.TotalFollowups = detail.Followups.Count;
                permit.HasFollowup = permit.TotalFollowups > 0;
                if (detail.Followups.Any())
                {
                    permit.LatestInspectionStatus = detail.Followups.First().InspectionStatus;
                    permit.LatestInspectionTime = detail.Followups.First().InspectionTime;
                }

                return detail;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[SpecialPermitService] Error getting detail for {PermitId}", permitId);
                return null;
            }
        }

        public async Task<SpecialPermitFollowupItemDto?> CreateFollowupAsync(CreateSpecialPermitFollowupDto req)
        {
            if (string.IsNullOrWhiteSpace(req.SpecialPermitId)) return null;

            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return null;

            await using var tran = await conn.BeginTransactionAsync();
            try
            {
                const string sqlInsert = @"
                    INSERT INTO public.tbl_m_folloup_special_permit
                    (special_permit_id, req_id, activity_type, work_location, inspector_nik, inspector_name,
                     inspector_role, inspection_status, inspection_notes, corrective_action, is_safe,
                     work_condition_rating, latitude, longitude, inspection_time, created_at, updated_at)
                    VALUES
                    (@spId, @reqId, @actType, @loc, @nik, @name,
                     @role, @status, @notes, @corrective, @isSafe,
                     @rating, @lat, @lng, NOW(), NOW(), NOW())
                    RETURNING id, inspection_time;";

                await using var cmd = new NpgsqlCommand(sqlInsert, conn, tran);
                cmd.Parameters.AddWithValue("@spId", req.SpecialPermitId);
                cmd.Parameters.AddWithValue("@reqId", (object?)req.ReqId ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@actType", (object?)req.ActivityType ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@loc", (object?)req.WorkLocation ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@nik", req.InspectorNik.Trim());
                cmd.Parameters.AddWithValue("@name", (object?)req.InspectorName ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@role", (object?)req.InspectorRole ?? "INSPECTOR");
                cmd.Parameters.AddWithValue("@status", req.InspectionStatus.ToUpper());
                cmd.Parameters.AddWithValue("@notes", (object?)req.InspectionNotes ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@corrective", (object?)req.CorrectiveAction ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@isSafe", req.IsSafe);
                cmd.Parameters.AddWithValue("@rating", req.WorkConditionRating);
                cmd.Parameters.AddWithValue("@lat", (object?)req.Latitude ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@lng", (object?)req.Longitude ?? DBNull.Value);

                long newId = 0;
                DateTime insTime = DateTime.UtcNow;
                await using (var rdr = await cmd.ExecuteReaderAsync())
                {
                    if (await rdr.ReadAsync())
                    {
                        newId = rdr.GetInt64(0);
                        insTime = rdr.GetDateTime(1);
                    }
                }

                var photosSaved = new List<SpecialPermitPhotoDto>();

                // Save Photos
                if (req.PhotosBase64 != null && req.PhotosBase64.Any())
                {
                    var uploadDir = Path.Combine(_env.ContentRootPath, "wwwroot", "uploads", "special_permit");
                    if (!Directory.Exists(uploadDir)) Directory.CreateDirectory(uploadDir);

                    foreach (var rawBase64 in req.PhotosBase64)
                    {
                        try
                        {
                            var clean = rawBase64;
                            if (clean.Contains(","))
                            {
                                clean = clean.Substring(clean.IndexOf(",") + 1);
                            }
                            var bytes = Convert.FromBase64String(clean);
                            var fileName = $"sp_{newId}_{Guid.NewGuid():N}.jpg";
                            var filePath = Path.Combine(uploadDir, fileName);
                            await File.WriteAllBytesAsync(filePath, bytes);

                            var relativeUrl = $"/uploads/special_permit/{fileName}";

                            const string sqlPhoto = @"
                                INSERT INTO public.tbl_t_folloup_special_permit_photo
                                (followup_id, photo_url, caption, created_at)
                                VALUES (@fId, @url, @caption, NOW())
                                RETURNING id;";

                            await using var cmdP = new NpgsqlCommand(sqlPhoto, conn, tran);
                            cmdP.Parameters.AddWithValue("@fId", newId);
                            cmdP.Parameters.AddWithValue("@url", relativeUrl);
                            cmdP.Parameters.AddWithValue("@caption", "Dokumentasi Verifikasi Lapangan");
                            var pId = Convert.ToInt64(await cmdP.ExecuteScalarAsync());

                            photosSaved.Add(new SpecialPermitPhotoDto
                            {
                                Id = pId,
                                FollowupId = newId,
                                PhotoUrl = relativeUrl,
                                Caption = "Dokumentasi Verifikasi Lapangan",
                                CreatedAt = DateTime.UtcNow
                            });
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "[SpecialPermitService] Error saving photo for followup {Id}", newId);
                        }
                    }
                }

                await tran.CommitAsync();

                // Simpan juga ke tabel SQL Server DB_SAP
                await SaveFollowupToSqlServerAsync(req, newId, insTime, photosSaved);

                return new SpecialPermitFollowupItemDto
                {
                    Id = newId,
                    SpecialPermitId = req.SpecialPermitId,
                    ReqId = req.ReqId,
                    ActivityType = req.ActivityType,
                    WorkLocation = req.WorkLocation,
                    InspectorNik = req.InspectorNik,
                    InspectorName = req.InspectorName,
                    InspectorRole = req.InspectorRole,
                    InspectionStatus = req.InspectionStatus,
                    InspectionNotes = req.InspectionNotes,
                    CorrectiveAction = req.CorrectiveAction,
                    IsSafe = req.IsSafe,
                    WorkConditionRating = req.WorkConditionRating,
                    Latitude = req.Latitude,
                    Longitude = req.Longitude,
                    InspectionTime = insTime,
                    Photos = photosSaved
                };
            }
            catch (Exception ex)
            {
                await tran.RollbackAsync();
                _logger.LogError(ex, "[SpecialPermitService] Error creating followup for permit {Id}", req.SpecialPermitId);
                return null;
            }
        }

        private async Task SaveFollowupToSqlServerAsync(
            CreateSpecialPermitFollowupDto req,
            long bimaFollowupId,
            DateTime insTime,
            List<SpecialPermitPhotoDto> photosSaved)
        {
            try
            {
                var connStr = _config.GetConnectionString("DefaultConnection");
                if (string.IsNullOrWhiteSpace(connStr)) return;

                await using var conn = new SqlConnection(connStr);
                await conn.OpenAsync();

                const string sql = @"
                    INSERT INTO dbo.tbl_t_special_permit_followup
                    (special_permit_id, req_id, activity_type, work_location, inspector_nik, inspector_name,
                     inspector_role, inspection_status, inspection_notes, corrective_action, is_safe,
                     work_condition_rating, latitude, longitude, bima_followup_id, inspection_time, created_at, updated_at)
                    OUTPUT INSERTED.id
                    VALUES
                    (@spId, @reqId, @actType, @loc, @nik, @name,
                     @role, @status, @notes, @corrective, @isSafe,
                     @rating, @lat, @lng, @bimaId, @insTime, GETDATE(), GETDATE());";

                await using var cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@spId", req.SpecialPermitId);
                cmd.Parameters.AddWithValue("@reqId", (object?)req.ReqId ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@actType", (object?)req.ActivityType ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@loc", (object?)req.WorkLocation ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@nik", req.InspectorNik.Trim());
                cmd.Parameters.AddWithValue("@name", (object?)req.InspectorName ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@role", (object?)req.InspectorRole ?? "INSPECTOR");
                cmd.Parameters.AddWithValue("@status", req.InspectionStatus.ToUpper());
                cmd.Parameters.AddWithValue("@notes", (object?)req.InspectionNotes ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@corrective", (object?)req.CorrectiveAction ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@isSafe", req.IsSafe);
                cmd.Parameters.AddWithValue("@rating", req.WorkConditionRating);
                cmd.Parameters.AddWithValue("@lat", (object?)req.Latitude ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@lng", (object?)req.Longitude ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@bimaId", bimaFollowupId > 0 ? (object)bimaFollowupId : DBNull.Value);
                cmd.Parameters.AddWithValue("@insTime", insTime);

                var sqlFollowupId = Convert.ToInt64(await cmd.ExecuteScalarAsync());

                if (photosSaved != null && photosSaved.Any())
                {
                    foreach (var photo in photosSaved)
                    {
                        const string sqlPhoto = @"
                            INSERT INTO dbo.tbl_t_special_permit_followup_photo
                            (followup_id, photo_url, caption, created_at)
                            VALUES (@fId, @url, @caption, GETDATE());";

                        await using var cmdP = new SqlCommand(sqlPhoto, conn);
                        cmdP.Parameters.AddWithValue("@fId", sqlFollowupId);
                        cmdP.Parameters.AddWithValue("@url", photo.PhotoUrl);
                        cmdP.Parameters.AddWithValue("@caption", (object?)photo.Caption ?? "Dokumentasi Verifikasi Lapangan");
                        await cmdP.ExecuteNonQueryAsync();
                    }
                }

                _logger.LogInformation("[SpecialPermitService] Followup successfully saved to SQL Server DB_SAP (ID: {SqlId})", sqlFollowupId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[SpecialPermitService] Error saving followup to SQL Server DB_SAP");
            }
        }

        public async Task<List<SpecialPermitItemDto>> GetHighRiskAlertsAsync(string nik)
        {
            var alerts = new List<SpecialPermitItemDto>();
            if (string.IsNullOrWhiteSpace(nik)) return alerts;

            await using var conn = await GetBimaConnectionAsync();
            if (conn == null) return alerts;

            try
            {
                var nikClean = nik.Trim();
                var nikTrimmed = nikClean.TrimStart('0');

                // Permits active within work schedule where user is PJO or Inspector, and has not yet been inspected/followed up
                const string sql = @"
                    SELECT sp.id, sp.req_id, sp.activity_type, sp.status, sp.issue_date, sp.issue_time::text,
                           sp.pjo_nik, sp.pjo_name, sp.inspector_nik, sp.inspector_name,
                           sp.work_location, sp.start_date, sp.end_date, sp.job_description, sp.special_equipment,
                           sp.department_id, sp.department, sp.company_id, sp.company_name,
                           sp.implementing_contractor, sp.applicant_nik, sp.applicant_name,
                           sp.phone, sp.responsible_person_nik, sp.responsible_person_name, sp.work_related_hazard
                    FROM public.special_permit sp
                    WHERE (
                        (NULLIF(TRIM(sp.pjo_nik), '') = @nikClean OR NULLIF(TRIM(sp.pjo_nik), '') = @nikTrimmed) OR
                        (NULLIF(TRIM(sp.inspector_nik), '') = @nikClean OR NULLIF(TRIM(sp.inspector_nik), '') = @nikTrimmed)
                    )
                    AND UPPER(sp.status) IN ('WAITING', 'APPROVED')
                    -- Tampilkan sesuai jam pekerjaan / schedule
                    AND (
                        (sp.start_date IS NOT NULL AND sp.start_date <= NOW() AND (sp.end_date IS NULL OR sp.end_date >= NOW()))
                        OR
                        (sp.start_date IS NULL AND sp.issue_date IS NOT NULL AND (sp.issue_date < CURRENT_DATE OR (sp.issue_date = CURRENT_DATE AND (sp.issue_time IS NULL OR sp.issue_time <= CURRENT_TIME))))
                        OR
                        (sp.start_date IS NULL AND sp.issue_date IS NULL)
                    )
                    -- Belum diinspeksi / follow-up sama sekali
                    AND NOT EXISTS (
                        SELECT 1 FROM public.tbl_m_folloup_special_permit f
                        WHERE (f.special_permit_id = sp.id OR f.req_id = sp.req_id)
                    )
                    ORDER BY sp.created_at DESC
                    LIMIT 20;";

                await using var cmd = new NpgsqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@nikClean", nikClean);
                cmd.Parameters.AddWithValue("@nikTrimmed", nikTrimmed);

                await using var rdr = await cmd.ExecuteReaderAsync();
                while (await rdr.ReadAsync())
                {
                    alerts.Add(new SpecialPermitItemDto
                    {
                        Id = rdr.GetString(0),
                        ReqId = rdr.IsDBNull(1) ? string.Empty : rdr.GetString(1),
                        ActivityType = rdr.IsDBNull(2) ? string.Empty : rdr.GetString(2),
                        Status = rdr.IsDBNull(3) ? string.Empty : rdr.GetString(3),
                        IssueDate = rdr.IsDBNull(4) ? (DateTime?)null : rdr.GetDateTime(4),
                        IssueTime = rdr.IsDBNull(5) ? null : rdr.GetString(5),
                        PjoNik = rdr.IsDBNull(6) ? null : rdr.GetString(6),
                        PjoName = rdr.IsDBNull(7) ? null : rdr.GetString(7),
                        InspectorNik = rdr.IsDBNull(8) ? null : rdr.GetString(8),
                        InspectorName = rdr.IsDBNull(9) ? null : rdr.GetString(9),
                        WorkLocation = rdr.IsDBNull(10) ? null : rdr.GetString(10),
                        StartDate = rdr.IsDBNull(11) ? (DateTime?)null : rdr.GetDateTime(11),
                        EndDate = rdr.IsDBNull(12) ? (DateTime?)null : rdr.GetDateTime(12),
                        JobDescription = rdr.IsDBNull(13) ? null : rdr.GetString(13),
                        SpecialEquipment = rdr.IsDBNull(14) ? null : rdr.GetString(14),
                        DepartmentId = rdr.IsDBNull(15) ? null : Convert.ToInt32(rdr.GetValue(15)),
                        Department = rdr.IsDBNull(16) ? null : rdr.GetString(16),
                        CompanyId = rdr.IsDBNull(17) ? null : Convert.ToInt32(rdr.GetValue(17)),
                        CompanyName = rdr.IsDBNull(18) ? null : rdr.GetString(18),
                        ImplementingContractor = rdr.IsDBNull(19) ? null : rdr.GetString(19),
                        ApplicantNik = rdr.IsDBNull(20) ? null : rdr.GetString(20),
                        ApplicantName = rdr.IsDBNull(21) ? null : rdr.GetString(21),
                        Phone = rdr.IsDBNull(22) ? null : rdr.GetString(22),
                        ResponsiblePersonNik = rdr.IsDBNull(23) ? null : rdr.GetString(23),
                        ResponsiblePersonName = rdr.IsDBNull(24) ? null : rdr.GetString(24),
                        WorkRelatedHazard = rdr.IsDBNull(25) ? null : rdr.GetString(25),
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[SpecialPermitService] Error checking high risk alerts");
            }

            return alerts;
        }
    }
}
