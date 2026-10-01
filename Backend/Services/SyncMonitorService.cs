using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;

namespace Indexsafe.Api.Services
{
    public class TransactionEvent
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N")[..8];
        public string Type { get; set; } = "Hazard";
        public string Source { get; set; } = "Offline Outbox Sync";
        public int ServerId { get; set; }
        public string Code { get; set; } = string.Empty;
        public string Nik { get; set; } = string.Empty;
        public string Nama { get; set; } = string.Empty;
        public string Perusahaan { get; set; } = string.Empty;
        public string Area { get; set; } = string.Empty;
        public string Lokasi { get; set; } = string.Empty;
        public string DetilLokasi { get; set; } = string.Empty;
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public double? GpsAccuracy { get; set; }
        public bool HasGps => Latitude.HasValue && Longitude.HasValue;
        public bool HasPhoto { get; set; }
        public string? PhotoUrl { get; set; }
        public DateTime InspectionDate { get; set; } = DateTime.Today;
        public DateTime SyncedAt { get; set; } = DateTime.Now;
        public long DurationMs { get; set; }
        public string Status { get; set; } = "Success";
        public string Summary { get; set; } = string.Empty;
    }

    public class UploadEvent
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N")[..8];
        public string FileName { get; set; } = string.Empty;
        public string Category { get; set; } = "hazard";
        public long OriginalSizeKb { get; set; }
        public long CompressedSizeKb { get; set; }
        public int SavedPercent => OriginalSizeKb > 0 ? (int)Math.Max(0, (1.0 - ((double)CompressedSizeKb / OriginalSizeKb)) * 100) : 0;
        public string SavedUrl { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; } = DateTime.Now;
        public long DurationMs { get; set; }
        public string Status { get; set; } = "Compressed";
    }

    public class ErrorEvent
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N")[..8];
        public DateTime Timestamp { get; set; } = DateTime.Now;
        public string Module { get; set; } = "Sync";
        public string Endpoint { get; set; } = "/api/tran";
        public string? ClientUuid { get; set; }
        public string? UserNik { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
        public string? StackTrace { get; set; }
        public string Severity { get; set; } = "ERROR"; // ERROR, WARNING
        public string? PayloadSnippet { get; set; }
        public string SuggestedFix { get; set; } = string.Empty;
    }

    public class DashboardStats
    {
        public int TotalTransactionsToday { get; set; }
        public int TotalOfflineSyncs { get; set; }
        public int TotalMediaUploads { get; set; }
        public int TotalErrors { get; set; }
        public int TotalGpsMapped { get; set; }
        public double BandwidthSavedMb { get; set; }
        public bool DatabaseConnected { get; set; } = true;
        public string DatabaseServer { get; set; } = "172.16.1.93";
        public string DatabaseName { get; set; } = "DB_SAP";
        public DateTime ServerTime { get; set; } = DateTime.Now;
    }

    public class SyncMonitorService
    {
        private readonly ConcurrentQueue<TransactionEvent> _transactions = new();
        private readonly ConcurrentQueue<UploadEvent> _uploads = new();
        private readonly ConcurrentQueue<ErrorEvent> _errors = new();
        private readonly int _maxQueueSize = 200;

        public void RecordTransaction(TransactionEvent evt)
        {
            _transactions.Enqueue(evt);
            while (_transactions.Count > _maxQueueSize && _transactions.TryDequeue(out _)) { }
        }

        public void RecordUpload(UploadEvent evt)
        {
            _uploads.Enqueue(evt);
            while (_uploads.Count > _maxQueueSize && _uploads.TryDequeue(out _)) { }
        }

        public void RecordError(ErrorEvent evt)
        {
            _errors.Enqueue(evt);
            while (_errors.Count > _maxQueueSize && _errors.TryDequeue(out _)) { }
        }

        public List<TransactionEvent> GetRecentTransactions(int limit = 50)
        {
            return _transactions.Reverse().Take(limit).ToList();
        }

        public List<UploadEvent> GetRecentUploads(int limit = 50)
        {
            return _uploads.Reverse().Take(limit).ToList();
        }

        public List<ErrorEvent> GetRecentErrors(int limit = 50)
        {
            return _errors.Reverse().Take(limit).ToList();
        }

        public DashboardStats GetStats()
        {
            var txList = _transactions.ToList();
            var uploadList = _uploads.ToList();
            var errorList = _errors.ToList();

            var today = DateTime.Today;
            var totalTxToday = txList.Count(x => x.SyncedAt.Date == today);
            var totalOffline = txList.Count(x => x.Source.Contains("Offline", StringComparison.OrdinalIgnoreCase));
            var totalGps = txList.Count(x => x.HasGps);

            long totalOriginalKb = uploadList.Sum(u => u.OriginalSizeKb);
            long totalCompressedKb = uploadList.Sum(u => u.CompressedSizeKb);
            double savedMb = Math.Max(0, (totalOriginalKb - totalCompressedKb) / 1024.0);

            return new DashboardStats
            {
                TotalTransactionsToday = Math.Max(totalTxToday, txList.Count),
                TotalOfflineSyncs = totalOffline,
                TotalMediaUploads = uploadList.Count,
                TotalErrors = errorList.Count,
                TotalGpsMapped = totalGps,
                BandwidthSavedMb = Math.Round(savedMb, 2),
                DatabaseConnected = true,
                DatabaseServer = "172.16.1.93",
                DatabaseName = "DB_SAP",
                ServerTime = DateTime.Now
            };
        }
    }
}
