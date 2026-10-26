using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_dci_report")]
    public class DciReport
    {
        [Key]
        public int Id { get; set; }

        public DateTime Tanggal { get; set; } = DateTime.Today;

        public TimeSpan Waktu { get; set; } = DateTime.Now.TimeOfDay;

        [MaxLength(50)]
        public string Nik { get; set; } = string.Empty;

        [MaxLength(150)]
        public string Nama { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? Departemen { get; set; }

        [MaxLength(200)]
        public string? Perusahaan { get; set; }

        public int? PerusahaanId { get; set; }

        [MaxLength(100)]
        public string Area { get; set; } = string.Empty;

        [MaxLength(200)]
        public string Lokasi { get; set; } = string.Empty;

        [MaxLength(250)]
        public string? DetilLokasi { get; set; }

        [MaxLength(100)]
        public string? Disposal { get; set; }

        [MaxLength(100)]
        public string? NamaDump { get; set; }

        [MaxLength(100)]
        public string? Pad { get; set; }

        [MaxLength(20)]
        public string? Shift { get; set; }

        [MaxLength(50)]
        public string? Latitude { get; set; }

        [MaxLength(50)]
        public string? Longitude { get; set; }

        // Parameter Penilaian Dump Condition Index (DCI) - Skor 0 - 100
        // 1. Daya Dukung & Kerataan Lantai Dump (15%)
        public int SkorLantaiDump { get; set; } = 100;

        // 2. Tanggul Pengaman / Safety Berm (15%)
        public int SkorSafetyBerm { get; set; } = 100;

        // 3. Kondisi Crest & Tepi Dumping (15%)
        public int SkorKondisiCrest { get; set; } = 100;

        // 4. Counter Grade Lantai Dump (15%)
        public int SkorGradeDumping { get; set; } = 100;

        // 5. Drainase & Saluran Air Dump (10%)
        public int SkorDrainaseDump { get; set; } = 100;

        // 6. Penataan Spillage & Kebersihan (10%)
        public int SkorPenataanSpillage { get; set; } = 100;

        // 7. Rambu K3 & Lampu Penerangan (10%)
        public int SkorRambuPenerangan { get; set; } = 100;

        // 8. Spotter & Pola Manuver Unit (10%)
        public int SkorSpotterManuver { get; set; } = 100;

        public double TotalScore { get; set; } = 100;

        [MaxLength(50)]
        public string KategoriIndex { get; set; } = "Baik";

        [MaxLength(2000)]
        public string? Catatan { get; set; }

        [MaxLength(2000)]
        public string? TindakanPerbaikan { get; set; }

        [MaxLength(100)]
        public string? Pic { get; set; }

        [MaxLength(500)]
        public string? FotoUrl { get; set; }

        [Column("is_deleted")]
        public bool IsDeleted { get; set; } = false;

        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public DateTime? UpdatedAt { get; set; }
    }
}
