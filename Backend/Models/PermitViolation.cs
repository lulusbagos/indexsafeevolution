using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_permit_violation")]
    public class PermitViolation
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Required]
        [MaxLength(80)]
        [Column("violator_nik")]
        public string ViolatorNik { get; set; } = string.Empty;

        [MaxLength(180)]
        [Column("violator_name")]
        public string? ViolatorName { get; set; }

        [MaxLength(180)]
        [Column("violator_company")]
        public string? ViolatorCompany { get; set; }

        [MaxLength(180)]
        [Column("violator_department")]
        public string? ViolatorDepartment { get; set; }

        [MaxLength(100)]
        [Column("permit_number")]
        public string? PermitNumber { get; set; }

        [Required]
        [MaxLength(100)]
        [Column("violation_type")]
        public string ViolationType { get; set; } = string.Empty;

        [Required]
        [MaxLength(1000)]
        [Column("violation_description")]
        public string ViolationDescription { get; set; } = string.Empty;

        [MaxLength(250)]
        [Column("violation_location")]
        public string? ViolationLocation { get; set; }

        [MaxLength(500)]
        [Column("photo_url")]
        public string? PhotoUrl { get; set; }

        [MaxLength(50)]
        [Column("severity")]
        public string Severity { get; set; } = "Medium";

        [MaxLength(500)]
        [Column("action_taken")]
        public string? ActionTaken { get; set; }

        [Required]
        [MaxLength(80)]
        [Column("reported_by_nik")]
        public string ReportedByNik { get; set; } = string.Empty;

        [MaxLength(180)]
        [Column("reported_by_name")]
        public string? ReportedByName { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;
    }
}
