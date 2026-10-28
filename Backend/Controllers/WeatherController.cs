using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;

namespace Indexsafe.Api.Controllers
{
    [ApiController]
    [Route("api/weather")]
    public class WeatherController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IMemoryCache _cache;

        private const double DefaultLat = 0.9083;
        private const double DefaultLon = 117.8542;
        private const string DefaultLoc = "Kaliorang";
        private const string DefaultSub = "Kutai Timur";

        public WeatherController(IHttpClientFactory httpClientFactory, IMemoryCache cache)
        {
            _httpClientFactory = httpClientFactory;
            _cache = cache;
        }

        [AllowAnonymous]
        [HttpGet("current")]
        public async Task<IActionResult> GetCurrentWeather([FromQuery] double? lat, [FromQuery] double? lon)
        {
            double targetLat = lat ?? DefaultLat;
            double targetLon = lon ?? DefaultLon;

            // Cache key rounded to ~2 decimals to group nearby requests
            string cacheKey = $"weather_{Math.Round(targetLat, 2)}_{Math.Round(targetLon, 2)}";

            if (_cache.TryGetValue(cacheKey, out object? cachedResult) && cachedResult != null)
            {
                return Ok(new { status = true, source = "cache", data = cachedResult });
            }

            var client = _httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(6);
            client.DefaultRequestHeaders.UserAgent.ParseAdd("IndexsafeMobile/1.0");

            string locName = DefaultLoc;
            string subName = DefaultSub;

            var inv = System.Globalization.CultureInfo.InvariantCulture;
            string latStr = targetLat.ToString(inv);
            string lonStr = targetLon.ToString(inv);

            // 1. Reverse Geocoding
            try
            {
                var geoUrl = $"https://api.bigdatacloud.net/data/reverse-geocode-client?latitude={latStr}&longitude={lonStr}&localityLanguage=id";
                var geoResp = await client.GetAsync(geoUrl);
                if (geoResp.IsSuccessStatusCode)
                {
                    using var stream = await geoResp.Content.ReadAsStreamAsync();
                    using var doc = await JsonDocument.ParseAsync(stream);
                    var root = doc.RootElement;
                    if (root.TryGetProperty("city", out var cityEl) && !string.IsNullOrWhiteSpace(cityEl.GetString()))
                    {
                        locName = cityEl.GetString()!;
                    }
                    else if (root.TryGetProperty("locality", out var locEl) && !string.IsNullOrWhiteSpace(locEl.GetString()))
                    {
                        locName = locEl.GetString()!;
                    }

                    if (root.TryGetProperty("principalSubdivision", out var subEl) && !string.IsNullOrWhiteSpace(subEl.GetString()))
                    {
                        subName = subEl.GetString()!;
                    }
                }
            }
            catch { /* fallback to default */ }

            // 2. Fetch Open-Meteo
            try
            {
                var weatherUrl = $"https://api.open-meteo.com/v1/forecast?latitude={latStr}&longitude={lonStr}&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&timezone=auto";
                var weatherResp = await client.GetAsync(weatherUrl);
                if (weatherResp.IsSuccessStatusCode)
                {
                    using var stream = await weatherResp.Content.ReadAsStreamAsync();
                    using var doc = await JsonDocument.ParseAsync(stream);
                    var current = doc.RootElement.GetProperty("current");

                    double temp = current.TryGetProperty("temperature_2m", out var tEl) ? tEl.GetDouble() : 28.0;
                    double apparent = current.TryGetProperty("apparent_temperature", out var aEl) ? aEl.GetDouble() : temp + 4.0;
                    int humidity = current.TryGetProperty("relative_humidity_2m", out var hEl) ? hEl.GetInt32() : 75;
                    double wind = current.TryGetProperty("wind_speed_10m", out var wEl) ? wEl.GetDouble() : 8.0;
                    double precip = current.TryGetProperty("precipitation", out var pEl) ? pEl.GetDouble() : 0.0;
                    int code = current.TryGetProperty("weather_code", out var cEl) ? cEl.GetInt32() : 2;
                    bool isDay = current.TryGetProperty("is_day", out var dEl) && dEl.GetInt32() == 1;

                    string condText = GetConditionText(code, isDay);
                    string safety = GetSafetyStatus(code, precip, wind, apparent);
                    string statusLevel = GetStatusLevel(code, precip, wind, apparent);

                    var data = new
                    {
                        temperature = temp,
                        apparentTemperature = apparent,
                        humidity = humidity,
                        windSpeed = wind,
                        precipitation = precip,
                        weatherCode = code,
                        isDay = isDay,
                        conditionText = condText,
                        safetyStatus = safety,
                        statusLevel = statusLevel,
                        locationName = locName,
                        subdivision = subName,
                        latitude = targetLat,
                        longitude = targetLon,
                        updatedAt = DateTime.UtcNow
                    };

                    _cache.Set(cacheKey, data, TimeSpan.FromMinutes(10));
                    return Ok(new { status = true, source = "live", data });
                }
            }
            catch (Exception)
            {
                // return fallback data
            }

            var fallbackData = new
            {
                temperature = 28.4,
                apparentTemperature = 33.0,
                humidity = 78,
                windSpeed = 8.0,
                precipitation = 0.0,
                weatherCode = 2,
                isDay = true,
                conditionText = "Cerah Berawan",
                safetyStatus = "Kondisi Aman untuk Aktivitas Lapangan",
                statusLevel = "Aman",
                locationName = locName,
                subdivision = subName,
                latitude = targetLat,
                longitude = targetLon,
                updatedAt = DateTime.UtcNow
            };

            return Ok(new { status = true, source = "fallback", data = fallbackData });
        }

        private static string GetConditionText(int code, bool isDay) => code switch
        {
            0 => isDay ? "Cerah" : "Cerah Berbintang",
            1 => isDay ? "Sebagian Cerah" : "Cerah Berawan",
            2 => "Cerah Berawan",
            3 => "Berawan Tebal",
            45 or 48 => "Berkabut",
            51 or 53 or 55 => "Gerimis",
            61 => "Hujan Ringan",
            63 => "Hujan Sedang",
            65 => "Hujan Lebat",
            80 or 81 or 82 => "Hujan Lokal",
            95 or 96 or 99 => "Badai Petir",
            _ => "Berawan"
        };

        private static string GetSafetyStatus(int code, double precip, double wind, double apparent)
        {
            if (code >= 95) return "Bahaya Petir - Hentikan Bekerja di Luar / Ketinggian";
            if (code == 65 || precip >= 10.0) return "Hujan Lebat - Waspada Jalan Tambang Licin & Longsor";
            if (code >= 61 || precip > 0.5) return "Hujan Aktif - Waspada Jalur Licin & Kurangi Kecepatan";
            if (wind >= 30.0) return "Angin Kencang - Waspada Bekerja di Ketinggian";
            if (apparent >= 36.0) return "Indeks Panas Tinggi - Pastikan Cukupi Asupan Cairan";
            return "Kondisi Aman untuk Aktivitas Lapangan";
        }

        private static string GetStatusLevel(int code, double precip, double wind, double apparent)
        {
            if (code >= 95 || code == 65) return "Bahaya";
            if (code >= 61 || wind >= 28.0 || apparent >= 36.0) return "Waspada";
            return "Aman";
        }
    }
}
