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
        private readonly CompanyHierarchyService _companyHierarchyService;

        public HazardApiController(AppDbContext context, ImageUploadService imageUploadService, CompanyHierarchyService companyHierarchyService)
        {
            _context = context;
            _imageUploadService = imageUploadService;
            _companyHierarchyService = companyHierarchyService;
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

            // 1. ACTION (Tugas PJA yang diarahkan ke saya dan belum selesai)
            var totalAction = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.NikPja == trimmedNik && h.StatusTemuan != "Closed");

            // 2. MONITORING (Temuan yang SAYA laporkan yang masih aktif / sedang berproses di PJA)
            var totalMonitoring = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == trimmedNik && h.StatusTemuan != "Closed");

            // 3. SUMMARY (Laporan yang SUDAH SELESAI / Closed)
            var totalSummary = await _context.HazardReports.CountAsync(h => !h.IsDeleted && (h.Nik == trimmedNik || h.NikPja == trimmedNik) && h.StatusTemuan == "Closed");

            var totalInput = await _context.HazardReports.CountAsync(h => !h.IsDeleted && h.Nik == trimmedNik);
            var totalSiteAll = await _context.HazardReports.CountAsync(h => !h.IsDeleted);

            IQueryable<HazardReport> query = baseQuery;

            // Filter alur kerja & status
            filter = (filter ?? "all").Trim().ToLowerInvariant();
            if (filter == "action" || filter == "assigned" || filter == "pja" || filter == "tugas_pja")
            {
                // Action: diarahkan ke saya sebagai PJA yang masih butuh tindakan
                query = _context.HazardReports.AsNoTracking().Where(h => !h.IsDeleted && h.NikPja == trimmedNik && h.StatusTemuan != "Closed");
            }
            else if (filter == "monitoring" || filter == "monitor" || filter == "in_flight" || filter == "berproses")
            {
                // Monitoring: laporan saya yang sedang berjalan / diarahkan ke PJA
                query = _context.HazardReports.AsNoTracking().Where(h => !h.IsDeleted && h.Nik == trimmedNik && h.StatusTemuan != "Closed");
            }
            else if (filter == "summary" || filter == "selesai" || filter == "closed")
            {
                // Summary: laporan selesai / Closed
                query = _context.HazardReports.AsNoTracking().Where(h => !h.IsDeleted && (h.Nik == trimmedNik || h.NikPja == trimmedNik) && h.StatusTemuan == "Closed");
            }
            else if (filter == "all_site" || filter == "all_company" || filter == "site")
            {
                // Pantau seluruh site (opsional)
                query = _context.HazardReports.AsNoTracking().Where(h => !h.IsDeleted);
            }
            else if (filter == "my_reports" || filter == "laporan_saya")
            {
                query = _context.HazardReports.AsNoTracking().Where(h => !h.IsDeleted && h.Nik == trimmedNik);
            }
            else if (filter == "open")
            {
                query = query.Where(h => h.StatusTemuan == "Open" || h.StatusTemuan == "In Progress");
            }
            else if (filter == "inprogress" || filter == "in_progress" || filter == "takeup")
            {
                query = query.Where(h => h.StatusTemuan == "In Progress");
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
                    can_take_up = (h.NikPja == trimmedNik || h.Nik == trimmedNik) && h.StatusTemuan == "Open",
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
                    total_action = totalAction,
                    total_monitoring = totalMonitoring,
                    total_summary = totalSummary,
                    total_input = totalInput,
                    total_open = totalMonitoring,
                    total_closed = totalSummary,
                    total_assigned = totalAction,
                    total_site = totalSiteAll,
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
                        RecipientNik = nikPja.Trim(),
                        Title = "Penugasan PJA Temuan Hazard",
                        Message = $"Anda ditunjuk sebagai PJA untuk temuan Hazard di {lokasi} oleh {userName}. Segera tindaklanjuti (Take Up) atau alihkan ke PJA lain jika salah sasaran.",
                        Url = "/Hazard/Index",
                        NotifType = "hazard_assigned",
                        IsRead = false,
                        IsActioned = false,
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
                            RecipientNik = hazard.NikPja.Trim(),
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

                    // Tandai notifikasi penugasan terkait temuan ini sebagai actioned (agar tidak muncul lagi sebagai tugas tertunda)
                    var relatedNotifs = await _context.Notifications
                        .Where(n => !n.IsActioned && (n.Message.Contains(hazard.Lokasi ?? "") || n.Message.Contains($"#{hazard.Id}")))
                        .ToListAsync();
                    foreach (var rn in relatedNotifs)
                    {
                        rn.IsActioned = true;
                    }

                    // Notifikasi ke pelapor jika ditutup oleh PJA
                    if (isPja && !string.IsNullOrWhiteSpace(hazard.Nik) && hazard.Nik != userNik)
                    {
                        _context.Notifications.Add(new Notification
                        {
                            RecipientNik = hazard.Nik.Trim(),
                            Title = "Temuan Hazard Telah Ditutup (Completed)",
                            Message = $"Temuan Hazard #{hazard.Id} di {hazard.Lokasi ?? hazard.Area} telah selesai ditindaklanjuti oleh {userName} (PJA).",
                            Url = "/Hazard/Index",
                            NotifType = "hazard_completed",
                            IsActioned = true,
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
                        RecipientNik = hazard.NikPja.Trim(),
                        Title = "Pengalihan Penugasan PJA Hazard",
                        Message = $"{userName} telah mengalihkan penugasan temuan hazard di {hazard.Lokasi ?? hazard.Area} kepada Anda. Alasan: {req.Keterangan}. Segera tindaklanjuti (Take Up) atau alihkan jika salah sasaran.",
                        Url = "/Hazard/Index",
                        NotifType = "hazard_assigned",
                        IsRead = false,
                        IsActioned = false,
                        CreatedAt = DateTime.Now
                    });
                }

                // Tandai notifikasi pengalihan PJA sebelumnya sebagai actioned
                var prevNotifs = await _context.Notifications
                    .Where(n => n.RecipientNik == userNik && !n.IsActioned && (n.NotifType == "hazard_assigned" || n.NotifType == "hazard_new" || n.NotifType == "hazard_reassigned"))
                    .ToListAsync();
                foreach (var pn in prevNotifs)
                {
                    pn.IsActioned = true;
                }

                // Notifikasi ke Pelapor bahwa PJA telah dialihkan
                if (!string.IsNullOrWhiteSpace(hazard.Nik) && hazard.Nik != userNik)
                {
                    _context.Notifications.Add(new Notification
                    {
                        RecipientNik = hazard.Nik.Trim(),
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

        public class TakeUpDto
        {
            public int Id { get; set; }
            public string? Note { get; set; }
        }

        /// <summary>
        /// POST /api/hazard/take-up
        /// PJA mengambil alih (Take Up) temuan hazard untuk ditindaklanjuti.
        /// Status temuan diperbarui menjadi 'In Progress'.
        /// </summary>
        [HttpPost("take-up")]
        public async Task<IActionResult> TakeUpHazard([FromBody] TakeUpDto req)
        {
            try
            {
                var userNik = GetCurrentNik();
                var userName = GetCurrentName();

                if (req == null || req.Id <= 0)
                {
                    return BadRequest(new { success = false, message = "ID Hazard tidak valid." });
                }

                var hazard = await _context.HazardReports.FirstOrDefaultAsync(h => h.Id == req.Id && !h.IsDeleted);
                if (hazard == null)
                {
                    return NotFound(new { success = false, message = "Data Hazard tidak ditemukan." });
                }

                if (string.Equals(hazard.StatusTemuan, "Closed", StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new { success = false, message = "Temuan Hazard sudah berstatus Closed." });
                }

                // Periksa otorisasi PJA atau pelapor atau Admin
                if (hazard.NikPja != userNik && hazard.Nik != userNik && !User.IsInRole("Admin"))
                {
                    return StatusCode(403, new { success = false, message = "Anda bukan PJA yang ditugaskan untuk temuan ini." });
                }

                hazard.StatusTemuan = "In Progress";
                if (!string.IsNullOrWhiteSpace(req.Note))
                {
                    hazard.TindakanPerbaikan = string.IsNullOrWhiteSpace(hazard.TindakanPerbaikan)
                        ? req.Note.Trim()
                        : $"{hazard.TindakanPerbaikan}\n[Take Up oleh {userName}]: {req.Note.Trim()}";
                }

                _context.HazardReports.Update(hazard);

                // Sinkron ke ActionPlan jika ada
                var actionPlanItemSap = $"hazard:{hazard.Id}";
                var actionPlan = await _context.ActionPlans.FirstOrDefaultAsync(a => a.ItemSap == actionPlanItemSap && !a.IsDeleted);
                if (actionPlan != null)
                {
                    actionPlan.Status = "In Progress";
                    if (!string.IsNullOrWhiteSpace(req.Note))
                    {
                        actionPlan.RencanaPerbaikan = req.Note.Trim();
                    }
                    _context.ActionPlans.Update(actionPlan);
                }

                // Kirim notifikasi ke pelapor bahwa temuan telah di-take up
                if (!string.IsNullOrWhiteSpace(hazard.Nik) && hazard.Nik != userNik)
                {
                    _context.Notifications.Add(new Notification
                    {
                        RecipientNik = hazard.Nik.Trim(),
                        Title = "Temuan Hazard Di-Take Up oleh PJA",
                        Message = $"Temuan Hazard Anda di {hazard.Lokasi ?? hazard.Area} telah di-take up oleh {userName} (PJA) dan sedang diproses.",
                        Url = "/Hazard/Index",
                        NotifType = "hazard_takeup",
                        IsRead = false,
                        IsActioned = false,
                        CreatedAt = DateTime.Now
                    });
                }

                // Tandai notifikasi penugasan PJA milik user ini sebagai telah di-action
                var userNotifs = await _context.Notifications
                    .Where(n => n.RecipientNik == userNik && !n.IsActioned && (n.NotifType == "hazard_assigned" || n.NotifType == "hazard_new" || n.NotifType == "hazard_reassigned"))
                    .ToListAsync();
                foreach (var notif in userNotifs)
                {
                    notif.IsActioned = true;
                }

                await _context.SaveChangesAsync();

                return Ok(new
                {
                    success = true,
                    message = $"Temuan Hazard #{hazard.Id} berhasil di-take up untuk ditindaklanjuti!",
                    data = new
                    {
                        id = hazard.Id,
                        status_temuan = hazard.StatusTemuan
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal take up Hazard: {ex.Message}" });
            }
        }

        /// <summary>
        /// GET /api/hazard/search-pja
        /// Cari karyawan untuk penunjukan atau pengalihan PJA dengan dukungan Mode Lintas Perusahaan.
        /// </summary>
        [HttpGet("search-pja")]
        public async Task<IActionResult> SearchPja([FromQuery] string? q, [FromQuery] bool lintasPerusahaan = true)
        {
            var query = (q ?? string.Empty).Trim().ToLower();
            if (string.IsNullOrWhiteSpace(query))
            {
                return Ok(new { success = true, data = new List<object>() });
            }

            var cid = GetCurrentCompanyId();
            var allowedCompanyIds = lintasPerusahaan ? null : await _companyHierarchyService.GetAccessibleCompanyIdsAsync(cid);

            var baseQuery = from k in _context.Karyawans.AsNoTracking()
                            join p in _context.Personals.AsNoTracking() on k.IdPersonal equals p.IdPersonal
                            join j in _context.Jabatans.AsNoTracking() on k.IdJabatan equals j.JabatanId into jg
                            from j in jg.DefaultIfEmpty()
                            join d in _context.Departemens.AsNoTracking() on k.IdDepartemen equals d.DepartemenId into dg
                            from d in dg.DefaultIfEmpty()
                            join c in _context.Perusahaans.AsNoTracking() on k.IdPerusahaan equals c.PerusahaanId into cg
                            from c in cg.DefaultIfEmpty()
                            where k.StatusAktif
                            select new
                            {
                                nik = k.NoNik,
                                nama = p.NamaLengkap,
                                jabatan = j != null ? j.NamaJabatan : "Staff",
                                departemen = d != null ? d.NamaDepartemen : "GENERAL",
                                perusahaan = c != null ? c.NamaPerusahaan : "PT INDEXIM COALINDO",
                                companyId = k.IdPerusahaan
                            };

            if (allowedCompanyIds != null && allowedCompanyIds.Count > 0)
            {
                baseQuery = baseQuery.Where(k => allowedCompanyIds.Contains(k.companyId));
            }

            baseQuery = baseQuery.Where(k =>
                k.nik.ToLower().Contains(query) ||
                k.nama.ToLower().Contains(query) ||
                k.departemen.ToLower().Contains(query) ||
                k.perusahaan.ToLower().Contains(query)
            );

            var results = await baseQuery
                .OrderBy(k => k.nama)
                .Take(40)
                .Select(k => new
                {
                    nik = k.nik,
                    nama = k.nama,
                    jabatan = k.jabatan,
                    departemen = k.departemen,
                    perusahaan = k.perusahaan,
                    company_id = k.companyId
                })
                .ToListAsync();

            return Ok(new { success = true, data = results });
        }

        /// <summary>
        /// GET /api/hazard/detail/{id}
        /// GET /api/hazard/{id}
        /// Mengambil detail lengkap satu temuan Hazard.
        /// </summary>
        [HttpGet("detail/{id}")]
        [HttpGet("{id}")]
        public async Task<IActionResult> GetHazardDetail(int id)
        {
            var h = await _context.HazardReports
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted);

            if (h == null)
            {
                return NotFound(new { success = false, message = "Data Hazard tidak ditemukan." });
            }

            return Ok(new
            {
                success = true,
                data = new
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
                    created_at = h.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss")
                }
            });
        }
    }
}
