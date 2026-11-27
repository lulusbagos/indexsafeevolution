using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Indexsafe.Api.Data;
using Indexsafe.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/one-ev")]
    public class OneEvController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly PermitService _permitService;

        public OneEvController(AppDbContext context, IConfiguration configuration, PermitService permitService)
        {
            _context = context;
            _configuration = configuration;
            _permitService = permitService;
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
        /// GET /api/one-ev/simper
        /// Mengambil data SIMPER Tambang resmi dan daftar unit yang diizinkan (tb_simper & tb_simper_unit) dari PostgreSQL BIMA.
        /// </summary>
        [HttpGet("simper")]
        [AllowAnonymous]
        public async Task<IActionResult> GetSimperDetail([FromQuery] string? nik = null)
        {
            var targetNik = GetCallerNik(nik);
            try
            {
                var simper = await _permitService.GetFullSimperDetailAsync(targetNik);
                if (simper == null)
                {
                    return Ok(new
                    {
                        success = true,
                        has_simper = false,
                        message = "Data SIMPER Tambang belum terdaftar untuk karyawan ini."
                    });
                }

                return Ok(new
                {
                    success = true,
                    has_simper = true,
                    data = simper
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    success = false,
                    message = "Gagal mengambil data SIMPER Tambang: " + ex.Message
                });
            }
        }

        /// <summary>
        /// GET /api/one-ev/profile
        /// Mengambil rincian data karyawan aktif dari tabel [ONE_DB_MITRA] sesuai form /KaryawanAdmin/Edit/.
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
                    // 1. Data utama dari vw_m_karyawan_aktif dan tabel pendukung
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
                            p.no_npwp, p.no_bpjs_tk, p.no_bpjs_kes, p.no_bpjs_pensiun, p.alamat, p.provinsi, p.kabupaten, p.kecamatan, p.desa, p.kode_pos,
                            p.id_pendidikan, p.nama_sekolah, p.fakultas, p.jurusan,
                            a.nama as nama_agama, sn.nama as nama_status_nikah, tp.nama as nama_jenjang_pendidikan,
                            k.email_kantor
                        FROM [ONE_DB_MITRA].dbo.vw_m_karyawan_aktif ka
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_personal p ON ka.id_personal = p.id_personal
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_t_karyawan k ON ka.id_karyawan = k.id_karyawan
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_agama a ON p.id_agama = a.id
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_status_nikah sn ON p.id_status_nikah = sn.id
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_tingkat_pendidikan tp ON p.id_pendidikan = tp.id
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
                        ["warga_negara"] = reader["warga_negara"]?.ToString() ?? "",
                        ["jenis_kelamin"] = reader["jenis_kelamin"]?.ToString() ?? "",
                        ["tempat_lahir"] = reader["tempat_lahir"]?.ToString() ?? "",
                        ["tanggal_lahir"] = reader["tanggal_lahir"] != DBNull.Value ? Convert.ToDateTime(reader["tanggal_lahir"]).ToString("yyyy-MM-dd") : null,
                        ["id_agama"] = reader["id_agama"] != DBNull.Value ? Convert.ToInt32(reader["id_agama"]) : (int?)null,
                        ["agama"] = reader["nama_agama"]?.ToString() ?? "",
                        ["id_status_nikah"] = reader["id_status_nikah"] != DBNull.Value ? Convert.ToInt32(reader["id_status_nikah"]) : (int?)null,
                        ["status_nikah"] = reader["nama_status_nikah"]?.ToString() ?? reader["status_nikah"]?.ToString() ?? "",
                        ["golongan_darah"] = null,
                        ["nama_ibu"] = reader["nama_ibu"]?.ToString() ?? "",
                        ["nama_ayah"] = reader["nama_ayah"]?.ToString() ?? "",

                        // Kontak
                        ["email_pribadi"] = reader["email_pribadi"]?.ToString() ?? "",
                        ["email_kantor"] = reader["email_kantor"]?.ToString() ?? "",
                        ["hp_1"] = reader["hp_1"]?.ToString() ?? "",
                        ["hp_2"] = reader["hp_2"]?.ToString() ?? "",

                        // Domisili
                        ["alamat"] = reader["alamat"]?.ToString() ?? reader["alamat_terbaru"]?.ToString() ?? "",
                        ["provinsi"] = reader["provinsi"]?.ToString() ?? "",
                        ["kabupaten"] = reader["kabupaten"]?.ToString() ?? "",
                        ["kecamatan"] = reader["kecamatan"]?.ToString() ?? "",
                        ["desa"] = reader["desa"]?.ToString() ?? "",
                        ["rt"] = System.Text.RegularExpressions.Regex.Match(reader["alamat"]?.ToString() ?? reader["alamat_terbaru"]?.ToString() ?? "", @"RT\s*(\d+)", System.Text.RegularExpressions.RegexOptions.IgnoreCase).Groups[1].Value,
                        ["rw"] = System.Text.RegularExpressions.Regex.Match(reader["alamat"]?.ToString() ?? reader["alamat_terbaru"]?.ToString() ?? "", @"RW\s*(\d+)", System.Text.RegularExpressions.RegexOptions.IgnoreCase).Groups[1].Value,
                        ["kode_pos"] = reader["kode_pos"]?.ToString() ?? reader["kode_pos_alamat"]?.ToString() ?? "",

                        // Jaminan & Pajak
                        ["no_npwp"] = reader["no_npwp"]?.ToString() ?? "",
                        ["no_bpjs_tk"] = reader["no_bpjs_tk"]?.ToString() ?? "",
                        ["no_bpjs_kes"] = reader["no_bpjs_kes"]?.ToString() ?? "",
                        ["no_bpjs_pensiun"] = reader["no_bpjs_pensiun"]?.ToString() ?? "",

                        // Pendidikan
                        ["id_pendidikan"] = reader["id_pendidikan"] != DBNull.Value ? Convert.ToInt32(reader["id_pendidikan"]) : (int?)null,
                        ["jenjang_pendidikan"] = reader["nama_jenjang_pendidikan"]?.ToString() ?? "",
                        ["nama_sekolah"] = reader["nama_sekolah"]?.ToString() ?? "",
                        ["fakultas"] = reader["fakultas"]?.ToString() ?? "",
                        ["jurusan"] = reader["jurusan"]?.ToString() ?? "",

                        // Kepegawaian (Terkunci HR)
                        ["id_perusahaan"] = reader["id_perusahaan"] != DBNull.Value ? Convert.ToInt32(reader["id_perusahaan"]) : 0,
                        ["nama_perusahaan"] = reader["nama_perusahaan"]?.ToString() ?? "",
                        ["kode_perusahaan"] = reader["kode_perusahaan"]?.ToString() ?? "",
                        ["id_departemen"] = reader["id_departemen"] != DBNull.Value ? Convert.ToInt32(reader["id_departemen"]) : 0,
                        ["nama_departemen"] = reader["nama_departemen"]?.ToString() ?? "",
                        ["nama_seksi"] = reader["nama_seksi"]?.ToString() ?? "",
                        ["id_jabatan"] = reader["id_jabatan"] != DBNull.Value ? Convert.ToInt32(reader["id_jabatan"]) : 0,
                        ["nama_jabatan"] = reader["nama_jabatan"]?.ToString() ?? "",
                        ["id_posisi"] = reader["id_posisi"] != DBNull.Value ? Convert.ToInt32(reader["id_posisi"]) : 0,
                        ["nama_posisi"] = reader["nama_posisi"]?.ToString() ?? reader["nama_jabatan"]?.ToString() ?? "",
                        ["grade"] = reader["grade"]?.ToString() ?? "",
                        ["roster_kerja"] = reader["roster_kerja"]?.ToString() ?? "",
                        ["golongan_tipe"] = reader["golongan_tipe"]?.ToString() ?? "",
                        ["lokasi_kerja"] = reader["lokasi_kerja"]?.ToString() ?? "",
                        ["tanggal_masuk"] = reader["tanggal_masuk"] != DBNull.Value ? Convert.ToDateTime(reader["tanggal_masuk"]).ToString("yyyy-MM-dd") : null,
                        ["tanggal_aktif"] = reader["tanggal_aktif"] != DBNull.Value ? Convert.ToDateTime(reader["tanggal_aktif"]).ToString("yyyy-MM-dd") : null,
                        ["path_foto"] = !string.IsNullOrWhiteSpace(reader["path_foto"]?.ToString())
                            ? (reader["path_foto"]!.ToString()!.Trim().StartsWith("http", StringComparison.OrdinalIgnoreCase)
                                ? reader["path_foto"]!.ToString()!.Trim()
                                : "https://oneev.indexim.id" + (reader["path_foto"]!.ToString()!.Trim().StartsWith("/") ? "" : "/") + reader["path_foto"]!.ToString()!.Trim().Replace("\\", "/"))
                            : null,
                        ["status_aktif"] = reader["status_aktif_efektif"] != DBNull.Value && Convert.ToBoolean(reader["status_aktif_efektif"]),
                        ["permit_jenis"] = reader["permit_pengajuan_terakhir"]?.ToString() ?? "",
                        ["permit_berakhir"] = reader["permit_berakhir_kerja"] != DBNull.Value ? Convert.ToDateTime(reader["permit_berakhir_kerja"]).ToString("yyyy-MM-dd") : null,
                    };
                    reader.Close();

                    // 2. Kontak Darurat dari tbl_t_karyawan_kontak_darurat
                    using var cmdKd = conn.CreateCommand();
                    cmdKd.CommandText = @"
                        SELECT TOP 1 nama, telp, telp_lain, relasi, keterangan
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
                        profileData["kontak_darurat_nama"] = readerKd["nama"]?.ToString() ?? "";
                        profileData["kontak_darurat_telp"] = readerKd["telp"]?.ToString() ?? "";
                        profileData["kontak_darurat_telp_lain"] = readerKd["telp_lain"]?.ToString() ?? "";
                        profileData["kontak_darurat_relasi"] = readerKd["relasi"]?.ToString() ?? "";
                        profileData["kontak_darurat_keterangan"] = readerKd["keterangan"]?.ToString() ?? "";
                    }
                    else
                    {
                        profileData["kontak_darurat_nama"] = "";
                        profileData["kontak_darurat_telp"] = "";
                        profileData["kontak_darurat_telp_lain"] = "";
                        profileData["kontak_darurat_relasi"] = "";
                        profileData["kontak_darurat_keterangan"] = "";
                    }
                    readerKd.Close();

                    // 2b. Medical Check Up (MCU) dari tbl_t_karyawan_mcu
                    using var cmdMcu = conn.CreateCommand();
                    cmdMcu.CommandText = @"
                        SELECT TOP 1 m.id, m.tanggal_mcu, m.keterangan_mcu, j.hasil_mcu, m.file_pendukung
                        FROM [ONE_DB_MITRA].dbo.tbl_t_karyawan_mcu m
                        LEFT JOIN [ONE_DB_MITRA].dbo.tbl_m_mcu_jenis j ON m.id_hasil_mcu = j.id
                        WHERE m.id_personal = @idPersonal AND (m.deleted_at IS NULL)
                        ORDER BY m.id DESC;
                    ";
                    var pIdMcu = cmdMcu.CreateParameter();
                    pIdMcu.ParameterName = "@idPersonal";
                    pIdMcu.Value = idPersonal;
                    cmdMcu.Parameters.Add(pIdMcu);

                    using var readerMcu = await cmdMcu.ExecuteReaderAsync();
                    if (await readerMcu.ReadAsync())
                    {
                        profileData["mcu_tanggal"] = readerMcu["tanggal_mcu"] != DBNull.Value ? Convert.ToDateTime(readerMcu["tanggal_mcu"]).ToString("yyyy-MM-dd") : null;
                        profileData["mcu_hasil"] = readerMcu["hasil_mcu"]?.ToString() ?? "";
                        profileData["mcu_keterangan"] = readerMcu["keterangan_mcu"]?.ToString() ?? "";
                        profileData["mcu_file"] = readerMcu["file_pendukung"]?.ToString() ?? "";
                    }
                    else
                    {
                        profileData["mcu_tanggal"] = null;
                        profileData["mcu_hasil"] = "";
                        profileData["mcu_keterangan"] = "";
                        profileData["mcu_file"] = "";
                    }
                    readerMcu.Close();

                    // 3. Ringkasan Sertifikat & Skill (DEDUPLICATED)
                    using var cmdCount = conn.CreateCommand();
                    cmdCount.CommandText = @"
                        SELECT 
                            (SELECT COUNT(DISTINCT LOWER(LTRIM(RTRIM(nama_training)))) 
                             FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_training 
                             WHERE (no_nik = @nik OR (personal_id = @idPersonal AND @idPersonal > 0))
                               AND nama_training IS NOT NULL AND LTRIM(RTRIM(nama_training)) <> '') as total_training,
                            (SELECT COUNT(DISTINCT LOWER(LTRIM(RTRIM(nama_kompetensi)))) 
                             FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency 
                             WHERE (no_nik = @nik OR (personal_id = @idPersonal AND @idPersonal > 0))
                               AND nama_kompetensi IS NOT NULL AND LTRIM(RTRIM(nama_kompetensi)) <> '') as total_competency;
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
        /// Mengedit data karyawan sesuai login dari semua form /KaryawanAdmin/Edit/ (KECUALI form kepegawaian).
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

                    // 1. Update tbl_m_personal (Semua form personal, domisili, kontak, jaminan, dan pendidikan)
                    using (var cmdP = conn.CreateCommand())
                    {
                        cmdP.CommandText = @"
                            UPDATE [ONE_DB_MITRA].dbo.tbl_m_personal
                            SET nama_lengkap = COALESCE(@namaLengkap, nama_lengkap),
                                nama_alias = COALESCE(@namaAlias, nama_alias),
                                warga_negara = COALESCE(@wargaNegara, warga_negara),
                                no_ktp = COALESCE(@noKtp, no_ktp),
                                no_kk = COALESCE(@noKk, no_kk),
                                jenis_kelamin = COALESCE(@jenisKelamin, jenis_kelamin),
                                tempat_lahir = COALESCE(@tempatLahir, tempat_lahir),
                                tanggal_lahir = COALESCE(@tanggalLahir, tanggal_lahir),
                                id_agama = COALESCE(@idAgama, id_agama),
                                id_status_nikah = COALESCE(@idStatusNikah, id_status_nikah),
                                status_nikah = COALESCE(@statusNikah, status_nikah),
                                nama_ibu = COALESCE(@namaIbu, nama_ibu),
                                nama_ayah = COALESCE(@namaAyah, nama_ayah),
                                hp_1 = COALESCE(@hp1, hp_1),
                                hp_2 = COALESCE(@hp2, hp_2),
                                email_pribadi = COALESCE(@emailPribadi, email_pribadi),
                                alamat = COALESCE(@alamat, alamat),
                                provinsi = COALESCE(@provinsi, provinsi),
                                kabupaten = COALESCE(@kabupaten, kabupaten),
                                kecamatan = COALESCE(@kecamatan, kecamatan),
                                desa = COALESCE(@desa, desa),
                                kode_pos = COALESCE(@kodePos, kode_pos),
                                no_npwp = COALESCE(@noNpwp, no_npwp),
                                no_bpjs_tk = COALESCE(@noBpjsTk, no_bpjs_tk),
                                no_bpjs_kes = COALESCE(@noBpjsKes, no_bpjs_kes),
                                no_bpjs_pensiun = COALESCE(@noBpjsPensiun, no_bpjs_pensiun),
                                id_pendidikan = COALESCE(@idPendidikan, id_pendidikan),
                                nama_sekolah = COALESCE(@namaSekolah, nama_sekolah),
                                fakultas = COALESCE(@fakultas, fakultas),
                                jurusan = COALESCE(@jurusan, jurusan),
                                updated_at = GETDATE(),
                                updated_by = @updater
                            WHERE id_personal = @idPersonal;
                        ";
                        AddParam(cmdP, "@namaLengkap", request.NamaLengkap);
                        AddParam(cmdP, "@namaAlias", request.NamaAlias);
                        AddParam(cmdP, "@wargaNegara", request.WargaNegara);
                        AddParam(cmdP, "@noKtp", request.NoKtp);
                        AddParam(cmdP, "@noKk", request.NoKk);
                        AddParam(cmdP, "@jenisKelamin", request.JenisKelamin);
                        AddParam(cmdP, "@tempatLahir", request.TempatLahir);
                        AddParam(cmdP, "@tanggalLahir", request.TanggalLahir);
                        AddParam(cmdP, "@idAgama", request.IdAgama);
                        AddParam(cmdP, "@idStatusNikah", request.IdStatusNikah);
                        AddParam(cmdP, "@statusNikah", request.StatusNikah);
                        AddParam(cmdP, "@namaIbu", request.NamaIbu);
                        AddParam(cmdP, "@namaAyah", request.NamaAyah);
                        AddParam(cmdP, "@hp1", request.Hp1);
                        AddParam(cmdP, "@hp2", request.Hp2);
                        AddParam(cmdP, "@emailPribadi", request.EmailPribadi);
                        AddParam(cmdP, "@alamat", request.Alamat);
                        AddParam(cmdP, "@provinsi", request.Provinsi);
                        AddParam(cmdP, "@kabupaten", request.Kabupaten);
                        AddParam(cmdP, "@kecamatan", request.Kecamatan);
                        AddParam(cmdP, "@desa", request.Desa);
                        AddParam(cmdP, "@kodePos", request.KodePos);
                        AddParam(cmdP, "@noNpwp", request.NoNpwp);
                        AddParam(cmdP, "@noBpjsTk", request.NoBpjsTk);
                        AddParam(cmdP, "@noBpjsKes", request.NoBpjsKes);
                        AddParam(cmdP, "@noBpjsPensiun", request.NoBpjsPensiun);
                        AddParam(cmdP, "@idPendidikan", request.IdPendidikan);
                        AddParam(cmdP, "@namaSekolah", request.NamaSekolah);
                        AddParam(cmdP, "@fakultas", request.Fakultas);
                        AddParam(cmdP, "@jurusan", request.Jurusan);
                        AddParam(cmdP, "@updater", $"MobileApp_{callerName}");
                        AddParam(cmdP, "@idPersonal", idPersonal);

                        await cmdP.ExecuteNonQueryAsync();
                    }

                    // 2. Update email_kantor di tbl_t_karyawan (Penempatan/Kepegawaian lainnya dilindungi HR)
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
                                    telp_lain = COALESCE(@telpLain, telp_lain),
                                    relasi = COALESCE(@relasi, relasi),
                                    keterangan = COALESCE(@keterangan, keterangan),
                                    status_aktif = '1',
                                    updated_at = GETDATE(),
                                    updated_by = @updater
                                WHERE id_personal = @idPersonal;
                            END
                            ELSE
                            BEGIN
                                INSERT INTO [ONE_DB_MITRA].dbo.tbl_t_karyawan_kontak_darurat
                                (id_personal, nama, telp, telp_lain, relasi, keterangan, status_aktif, created_at, created_by)
                                VALUES
                                (@idPersonal, @nama, @telp, @telpLain, @relasi, @keterangan, '1', GETDATE(), @updater);
                            END
                        ";
                        AddParam(cmdKd, "@idPersonal", idPersonal);
                        AddParam(cmdKd, "@nama", request.KontakDaruratNama);
                        AddParam(cmdKd, "@telp", request.KontakDaruratTelp);
                        AddParam(cmdKd, "@telpLain", request.KontakDaruratTelpLain);
                        AddParam(cmdKd, "@relasi", request.KontakDaruratRelasi ?? "Keluarga");
                        AddParam(cmdKd, "@keterangan", request.KontakDaruratKeterangan);
                        AddParam(cmdKd, "@updater", $"MobileApp_{callerName}");
                        await cmdKd.ExecuteNonQueryAsync();
                    }

                    return Ok(new
                    {
                        success = true,
                        message = "Semua form profil karyawan (personal, kontak, domisili, darurat, jaminan, pendidikan) berhasil diperbarui di database One Evolution.",
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
        /// Mengambil daftar sertifikat / training karyawan dari tabel [tbl_r_karyawan_training] TANPA DUPLIKAT.
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

                    // 1. Bersihkan duplikat fisik lama di database untuk user ini (simpan 1 record ID terbaru)
                    try
                    {
                        using var cleanCmd = conn.CreateCommand();
                        cleanCmd.CommandText = @"
                            DELETE FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                            WHERE training_id IN (
                                SELECT training_id FROM (
                                    SELECT training_id,
                                           ROW_NUMBER() OVER (
                                               PARTITION BY LOWER(LTRIM(RTRIM(nama_training))), LOWER(LTRIM(RTRIM(ISNULL(penyelenggara, ''))))
                                               ORDER BY COALESCE(tanggal_expired, tanggal_training, created_at) DESC, training_id DESC
                                           ) AS rn
                                    FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                                    WHERE (no_nik = @nik OR (personal_id = @idPersonal AND @idPersonal > 0))
                                      AND nama_training IS NOT NULL AND LTRIM(RTRIM(nama_training)) <> ''
                                ) t WHERE t.rn > 1
                            );
                        ";
                        AddParam(cleanCmd, "@nik", targetNik);
                        AddParam(cleanCmd, "@idPersonal", idPersonal);
                        await cleanCmd.ExecuteNonQueryAsync();
                    }
                    catch
                    {
                        // Ignore jika table lock
                    }

                    // 2. Ambil daftar training unik (DEDUPLICATED)
                    var list = new List<Dictionary<string, object?>>();
                    using (var cmd = conn.CreateCommand())
                    {
                        cmd.CommandText = @"
                            WITH RankedTraining AS (
                                SELECT training_id, no_nik, nama_training, penyelenggara, tanggal_training, tanggal_expired, file_path, created_at,
                                       ROW_NUMBER() OVER (
                                           PARTITION BY LOWER(LTRIM(RTRIM(nama_training))), LOWER(LTRIM(RTRIM(ISNULL(penyelenggara, ''))))
                                           ORDER BY COALESCE(tanggal_expired, tanggal_training, created_at) DESC, training_id DESC
                                       ) AS rn
                                FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                                WHERE (no_nik = @nik OR (personal_id = @idPersonal AND @idPersonal > 0))
                                  AND nama_training IS NOT NULL AND LTRIM(RTRIM(nama_training)) <> ''
                            )
                            SELECT training_id, no_nik, nama_training, penyelenggara, tanggal_training, tanggal_expired, file_path, created_at
                            FROM RankedTraining
                            WHERE rn = 1
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
        /// Menambahkan atau memperbarui data sertifikat ke [tbl_r_karyawan_training] (Mencegah duplikat).
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

                    // Upsert untuk mencegah sertifikat duplikat
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        IF EXISTS (
                            SELECT 1 FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                            WHERE (no_nik = @nik OR personal_id = @personalId)
                              AND LOWER(LTRIM(RTRIM(nama_training))) = LOWER(LTRIM(RTRIM(@nama)))
                        )
                        BEGIN
                            UPDATE [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                            SET penyelenggara = COALESCE(@penyelenggara, penyelenggara),
                                tanggal_training = @tglTrain,
                                tanggal_expired = @tglExp,
                                file_path = COALESCE(@filePath, file_path),
                                updated_at = GETDATE(),
                                updated_by = @updater
                            WHERE (no_nik = @nik OR personal_id = @personalId)
                              AND LOWER(LTRIM(RTRIM(nama_training))) = LOWER(LTRIM(RTRIM(@nama)));
                            SELECT 1;
                        END
                        ELSE
                        BEGIN
                            INSERT INTO [ONE_DB_MITRA].dbo.tbl_r_karyawan_training
                            (karyawan_id, personal_id, no_nik, nama_training, penyelenggara, tanggal_training, tanggal_expired, file_path, created_at, created_by)
                            VALUES
                            (@karyawanId, @personalId, @nik, @nama, @penyelenggara, @tglTrain, @tglExp, @filePath, GETDATE(), @updater);
                            SELECT SCOPE_IDENTITY();
                        END
                    ";
                    AddParam(cmd, "@karyawanId", idKaryawan);
                    AddParam(cmd, "@personalId", idPersonal);
                    AddParam(cmd, "@nik", targetNik);
                    AddParam(cmd, "@nama", request.NamaSertifikat.Trim());
                    AddParam(cmd, "@penyelenggara", request.Penyelenggara ?? "Lembaga Diklat K3");
                    AddParam(cmd, "@tglTrain", request.TanggalTerbit.HasValue ? request.TanggalTerbit.Value : DateTime.Today);
                    AddParam(cmd, "@tglExp", request.TanggalExpired);
                    AddParam(cmd, "@filePath", request.FilePath);
                    AddParam(cmd, "@updater", $"MobileApp_{callerName}");

                    var newId = await cmd.ExecuteScalarAsync();

                    return Ok(new
                    {
                        success = true,
                        message = "Sertifikat berhasil disimpan ke database One Evolution (tanpa duplikat).",
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
        /// Mengambil daftar matriks skill & kompetensi karyawan dari tabel [tbl_r_karyawan_lms_competency] TANPA DUPLIKAT.
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
                            WITH RankedSkills AS (
                                SELECT id, no_nik, nama_kompetensi, kategori, level_target, level_aktual, status, assessor, tanggal_assessment, catatan,
                                       ROW_NUMBER() OVER (
                                           PARTITION BY LOWER(LTRIM(RTRIM(nama_kompetensi)))
                                           ORDER BY tanggal_assessment DESC, id DESC
                                       ) AS rn
                                FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                                WHERE (no_nik = @nik OR (personal_id = @idPersonal AND @idPersonal > 0))
                                  AND nama_kompetensi IS NOT NULL AND LTRIM(RTRIM(nama_kompetensi)) <> ''
                            )
                            SELECT id, no_nik, nama_kompetensi, kategori, level_target, level_aktual, status, assessor, tanggal_assessment, catatan
                            FROM RankedSkills
                            WHERE rn = 1
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
        /// Memperbarui atau menambahkan penilaian matriks skill ke [tbl_r_karyawan_lms_competency] (Mencegah duplikat).
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
                            IF EXISTS (
                                SELECT 1 FROM [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                                WHERE (no_nik = @nik OR personal_id = @personalId)
                                  AND LOWER(LTRIM(RTRIM(nama_kompetensi))) = LOWER(LTRIM(RTRIM(@nama)))
                            )
                            BEGIN
                                UPDATE [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                                SET kategori = COALESCE(@kategori, kategori),
                                    level_target = COALESCE(@target, level_target),
                                    level_aktual = COALESCE(@aktual, level_aktual),
                                    status = COALESCE(@status, status),
                                    assessor = COALESCE(@assessor, assessor),
                                    catatan = COALESCE(@catatan, catatan),
                                    updated_at = GETDATE(),
                                    updated_by = @updater
                                WHERE (no_nik = @nik OR personal_id = @personalId)
                                  AND LOWER(LTRIM(RTRIM(nama_kompetensi))) = LOWER(LTRIM(RTRIM(@nama)));
                            END
                            ELSE
                            BEGIN
                                INSERT INTO [ONE_DB_MITRA].dbo.tbl_r_karyawan_lms_competency
                                (karyawan_id, personal_id, no_nik, nama_kompetensi, kategori, level_target, level_aktual, status, assessor, tanggal_assessment, catatan, created_at, created_by)
                                VALUES
                                (@karyawanId, @personalId, @nik, @nama, @kategori, @target, @aktual, @status, @assessor, GETDATE(), @catatan, GETDATE(), @updater);
                            END
                        ";
                    }

                    AddParam(cmd, "@karyawanId", idKaryawan);
                    AddParam(cmd, "@personalId", idPersonal);
                    AddParam(cmd, "@nik", targetNik);
                    AddParam(cmd, "@nama", request.NamaKompetensi.Trim());
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
                        message = "Matriks skill berhasil diperbarui di database One Evolution (tanpa duplikat)."
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

        [HttpGet("master/agama")]
        [AllowAnonymous]
        public async Task<IActionResult> GetMasterAgama()
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = "SELECT id, UPPER(LTRIM(RTRIM(nama))) AS nama FROM [ONE_DB_MITRA].dbo.tbl_m_agama WHERE (status_aktif IS NULL OR status_aktif = '1') ORDER BY id ASC;";
                    using var reader = await cmd.ExecuteReaderAsync();
                    var list = new List<object>();
                    while (await reader.ReadAsync())
                    {
                        list.Add(new
                        {
                            id = Convert.ToInt32(reader["id"]),
                            nama = reader["nama"]?.ToString() ?? ""
                        });
                    }
                    return Ok(new { success = true, data = list });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal mengambil master agama: {ex.Message}" });
            }
        }

        [HttpGet("master/pendidikan")]
        [AllowAnonymous]
        public async Task<IActionResult> GetMasterPendidikan()
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = "SELECT id, UPPER(LTRIM(RTRIM(nama))) AS nama FROM [ONE_DB_MITRA].dbo.tbl_m_tingkat_pendidikan ORDER BY id ASC;";
                    using var reader = await cmd.ExecuteReaderAsync();
                    var list = new List<object>();
                    while (await reader.ReadAsync())
                    {
                        list.Add(new
                        {
                            id = Convert.ToInt32(reader["id"]),
                            nama = reader["nama"]?.ToString() ?? ""
                        });
                    }
                    return Ok(new { success = true, data = list });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal mengambil master tingkat pendidikan: {ex.Message}" });
            }
        }

        [HttpGet("master/provinsi")]
        [AllowAnonymous]
        public async Task<IActionResult> GetMasterProvinsi()
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = "SELECT kode_provinsi AS kode, UPPER(LTRIM(RTRIM(nama_provinsi))) AS nama FROM [ONE_DB_MITRA].dbo.tbl_m_provinsi ORDER BY nama ASC;";
                    using var reader = await cmd.ExecuteReaderAsync();
                    var list = new List<object>();
                    while (await reader.ReadAsync())
                    {
                        list.Add(new
                        {
                            kode = reader["kode"]?.ToString() ?? "",
                            nama = reader["nama"]?.ToString() ?? ""
                        });
                    }
                    return Ok(new { success = true, data = list });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal mengambil master provinsi: {ex.Message}" });
            }
        }

        [HttpGet("master/kabupaten")]
        [AllowAnonymous]
        public async Task<IActionResult> GetMasterKabupaten([FromQuery] string? provinsi = null)
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        DECLARE @provParam NVARCHAR(100) = @prov;
                        DECLARE @provKode VARCHAR(10) = NULL;

                        IF @provParam IS NOT NULL AND LTRIM(RTRIM(@provParam)) <> ''
                        BEGIN
                            SELECT TOP 1 @provKode = kode_provinsi 
                            FROM [ONE_DB_MITRA].dbo.tbl_m_provinsi 
                            WHERE UPPER(LTRIM(RTRIM(nama_provinsi))) = UPPER(LTRIM(RTRIM(@provParam))) OR kode_provinsi = @provParam;
                        END

                        SELECT MIN(kode_kabupaten) AS kode, UPPER(LTRIM(RTRIM(nama_kabupaten))) AS nama 
                        FROM [ONE_DB_MITRA].dbo.tbl_m_kabupaten 
                        WHERE (@provKode IS NULL OR kode_provinsi = @provKode OR LEFT(kode_kabupaten, 2) = @provKode)
                        GROUP BY UPPER(LTRIM(RTRIM(nama_kabupaten)))
                        ORDER BY nama ASC;
                    ";
                    AddParam(cmd, "@prov", string.IsNullOrWhiteSpace(provinsi) ? (object)DBNull.Value : provinsi.Trim());
                    using var reader = await cmd.ExecuteReaderAsync();
                    var list = new List<object>();
                    while (await reader.ReadAsync())
                    {
                        list.Add(new
                        {
                            kode = reader["kode"]?.ToString() ?? "",
                            nama = reader["nama"]?.ToString() ?? ""
                        });
                    }
                    return Ok(new { success = true, data = list });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal mengambil master kabupaten: {ex.Message}" });
            }
        }

        [HttpGet("master/kecamatan")]
        [AllowAnonymous]
        public async Task<IActionResult> GetMasterKecamatan([FromQuery] string? kabupaten = null)
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        DECLARE @kabParam NVARCHAR(100) = @kab;
                        DECLARE @kabKode VARCHAR(10) = NULL;

                        IF @kabParam IS NOT NULL AND LTRIM(RTRIM(@kabParam)) <> ''
                        BEGIN
                            SELECT TOP 1 @kabKode = kode_kabupaten 
                            FROM [ONE_DB_MITRA].dbo.tbl_m_kabupaten 
                            WHERE UPPER(LTRIM(RTRIM(nama_kabupaten))) = UPPER(LTRIM(RTRIM(@kabParam))) OR kode_kabupaten = @kabParam;
                        END

                        SELECT MIN(kode_kecamatan) AS kode, UPPER(LTRIM(RTRIM(nama_kecamatan))) AS nama 
                        FROM [ONE_DB_MITRA].dbo.tbl_m_kecamatan 
                        WHERE (@kabKode IS NULL OR kode_kabupaten = @kabKode OR LEFT(kode_kecamatan, LEN(@kabKode)) = @kabKode)
                        GROUP BY UPPER(LTRIM(RTRIM(nama_kecamatan)))
                        ORDER BY nama ASC;
                    ";
                    AddParam(cmd, "@kab", string.IsNullOrWhiteSpace(kabupaten) ? (object)DBNull.Value : kabupaten.Trim());
                    using var reader = await cmd.ExecuteReaderAsync();
                    var list = new List<object>();
                    while (await reader.ReadAsync())
                    {
                        list.Add(new
                        {
                            kode = reader["kode"]?.ToString() ?? "",
                            nama = reader["nama"]?.ToString() ?? ""
                        });
                    }
                    return Ok(new { success = true, data = list });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal mengambil master kecamatan: {ex.Message}" });
            }
        }

        [HttpGet("master/kelurahan")]
        [AllowAnonymous]
        public async Task<IActionResult> GetMasterKelurahan([FromQuery] string? kecamatan = null)
        {
            try
            {
                var conn = _context.Database.GetDbConnection();
                bool wasClosed = conn.State != ConnectionState.Open;
                if (wasClosed) await conn.OpenAsync();

                try
                {
                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = @"
                        DECLARE @kecParam NVARCHAR(100) = @kec;
                        DECLARE @kecKode VARCHAR(20) = NULL;

                        IF @kecParam IS NOT NULL AND LTRIM(RTRIM(@kecParam)) <> ''
                        BEGIN
                            SELECT TOP 1 @kecKode = kode_kecamatan 
                            FROM [ONE_DB_MITRA].dbo.tbl_m_kecamatan 
                            WHERE UPPER(LTRIM(RTRIM(nama_kecamatan))) = UPPER(LTRIM(RTRIM(@kecParam))) OR kode_kecamatan = @kecParam;
                        END

                        SELECT MIN(kode_kelurahan) AS kode, UPPER(LTRIM(RTRIM(kelurahan))) AS nama 
                        FROM [ONE_DB_MITRA].dbo.tbl_m_kelurahan 
                        WHERE (@kecKode IS NULL OR kode_kecamatan = @kecKode OR LEFT(kode_kelurahan, LEN(@kecKode)) = @kecKode)
                        GROUP BY UPPER(LTRIM(RTRIM(kelurahan)))
                        ORDER BY nama ASC;
                    ";
                    AddParam(cmd, "@kec", string.IsNullOrWhiteSpace(kecamatan) ? (object)DBNull.Value : kecamatan.Trim());
                    using var reader = await cmd.ExecuteReaderAsync();
                    var list = new List<object>();
                    while (await reader.ReadAsync())
                    {
                        list.Add(new
                        {
                            kode = reader["kode"]?.ToString() ?? "",
                            nama = reader["nama"]?.ToString() ?? ""
                        });
                    }
                    return Ok(new { success = true, data = list });
                }
                finally
                {
                    if (wasClosed) await conn.CloseAsync();
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Gagal mengambil master kelurahan: {ex.Message}" });
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

        // Step 1: Personal
        public string? NamaLengkap { get; set; }
        public string? NamaAlias { get; set; }
        public string? WargaNegara { get; set; }
        public string? NoKtp { get; set; }
        public string? NoKk { get; set; }
        public string? JenisKelamin { get; set; }
        public string? TempatLahir { get; set; }
        public DateTime? TanggalLahir { get; set; }
        public int? IdAgama { get; set; }
        public string? Agama { get; set; }
        public int? IdStatusNikah { get; set; }
        public string? StatusNikah { get; set; }
        public string? GolonganDarah { get; set; }
        public string? NamaIbu { get; set; }
        public string? NamaAyah { get; set; }

        // Domisili
        public string? Alamat { get; set; }
        public string? Rt { get; set; }
        public string? Rw { get; set; }
        public string? Provinsi { get; set; }
        public string? Kabupaten { get; set; }
        public string? Kecamatan { get; set; }
        public string? Desa { get; set; }
        public string? KodePos { get; set; }

        // Step 3: Kontak Utama
        public string? Hp1 { get; set; }
        public string? Hp2 { get; set; }
        public string? EmailPribadi { get; set; }
        public string? EmailKantor { get; set; }

        // Kontak Darurat
        public string? KontakDaruratNama { get; set; }
        public string? KontakDaruratTelp { get; set; }
        public string? KontakDaruratTelpLain { get; set; }
        public string? KontakDaruratRelasi { get; set; }
        public string? KontakDaruratKeterangan { get; set; }

        // Jaminan & Pajak
        public string? NoNpwp { get; set; }
        public string? NoBpjsTk { get; set; }
        public string? NoBpjsKes { get; set; }
        public string? NoBpjsPensiun { get; set; }

        // Pendidikan
        public int? IdPendidikan { get; set; }
        public string? JenjangPendidikan { get; set; }
        public string? NamaSekolah { get; set; }
        public string? Fakultas { get; set; }
        public string? Jurusan { get; set; }
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
