import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/preference.dart';

/// Enum Pembagian Waktu Operasional Tambang
enum AmbientTimePeriod {
  morning, // Pagi (05:00 - 10:59) - Semangat Fajar & Briefing
  afternoon, // Siang (11:00 - 14:59) - Fokus Operasional Puncak
  evening, // Sore (15:00 - 18:29) - Senja & Transisi Shift
  night, // Malam (18:30 - 04:59) - Operasi Shift Malam & Ketenangan
}

/// AmbientBackground Cerdas:
/// 1. Berbeda setiap waktu (Pagi, Siang, Sore, Malam) dengan mood warna & ritme gerak khas.
/// 2. Berbeda setiap user (Personal Signature Color Hue & Particle Seed berdasarkan NIK / Nama).
class AmbientBackground extends StatefulWidget {
  final Widget child;
  final bool enableFloatingShapes;
  final List<Color>? customColors;
  final String? userSeed;

  const AmbientBackground({
    super.key,
    required this.child,
    this.enableFloatingShapes = true,
    this.customColors,
    this.userSeed,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _fadeInController;
  late final AmbientTimePeriod _timePeriod;
  late final int _userHash;
  late final double _userHueShift;
  late final List<Color> _resolvedColors;
  late final List<Color> _baseCanvasGradient;

  @override
  void initState() {
    super.initState();

    // 1. Tentukan Periode Waktu Saat Ini
    _timePeriod = _calculateTimePeriod();

    // 2. Hitung Hash Unik Pengguna (dari NIK atau Nama)
    final seedString = widget.userSeed ??
        PreferenceService.getProfile()?.noNik ??
        PreferenceService.getUser() ??
        'indexsafe_evolution';

    int hash = 0;
    for (int char in seedString.codeUnits) {
      hash = (hash * 37 + char) & 0x7FFFFFFF;
    }
    _userHash = hash;

    // Pergeseran Hue unik untuk user (-35 derajat sampai +35 derajat)
    _userHueShift = ((_userHash % 70) - 35).toDouble();

    // 3. Tentukan Kecepatan Animasi Berdasarkan Waktu
    Duration animDuration;
    switch (_timePeriod) {
      case AmbientTimePeriod.morning:
        animDuration = const Duration(seconds: 8);
        break;
      case AmbientTimePeriod.afternoon:
        animDuration = const Duration(seconds: 7);
        break;
      case AmbientTimePeriod.evening:
        animDuration = const Duration(seconds: 10);
        break;
      case AmbientTimePeriod.night:
        animDuration = const Duration(seconds: 13);
        break;
    }

    final isPowerSaver = PreferenceService.isPowerSaverEnabled();

    _controller = AnimationController(
      vsync: this,
      duration: animDuration,
    );

    // Animasi Opacity Progresif
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (isPowerSaver) {
      // Pada mode efisiensi daya: Opasitas langsung 100%, ticker GPU tidak dijalankan sama sekali
      _fadeInController.value = 1.0;
    } else {
      _controller.repeat();
      _fadeInController.forward();
    }

    // 4. Bangun Palet Warna Spesifik Waktu + Personalisasi User
    _resolvedColors = _generateTimeAndUserColors();
    _baseCanvasGradient = _generateBaseCanvas();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _controller.dispose();
    super.dispose();
  }

  AmbientTimePeriod _calculateTimePeriod() {
    final hour = DateTime.now().hour;
    final minute = DateTime.now().minute;
    final totalMinutes = hour * 60 + minute;

    if (totalMinutes >= 5 * 60 && totalMinutes < 11 * 60) {
      return AmbientTimePeriod.morning;
    } else if (totalMinutes >= 11 * 60 && totalMinutes < 15 * 60) {
      return AmbientTimePeriod.afternoon;
    } else if (totalMinutes >= 15 * 60 && totalMinutes < 18 * 60 + 30) {
      return AmbientTimePeriod.evening;
    } else {
      return AmbientTimePeriod.night;
    }
  }

  List<Color> _generateBaseCanvas() {
    switch (_timePeriod) {
      case AmbientTimePeriod.morning:
        return const [
          Color(0xFFFEF3C7), // Faint Morning Amber
          Color(0xFFF0FDF4), // Fresh Dew Mint
          Color(0xFFF8FAFC), // Crisp Slate
        ];
      case AmbientTimePeriod.afternoon:
        return const [
          Color(0xFFE0F2FE), // Bright Sky Tint
          Color(0xFFF8FAFC), // Pure Slate
          Color(0xFFF1F5F9), // Light Steel
        ];
      case AmbientTimePeriod.evening:
        return const [
          Color(0xFFFFF1F2), // Soft Sunset Rose
          Color(0xFFFAF5FF), // Dusk Lavender
          Color(0xFFF8FAFC), // Smooth Slate
        ];
      case AmbientTimePeriod.night:
        return const [
          Color(0xFFE2E8F0), // Cool Moonlight Slate
          Color(0xFFF8FAFC), // Background
          Color(0xFFEDE9FE), // Deep Violet Tint
        ];
    }
  }

  List<Color> _generateTimeAndUserColors() {
    if (widget.customColors != null && widget.customColors!.isNotEmpty) {
      return widget.customColors!;
    }

    List<Color> rawColors;
    switch (_timePeriod) {
      case AmbientTimePeriod.morning:
        // Fajar Emas, Mint Segar, Biru Fajar (Semangat Pagi Tambang)
        rawColors = const [
          Color(0xFFF59E0B), // Amber Sunrise
          Color(0xFF10B981), // Emerald Mint
          Color(0xFF06B6D4), // Cyan Glow
          Color(0xFFFB7185), // Coral Spark
        ];
        break;
      case AmbientTimePeriod.afternoon:
        // Azure Sapphire, Electric Cyan, Jade Fokus (Puncak Operasional)
        rawColors = const [
          Color(0xFF0284C7), // Vivid Cyan
          Color(0xFF38BDF8), // Sky Azure
          Color(0xFF4F46E5), // Indigo Sapphire
          Color(0xFF14B8A6), // Sunlit Teal
        ];
        break;
      case AmbientTimePeriod.evening:
        // Sunset Peach, Dusk Rose, Violet Amber, Twilight Indigo (Senja Tambang)
        rawColors = const [
          Color(0xFFF43F5E), // Sunset Rose
          Color(0xFFF97316), // Warm Coral Amber
          Color(0xFF8B5CF6), // Dusk Violet
          Color(0xFF6366F1), // Twilight Indigo
        ];
        break;
      case AmbientTimePeriod.night:
        // Electric Blue, Cyber Cyan, Mystic Violet, Night Emerald (Operasi Malam)
        rawColors = const [
          Color(0xFF2563EB), // Electric Blue
          Color(0xFF22D3EE), // Cyber Cyan Sparkle
          Color(0xFF7C3AED), // Mystic Amethyst
          Color(0xFF059669), // Night Beacon Green
        ];
        break;
    }

    // Terapkan User Signature Hue Shift ke setiap warna palet
    return rawColors.map((color) {
      final hsl = HSLColor.fromColor(color);
      final newHue = (hsl.hue + _userHueShift + 360) % 360;
      return hsl.withHue(newHue).toColor();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isPowerSaver = PreferenceService.isPowerSaverEnabled();

    return Stack(
      children: [
        // 0. Base Neutral Slate Canvas
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFFF8FAFC)),
        ),

        // 1 & 2. Ambient Layer:
        // Jika Mode Efisiensi Daya Aktif: Warna latar dipertahankan penuh tetapi STATIS (0% beban GPU, HP tetap dingin).
        // Jika Nonaktif: Animasi fluid dinamis 60fps aktif.
        Positioned.fill(
          child: isPowerSaver
              ? Stack(
                  children: [
                    // Base Adaptive Gradient Canvas
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _baseCanvasGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Static Ambient Artwork: warna tetap tampil kaya & elegan tanpa ticker animasi
                    if (widget.enableFloatingShapes)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _DynamicAmbientPainter(
                              progress: 0.28,
                              colors: _resolvedColors,
                              timePeriod: _timePeriod,
                              userHash: _userHash,
                              isStatic: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : AnimatedBuilder(
                  animation: _fadeInController,
                  builder: (context, _) {
                    final curved = Curves.easeOutCubic.transform(_fadeInController.value);
                    final dynamicOpacity = (0.15 + (curved * 0.85)).clamp(0.0, 1.0);

                    return Opacity(
                      opacity: dynamicOpacity,
                      child: Stack(
                        children: [
                          // Base Adaptive Gradient Canvas
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _baseCanvasGradient,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),

                          // Dynamic GPU Canvas Animation
                          if (widget.enableFloatingShapes)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: _DynamicAmbientPainter(
                                      progress: _controller.value,
                                      colors: _resolvedColors,
                                      timePeriod: _timePeriod,
                                      userHash: _userHash,
                                      isStatic: false,
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // 3. Main content layered cleanly on top
        widget.child,
      ],
    );
  }
}

class _DynamicAmbientPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final AmbientTimePeriod timePeriod;
  final int userHash;
  final bool isStatic;

  _DynamicAmbientPainter({
    required this.progress,
    required this.colors,
    required this.timePeriod,
    required this.userHash,
    this.isStatic = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = progress * 2 * math.pi;
    final userOffset = (userHash % 100) / 100.0 * 2 * math.pi;

    // A. FLUID AURORA WAVE 1 (Top Wave)
    _drawFluidWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.14,
      amplitude: 26,
      frequency: 1.8,
      phase: t + userOffset,
      color: colors[0],
      alpha: 0.16,
    );

    // B. FLUID AURORA WAVE 2 (Mid-Screen Soft Wave)
    _drawFluidWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.44,
      amplitude: 32,
      frequency: 1.4,
      phase: t + math.pi * 0.6 + (userOffset * 0.5),
      color: colors[1 % colors.length],
      alpha: 0.12,
    );

    // C. GLOWING ORB 1: Top-Right (Pulse dipersonalisasi user)
    final orb1Center = Offset(
      size.width * 0.82 + math.sin(t + userOffset) * 40,
      size.height * 0.15 + math.cos(t * 0.9 + userOffset) * 36,
    );
    final orb1Radius = size.width * 0.52 + math.sin(t * 1.4) * 26;
    _drawGlow(canvas, orb1Center, orb1Radius, colors[0], 0.25);

    // D. GLOWING ORB 2: Mid-Left
    final orb2Center = Offset(
      size.width * 0.12 + math.cos(t * 0.8 + userOffset) * 34,
      size.height * 0.45 + math.sin(t * 1.1 + userOffset) * 40,
    );
    final orb2Radius = size.width * 0.54 + math.cos(t * 1.2) * 30;
    _drawGlow(canvas, orb2Center, orb2Radius, colors[1 % colors.length], 0.20);

    // E. GLOWING ORB 3: Bottom Accent
    final orb3Center = Offset(
      size.width * 0.74 + math.sin(t * 0.7) * 36,
      size.height * 0.78 + math.cos(t * 0.8) * 38,
    );
    final orb3Radius = size.width * 0.48 + math.sin(t) * 24;
    _drawGlow(canvas, orb3Center, orb3Radius, colors[2 % colors.length], 0.18);

    // F. GLOWING ORB 4: Center Ambient Pulse
    final orb4Center = Offset(
      size.width * 0.46 + math.cos(t * 1.2) * 42,
      size.height * 0.30 + math.sin(t * 0.6) * 32,
    );
    final orb4Radius = size.width * 0.38 + math.sin(t * 0.9) * 20;
    _drawGlow(canvas, orb4Center, orb4Radius, colors[3 % colors.length], 0.15);

    // G. FLOATING SPARKS & SAFETY PARTICLES (Drifting upward)
    _drawFloatingParticles(canvas, size, progress);

    // H. SUBTLE GEOMETRIC MODERN DOT GRID
    _drawDynamicDotGrid(canvas, size, progress);
  }

  void _drawGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double maxAlpha,
  ) {
    if (radius <= 0) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: maxAlpha),
          color.withValues(alpha: maxAlpha * 0.52),
          color.withValues(alpha: maxAlpha * 0.20),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.38, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  void _drawFluidWave({
    required Canvas canvas,
    required Size size,
    required double baseY,
    required double amplitude,
    required double frequency,
    required double phase,
    required Color color,
    required double alpha,
  }) {
    final path = Path();
    path.moveTo(0, baseY);

    const int steps = 24;
    for (int i = 0; i <= steps; i++) {
      final x = size.width * (i / steps);
      final normalizedX = (i / steps) * 2 * math.pi * frequency;
      final y = baseY + math.sin(normalizedX + phase) * amplitude;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, baseY - amplitude, size.width, size.height - baseY + amplitude));

    canvas.drawPath(path, wavePaint);
  }

  void _drawFloatingParticles(Canvas canvas, Size size, double p) {
    final particlePaint = Paint();
    const particleCount = 15;

    for (int i = 0; i < particleCount; i++) {
      final seedX = (math.sin((i + userHash % 17) * 99.7) * 0.5 + 0.5);
      final speed = 0.5 + (math.cos(i * 43.1) * 0.5 + 0.5) * 0.8;

      final driftY = (1.0 - ((p * speed + (i / particleCount)) % 1.0));
      final x = size.width * seedX + math.sin(p * 2 * math.pi + i) * 18;
      final y = size.height * driftY;

      final twinkle = 0.35 + math.sin(p * 4 * math.pi + i * 2) * 0.35;
      final particleSize = 1.8 + (i % 3) * 1.0;

      final colorIndex = (i + userHash) % colors.length;
      particlePaint.color = colors[colorIndex].withValues(alpha: twinkle.clamp(0.15, 0.75));

      canvas.drawCircle(Offset(x, y), particleSize, particlePaint);

      // Halo ring tipis di sekitar partikel
      final haloPaint = Paint()
        ..color = colors[colorIndex].withValues(alpha: (twinkle * 0.35).clamp(0.06, 0.32))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(x, y), particleSize * 2.2, haloPaint);
    }
  }

  void _drawDynamicDotGrid(Canvas canvas, Size size, double p) {
    final dotPaint = Paint()..color = const Color(0x0E0F172A);
    const spacing = 30.0;
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();

    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        final wave = math.sin((i * 0.4 + j * 0.4) + p * 2 * math.pi) * 0.5;
        canvas.drawCircle(
          Offset(i * spacing + 15, j * spacing + 15),
          1.0 + wave,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicAmbientPainter oldDelegate) {
    if (isStatic && oldDelegate.isStatic) return false;
    return oldDelegate.progress != progress ||
        oldDelegate.timePeriod != timePeriod ||
        oldDelegate.colors != colors ||
        oldDelegate.userHash != userHash ||
        oldDelegate.isStatic != isStatic;
  }
}
