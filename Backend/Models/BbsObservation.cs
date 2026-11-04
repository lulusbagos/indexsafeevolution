using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_bbs_observation")]
    public class BbsObservation
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Column("observation_no")]
        [MaxLength(50)]
        public string? ObservationNo { get; set; }

        [Column("observation_type")]
        [MaxLength(50)]
        public string? ObservationType { get; set; } = "Peer Observation";

        [Column("tanggal")]
        public DateTime Tanggal { get; set; } = DateTime.Today;

        [Column("waktu")]
        [MaxLength(10)]
        public string? Waktu { get; set; }

        [Column("observer_nik")]
        [MaxLength(50)]
        public string ObserverNik { get; set; } = string.Empty;

        [Column("observer_nama")]
        [MaxLength(150)]
        public string ObserverNama { get; set; } = string.Empty;

        [Column("observer_dept")]
        [MaxLength(100)]
        public string? ObserverDept { get; set; }

        [Column("observer_perusahaan_id")]
        public int? ObserverPerusahaanId { get; set; }

        [Column("observer_perusahaan")]
        [MaxLength(200)]
        public string? ObserverPerusahaan { get; set; }

        [Column("site")]
        [MaxLength(100)]
        public string? Site { get; set; } = "SITE KAUBUN";

        [Column("area")]
        [MaxLength(100)]
        public string? Area { get; set; }

        [Column("detil_lokasi")]
        [MaxLength(250)]
        public string? DetilLokasi { get; set; }

        [Column("observed_nik")]
        [MaxLength(50)]
        public string? ObservedNik { get; set; }

        [Column("observed_nama")]
        [MaxLength(150)]
        public string? ObservedNama { get; set; }

        [Column("observed_jabatan")]
        [MaxLength(100)]
        public string? ObservedJabatan { get; set; }

        [Column("observed_dept")]
        [MaxLength(100)]
        public string? ObservedDept { get; set; }

        [Column("observed_perusahaan_id")]
        public int? ObservedPerusahaanId { get; set; }

        [Column("observed_perusahaan")]
        [MaxLength(200)]
        public string? ObservedPerusahaan { get; set; }

        [Column("category_id")]
        public int? CategoryId { get; set; }

        [Column("category_name")]
        [MaxLength(150)]
        public string? CategoryName { get; set; }

        [Column("topic_id")]
        public int? TopicId { get; set; }

        [Column("topic_name")]
        [MaxLength(150)]
        public string? TopicName { get; set; }

        [Column("selected_behaviors_json")]
        public string? SelectedBehaviorsJson { get; set; }

        [Column("custom_behavior")]
        [MaxLength(300)]
        public string? CustomBehavior { get; set; }

        [Column("klasifikasi")]
        [MaxLength(50)]
        public string? Klasifikasi { get; set; } = "Perilaku Aman";

        [Column("kondisi_jalan")]
        [MaxLength(100)]
        public string? KondisiJalan { get; set; }

        [Column("kondisi_kerja")]
        [MaxLength(100)]
        public string? KondisiKerja { get; set; }

        [Column("faktor_pemicu")]
        [MaxLength(500)]
        public string? FaktorPemicu { get; set; }

        [Column("tingkat_risiko")]
        [MaxLength(50)]
        public string? TingkatRisiko { get; set; } = "Rendah";

        [Column("deskripsi")]
        [MaxLength(2000)]
        public string? Deskripsi { get; set; }

        [Column("respons_pekerja")]
        [MaxLength(50)]
        public string? ResponsPekerja { get; set; } = "Positif";

        [Column("tindakan_dilakukan")]
        [MaxLength(500)]
        public string? TindakanDilakukan { get; set; }

        [Column("catatan_coaching")]
        [MaxLength(2000)]
        public string? CatatanCoaching { get; set; }

        [Column("foto_url")]
        [MaxLength(500)]
        public string? FotoUrl { get; set; }

        [Column("is_deleted")]
        public bool IsDeleted { get; set; } = false;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [Column("updated_at")]
        public DateTime? UpdatedAt { get; set; } = DateTime.Now;
    }
}
