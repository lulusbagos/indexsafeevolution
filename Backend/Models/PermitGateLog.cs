using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_permit_gate_log")]
    public class PermitGateLog
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        [Column("nik")]
        public string Nik { get; set; } = string.Empty;

        [MaxLength(150)]
        [Column("nama")]
        public string? Nama { get; set; }

        [MaxLength(150)]
        [Column("perusahaan")]
        public string? Perusahaan { get; set; }

        [MaxLength(150)]
        [Column("departemen")]
        public string? Departemen { get; set; }

        [MaxLength(100)]
        [Column("nomor_permit")]
        public string? NomorPermit { get; set; }

        [Required]
        [MaxLength(20)]
        [Column("direction")]
        public string Direction { get; set; } = "MASUK"; // 'MASUK' / 'KELUAR'

        [MaxLength(50)]
        [Column("nomor_unit")]
        public string? NomorUnit { get; set; }

        [Column("jumlah_penumpang")]
        public int JumlahPenumpang { get; set; } = 0;

        [Required]
        [MaxLength(500)]
        [Column("keperluan")]
        public string Keperluan { get; set; } = string.Empty;

        [MaxLength(150)]
        [Column("lokasi_pos")]
        public string? LokasiPos { get; set; }

        [Required]
        [MaxLength(50)]
        [Column("created_by_nik")]
        public string CreatedByNik { get; set; } = string.Empty;

        [MaxLength(150)]
        [Column("created_by_name")]
        public string? CreatedByName { get; set; }

        [Column("latitude")]
        public double? Latitude { get; set; }

        [Column("longitude")]
        public double? Longitude { get; set; }

        [MaxLength(255)]
        [Column("detil_lokasi")]
        public string? DetilLokasi { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;
    }
}
