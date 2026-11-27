using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_m_inspection_question")]
    public class MasterInspectionQuestion
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        [Column("key")]
        public string Key { get; set; } = string.Empty; // e.g. "1_1", "1_2", or custom key

        [Required]
        [MaxLength(150)]
        [Column("module_title")]
        public string ModuleTitle { get; set; } = string.Empty; // e.g. "Modul 1: Kepatuhan & Sistem"

        [Required]
        [MaxLength(500)]
        [Column("question")]
        public string Question { get; set; } = string.Empty;

        [MaxLength(500)]
        [Column("guidance")]
        public string? Guidance { get; set; }

        [Column("order_index")]
        public int OrderIndex { get; set; } = 0;

        [Column("is_active")]
        public bool IsActive { get; set; } = true;

        [Column("is_custom")]
        public bool IsCustom { get; set; } = false;

        [MaxLength(50)]
        [Column("created_by_nik")]
        public string? CreatedByNik { get; set; }

        [MaxLength(150)]
        [Column("created_by_name")]
        public string? CreatedByName { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [Column("updated_at")]
        public DateTime? UpdatedAt { get; set; }
    }
}
