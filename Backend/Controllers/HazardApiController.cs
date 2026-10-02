using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Models;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/hazard")]
    [Authorize]
    public class HazardApiController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ImageUploadService _imageUploadService;

        public HazardApiController(AppDbContext context, ImageUploadService imageUploadService)
        {
            _context = context;
            _imageUploadService = imageUploadService;
        }

        private string GetCurrentNik() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0000";
        private string GetCurrentName() => User.Identity?.Name ?? User.FindFirst(ClaimTypes.Name)?.Value ?? "Pengguna";
        private string GetCurrentDepartment() => User.FindFirst("Department")?.Value ?? "GENERAL";
        private int GetCurrentCompanyId() => int.TryParse(User.FindFirst("CompanyId")?.Value, out var cid) ? cid : 1;

        /// <summary>
        /// GET /api/hazard/hub
        /// Mengambil ringkasan statistik (scorecard temuan) dan daftar temuan user & penugasan PJA.
        /// </summary>
        [HttpGet("hub")]
        public async Task<IActionResult> GetHazardHub([FromQuery] string? filter, [FromQuery] string? search)
        {
            var userNik = GetCurrentNik();
            var trimmedNik = userNik.Trim();

            // Query dasar: temuan yang dibuat oleh user ATAU ditugaskan ke user sebagai PJA
            var baseQuery = _context.HazardReports
                .AsNoTracking()
                .Where(h => !h.IsDeleted && (h.Nik == trimmedNik || h.NikPja == trimmedNik));

            // Statistik dokumentasi & scoring
            var totalInput = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == trimmedNik);
            var totalOpen = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == trimmedNik && h.StatusTemuan == "Open");
            var totalClosed = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == trimmedNik && h.StatusTemuan == "Closed");
            var totalAssignedToMe = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.NikPja == trimmedNik && h.Nik != trimmedNik && h.StatusTemuan == "Open");

            var query = baseQuery;

            // Filter status/assigned
            filter = (filter ?? "all").Trim().ToLowerInvariant();
            if (filter == "open")
            {
                query = query.Where(h => h.StatusTemuan == "Open");
            }
            else if (filter == "closed")
            {
                query = query.Where(h => h.StatusTemuan == "Closed");
            }
            else if (filter == "assigned" || filter == "pja")
            {
                query = query.Where(h => h.NikPja == trimmedNik && h.Nik != trimmedNik);
            }

            // Filter search
            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim().ToLower();
                query = query.Where(h =>
                    (h.Temuan != null && h.Temuan.ToLower().Contains(s)) ||
                    (h.Lokasi != null && h.Lokasi.ToLower().Contains(s)) ||
                    (h.Area != null && h.Area.ToLower().Contains(s)) ||
                    (h.Nama != null && h.Nama.ToLower().Contains(s)) ||
                    (h.Pja != null && h.Pja.ToLower().Contains(s)));
            }

            var items = await query
                .OrderByDescending(h => h.CreatedAt)
                .ThenByDescending(h => h.Id)
                .Take(200)
                .Select(h => new
                {
                    id = h.Id,
                    tanggal = h.Tanggal.ToString("yyyy-MM-dd"),
                    waktu = $"{h.Waktu.Hours:D2}:{h.Waktu.Minutes:D2}",
                    nama = h.Nama,
                    nik = h.Nik,
                    departemen = h.Departemen,
                    area = h.Area,
                    lokasi = h.Lokasi,
                    detil_lokasi = h.DetilLokasi,
                    temuan = h.Temuan,
                    kategori_bahaya = h.KategoriBahaya,
                    jenis_bahaya = h.JenisBahaya,
                    jenis_ketidaksesuaian = h.JenisKetidaksesuaian,
                    tingkat_resiko = h.TingkatResiko ?? "Rendah",
                    perbaikan = h.Perbaikan,
                    tindakan_perbaikan = h.TindakanPerbaikan,
                    pja = h.Pja,
                    nik_pja = h.NikPja,
                    departemen_pja = h.DepartemenPja,
                    status_temuan = h.StatusTemuan,
                    foto_temuan = h.FotoTemuan,
                    foto_perbaikan = h.FotoPerbaikan,
                    created_at = h.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss"),
                    is_my_report = h.Nik == trimmedNik,
                    is_assigned_to_me = h.NikPja == trimmedNik && h.Nik != trimmedNik,
                    can_close = (h.Nik == trimmedNik || h.NikPja == trimmedNik) && h.StatusTemuan != "Closed",
                    can_reassign = (h.NikPja == trimmedNik || h.Nik == trimmedNik) && h.StatusTemuan != "Closed",
                    can_delete = h.Nik == trimmedNik && h.StatusTemuan != "Closed"
                })
                .ToListAsync();

            return Ok(new
            {
                success = true,
                summary = new
                {
                    total_input = totalInput,
                    total_open = totalOpen,
                    total_closed = totalClosed,
                    total_assigned = totalAssignedToMe,
                    score = totalInput * 10 // Poin skor keselamatan SAP
                },
                data = items
            });
        }

        /// <summary>
        /// POST /api/hazard/create
        /// Lapor temuan Hazard baru persis seperti alur web MBS_SAP.
        /// </summary>
        [HttpPost("create")]
        public async Task<IActionResult> CreateHazard([FromForm] IFormCollection form)
        {
            try
            {
                var userNik = GetCurrentNik();
                var userName = GetCurrentName();
                var userDept = GetCurrentDepartment();
                var companyId = GetCurrentCompanyId();

                var tanggal = DateTime.TryParse(form["tanggal"].FirstOrDefault(), out var tgl) ? tgl.Date : DateTime.Today;
                var waktuStr = form["waktu"].FirstOrDefault() ?? DateTime.Now.ToString("HH:mm");
                var waktu = TimeSpan.TryParse(waktuStr, out var ts) ? ts : DateTime.Now.TimeOfDay;

                var area = form["area"].FirstOrDefault()?.Trim() ?? "AREA OPERASIONAL";
                var lokasi = form["lokasi"].FirstOrDefault()?.Trim() ?? "LOKASI KERJA";
                var detilLokasi = form["detil_lokasi"].FirstOrDefault()?.Trim();
                var temuan = form["temuan"].FirstOrDefault()?.Trim() ?? "";
                var kategoriBahaya = form["kategori_bahaya"].FirstOrDefault()?.Trim() ?? "Kondisi Tidak Aman";
                var jenisBahaya = form["jenis_bahaya"].FirstOrDefault()?.Trim() ?? "Dan lain-lain";
                var jenisKetidaksesuaian = form["jenis_ketidaksesuaian"].FirstOrDefault()?.Trim();
                var tingkatResiko = form["tingkat_resiko"].FirstOrDefault()?.Trim() ?? "Sedang";
                var perbaikan = form["perbaikan"].FirstOrDefault()?.Trim();
                var tindakanPerbaikan = form["tindakan_perbaikan"].FirstOrDefault()?.Trim();
                var pja = form["pja"].FirstOrDefault()?.Trim();
                var nikPja = form["nik_pja"].FirstOrDefault()?.Trim();
                var deptPja = form["departemen_pja"].FirstOrDefault()?.Trim();
                var statusTemuan = form["status_temuan"].FirstOrDefault()?.Trim() ?? "Open";

                if (string.IsNullOrWhiteSpace(temuan))
                {
                    return BadRequest(new { success = false, message = "Uraian temuan hazard wajib diisi." });
                }

                // Duplicate guard backend 20 detik seperti Web MBS_SAP
                var duplicateWindowStart = DateTime.Now.AddSeconds(-20);
                var normalizedTemuan = temuan.Trim().ToLower();
                var normalizedArea = area.Trim().ToLower();
                var normalizedLokasi = lokasi.Trim().ToLower();

                var duplicate = await _context.HazardReports
                    .AsNoTracking()
                    .Where(h => !h.IsDeleted && h.Nik == userNik && h.CreatedAt >= duplicateWindowStart)
                    .FirstOrDefaultAsync(h => (h.Temuan ?? "").Trim().ToLower() == normalizedTemuan
                                           && (h.Area ?? "").Trim().ToLower() == normalizedArea
                                           && (h.Lokasi ?? "").Trim().ToLower() == normalizedLokasi);

                if (duplicate != null)
                {
                    return BadRequest(new
                    {
                        success = false,
                        message = "Data hazard yang sama terdeteksi terkirim dua kali dalam waktu singkat. Sistem hanya menyimpan satu data."
                    });
                }

                // Upload Foto Temuan
                string? fotoTemuanUrl = null;
                var photoFile = form.Files["foto_temuan"] ?? form.Files["image"] ?? form.Files["foto"];
                if (photoFile != null && photoFile.Length > 0)
                {
                    fotoTemuanUrl = await _imageUploadService.UploadAndCompressImageAsync(photoFile, "hazard", "hz");
                }

                // Upload Foto Perbaikan (jika langsung closed)
                string? fotoPerbaikanUrl = null;
                var repairFile = form.Files["foto_perbaikan"] ?? form.Files["repair_image"];
                if (repairFile != null && repairFile.Length > 0)
                {
                    fotoPerbaikanUrl = await _imageUploadService.UploadAndCompressImageAsync(repairFile, "actionplan", "ap");
                }

                var hazard = new HazardReport
                {
                    Tanggal = tanggal,
                    Waktu = waktu,
                    Nama = userName,
                    Nik = userNik,
                    Departemen = userDept,
                    Area = area,
                    Lokasi = lokasi,
                    DetilLokasi = detilLokasi,
                    Temuan = temuan,
                    KategoriBahaya = kategoriBahaya,
                    JenisBahaya = jenisBahaya,
                    JenisKetidaksesuaian = jenisKetidaksesuaian,
                    TingkatResiko = tingkatResiko,
                    Perbaikan = perbaikan,
                    TindakanPerbaikan = tindakanPerbaikan,
                    Pja = pja,
                    NikPja = nikPja,
                    DepartemenPja = deptPja,
                    StatusTemuan = statusTemuan,
                    FotoTemuan = fotoTemuanUrl,
                    FotoPerbaikan = fotoPerbaikanUrl,
                    PerusahaanId = companyId,
                    IsDeleted = false,
                    CreatedAt = DateTime.Now
                };

                _context.HazardReports.Add(hazard);
                await _context.SaveChangesAsync();

                // Sinkron ke ActionPlan jika ada PJA atau status Open
                if (!string.IsNullOrWhiteSpace(hazard.Pja))
                {
                    var actionPlan = new ActionPlan
                    {
                        Tanggal = tanggal,
                        Waktu = waktu,
                        Nama = userName,
                        Nik = userNik,
                        Departemen = userDept,
                        Area = area,
                        Lokasi = lokasi,
                        DetilLokasi = detilLokasi,
                        ItemSap = $"hazard:{hazard.Id}",
                        KategoriTemuan = kategoriBahaya,
                        DetilTemuan = temuan,
                        Status = statusTemuan,
                        Pja = pja,
                        NikPja = nikPja,
                        DepartemenPja = deptPja,
                        RencanaPerbaikan = tindakanPerbaikan,
                        Perbaikan = perbaikan,
                        FotoTemuan = fotoTemuanUrl,
                        FotoPerbaikan = fotoPerbaikanUrl,
                        PerusahaanId = companyId,
                        CreatedAt = DateTime.Now,
                        IsDeleted = false
                    };
                    _context.ActionPlans.Add(actionPlan);
                    await _context.SaveChangesAsync();
                }

                // Kirim notifikasi ke PJA yang ditunjuk
                if (!string.IsNullOrWhiteSpace(nikPja))
                {
                    _context.Notifications.Add(new Notification
                    {
                        RecipientNik = nikPja,
                        Title = "Temuan Hazard Baru",
                        Message = $"Anda ditunjuk sebagai PJA untuk temuan Hazard di {lokasi} oleh {userName}.",
                        Url = $"/ActionPlan/Index",
                        NotifType = "hazard_new",
                        CreatedAt = DateTime.Now
                    });
                    await _context.SaveChangesAsync();
                }

                return Ok(new
                {
                    success = true,
                    message = "Laporan Hazard berhasil dikirim!",
                    data = new
                    {
                        id = hazard.Id,
                        status_temuan = hazard.StatusTemuan,
                        foto_temuan = hazard.FotoTemuan
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal menyimpan Hazard: {ex.Message}" });
            }
        }

        /// <summary>
        /// POST /api/hazard/close
        /// Menutup temuan Hazard oleh PJA atau Pelapor.
        /// Mendukung 2 mode web MBS_SAP:
        /// - 'pja': Kirim ke PJA untuk ditindaklanjuti sebagai Action Plan (status temuan di-close di pelapor, PJA menerima notifikasi & action plan Open).
        /// - 'self': Selesaikan sendiri oleh pelapor / tindakan selesai langsung.
        /// - PJA direct close: Ditutup oleh PJA dengan bukti foto perbaikan & catatan perbaikan.
        /// </summary>
        [HttpPost("close")]
        public async Task<IActionResult> CloseHazard([FromForm] IFormCollection form)
        {
            try
            {
                var userNik = GetCurrentNik();
                var userName = GetCurrentName();
                var userDept = GetCurrentDepartment();

                if (!int.TryParse(form["id"].FirstOrDefault(), out var id) || id <= 0)
                {
                    return BadRequest(new { success = false, message = "ID Hazard tidak valid." });
                }

                var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == id && !h.IsDeleted);
                if (hazard == null)
                {
                    return NotFound(new { success = false, message = "Data Hazard tidak ditemukan." });
                }

                if (string.Equals(hazard.StatusTemuan, "Closed", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new { success = false, message = "Laporan hazard sudah berstatus Closed." });
                }

                // Validasi otorisasi: pelapor atau PJA atau Admin
                var isCreator = hazard.Nik == userNik;
                var isPja = hazard.NikPja == userNik;
                if (!isCreator && !isPja && !User.IsInRole("Admin"))
                {
                    return StatusCode(403, new { success = false, message = "Anda tidak memiliki wewenang untuk menutup temuan ini." });
                }

                var closeMode = (form["close_mode"].FirstOrDefault() ?? "").Trim().ToLowerInvariant();
                var tindakan = form["tindakan_perbaikan"].FirstOrDefault()?.Trim() 
                            ?? form["perbaikan"].FirstOrDefault()?.Trim() 
                            ?? form["close_note"].FirstOrDefault()?.Trim() 
                            ?? "Telah diselesaikan.";
                
                string? fotoPerbaikanUrl = null;
                var repairFile = form.Files["foto_perbaikan"] ?? form.Files["image"] ?? form.Files["foto"];
                if (repairFile != null && repairFile.Length > 0)
                {
                    fotoPerbaikanUrl = await _imageUploadService.UploadAndCompressImageAsync(repairFile, "actionplan", "ap");
                }

                var actionPlanItemSap = $"hazard:{hazard.Id}";
                var actionPlan = await _context.ActionPlans.FirstOrDefaultAsync(a => a.ItemSap == actionPlanItemSap && !a.IsDeleted);

                if (closeMode == "pja")
                {
                    // MODE WEB: Pelapor melempar/menutup di sisi hazard dan mengirim ke PJA sebagai Action Plan
                    if (string.IsNullOrWhiteSpace(hazard.Pja))
                    {
                        return BadRequest(new { success = false, message = "PJA belum ditentukan. Silakan alihkan / tentukan PJA terlebih dahulu." });
                    }

                    if (actionPlan == null)
                    {
                        actionPlan = new ActionPlan
                        {
                            Tanggal = DateTime.Today,
                            Waktu = DateTime.Now.TimeOfDay,
                            Nama = userName,
                            Nik = userNik,
                            Departemen = userDept,
                            Area = hazard.Area,
                            Lokasi = hazard.Lokasi,
                            DetilLokasi = hazard.DetilLokasi,
                            ItemSap = actionPlanItemSap,
                            KategoriTemuan = hazard.KategoriBahaya,
                            DetilTemuan = hazard.Temuan,
                            Status = "Open",
                            Pja = hazard.Pja,
                            NikPja = hazard.NikPja,
                            DepartemenPja = hazard.DepartemenPja,
                            RencanaPerbaikan = tindakan,
                            FotoTemuan = hazard.FotoTemuan,
                            PerusahaanId = hazard.PerusahaanId,
                            CreatedAt = DateTime.Now
                        };
                        _context.ActionPlans.Add(actionPlan);
                    }
                    else
                    {
                        actionPlan.Status = "Open";
                        actionPlan.RencanaPerbaikan = tindakan;
                        _context.ActionPlans.Update(actionPlan);
                    }

                    hazard.StatusTemuan = "Closed";
                    hazard.TindakanPerbaikan = tindakan;
                    _context.HazardReports.Update(hazard);

                    // Kirim notifikasi ke PJA
                    if (!string.IsNullOrWhiteSpace(hazard.NikPja))
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = hazard.NikPja,
                            Title = "Action Plan Hazard Baru",
                            Message = $"Anda menerima tindak lanjut hazard dari {hazard.Nama} di {hazard.Lokasi ?? hazard.Area}.",
                            Url = "/ActionPlan/Index",
                            NotifType = "hazard_action_plan",
                            CreatedAt = DateTime.Now
                        });
                    }

                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        success = true,
                        message = "Hazard berhasil di-close dan diteruskan ke PJA sebagai Action Plan.",
                        data = new
                        {
                            id = hazard.Id,
                            status_temuan = hazard.StatusTemuan
                        }
                    });
                }
                else
                {
                    // MODE WEB: Selesaikan sendiri oleh pelapor ATAU PJA menuntaskan perbaikan
                    hazard.StatusTemuan = "Closed";
                    hazard.Perbaikan = string.IsNullOrWhiteSpace(hazard.Perbaikan)
                        ? tindakan
                        : $"{hazard.Perbaikan}\n[Close oleh {userName}]: {tindakan}";

                    if (!string.IsNullOrEmpty(fotoPerbaikanUrl))
                    {
                        hazard.FotoPerbaikan = fotoPerbaikanUrl;
                    }

                    _context.HazardReports.Update(hazard);

                    if (actionPlan != null)
                    {
                        actionPlan.Status = "Closed";
                        actionPlan.Perbaikan = tindakan;
                        actionPlan.TanggalPerbaikan = DateTime.Today;
                        if (!string.IsNullOrEmpty(fotoPerbaikanUrl))
                        {
                            actionPlan.FotoPerbaikan = fotoPerbaikanUrl;
                        }
                        _context.ActionPlans.Update(actionPlan);
                    }

                    // Notifikasi ke pelapor jika ditutup oleh PJA
                    if (isPja && !string.IsNullOrWhiteSpace(hazard.Nik) && hazard.Nik != userNik)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = hazard.Nik,
                            Title = "Temuan Hazard Telah Ditutup",
                            Message = $"Temuan Hazard di {hazard.Lokasi ?? hazard.Area} telah selesai ditindaklanjuti oleh {userName} (PJA).",
                            Url = "/Hazard/Index",
                            NotifType = "hazard_closed",
                            CreatedAt = DateTime.Now
                        });
                    }

                    await _context.SaveChangesAsync();

                    return Ok(new
                    {
                        success = true,
                        message = "Temuan Hazard berhasil ditutup (Closed)!",
                        data = new
                        {
                            id = hazard.Id,
                            status_temuan = hazard.StatusTemuan,
                            foto_perbaikan = hazard.FotoPerbaikan,
                            perbaikan = hazard.Perbaikan
                        }
                    });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal menutup Hazard: {ex.Message}" });
            }
        }

        public class ReassignDto
        {
            public int Id { get; set; }
            public string? NewNik { get; set; }
            public string? NewNama { get; set; }
            public string? NewDepartemen { get; set; }
            public string? Keterangan { get; set; }
        }

        /// <summary>
        /// POST /api/hazard/reassign
        /// PJA mengarahkan ke orang lain jika memang salah sasaran PJA.
        /// </summary>
        [HttpPost("reassign")]
        public async Task<IActionResult> ReassignPja([FromBody] ReassignDto req)
        {
            try
            {
                var userNik = GetCurrentNik();
                var userName = GetCurrentName();

                if (req == null || req.Id <= 0 || string.IsNullOrWhiteSpace(req.NewNama))
                {
                    return BadRequest(new { success = false, message = "Data pengalihan PJA tidak lengkap." });
                }

                if (string.IsNullOrWhiteSpace(req.Keterangan))
                {
                    return BadRequest(new { success = false, message = "Alasan pengalihan PJA wajib diisi." });
                }

                var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == req.Id && !h.IsDeleted);
                if (hazard == null)
                {
                    return NotFound(new { success = false, message = "Data Hazard tidak ditemukan." });
                }

                if (string.Equals(hazard.StatusTemuan, "Closed", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new { success = false, message = "Temuan Hazard yang sudah Closed tidak dapat dialihkan." });
                }

                var oldPja = hazard.Pja;
                var oldNikPja = hazard.NikPja;

                hazard.Pja = req.NewNama.Trim().ToUpperInvariant();
                hazard.NikPja = req.NewNik?.Trim();
                hazard.DepartemenPja = req.NewDepartemen?.Trim().ToUpperInvariant();

                _context.HazardReports.Update(hazard);

                // Sinkron ke ActionPlan
                var actionPlanItemSap = $"hazard:{hazard.Id}";
                var actionPlan = await _context.ActionPlans.FirstOrDefaultAsync(a => a.ItemSap == actionPlanItemSap && !a.IsDeleted);
                if (actionPlan != null)
                {
                    actionPlan.ReassignedFrom = oldPja;
                    actionPlan.ReassignedTo = hazard.Pja;
                    actionPlan.ReassignedAt = DateTime.Now;
                    actionPlan.ReassignNote = req.Keterangan;
                    actionPlan.Pja = hazard.Pja;
                    actionPlan.NikPja = hazard.NikPja;
                    actionPlan.DepartemenPja = hazard.DepartemenPja;
                    _context.ActionPlans.Update(actionPlan);
                }

                // Kirim notifikasi ke PJA baru
                if (!string.IsNullOrWhiteSpace(hazard.NikPja))
                {
                    _context.Notifications.Add(new Notification
                    {
                        RecipientNik = hazard.NikPja,
                        Title = "Pengalihan Penugasan PJA Hazard",
                        Message = $"{userName} telah mengalihkan penugasan temuan hazard di {hazard.Lokasi ?? hazard.Area} kepada Anda. Alasan: {req.Keterangan}",
                        Url = $"/ActionPlan/Index",
                        NotifType = "hazard_reassigned",
                        CreatedAt = DateTime.Now
                    });
                }

                // Notifikasi ke Pelapor bahwa PJA telah dialihkan
                if (!string.IsNullOrWhiteSpace(hazard.Nik) && hazard.Nik != userNik)
                {
                    _context.Notifications.Add(new Notification
                    {
                        RecipientNik = hazard.Nik,
                        Title = "Info Pengalihan PJA Temuan Hazard",
                        Message = $"PJA untuk temuan Hazard Anda di {hazard.Lokasi ?? hazard.Area} telah dialihkan oleh {userName} kepada {hazard.Pja}.",
                        Url = $"/Hazard/Index",
                        NotifType = "hazard_info",
                        CreatedAt = DateTime.Now
                    });
                }

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    success = true,
                    message = $"PJA berhasil dialihkan kepada {hazard.Pja}!",
                    data = new
                    {
                        id = hazard.Id,
                        pja = hazard.Pja,
                        nik_pja = hazard.NikPja,
                        departemen_pja = hazard.DepartemenPja
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal mengalihkan PJA: {ex.Message}" });
            }
        }

        /// <summary>
        /// DELETE /api/hazard/{id}
        /// Hapus laporan hazard jika masih Open dan dibuat oleh user sendiri.
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteHazard(int id)
        {
            var userNik = GetCurrentNik();
            var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == id && !h.IsDeleted);

            if (hazard == null)
            {
                return NotFound(new { success = false, message = "Data Hazard tidak ditemukan." });
            }

            if (string.Equals(hazard.StatusTemuan, "Closed", StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new { success = false, message = "Laporan hazard yang sudah Closed tidak dapat dihapus." });
            }

            if (hazard.Nik != userNik && !User.IsInRole("Admin"))
            {
                return StatusCode(403, new { success = false, message = "Anda hanya dapat menghapus temuan yang Anda buat sendiri." });
            }

            hazard.IsDeleted = true;
            _context.HazardReports.Update(hazard);

            var actionPlanItemSap = $"hazard:{hazard.Id}";
            var actionPlan = await _context.ActionPlans.FirstOrDefaultAsync(a => a.ItemSap == actionPlanItemSap && !a.IsDeleted);
            if (actionPlan != null)
            {
                actionPlan.IsDeleted = true;
                _context.ActionPlans.Update(actionPlan);
            }

            await _context.SaveChangesAsync();

            return Ok(new { success = true, message = "Laporan hazard berhasil dihapus." });
        }

        /// <summary>
        /// GET /api/hazard/search-pja
        /// Cari karyawan untuk penunjukan atau pengalihan PJA.
        /// </summary>
        [HttpGet("search-pja")]
        public async Task<IActionResult> SearchPja([FromQuery] string? q)
        {
            var query = (q ?? string.Empty).Trim().ToLower();
            if (string.IsNullOrWhiteSpace(query))
            {
                return Ok(new { success = true, data = new List<object>() });
            }

            var results = await (from k in _context.Karyawans.AsNoTracking()
                                 join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                                 join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                                 from j in jg.DefaultIfEmpty()
                                 join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                                 from d in dg.DefaultIfEmpty()
                                 join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                                 from c in cg.DefaultIfEmpty()
                                 where k.StatusAktif && (
                                     k.NoNik.ToLower().Contains(query) ||
                                     p.NamaLengkap.ToLower().Contains(query) ||
                                     (d != null && d.NamaDepartemen.ToLower().Contains(query))
                                 )
                                 orderby p.NamaLengkap
                                 select new
                                 {
                                     nik = k.NoNik,
                                     nama = p.NamaLengkap,
                                     jabatan = j != null ? j.NamaJabatan : "Staff",
                                     departemen = d != null ? d.NamaDepartemen : "GENERAL",
                                     perusahaan = c != null ? c.NamaPerusahaan : "PT INDEXIM COALINDO"
                                 })
                                 .Take(30)
                                 .ToListAsync();

            return Ok(new { success = true, data = results });
        }
    }
}
