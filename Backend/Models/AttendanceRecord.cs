using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_attendance_record")]
    public class AttendanceRecord
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [ForeignKey(nameof(AttendanceEvent))]
        [Column("attendance_event_id")]
        public int AttendanceEventId { get; set; }

        [Required]
        [MaxLength(80)]
        [Column("nik")]
        public string Nik { get; set; } = string.Empty;

        [MaxLength(180)]
        [Column("nama")]
        public string? Nama { get; set; }

        [MaxLength(180)]
        [Column("jabatan")]
        public string? Jabatan { get; set; }

        [MaxLength(180)]
        [Column("perusahaan")]
        public string? Perusahaan { get; set; }

        [Column("scan_at")]
        public DateTime ScanAt { get; set; } = DateTime.Now;

        [MaxLength(60)]
        [Column("source")]
        public string Source { get; set; } = "qr";

        [Column("Latitude")]
        public double? Latitude { get; set; }

        [Column("Longitude")]
        public double? Longitude { get; set; }

        public AttendanceEvent? AttendanceEvent { get; set; }
    }
}
