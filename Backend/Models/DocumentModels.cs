using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_m_document_folders")]
    public class DocumentFolder
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Column("parent_id")]
        public int? ParentId { get; set; }

        [Required]
        [MaxLength(200)]
        [Column("name")]
        public string Name { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        [Column("category")]
        public string Category { get; set; } = "Drive";

        [MaxLength(100)]
        [Column("department")]
        public string? Department { get; set; }

        [MaxLength(100)]
        [Column("company")]
        public string? Company { get; set; }

        [MaxLength(20)]
        [Column("color")]
        public string? Color { get; set; } = "#3B82F6";

        [MaxLength(50)]
        [Column("icon")]
        public string? Icon { get; set; } = "folder";

        [MaxLength(50)]
        [Column("created_by_nik")]
        public string? CreatedByNik { get; set; }

        [MaxLength(150)]
        [Column("created_by_name")]
        public string? CreatedByName { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [Column("is_deleted")]
        public bool IsDeleted { get; set; } = false;
    }

    [Table("tbl_t_documents")]
    public class DocumentItem
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Column("folder_id")]
        public int? FolderId { get; set; }

        [MaxLength(100)]
        [Column("doc_number")]
        public string? DocNumber { get; set; }

        [Required]
        [MaxLength(300)]
        [Column("title")]
        public string Title { get; set; } = string.Empty;

        [Column("description")]
        public string? Description { get; set; }

        [Required]
        [MaxLength(50)]
        [Column("category")]
        public string Category { get; set; } = "Drive"; // Drive, Pengajuan, SOP, Perizinan, Kebijakan

        [Required]
        [MaxLength(20)]
        [Column("file_type")]
        public string FileType { get; set; } = "pdf"; // pdf, docx, xlsx, image

        [MaxLength(500)]
        [Column("file_url")]
        public string? FileUrl { get; set; }

        [MaxLength(250)]
        [Column("file_name")]
        public string? FileName { get; set; }

        [Column("file_size")]
        public long FileSize { get; set; } = 0;

        [MaxLength(20)]
        [Column("version")]
        public string Version { get; set; } = "v1.0";

        [MaxLength(100)]
        [Column("department")]
        public string? Department { get; set; }

        [MaxLength(100)]
        [Column("company")]
        public string? Company { get; set; }

        [MaxLength(50)]
        [Column("uploader_nik")]
        public string? UploaderNik { get; set; }

        [MaxLength(150)]
        [Column("uploader_name")]
        public string? UploaderName { get; set; }

        [MaxLength(50)]
        [Column("approval_status")]
        public string ApprovalStatus { get; set; } = "Approved"; // Draft, Submitted, UnderReview, Approved, Rejected

        [MaxLength(50)]
        [Column("approver_nik")]
        public string? ApproverNik { get; set; }

        [MaxLength(150)]
        [Column("approver_name")]
        public string? ApproverName { get; set; }

        [Column("approval_notes")]
        public string? ApprovalNotes { get; set; }

        [Column("approved_at")]
        public DateTime? ApprovedAt { get; set; }

        [Column("is_confidential")]
        public bool IsConfidential { get; set; } = false;

        [Column("downloads_count")]
        public int DownloadsCount { get; set; } = 0;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [Column("updated_at")]
        public DateTime UpdatedAt { get; set; } = DateTime.Now;

        [Column("is_deleted")]
        public bool IsDeleted { get; set; } = false;
    }
}
