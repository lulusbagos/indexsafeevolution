using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.DTOs;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/special-permit")]
    public class SpecialPermitController : ControllerBase
    {
        private readonly SpecialPermitService _spService;

        public SpecialPermitController(SpecialPermitService spService)
        {
            _spService = spService;
        }

        private string GetCallerNik(string? fallbackNik = null)
        {
            var claimNik = User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
                           ?? User?.FindFirst("nrp")?.Value
                           ?? User?.FindFirst("nik")?.Value;

            return !string.IsNullOrWhiteSpace(fallbackNik) ? fallbackNik.Trim() : (claimNik?.Trim() ?? string.Empty);
        }

        private string GetCallerName(string? fallbackName = null)
        {
            var claimName = User?.FindFirst(ClaimTypes.Name)?.Value
                            ?? User?.FindFirst("nama")?.Value
                            ?? User?.FindFirst("name")?.Value;

            return !string.IsNullOrWhiteSpace(fallbackName) ? fallbackName.Trim() : (claimName?.Trim() ?? string.Empty);
        }

        [HttpGet("list")]
        [AllowAnonymous]
        public async Task<IActionResult> GetList(
            [FromQuery] string? nik,
            [FromQuery] string? status = null,
            [FromQuery] string? search = null)
        {
            var activeNik = GetCallerNik(nik);
            var items = await _spService.GetSpecialPermitsAsync(activeNik, status, search);
            return Ok(new
            {
                status = 200,
                message = "Success",
                count = items.Count,
                data = items
            });
        }

        [HttpGet("detail/{id}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetDetail(string id)
        {
            var detail = await _spService.GetSpecialPermitDetailAsync(id);
            if (detail == null)
            {
                return NotFound(new { status = 404, message = "Special permit tidak ditemukan" });
            }

            return Ok(new
            {
                status = 200,
                message = "Success",
                data = detail
            });
        }

        [HttpPost("followup")]
        [AllowAnonymous]
        public async Task<IActionResult> CreateFollowup([FromBody] CreateSpecialPermitFollowupDto request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.SpecialPermitId))
            {
                return BadRequest(new { status = 400, message = "ID Special Permit wajib diisi" });
            }

            if (request.PhotosBase64 == null || !request.PhotosBase64.Any())
            {
                return BadRequest(new { status = 400, message = "Wajib melampirkan minimal 1 foto dokumentasi bukti inspeksi lapangan" });
            }

            if (string.IsNullOrWhiteSpace(request.InspectorNik))
            {
                request.InspectorNik = GetCallerNik();
            }

            if (string.IsNullOrWhiteSpace(request.InspectorName))
            {
                request.InspectorName = GetCallerName();
            }

            var result = await _spService.CreateFollowupAsync(request);
            if (result == null)
            {
                return BadRequest(new { status = 400, message = "Gagal menyimpan verifikasi follow-up special permit" });
            }

            return Ok(new
            {
                status = 200,
                message = "Verifikasi follow-up special permit berhasil disimpan ke database",
                data = result
            });
        }

        [HttpGet("alerts")]
        [AllowAnonymous]
        public async Task<IActionResult> GetAlerts([FromQuery] string? nik)
        {
            var activeNik = GetCallerNik(nik);
            if (string.IsNullOrWhiteSpace(activeNik))
            {
                return Ok(new { status = 200, count = 0, data = Array.Empty<object>() });
            }

            var alerts = await _spService.GetHighRiskAlertsAsync(activeNik);
            return Ok(new
            {
                status = 200,
                message = "Success",
                count = alerts.Count,
                data = alerts
            });
        }

        [HttpPost("reassign")]
        [AllowAnonymous]
        public async Task<IActionResult> ReassignInspector([FromBody] ReassignSpecialPermitDto req)
        {
            if (string.IsNullOrWhiteSpace(req.SpecialPermitId) || string.IsNullOrWhiteSpace(req.NewInspectorNik))
            {
                return BadRequest(new { status = 400, message = "Special Permit ID dan NIK Inspector Baru wajib diisi." });
            }

            var callerNik = GetCallerNik();
            var callerName = GetCallerName();

            var success = await _spService.ReassignInspectorAsync(
                req.SpecialPermitId,
                req.NewInspectorNik,
                req.NewInspectorName,
                callerNik,
                callerName,
                req.Reason
            );

            if (!success)
            {
                return NotFound(new { status = 404, message = "Special Permit tidak ditemukan atau gagal memperbarui inspector." });
            }

            return Ok(new
            {
                status = 200,
                message = $"Berhasil mengalihkan tugas inspeksi kepada {req.NewInspectorName} ({req.NewInspectorNik})."
            });
        }

        [HttpGet("inspectors")]
        [AllowAnonymous]
        public async Task<IActionResult> SearchInspectors([FromQuery] string? query)
        {
            var list = await _spService.SearchInspectorsAsync(query);
            return Ok(new
            {
                status = 200,
                count = list.Count,
                data = list
            });
        }
    }
}
