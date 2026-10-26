using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_gci_report")]
    public class GciReport
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
        public string? Pit { get; set; }

        [MaxLength(100)]
        public string? NamaLereng { get; set; }

        // Area Type: Highwall, Lowwall, Sidewall, Bench/Jenjang, Disposal Slope, In-Pit Dump, Stockpile Embankment, Sump Slope
        [MaxLength(50)]
        public string? AreaType { get; set; } = "Highwall";

        [MaxLength(20)]
        public string? Shift { get; set; }

        [MaxLength(50)]
        public string? Latitude { get; set; }

        [MaxLength(50)]
        public string? Longitude { get; set; }

        // Parameter Penilaian Geotechnical Condition Index (GCI) - Bobot Total 100%
        // 1. Geometri & Kemiringan Lereng vs Desain (15%)
        public int SkorGeometriLereng { get; set; } = 100;

        // 2. Kondisi Crest, Toe & Catch Berm (15%)
        public int SkorKondisiCrestToe { get; set; } = 100;

        // 3. Bebas Retakan Tarik & Amblesan (15%)
        public int SkorTensionCrack { get; set; } = 100;

        // 4. Kestabilan Batuan, Bulging & Rockfall (15%)
        public int SkorKestabilanBatuan { get; set; } = 100;

        // 5. Kontrol Rembesan Air & Drainase (10%)
        public int SkorRembesanDrainase { get; set; } = 100;

        // 6. Pemantauan Sensor & Tren Deformasi (10%)
        public int SkorPemantauanSensor { get; set; } = 100;

        // 7. Demarkasi Exclusion Zone & Tanggap Darurat (10%)
        public int SkorDemarkasiZona { get; set; } = 100;

        // 8. Kepatuhan Rekomendasi Geoteknik (10%)
        public int SkorKepatuhanRekomendasi { get; set; } = 100;

        public double TotalScore { get; set; } = 100;

        [MaxLength(50)]
        public string KategoriIndex { get; set; } = "Baik";

        // TARP Level: GREEN, YELLOW, ORANGE, RED
        [MaxLength(50)]
        public string TarpLevel { get; set; } = "GREEN";

        [MaxLength(2000)]
        public string? Catatan { get; set; }

        [MaxLength(2000)]
        public string? TindakanPerbaikan { get; set; }

        [MaxLength(100)]
        public string? Pic { get; set; }

        [MaxLength(50)]
        public string? PicNik { get; set; }

        [MaxLength(250)]
        public string? JudulTemuan { get; set; }

        public DateTime? DueDate { get; set; }

        [MaxLength(500)]
        public string? FotoUrl { get; set; }

        [MaxLength(50)]
        public string? JenisInspeksi { get; set; } = "Inspeksi Rutin";

        [MaxLength(100)]
        public string? PjaNama { get; set; }

        [MaxLength(50)]
        public string? PjaNik { get; set; }

        [Column("is_deleted")]
        public bool IsDeleted { get; set; } = false;

        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public DateTime? UpdatedAt { get; set; }
    }
}
