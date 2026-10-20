using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_t_attendance_event")]
    public class AttendanceEvent
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Required]
        [MaxLength(160)]
        [Column("event_name")]
        public string EventName { get; set; } = string.Empty;

        [MaxLength(220)]
        [Column("event_location")]
        public string? EventLocation { get; set; }

        [MaxLength(1200)]
        [Column("event_description")]
        public string? EventDescription { get; set; }

        [Column("start_at")]
        public DateTime StartAt { get; set; }

        [Column("end_at")]
        public DateTime EndAt { get; set; }

        [Required]
        [MaxLength(80)]
        [Column("qr_token")]
        public string QrToken { get; set; } = string.Empty;

        [MaxLength(100)]
        [Column("created_by")]
        public string? CreatedBy { get; set; }

        [Column("is_active")]
        public bool IsActive { get; set; } = true;

        [Column("is_deleted")]
        public bool IsDeleted { get; set; } = false;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public List<AttendanceRecord> AttendanceRecords { get; set; } = new List<AttendanceRecord>();
    }
}
