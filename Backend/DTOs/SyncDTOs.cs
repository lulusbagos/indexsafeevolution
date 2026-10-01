using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Http;

namespace Indexsafe.Api.DTOs
{
    public class ApiResponse<T>
    {
        [JsonPropertyName("status")]
        public bool Status { get; set; } = true;

        [JsonPropertyName("message")]
        public string? Message { get; set; }

        [JsonPropertyName("data")]
        public T? Data { get; set; }
    }

    public class ApiListResponse<T>
    {
        [JsonPropertyName("status")]
        public bool Status { get; set; } = true;

        [JsonPropertyName("data")]
        public List<T> Data { get; set; } = new();
    }

    public class SyncResultDto
    {
        [JsonPropertyName("id")]
        public int Id { get; set; }

        [JsonPropertyName("code")]
        public string? Code { get; set; }

        [JsonPropertyName("updated_at")]
        public string? UpdatedAt { get; set; }
    }

    public class HazardTransactionDto
    {
        public int? Id { get; set; }
        public DateTime? Tanggal { get; set; }
        public string? Waktu { get; set; }
        public string? Area { get; set; }
        public string? Lokasi { get; set; }
        public string? DetilLokasi { get; set; }
        public string? Temuan { get; set; }
        public string? KategoriBahaya { get; set; }
        public string? JenisBahaya { get; set; }
        public string? JenisKetidaksesuaian { get; set; }
        public string? TingkatResiko { get; set; }
        public string? Perbaikan { get; set; }
        public string? TindakanPerbaikan { get; set; }
        public string? Pja { get; set; }
        public string? NikPja { get; set; }
        public string? DepartemenPja { get; set; }
        public string? StatusTemuan { get; set; }

        // GPS Location Fields
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public double? GpsAccuracy { get; set; }

        // Idempotency Key from Mobile
        public string? ClientUuid { get; set; }

        // Photos from Form Data
        public IFormFile? Image { get; set; }
        public IFormFile? RepairImage { get; set; }
        public IFormFile? ActionImage { get; set; }
    }

    public class InspectionTransactionDto
    {
        public int? Id { get; set; }
        public DateTime? Tanggal { get; set; }
        public string? Waktu { get; set; }
        public string? JenisInspeksi { get; set; }
        public string? Area { get; set; }
        public string? Lokasi { get; set; }
        public string? DetilLokasi { get; set; }
        public string? Pja { get; set; }
        public string? NikPja { get; set; }
        public string? DepartemenPja { get; set; }
        public string? Catatan { get; set; }

        public int Q1_1 { get; set; }
        public int Q1_2 { get; set; }
        public int Q1_3 { get; set; }
        public int Q2_1 { get; set; }
        public int Q2_2 { get; set; }
        public int Q2_3 { get; set; }
        public int Q3_1 { get; set; }
        public int Q3_2 { get; set; }
        public int Q3_3 { get; set; }
        public int Q4_1 { get; set; }
        public int Q4_2 { get; set; }
        public int Q4_3 { get; set; }
        public int Q5_1 { get; set; }
        public int Q5_2 { get; set; }
        public int Q5_3 { get; set; }

        // GPS Location Fields
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public double? GpsAccuracy { get; set; }

        public string? ClientUuid { get; set; }

        public IFormFile? Image { get; set; }
    }

    public class ActionPlanUpdateDto
    {
        public int? Id { get; set; }
        public string? ItemSap { get; set; }
        public string? RencanaPerbaikan { get; set; }
        public DateTime? TanggalRencanaPerbaikan { get; set; }
        public string? Perbaikan { get; set; }
        public DateTime? TanggalPerbaikan { get; set; }
        public string? Pic { get; set; }
        public string? NikPic { get; set; }
        public string? DepartemenPic { get; set; }
        public string? Status { get; set; }
        public string? Overdue { get; set; }
        public string? AlasanOverdue { get; set; }

        // GPS Location
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        public IFormFile? RepairImage { get; set; }
        public IFormFile? ActionImage { get; set; }
    }

    public class DetailItemDto
    {
        public int? Id { get; set; }
        public int? RefId { get; set; } // Server Tran ID
        public int? TranId { get; set; }
        public string? Name { get; set; }
        public int? PointId { get; set; }
        public int? Level { get; set; }
        public int? Yesno { get; set; }
        public string? Remark { get; set; }
        public int? Status { get; set; }
        public int? Repair { get; set; }
        public string? RepairRemark { get; set; }

        public IFormFile? Image { get; set; }
        public IFormFile? RepairImage { get; set; }
        public IFormFile? ActionImage { get; set; }
    }

    public class FileAttachmentDto
    {
        public int? Id { get; set; }
        public int? TranId { get; set; }
        public int? DetailId { get; set; }
        public string? Table { get; set; }
        public string? Category { get; set; }
        public string? Type { get; set; }

        public IFormFile? Name { get; set; }
        public IFormFile? File { get; set; }
    }
}
