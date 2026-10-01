using System;
using System.Collections.Generic;

namespace Indexsafe.Api.Models
{
    public class HazardAiAnalysisResult
    {
        public string PriorityLevel { get; set; } = "MEDIUM";
        public string PriorityLabel { get; set; } = "MEDIUM - Prioritas Sedang";
        public string PriorityBadgeColor { get; set; } = "#eab308";
        public string PriorityBadgeText { get; set; } = "MEDIUM (Max 7 Hari)";
        public int RecommendedDays { get; set; } = 7;
        public DateTime RecommendedDeadline { get; set; }
        public string RecommendedDueDateText { get; set; } = "7 Hari";
        public string DueDateFormatted { get; set; } = "";
        public string DueDateStatus { get; set; } = "Aktif";
        public string DueDateStatusColor { get; set; } = "#10b981";
        public int DaysRemainingOrOverdue { get; set; } = 0;
        public string RiskCategory { get; set; } = "Sedang";
        public string AiReasoning { get; set; } = "";
        public string ActionRecommendation { get; set; } = "";
        public int QualityScore { get; set; } = 4;
        public string QualityScoreNotes { get; set; } = "";
        public List<string> TriggeredKeywords { get; set; } = new List<string>();
        public bool IsGoldenRuleViolation { get; set; } = false;
        public string GoldenRuleTopic { get; set; } = "";
        public double RiskScore { get; set; } = 0;
    }
}
