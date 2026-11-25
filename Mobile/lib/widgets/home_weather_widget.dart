import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';

class HomeWeatherWidget extends StatefulWidget {
  const HomeWeatherWidget({super.key});

  @override
  State<HomeWeatherWidget> createState() => _HomeWeatherWidgetState();
}

class _HomeWeatherWidgetState extends State<HomeWeatherWidget> {
  WeatherData? _weather;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh) {
      // Load cache first if available
      final cached = await WeatherService.loadCachedWeather();
      if (cached != null && mounted) {
        setState(() {
          _weather = cached;
          _isLoading = false;
        });
      }
    }

    try {
      final fresh =
          await WeatherService.fetchCurrentWeather(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _weather = fresh;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDetailBottomSheet(BuildContext context, WeatherData weather) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WeatherDetailSheet(
        weather: weather,
        onRefresh: () async {
          Navigator.pop(ctx);
          await _loadWeather(forceRefresh: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _weather == null) {
      return _buildSkeletonLoader();
    }

    final weather = _weather ??
        WeatherData(
          temperature: 28.0,
          apparentTemperature: 32.0,
          humidity: 75,
          windSpeed: 6.0,
          precipitation: 0.0,
          weatherCode: 1,
          isDay: true,
          locationName: 'Site Indexim',
          subdivision: 'Kutai Timur',
          latitude: 0.9083,
          longitude: 117.8542,
          updatedAt: DateTime.now(),
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showDetailBottomSheet(context, weather),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                weather.iconData,
                color: weather.iconColor,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${weather.temperature.toStringAsFixed(0)}°C',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '•',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 70),
                child: Text(
                  weather.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: weather.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      width: 95,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

enum WeatherThemeType {
  thunderstorm, // Badai Petir
  heavyRain,    // Hujan Lebat
  rain,         // Hujan / Gerimis
  hotSunny,     // Panas Terik
  sunny,        // Cerah Siang
  night,        // Malam Hari (Cerah)
  cloudyNight,  // Malam Hari Berawan / Mendung
  cloudy,       // Berawan / Mendung Siang
}

class _WeatherDetailSheet extends StatefulWidget {
  final WeatherData weather;
  final VoidCallback onRefresh;

  const _WeatherDetailSheet({
    required this.weather,
    required this.onRefresh,
  });

  @override
  State<_WeatherDetailSheet> createState() => _WeatherDetailSheetState();
}

class _WeatherDetailSheetState extends State<_WeatherDetailSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    // Animasi aktif hanya saat pop up / sheet terbuka
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    // Controller otomatis di-dispose saat sheet ditutup, nol konsumsi background CPU
    _animCtrl.dispose();
    super.dispose();
  }

  WeatherThemeType _getThemeType(WeatherData w) {
    if (w.weatherCode >= 95) return WeatherThemeType.thunderstorm;
    if (w.weatherCode == 65 || w.weatherCode == 82 || w.precipitation >= 8.0) {
      return WeatherThemeType.heavyRain;
    }
    if (w.weatherCode >= 51 || w.precipitation > 0.3) {
      return WeatherThemeType.rain;
    }
    if (!w.isDay) {
      if (w.weatherCode >= 2) return WeatherThemeType.cloudyNight;
      return WeatherThemeType.night;
    }
    if (w.apparentTemperature >= 35.0 ||
        (w.weatherCode <= 1 && w.temperature >= 32.0)) {
      return WeatherThemeType.hotSunny;
    }
    if (w.weatherCode <= 1) return WeatherThemeType.sunny;
    return WeatherThemeType.cloudy;
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.weather;
    final timeStr = DateFormat('HH:mm').format(weather.updatedAt);
    final themeType = _getThemeType(weather);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header: Lokasi & Status Pembaruan
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              weather.locationName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFBFDBFE), width: 0.8),
                            ),
                            child: Text(
                              weather.subdivision.isNotEmpty
                                  ? weather.subdivision
                                  : 'Kaltim',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diperbarui pukul $timeStr WITA',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onRefresh();
                  },
                  tooltip: 'Perbarui Cuaca',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ANIMATED WEATHER CARD HERO
            _buildAnimatedWeatherHero(weather, themeType, timeStr),

            const SizedBox(height: 16),

            // Parameter Grid (Kelembapan, Angin, Curah Hujan, Waktu Hari)
            Row(
              children: [
                Expanded(
                  child: _buildParameterTile(
                    icon: Icons.water_drop_rounded,
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFE0F2FE),
                    label: 'Kelembapan',
                    value: '${weather.humidity}%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildParameterTile(
                    icon: Icons.air_rounded,
                    iconColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFD1FAE5),
                    label: 'Kecepatan Angin',
                    value: '${weather.windSpeed.toStringAsFixed(0)} km/j',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildParameterTile(
                    icon: Icons.umbrella_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFEDE9FE),
                    label: 'Curah Hujan',
                    value: '${weather.precipitation.toStringAsFixed(1)} mm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildParameterTile(
                    icon: weather.isDay
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    iconColor: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFEDD5),
                    label: 'Waktu Hari',
                    value: weather.isDay ? 'Siang Hari' : 'Malam Hari',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Field Safety Guidance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: weather.statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: weather.statusColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: weather.statusColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      size: 20,
                      color: weather.statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panduan Keselamatan Operasional',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: weather.statusColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          weather.safetyStatus,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Button Close
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWeatherHero(
    WeatherData weather,
    WeatherThemeType themeType,
    String timeStr,
  ) {
    List<Color> gradientColors;
    Color borderColor;
    Color accentBadgeBg;

    switch (themeType) {
      case WeatherThemeType.thunderstorm:
        gradientColors = const [
          Color(0xFF0F172A),
          Color(0xFF1E1B4B),
          Color(0xFF3B0764),
        ];
        borderColor = const Color(0xFFC084FC).withValues(alpha: 0.5);
        accentBadgeBg = const Color(0xFF7E22CE).withValues(alpha: 0.4);
        break;
      case WeatherThemeType.heavyRain:
        gradientColors = const [
          Color(0xFF082F49),
          Color(0xFF0C4A6E),
          Color(0xFF0369A1),
        ];
        borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.5);
        accentBadgeBg = const Color(0xFF0284C7).withValues(alpha: 0.4);
        break;
      case WeatherThemeType.rain:
        gradientColors = const [
          Color(0xFF0F3B66),
          Color(0xFF1E5B8E),
          Color(0xFF2563EB),
        ];
        borderColor = const Color(0xFF60A5FA).withValues(alpha: 0.4);
        accentBadgeBg = const Color(0xFF1D4ED8).withValues(alpha: 0.4);
        break;
      case WeatherThemeType.hotSunny:
        gradientColors = const [
          Color(0xFF9A3412),
          Color(0xFFC2410C),
          Color(0xFFEA580C),
        ];
        borderColor = const Color(0xFFFDBA74).withValues(alpha: 0.5);
        accentBadgeBg = const Color(0xFFC2410C).withValues(alpha: 0.4);
        break;
      case WeatherThemeType.sunny:
        gradientColors = const [
          Color(0xFF0369A1),
          Color(0xFF0284C7),
          Color(0xFF38BDF8),
        ];
        borderColor = const Color(0xFFBAE6FD).withValues(alpha: 0.4);
        accentBadgeBg = const Color(0xFF0369A1).withValues(alpha: 0.35);
        break;
      case WeatherThemeType.cloudyNight:
        gradientColors = const [
          Color(0xFF0A0F24),
          Color(0xFF141D3B),
          Color(0xFF1E2B52),
        ];
        borderColor = const Color(0xFF60A5FA).withValues(alpha: 0.45);
        accentBadgeBg = const Color(0xFF1E293B).withValues(alpha: 0.55);
        break;
      case WeatherThemeType.night:
        gradientColors = const [
          Color(0xFF030712),
          Color(0xFF0C1329),
          Color(0xFF1E1B4B),
        ];
        borderColor = const Color(0xFF818CF8).withValues(alpha: 0.45);
        accentBadgeBg = const Color(0xFF312E81).withValues(alpha: 0.5);
        break;
      case WeatherThemeType.cloudy:
        gradientColors = const [
          Color(0xFF1E293B),
          Color(0xFF334155),
          Color(0xFF475569),
        ];
        borderColor = const Color(0xFF94A3B8).withValues(alpha: 0.45);
        accentBadgeBg = const Color(0xFF334155).withValues(alpha: 0.45);
        break;
    }

    return Container(
      width: double.infinity,
      height: 205,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.38),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Dynamic Animated Weather Canvas (Awan Volumetrik, Bulan/Matahari, Bintang, dsb.)
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(double.infinity, 205),
                painter: _WeatherAtmospherePainter(
                  progress: _animCtrl.value,
                  themeType: themeType,
                ),
              );
            },
          ),

          // 2. Subtle Glassmorphic Sheen Reflection
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: const Alignment(0.8, 1.2),
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.04),
                    ],
                    stops: const [0.0, 0.25, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Content overlay
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: High-tech Live Badge + Day/Night Capsule
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentBadgeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _animCtrl,
                            builder: (context, _) {
                              final pulse = (math.sin(_animCtrl.value * 2 * math.pi) + 1) / 2;
                              return Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34D399)
                                      .withValues(alpha: 0.6 + 0.4 * pulse),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF34D399)
                                          .withValues(alpha: 0.5 + 0.5 * pulse),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 7),
                          Icon(weather.iconData, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          const Text(
                            'CUACA SAAT INI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Day/Night indicator pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            weather.isDay
                                ? Icons.wb_sunny_rounded
                                : Icons.nightlight_round,
                            size: 13,
                            color: weather.isDay
                                ? const Color(0xFFFDE047)
                                : const Color(0xFFA5B4FC),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            weather.isDay ? 'Siang' : 'Malam',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Bottom Content: Kondisi Cuaca & Suhu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weather.conditionText,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Color(0x77000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Terasa seperti ${weather.apparentTemperature.toStringAsFixed(0)}°C  •  ${weather.isDay ? 'Siang' : 'Malam'}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.92),
                              shadows: const [
                                Shadow(
                                  color: Color(0x55000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update $timeStr WITA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Big Temperature display
                    Text(
                      '${weather.temperature.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        fontSize: 66,
                        height: 0.95,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -4,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x45000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7.5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter untuk menghasilkan efek atmosferik cuaca hidup kelas dunia:
/// - Malam Berawan: Awan volumetrik berlapis 3D melayang di depan & belakang bulan, bintang berkedip, bintang jatuh
/// - Malam Cerah: Langit berbintang berkedip lembut, meteor/bintang jatuh, bulan purnama bercahaya
/// - Berawan Siang: Awan kumulus volumetrik realistis, berkas sinar matahari (God rays) menembus celah awan
/// - Cerah Siang: Matahari bersinar dengan corona berdenyut, sunburst berputar, partikel cahaya berkilau
/// - Panas Terik: Pancaran solar flare ganda berputar, partikel hangat melayang, gelombang fatamorgana panas
/// - Hujan / Hujan Lebat: Tetesan air miring berkecepatan dinamis, riak splash pantulan, kabut halus
/// - Badai Petir: Awan badai gelap bergulung, hujan lebat, kilatan petir cabang organik bercahaya terang
class _WeatherAtmospherePainter extends CustomPainter {
  final double progress;
  final WeatherThemeType themeType;

  // Precomputed fixed seed particles (zero garbage collection inside paint loop)
  static final List<_ParticleData> _rainDrops = List.generate(46, (i) {
    final rand = math.Random(i * 37 + 11);
    return _ParticleData(
      xRatio: rand.nextDouble(),
      yOffset: rand.nextDouble(),
      speed: 1.2 + rand.nextDouble() * 1.5,
      length: 12.0 + rand.nextDouble() * 20.0,
      opacity: 0.3 + rand.nextDouble() * 0.55,
    );
  });

  static final List<_StarData> _stars = List.generate(42, (i) {
    final rand = math.Random(i * 43 + 7);
    return _StarData(
      xRatio: rand.nextDouble(),
      yRatio: rand.nextDouble() * 0.72,
      radius: 0.9 + rand.nextDouble() * 1.8,
      speed: 2.0 + rand.nextDouble() * 3.0,
      phaseOffset: rand.nextDouble() * 2 * math.pi,
    );
  });

  static final List<_SparkleData> _sparkles = List.generate(24, (i) {
    final rand = math.Random(i * 59 + 17);
    return _SparkleData(
      xRatio: rand.nextDouble(),
      yOffset: rand.nextDouble(),
      size: 1.5 + rand.nextDouble() * 2.8,
      speed: 0.3 + rand.nextDouble() * 0.5,
      phase: rand.nextDouble() * 2 * math.pi,
    );
  });

  _WeatherAtmospherePainter({
    required this.progress,
    required this.themeType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (themeType) {
      case WeatherThemeType.thunderstorm:
        _paintThunderstorm(canvas, w, h);
        break;
      case WeatherThemeType.heavyRain:
        _paintRain(canvas, w, h, isHeavy: true);
        break;
      case WeatherThemeType.rain:
        _paintRain(canvas, w, h, isHeavy: false);
        break;
      case WeatherThemeType.hotSunny:
        _paintHotSunny(canvas, w, h);
        break;
      case WeatherThemeType.sunny:
        _paintSunny(canvas, w, h);
        break;
      case WeatherThemeType.cloudyNight:
        _paintCloudyNight(canvas, w, h);
        break;
      case WeatherThemeType.night:
        _paintNight(canvas, w, h);
        break;
      case WeatherThemeType.cloudy:
        _paintCloudy(canvas, w, h);
        break;
    }
  }

  // ==========================================
  // 1. MALAM BERAWAN (Cloudy Night) - KONDISI POPULER
  // ==========================================
  void _paintCloudyNight(Canvas canvas, double w, double h) {
    // 1. Langit berbintang di latar belakang
    _paintStarfield(canvas, w, h, maxAlpha: 0.85);

    // 2. Bintang jatuh (shooting star) periodik
    _paintShootingStar(canvas, w, h);

    // 3. Lapisan Awan Belakang (drifting lambat di belakang bulan)
    final backCloudSpeed = progress * 0.12;
    final backCloudX = (backCloudSpeed * w + 40) % (w + 180) - 90;
    _drawCloudCluster(
      canvas,
      position: Offset(backCloudX, h * 0.08),
      scale: 1.35,
      opacity: 0.55,
      isNight: true,
      isFront: false,
    );

    // 4. Bulan Bercahaya Realistis
    final moonCenter = Offset(w * 0.80, h * 0.28);
    _paintMoon(canvas, moonCenter, 32.0, progress);

    // 5. Lapisan Awan Depan Utama (drifting anggun melewati depan bulan)
    final frontCloudSpeed = progress * 0.24;
    final frontCloudX = (frontCloudSpeed * w + 110) % (w + 220) - 110;
    _drawCloudCluster(
      canvas,
      position: Offset(frontCloudX, h * 0.22),
      scale: 1.25,
      opacity: 0.72,
      isNight: true,
      isFront: true,
    );

    // 6. Lapisan Awan Depan Kedua (bagian bawah kiri)
    final frontCloud2Speed = progress * 0.32;
    final frontCloud2X = (frontCloud2Speed * w) % (w + 190) - 95;
    _drawCloudCluster(
      canvas,
      position: Offset(frontCloud2X, h * 0.45),
      scale: 1.05,
      opacity: 0.60,
      isNight: true,
      isFront: true,
    );
  }

  // ==========================================
  // 2. MALAM HARI CERAH (Clear Night)
  // ==========================================
  void _paintNight(Canvas canvas, double w, double h) {
    // 1. Langit berbintang padat berkedip
    _paintStarfield(canvas, w, h, maxAlpha: 1.0);

    // 2. Bintang jatuh dramatis
    _paintShootingStar(canvas, w, h);

    // 3. Bulan purnama bercahaya megah dengan halo ganda
    final moonCenter = Offset(w * 0.80, h * 0.28);
    _paintMoon(canvas, moonCenter, 35.0, progress, isFullHalo: true);

    // 4. Awan tipis semi-transparan mengambang lembut di kejauhan
    final cloudX = (progress * 0.10 * w) % (w + 180) - 90;
    _drawCloudCluster(
      canvas,
      position: Offset(cloudX, h * 0.50),
      scale: 1.1,
      opacity: 0.28,
      isNight: true,
      isFront: false,
    );
  }

  // ==========================================
  // 3. BERAWAN SIANG (Cloudy Day)
  // ==========================================
  void _paintCloudy(Canvas canvas, double w, double h) {
    final sunCenter = Offset(w * 0.82, h * 0.26);

    // 1. Matahari lembut mengintip di latar belakang
    _paintSun(canvas, sunCenter, 28.0, progress, isHot: false);

    // 2. Berkas sinar matahari tembus awan (God rays)
    final rayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final rayAngle = 0.55 + i * 0.24 + math.sin(progress * 2 * math.pi + i) * 0.04;
      final rayPath = Path()
        ..moveTo(sunCenter.dx, sunCenter.dy)
        ..lineTo(sunCenter.dx + math.cos(rayAngle - 0.08) * 220, sunCenter.dy + math.sin(rayAngle - 0.08) * 220)
        ..lineTo(sunCenter.dx + math.cos(rayAngle + 0.08) * 220, sunCenter.dy + math.sin(rayAngle + 0.08) * 220)
        ..close();
      canvas.drawPath(rayPath, rayPaint);
    }

    // 3. Lapisan Awan Belakang
    final backX = (progress * 0.14 * w + 60) % (w + 200) - 100;
    _drawCloudCluster(
      canvas,
      position: Offset(backX, h * 0.10),
      scale: 1.4,
      opacity: 0.65,
      isNight: false,
      isFront: false,
    );

    // 4. Lapisan Awan Depan Utama
    final frontX = (progress * 0.26 * w + 120) % (w + 240) - 120;
    _drawCloudCluster(
      canvas,
      position: Offset(frontX, h * 0.26),
      scale: 1.3,
      opacity: 0.88,
      isNight: false,
      isFront: true,
    );

    // 5. Lapisan Awan Depan Kedua
    final front2X = (progress * 0.35 * w) % (w + 210) - 105;
    _drawCloudCluster(
      canvas,
      position: Offset(front2X, h * 0.48),
      scale: 1.15,
      opacity: 0.75,
      isNight: false,
      isFront: true,
    );
  }

  // ==========================================
  // 4. CERAH SIANG (Sunny)
  // ==========================================
  void _paintSunny(Canvas canvas, double w, double h) {
    final sunCenter = Offset(w * 0.82, h * 0.26);

    // 1. Matahari bersinar megah dengan rotasi sinar
    _paintSun(canvas, sunCenter, 32.0, progress, isHot: false, hasRays: true);

    // 2. Partikel cahaya berkilau (sparkles) melayang lembut
    _paintSparkles(canvas, w, h, const Color(0xFFFEF08A));

    // 3. Awan tipis halus di kejauhan
    final cloudX = (progress * 0.15 * w) % (w + 180) - 90;
    _drawCloudCluster(
      canvas,
      position: Offset(cloudX, h * 0.52),
      scale: 0.95,
      opacity: 0.32,
      isNight: false,
      isFront: false,
    );
  }

  // ==========================================
  // 5. PANAS TERIK (Hot Sunny)
  // ==========================================
  void _paintHotSunny(Canvas canvas, double w, double h) {
    final sunCenter = Offset(w * 0.82, h * 0.24);

    // 1. Matahari panas terik dengan rotasi ganda & solar flare
    _paintSun(canvas, sunCenter, 35.0, progress, isHot: true, hasRays: true);

    // 2. Partikel panas hangat melayang
    _paintSparkles(canvas, w, h, const Color(0xFFFDBA74));

    // 3. Efek gelombang panas / fatamorgana di bagian bawah kartu
    _paintHeatRipples(canvas, w, h);
  }

  // ==========================================
  // 6. HUJAN & HUJAN LEBAT (Rain)
  // ==========================================
  void _paintRain(Canvas canvas, double w, double h, {required bool isHeavy}) {
    // 1. Awan mendung bergulung di atas
    final cloudX = (progress * 0.08 * w) % (w + 200) - 100;
    _drawCloudCluster(
      canvas,
      position: Offset(cloudX, -h * 0.05),
      scale: 1.5,
      opacity: isHeavy ? 0.90 : 0.75,
      isNight: true,
      isFront: false,
    );

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Garis tetesan hujan jatuh miring dinamis
    const slantX = -12.0;
    for (final drop in _rainDrops) {
      final yProgress = (drop.yOffset + progress * drop.speed) % 1.0;
      final startY = yProgress * (h + drop.length) - drop.length;
      final startX = drop.xRatio * w + (1.0 - yProgress) * 24;

      paint.color = Colors.white.withValues(
        alpha: (drop.opacity * (isHeavy ? 0.92 : 0.68)).clamp(0.0, 1.0),
      );
      paint.strokeWidth = isHeavy ? 1.8 : 1.2;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + slantX, startY + drop.length * (isHeavy ? 1.4 : 1.0)),
        paint,
      );

      // Splash ripple halus saat tetesan mendekati bagian bawah kartu
      if (yProgress > 0.86) {
        final rippleProgress = (yProgress - 0.86) / 0.14;
        final ripplePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(
            alpha: (0.45 * (1.0 - rippleProgress)).clamp(0.0, 1.0),
          );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(startX + slantX, h - 8),
            width: 16 * rippleProgress,
            height: 5 * rippleProgress,
          ),
          ripplePaint,
        );
      }
    }

    // Kabut halus di permukaan bawah
    final mistPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.white.withValues(alpha: isHeavy ? 0.18 : 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, h - 40, w, 40));
    canvas.drawRect(Rect.fromLTWH(0, h - 40, w, 40), mistPaint);
  }

  // ==========================================
  // 7. BADAI PETIR (Thunderstorm)
  // ==========================================
  void _paintThunderstorm(Canvas canvas, double w, double h) {
    // 1. Gambar hujan lebat
    _paintRain(canvas, w, h, isHeavy: true);

    // 2. Kilatan petir realistis (efek flash terang berkala)
    double flashAlpha = 0.0;
    if (progress > 0.22 && progress < 0.28) {
      final p = (progress - 0.22) / 0.06;
      flashAlpha = math.sin(p * math.pi) * 0.42;
    } else if (progress > 0.74 && progress < 0.80) {
      final p = (progress - 0.74) / 0.06;
      flashAlpha = math.sin(p * math.pi) * 0.55;
    }

    if (flashAlpha > 0.05) {
      // Sheet lightning flash
      final flashPaint = Paint()
        ..color = const Color(0xFFE0E7FF).withValues(alpha: flashAlpha);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), flashPaint);

      // Gambar kilat cabang zigzag organik di langit
      _paintLightning(canvas, w, h, flashAlpha);
    }
  }

  // ==========================================
  // HELPER METODE GAMBAR DETAIL
  // ==========================================

  /// Menggambar awan kumulus volumetrik realistis (multi-lobe organic cloud)
  void _drawCloudCluster(
    Canvas canvas, {
    required Offset position,
    required double scale,
    required double opacity,
    required bool isNight,
    required bool isFront,
  }) {
    final w = 112.0 * scale;
    final ox = position.dx;
    final oy = position.dy;

    // Gabungkan bentuk awan alami menjadi satu kontur menyatu (Path union)
    final basePill = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(ox, oy + 16 * scale, w, 22 * scale),
        Radius.circular(11 * scale),
      ));
    final circle1 = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(ox + 28 * scale, oy + 18 * scale),
        radius: 18 * scale,
      ));
    final circle2 = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(ox + 56 * scale, oy + 10 * scale),
        radius: 25 * scale,
      ));
    final circle3 = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(ox + 84 * scale, oy + 17 * scale),
        radius: 17 * scale,
      ));

    var cloudPath = Path.combine(PathOperation.union, basePill, circle1);
    cloudPath = Path.combine(PathOperation.union, cloudPath, circle2);
    cloudPath = Path.combine(PathOperation.union, cloudPath, circle3);

    // Gradien volumetrik awan
    final List<Color> colors;
    if (isNight) {
      colors = isFront
          ? [
              Colors.white.withValues(alpha: opacity * 0.45),
              const Color(0xFFC7D2FE).withValues(alpha: opacity * 0.25),
              const Color(0xFF1E293B).withValues(alpha: opacity * 0.10),
            ]
          : [
              const Color(0xFF475569).withValues(alpha: opacity * 0.35),
              const Color(0xFF0F172A).withValues(alpha: opacity * 0.15),
            ];
    } else {
      colors = isFront
          ? [
              Colors.white.withValues(alpha: opacity * 0.90),
              const Color(0xFFF1F5F9).withValues(alpha: opacity * 0.60),
              const Color(0xFFCBD5E1).withValues(alpha: opacity * 0.25),
            ]
          : [
              const Color(0xFFE2E8F0).withValues(alpha: opacity * 0.50),
              const Color(0xFF94A3B8).withValues(alpha: opacity * 0.18),
            ];
    }

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Rect.fromLTWH(ox, oy, w, 40 * scale))
      ..style = PaintingStyle.fill;

    canvas.drawPath(cloudPath, paint);

    // Rim highlight lembut di pinggiran atas awan (pantulan cahaya bulan/matahari)
    if (isFront) {
      final edgePaint = Paint()
        ..color =
            Colors.white.withValues(alpha: opacity * (isNight ? 0.30 : 0.60))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale;
      canvas.drawPath(cloudPath, edgePaint);
    }
  }

  /// Menggambar Bulan Realistis lengkap dengan Corona Aura & Kawah
  void _paintMoon(
    Canvas canvas,
    Offset center,
    double radius,
    double progress, {
    bool isFullHalo = false,
  }) {
    final pulse = (math.sin(progress * 2 * math.pi) + 1) / 2;

    // 1. Outer Corona Glow (Aura bulan berdenyut)
    final haloRadius = radius * (isFullHalo ? 2.6 : 2.2);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC7D2FE).withValues(alpha: 0.38 + 0.12 * pulse),
          const Color(0xFF818CF8).withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.32, 0.68, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: haloRadius));
    canvas.drawCircle(center, haloRadius, haloPaint);

    // 2. Moon Body Sphere
    final moonPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE2E8F0),
          Color(0xFFCBD5E1),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, moonPaint);

    // 3. Tekstur kawah bulan (Lunar Craters)
    final craterPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.30, center.dy - radius * 0.22),
      radius * 0.22,
      craterPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.24, center.dy + radius * 0.24),
      radius * 0.18,
      craterPaint,
    );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.12, center.dy + radius * 0.36),
      radius * 0.14,
      craterPaint,
    );
  }

  /// Menggambar Matahari dengan Corona, Sunburst berputar, & Solar Core
  void _paintSun(
    Canvas canvas,
    Offset center,
    double radius,
    double progress, {
    required bool isHot,
    bool hasRays = false,
  }) {
    final pulse = (math.sin(progress * 2 * math.pi) + 1) / 2;

    // 1. Shimmering Corona Glow
    final auraRadius = radius * (isHot ? 2.8 : 2.3);
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isHot ? const Color(0xFFFEF08A) : Colors.white)
              .withValues(alpha: 0.45 + 0.15 * pulse),
          (isHot ? const Color(0xFFF97316) : const Color(0xFF38BDF8))
              .withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.28, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: auraRadius));
    canvas.drawCircle(center, auraRadius, auraPaint);

    // 2. Rotating Sunburst Rays
    if (hasRays) {
      final rayPaint = Paint()
        ..color = Colors.white.withValues(alpha: isHot ? 0.18 : 0.12)
        ..style = PaintingStyle.fill;

      const rayCount = 12;
      const angleStep = (2 * math.pi) / rayCount;
      final rotation = progress * 2 * math.pi;

      for (int i = 0; i < rayCount; i++) {
        final angle = i * angleStep + rotation;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + math.cos(angle - 0.10) * (radius * 2.4),
            center.dy + math.sin(angle - 0.10) * (radius * 2.4),
          )
          ..lineTo(
            center.dx + math.cos(angle + 0.10) * (radius * 2.4),
            center.dy + math.sin(angle + 0.10) * (radius * 2.4),
          )
          ..close();
        canvas.drawPath(path, rayPaint);
      }
    }

    // 3. Glowing Solar Core
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: isHot
            ? const [Color(0xFFFFFBEB), Color(0xFFFDE047), Color(0xFFF97316)]
            : const [Color(0xFFFFFFFF), Color(0xFFFEF08A), Color(0xFFFBBF24)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sunPaint);
  }

  /// Menggambar Langit Berbintang yang berkedip dengan beragam ritme
  void _paintStarfield(Canvas canvas, double w, double h, {double maxAlpha = 1.0}) {
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (final star in _stars) {
      final twinkle =
          (math.sin(progress * star.speed * math.pi + star.phaseOffset) + 1) / 2;
      starPaint.color = Colors.white.withValues(
        alpha: (0.18 + 0.78 * twinkle) * maxAlpha,
      );
      final center = Offset(star.xRatio * w, star.yRatio * h);
      canvas.drawCircle(
        center,
        star.radius * (0.8 + 0.4 * twinkle),
        starPaint,
      );
    }
  }

  /// Menggambar Bintang Jatuh (Shooting Star / Meteor) yang melintas anggun
  void _paintShootingStar(Canvas canvas, double w, double h) {
    if (progress > 0.42 && progress < 0.62) {
      final p = (progress - 0.42) / 0.20;
      final startX = w * 0.92 - p * w * 0.60;
      final startY = h * 0.04 + p * h * 0.42;
      const trailLength = 54.0;
      const angle = 0.55;

      final trailEnd = Offset(
        startX + math.cos(angle) * trailLength,
        startY - math.sin(angle) * trailLength,
      );

      final trailPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: math.sin(p * math.pi) * 0.85),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(Offset(startX, startY), trailEnd))
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), trailEnd, trailPaint);

      // Kepala bintang jatuh yang bercahaya
      final headPaint = Paint()
        ..color = Colors.white.withValues(alpha: math.sin(p * math.pi) * 0.95);
      canvas.drawCircle(Offset(startX, startY), 1.8, headPaint);
    }
  }

  /// Menggambar Kilat Cabang Petir Realistis
  void _paintLightning(Canvas canvas, double w, double h, double flashAlpha) {
    final boltGlow = Paint()
      ..color = const Color(0xFFC7D2FE).withValues(alpha: flashAlpha * 1.5.clamp(0.0, 0.8))
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final boltCore = Paint()
      ..color = Colors.white.withValues(alpha: (flashAlpha * 2.2).clamp(0.0, 1.0))
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(w * 0.74, 0)
      ..lineTo(w * 0.70, h * 0.24)
      ..lineTo(w * 0.75, h * 0.27)
      ..lineTo(w * 0.66, h * 0.56)
      ..lineTo(w * 0.70, h * 0.60)
      ..lineTo(w * 0.63, h * 0.94);

    // Cabang sekunder
    final branchPath = Path()
      ..moveTo(w * 0.70, h * 0.24)
      ..lineTo(w * 0.64, h * 0.38)
      ..moveTo(w * 0.66, h * 0.56)
      ..lineTo(w * 0.59, h * 0.70);

    canvas.drawPath(path, boltGlow);
    canvas.drawPath(branchPath, boltGlow);
    canvas.drawPath(path, boltCore);
    canvas.drawPath(branchPath, boltCore);
  }

  /// Menggambar Partikel Berkilau (Sparkles / Bokeh motes)
  void _paintSparkles(Canvas canvas, double w, double h, Color baseColor) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final s in _sparkles) {
      final yProgress = (s.yOffset - progress * s.speed) % 1.0;
      final currentY = yProgress * h;
      final currentX = (s.xRatio * w + math.sin(progress * 2 * math.pi + s.phase) * 12) % w;
      final alpha = (math.sin(progress * 4 * math.pi + s.phase) + 1) / 2;

      paint.color = baseColor.withValues(alpha: 0.25 + 0.55 * alpha);
      canvas.drawCircle(Offset(currentX, currentY), s.size * (0.8 + 0.3 * alpha), paint);
    }
  }

  /// Menggambar Gelombang Fatamorgana Panas (Heat Shimmer)
  void _paintHeatRipples(Canvas canvas, double w, double h) {
    final ripplePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final baseH = h - 14.0 - i * 9.0;
      path.moveTo(0, baseH);
      for (double x = 0; x <= w; x += 20) {
        final waveY = baseH + math.sin((x / 30) + (progress * 4 * math.pi) + i) * 2.5;
        path.lineTo(x, waveY);
      }
      canvas.drawPath(path, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.themeType != themeType;
  }
}

class _ParticleData {
  final double xRatio;
  final double yOffset;
  final double speed;
  final double length;
  final double opacity;

  const _ParticleData({
    required this.xRatio,
    required this.yOffset,
    required this.speed,
    required this.length,
    required this.opacity,
  });
}

class _StarData {
  final double xRatio;
  final double yRatio;
  final double radius;
  final double speed;
  final double phaseOffset;

  const _StarData({
    required this.xRatio,
    required this.yRatio,
    required this.radius,
    required this.speed,
    required this.phaseOffset,
  });
}

class _SparkleData {
  final double xRatio;
  final double yOffset;
  final double size;
  final double speed;
  final double phase;

  const _SparkleData({
    required this.xRatio,
    required this.yOffset,
    required this.size,
    required this.speed,
    required this.phase,
  });
}
