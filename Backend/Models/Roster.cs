using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_m_roster")]
    public class Roster
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Column("id")]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        [Column("nik")]
        public string Nik { get; set; } = string.Empty;

        [Required]
        [Column("awal_dinas")]
        public DateTime AwalDinas { get; set; }

        [Required]
        [Column("akhir_dinas")]
        public DateTime AkhirDinas { get; set; }

        [Required]
        [Column("awal_cuti")]
        public DateTime AwalCuti { get; set; }

        [Required]
        [Column("akhir_cuti")]
        public DateTime AkhirCuti { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [Column("updated_at")]
        public DateTime? UpdatedAt { get; set; } = DateTime.Now;

        [MaxLength(50)]
        [Column("tipe_roster")]
        public string? TipeRoster { get; set; } = "REGULER"; // "REGULER" or "TUGAS"

        [MaxLength(255)]
        [Column("keterangan")]
        public string? Keterangan { get; set; }

        [MaxLength(30)]
        [Column("status")]
        public string? Status { get; set; } = "APPROVED"; // "APPROVED", "PENDING_APPROVAL", "REJECTED"

        [Column("id_reinduksi")]
        public int? IdReinduksi { get; set; }

        [MaxLength(50)]
        [Column("nik_pengawas")]
        public string? NikPengawas { get; set; }

        [MaxLength(150)]
        [Column("nama_pengawas")]
        public string? NamaPengawas { get; set; }
    }
}
