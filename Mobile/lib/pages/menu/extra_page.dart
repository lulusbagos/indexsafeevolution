import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/links.dart';
import '../../utils/routers.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/top_bar.dart';

class ExtraPage extends StatefulWidget {
  const ExtraPage({super.key});

  @override
  State<ExtraPage> createState() => _ExtraPageState();
}

class _ExtraPageState extends State<ExtraPage> {
  @override
  Widget build(BuildContext context) {
    final achievement = listMenuExtra.firstWhere(
      (m) => m.route == '/sap_achievement',
      orElse: () => listMenuExtra[0],
    );
    final league = listMenuExtra.firstWhere(
      (m) => m.route == '/sap_league',
      orElse: () => listMenuExtra[1],
    );
    final roster = listMenuExtra.firstWhere(
      (m) => m.route == '/sap_work_roster',
      orElse: () => listMenuExtra[2],
    );
    final quality = listMenuExtra.firstWhere(
      (m) => m.route == '/sap_quality',
      orElse: () => listMenuExtra[3],
    );
    final actionPlan = listMenuExtra.firstWhere(
      (m) => m.route == '/sap_action_plan',
      orElse: () => listMenuExtra[4],
    );

    final menuItems = [
      _PerformanceMenuItemData(
        title: 'Pencapaian SAP',
        subtitle: 'Target & Realisasi KPI',
        image: achievement.image,
        fallbackIcon: Icons.track_changes_rounded,
        accentColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        route: achievement.route,
      ),
      _PerformanceMenuItemData(
        title: 'Klasemen League',
        subtitle: 'Peringkat Kinerja Safety',
        image: league.image,
        fallbackIcon: Icons.emoji_events_rounded,
        accentColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        route: league.route,
      ),
      _PerformanceMenuItemData(
        title: 'Roster Kerja',
        subtitle: 'Jadwal & Rotasi Kerja',
        image: roster.image,
        fallbackIcon: Icons.calendar_month_rounded,
        accentColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
        route: roster.route,
      ),
      _PerformanceMenuItemData(
        title: 'Kualitas SAP',
        subtitle: 'Audit Mutu Pelaporan K3',
        image: quality.image,
        fallbackIcon: Icons.verified_rounded,
        accentColor: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        route: quality.route,
      ),
      _PerformanceMenuItemData(
        title: 'Action Tracker',
        subtitle: 'Tindak Lanjut Temuan',
        image: actionPlan.image,
        fallbackIcon: Icons.assignment_turned_in_rounded,
        accentColor: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFF1F2),
        route: actionPlan.route,
      ),
      const _PerformanceMenuItemData(
        title: 'Informasi Insiden',
        subtitle: 'Data & Pembelajaran K3',
        image: '',
        fallbackIcon: Icons.campaign_rounded,
        accentColor: Color(0xFF0284C7),
        bgColor: Color(0xFFF0F9FF),
        route: '/sap_incident_information',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Performance Hub'),
      body: AmbientBackground(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SECTION TITLE
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 12),
                child: Text(
                  'Metrik & Kinerja SAP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              // 2. CLEAN 2-COLUMN GRID (Identical to SAP & OHS)
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

  /// Kartu Modul Bersih, Elegan, dan Proporsional (Identik dengan tema SAP)
  Widget _buildModuleCard(_PerformanceMenuItemData item) {
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

class _PerformanceMenuItemData {
  final String title;
  final String subtitle;
  final String image;
  final IconData fallbackIcon;
  final Color accentColor;
  final Color bgColor;
  final String route;

  const _PerformanceMenuItemData({
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

