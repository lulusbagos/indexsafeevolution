using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Net.Http;
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

        /// <summary>
        /// Ringkasan statistik dokumen tambang dari ONE_DB_MITRA
        /// </summary>
        [HttpGet("summary")]
        [AllowAnonymous]
        public async Task<IActionResult> GetSummary([FromQuery] string? department = null)
        {
            try
            {
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

                        SELECT TOP 8 
                            file_id, folder_id, nama_dokumen, nama_file_stored, file_path, content_type, size_bytes,
                            is_read_only, is_bold, created_at, created_by
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file
                        WHERE is_deleted = 0
                        ORDER BY file_id DESC;
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
                            var filePath = reader["file_path"]?.ToString() ?? "";
                            var docName = reader["nama_dokumen"]?.ToString() ?? "";
                            var size = reader["size_bytes"] != DBNull.Value ? Convert.ToInt64(reader["size_bytes"]) : 0;
                            var ext = Path.GetExtension(docName).TrimStart('.').ToLower();
                            if (string.IsNullOrEmpty(ext)) ext = Path.GetExtension(filePath).TrimStart('.').ToLower();
                            if (string.IsNullOrEmpty(ext)) ext = "pdf";

                            recentDocs.Add(new
                            {
                                id = Convert.ToInt32(reader["file_id"]),
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
                        }
                    }

                    return Ok(new
                    {
                        status = 200,
                        success = true,
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
        /// Mengambil daftar folder (hierarkis berjenjang) dari ONE_DB_MITRA.
        /// Jika parentId null/0, default menampilkan folder utama PT Indexim Coalindo (folder_id = 9).
        /// </summary>
        [HttpGet("folders")]
        [AllowAnonymous]
        public async Task<IActionResult> GetFolders([FromQuery] int? parentId = null)
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    // Menentukan target parent_id
                    // Folder ID 9 = "PT Indexim Coalindo" (induk seluruh kategori dokumen site)
                    int targetParent = parentId.HasValue && parentId.Value > 0 ? parentId.Value : 9;

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
                        var folderId = Convert.ToInt32(reader["folder_id"]);
                        var color = reader["folder_color"]?.ToString();
                        if (string.IsNullOrWhiteSpace(color)) color = "#0284C7";

                        folders.Add(new
                        {
                            id = folderId,
                            parentId = reader["parent_folder_id"] != DBNull.Value ? Convert.ToInt32(reader["parent_folder_id"]) : (int?)null,
                            name = reader["nama_folder"]?.ToString() ?? "Folder",
                            path = reader["path_key"]?.ToString() ?? "",
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
        /// Mengambil daftar file dokumen dalam satu folder secara on-demand.
        /// </summary>
        [HttpGet("files")]
        [AllowAnonymous]
        public async Task<IActionResult> GetFiles(
            [FromQuery] int folderId,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 100)
        {
            try
            {
                if (folderId <= 0)
                {
                    return BadRequest(new { status = 400, success = false, message = "folderId wajib diisi" });
                }

                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT COUNT(*) 
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file 
                        WHERE folder_id = @folderId AND is_deleted = 0;

                        SELECT 
                            file_id, folder_id, nama_dokumen, nama_file_stored, file_path, content_type, size_bytes,
                            is_read_only, is_bold, expired_at, created_at, created_by
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file
                        WHERE folder_id = @folderId AND is_deleted = 0
                        ORDER BY nama_dokumen ASC
                        OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
                    ";

                    var pFolder = cmd.CreateParameter();
                    pFolder.ParameterName = "@folderId";
                    pFolder.Value = folderId;
                    cmd.Parameters.Add(pFolder);

                    int offset = Math.Max(0, (page - 1) * pageSize);
                    var pOffset = cmd.CreateParameter();
                    pOffset.ParameterName = "@offset";
                    pOffset.Value = offset;
                    cmd.Parameters.Add(pOffset);

                    var pSize = cmd.CreateParameter();
                    pSize.ParameterName = "@pageSize";
                    pSize.Value = pageSize;
                    cmd.Parameters.Add(pSize);

                    int total = 0;
                    var files = new List<object>();

                    using var reader = await cmd.ExecuteReaderAsync();
                    if (await reader.ReadAsync())
                    {
                        total = Convert.ToInt32(reader[0]);
                    }

                    if (await reader.NextResultAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            var filePath = reader["file_path"]?.ToString() ?? "";
                            var docName = reader["nama_dokumen"]?.ToString() ?? "";
                            var size = reader["size_bytes"] != DBNull.Value ? Convert.ToInt64(reader["size_bytes"]) : 0;
                            var ext = Path.GetExtension(docName).TrimStart('.').ToLower();
                            if (string.IsNullOrEmpty(ext)) ext = Path.GetExtension(filePath).TrimStart('.').ToLower();
                            if (string.IsNullOrEmpty(ext)) ext = "pdf";

                            files.Add(new
                            {
                                id = Convert.ToInt32(reader["file_id"]),
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
                    }

                    return Ok(new
                    {
                        status = 200,
                        success = true,
                        folderId = folderId,
                        total = total,
                        page = page,
                        pageSize = pageSize,
                        data = files
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
        /// Pencarian cepat (instant search) pada seluruh koleksi 4.100+ dokumen ONE_DB_MITRA.
        /// </summary>
        [HttpGet("search")]
        [AllowAnonymous]
        public async Task<IActionResult> SearchDocuments([FromQuery] string q, [FromQuery] int limit = 40)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 2)
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
                    pLimit.Value = Math.Clamp(limit, 1, 100);
                    cmd.Parameters.Add(pLimit);

                    var results = new List<object>();
                    using var reader = await cmd.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        var filePath = reader["file_path"]?.ToString() ?? "";
                        var docName = reader["nama_dokumen"]?.ToString() ?? "";
                        var size = reader["size_bytes"] != DBNull.Value ? Convert.ToInt64(reader["size_bytes"]) : 0;
                        var ext = Path.GetExtension(docName).TrimStart('.').ToLower();
                        if (string.IsNullOrEmpty(ext)) ext = Path.GetExtension(filePath).TrimStart('.').ToLower();
                        if (string.IsNullOrEmpty(ext)) ext = "pdf";

                        results.Add(new
                        {
                            id = Convert.ToInt32(reader["file_id"]),
                            folderId = reader["folder_id"] != DBNull.Value ? Convert.ToInt32(reader["folder_id"]) : (int?)null,
                            folderName = reader["nama_folder"]?.ToString() ?? "",
                            folderPath = reader["path_key"]?.ToString() ?? "",
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
        /// Download / streaming file dokumen on-demand.
        /// </summary>
        [HttpGet("download/{fileId}")]
        [AllowAnonymous]
        public async Task<IActionResult> DownloadFile(int fileId)
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                string filePath = "";
                string docName = "";
                string contentType = "application/pdf";

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT file_id, nama_dokumen, file_path, content_type 
                        FROM [ONE_DB_MITRA].dbo.tbl_t_dokumen_file 
                        WHERE file_id = @id AND is_deleted = 0;
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
                catch (Exception downloadEx)
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
