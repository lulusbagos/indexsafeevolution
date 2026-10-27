using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.DTOs;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/approval-center")]
    public class ApprovalCenterController : ControllerBase
    {
        private readonly BimaApprovalService _approvalService;

        public ApprovalCenterController(BimaApprovalService approvalService)
        {
            _approvalService = approvalService;
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

        [HttpGet("status")]
        [AllowAnonymous]
        public async Task<IActionResult> GetStatus([FromQuery] string? nik)
        {
            var activeNik = GetCallerNik(nik);
            if (string.IsNullOrWhiteSpace(activeNik))
            {
                return BadRequest(new { status = 400, message = "NIK / NRP wajib diisi" });
            }

            var status = await _approvalService.CheckUserStatusAsync(activeNik);
            return Ok(new
            {
                status = 200,
                message = status.IsRegistered ? "User terdaftar di Bima" : "User tidak terdaftar di Bima",
                data = status
            });
        }

        [HttpGet("pending")]
        [AllowAnonymous]
        public async Task<IActionResult> GetPending(
            [FromQuery] string? nik,
            [FromQuery] string? module = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            var activeNik = GetCallerNik(nik);
            if (string.IsNullOrWhiteSpace(activeNik))
            {
                return BadRequest(new { status = 400, message = "NIK / NRP wajib diisi" });
            }

            var items = await _approvalService.GetPendingApprovalsAsync(activeNik, module, page, pageSize);
            return Ok(new
            {
                status = 200,
                message = "Success",
                count = items.Count,
                page,
                pageSize,
                data = items
            });
        }

        [HttpGet("submissions")]
        [AllowAnonymous]
        public async Task<IActionResult> GetSubmissions(
            [FromQuery] string? nik,
            [FromQuery] string? module = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            var activeNik = GetCallerNik(nik);
            if (string.IsNullOrWhiteSpace(activeNik))
            {
                return BadRequest(new { status = 400, message = "NIK / NRP wajib diisi" });
            }

            var items = await _approvalService.GetMySubmissionsAsync(activeNik, module, page, pageSize);
            return Ok(new
            {
                status = 200,
                message = "Success",
                count = items.Count,
                page,
                pageSize,
                data = items
            });
        }

        [HttpGet("detail/{id:long}")]
        [AllowAnonymous]
        public async Task<IActionResult> GetDetail(long id, [FromQuery] string? nik)
        {
            var activeNik = GetCallerNik(nik);
            var detail = await _approvalService.GetApprovalDetailAsync(id, activeNik);
            if (detail == null)
            {
                return NotFound(new { status = 404, message = "Detail approval tidak ditemukan" });
            }

            return Ok(new
            {
                status = 200,
                message = "Success",
                data = detail
            });
        }

        [HttpPost("action")]
        [AllowAnonymous]
        public async Task<IActionResult> ProcessAction([FromBody] ApprovalActionRequestDto request)
        {
            if (request == null || request.ApprovalId <= 0)
            {
                return BadRequest(new { status = 400, message = "Data request approval tidak valid" });
            }

            if (string.IsNullOrWhiteSpace(request.UserNik))
            {
                request.UserNik = GetCallerNik();
            }

            if (string.IsNullOrWhiteSpace(request.UserName))
            {
                request.UserName = GetCallerName();
            }

            var result = await _approvalService.ProcessApprovalActionAsync(request);
            if (!result.Success)
            {
                return BadRequest(new { status = 400, message = result.Message, data = result });
            }

            return Ok(new { status = 200, message = result.Message, data = result });
        }

        [HttpPost("batch-action")]
        [AllowAnonymous]
        public async Task<IActionResult> ProcessBatchAction([FromBody] BatchApprovalActionRequestDto request)
        {
            if (request == null || request.ApprovalIds == null || !request.ApprovalIds.Any())
            {
                return BadRequest(new { status = 400, message = "Daftar ID approval tidak boleh kosong" });
            }

            if (string.IsNullOrWhiteSpace(request.UserNik))
            {
                request.UserNik = GetCallerNik();
            }

            if (string.IsNullOrWhiteSpace(request.UserName))
            {
                request.UserName = GetCallerName();
            }

            var result = await _approvalService.ProcessBatchApprovalActionAsync(request);
            if (!result.Success && result.TotalSuccess == 0)
            {
                return BadRequest(new { status = 400, message = result.Message, data = result });
            }

            return Ok(new { status = 200, message = result.Message, data = result });
        }
    }
}

