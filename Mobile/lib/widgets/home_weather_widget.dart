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
            // The header photo remains visible through this small weather cue;
            // it is intentionally a glass tint, not a separate white card.
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

class _WeatherDetailSheet extends StatelessWidget {
  final WeatherData weather;
  final VoidCallback onRefresh;

  const _WeatherDetailSheet({
    required this.weather,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(weather.updatedAt);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Title & Location
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: weather.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    weather.iconData,
                    color: weather.iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            weather.locationName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${weather.subdivision} • Diperbarui pukul $timeStr WITA',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Perbarui Cuaca',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Hero bergaya weather Android: terang, berlapis, dan terasa hidup.
            Container(
              width: double.infinity,
              height: 174,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEFF7FF),
                    Color(0xFFDCEEFF),
                    Color(0xFFC8E4FF)
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFFFFF)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1A2563EB),
                      blurRadius: 18,
                      offset: Offset(0, 8)),
                ],
              ),
              child: Stack(children: [
                Positioned(
                  right: -22,
                  top: -36,
                  child: Container(
                    width: 154,
                    height: 154,
                    decoration: const BoxDecoration(
                        color: Color(0x52FFFFFF), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: -48,
                  child: Container(
                    width: 190,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0x70FFFFFF),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                                color: Color(0xCCFFFFFF),
                                shape: BoxShape.circle),
                            child: Icon(weather.iconData,
                                size: 22, color: weather.iconColor),
                          ),
                          const SizedBox(width: 8),
                          Text('CUACA SAAT INI',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: .8))),
                        ]),
                        const Spacer(),
                        Text(weather.conditionText,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF102A56))),
                        const SizedBox(height: 3),
                        Text(
                            'Terasa seperti ${weather.apparentTemperature.toStringAsFixed(0)}°C  •  ${weather.isDay ? 'Siang hari' : 'Malam hari'}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF52709B))),
                        const SizedBox(height: 8),
                        Text('Diperbarui $timeStr WITA',
                            style: const TextStyle(
                                fontSize: 10.5, color: Color(0xFF6B85A9))),
                      ]),
                ),
                Positioned(
                  right: 19,
                  bottom: 14,
                  child: Text('${weather.temperature.toStringAsFixed(0)}°',
                      style: const TextStyle(
                          fontSize: 58,
                          height: 1,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -3,
                          color: Color(0xFF0B4BA8))),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // Parameter Grid (Kelembapan, Angin, Presipitasi, Waktu)
            Row(
              children: [
                Expanded(
                  child: _buildParameterTile(
                    icon: Icons.water_drop_outlined,
                    iconColor: const Color(0xFF0284C7),
                    label: 'Kelembapan',
                    value: '${weather.humidity}%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildParameterTile(
                    icon: Icons.air_rounded,
                    iconColor: const Color(0xFF059669),
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
                    icon: Icons.umbrella_outlined,
                    iconColor: const Color(0xFF7C3AED),
                    label: 'Curah Hujan',
                    value: '${weather.precipitation.toStringAsFixed(1)} mm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildParameterTile(
                    icon: weather.isDay
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_outlined,
                    iconColor: const Color(0xFFEA580C),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: weather.statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: weather.statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 20,
                    color: weather.statusColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panduan Keselamatan Operasional',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: weather.statusColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          weather.safetyStatus,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                            height: 1.3,
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
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
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

  Widget _buildParameterTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
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
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
