using System;
using System.Text.Json.Serialization;

namespace Indexsafe.Api.DTOs
{
    public class LoginRequest
    {
        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("nik")]
        public string? Nik { get; set; }

        [JsonPropertyName("password")]
        public string Password { get; set; } = string.Empty;
    }

    public class RegisterRequest
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("password")]
        public string Password { get; set; } = string.Empty;

        [JsonPropertyName("password_confirmation")]
        public string PasswordConfirmation { get; set; } = string.Empty;
    }

    public class ChangePasswordRequest
    {
        [JsonPropertyName("old_password")]
        public string? OldPasswordSnake { get; set; }

        [JsonPropertyName("oldPassword")]
        public string? OldPasswordCamel { get; set; }

        [JsonIgnore]
        public string OldPassword
        {
            get => !string.IsNullOrWhiteSpace(OldPasswordSnake) ? OldPasswordSnake : (OldPasswordCamel ?? string.Empty);
            set => OldPasswordSnake = value;
        }

        [JsonPropertyName("new_password")]
        public string? NewPasswordSnake { get; set; }

        [JsonPropertyName("newPassword")]
        public string? NewPasswordCamel { get; set; }

        [JsonIgnore]
        public string NewPassword
        {
            get => !string.IsNullOrWhiteSpace(NewPasswordSnake) ? NewPasswordSnake : (NewPasswordCamel ?? string.Empty);
            set => NewPasswordSnake = value;
        }

        [JsonPropertyName("new_password_confirmation")]
        public string? NewPasswordConfirmationSnake { get; set; }

        [JsonPropertyName("newPasswordConfirmation")]
        public string? NewPasswordConfirmationCamel { get; set; }

        [JsonIgnore]
        public string NewPasswordConfirmation
        {
            get => !string.IsNullOrWhiteSpace(NewPasswordConfirmationSnake) ? NewPasswordConfirmationSnake : (NewPasswordConfirmationCamel ?? string.Empty);
            set => NewPasswordConfirmationSnake = value;
        }
    }

    public class AuthResponse
    {
        [JsonPropertyName("token")]
        public string Token { get; set; } = string.Empty;

        [JsonPropertyName("user")]
        public UserDto User { get; set; } = new();

        [JsonPropertyName("profile")]
        public UserProfileDto? Profile { get; set; }
    }

    public class UserDto
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("role")]
        public string Role { get; set; } = string.Empty;

        [JsonPropertyName("company")]
        public string Company { get; set; } = string.Empty;

        [JsonPropertyName("company_id")]
        public int CompanyId { get; set; }

        [JsonPropertyName("department")]
        public string Department { get; set; } = string.Empty;

        [JsonPropertyName("job_title")]
        public string JobTitle { get; set; } = string.Empty;

        [JsonPropertyName("created_at")]
        public string? CreatedAt { get; set; }
    }

    public class UserProfileDto
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }

        [JsonPropertyName("no_nik")]
        public string NoNik { get; set; } = string.Empty;

        [JsonPropertyName("nama_lengkap")]
        public string NamaLengkap { get; set; } = string.Empty;

        [JsonPropertyName("nama_alias")]
        public string NamaAlias { get; set; } = string.Empty;

        [JsonPropertyName("company")]
        public string Company { get; set; } = string.Empty;

        [JsonPropertyName("company_id")]
        public int CompanyId { get; set; }

        [JsonPropertyName("user_id")]
        public int UserId { get; set; }

        [JsonPropertyName("depart")]
        public string Depart { get; set; } = string.Empty;

        [JsonPropertyName("section")]
        public string Section { get; set; } = string.Empty;

        [JsonPropertyName("posisi")]
        public string Posisi { get; set; } = string.Empty;

        [JsonPropertyName("foto")]
        public string? Foto { get; set; }

        [JsonPropertyName("role")]
        public string Role { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("phone")]
        public string? Phone { get; set; }

        [JsonPropertyName("my_hazards")]
        public int MyHazards { get; set; }

        [JsonPropertyName("my_inspections")]
        public int MyInspections { get; set; }

        [JsonPropertyName("my_safety_talks")]
        public int MySafetyTalks { get; set; }

        [JsonPropertyName("my_observasi")]
        public int MyObservasi { get; set; }

        [JsonPropertyName("my_coaching")]
        public int MyCoaching { get; set; }

        [JsonPropertyName("my_p5ms")]
        public int MyP5ms { get; set; }

        // Targets from vw_r_karyawan_jabatan_mapping_preview
        [JsonPropertyName("target_hazard_report")]
        public int TargetHazardReport { get; set; }

        [JsonPropertyName("target_inspeksi")]
        public int TargetInspeksi { get; set; }

        [JsonPropertyName("target_safety_talk")]
        public int TargetSafetyTalk { get; set; }

        [JsonPropertyName("target_observasi")]
        public int TargetObservasi { get; set; }

        [JsonPropertyName("target_coaching")]
        public int TargetCoaching { get; set; }

        [JsonPropertyName("target_p5m")]
        public int TargetP5m { get; set; }

        [JsonPropertyName("total_target")]
        public int TotalTarget { get; set; }

        [JsonPropertyName("kategori_pengawas")]
        public string? KategoriPengawas { get; set; }

        [JsonPropertyName("alasan_target_zero")]
        public string? AlasanTargetZero { get; set; }

        // Lifetime All-time totals
        [JsonPropertyName("my_hazards_total")]
        public int MyHazardsTotal { get; set; }

        [JsonPropertyName("my_inspections_total")]
        public int MyInspectionsTotal { get; set; }

        [JsonPropertyName("my_safety_talks_total")]
        public int MySafetyTalksTotal { get; set; }

        [JsonPropertyName("my_observasi_total")]
        public int MyObservasiTotal { get; set; }

        [JsonPropertyName("my_coaching_total")]
        public int MyCoachingTotal { get; set; }

        [JsonPropertyName("my_p5ms_total")]
        public int MyP5msTotal { get; set; }

        [JsonPropertyName("total_submissions")]
        public int TotalSubmissions { get; set; }

        [JsonPropertyName("compliance_rate")]
        public double ComplianceRate { get; set; }

        [JsonPropertyName("badge_name")]
        public string? BadgeName { get; set; }

        [JsonPropertyName("badge_icon")]
        public string? BadgeIcon { get; set; }

        [JsonPropertyName("badge_color")]
        public string? BadgeColor { get; set; }

        // League & Performance in Company & Dept (matching /Performance/Index)
        [JsonPropertyName("is_my_week_compliant")]
        public bool IsMyWeekCompliant { get; set; } = true;

        [JsonPropertyName("my_total_week")]
        public int MyTotalWeek { get; set; }

        [JsonPropertyName("my_weekly_target")]
        public int MyWeeklyTarget { get; set; }

        [JsonPropertyName("user_dept_name")]
        public string? UserDeptName { get; set; }

        [JsonPropertyName("user_dept_rank")]
        public int UserDeptRank { get; set; } = 19;

        [JsonPropertyName("user_dept_total_count")]
        public int UserDeptTotalCount { get; set; } = 24;

        [JsonPropertyName("user_dept_mtd_rate")]
        public double UserDeptMtdRate { get; set; } = 0.0;

        [JsonPropertyName("user_emp_dept_rank")]
        public int UserEmpDeptRank { get; set; } = 5;

        [JsonPropertyName("user_emp_dept_total_count")]
        public int UserEmpDeptTotalCount { get; set; } = 5;

        [JsonPropertyName("user_emp_company_rank")]
        public int? UserEmpCompanyRank { get; set; }

        [JsonPropertyName("user_emp_company_total_count")]
        public int? UserEmpCompanyTotalCount { get; set; }

        // BIMA PostgreSQL (tb_permit & tb_simper)
        [JsonPropertyName("has_permit")]
        public bool HasPermit { get; set; }

        [JsonPropertyName("permit_nomor")]
        public string? PermitNomor { get; set; }

        [JsonPropertyName("permit_status")]
        public string? PermitStatus { get; set; }

        [JsonPropertyName("permit_last_expired")]
        public string? PermitLastExpired { get; set; }

        [JsonPropertyName("permit_berakhir_kerja")]
        public string? PermitBerakhirKerja { get; set; }

        [JsonPropertyName("is_permit_active")]
        public bool IsPermitActive { get; set; }

        [JsonPropertyName("has_simper")]
        public bool HasSimper { get; set; }

        [JsonPropertyName("simper_nomor")]
        public string? SimperNomor { get; set; }

        [JsonPropertyName("simper_status")]
        public string? SimperStatus { get; set; }

        [JsonPropertyName("jenis_simper")]
        public string? JenisSimper { get; set; }

        [JsonPropertyName("simper_expired_date")]
        public string? SimperExpiredDate { get; set; }

        [JsonPropertyName("simper_masa_berlaku")]
        public string? SimperMasaBerlaku { get; set; }

        [JsonPropertyName("simper_jenis_sim")]
        public string? SimperJenisSim { get; set; }

        [JsonPropertyName("simper_nomor_sim")]
        public string? SimperNomorSim { get; set; }

        [JsonPropertyName("is_simper_active")]
        public bool IsSimperActive { get; set; }
    }

    public class ResetPasswordRequest
    {
        [JsonPropertyName("nik")]
        public string? Nik { get; set; }

        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("birth_date")]
        public string? BirthDateSnake { get; set; }

        [JsonPropertyName("birthDate")]
        public string? BirthDateCamel { get; set; }

        [JsonPropertyName("tanggal_lahir")]
        public string? TanggalLahir { get; set; }

        [JsonIgnore]
        public string BirthDate => !string.IsNullOrWhiteSpace(BirthDateSnake)
            ? BirthDateSnake
            : (!string.IsNullOrWhiteSpace(BirthDateCamel)
                ? BirthDateCamel
                : (TanggalLahir ?? string.Empty));
    }
}
