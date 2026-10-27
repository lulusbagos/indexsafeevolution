using System;
using System.Collections.Generic;
using System.Data;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace Indexsafe.Api.Services
{
    public class PermitSimperDto
    {
        [JsonPropertyName("has_permit")]
        public bool HasPermit { get; set; }

        [JsonPropertyName("permit_id")]
        public long? PermitId { get; set; }

        [JsonPropertyName("permit_nomor")]
        public string? PermitNomor { get; set; }

        [JsonPropertyName("masa_aktif_permit")]
        public string? MasaAktifPermit { get; set; }

        [JsonPropertyName("permit_status")]
        public string? PermitStatus { get; set; }

        [JsonPropertyName("permit_pengajuan")]
        public string? PermitPengajuan { get; set; }

        [JsonPropertyName("akses_lokasi")]
        public string? AksesLokasi { get; set; }

        [JsonPropertyName("mulai_kerja")]
        public string? MulaiKerja { get; set; }

        [JsonPropertyName("berakhir_kerja")]
        public string? BerakhirKerja { get; set; }

        [JsonPropertyName("last_expired")]
        public string? LastExpired { get; set; }

        [JsonPropertyName("is_permit_printed")]
        public bool IsPermitPrinted { get; set; }

        [JsonPropertyName("raw_permit_status")]
        public string? RawPermitStatus { get; set; }

        [JsonPropertyName("is_permit_active")]
        public bool IsPermitActive { get; set; }

        // SIMPER
        [JsonPropertyName("has_simper")]
        public bool HasSimper { get; set; }

        [JsonPropertyName("simper_id")]
        public long? SimperId { get; set; }

        [JsonPropertyName("simper_nomor")]
        public string? SimperNomor { get; set; }

        [JsonPropertyName("simper_status")]
        public string? SimperStatus { get; set; }

        [JsonPropertyName("is_simper_printed")]
        public bool IsSimperPrinted { get; set; }

        [JsonPropertyName("raw_simper_status")]
        public string? RawSimperStatus { get; set; }

        [JsonPropertyName("jenis_simper")]
        public string? JenisSimper { get; set; }

        [JsonPropertyName("jenis_sim")]
        public string? JenisSim { get; set; }

        [JsonPropertyName("nomor_sim")]
        public string? NomorSim { get; set; }

        [JsonPropertyName("simper_expired_date")]
        public string? SimperExpiredDate { get; set; }

        [JsonPropertyName("masa_berlaku")]
        public string? MasaBerlaku { get; set; }

        [JsonPropertyName("masa_berlaku_sio")]
        public string? MasaBerlakuSio { get; set; }

        [JsonPropertyName("kacamata")]
        public string? Kacamata { get; set; }

        [JsonPropertyName("is_simper_active")]
        public bool IsSimperActive { get; set; }

        [JsonPropertyName("units")]
        public List<SimperUnitDto> Units { get; set; } = new();

        [JsonPropertyName("simper_days_left")]
        public int SimperDaysLeft { get; set; }

        [JsonPropertyName("simper_is_expired")]
        public bool IsSimperExpired { get; set; }

        [JsonPropertyName("card_photo_path")]
        public string? CardPhotoPath { get; set; }

        [JsonPropertyName("card_photo_scan_path")]
        public string? CardPhotoScanPath { get; set; }

        [JsonPropertyName("permit_doc_photo_path")]
        public string? PermitDocPhotoPath { get; set; }

        [JsonPropertyName("error_message")]
        public string? ErrorMessage { get; set; }
    }

    public class PermitService
    {
        private readonly ILogger<PermitService> _logger;
        private readonly string[] _candidateHosts = new[] { "172.16.1.96", "172.16.1.93" };
        private readonly string[] _candidateDbs = new[] { "bima", "BIMA", "db_bima", "sysinteg_bima", "minepermit", "db_permit", "sysinteg_indexsafe2", "postgres" };
        private const string User = "postgres";
        private const string Pass = "index.123";

        public PermitService(ILogger<PermitService> logger)
        {
            _logger = logger;
        }

        public async Task<PermitSimperDto> GetLatestPermitSimperAsync(string nik)
        {
            var result = new PermitSimperDto();
            if (string.IsNullOrWhiteSpace(nik)) return result;

            NpgsqlConnection? activeConn = null;
            string? connectedHost = null;
            string? connectedDb = null;

            // 1. Try candidate hosts & databases
            foreach (var host in _candidateHosts)
            {
                var dbsToTry = new List<string> { "Bima", "BimaTest", "sysinteg_indexsafe2", "postgres" };
                try
                {
                    var discStr = $"Host={host};Port=5432;Database=sysinteg_indexsafe2;Username={User};Password={Pass};Timeout=3;";
                    await using var discConn = new NpgsqlConnection(discStr);
                    await discConn.OpenAsync();
                    await using var cmd = new NpgsqlCommand("SELECT datname FROM pg_database WHERE datistemplate = false;", discConn);
                    await using var rdr = await cmd.ExecuteReaderAsync();
                    while (await rdr.ReadAsync())
                    {
                        var name = rdr.GetString(0);
                        if (!dbsToTry.Contains(name, StringComparer.OrdinalIgnoreCase))
                        {
                            dbsToTry.Add(name);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("[PermitService] Discovery on {Host} failed: {Msg}", host, ex.Message);
                }

                foreach (var db in dbsToTry)
                {
                    try
                    {
                        var builder = new NpgsqlConnectionStringBuilder
                        {
                            Host = host,
                            Port = 5432,
                            Database = db,
                            Username = User,
                            Password = Pass,
                            Timeout = 3,
                            CommandTimeout = 5
                        };
                        var conn = new NpgsqlConnection(builder.ConnectionString);
                        await conn.OpenAsync();

                        // Check if tb_permit exists in this db using text cast
                        await using (var checkCmd = new NpgsqlCommand("SELECT to_regclass('public.tb_permit')::text;", conn))
                        {
                            var reg = await checkCmd.ExecuteScalarAsync();
                            if (reg != null && reg != DBNull.Value && !string.IsNullOrWhiteSpace(reg.ToString()))
                            {
                                activeConn = conn;
                                connectedHost = host;
                                connectedDb = db;
                                _logger.LogInformation("[PermitService] Successfully connected to tb_permit in database {Db} on {Host}!", db, host);
                                break;
                            }
                        }
                        await conn.DisposeAsync();
                    }
                    catch (Exception ex)
                    {
                        if (db.Contains("bima", StringComparison.OrdinalIgnoreCase))
                        {
                            _logger.LogWarning("[PermitService] Failed checking {Db} on {Host}: {Msg}", db, host, ex.Message);
                        }
                    }
                }

                if (activeConn != null) break;
            }

            if (activeConn == null)
            {
                result.ErrorMessage = "Tidak dapat terhubung ke database PostgreSQL BIMA (172.16.1.93 / 172.16.1.96).";
                return result;
            }

            var nikClean = nik.Trim();
            var nikNoZero = nikClean.TrimStart('0');

            await using (activeConn)
            {
                try
                {
                    // 1. Ambil data TERBARU dari public.tb_permit berdasarkan NIK (ORDER BY created_at DESC NULLS LAST, id DESC)
                    const string sqlPermit = @"
                        SELECT id, nomor, status, pengajuan, (tanggal + INTERVAL '1 year')::date AS masa_aktif_permit, akses_lokasi, mulai_kerja, berakhir_kerja, last_expired, tercetak, waktu_tercetak, created_at, updated_at
                        FROM public.tb_permit
                        WHERE TRIM(nik) = @nikClean 
                           OR TRIM(employee_id) = @nikClean
                           OR TRIM(nomor) = @nikClean
                           OR (@nikNoZero <> '' AND (TRIM(nik) = @nikNoZero OR TRIM(employee_id) = @nikNoZero OR TRIM(nomor) = @nikNoZero))
                        ORDER BY created_at DESC NULLS LAST, id DESC
                        LIMIT 1;";

                    long? permitId = null;
                    DateTime? permitBerakhir = null;
                    DateTime? permitLastExpired = null;

                    await using (var cmd = new NpgsqlCommand(sqlPermit, activeConn))
                    {
                        cmd.Parameters.AddWithValue("@nikClean", nikClean);
                        cmd.Parameters.AddWithValue("@nikNoZero", nikNoZero);
                        await using var reader = await cmd.ExecuteReaderAsync();
                        if (await reader.ReadAsync())
                        {
                            result.HasPermit = true;
                            permitId = reader.GetInt64(reader.GetOrdinal("id"));
                            result.PermitId = permitId;
                            result.PermitNomor = reader.IsDBNull(reader.GetOrdinal("nomor")) ? null : reader.GetString(reader.GetOrdinal("nomor"));
                            result.PermitPengajuan = reader.IsDBNull(reader.GetOrdinal("pengajuan")) ? null : reader.GetString(reader.GetOrdinal("pengajuan"));
                            result.AksesLokasi = reader.IsDBNull(reader.GetOrdinal("akses_lokasi")) ? null : reader.GetString(reader.GetOrdinal("akses_lokasi"));

                            if (!reader.IsDBNull(reader.GetOrdinal("masa_aktif_permit")))
                            {
                                var mapVal = reader.GetValue(reader.GetOrdinal("masa_aktif_permit"));
                                if (mapVal is DateTime dt)
                                {
                                    result.MasaAktifPermit = dt.ToString("yyyy-MM-dd");
                                }
                                else if (mapVal is DateOnly dOnly)
                                {
                                    result.MasaAktifPermit = dOnly.ToString("yyyy-MM-dd");
                                }
                                else if (mapVal != null)
                                {
                                    result.MasaAktifPermit = mapVal.ToString();
                                }
                            }

                            if (!reader.IsDBNull(reader.GetOrdinal("mulai_kerja")))
                            {
                                result.MulaiKerja = reader.GetValue(reader.GetOrdinal("mulai_kerja"))?.ToString();
                            }

                            if (!reader.IsDBNull(reader.GetOrdinal("berakhir_kerja")))
                            {
                                var val = reader.GetValue(reader.GetOrdinal("berakhir_kerja"));
                                result.BerakhirKerja = val?.ToString();
                                permitBerakhir = ParseDateFlexible(val);
                            }

                            if (!reader.IsDBNull(reader.GetOrdinal("last_expired")))
                            {
                                var val = reader.GetValue(reader.GetOrdinal("last_expired"));
                                result.LastExpired = val?.ToString();
                                permitLastExpired = ParseDateFlexible(val);
                            }

                            // Logika Status: Jika tercetak > 0 atau waktu_tercetak ada atau status PRINTED -> PRINTED
                            string rawPermitStatus = reader.IsDBNull(reader.GetOrdinal("status")) ? "" : reader.GetValue(reader.GetOrdinal("status"))?.ToString()?.Trim() ?? "";
                            bool hasTercetak = false;
                            try
                            {
                                if (!reader.IsDBNull(reader.GetOrdinal("tercetak")))
                                {
                                    hasTercetak = Convert.ToInt32(reader.GetValue(reader.GetOrdinal("tercetak"))) > 0;
                                }
                            }
                            catch { }
                            try
                            {
                                if (!hasTercetak && !reader.IsDBNull(reader.GetOrdinal("waktu_tercetak")))
                                {
                                    hasTercetak = true;
                                }
                            }
                            catch { }

                            bool isPermitPrinted = rawPermitStatus.Equals("PRINTED", StringComparison.OrdinalIgnoreCase)
                                                || rawPermitStatus.Equals("PRINT", StringComparison.OrdinalIgnoreCase)
                                                || rawPermitStatus.Contains("PRINT", StringComparison.OrdinalIgnoreCase)
                                                || hasTercetak;

                            result.IsPermitPrinted = isPermitPrinted;
                            result.RawPermitStatus = rawPermitStatus;
                            result.PermitStatus = isPermitPrinted ? "PRINTED" : "PROSES PENGAJUAN";

                            var maxPermitDate = permitBerakhir ?? permitLastExpired;
                            if (permitLastExpired.HasValue && permitBerakhir.HasValue)
                            {
                                maxPermitDate = permitBerakhir.Value > permitLastExpired.Value ? permitBerakhir : permitLastExpired;
                            }

                            // Pastikan BerakhirKerja membawa tanggal aktif terbaru (misal: 2027-08-18)
                            if (maxPermitDate.HasValue)
                            {
                                result.BerakhirKerja = maxPermitDate.Value.ToString("yyyy-MM-dd");
                            }

                            result.IsPermitActive = isPermitPrinted && (maxPermitDate == null || maxPermitDate.Value.Date >= DateTime.Today);
                        }
                    }

                    // 2. Ambil data TERBARU dari public.tb_simper berdasarkan permit_id atau NIK (ORDER BY id DESC)
                    const string sqlSimper = @"
                        SELECT id, permit_id, nomor, status, jenis_simper, jenis_sim, nomor_sim, expired_date, masa_berlaku, masa_berlaku_sio, kacamata, printed_at, printed_count, created_at, updated_at
                        FROM public.tb_simper
                        WHERE (employee_id IS NOT NULL AND (TRIM(employee_id) = @nikClean OR (@nikNoZero <> '' AND TRIM(employee_id) = @nikNoZero)))
                           OR (@permitId IS NOT NULL AND permit_id = @permitId)
                        ORDER BY id DESC
                        LIMIT 1;";

                    await using (var cmdSimper = new NpgsqlCommand(sqlSimper, activeConn))
                    {
                        cmdSimper.Parameters.AddWithValue("@nikClean", nikClean);
                        cmdSimper.Parameters.AddWithValue("@nikNoZero", nikNoZero);
                        cmdSimper.Parameters.AddWithValue("@permitId", (object?)permitId ?? DBNull.Value);

                        await using var reader = await cmdSimper.ExecuteReaderAsync();
                        if (await reader.ReadAsync())
                        {
                            result.HasSimper = true;
                            result.SimperId = reader.GetInt64(reader.GetOrdinal("id"));
                            result.SimperNomor = reader.IsDBNull(reader.GetOrdinal("nomor")) ? null : reader.GetString(reader.GetOrdinal("nomor"));
                            result.JenisSimper = reader.IsDBNull(reader.GetOrdinal("jenis_simper")) ? null : reader.GetString(reader.GetOrdinal("jenis_simper"));
                            result.JenisSim = reader.IsDBNull(reader.GetOrdinal("jenis_sim")) ? null : reader.GetString(reader.GetOrdinal("jenis_sim"));
                            result.NomorSim = reader.IsDBNull(reader.GetOrdinal("nomor_sim")) ? null : reader.GetString(reader.GetOrdinal("nomor_sim"));

                            if (!reader.IsDBNull(reader.GetOrdinal("kacamata")))
                            {
                                var kVal = reader.GetValue(reader.GetOrdinal("kacamata"));
                                result.Kacamata = kVal is bool b ? (b ? "YA" : "TIDAK") : kVal.ToString();
                            }

                            DateTime? simperExp = null;
                            if (!reader.IsDBNull(reader.GetOrdinal("expired_date")))
                            {
                                var val = reader.GetValue(reader.GetOrdinal("expired_date"));
                                result.SimperExpiredDate = val?.ToString();
                                simperExp = ParseDateFlexible(val);
                            }

                            DateTime? simperMasaBerlaku = null;
                            if (!reader.IsDBNull(reader.GetOrdinal("masa_berlaku")))
                            {
                                var val = reader.GetValue(reader.GetOrdinal("masa_berlaku"));
                                result.MasaBerlaku = val?.ToString();
                                simperMasaBerlaku = ParseDateFlexible(val);
                            }

                            if (!reader.IsDBNull(reader.GetOrdinal("masa_berlaku_sio")))
                            {
                                result.MasaBerlakuSio = reader.GetValue(reader.GetOrdinal("masa_berlaku_sio"))?.ToString();
                            }

                            // Logika Status SIMPER: Jika printed_count > 0 atau printed_at ada atau status PRINTED -> PRINTED
                            string rawSimperStatus = reader.IsDBNull(reader.GetOrdinal("status")) ? "" : reader.GetValue(reader.GetOrdinal("status"))?.ToString()?.Trim() ?? "";
                            bool hasPrinted = false;
                            try
                            {
                                if (!reader.IsDBNull(reader.GetOrdinal("printed_count")))
                                {
                                    hasPrinted = Convert.ToInt32(reader.GetValue(reader.GetOrdinal("printed_count"))) > 0;
                                }
                            }
                            catch { }
                            try
                            {
                                if (!hasPrinted && !reader.IsDBNull(reader.GetOrdinal("printed_at")))
                                {
                                    hasPrinted = true;
                                }
                            }
                            catch { }

                            bool isSimperPrinted = rawSimperStatus.Equals("PRINTED", StringComparison.OrdinalIgnoreCase)
                                                || rawSimperStatus.Equals("PRINT", StringComparison.OrdinalIgnoreCase)
                                                || rawSimperStatus.Contains("PRINT", StringComparison.OrdinalIgnoreCase)
                                                || hasPrinted;

                            result.IsSimperPrinted = isSimperPrinted;
                            result.RawSimperStatus = rawSimperStatus;
                            result.SimperStatus = isSimperPrinted ? "PRINTED" : "PROSES PENGAJUAN";

                            // Jika permit sudah diperpanjang ke masa berlaku baru, sinkronkan expired_date SIMPER ke permit baru
                            var maxPermitDateVal = permitBerakhir ?? permitLastExpired;
                            if (permitLastExpired.HasValue && permitBerakhir.HasValue)
                            {
                                maxPermitDateVal = permitBerakhir.Value > permitLastExpired.Value ? permitBerakhir : permitLastExpired;
                            }

                            if (maxPermitDateVal.HasValue && (!simperExp.HasValue || simperExp.Value < maxPermitDateVal.Value))
                            {
                                simperExp = maxPermitDateVal.Value;
                                result.SimperExpiredDate = maxPermitDateVal.Value.ToString("yyyy-MM-dd");
                            }

                            var maxSimperDate = simperMasaBerlaku ?? simperExp;
                            if (simperExp.HasValue && simperMasaBerlaku.HasValue)
                            {
                                maxSimperDate = simperMasaBerlaku.Value > simperExp.Value ? simperMasaBerlaku : simperExp;
                            }

                            result.IsSimperActive = isSimperPrinted && (maxSimperDate == null || maxSimperDate.Value.Date >= DateTime.Today);
                            if (maxSimperDate.HasValue)
                            {
                                result.SimperDaysLeft = (maxSimperDate.Value.Date - DateTime.Today).Days;
                                result.IsSimperExpired = maxSimperDate.Value.Date < DateTime.Today;
                            }
                            else
                            {
                                result.SimperDaysLeft = 999;
                                result.IsSimperExpired = false;
                            }
                        }
                    }

                    // Query tb_simper_unit
                    if (result.SimperId.HasValue)
                    {
                        try
                        {
                            const string sqlUnits = @"
                                SELECT id, simper_id, kendaraan, kewenangan, jam_min, jam_aktual, equipment_classification, equipment_type, equipment_model
                                FROM public.tb_simper_unit
                                WHERE simper_id = @sId
                                ORDER BY id ASC;";
                            await using var cmdUnits = new NpgsqlCommand(sqlUnits, activeConn);
                            cmdUnits.Parameters.AddWithValue("@sId", result.SimperId.Value);
                            await using var uReader = await cmdUnits.ExecuteReaderAsync();
                            while (await uReader.ReadAsync())
                            {
                                result.Units.Add(new SimperUnitDto
                                {
                                    Id = uReader.GetInt64(0),
                                    SimperId = uReader.GetInt64(1),
                                    Kendaraan = uReader.IsDBNull(2) ? null : uReader.GetString(2),
                                    Kewenangan = uReader.IsDBNull(3) ? null : uReader.GetString(3),
                                    JamMin = uReader.IsDBNull(4) ? null : Convert.ToInt32(uReader.GetValue(4)),
                                    JamAktual = uReader.IsDBNull(5) ? null : Convert.ToInt32(uReader.GetValue(5)),
                                    EquipmentClassification = uReader.IsDBNull(6) ? null : uReader.GetString(6),
                                    EquipmentType = uReader.IsDBNull(7) ? null : uReader.GetString(7),
                                    EquipmentModel = uReader.IsDBNull(8) ? null : uReader.GetString(8),
                                });
                            }
                        }
                        catch (Exception exUnits)
                        {
                            _logger.LogWarning("[PermitService] Query tb_simper_unit in GetLatestPermitSimperAsync failed: {Msg}", exUnits.Message);
                        }
                    }

                    // 3. Ambil data FOTO RESMI Mine Permit dari public.employee_card (Indexsafemission)
                    try
                    {
                        const string sqlCard = @"
                            SELECT id_card_photo, id_card_photo_scan, simper_card_photo
                            FROM public.employee_card
                            WHERE (nik IS NOT NULL AND (TRIM(nik) = @nikClean OR (@nikNoZero <> '' AND TRIM(nik) = @nikNoZero)))
                            ORDER BY id DESC
                            LIMIT 1;";
                        await using (var cmdCard = new NpgsqlCommand(sqlCard, activeConn))
                        {
                            cmdCard.Parameters.AddWithValue("@nikClean", nikClean);
                            cmdCard.Parameters.AddWithValue("@nikNoZero", nikNoZero);
                            await using var cardReader = await cmdCard.ExecuteReaderAsync();
                            if (await cardReader.ReadAsync())
                            {
                                result.CardPhotoPath = cardReader.IsDBNull(0) ? null : cardReader.GetString(0);
                                result.CardPhotoScanPath = cardReader.IsDBNull(1) ? null : cardReader.GetString(1);
                                _logger.LogInformation("[PermitService] employee_card found for {Nik}: id_card_photo={P1}, scan={P2}", nik, result.CardPhotoPath, result.CardPhotoScanPath);
                            }
                        }
                    }
                    catch (Exception exCard)
                    {
                        _logger.LogWarning("[PermitService] Query employee_card failed: {Msg}", exCard.Message);
                    }

                    // 4. Jika belum ada di employee_card, cari lampiran FOTO dari public.tb_permit_doc
                    if (string.IsNullOrEmpty(result.CardPhotoPath) && permitId.HasValue)
                    {
                        try
                        {
                            const string sqlDoc = @"
                                SELECT file_path, file_name, document_name
                                FROM public.tb_permit_doc
                                WHERE permit_id = @permitId
                                  AND (document_name ILIKE '%FOTO%' OR document_name ILIKE '%PHOTO%')
                                ORDER BY id DESC
                                LIMIT 1;";
                            await using (var cmdDoc = new NpgsqlCommand(sqlDoc, activeConn))
                            {
                                cmdDoc.Parameters.AddWithValue("@permitId", permitId.Value);
                                await using var docReader = await cmdDoc.ExecuteReaderAsync();
                                if (await docReader.ReadAsync())
                                {
                                    result.PermitDocPhotoPath = docReader.IsDBNull(0) ? (docReader.IsDBNull(1) ? null : docReader.GetString(1)) : docReader.GetString(0);
                                    _logger.LogInformation("[PermitService] tb_permit_doc found for {Nik}: path={Path}", nik, result.PermitDocPhotoPath);
                                }
                            }
                        }
                        catch (Exception exDoc)
                        {
                            _logger.LogWarning("[PermitService] Query tb_permit_doc failed: {Msg}", exDoc.Message);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "[PermitService] Error querying tb_permit or tb_simper for NIK {Nik}", nik);
                    result.ErrorMessage = ex.Message;
                }
            }

            return result;
        }

        private static DateTime? ParseDateFlexible(object? val)
        {
            if (val == null || val == DBNull.Value) return null;
            if (val is DateTime dt) return dt;
            if (val is DateOnly dOnly) return dOnly.ToDateTime(TimeOnly.MinValue);
            var str = val.ToString()?.Trim();
            if (string.IsNullOrEmpty(str)) return null;

            string[] formats = { "dd/MM/yyyy", "dd/MM/yyyy HH:mm:ss", "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-ddTHH:mm:ss" };
            if (DateTime.TryParseExact(str, formats, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out var exactDt))
            {
                return exactDt;
            }
            if (DateTime.TryParse(str, out var parsedDt))
            {
                return parsedDt;
            }
            return null;
        }

        public async Task<PermitFullDetailDto?> GetFullPermitDetailAsync(string nik)
        {
            if (string.IsNullOrWhiteSpace(nik)) return null;

            var nikClean = nik.Trim();
            var nikNoZero = nikClean.TrimStart('0');

            NpgsqlConnection? activeConn = null;
            foreach (var host in _candidateHosts)
            {
                var dbsToTry = new List<string> { "Bima", "BimaTest", "sysinteg_indexsafe2", "postgres" };
                foreach (var db in dbsToTry)
                {
                    try
                    {
                        var builder = new NpgsqlConnectionStringBuilder
                        {
                            Host = host,
                            Port = 5432,
                            Database = db,
                            Username = User,
                            Password = Pass,
                            Timeout = 3,
                            CommandTimeout = 5
                        };
                        var conn = new NpgsqlConnection(builder.ConnectionString);
                        await conn.OpenAsync();

                        await using (var checkCmd = new NpgsqlCommand("SELECT to_regclass('public.tb_permit')::text;", conn))
                        {
                            var reg = await checkCmd.ExecuteScalarAsync();
                            if (reg != null && reg != DBNull.Value && !string.IsNullOrWhiteSpace(reg.ToString()))
                            {
                                activeConn = conn;
                                break;
                            }
                        }
                        await conn.DisposeAsync();
                    }
                    catch { }
                }
                if (activeConn != null) break;
            }

            if (activeConn == null) return null;

            await using (activeConn)
            {
                try
                {
                    const string sql = @"
                        SELECT DISTINCT ON (nik)
                            nik,
                            tanggal,
                            (tanggal + INTERVAL '1 year')::date AS masa_aktif_permit,
                            nomor,
                            akses_lokasi, perusahaan, nama, email, departemen, jabatan, posisi,
                            status,
                            pengajuan,
                            berakhir_kerja
                        FROM public.tb_permit
                        WHERE (TRIM(nik) = @nikClean 
                            OR TRIM(employee_id) = @nikClean 
                            OR TRIM(nomor) = @nikClean
                            OR (@nikNoZero <> '' AND (TRIM(nik) = @nikNoZero OR TRIM(employee_id) = @nikNoZero OR TRIM(nomor) = @nikNoZero)))
                        ORDER BY nik, created_at DESC NULLS LAST, id DESC
                        LIMIT 1;";

                    await using var cmd = new NpgsqlCommand(sql, activeConn);
                    cmd.Parameters.AddWithValue("@nikClean", nikClean);
                    cmd.Parameters.AddWithValue("@nikNoZero", nikNoZero);

                    await using var r = await cmd.ExecuteReaderAsync();
                    if (await r.ReadAsync())
                    {
                        var dto = new PermitFullDetailDto
                        {
                            Nik = r.IsDBNull(r.GetOrdinal("nik")) ? nikClean : r.GetString(r.GetOrdinal("nik")),
                            Nama = r.IsDBNull(r.GetOrdinal("nama")) ? null : r.GetString(r.GetOrdinal("nama")),
                            Nomor = r.IsDBNull(r.GetOrdinal("nomor")) ? null : r.GetString(r.GetOrdinal("nomor")),
                            AksesLokasi = r.IsDBNull(r.GetOrdinal("akses_lokasi")) ? null : r.GetString(r.GetOrdinal("akses_lokasi")),
                            Perusahaan = r.IsDBNull(r.GetOrdinal("perusahaan")) ? null : r.GetString(r.GetOrdinal("perusahaan")),
                            Email = r.IsDBNull(r.GetOrdinal("email")) ? null : r.GetString(r.GetOrdinal("email")),
                            Departemen = r.IsDBNull(r.GetOrdinal("departemen")) ? null : r.GetString(r.GetOrdinal("departemen")),
                            Jabatan = r.IsDBNull(r.GetOrdinal("jabatan")) ? null : r.GetString(r.GetOrdinal("jabatan")),
                            Posisi = r.IsDBNull(r.GetOrdinal("posisi")) ? null : r.GetString(r.GetOrdinal("posisi")),
                            Status = r.IsDBNull(r.GetOrdinal("status")) ? null : r.GetString(r.GetOrdinal("status")),
                            Pengajuan = r.IsDBNull(r.GetOrdinal("pengajuan")) ? null : r.GetString(r.GetOrdinal("pengajuan"))
                        };

                        if (!r.IsDBNull(r.GetOrdinal("tanggal")))
                        {
                            var tVal = r.GetValue(r.GetOrdinal("tanggal"));
                            var dt = ParseDateFlexible(tVal);
                            dto.Tanggal = dt?.ToString("yyyy-MM-dd") ?? tVal.ToString();
                        }

                        if (!r.IsDBNull(r.GetOrdinal("berakhir_kerja")))
                        {
                            var bVal = r.GetValue(r.GetOrdinal("berakhir_kerja"));
                            var dt = ParseDateFlexible(bVal);
                            dto.BerakhirKerja = dt?.ToString("yyyy-MM-dd") ?? bVal.ToString();
                        }

                        if (!r.IsDBNull(r.GetOrdinal("masa_aktif_permit")))
                        {
                            var mapVal = r.GetValue(r.GetOrdinal("masa_aktif_permit"));
                            var expDt = ParseDateFlexible(mapVal);
                            if (expDt.HasValue)
                            {
                                dto.MasaAktifPermit = expDt.Value.ToString("yyyy-MM-dd");
                                dto.DaysLeft = (expDt.Value.Date - DateTime.Today).Days;
                                dto.IsExpired = DateTime.Today > expDt.Value.Date;
                            }
                            else
                            {
                                dto.MasaAktifPermit = mapVal?.ToString();
                            }
                        }

                        return dto;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "[PermitService] Error querying GetFullPermitDetailAsync: {Msg}", ex.Message);
                }
            }

            return null;
        }

        public async Task<SimperFullDetailDto?> GetFullSimperDetailAsync(string queryCode)
        {
            if (string.IsNullOrWhiteSpace(queryCode)) return null;

            var cleanCode = queryCode.Trim();

            NpgsqlConnection? activeConn = null;
            foreach (var host in _candidateHosts)
            {
                var dbsToTry = new List<string> { "Bima", "BimaTest", "sysinteg_indexsafe2", "postgres" };
                foreach (var db in dbsToTry)
                {
                    try
                    {
                        var builder = new NpgsqlConnectionStringBuilder
                        {
                            Host = host,
                            Port = 5432,
                            Database = db,
                            Username = User,
                            Password = Pass,
                            Timeout = 3,
                            CommandTimeout = 5
                        };
                        var conn = new NpgsqlConnection(builder.ConnectionString);
                        await conn.OpenAsync();

                        await using (var checkCmd = new NpgsqlCommand("SELECT to_regclass('public.tb_simper')::text;", conn))
                        {
                            var reg = await checkCmd.ExecuteScalarAsync();
                            if (reg != null && reg != DBNull.Value && !string.IsNullOrWhiteSpace(reg.ToString()))
                            {
                                activeConn = conn;
                                break;
                            }
                        }
                        await conn.DisposeAsync();
                    }
                    catch { }
                }
                if (activeConn != null) break;
            }

            if (activeConn == null) return null;

            await using (activeConn)
            {
                try
                {
                    const string sqlSimper = @"
                        SELECT id, permit_id, req_id, tanggal, nomor, status, nomor_sim, masa_berlaku, masa_berlaku_sio, kacamata, nilai_praktek, nilai_teori, employee_id, jenis_simper, ref_id, company_id, departemen, created_by, updated_by, deleted_by, created_at, updated_at, deleted_at, ketentuan_hauling, tes_simper, praktek_simper, qr_encrypt, qr_decrypt, expired_date, created_company_id, created_department_id, printed_at, printed_count, jenis_sim
                        FROM public.tb_simper
                        WHERE TRIM(qr_encrypt) = @code
                           OR TRIM(qr_decrypt) = @code
                           OR TRIM(nomor) = @code
                           OR TRIM(req_id::text) = @code
                           OR TRIM(employee_id) = @code
                        ORDER BY id DESC
                        LIMIT 1;";

                    SimperFullDetailDto? dto = null;
                    await using (var cmd = new NpgsqlCommand(sqlSimper, activeConn))
                    {
                        cmd.Parameters.AddWithValue("@code", cleanCode);
                        await using var r = await cmd.ExecuteReaderAsync();
                        if (await r.ReadAsync())
                        {
                            dto = new SimperFullDetailDto
                            {
                                Id = r.GetInt64(r.GetOrdinal("id")),
                                PermitId = r.IsDBNull(r.GetOrdinal("permit_id")) ? null : r.GetInt64(r.GetOrdinal("permit_id")),
                                ReqId = r.IsDBNull(r.GetOrdinal("req_id")) ? null : r.GetValue(r.GetOrdinal("req_id"))?.ToString(),
                                Nomor = r.IsDBNull(r.GetOrdinal("nomor")) ? null : r.GetString(r.GetOrdinal("nomor")),
                                Status = r.IsDBNull(r.GetOrdinal("status")) ? null : r.GetString(r.GetOrdinal("status")),
                                NomorSim = r.IsDBNull(r.GetOrdinal("nomor_sim")) ? null : r.GetString(r.GetOrdinal("nomor_sim")),
                                JenisSim = r.IsDBNull(r.GetOrdinal("jenis_sim")) ? null : r.GetString(r.GetOrdinal("jenis_sim")),
                                EmployeeId = r.IsDBNull(r.GetOrdinal("employee_id")) ? cleanCode : r.GetString(r.GetOrdinal("employee_id")),
                                JenisSimper = r.IsDBNull(r.GetOrdinal("jenis_simper")) ? null : r.GetString(r.GetOrdinal("jenis_simper")),
                                Departemen = r.IsDBNull(r.GetOrdinal("departemen")) ? null : r.GetString(r.GetOrdinal("departemen")),
                                QrEncrypt = r.IsDBNull(r.GetOrdinal("qr_encrypt")) ? null : r.GetString(r.GetOrdinal("qr_encrypt")),
                                QrDecrypt = r.IsDBNull(r.GetOrdinal("qr_decrypt")) ? null : r.GetString(r.GetOrdinal("qr_decrypt")),
                            };

                            if (!r.IsDBNull(r.GetOrdinal("kacamata")))
                            {
                                var kVal = r.GetValue(r.GetOrdinal("kacamata"));
                                dto.Kacamata = kVal is bool b ? (b ? "WAJIB KACAMATA" : "TIDAK") : kVal.ToString();
                            }

                            if (!r.IsDBNull(r.GetOrdinal("ketentuan_hauling")))
                            {
                                var hVal = r.GetValue(r.GetOrdinal("ketentuan_hauling"));
                                dto.KetentuanHauling = hVal is bool b ? b : false;
                            }

                            if (!r.IsDBNull(r.GetOrdinal("nilai_teori")))
                            {
                                dto.NilaiTeori = Convert.ToDouble(r.GetValue(r.GetOrdinal("nilai_teori")));
                            }

                            if (!r.IsDBNull(r.GetOrdinal("nilai_praktek")))
                            {
                                dto.NilaiPraktek = Convert.ToDouble(r.GetValue(r.GetOrdinal("nilai_praktek")));
                            }

                            if (!r.IsDBNull(r.GetOrdinal("printed_count")))
                            {
                                dto.PrintedCount = Convert.ToInt32(r.GetValue(r.GetOrdinal("printed_count")));
                            }

                            if (!r.IsDBNull(r.GetOrdinal("printed_at")))
                            {
                                dto.PrintedAt = r.GetValue(r.GetOrdinal("printed_at"))?.ToString();
                            }

                            DateTime? dtTanggal = ParseDateFlexible(r.GetValue(r.GetOrdinal("tanggal")));
                            if (dtTanggal.HasValue) dto.Tanggal = dtTanggal.Value.ToString("yyyy-MM-dd");

                            DateTime? dtMasaBerlaku = ParseDateFlexible(r.GetValue(r.GetOrdinal("masa_berlaku")));
                            if (dtMasaBerlaku.HasValue) dto.MasaBerlaku = dtMasaBerlaku.Value.ToString("yyyy-MM-dd");

                            DateTime? dtExpired = ParseDateFlexible(r.GetValue(r.GetOrdinal("expired_date")));
                            if (dtExpired.HasValue) dto.ExpiredDate = dtExpired.Value.ToString("yyyy-MM-dd");

                            DateTime? effectiveExpiry = dtMasaBerlaku ?? dtExpired;
                            if (effectiveExpiry.HasValue)
                            {
                                dto.DaysLeft = (effectiveExpiry.Value.Date - DateTime.Today).Days;
                                dto.IsExpired = DateTime.Today > effectiveExpiry.Value.Date;
                            }

                            string rawStatus = dto.Status?.Trim() ?? "";
                            bool isPrinted = rawStatus.Contains("PRINT", StringComparison.OrdinalIgnoreCase) || dto.PrintedCount > 0 || !string.IsNullOrEmpty(dto.PrintedAt);
                            dto.IsSimperActive = isPrinted && (!effectiveExpiry.HasValue || effectiveExpiry.Value.Date >= DateTime.Today);
                        }
                    }

                    if (dto != null)
                    {
                        // Fetch units from tb_simper_unit
                        const string sqlUnits = @"
                            SELECT id, simper_id, kendaraan, kewenangan, jam_min, jam_aktual, equipment_classification, equipment_type, equipment_model
                            FROM public.tb_simper_unit
                            WHERE simper_id = @sId
                            ORDER BY id ASC;";
                        await using (var cmdUnits = new NpgsqlCommand(sqlUnits, activeConn))
                        {
                            cmdUnits.Parameters.AddWithValue("@sId", dto.Id);
                            await using var uReader = await cmdUnits.ExecuteReaderAsync();
                            while (await uReader.ReadAsync())
                            {
                                dto.Units.Add(new SimperUnitDto
                                {
                                    Id = uReader.GetInt64(0),
                                    SimperId = uReader.GetInt64(1),
                                    Kendaraan = uReader.IsDBNull(2) ? null : uReader.GetString(2),
                                    Kewenangan = uReader.IsDBNull(3) ? null : uReader.GetString(3),
                                    JamMin = uReader.IsDBNull(4) ? null : Convert.ToInt32(uReader.GetValue(4)),
                                    JamAktual = uReader.IsDBNull(5) ? null : Convert.ToInt32(uReader.GetValue(5)),
                                    EquipmentClassification = uReader.IsDBNull(6) ? null : uReader.GetString(6),
                                    EquipmentType = uReader.IsDBNull(7) ? null : uReader.GetString(7),
                                    EquipmentModel = uReader.IsDBNull(8) ? null : uReader.GetString(8),
                                });
                            }
                        }

                        return dto;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "[PermitService] Error in GetFullSimperDetailAsync: {Msg}", ex.Message);
                }
            }

            return null;
        }
    }

    public class SimperUnitDto
    {
        [JsonPropertyName("id")]
        public long Id { get; set; }

        [JsonPropertyName("simper_id")]
        public long SimperId { get; set; }

        [JsonPropertyName("kendaraan")]
        public string? Kendaraan { get; set; }

        [JsonPropertyName("kewenangan")]
        public string? Kewenangan { get; set; }

        [JsonPropertyName("jam_min")]
        public int? JamMin { get; set; }

        [JsonPropertyName("jam_aktual")]
        public int? JamAktual { get; set; }

        [JsonPropertyName("equipment_classification")]
        public string? EquipmentClassification { get; set; }

        [JsonPropertyName("equipment_type")]
        public string? EquipmentType { get; set; }

        [JsonPropertyName("equipment_model")]
        public string? EquipmentModel { get; set; }
    }

    public class SimperFullDetailDto
    {
        [JsonPropertyName("id")]
        public long Id { get; set; }

        [JsonPropertyName("permit_id")]
        public long? PermitId { get; set; }

        [JsonPropertyName("req_id")]
        public string? ReqId { get; set; }

        [JsonPropertyName("tanggal")]
        public string? Tanggal { get; set; }

        [JsonPropertyName("nomor")]
        public string? Nomor { get; set; }

        [JsonPropertyName("status")]
        public string? Status { get; set; }

        [JsonPropertyName("nomor_sim")]
        public string? NomorSim { get; set; }

        [JsonPropertyName("jenis_sim")]
        public string? JenisSim { get; set; }

        [JsonPropertyName("masa_berlaku")]
        public string? MasaBerlaku { get; set; }

        [JsonPropertyName("masa_berlaku_sio")]
        public string? MasaBerlakuSio { get; set; }

        [JsonPropertyName("expired_date")]
        public string? ExpiredDate { get; set; }

        [JsonPropertyName("kacamata")]
        public string? Kacamata { get; set; }

        [JsonPropertyName("nilai_praktek")]
        public double? NilaiPraktek { get; set; }

        [JsonPropertyName("nilai_teori")]
        public double? NilaiTeori { get; set; }

        [JsonPropertyName("employee_id")]
        public string EmployeeId { get; set; } = string.Empty;

        [JsonPropertyName("jenis_simper")]
        public string? JenisSimper { get; set; }

        [JsonPropertyName("company_id")]
        public int? CompanyId { get; set; }

        [JsonPropertyName("departemen")]
        public string? Departemen { get; set; }

        [JsonPropertyName("ketentuan_hauling")]
        public bool? KetentuanHauling { get; set; }

        [JsonPropertyName("qr_encrypt")]
        public string? QrEncrypt { get; set; }

        [JsonPropertyName("qr_decrypt")]
        public string? QrDecrypt { get; set; }

        [JsonPropertyName("printed_at")]
        public string? PrintedAt { get; set; }

        [JsonPropertyName("printed_count")]
        public int PrintedCount { get; set; }

        [JsonPropertyName("is_simper_active")]
        public bool IsSimperActive { get; set; }

        [JsonPropertyName("days_left")]
        public int DaysLeft { get; set; }

        [JsonPropertyName("is_expired")]
        public bool IsExpired { get; set; }

        [JsonPropertyName("nama")]
        public string? Nama { get; set; }

        [JsonPropertyName("nik")]
        public string? Nik { get; set; }

        [JsonPropertyName("perusahaan")]
        public string? Perusahaan { get; set; }

        [JsonPropertyName("jabatan")]
        public string? Jabatan { get; set; }

        [JsonPropertyName("posisi")]
        public string? Posisi { get; set; }

        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("no_hp")]
        public string? NoHp { get; set; }

        [JsonPropertyName("jenis_kelamin")]
        public string? JenisKelamin { get; set; }

        [JsonPropertyName("foto")]
        public string? Foto { get; set; }

        [JsonPropertyName("photo_url")]
        public string? PhotoUrl { get; set; }

        [JsonPropertyName("units")]
        public List<SimperUnitDto> Units { get; set; } = new();

        [JsonPropertyName("can_input_pelanggaran")]
        public bool CanInputPelanggaran { get; set; }

        [JsonPropertyName("can_input_keluar_masuk")]
        public bool CanInputKeluarMasuk { get; set; }
    }

    public class PermitFullDetailDto
    {
        [JsonPropertyName("nik")]
        public string Nik { get; set; } = string.Empty;

        [JsonPropertyName("nama")]
        public string? Nama { get; set; }

        [JsonPropertyName("nomor")]
        public string? Nomor { get; set; }

        [JsonPropertyName("tanggal")]
        public string? Tanggal { get; set; }

        [JsonPropertyName("masa_aktif_permit")]
        public string? MasaAktifPermit { get; set; }

        [JsonPropertyName("days_left")]
        public int DaysLeft { get; set; }

        [JsonPropertyName("is_expired")]
        public bool IsExpired { get; set; }

        [JsonPropertyName("status")]
        public string? Status { get; set; }

        [JsonPropertyName("pengajuan")]
        public string? Pengajuan { get; set; }

        [JsonPropertyName("berakhir_kerja")]
        public string? BerakhirKerja { get; set; }

        [JsonPropertyName("perusahaan")]
        public string? Perusahaan { get; set; }

        [JsonPropertyName("departemen")]
        public string? Departemen { get; set; }

        [JsonPropertyName("jabatan")]
        public string? Jabatan { get; set; }

        [JsonPropertyName("posisi")]
        public string? Posisi { get; set; }

        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("akses_lokasi")]
        public string? AksesLokasi { get; set; }

        [JsonPropertyName("can_input_pelanggaran")]
        public bool CanInputPelanggaran { get; set; }
    }
}
