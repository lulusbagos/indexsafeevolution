using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_reinduksi")]
    public class Reinduksi
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Column("id")]
        public int Id { get; set; }

        [Column("roster_id")]
        public int? RosterId { get; set; }

        [Required]
        [MaxLength(50)]
        [Column("nik")]
        public string Nik { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        [Column("nama")]
        public string Nama { get; set; } = string.Empty;

        [MaxLength(150)]
        [Column("perusahaan")]
        public string? Perusahaan { get; set; }

        [MaxLength(100)]
        [Column("jabatan")]
        public string? Jabatan { get; set; }

        [MaxLength(100)]
        [Column("departemen")]
        public string? Departemen { get; set; }

        [MaxLength(50)]
        [Column("nik_pengawas")]
        public string? NikPengawas { get; set; }

        [MaxLength(150)]
        [Column("nama_pengawas")]
        public string? NamaPengawas { get; set; }

        [Column("tanggal_mulai_offsite")]
        public DateTime? TanggalMulaiOffsite { get; set; }

        [Column("tanggal_mulai_onsite")]
        public DateTime? TanggalMulaiOnsite { get; set; }

        [Column("awal_dinas")]
        public DateTime? AwalDinas { get; set; }

        [Column("akhir_dinas")]
        public DateTime? AkhirDinas { get; set; }

        [Column("awal_cuti")]
        public DateTime? AwalCuti { get; set; }

        [Column("akhir_cuti")]
        public DateTime? AkhirCuti { get; set; }

        [MaxLength(50)]
        [Column("tipe_roster")]
        public string TipeRoster { get; set; } = "REGULER";

        [Column("is_exempt")]
        public bool IsExempt { get; set; } = false;

        [MaxLength(30)]
        [Column("status")]
        public string Status { get; set; } = "PENDING_APPROVAL"; // PENDING_APPROVAL, APPROVED, REJECTED

        [MaxLength(10)]
        [Column("q1_answer")]
        public string? Q1Answer { get; set; }

        [MaxLength(500)]
        [Column("q1_notes")]
        public string? Q1Notes { get; set; }

        [MaxLength(10)]
        [Column("q2_answer")]
        public string? Q2Answer { get; set; }

        [MaxLength(500)]
        [Column("q2_notes")]
        public string? Q2Notes { get; set; }

        [MaxLength(10)]
        [Column("q3_answer")]
        public string? Q3Answer { get; set; }

        [MaxLength(500)]
        [Column("q3_notes")]
        public string? Q3Notes { get; set; }

        [MaxLength(10)]
        [Column("q4_answer")]
        public string? Q4Answer { get; set; }

        [MaxLength(500)]
        [Column("q4_notes")]
        public string? Q4Notes { get; set; }

        [MaxLength(10)]
        [Column("q5_answer")]
        public string? Q5Answer { get; set; }

        [MaxLength(500)]
        [Column("q5_notes")]
        public string? Q5Notes { get; set; }

        [MaxLength(10)]
        [Column("q6_answer")]
        public string? Q6Answer { get; set; }

        [MaxLength(500)]
        [Column("q6_notes")]
        public string? Q6Notes { get; set; }

        [MaxLength(10)]
        [Column("q7_answer")]
        public string? Q7Answer { get; set; }

        [MaxLength(500)]
        [Column("q7_notes")]
        public string? Q7Notes { get; set; }

        [Column("signature_karyawan")]
        public string? SignatureKaryawan { get; set; }

        [Column("signature_pengawas")]
        public string? SignaturePengawas { get; set; }

        [MaxLength(500)]
        [Column("supervisor_notes")]
        public string? SupervisorNotes { get; set; }

        [Column("approved_at")]
        public DateTime? ApprovedAt { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [Column("updated_at")]
        public DateTime UpdatedAt { get; set; } = DateTime.Now;

        [Column("is_deleted")]
        public bool IsDeleted { get; set; } = false;
    }
}

