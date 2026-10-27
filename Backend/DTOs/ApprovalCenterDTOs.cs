using System;
using System.Collections.Generic;

namespace Indexsafe.Api.DTOs
{
    public class BimaUserStatusDto
    {
        public bool IsRegistered { get; set; }
        public int? UserId { get; set; }
        public string? Fullname { get; set; }
        public string? EmployeeId { get; set; }
        public int? RoleId { get; set; }
        public string? RoleName { get; set; }
        public string? Department { get; set; }
        public string? CompanyName { get; set; }
        public int? CompanyId { get; set; }
        public int? DepartmentId { get; set; }
        public int PendingCount { get; set; }
        public int MySubmissionCount { get; set; }
        public List<UserRoleInfoDto> Roles { get; set; } = new();
    }

    public class UserRoleInfoDto
    {
        public int RoleId { get; set; }
        public string RoleName { get; set; } = string.Empty;
    }

    public class ApprovalItemDto
    {
        public long ApprovalId { get; set; }
        public string Nomor { get; set; } = string.Empty;
        public string ReqId { get; set; } = string.Empty;
        public string Module { get; set; } = string.Empty; // PERMIT, SIMPER, SPECIAL_PERMIT, COMMISSIONING
        public int Level { get; set; }
        public DateTime? ReqTime { get; set; }
        public string ReqStatus { get; set; } = string.Empty;
        public string ApplicantNik { get; set; } = string.Empty;
        public string ApplicantName { get; set; } = string.Empty;
        public string CompanyName { get; set; } = string.Empty;
        public string Department { get; set; } = string.Empty;
        public string SubmissionType { get; set; } = string.Empty;
        public string? SubDetail { get; set; }
        public int? RoleId { get; set; }
        public string? RoleName { get; set; }
        public string? Notes { get; set; }
        public bool IsCurrentDocument { get; set; }
        public string? ActionBy { get; set; }
        public string? ActionByName { get; set; }
        public DateTime? ActionTime { get; set; }
    }

    public class ApprovalDetailDto
    {
        public ApprovalItemDto Header { get; set; } = new();
        public List<ApprovalHistoryItemDto> History { get; set; } = new();
        public List<ApprovalDocItemDto> Documents { get; set; } = new();
        public bool CanApprove { get; set; }
    }

    public class ApprovalHistoryItemDto
    {
        public long Id { get; set; }
        public int LevelApproval { get; set; }
        public string ReqStatus { get; set; } = string.Empty;
        public int? RoleId { get; set; }
        public string RoleName { get; set; } = string.Empty;
        public string? ActionBy { get; set; }
        public string? ActionByName { get; set; }
        public DateTime? ActionTime { get; set; }
        public string? Notes { get; set; }
    }

    public class ApprovalDocItemDto
    {
        public long Id { get; set; }
        public string DocumentName { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public string? FileType { get; set; }
        public string? FilePath { get; set; }
        public DateTime? CreatedAt { get; set; }
    }

    public class ApprovalActionRequestDto
    {
        public long ApprovalId { get; set; }
        public string Action { get; set; } = "APPROVED"; // APPROVED or REJECTED
        public string? Notes { get; set; }
        public string? UserNik { get; set; }
        public string? UserName { get; set; }
    }

    public class ApprovalActionResponseDto
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public int? NextLevel { get; set; }
        public string? NextStatus { get; set; }
    }
}
