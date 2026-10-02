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

            await using (activeConn)
            {
                try
                {
                    // 1. Ambil data terakhir dari public.tb_permit berdasarkan NIK
                    const string sqlPermit = @"
                        SELECT id, nomor, status, pengajuan, akses_lokasi, mulai_kerja, berakhir_kerja, last_expired, created_at, updated_at
                        FROM public.tb_permit
                        WHERE nik = @nik OR employee_id = @nik
                        ORDER BY COALESCE(updated_at, created_at, tanggal) DESC, id DESC
                        LIMIT 1;";

                    long? permitId = null;
                    DateTime? permitBerakhir = null;
                    DateTime? permitLastExpired = null;

                    await using (var cmd = new NpgsqlCommand(sqlPermit, activeConn))
                    {
                        cmd.Parameters.AddWithValue("@nik", nik);
                        await using var reader = await cmd.ExecuteReaderAsync();
                        if (await reader.ReadAsync())
                        {
                            result.HasPermit = true;
                            permitId = reader.GetInt64(reader.GetOrdinal("id"));
                            result.PermitId = permitId;
                            result.PermitNomor = reader.IsDBNull(reader.GetOrdinal("nomor")) ? null : reader.GetString(reader.GetOrdinal("nomor"));
                            result.PermitStatus = reader.IsDBNull(reader.GetOrdinal("status")) ? null : reader.GetString(reader.GetOrdinal("status"));
                            result.PermitPengajuan = reader.IsDBNull(reader.GetOrdinal("pengajuan")) ? null : reader.GetString(reader.GetOrdinal("pengajuan"));
                            result.AksesLokasi = reader.IsDBNull(reader.GetOrdinal("akses_lokasi")) ? null : reader.GetString(reader.GetOrdinal("akses_lokasi"));

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

                            // Cek masa aktif permit
                            bool isPermitPrintedOrActive = string.Equals(result.PermitStatus, "PRINTED", StringComparison.OrdinalIgnoreCase)
                                                        || string.Equals(result.PermitStatus, "ACTIVE", StringComparison.OrdinalIgnoreCase)
                                                        || string.Equals(result.PermitStatus, "DISETUJUI", StringComparison.OrdinalIgnoreCase)
                                                        || string.Equals(result.PermitStatus, "APPROVED", StringComparison.OrdinalIgnoreCase);

                            var maxPermitDate = permitBerakhir ?? permitLastExpired;
                            if (permitLastExpired.HasValue && permitBerakhir.HasValue)
                            {
                                maxPermitDate = permitLastExpired.Value > permitBerakhir.Value ? permitLastExpired : permitBerakhir;
                            }

                            result.IsPermitActive = isPermitPrintedOrActive || (maxPermitDate.HasValue && maxPermitDate.Value.Date >= DateTime.Today);
                        }
                    }

                    // 2. Ambil data terakhir dari public.tb_simper berdasarkan permit_id atau employee_id
                    const string sqlSimper = @"
                        SELECT id, permit_id, nomor, status, jenis_simper, jenis_sim, nomor_sim, expired_date, masa_berlaku, masa_berlaku_sio, kacamata, created_at, updated_at
                        FROM public.tb_simper
                        WHERE (@permitId IS NOT NULL AND permit_id = @permitId) OR employee_id = @nik
                        ORDER BY COALESCE(updated_at, created_at, tanggal) DESC, id DESC
                        LIMIT 1;";

                    await using (var cmdSimper = new NpgsqlCommand(sqlSimper, activeConn))
                    {
                        cmdSimper.Parameters.AddWithValue("@permitId", (object?)permitId ?? DBNull.Value);
                        cmdSimper.Parameters.AddWithValue("@nik", nik);

                        await using var reader = await cmdSimper.ExecuteReaderAsync();
                        if (await reader.ReadAsync())
                        {
                            result.HasSimper = true;
                            result.SimperId = reader.GetInt64(reader.GetOrdinal("id"));
                            result.SimperNomor = reader.IsDBNull(reader.GetOrdinal("nomor")) ? null : reader.GetString(reader.GetOrdinal("nomor"));
                            result.SimperStatus = reader.IsDBNull(reader.GetOrdinal("status")) ? null : reader.GetString(reader.GetOrdinal("status"));
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

                            var maxSimperDate = simperMasaBerlaku ?? simperExp;
                            if (simperExp.HasValue && simperMasaBerlaku.HasValue)
                            {
                                maxSimperDate = simperMasaBerlaku.Value > simperExp.Value ? simperMasaBerlaku : simperExp;
                            }

                            bool isSimperPrintedOrActive = string.Equals(result.SimperStatus, "PRINTED", StringComparison.OrdinalIgnoreCase)
                                                        || string.Equals(result.SimperStatus, "ACTIVE", StringComparison.OrdinalIgnoreCase)
                                                        || string.Equals(result.SimperStatus, "APPROVED", StringComparison.OrdinalIgnoreCase)
                                                        || string.Equals(result.SimperStatus, "DISETUJUI", StringComparison.OrdinalIgnoreCase);

                            // Jika status WAITING, belum aktif
                            bool isWaiting = string.Equals(result.SimperStatus, "WAITING", StringComparison.OrdinalIgnoreCase)
                                          || string.Equals(result.SimperStatus, "PENDING", StringComparison.OrdinalIgnoreCase);

                            result.IsSimperActive = !isWaiting && (isSimperPrintedOrActive || (maxSimperDate.HasValue && maxSimperDate.Value.Date >= DateTime.Today));
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
    }
}
