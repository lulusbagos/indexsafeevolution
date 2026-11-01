using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_permit_violation_approver")]
    public class PermitViolationApprover
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Column("violation_id")]
        public int ViolationId { get; set; }

        [ForeignKey("ViolationId")]
        public PermitViolation? Violation { get; set; }

        [Required]
        [MaxLength(80)]
        [Column("approver_nik")]
        public string ApproverNik { get; set; } = string.Empty;

        [MaxLength(180)]
        [Column("approver_name")]
        public string? ApproverName { get; set; }

        [MaxLength(180)]
        [Column("approver_position")]
        public string? ApproverPosition { get; set; }

        [MaxLength(180)]
        [Column("approver_department")]
        public string? ApproverDepartment { get; set; }

        [MaxLength(180)]
        [Column("approver_company")]
        public string? ApproverCompany { get; set; }

        [Required]
        [MaxLength(30)]
        [Column("status")]
        public string Status { get; set; } = "PENDING"; // PENDING, APPROVED, REJECTED

        [MaxLength(500)]
        [Column("notes")]
        public string? Notes { get; set; }

        [Column("action_at")]
        public DateTime? ActionAt { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;
    }
}
