using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Indexsafe.Api.Models
{
    public class PasswordOverride
    {
        [Key]
        [Required]
        [MaxLength(50)]
        [Column("nrp")]
        public string Nrp { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        [Column("kata_sandi")]
        public string KataSandi { get; set; } = string.Empty;

        [Column("diubah_pada")]
        public DateTime DiubahPada { get; set; } = DateTime.Now;

        [MaxLength(1000)]
        [Column("profile_picture")]
        public string? ProfilePicture { get; set; }

        [Column("has_agreed_to_terms")]
        public bool HasAgreedToTerms { get; set; } = false;

        [MaxLength(500)]
        [Column("fcm_token")]
        public string? FcmToken { get; set; }

        [Column("terakhir_login")]
        public DateTime? TerakhirLogin { get; set; }

        [MaxLength(50)]
        [Column("app_version")]
        public string? AppVersion { get; set; }
    }
}
