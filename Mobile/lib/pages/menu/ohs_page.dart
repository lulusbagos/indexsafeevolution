import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/link_model.dart';
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
  LinkMenuModel _findMenuItem(String route) {
    return listMenuOhs1.firstWhere(
      (m) => m.route == route,
      orElse: () => LinkMenuModel(
          title: '', icon: Icons.widgets_rounded, image: '', route: route, opacity: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _findMenuItem('/inspection');
    final daily = _findMenuItem('/daily_inspection');
    final p5m = _findMenuItem('/p5m');
    final simama = _findMenuItem('/simama');
    final p2h = _findMenuItem('/p2h');
    final dpa = _findMenuItem('/dpa');

    final groupInspection = [
      _OhsFioriItemData(
        title: 'Management Inspection',
        subtitle: 'Inspeksi Manajemen K3',
        description: 'Pemeriksaan kepatuhan standar K3 tingkat pimpinan dan pengawas operasional tambang.',
        tag: 'AUDIT MANAJEMEN',
        tagColor: const Color(0xFF0284C7),
        tagBgColor: const Color(0xFFF0F9FF),
        image: inspection.image,
        fallbackIcon: Icons.manage_search_sharp,
        route: inspection.route,
      ),
      _OhsFioriItemData(
        title: 'Daily Inspection',
        subtitle: 'Inspeksi Rutin Lapangan',
        description: 'Pemeriksaan berkala kondisi fisik area kerja, jalur hauling, dan fasilitas tambang.',
        tag: 'INSPEKSI RUTIN',
        tagColor: const Color(0xFF0D9488),
        tagBgColor: const Color(0xFFF0FDFA),
        image: daily.image,
        fallbackIcon: Icons.fact_check_rounded,
        route: daily.route,
      ),
    ];

    final groupPersonnel = [
      _OhsFioriItemData(
        title: 'Fit to Work P5M',
        subtitle: 'Kesiapan & Briefing 5M',
        description: 'Deklarasi kebugaran jasmani, tensi, dan evaluasi kesiapan kerja sebelum memulai tugas.',
        tag: 'PRA-SHIFT 5M',
        tagColor: const Color(0xFF059669),
        tagBgColor: const Color(0xFFECFDF5),
        image: p5m.image,
        fallbackIcon: Icons.health_and_safety_rounded,
        route: p5m.route,
      ),
      _OhsFioriItemData(
        title: 'SiMaMa',
        subtitle: 'Monitoring Shift Malam',
        description: 'Monitoring kesiapan masuk kerja malam dan manajemen risiko pencegahan fatigue.',
        tag: 'SHIFT MALAM',
        tagColor: const Color(0xFF4F46E5),
        tagBgColor: const Color(0xFFEEF2FF),
        image: simama.image,
        fallbackIcon: Icons.nightlight_round,
        route: simama.route,
      ),
    ];

    final groupVehicle = [
      _OhsFioriItemData(
        title: 'P2H Unit & LV',
        subtitle: 'Pemeriksaan Harian Sarana',
        description: 'Pemeriksaan dan pencatatan pra-operasional sarana kendaraan / LV sebelum dioperasikan.',
        tag: 'PEMERIKSAAN HARIAN',
        tagColor: const Color(0xFFD97706),
        tagBgColor: const Color(0xFFFFFBEB),
        image: p2h.image,
        fallbackIcon: Icons.car_repair_rounded,
        route: p2h.route,
      ),
      _OhsFioriItemData(
        title: 'Driver Assessment (DPA)',
        subtitle: 'Otorisasi Mengemudi K3',
        description: 'Verifikasi kelayakan berkendara, evaluasi kompetensi driver, dan otorisasi sarana tambang.',
        tag: 'OTORISASI DRIVER',
        tagColor: const Color(0xFF7C3AED),
        tagBgColor: const Color(0xFFF5F3FF),
        image: dpa.image.isNotEmpty ? dpa.image : 'assets/icons/ohs-06.png',
        fallbackIcon: Icons.drive_eta_rounded,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. DOMAIN 1: PENGAWASAN & AUDIT LAPANGAN
              _buildDomainSection(
                domainTitle: 'Pengawasan & Audit Lapangan',
                domainCount: '2 Modul',
                items: groupInspection,
              ),

              const SizedBox(height: 20),

              // 2. DOMAIN 2: KESIAPAN PERSONEL & SHIFT
              _buildDomainSection(
                domainTitle: 'Kesiapan Mandiri & Shift Kerja',
                domainCount: '2 Modul',
                items: groupPersonnel,
              ),

              const SizedBox(height: 20),

              // 3. DOMAIN 3: KELAIKAN SARANA & DRIVER
              _buildDomainSection(
                domainTitle: 'Kelaikan Armada & Otorisasi',
                domainCount: '2 Modul',
                items: groupVehicle,
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
    required List<_OhsFioriItemData> items,
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
  Widget _buildFioriWorklistCard(_OhsFioriItemData item) {
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
                        color: const Color(0xFF0D9488),
                        size: 26,
                      ),
                    )
                  : Icon(
                      item.fallbackIcon,
                      color: const Color(0xFF0D9488),
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

class _OhsFioriItemData {
  final String title;
  final String subtitle;
  final String description;
  final String tag;
  final Color tagColor;
  final Color tagBgColor;
  final String image;
  final IconData fallbackIcon;
  final String route;

  const _OhsFioriItemData({
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
