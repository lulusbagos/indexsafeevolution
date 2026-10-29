using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    [Table("tbl_m_web_campaign")]
    public class WebCampaign
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }

        [Required]
        [MaxLength(200)]
        [Column("title")]
        public string Title { get; set; } = "Kuis & Game K3";

        [Required]
        [MaxLength(1000)]
        [Column("url")]
        public string Url { get; set; } = string.Empty;

        [Column("is_active")]
        public bool IsActive { get; set; } = false;

        /// <summary>"ALL" or "SPECIFIC_USERS"</summary>
        [MaxLength(50)]
        [Column("target_type")]
        public string TargetType { get; set; } = "ALL";

        /// <summary>Daftar NIK yang dipisahkan koma, misal: "24051940986,123456"</summary>
        [Column("target_niks")]
        public string? TargetNiks { get; set; }

        /// <summary>"once_per_day", "every_open", "once_forever"</summary>
        [MaxLength(50)]
        [Column("frequency")]
        public string Frequency { get; set; } = "once_per_day";

        [Column("is_dismissible")]
        public bool IsDismissible { get; set; } = true;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        [Column("updated_at")]
        public DateTime? UpdatedAt { get; set; } = DateTime.Now;
    }
}

