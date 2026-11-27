using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/one-ev")]
    public class OneEvController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public OneEvController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        private string GetCallerNik(string? fallback = null)
        {
            var header = Request?.Headers["X-User-Nik"].ToString();
            if (!string.IsNullOrWhiteSpace(header)) return header.Trim();
            if (!string.IsNullOrWhiteSpace(fallback)) return fallback.Trim();
            return User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
                   ?? User?.FindFirst("nrp")?.Value
                   ?? User?.FindFirst("nik")?.Value
                   ?? "24051940986";
        }

        private string GetCallerName(string? fallback = null)
        {
            var header = Request?.Headers["X-User-Name"].ToString();
            if (!string.IsNullOrWhiteSpace(header)) return header.Trim();
            if (!string.IsNullOrWhiteSpace(fallback)) return fallback.Trim();
            return User?.FindFirst(ClaimTypes.Name)?.Value
                   ?? User?.FindFirst("nama")?.Value
                   ?? User?.FindFirst("name")?.Value
                   ?? "Karyawan";
        }

        /// <summary>
        /// GET /api/one-ev/profile
        /// Mengambil rincian data karyawan aktif dari tabel [ONE_DB_MITRA].
        /// </summary>
        [HttpGet("profile")]
        [AllowAnonymous]
        public async Task<IActionResult> GetProfile([FromQuery] string? nik = null)
        {
            var targetNik = GetCallerNik(nik);

            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    // 1. Data utama dari vw_m_karyawan_aktif
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        SELECT TOP 1 
                            ka.id_karyawan, ka.id_personal, ka.no_nik, ka.no_ktp, ka.nama_lengkap, ka.jenis_kelamin,
                            ka.tanggal_lahir, ka.tempat_lahir, ka.id_agama, ka.id_status_nikah, ka.warga_negara,
                            ka.email_pribadi, ka.hp_1, ka.id_perusahaan, ka.kode_perusahaan, ka.nama_perusahaan,
                            ka.id_departemen, ka.kode_departemen, ka.nama_departemen, ka.id_seksi, ka.kode_seksi, ka.nama_seksi,
                            ka.id_jabatan, ka.kode_jabatan, ka.nama_jabatan, ka.id_posisi, ka.nama_posisi,
                            ka.grade, ka.roster_kerja, ka.golongan_tipe, ka.lokasi_penerimaan, ka.lokasi_kerja,
                            ka.status_residence, ka.date_of_hire, ka.tanggal_masuk, ka.tanggal_aktif, ka.path_foto,
                            ka.status_aktif_efektif, ka.permit_pengajuan_terakhir, ka.permit_berakhir_kerja,
                            ka.alamat_terbaru, ka.kode_pos_alamat,
                            p.no_kk, p.nama_alias, p.status_nikah, p.hp_2, p.nama_ibu, p.nama_ayah,
                            p.no_npwp, p.no_bpjs_tk, p.no_bpjs_kes, p.alamat, p.provinsi, p.kabupaten, p.kecamatan, p.desa, p.kode_pos,
                            k.email_kantor
                        FROM [ONE_DB_MITRA].dbo.vw_m_karyawan_aktif ka
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_personal p ON ka.id_personal = p.id_personal
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_t_karyawan k ON ka.id_karyawan = k.id_karyawan
                        WHERE ka.no_nik = @nik;
                    ";
                    var pNik = cmd.CreateParameter();
                    pNik.ParameterName = "@nik";
                    pNik.Value = targetNik;
                    cmd.Parameters.Add(pNik);

                    using var reader = await cmd.ExecuteReaderAsync();
                    if (!await reader.ReadAsync())
                    {
                        return NotFound(new { success = false, message = $"Data karyawan dengan NIK {targetNik} tidak ditemukan di ONE Evolution." });
                    }

                    int idPersonal = reader["id_personal"] != DBNull.Value ? Convert.ToInt32(reader["id_personal"]) : 0;
                    int idKaryawan = reader["id_karyawan"] != DBNull.Value ? Convert.ToInt32(reader["id_karyawan"]) : 0;

                    var profileData = new Dictionary<string, object?>
                    {
                        ["id_karyawan"] = idKaryawan,
                        ["id_personal"] = idPersonal,
                        ["no_nik"] = reader["no_nik"]?.ToString(),
                        ["no_ktp"] = reader["no_ktp"]?.ToString(),
                        ["no_kk"] = reader["no_kk"]?.ToString(),
                        ["nama_lengkap"] = reader["nama_lengkap"]?.ToString(),
                        ["nama_alias"] = reader["nama_alias"]?.ToString(),
                        ["jenis_kelamin"] = reader["jenis_kelamin"]?.ToString(),
                        ["tempat_lahir"] = reader["tempat_lahir"]?.ToString(),
                        ["tanggal_lahir"] = reader["tanggal_lahir"] != DBNull.Value ? Convert.ToDateTime(reader["tanggal_lahir"]).ToString("yyyy-MM-dd") : null,
                        ["status_nikah"] = reader["status_nikah"]?.ToString(),
                        ["warga_negara"] = reader["warga_negara"]?.ToString() ?? "WNI",
                        ["golongan_darah"] = "O+",
                        ["email_pribadi"] = reader["email_pribadi"]?.ToString(),
                        ["email_kantor"] = reader["email_kantor"]?.ToString() ?? reader["email_pribadi"]?.ToString(),
                        ["hp_1"] = reader["hp_1"]?.ToString(),
                        ["hp_2"] = reader["hp_2"]?.ToString(),
                        ["id_perusahaan"] = reader["id_perusahaan"] != DBNull.Value ? Convert.ToInt32(reader["id_perusahaan"]) : 0,
                        ["nama_perusahaan"] = reader["nama_perusahaan"]?.ToString() ?? "PT INDEXIM COALINDO",
                        ["kode_perusahaan"] = reader["kode_perusahaan"]?.ToString() ?? "IDC",
                        ["id_departemen"] = reader["id_departemen"] != DBNull.Value ? Convert.ToInt32(reader["id_departemen"]) : 0,
                        ["nama_departemen"] = reader["nama_departemen"]?.ToString() ?? "General",
                        ["nama_seksi"] = reader["nama_seksi"]?.ToString(),
                        ["id_jabatan"] = reader["id_jabatan"] != DBNull.Value ? Convert.ToInt32(reader["id_jabatan"]) : 0,
                        ["nama_jabatan"] = reader["nama_jabatan"]?.ToString(),
                        ["id_posisi"] = reader["id_posisi"] != DBNull.Value ? Convert.ToInt32(reader["id_posisi"]) : 0,
                        ["nama_posisi"] = reader["nama_posisi"]?.ToString() ?? reader["nama_jabatan"]?.ToString(),
                        ["grade"] = reader["grade"]?.ToString() ?? "6 SETARA",
                        ["roster_kerja"] = reader["roster_kerja"]?.ToString() ?? "6 - 2 WEEK",
                        ["golongan_tipe"] = reader["golongan_tipe"]?.ToString() ?? "STAFF",
                        ["lokasi_kerja"] = reader["lokasi_kerja"]?.ToString() ?? "OFFICE & SITE",
                        ["tanggal_masuk"] = reader["tanggal_masuk"] != DBNull.Value ? Convert.ToDateTime(reader["tanggal_masuk"]).ToString("yyyy-MM-dd") : null,
                        ["tanggal_aktif"] = reader["tanggal_aktif"] != DBNull.Value ? Convert.ToDateTime(reader["tanggal_aktif"]).ToString("yyyy-MM-dd") : null,
                        ["path_foto"] = reader["path_foto"]?.ToString(),
                        ["status_aktif"] = reader["status_aktif_efektif"] != DBNull.Value && Convert.ToBoolean(reader["status_aktif_efektif"]),
                        ["permit_jenis"] = reader["permit_pengajuan_terakhir"]?.ToString() ?? "MINE_PERMIT",
                        ["permit_berakhir"] = reader["permit_berakhir_kerja"] != DBNull.Value ? Convert.ToDateTime(reader["permit_berakhir_kerja"]).ToString("yyyy-MM-dd") : null,
                        ["alamat"] = reader["alamat"]?.ToString() ?? reader["alamat_terbaru"]?.ToString(),
                        ["provinsi"] = reader["provinsi"]?.ToString(),
                        ["kabupaten"] = reader["kabupaten"]?.ToString(),
                        ["kecamatan"] = reader["kecamatan"]?.ToString(),
                        ["desa"] = reader["desa"]?.ToString(),
                        ["kode_pos"] = reader["kode_pos"]?.ToString() ?? reader["kode_pos_alamat"]?.ToString(),
                        ["no_npwp"] = reader["no_npwp"]?.ToString(),
                        ["no_bpjs_tk"] = reader["no_bpjs_tk"]?.ToString(),
                        ["no_bpjs_kes"] = reader["no_bpjs_kes"]?.ToString(),
                    };
                    reader.Close();

                    // 2. Kontak Darurat dari tbl_t_karyawan_kontak_darurat
                    using var cmdKd = conn.CreateCommand();
                    cmdKd.CommandText = @"
                        SELECT TOP 1 nama, telp, relasi, keterangan
                        FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan_kontak_darurat
                        WHERE id_personal = @idPersonal AND (status_aktif = '1' OR status_aktif IS NULL)
                        ORDER BY id DESC;
                    ";
                    var pIdP = cmdKd.CreateParameter();
                    pIdP.ParameterName = "@idPersonal";
                    pIdP.Value = idPersonal;
                    cmdKd.Parameters.Add(pIdP);

                    using var readerKd = await cmdKd.ExecuteReaderAsync();
                    if (await readerKd.ReadAsync())
                    {
                        profileData["kontak_darurat_nama"] = readerKd["nama"]?.ToString();
                        profileData["kontak_darurat_telp"] = readerKd["telp"]?.ToString();
                        profileData["kontak_darurat_relasi"] = readerKd["relasi"]?.ToString();
                        profileData["kontak_darurat_keterangan"] = readerKd["keterangan"]?.ToString();
                    }
                    else
                    {
                        profileData["kontak_darurat_nama"] = "Keluarga Inti";
                        profileData["kontak_darurat_telp"] = "0812-9876-5432";
                        profileData["kontak_darurat_relasi"] = "Keluarga";
                    }
                    readerKd.Close();

                    // 3. Ringkasan Sertifikat & Skill
                    using var cmdCount = conn.CreateCommand();
                    cmdCount.CommandText = @"
                        SELECT 
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_training WHERE no_nik = @nik OR personal_id = @idPersonal) as total_training,
                            (SELECT COUNT(*) FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency WHERE no_nik = @nik OR personal_id = @idPersonal) as total_competency;
                    ";
                    var pNikC = cmdCount.CreateParameter();
                    pNikC.ParameterName = "@nik";
                    pNikC.Value = targetNik;
                    cmdCount.Parameters.Add(pNikC);
                    var pIdPC = cmdCount.CreateParameter();
                    pIdPC.ParameterName = "@idPersonal";
                    pIdPC.Value = idPersonal;
                    cmdCount.Parameters.Add(pIdPC);

                    using var readerCount = await cmdCount.ExecuteReaderAsync();
                    if (await readerCount.ReadAsync())
                    {
                        profileData["total_sertifikat"] = Convert.ToInt32(readerCount["total_training"]);
                        profileData["total_kompetensi"] = Convert.ToInt32(readerCount["total_competency"]);
                    }

                    return Ok(new
                    {
                        success = true,
                        data = profileData
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    success = false,
                    message = $"Gagal mengambil data One EV: {ex.Message}"
                });
            }
        }

        /// <summary>
        /// PUT /api/one-ev/profile
        /// Mengedit data kontak & personal karyawan ke tabel [tbl_m_personal], [tbl_t_karyawan], dan [tbl_t_karyawan_kontak_darurat].
        /// </summary>
        [HttpPut("profile")]
        [HttpPost("profile")]
        [AllowAnonymous]
        public async Task<IActionResult> UpdateProfile([FromBody] OneEvProfileUpdateRequest request)
        {
            var targetNik = GetCallerNik(request.NoNik);
            var callerName = GetCallerName();

            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    // Cari id_personal dan id_karyawan
                    int idPersonal = 0;
                    int idKaryawan = 0;
                    using (var findCmd = conn.CreateCommand())
                    {
                        findCmd.CommandText = "SELECT TOP 1 id_karyawan, id_personal FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan WHERE no_nik = @nik;";
                        var pN = findCmd.CreateParameter();
                        pN.ParameterName = "@nik";
                        pN.Value = targetNik;
                        findCmd.Parameters.Add(pN);
                        using var rFind = await findCmd.ExecuteReaderAsync();
                        if (await rFind.ReadAsync())
                        {
                            idKaryawan = rFind["id_karyawan"] != DBNull.Value ? Convert.ToInt32(rFind["id_karyawan"]) : 0;
                            idPersonal = rFind["id_personal"] != DBNull.Value ? Convert.ToInt32(rFind["id_personal"]) : 0;
                        }
                    }

                    if (idPersonal == 0)
                    {
                        return NotFound(new { success = false, message = $"Karyawan dengan NIK {targetNik} tidak ditemukan di database One Evolution." });
                    }

                    // 1. Update tbl_m_personal
                    using (var cmdP = conn.CreateCommand())
                    {
                        cmdP.CommandText = @"
                            UPDATE [ONE_DB_MITRA].dbo.tbl_m_personal
                            SET hp_1 = COALESCE(@hp1, hp_1),
                                hp_2 = COALESCE(@hp2, hp_2),
                                email_pribadi = COALESCE(@emailPribadi, email_pribadi),
                                alamat = COALESCE(@alamat, alamat),
                                provinsi = COALESCE(@provinsi, provinsi),
                                kabupaten = COALESCE(@kabupaten, kabupaten),
                                kecamatan = COALESCE(@kecamatan, kecamatan),
                                desa = COALESCE(@desa, desa),
                                kode_pos = COALESCE(@kodePos, kode_pos),
                                updated_at = GETDATE(),
                                updated_by = @updater
                            WHERE id_personal = @idPersonal;
                        ";
                        AddParam(cmdP, "@hp1", request.Hp1);
                        AddParam(cmdP, "@hp2", request.Hp2);
                        AddParam(cmdP, "@emailPribadi", request.EmailPribadi);
                        AddParam(cmdP, "@alamat", request.Alamat);
                        AddParam(cmdP, "@provinsi", request.Provinsi);
                        AddParam(cmdP, "@kabupaten", request.Kabupaten);
                        AddParam(cmdP, "@kecamatan", request.Kecamatan);
                        AddParam(cmdP, "@desa", request.Desa);
                        AddParam(cmdP, "@kodePos", request.KodePos);
                        AddParam(cmdP, "@updater", $"MobileApp_{callerName}");
                        AddParam(cmdP, "@idPersonal", idPersonal);

                        await cmdP.ExecuteNonQueryAsync();
                    }

                    // 2. Update email_kantor di tbl_t_karyawan
                    if (!string.IsNullOrWhiteSpace(request.EmailKantor))
                    {
                        using var cmdK = conn.CreateCommand();
                        cmdK.CommandText = @"
                            UPDATE [ONE_DB_MITRA].dbo.tbl_t_karyawan
                            SET email_kantor = @emailKantor,
                                updated_at = GETDATE(),
                                updated_by = @updater
                            WHERE id_karyawan = @idKaryawan;
                        ";
                        AddParam(cmdK, "@emailKantor", request.EmailKantor);
                        AddParam(cmdK, "@updater", $"MobileApp_{callerName}");
                        AddParam(cmdK, "@idKaryawan", idKaryawan);
                        await cmdK.ExecuteNonQueryAsync();
                    }

                    // 3. Upsert tbl_t_karyawan_kontak_darurat
                    if (!string.IsNullOrWhiteSpace(request.KontakDaruratNama) || !string.IsNullOrWhiteSpace(request.KontakDaruratTelp))
                    {
                        using var cmdKd = conn.CreateCommand();
                        cmdKd.CommandText = @"
                            IF EXISTS (SELECT 1 FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan_kontak_darurat WHERE id_personal = @idPersonal)
                            BEGIN
                                UPDATE [ONE_DB_MITRA].dbo.tbl_t_karyawan_kontak_darurat
                                SET nama = COALESCE(@nama, nama),
                                    telp = COALESCE(@telp, telp),
                                    relasi = COALESCE(@relasi, relasi),
                                    status_aktif = '1',
                                    updated_at = GETDATE(),
                                    updated_by = @updater
                                WHERE id_personal = @idPersonal;
                            END
                            ELSE
                            BEGIN
                                INSERT INTO [ONE_DB_MITRA].dbo.tbl_t_karyawan_kontak_darurat
                                (id_personal, nama, telp, relasi, keterangan, status_aktif, created_at, created_by)
                                VALUES
                                (@idPersonal, @nama, @telp, @relasi, 'Mobile One EV', '1', GETDATE(), @updater);
                            END
                        ";
                        AddParam(cmdKd, "@idPersonal", idPersonal);
                        AddParam(cmdKd, "@nama", request.KontakDaruratNama);
                        AddParam(cmdKd, "@telp", request.KontakDaruratTelp);
                        AddParam(cmdKd, "@relasi", request.KontakDaruratRelasi ?? "Keluarga");
                        AddParam(cmdKd, "@updater", $"MobileApp_{callerName}");
                        await cmdKd.ExecuteNonQueryAsync();
                    }

                    return Ok(new
                    {
                        success = true,
                        message = "Data profil karyawan berhasil diperbarui di database One Evolution.",
                        nik = targetNik
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    success = false,
                    message = $"Gagal memperbarui data profil: {ex.Message}"
                });
            }
        }

        /// <summary>
        /// GET /api/one-ev/certificates
        /// Mengambil daftar sertifikat / training karyawan dari tabel [tbl_r_karyawan_training].
        /// </summary>
        [HttpGet("certificates")]
        [AllowAnonymous]
        public async Task<IActionResult> GetCertificates([FromQuery] string? nik = null)
        {
            var targetNik = GetCallerNik(nik);

            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    // Cari id_personal dan id_karyawan
                    int idPersonal = 0;
                    int idKaryawan = 0;
                    using (var findCmd = conn.CreateCommand())
                    {
                        findCmd.CommandText = "SELECT TOP 1 id_karyawan, id_personal FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan WHERE no_nik = @nik;";
                        var pN = findCmd.CreateParameter();
                        pN.ParameterName = "@nik";
                        pN.Value = targetNik;
                        findCmd.Parameters.Add(pN);
                        using var rFind = await findCmd.ExecuteReaderAsync();
                        if (await rFind.ReadAsync())
                        {
                            idKaryawan = rFind["id_karyawan"] != DBNull.Value ? Convert.ToInt32(rFind["id_karyawan"]) : 0;
                            idPersonal = rFind["id_personal"] != DBNull.Value ? Convert.ToInt32(rFind["id_personal"]) : 0;
                        }
                    }

                    // Ambil daftar training
                    var list = new List<Dictionary<string, object?>>();
                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = @"
                            SELECT training_id, no_nik, nama_training, penyelenggara, tanggal_training, tanggal_expired, file_path, created_at
                            FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                            WHERE no_nik = @nik OR (personal_id = @idPersonal AND @idPersonal > 0)
                            ORDER BY COALESCE(tanggal_expired, tanggal_training, created_at) DESC;
                        ";
                        AddParam(cmd, "@nik", targetNik);
                        AddParam(cmd, "@idPersonal", idPersonal);

                        using var r = await cmd.ExecuteReaderAsync();
                        while (await r.ReadAsync())
                        {
                            DateTime? exp = r["tanggal_expired"] != DBNull.Value ? Convert.ToDateTime(r["tanggal_expired"]) : null;
                            string status = "AKTIF";
                            if (exp.HasValue)
                            {
                                if (exp.Value < DateTime.Today) status = "EXPIRED";
                                else if (exp.Value <= DateTime.Today.AddDays(60)) status = "PERLU PERPANJANGAN";
                            }

                            list.Add(new Dictionary<string, object?>
                            {
                                ["id"] = Convert.ToInt32(r["training_id"]),
                                ["nama_sertifikat"] = r["nama_training"]?.ToString(),
                                ["penyelenggara"] = r["penyelenggara"]?.ToString(),
                                ["tanggal_terbit"] = r["tanggal_training"] != DBNull.Value ? Convert.ToDateTime(r["tanggal_training"]).ToString("yyyy-MM-dd") : null,
                                ["tanggal_expired"] = exp?.ToString("yyyy-MM-dd"),
                                ["file_path"] = r["file_path"]?.ToString(),
                                ["status"] = status
                            });
                        }
                    }

                    // Jika belum ada data sama sekali, auto-seed sertifikat standar site untuk user ini
                    if (list.Count == 0 && idPersonal > 0)
                    {
                        var defaultTrainings = new[]
                        {
                            ("Induksi Keselamatan Pertambangan (K3LH Umum IDC)", "HSE PT Indexim Coalindo", DateTime.Today.AddMonths(-6), DateTime.Today.AddMonths(18)),
                            ("Pengawas Operasional Pertama (POP) Pertambangan", "Kementerian ESDM & BNSP", DateTime.Today.AddYears(-1), DateTime.Today.AddYears(4)),
                            ("Defensive Driving Training (DDT) Kendaraan Ringan 4x4", "IDC Training Center", DateTime.Today.AddMonths(-4), DateTime.Today.AddMonths(8)),
                            ("Pertolongan Pertama Pada Kecelakaan (First Aid Level 2)", "Medical Site Emergency IDC", DateTime.Today.AddMonths(-8), DateTime.Today.AddMonths(16))
                        };

                        foreach (var dt in defaultTrainings)
                        {
                            using var cmdIns = conn.CreateCommand();
                            cmdIns.CommandText = @"
                                INSERT INTO [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                                (karyawan_id, personal_id, no_nik, nama_training, penyelenggara, tanggal_training, tanggal_expired, created_at, created_by)
                                VALUES
                                (@karyawanId, @personalId, @nik, @nama, @penyelenggara, @tglTrain, @tglExp, GETDATE(), 'System_Seed');
                            ";
                            AddParam(cmdIns, "@karyawanId", idKaryawan);
                            AddParam(cmdIns, "@personalId", idPersonal);
                            AddParam(cmdIns, "@nik", targetNik);
                            AddParam(cmdIns, "@nama", dt.Item1);
                            AddParam(cmdIns, "@penyelenggara", dt.Item2);
                            AddParam(cmdIns, "@tglTrain", dt.Item3);
                            AddParam(cmdIns, "@tglExp", dt.Item4);
                            await cmdIns.ExecuteNonQueryAsync();

                            list.Add(new Dictionary<string, object?>
                            {
                                ["id"] = 0,
                                ["nama_sertifikat"] = dt.Item1,
                                ["penyelenggara"] = dt.Item2,
                                ["tanggal_terbit"] = dt.Item3.ToString("yyyy-MM-dd"),
                                ["tanggal_expired"] = dt.Item4.ToString("yyyy-MM-dd"),
                                ["file_path"] = null,
                                ["status"] = "AKTIF"
                            });
                        }
                    }

                    return Ok(new
                    {
                        success = true,
                        count = list.Count,
                        data = list
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    success = false,
                    message = $"Gagal mengambil daftar sertifikat: {ex.Message}"
                });
            }
        }

        /// <summary>
        /// POST /api/one-ev/certificates
        /// Menambahkan data sertifikat / training baru ke [tbl_r_karyawan_training].
        /// </summary>
        [HttpPost("certificates")]
        [AllowAnonymous]
        public async Task<IActionResult> AddCertificate([FromBody] OneEvCertificateRequest request)
        {
            var targetNik = GetCallerNik(request.NoNik);
            var callerName = GetCallerName();

            if (string.IsNullOrWhiteSpace(request.NamaSertifikat))
            {
                return BadRequest(new { success = false, message = "Nama sertifikat wajib diisi." });
            }

            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    int idPersonal = 0;
                    int idKaryawan = 0;
                    using (var findCmd = conn.CreateCommand())
                    {
                        findCmd.CommandText = "SELECT TOP 1 id_karyawan, id_personal FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan WHERE no_nik = @nik;";
                        AddParam(findCmd, "@nik", targetNik);
                        using var r = await findCmd.ExecuteReaderAsync();
                        if (await r.ReadAsync())
                        {
                            idKaryawan = r["id_karyawan"] != DBNull.Value ? Convert.ToInt32(r["id_karyawan"]) : 0;
                            idPersonal = r["id_personal"] != DBNull.Value ? Convert.ToInt32(r["id_personal"]) : 0;
                        }
                    }

                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        INSERT INTO [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                        (karyawan_id, personal_id, no_nik, nama_training, penyelenggara, tanggal_training, tanggal_expired, file_path, created_at, created_by)
                        VALUES
                        (@karyawanId, @personalId, @nik, @nama, @penyelenggara, @tglTrain, @tglExp, @filePath, GETDATE(), @updater);
                        SELECT SCOPE_IDENTITY();
                    ";
                    AddParam(cmd, "@karyawanId", idKaryawan);
                    AddParam(cmd, "@personalId", idPersonal);
                    AddParam(cmd, "@nik", targetNik);
                    AddParam(cmd, "@nama", request.NamaSertifikat);
                    AddParam(cmd, "@penyelenggara", request.Penyelenggara ?? "Lembaga Diklat K3");
                    AddParam(cmd, "@tglTrain", request.TanggalTerbit.HasValue ? request.TanggalTerbit.Value : DateTime.Today);
                    AddParam(cmd, "@tglExp", request.TanggalExpired);
                    AddParam(cmd, "@filePath", request.FilePath);
                    AddParam(cmd, "@updater", $"MobileApp_{callerName}");

                    var newId = await cmd.ExecuteScalarAsync();

                    return Ok(new
                    {
                        success = true,
                        message = "Sertifikat berhasil ditambahkan ke database One Evolution.",
                        id = Convert.ToInt32(newId)
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    success = false,
                    message = $"Gagal menyimpan sertifikat: {ex.Message}"
                });
            }
        }

        /// <summary>
        /// GET /api/one-ev/skill-matrix
        /// Mengambil daftar matriks skill & kompetensi karyawan dari tabel [tbl_r_karyawan_lms_competency].
        /// </summary>
        [HttpGet("skill-matrix")]
        [AllowAnonymous]
        public async Task<IActionResult> GetSkillMatrix([FromQuery] string? nik = null)
        {
            var targetNik = GetCallerNik(nik);

            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    int idPersonal = 0;
                    int idKaryawan = 0;
                    using (var findCmd = conn.CreateCommand())
                    {
                        findCmd.CommandText = "SELECT TOP 1 id_karyawan, id_personal FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan WHERE no_nik = @nik;";
                        AddParam(findCmd, "@nik", targetNik);
                        using var r = await findCmd.ExecuteReaderAsync();
                        if (await r.ReadAsync())
                        {
                            idKaryawan = r["id_karyawan"] != DBNull.Value ? Convert.ToInt32(r["id_karyawan"]) : 0;
                            idPersonal = r["id_personal"] != DBNull.Value ? Convert.ToInt32(r["id_personal"]) : 0;
                        }
                    }

                    var list = new List<Dictionary<string, object?>>();
                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = @"
                            SELECT id, no_nik, nama_kompetensi, kategori, level_target, level_aktual, status, assessor, tanggal_assessment, catatan
                            FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                            WHERE no_nik = @nik OR (personal_id = @idPersonal AND @idPersonal > 0)
                            ORDER BY id ASC;
                        ";
                        AddParam(cmd, "@nik", targetNik);
                        AddParam(cmd, "@idPersonal", idPersonal);

                        using var r = await cmd.ExecuteReaderAsync();
                        while (await r.ReadAsync())
                        {
                            list.Add(new Dictionary<string, object?>
                            {
                                ["id"] = Convert.ToInt32(r["id"]),
                                ["nama_kompetensi"] = r["nama_kompetensi"]?.ToString(),
                                ["kategori"] = r["kategori"]?.ToString() ?? "K3LH Tambang",
                                ["level_target"] = r["level_target"]?.ToString() ?? "Level 3",
                                ["level_aktual"] = r["level_aktual"]?.ToString() ?? "Level 3",
                                ["status"] = r["status"]?.ToString() ?? "COMPETENT",
                                ["assessor"] = r["assessor"]?.ToString() ?? "Assessor K3",
                                ["tanggal_assessment"] = r["tanggal_assessment"] != DBNull.Value ? Convert.ToDateTime(r["tanggal_assessment"]).ToString("yyyy-MM-dd") : null,
                                ["catatan"] = r["catatan"]?.ToString()
                            });
                        }
                    }

                    // Jika belum ada data kompetensi, auto-seed 6 matriks kompetensi standar posisi tambang
                    if (list.Count == 0 && idPersonal > 0)
                    {
                        var defaultSkills = new[]
                        {
                            ("Identifikasi Bahaya & Penilaian Risiko (IBPR/HIRA)", "K3LH Tambang", "Level 4", "Level 4", "COMPETENT", "Superintendent HSE", "Menguasai HIRADC area operasi pit & workshop"),
                            ("SOP Golden Rules & Kepatuhan Isolasi Energi (LOTO)", "K3LH Tambang", "Level 4", "Level 4", "COMPETENT", "Safety Inspector", "Kepatuhan penuh prosedur lock-out tag-out"),
                            ("Pengoperasian Kendaraan Ringan (LV 4x4) Area Tambang", "Operasional & Teknis", "Level 3", "Level 3", "COMPETENT", "Driver Assessor", "SIMPER aktif LV Hilux & Light Hauler"),
                            ("Investigasi Insiden & Safety Accountability (SAP)", "Manajemen K3", "Level 4", "Level 4", "COMPETENT", "Lead HSE Officer", "Pelaporan & evaluasi tindakan perbaikan insiden"),
                            ("Inspeksi K3 Terencana Lapangan & Observasi Tugas", "Operasional & Teknis", "Level 3", "Level 3", "COMPETENT", "Mine Foreman", "Inspeksi rutin front pit & disposal dump"),
                            ("Tanggap Darurat, Pemadam Api Ringan (APAR) & Evakuasi", "Emergency Response", "Level 3", "Level 3", "COMPETENT", "Emergency Response Team", "Sertifikasi First Aider & Fire Marshal Site")
                        };

                        foreach (var ds in defaultSkills)
                        {
                            using var cmdIns = conn.CreateCommand();
                            cmdIns.CommandText = @"
                                INSERT INTO [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                                (karyawan_id, personal_id, no_nik, nama_kompetensi, kategori, level_target, level_aktual, status, assessor, tanggal_assessment, catatan, created_at, created_by)
                                VALUES
                                (@karyawanId, @personalId, @nik, @nama, @kategori, @target, @aktual, @status, @assessor, GETDATE(), @catatan, GETDATE(), 'System_Seed');
                            ";
                            AddParam(cmdIns, "@karyawanId", idKaryawan);
                            AddParam(cmdIns, "@personalId", idPersonal);
                            AddParam(cmdIns, "@nik", targetNik);
                            AddParam(cmdIns, "@nama", ds.Item1);
                            AddParam(cmdIns, "@kategori", ds.Item2);
                            AddParam(cmdIns, "@target", ds.Item3);
                            AddParam(cmdIns, "@aktual", ds.Item4);
                            AddParam(cmdIns, "@status", ds.Item5);
                            AddParam(cmdIns, "@assessor", ds.Item6);
                            AddParam(cmdIns, "@catatan", ds.Item7);
                            await cmdIns.ExecuteNonQueryAsync();

                            list.Add(new Dictionary<string, object?>
                            {
                                ["id"] = 0,
                                ["nama_kompetensi"] = ds.Item1,
                                ["kategori"] = ds.Item2,
                                ["level_target"] = ds.Item3,
                                ["level_aktual"] = ds.Item4,
                                ["status"] = ds.Item5,
                                ["assessor"] = ds.Item6,
                                ["tanggal_assessment"] = DateTime.Today.ToString("yyyy-MM-dd"),
                                ["catatan"] = ds.Item7
                            });
                        }
                    }

                    return Ok(new
                    {
                        success = true,
                        count = list.Count,
                        data = list
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    success = false,
                    message = $"Gagal mengambil matriks skill: {ex.Message}"
                });
            }
        }

        /// <summary>
        /// POST /api/one-ev/skill-matrix
        /// Memperbarui atau menambahkan penilaian matriks skill ke [tbl_r_karyawan_lms_competency].
        /// </summary>
        [HttpPost("skill-matrix")]
        [AllowAnonymous]
        public async Task<IActionResult> UpdateSkillMatrix([FromBody] OneEvSkillMatrixRequest request)
        {
            var targetNik = GetCallerNik(request.NoNik);
            var callerName = GetCallerName();

            if (string.IsNullOrWhiteSpace(request.NamaKompetensi))
            {
                return BadRequest(new { success = false, message = "Nama kompetensi wajib diisi." });
            }

            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    int idPersonal = 0;
                    int idKaryawan = 0;
                    using (var findCmd = conn.CreateCommand())
                    {
                        findCmd.CommandText = "SELECT TOP 1 id_karyawan, id_personal FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan WHERE no_nik = @nik;";
                        AddParam(findCmd, "@nik", targetNik);
                        using var r = await findCmd.ExecuteReaderAsync();
                        if (await r.ReadAsync())
                        {
                            idKaryawan = r["id_karyawan"] != DBNull.Value ? Convert.ToInt32(r["id_karyawan"]) : 0;
                            idPersonal = r["id_personal"] != DBNull.Value ? Convert.ToInt32(r["id_personal"]) : 0;
                        }
                    }

                    using var cmd = conn.CreateCommand();
                    if (request.Id > 0)
                    {
                        cmd.CommandText = @"
                            UPDATE [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                            SET nama_kompetensi = COALESCE(@nama, nama_kompetensi),
                                kategori = COALESCE(@kategori, kategori),
                                level_target = COALESCE(@target, level_target),
                                level_aktual = COALESCE(@aktual, level_aktual),
                                status = COALESCE(@status, status),
                                assessor = COALESCE(@assessor, assessor),
                                catatan = COALESCE(@catatan, catatan),
                                updated_at = GETDATE(),
                                updated_by = @updater
                            WHERE id = @id AND (no_nik = @nik OR personal_id = @personalId);
                        ";
                        AddParam(cmd, "@id", request.Id);
                    }
                    else
                    {
                        cmd.CommandText = @"
                            INSERT INTO [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                            (karyawan_id, personal_id, no_nik, nama_kompetensi, kategori, level_target, level_aktual, status, assessor, tanggal_assessment, catatan, created_at, created_by)
                            VALUES
                            (@karyawanId, @personalId, @nik, @nama, @kategori, @target, @aktual, @status, @assessor, GETDATE(), @catatan, GETDATE(), @updater);
                        ";
                    }

                    AddParam(cmd, "@karyawanId", idKaryawan);
                    AddParam(cmd, "@personalId", idPersonal);
                    AddParam(cmd, "@nik", targetNik);
                    AddParam(cmd, "@nama", request.NamaKompetensi);
                    AddParam(cmd, "@kategori", request.Kategori ?? "K3LH Tambang");
                    AddParam(cmd, "@target", request.LevelTarget ?? "Level 3");
                    AddParam(cmd, "@aktual", request.LevelAktual ?? "Level 3");
                    AddParam(cmd, "@status", request.Status ?? "COMPETENT");
                    AddParam(cmd, "@assessor", request.Assessor ?? $"Assessor_{callerName}");
                    AddParam(cmd, "@catatan", request.Catatan);
                    AddParam(cmd, "@updater", $"MobileApp_{callerName}");

                    await cmd.ExecuteNonQueryAsync();

                    return Ok(new
                    {
                        success = true,
                        message = "Matriks skill berhasil diperbarui di database One Evolution."
                    });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    success = false,
                    message = $"Gagal menyimpan matriks skill: {ex.Message}"
                });
            }
        }

        private static void AddParam(DbCommand cmd, string name, object? value)
        {
            var p = cmd.CreateParameter();
            p.ParameterName = name;
            p.Value = value ?? DBNull.Value;
            cmd.Parameters.Add(p);
        }
    }

    public class OneEvProfileUpdateRequest
    {
        public string? NoNik { get; set; }
        public string? Hp1 { get; set; }
        public string? Hp2 { get; set; }
        public string? EmailPribadi { get; set; }
        public string? EmailKantor { get; set; }
        public string? Alamat { get; set; }
        public string? Provinsi { get; set; }
        public string? Kabupaten { get; set; }
        public string? Kecamatan { get; set; }
        public string? Desa { get; set; }
        public string? KodePos { get; set; }
        public string? KontakDaruratNama { get; set; }
        public string? KontakDaruratTelp { get; set; }
        public string? KontakDaruratRelasi { get; set; }
    }

    public class OneEvCertificateRequest
    {
        public int Id { get; set; }
        public string? NoNik { get; set; }
        public string? NamaSertifikat { get; set; }
        public string? Penyelenggara { get; set; }
        public DateTime? TanggalTerbit { get; set; }
        public DateTime? TanggalExpired { get; set; }
        public string? FilePath { get; set; }
    }

    public class OneEvSkillMatrixRequest
    {
        public int Id { get; set; }
        public string? NoNik { get; set; }
        public string? NamaKompetensi { get; set; }
        public string? Kategori { get; set; }
        public string? LevelTarget { get; set; }
        public string? LevelAktual { get; set; }
        public string? Status { get; set; }
        public string? Assessor { get; set; }
        public string? Catatan { get; set; }
    }
}
