import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class WeatherData {
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;
  final bool isDay;
  final String locationName;
  final String subdivision;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherCode,
    required this.isDay,
    required this.locationName,
    required this.subdivision,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  /// Deskripsi cuaca dalam Bahasa Indonesia standar BMKG / WMO
  String get conditionText {
    switch (weatherCode) {
      case 0:
        return isDay ? 'Cerah' : 'Cerah Berbintang';
      case 1:
        return isDay ? 'Sebagian Cerah' : 'Cerah Berawan';
      case 2:
        return 'Cerah Berawan';
      case 3:
        return 'Berawan Tebal';
      case 45:
      case 48:
        return 'Berkabut';
      case 51:
      case 53:
      case 55:
        return 'Gerimis';
      case 56:
      case 57:
        return 'Gerimis Dingin';
      case 61:
        return 'Hujan Ringan';
      case 63:
        return 'Hujan Sedang';
      case 65:
        return 'Hujan Lebat';
      case 66:
      case 67:
        return 'Hujan Beku';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Salju';
      case 80:
        return 'Hujan Singkat Ringan';
      case 81:
        return 'Hujan Singkat Sedang';
      case 82:
        return 'Hujan Singkat Lebat';
      case 85:
      case 86:
        return 'Hujan Salju';
      case 95:
        return 'Badai Petir';
      case 96:
      case 99:
        return 'Badai Petir & Es';
      default:
        return 'Berawan';
    }
  }

  /// Rekomendasi keselamatan kerja lapangan untuk area tambang / proyek
  String get safetyStatus {
    if (weatherCode >= 95) {
      return 'Bahaya Petir - Hentikan Bekerja di Luar / Ketinggian';
    }
    if (weatherCode == 65 || weatherCode == 82 || precipitation >= 10.0) {
      return 'Hujan Lebat - Waspada Jalan Tambang Licin & Longsor';
    }
    if (weatherCode >= 61 || weatherCode >= 80 || precipitation > 0.5) {
      return 'Hujan Aktif - Waspada Jalur Licin & Kurangi Kecepatan';
    }
    if (windSpeed >= 30.0) {
      return 'Angin Kencang - Waspada Bekerja di Ketinggian';
    }
    if (apparentTemperature >= 36.0) {
      return 'Indeks Panas Tinggi - Pastikan Cukupi Asupan Cairan';
    }
    return 'Kondisi Aman untuk Aktivitas Lapangan';
  }

  Color get statusColor {
    if (weatherCode >= 95 || weatherCode == 65 || weatherCode == 82) {
      return const Color(0xFFEF4444); // Red
    }
    if (weatherCode >= 61 || weatherCode >= 80 || windSpeed >= 28.0 || apparentTemperature >= 36.0) {
      return const Color(0xFFF59E0B); // Amber
    }
    return const Color(0xFF10B981); // Emerald Green
  }

  IconData get iconData {
    switch (weatherCode) {
      case 0:
        return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
      case 1:
        return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
      case 2:
        return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_outlined;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.blur_on_rounded;
      case 51:
      case 53:
      case 55:
        return Icons.grain_rounded;
      case 61:
      case 63:
        return Icons.water_drop_rounded;
      case 65:
        return Icons.thunderstorm_outlined;
      case 80:
      case 81:
      case 82:
        return Icons.shower_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.flash_on_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  Color get iconColor {
    switch (weatherCode) {
      case 0:
        return isDay ? const Color(0xFFF59E0B) : const Color(0xFF818CF8);
      case 1:
      case 2:
        return isDay ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8);
      case 3:
        return const Color(0xFF64748B);
      case 45:
      case 48:
        return const Color(0xFF94A3B8);
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
        return const Color(0xFF0284C7);
      case 65:
      case 80:
      case 81:
      case 82:
        return const Color(0xFF0369A1);
      case 95:
      case 96:
      case 99:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0284C7);
    }
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'apparentTemperature': apparentTemperature,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'precipitation': precipitation,
        'weatherCode': weatherCode,
        'isDay': isDay,
        'locationName': locationName,
        'subdivision': subdivision,
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        apparentTemperature:
            (json['apparentTemperature'] as num?)?.toDouble() ?? 0.0,
        humidity: (json['humidity'] as num?)?.toInt() ?? 0,
        windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
        precipitation: (json['precipitation'] as num?)?.toDouble() ?? 0.0,
        weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
        isDay: json['isDay'] as bool? ?? true,
        locationName: json['locationName'] as String? ?? 'Site Indexim',
        subdivision: json['subdivision'] as String? ?? 'Kutai Timur',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.9083,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 117.8542,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class WeatherService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  // Site PT Indexim Coalindo default location (Kaliorang, Kutai Timur)
  static const double defaultLat = 0.9083;
  static const double defaultLon = 117.8542;
  static const String defaultLocation = 'Kaliorang';
  static const String defaultSubdivision = 'Kutai Timur';

  static WeatherData? _cachedWeather;

  static WeatherData? get cachedWeather => _cachedWeather;

  /// Load cached weather from memory or SharedPreferences
  static Future<WeatherData?> loadCachedWeather() async {
    if (_cachedWeather != null) return _cachedWeather;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_weather_v1');
      if (raw != null && raw.isNotEmpty) {
        _cachedWeather = WeatherData.fromJson(jsonDecode(raw));
        return _cachedWeather;
      }
    } catch (_) {}
    return null;
  }

  /// Get actual real-time weather at current user location or fallback to site
  static Future<WeatherData> fetchCurrentWeather({bool forceRefresh = false}) async {
    // Return cache if fresh (< 10 minutes) and not forceRefresh
    if (!forceRefresh && _cachedWeather != null) {
      final diff = DateTime.now().difference(_cachedWeather!.updatedAt);
      if (diff.inMinutes < 10) {
        return _cachedWeather!;
      }
    }

    double lat = defaultLat;
    double lon = defaultLon;
    String locName = defaultLocation;
    String subName = defaultSubdivision;

    // 1. Dapatkan koordinat GPS aktual perangkat
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          Position? pos = await Geolocator.getLastKnownPosition();
          pos ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 4),
          );
          lat = pos.latitude;
          lon = pos.longitude;
        }
      }
    } catch (_) {
      // Fallback tetap ke defaultLat & defaultLon
    }

    // 1. Coba ambil dari Backend Mobile Indexsafe terlebih dahulu
    try {
      final backendUrl = ApiService.activeBaseUrl;
      final res = await _dio.get(
        '$backendUrl/api/weather/current',
        queryParameters: {
          'lat': lat,
          'lon': lon,
        },
      );
      if (res.statusCode == 200 && res.data is Map && res.data['data'] is Map) {
        final d = Map<String, dynamic>.from(res.data['data']);
        final weather = WeatherData.fromJson(d);
        _cachedWeather = weather;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'cached_weather_v1', jsonEncode(weather.toJson()));
        } catch (_) {}
        return weather;
      }
    } catch (_) {
      // Jika backend tidak merespons, lanjutkan ke direct query
    }

    // 2. Reverse geocode untuk mendapatkan nama kota / area aktual
    try {
      final geoRes = await _dio.get(
        'https://api.bigdatacloud.net/data/reverse-geocode-client',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'localityLanguage': 'id',
        },
      );
      if (geoRes.statusCode == 200 && geoRes.data is Map) {
        final data = geoRes.data as Map;
        final city = (data['city'] ?? data['locality'] ?? '').toString().trim();
        final district = (data['locality'] ?? '').toString().trim();
        final prov = (data['principalSubdivision'] ?? '').toString().trim();

        if (city.isNotEmpty) {
          locName = city;
        } else if (district.isNotEmpty) {
          locName = district;
        }

        if (prov.isNotEmpty) {
          subName = prov;
        }
      }
    } catch (_) {
      // Jika geocode gagal atau offline, gunakan nama default
    }

    // 3. Ambil data cuaca dari Open-Meteo
    try {
      final weatherRes = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m',
          'timezone': 'auto',
        },
      );

      if (weatherRes.statusCode == 200 && weatherRes.data is Map) {
        final current = weatherRes.data['current'] as Map?;
        if (current != null) {
          final weather = WeatherData(
            temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 28.0,
            apparentTemperature:
                (current['apparentTemperature'] as num?)?.toDouble() ??
                    (current['apparent_temperature'] as num?)?.toDouble() ??
                    29.0,
            humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 75,
            windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 5.0,
            precipitation: (current['precipitation'] as num?)?.toDouble() ?? 0.0,
            weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
            isDay: (current['is_day'] as num?)?.toInt() == 1,
            locationName: locName,
            subdivision: subName,
            latitude: lat,
            longitude: lon,
            updatedAt: DateTime.now(),
          );

          _cachedWeather = weather;

          // Simpan ke SharedPreferences
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
                'cached_weather_v1', jsonEncode(weather.toJson()));
          } catch (_) {}

          return weather;
        }
      }
    } catch (e) {
      // Jika request gagal tapi ada cache lama, gunakan cache lama
      if (_cachedWeather != null) {
        return _cachedWeather!;
      }
    }

    // Fallback data jika offline dan belum pernah ada cache
    final fallback = WeatherData(
      temperature: 28.4,
      apparentTemperature: 33.0,
      humidity: 78,
      windSpeed: 8.0,
      precipitation: 0.0,
      weatherCode: 2,
      isDay: true,
      locationName: locName,
      subdivision: subName,
      latitude: lat,
      longitude: lon,
      updatedAt: DateTime.now(),
    );
    _cachedWeather = fallback;
    return fallback;
  }
}
