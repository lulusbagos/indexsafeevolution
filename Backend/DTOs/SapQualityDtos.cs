using System;
using System.Collections.Generic;

namespace Indexsafe.Api.DTOs
{
    public class SapQualityDashboardResponseDto
    {
        public string Nik { get; set; } = string.Empty;
        public string Nama { get; set; } = string.Empty;
        public string Departemen { get; set; } = string.Empty;
        public string Perusahaan { get; set; } = string.Empty;
        public int? SelectedYear { get; set; }
        public int? SelectedMonth { get; set; }

        // Top summary metrics
        public int TotalAllSap { get; set; }
        public int TotalAssessed { get; set; }
        public int AuditedBySupervisorCount { get; set; }
        public int KualitasBaik { get; set; } // Stars 3-5
        public int KejarTarget { get; set; }  // Stars 1-2
        public double GoodPercentage { get; set; }
        public double TargetPercentage { get; set; }
        public double AverageRating { get; set; } // Scale 1.0 - 5.0
        public double QualityScorePercent { get; set; } // Scale 0 - 100%

        // Star breakdown (counts & percentages)
        public int Star5 { get; set; }
        public int Star4 { get; set; }
        public int Star3 { get; set; }
        public int Star2 { get; set; }
        public int Star1 { get; set; }

        // Module statistics (Hazard, Inspection, SafetyTalk, Observation, Coaching)
        public List<SapQualityModuleStatDto> ModuleStats { get; set; } = new();

        // Submissions & assessments for this user
        public List<SapQualityItemDto> Items { get; set; } = new();
    }

    public class SapQualityModuleStatDto
    {
        public string Key { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public int Total { get; set; }
        public int Assessed { get; set; }
        public double AverageRating { get; set; }
        public string ThemeColor { get; set; } = "#3b82f6";
        public string Icon { get; set; } = "shield";
        public int Star1 { get; set; }
        public int Star2 { get; set; }
        public int Star3 { get; set; }
        public int Star4 { get; set; }
        public int Star5 { get; set; }
    }

    public class SapQualityItemDto
    {
        public int Id { get; set; }
        public string ProgramType { get; set; } = string.Empty; // Hazard, Inspection, SafetyTalk, Observation, Coaching
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public DateTime Tanggal { get; set; }
        public string TanggalFormatted { get; set; } = string.Empty;
        public string? Lokasi { get; set; }
        public int Rating { get; set; } // 1 - 5
        public string QualityLabel { get; set; } = string.Empty; // Sangat Baik, Baik, Cukup, Kurang, Kejar Target
        public string QualityColor { get; set; } = "#10b981";
        public string? Notes { get; set; }
        public bool IsAuditedBySupervisor { get; set; }
        public bool IsAiAssessed { get; set; }
        public string? PhotoUrl { get; set; }
        public string? HazardPriority { get; set; }
        public string? HazardBadgeColor { get; set; }
        public string? HazardDueDateText { get; set; }
    }
}
