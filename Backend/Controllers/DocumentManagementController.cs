using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/document-management")]
    public class DocumentManagementController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IWebHostEnvironment _env;

        public DocumentManagementController(AppDbContext context, IWebHostEnvironment env)
        {
            _context = context;
            _env = env;
        }

        private string GetCallerNik(string? fallback = null)
        {
            var header = Request?.Headers["X-User-Nik"].ToString();
            if (!string.IsNullOrWhiteSpace(header)) return header.Trim();
            if (!string.IsNullOrWhiteSpace(fallback)) return fallback.Trim();
            return User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
                   ?? User?.FindFirst("nrp")?.Value
                   ?? User?.FindFirst("nik")?.Value
                   ?? string.Empty;
        }

        private string GetCallerName(string? fallback = null)
        {
            var header = Request?.Headers["X-User-Name"].ToString();
            if (!string.IsNullOrWhiteSpace(header)) return header.Trim();
            if (!string.IsNullOrWhiteSpace(fallback)) return fallback.Trim();
            return User?.FindFirst(ClaimTypes.Name)?.Value
                   ?? User?.FindFirst("nama")?.Value
                   ?? User?.FindFirst("name")?.Value
                   ?? string.Empty;
        }

        [HttpGet("summary")]
        [AllowAnonymous]
        public async Task<IActionResult> GetSummary([FromQuery] string? department = null)
        {
            try
            {
                var docQuery = _context.Documents.Where(d => !d.IsDeleted);
                if (!string.IsNullOrWhiteSpace(department))
                {
                    docQuery = docQuery.Where(d => d.Department == department || d.Department == "MANAGEMENT" || d.Department == "HSE & OHS");
                }

                var totalDocs = await docQuery.CountAsync();
                var totalFolders = await _context.DocumentFolders.CountAsync(f => !f.IsDeleted);
                var pendingApprovals = await docQuery.CountAsync(d => d.ApprovalStatus == "Submitted" || d.ApprovalStatus == "UnderReview");
                var activeSop = await docQuery.CountAsync(d => d.Category == "SOP" && d.ApprovalStatus == "Approved");
                var totalStorage = await docQuery.SumAsync(d => (long?)d.FileSize) ?? 0;

                var recentDocs = await docQuery
                    .OrderByDescending(d => d.UpdatedAt)
                    .Take(6)
                    .Select(d => new
                    {
                        d.Id,
                        d.FolderId,
                        d.DocNumber,
                        d.Title,
                        d.Category,
                        d.FileType,
                        d.FileName,
                        d.FileSize,
                        d.Version,
                        d.Department,
                        d.UploaderName,
                        d.ApprovalStatus,
                        d.UpdatedAt
                    })
                    .ToListAsync();

                return Ok(new
                {
                    status = 200,
                    success = true,
                    data = new
                    {
                        totalDocuments = totalDocs,
                        totalFolders,
                        pendingApprovals,
                        activeSopCount = activeSop,
                        totalStorageBytes = totalStorage,
                        storageFormatted = FormatStorage(totalStorage),
                        recentDocuments = recentDocs
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpGet("folders")]
        [AllowAnonymous]
        public async Task<IActionResult> GetFolders(
            [FromQuery] int? parentId = null,
            [FromQuery] string? category = null,
            [FromQuery] string? department = null)
        {
            try
            {
                var query = _context.DocumentFolders.Where(f => !f.IsDeleted);

                if (parentId.HasValue)
                {
                    query = query.Where(f => f.ParentId == parentId.Value);
                }
                else
                {
                    query = query.Where(f => f.ParentId == null);
                }

                if (!string.IsNullOrWhiteSpace(category) && !category.Equals("all", StringComparison.OrdinalIgnoreCase))
                {
                    query = query.Where(f => f.Category == category);
                }

                var folders = await query.OrderBy(f => f.Name).ToListAsync();

                // Compute file counts per folder
                var folderIds = folders.Select(f => f.Id).ToList();
                var counts = await _context.Documents
                    .Where(d => !d.IsDeleted && d.FolderId.HasValue && folderIds.Contains(d.FolderId.Value))
                    .GroupBy(d => d.FolderId!.Value)
                    .Select(g => new { FolderId = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.FolderId, x => x.Count);

                var result = folders.Select(f => new
                {
                    f.Id,
                    f.ParentId,
                    f.Name,
                    f.Category,
                    f.Department,
                    f.Company,
                    f.Color,
                    f.Icon,
                    f.CreatedByName,
                    f.CreatedAt,
                    FilesCount = counts.TryGetValue(f.Id, out var c) ? c : 0
                });

                return Ok(new { status = 200, success = true, data = result });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpPost("folders")]
        [AllowAnonymous]
        public async Task<IActionResult> CreateFolder([FromBody] CreateFolderRequest req)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(req.Name))
                {
                    return BadRequest(new { status = 400, success = false, message = "Nama folder wajib diisi" });
                }

                var folder = new DocumentFolder
                {
                    ParentId = req.ParentId,
                    Name = req.Name.Trim(),
                    Category = string.IsNullOrWhiteSpace(req.Category) ? "Drive" : req.Category.Trim(),
                    Department = req.Department?.Trim(),
                    Company = req.Company?.Trim(),
                    Color = string.IsNullOrWhiteSpace(req.Color) ? "#3B82F6" : req.Color.Trim(),
                    Icon = string.IsNullOrWhiteSpace(req.Icon) ? "folder" : req.Icon.Trim(),
                    CreatedByNik = GetCallerNik(req.Nik),
                    CreatedByName = GetCallerName(req.Nama),
                    CreatedAt = DateTime.Now
                };

                _context.DocumentFolders.Add(folder);
                await _context.SaveChangesAsync();

                return Ok(new { status = 200, success = true, message = "Folder berhasil dibuat", data = folder });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpGet("files")]
        [AllowAnonymous]
        public async Task<IActionResult> GetFiles(
            [FromQuery] int? folderId = null,
            [FromQuery] string? category = null,
            [FromQuery] string? search = null,
            [FromQuery] string? approvalStatus = null,
            [FromQuery] string? department = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            try
            {
                var query = _context.Documents.Where(d => !d.IsDeleted);

                if (folderId.HasValue && folderId.Value > 0)
                {
                    query = query.Where(d => d.FolderId == folderId.Value);
                }

                if (!string.IsNullOrWhiteSpace(category) && !category.Equals("all", StringComparison.OrdinalIgnoreCase))
                {
                    query = query.Where(d => d.Category == category);
                }

                if (!string.IsNullOrWhiteSpace(approvalStatus) && !approvalStatus.Equals("all", StringComparison.OrdinalIgnoreCase))
                {
                    query = query.Where(d => d.ApprovalStatus == approvalStatus);
                }

                if (!string.IsNullOrWhiteSpace(department))
                {
                    query = query.Where(d => d.Department == department || d.Department == "MANAGEMENT" || d.Department == "HSE & OHS");
                }

                if (!string.IsNullOrWhiteSpace(search))
                {
                    var term = search.Trim().ToLower();
                    query = query.Where(d =>
                        d.Title.ToLower().Contains(term) ||
                        (d.DocNumber != null && d.DocNumber.ToLower().Contains(term)) ||
                        (d.FileName != null && d.FileName.ToLower().Contains(term)) ||
                        (d.Description != null && d.Description.ToLower().Contains(term)));
                }

                var totalCount = await query.CountAsync();
                var files = await query
                    .OrderByDescending(d => d.UpdatedAt)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToListAsync();

                return Ok(new
                {
                    status = 200,
                    success = true,
                    data = files,
                    total = totalCount,
                    page,
                    pageSize
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpGet("files/{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetFileById(int id)
        {
            try
            {
                var doc = await _context.Documents.FirstOrDefaultAsync(d => d.Id == id && !d.IsDeleted);
                if (doc == null)
                {
                    return NotFound(new { status = 404, success = false, message = "Dokumen tidak ditemukan" });
                }

                return Ok(new { status = 200, success = true, data = doc });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpPost("submit-pengajuan")]
        [AllowAnonymous]
        public async Task<IActionResult> SubmitPengajuan([FromBody] SubmitPengajuanRequest req)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(req.Title))
                {
                    return BadRequest(new { status = 400, success = false, message = "Judul pengajuan dokumen wajib diisi" });
                }

                var doc = new DocumentItem
                {
                    FolderId = req.FolderId,
                    DocNumber = string.IsNullOrWhiteSpace(req.DocNumber)
                        ? $"DOC-REQ-{DateTime.Now:yyyyMMdd}-{new Random().Next(100, 999)}"
                        : req.DocNumber.Trim(),
                    Title = req.Title.Trim(),
                    Description = req.Description?.Trim(),
                    Category = string.IsNullOrWhiteSpace(req.Category) ? "Pengajuan" : req.Category.Trim(),
                    FileType = string.IsNullOrWhiteSpace(req.FileType) ? "pdf" : req.FileType.Trim(),
                    FileName = req.FileName?.Trim() ?? $"{req.Title.Trim()}.pdf",
                    FileSize = req.FileSize > 0 ? req.FileSize : 1024000,
                    FileUrl = req.FileUrl?.Trim(),
                    Version = string.IsNullOrWhiteSpace(req.Version) ? "v1.0" : req.Version.Trim(),
                    Department = req.Department?.Trim(),
                    Company = req.Company?.Trim(),
                    UploaderNik = GetCallerNik(req.UploaderNik),
                    UploaderName = GetCallerName(req.UploaderName),
                    ApprovalStatus = "Submitted",
                    CreatedAt = DateTime.Now,
                    UpdatedAt = DateTime.Now
                };

                _context.Documents.Add(doc);
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    status = 200,
                    success = true,
                    message = "Dokumen pengajuan berhasil diajukan dan sedang menunggu verifikasi/persetujuan",
                    data = doc
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpPost("approve")]
        [AllowAnonymous]
        public async Task<IActionResult> ApproveDocument([FromBody] ApprovalActionRequest req)
        {
            try
            {
                var doc = await _context.Documents.FirstOrDefaultAsync(d => d.Id == req.DocumentId && !d.IsDeleted);
                if (doc == null)
                {
                    return NotFound(new { status = 404, success = false, message = "Dokumen tidak ditemukan" });
                }

                doc.ApprovalStatus = "Approved";
                doc.ApproverNik = GetCallerNik(req.ApproverNik);
                doc.ApproverName = GetCallerName(req.ApproverName);
                doc.ApprovalNotes = req.Notes?.Trim();
                doc.ApprovedAt = DateTime.Now;
                doc.UpdatedAt = DateTime.Now;

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    status = 200,
                    success = true,
                    message = $"Dokumen '{doc.Title}' berhasil disetujui",
                    data = doc
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpPost("reject")]
        [AllowAnonymous]
        public async Task<IActionResult> RejectDocument([FromBody] ApprovalActionRequest req)
        {
            try
            {
                var doc = await _context.Documents.FirstOrDefaultAsync(d => d.Id == req.DocumentId && !d.IsDeleted);
                if (doc == null)
                {
                    return NotFound(new { status = 404, success = false, message = "Dokumen tidak ditemukan" });
                }

                doc.ApprovalStatus = "Rejected";
                doc.ApproverNik = GetCallerNik(req.ApproverNik);
                doc.ApproverName = GetCallerName(req.ApproverName);
                doc.ApprovalNotes = req.Notes?.Trim() ?? "Ditolak / Perlu Revisi";
                doc.ApprovedAt = DateTime.Now;
                doc.UpdatedAt = DateTime.Now;

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    status = 200,
                    success = true,
                    message = $"Dokumen '{doc.Title}' telah ditolak dengan catatan",
                    data = doc
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        [HttpDelete("files/{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> DeleteFile(int id)
        {
            try
            {
                var doc = await _context.Documents.FirstOrDefaultAsync(d => d.Id == id && !d.IsDeleted);
                if (doc == null)
                {
                    return NotFound(new { status = 404, success = false, message = "Dokumen tidak ditemukan" });
                }

                doc.IsDeleted = true;
                doc.UpdatedAt = DateTime.Now;
                await _context.SaveChangesAsync();

                return Ok(new { status = 200, success = true, message = "Dokumen berhasil dihapus" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { status = 500, success = false, message = ex.Message });
            }
        }

        private static string FormatStorage(long bytes)
        {
            if (bytes <= 0) return "0 MB";
            if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
            if (bytes < 1024L * 1024 * 1024) return $"{bytes / (1024.0 * 1024):F1} MB";
            return $"{bytes / (1024.0 * 1024 * 1024):F2} GB";
        }
    }

    public class CreateFolderRequest
    {
        public int? ParentId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Category { get; set; }
        public string? Department { get; set; }
        public string? Company { get; set; }
        public string? Color { get; set; }
        public string? Icon { get; set; }
        public string? Nik { get; set; }
        public string? Nama { get; set; }
    }

    public class SubmitPengajuanRequest
    {
        public int? FolderId { get; set; }
        public string? DocNumber { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public string? Category { get; set; }
        public string? FileType { get; set; }
        public string? FileName { get; set; }
        public long FileSize { get; set; }
        public string? FileUrl { get; set; }
        public string? Version { get; set; }
        public string? Department { get; set; }
        public string? Company { get; set; }
        public string? UploaderNik { get; set; }
        public string? UploaderName { get; set; }
    }

    public class ApprovalActionRequest
    {
        public int DocumentId { get; set; }
        public string? Notes { get; set; }
        public string? ApproverNik { get; set; }
        public string? ApproverName { get; set; }
    }
}
