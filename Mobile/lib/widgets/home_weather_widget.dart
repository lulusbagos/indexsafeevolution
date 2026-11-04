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
  night,        // Malam Hari
  cloudy,       // Berawan / Mendung
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
    if (!w.isDay) return WeatherThemeType.night;
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
      case WeatherThemeType.night:
        gradientColors = const [
          Color(0xFF030712),
          Color(0xFF0F172A),
          Color(0xFF1E1B4B),
        ];
        borderColor = const Color(0xFF818CF8).withValues(alpha: 0.4);
        accentBadgeBg = const Color(0xFF312E81).withValues(alpha: 0.4);
        break;
      case WeatherThemeType.cloudy:
        gradientColors = const [
          Color(0xFF1E293B),
          Color(0xFF334155),
          Color(0xFF475569),
        ];
        borderColor = const Color(0xFF94A3B8).withValues(alpha: 0.4);
        accentBadgeBg = const Color(0xFF334155).withValues(alpha: 0.4);
        break;
    }

    return Container(
      width: double.infinity,
      height: 190,
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
            color: gradientColors.last.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Dynamic Animated Weather Canvas (Hujan, Badai, Panas, dsb.)
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(double.infinity, 190),
                painter: _WeatherAtmospherePainter(
                  progress: _animCtrl.value,
                  themeType: themeType,
                ),
              );
            },
          ),

          // 2. Content overlay
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge: "CUACA SAAT INI" + Glowing Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentBadgeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
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
                                  color: Colors.white.withValues(alpha: 0.5 + 0.5 * pulse),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.4 + 0.4 * pulse),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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

                    // Floating animated weather icon
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, child) {
                        final floatY = math.sin(_animCtrl.value * 2 * math.pi) * 3.5;
                        return Transform.translate(
                          offset: Offset(0, floatY),
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.15),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          weather.iconData,
                          size: 24,
                          color: Colors.white,
                        ),
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
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Terasa seperti ${weather.apparentTemperature.toStringAsFixed(0)}°C  •  ${weather.isDay ? 'Siang' : 'Malam'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                              shadows: const [
                                Shadow(
                                  color: Color(0x44000000),
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
                        fontSize: 64,
                        height: 0.95,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -4,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x40000000),
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

/// CustomPainter untuk menghasilkan efek atmosferik cuaca hidup:
/// - Hujan / Gerimis: Garis tetesan air jatuh miring + efek splash
/// - Badai Petir: Hujan lebat miring + kilatan listrik petir
/// - Panas Terik: Pancaran sinar matahari berputar + partikel berkilau hangat
/// - Cerah: Cincin cahaya matahari bersinar lembut
/// - Malam: Bintang-bintang berkedip lembut di langit malam
/// - Berawan: Awan-awan melayang perlahan secara horizontal
class _WeatherAtmospherePainter extends CustomPainter {
  final double progress;
  final WeatherThemeType themeType;

  // Precomputed fixed seed particles
  static final List<_ParticleData> _rainDrops = List.generate(42, (i) {
    final rand = math.Random(i * 37 + 11);
    return _ParticleData(
      xRatio: rand.nextDouble(),
      yOffset: rand.nextDouble(),
      speed: 1.1 + rand.nextDouble() * 1.4,
      length: 12.0 + rand.nextDouble() * 18.0,
      opacity: 0.25 + rand.nextDouble() * 0.5,
    );
  });

  static final List<_StarData> _stars = List.generate(36, (i) {
    final rand = math.Random(i * 43 + 7);
    return _StarData(
      xRatio: rand.nextDouble(),
      yRatio: rand.nextDouble() * 0.75, // Bintang di bagian atas/tengah
      radius: 1.0 + rand.nextDouble() * 1.8,
      phaseOffset: rand.nextDouble() * 2 * math.pi,
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
      case WeatherThemeType.night:
        _paintNight(canvas, w, h);
        break;
      case WeatherThemeType.cloudy:
        _paintCloudy(canvas, w, h);
        break;
    }
  }

  void _paintRain(Canvas canvas, double w, double h, {required bool isHeavy}) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Garis tetesan hujan jatuh miring
    const slantX = -10.0;
    for (final drop in _rainDrops) {
      final yProgress = (drop.yOffset + progress * drop.speed) % 1.0;
      final startY = yProgress * (h + drop.length) - drop.length;
      final startX = drop.xRatio * w + (1.0 - yProgress) * 20;

      paint.color = Colors.white.withValues(
        alpha: (drop.opacity * (isHeavy ? 0.9 : 0.65)).clamp(0.0, 1.0),
      );
      paint.strokeWidth = isHeavy ? 1.8 : 1.2;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + slantX, startY + drop.length * (isHeavy ? 1.4 : 1.0)),
        paint,
      );

      // Splash ripple halus saat tetesan mendekati bagian bawah kartu
      if (yProgress > 0.88) {
        final rippleProgress = (yProgress - 0.88) / 0.12;
        final ripplePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(
            alpha: (0.4 * (1.0 - rippleProgress)).clamp(0.0, 1.0),
          );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(startX + slantX, h - 6),
            width: 14 * rippleProgress,
            height: 4 * rippleProgress,
          ),
          ripplePaint,
        );
      }
    }
  }

  void _paintThunderstorm(Canvas canvas, double w, double h) {
    // 1. Gambar hujan lebat
    _paintRain(canvas, w, h, isHeavy: true);

    // 2. Kilatan petir realistis (efek flash terang berkala)
    // Flash terjadi saat progress di sekitar 0.23 dan 0.76
    double flashAlpha = 0.0;
    if ((progress > 0.22 && progress < 0.28)) {
      final p = (progress - 0.22) / 0.06;
      flashAlpha = math.sin(p * math.pi) * 0.35;
    } else if ((progress > 0.74 && progress < 0.80)) {
      final p = (progress - 0.74) / 0.06;
      flashAlpha = math.sin(p * math.pi) * 0.45;
    }

    if (flashAlpha > 0.05) {
      final flashPaint = Paint()
        ..color = const Color(0xFFE0E7FF).withValues(alpha: flashAlpha);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), flashPaint);

      // Gambar garis petir zigzag di sudut kanan atas saat flash puncak
      final boltPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashAlpha * 2.0.clamp(0.0, 1.0))
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(w * 0.72, 0)
        ..lineTo(w * 0.68, h * 0.25)
        ..lineTo(w * 0.73, h * 0.28)
        ..lineTo(w * 0.65, h * 0.58)
        ..lineTo(w * 0.69, h * 0.62)
        ..lineTo(w * 0.62, h * 0.95);
      canvas.drawPath(path, boltPaint);
    }
  }

  void _paintHotSunny(Canvas canvas, double w, double h) {
    final sunCenter = Offset(w * 0.88, h * 0.15);

    // 1. Sinar matahari berputar (Sunburst)
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    const rayCount = 12;
    const angleStep = (2 * math.pi) / rayCount;
    final rotationAngle = progress * 2 * math.pi;

    for (int i = 0; i < rayCount; i++) {
      final angle = i * angleStep + rotationAngle;
      final path = Path()
        ..moveTo(sunCenter.dx, sunCenter.dy)
        ..lineTo(
          sunCenter.dx + math.cos(angle - 0.12) * 160,
          sunCenter.dy + math.sin(angle - 0.12) * 160,
        )
        ..lineTo(
          sunCenter.dx + math.cos(angle + 0.12) * 160,
          sunCenter.dy + math.sin(angle + 0.12) * 160,
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // 2. Lingkaran solar flare mengembang & menyusut halus
    final pulse = (math.sin(progress * 2 * math.pi) + 1) / 2;
    final flarePaint1 = Paint()
      ..color = const Color(0xFFFEF08A).withValues(alpha: 0.20 + 0.10 * pulse)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sunCenter, 45 + 15 * pulse, flarePaint1);

    final flarePaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 + 0.15 * pulse)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sunCenter, 22 + 6 * pulse, flarePaint2);
  }

  void _paintSunny(Canvas canvas, double w, double h) {
    final sunCenter = Offset(w * 0.86, h * 0.20);
    final pulse = (math.sin(progress * 2 * math.pi) + 1) / 2;

    // Pancaran cincin aura cerah
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 + 0.08 * pulse)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sunCenter, 65 + 15 * pulse, glowPaint);

    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 + 0.10 * pulse)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sunCenter, 32 + 6 * pulse, innerPaint);
  }

  void _paintNight(Canvas canvas, double w, double h) {
    // 1. Bintang-bintang berkedip
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (final star in _stars) {
      final twinkle = (math.sin(progress * 4 * math.pi + star.phaseOffset) + 1) / 2;
      starPaint.color = Colors.white.withValues(alpha: 0.2 + 0.75 * twinkle);
      final center = Offset(star.xRatio * w, star.yRatio * h);
      canvas.drawCircle(center, star.radius * (0.8 + 0.4 * twinkle), starPaint);
    }

    // 2. Lingkaran cahaya bulan lembut di kanan atas
    final moonCenter = Offset(w * 0.85, h * 0.25);
    final moonGlow = Paint()
      ..color = const Color(0xFFC7D2FE).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(moonCenter, 45, moonGlow);
  }

  void _paintCloudy(Canvas canvas, double w, double h) {
    // Awan melayang perlahan horizontal
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final speed = 0.4 + i * 0.25;
      final xOffset = (progress * speed * w + i * 110) % (w + 140) - 70;
      final yOffset = 25.0 + i * 40.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(xOffset, yOffset, 120 + i * 30, 36 + i * 10),
          const Radius.circular(25),
        ),
        cloudPaint,
      );
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
  final double phaseOffset;

  const _StarData({
    required this.xRatio,
    required this.yRatio,
    required this.radius,
    required this.phaseOffset,
  });
}
