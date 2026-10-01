import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/link_model.dart';
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
  LinkMenuModel _findMenuItem(String route) {
    return listMenuExtra.firstWhere(
      (m) => m.route == route,
      orElse: () => LinkMenuModel(
          title: '', icon: Icons.widgets_rounded, image: '', route: route, opacity: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final achievement = _findMenuItem('/sap_achievement');
    final league = _findMenuItem('/sap_league');
    final roster = _findMenuItem('/sap_work_roster');
    final quality = _findMenuItem('/sap_quality');
    final actionPlan = _findMenuItem('/sap_action_plan');

    final groupPerformance = [
      _PerformanceFioriItemData(
        title: 'Pencapaian SAP',
        subtitle: 'Target & Realisasi KPI',
        description: 'Evaluasi target dan pencapaian akuntabilitas keselamatan kerja individu & tim.',
        tag: 'REALISASI KPI',
        tagColor: const Color(0xFF2563EB),
        tagBgColor: const Color(0xFFEFF6FF),
        image: achievement.image,
        fallbackIcon: Icons.track_changes_rounded,
        route: achievement.route,
      ),
      _PerformanceFioriItemData(
        title: 'Klasemen League',
        subtitle: 'Peringkat Safety Departemen',
        description: 'Papan peringkat kompetisi keselamatan kerja antar divisi dan departemen operasional.',
        tag: 'LEADERBOARD',
        tagColor: const Color(0xFFD97706),
        tagBgColor: const Color(0xFFFFFBEB),
        image: league.image,
        fallbackIcon: Icons.emoji_events_rounded,
        route: league.route,
      ),
    ];

    final groupOperations = [
      _PerformanceFioriItemData(
        title: 'Roster Kerja',
        subtitle: 'Jadwal & Rotasi Lapangan',
        description: 'Informasi jadwal rotasi shift kerja, siklus on/off site, dan kalender operasional tambang.',
        tag: 'JADWAL & SHIFT',
        tagColor: const Color(0xFF0D9488),
        tagBgColor: const Color(0xFFF0FDFA),
        image: roster.image,
        fallbackIcon: Icons.calendar_month_rounded,
        route: roster.route,
      ),
      _PerformanceFioriItemData(
        title: 'Kualitas SAP',
        subtitle: 'Audit Mutu Pelaporan K3',
        description: 'Pemeriksaan kepatuhan standar mutu, verifikasi bukti foto, dan akurasi pelaporan K3.',
        tag: 'AUDIT MUTU',
        tagColor: const Color(0xFF7C3AED),
        tagBgColor: const Color(0xFFF5F3FF),
        image: quality.image,
        fallbackIcon: Icons.verified_rounded,
        route: quality.route,
      ),
    ];

    final groupFollowUp = [
      _PerformanceFioriItemData(
        title: 'Action Tracker',
        subtitle: 'Tindak Lanjut Temuan (CAPA)',
        description: 'Monitoring progres perbaikan, PIC, dan batas waktu closing temuan bahaya/audit K3.',
        tag: 'ACTION PLAN',
        tagColor: const Color(0xFFE11D48),
        tagBgColor: const Color(0xFFFFF1F2),
        image: actionPlan.image,
        fallbackIcon: Icons.assignment_turned_in_rounded,
        route: actionPlan.route,
      ),
      const _PerformanceFioriItemData(
        title: 'Informasi Insiden',
        subtitle: 'Data & Pembelajaran K3',
        description: 'Database insiden, lesson learned, statistik keselamatan, dan buletin pencegahan kecelakaan.',
        tag: 'LESSON LEARNED',
        tagColor: Color(0xFF0284C7),
        tagBgColor: Color(0xFFF0F9FF),
        image: 'assets/icons/extra-06.png',
        fallbackIcon: Icons.campaign_rounded,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. DOMAIN 1: TARGET & KOMPETISI K3
              _buildDomainSection(
                domainTitle: 'Indikator Kinerja & Kompetisi K3',
                domainCount: '2 Modul',
                items: groupPerformance,
              ),

              const SizedBox(height: 20),

              // 2. DOMAIN 2: OPERASIONAL & KUALITAS
              _buildDomainSection(
                domainTitle: 'Operasional & Standar Mutu',
                domainCount: '2 Modul',
                items: groupOperations,
              ),

              const SizedBox(height: 20),

              // 3. DOMAIN 3: TINDAK LANJUT & PEMBELAJARAN
              _buildDomainSection(
                domainTitle: 'Tindak Lanjut & Pembelajaran K3',
                domainCount: '2 Modul',
                items: groupFollowUp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section Header & List of Fiori Tiles
  Widget _buildDomainSection({
    required String domainTitle,
    required String domainCount,
    required List<_PerformanceFioriItemData> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                domainTitle,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                domainCount,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _buildFioriWorklistCard(items[index]);
          },
        ),
      ],
    );
  }

  /// Authentic SAP Fiori Enterprise Worklist Card
  Widget _buildFioriWorklistCard(_PerformanceFioriItemData item) {
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x050F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(8),
              child: item.image.isNotEmpty
                  ? Image.asset(
                      item.image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        item.fallbackIcon,
                        color: const Color(0xFF2563EB),
                        size: 26,
                      ),
                    )
                  : Icon(
                      item.fallbackIcon,
                      color: const Color(0xFF2563EB),
                      size: 26,
                    ),
            ),
            const SizedBox(width: 14),

            // Center Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.tagBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.tag,
                          style: TextStyle(
                            color: item.tagColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey.shade600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing Chevron Indicator
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceFioriItemData {
  final String title;
  final String subtitle;
  final String description;
  final String tag;
  final Color tagColor;
  final Color tagBgColor;
  final String image;
  final IconData fallbackIcon;
  final String route;

  const _PerformanceFioriItemData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.tag,
    required this.tagColor,
    required this.tagBgColor,
    required this.image,
    required this.fallbackIcon,
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
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuad,
        child: widget.child,
      ),
    );
  }
}
