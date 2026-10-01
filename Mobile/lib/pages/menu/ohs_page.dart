import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/links.dart';
import '../../utils/routers.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/top_bar.dart';

class OhsPage extends StatefulWidget {
  const OhsPage({super.key});

  @override
  State<OhsPage> createState() => _OhsPageState();
}

class _OhsPageState extends State<OhsPage> {
  @override
  Widget build(BuildContext context) {
    final inspection = listMenuOhs1.firstWhere(
      (m) => m.route == '/inspection',
      orElse: () => listMenuOhs1[0],
    );
    final daily = listMenuOhs1.firstWhere(
      (m) => m.route == '/daily_inspection',
      orElse: () => listMenuOhs1[1],
    );
    final p5m = listMenuOhs1.firstWhere(
      (m) => m.route == '/p5m',
      orElse: () => listMenuOhs1[2],
    );
    final simama = listMenuOhs1.firstWhere(
      (m) => m.route == '/simama',
      orElse: () => listMenuOhs1[3],
    );
    final p2h = listMenuOhs1.firstWhere(
      (m) => m.route == '/p2h',
      orElse: () => listMenuOhs1[4],
    );
    final dpa = listMenuOhs1.firstWhere(
      (m) => m.route == '/dpa',
      orElse: () => listMenuOhs1[5],
    );

    final menuItems = [
      _OhsMenuItemData(
        title: 'Management Inspection',
        subtitle: 'Inspeksi Manajemen K3',
        image: inspection.image,
        fallbackIcon: Icons.manage_search_sharp,
        accentColor: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
        route: inspection.route,
      ),
      _OhsMenuItemData(
        title: 'Daily Inspection',
        subtitle: 'Inspeksi Rutin Harian',
        image: daily.image,
        fallbackIcon: Icons.fact_check_rounded,
        accentColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
        route: daily.route,
      ),
      _OhsMenuItemData(
        title: 'Fit to Work P5M',
        subtitle: 'Kesiapan & Briefing 5M',
        image: p5m.image,
        fallbackIcon: Icons.health_and_safety_rounded,
        accentColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        route: p5m.route,
      ),
      _OhsMenuItemData(
        title: 'SiMaMa',
        subtitle: 'Monitoring Shift Malam',
        image: simama.image,
        fallbackIcon: Icons.nightlight_round,
        accentColor: const Color(0xFF6366F1),
        bgColor: const Color(0xFFEEF2FF),
        route: simama.route,
      ),
      _OhsMenuItemData(
        title: 'P2H Unit & LV',
        subtitle: 'Pemeriksaan Harian Sarana',
        image: p2h.image,
        fallbackIcon: Icons.car_repair_rounded,
        accentColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        route: p2h.route,
      ),
      _OhsMenuItemData(
        title: 'Driver Assessment',
        subtitle: 'Evaluasi Pengemudi (DPA)',
        image: dpa.image,
        fallbackIcon: Icons.drive_eta_rounded,
        accentColor: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        route: dpa.route,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'OHS Program'),
      body: AmbientBackground(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER BANNER (Consistent Corporate Theme)
              _buildHeaderBanner(),

              const SizedBox(height: 16),

              // 2. CLEAN 2-COLUMN GRID
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 136,
                ),
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  return _buildModuleCard(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header Banner yang Simpel & Profesional
  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF065F46),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 12, color: Color(0xFF34D399)),
                    SizedBox(width: 5),
                    Text(
                      'PT INDEXIM COALINDO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF34D399),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Program Aktif',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Occupational Health & Safety (OHS)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Pemeriksaan kepatuhan standar K3, kesiapan fisik kerja, dan monitoring sarana operasional.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Modul Bersih, Elegan, dan Proporsional (Identik dengan tema SAP)
  Widget _buildModuleCard(_OhsMenuItemData item) {
    return _AnimatedPressable(
      onTap: () {
        if (item.route.isNotEmpty) {
          routePage(context, item.route, title: item.title);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: item.image.isNotEmpty
                      ? Image.asset(
                          item.image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            item.fallbackIcon,
                            color: item.accentColor,
                            size: 24,
                          ),
                        )
                      : Icon(
                          item.fallbackIcon,
                          color: item.accentColor,
                          size: 24,
                        ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OhsMenuItemData {
  final String title;
  final String subtitle;
  final String image;
  final IconData fallbackIcon;
  final Color accentColor;
  final Color bgColor;
  final String route;

  const _OhsMenuItemData({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.fallbackIcon,
    required this.accentColor,
    required this.bgColor,
    required this.route,
  });
}

/// Widget Interaktif: Animasi Bouncing Scale saat disentuh + Haptic Feedback
class _AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedPressable({
    required this.child,
    required this.onTap,
  });

  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuad,
        child: widget.child,
      ),
    );
  }
}

