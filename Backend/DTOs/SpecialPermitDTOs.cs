using System;
using System.Collections.Generic;

namespace Indexsafe.Api.DTOs
{
    public class SpecialPermitItemDto
    {
        public string Id { get; set; } = string.Empty;
        public string ReqId { get; set; } = string.Empty;
        public string ActivityType { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime? IssueDate { get; set; }
        public string? IssueTime { get; set; }
        public string? PjoNik { get; set; }
        public string? PjoName { get; set; }
        public string? InspectorNik { get; set; }
        public string? InspectorName { get; set; }
        public int? DepartmentId { get; set; }
        public string? Department { get; set; }
        public int? CompanyId { get; set; }
        public string? CompanyName { get; set; }
        public string? ImplementingContractor { get; set; }
        public string? ApplicantNik { get; set; }
        public string? ApplicantName { get; set; }
        public string? WorkLocation { get; set; }
        public string? Phone { get; set; }
        public string? ResponsiblePersonNik { get; set; }
        public string? ResponsiblePersonName { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public string? JobDescription { get; set; }
        public string? SpecialEquipment { get; set; }
        public string? WorkRelatedHazard { get; set; }
        public bool HasFollowup { get; set; }
        public string? LatestInspectionStatus { get; set; }
        public DateTime? LatestInspectionTime { get; set; }
        public string? LatestInspectorNik { get; set; }
        public string? LatestInspectorName { get; set; }
        public string? LatestInspectorRole { get; set; }
        public int TotalFollowups { get; set; }
    }

    public class ReassignSpecialPermitDto
    {
        public string SpecialPermitId { get; set; } = string.Empty;
        public string NewInspectorNik { get; set; } = string.Empty;
        public string NewInspectorName { get; set; } = string.Empty;
        public string? Reason { get; set; }
    }

    public class SpecialPermitDetailDto
    {
        public SpecialPermitItemDto Permit { get; set; } = new();
        public List<SpecialPermitFollowupItemDto> Followups { get; set; } = new();
    }

    public class SpecialPermitFollowupItemDto
    {
        public long Id { get; set; }
        public string SpecialPermitId { get; set; } = string.Empty;
        public string? ReqId { get; set; }
        public string? ActivityType { get; set; }
        public string? WorkLocation { get; set; }
        public string InspectorNik { get; set; } = string.Empty;
        public string? InspectorName { get; set; }
        public string? InspectorRole { get; set; }
        public string InspectionStatus { get; set; } = "AMAN";
        public string? InspectionNotes { get; set; }
        public string? CorrectiveAction { get; set; }
        public bool IsSafe { get; set; } = true;
        public int WorkConditionRating { get; set; } = 5;
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public DateTime InspectionTime { get; set; }
        public List<SpecialPermitPhotoDto> Photos { get; set; } = new();
    }

    public class SpecialPermitPhotoDto
    {
        public long Id { get; set; }
        public long FollowupId { get; set; }
        public string PhotoUrl { get; set; } = string.Empty;
        public string? Caption { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class CreateSpecialPermitFollowupDto
    {
        public string SpecialPermitId { get; set; } = string.Empty;
        public string? ReqId { get; set; }
        public string? ActivityType { get; set; }
        public string? WorkLocation { get; set; }
        public string InspectorNik { get; set; } = string.Empty;
        public string? InspectorName { get; set; }
        public string? InspectorRole { get; set; } // PJO, INSPECTOR, SUPERVISOR
        public string InspectionStatus { get; set; } = "AMAN"; // AMAN, TEMUAN, DIHENTIKAN, SELESAI
        public string? InspectionNotes { get; set; }
        public string? CorrectiveAction { get; set; }
        public bool IsSafe { get; set; } = true;
        public int WorkConditionRating { get; set; } = 5;
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public List<string> PhotosBase64 { get; set; } = new();
    }
}
