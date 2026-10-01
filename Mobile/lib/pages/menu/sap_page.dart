import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/link_model.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/links.dart';
import '../../utils/routers.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/top_bar.dart';
import '../sync/pending_sync_page.dart';

class SapPage extends StatefulWidget {
  const SapPage({super.key});

  @override
  State<SapPage> createState() => _SapPageState();
}

class _SapPageState extends State<SapPage> {
  final OfflineSyncService _syncService = OfflineSyncService();
  int _pendingCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkPendingSync();
    _syncService.pendingCountNotifier.addListener(_onPendingCountChanged);
    _syncService.isSyncingNotifier.addListener(_onSyncingChanged);
  }

  @override
  void dispose() {
    _syncService.pendingCountNotifier.removeListener(_onPendingCountChanged);
    _syncService.isSyncingNotifier.removeListener(_onSyncingChanged);
    super.dispose();
  }

  void _onPendingCountChanged() {
    if (mounted) {
      setState(() {
        _pendingCount = _syncService.pendingCountNotifier.value;
      });
    }
  }

  void _onSyncingChanged() {
    if (mounted) {
      setState(() {
        _isSyncing = _syncService.isSyncingNotifier.value;
      });
    }
  }

  Future<void> _checkPendingSync() async {
    final count = await _syncService.refreshPendingCount();
    if (!mounted) return;
    setState(() {
      _pendingCount = count;
    });
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    if (_pendingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua data lokal sudah tersinkronkan ke server.'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menyinkronkan data offline ke server...'),
        backgroundColor: Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    final res = await _syncService.syncAll();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (res.failed == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sinkronisasi selesai! ${res.success} transaksi berhasil dikirim ke server.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sinkronisasi: ${res.success} berhasil, ${res.failed} gagal/menunggu jaringan.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _checkPendingSync();
  }

  void _openPendingSyncPage() async {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PendingSyncPage()),
    );
    _checkPendingSync();
  }

  LinkMenuModel _findMenuItem(String route) {
    return listMenuSap.firstWhere(
      (m) => m.route == route,
      orElse: () => LinkMenuModel(
          title: '', icon: Icons.widgets_rounded, image: '', route: route, opacity: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _pendingCount > 0;

    final hazard = _findMenuItem('/hazard_report');
    final inspection = _findMenuItem('/inspection');
    final observation = _findMenuItem('/observation');
    final safetyTalk = _findMenuItem('/safety_talk');
    final coaching = _findMenuItem('/coaching');
    final sapReport = _findMenuItem('/sap_report');

    final menuItems = [
      _SapMenuItemData(
        title: 'Hazard Report',
        subtitle: 'Pelaporan Bahaya K3',
        image: hazard.image,
        fallbackIcon: Icons.warning_amber_rounded,
        accentColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        route: hazard.route,
      ),
      _SapMenuItemData(
        title: 'Inspection',
        subtitle: 'Inspeksi Keselamatan',
        image: inspection.image,
        fallbackIcon: Icons.fact_check_rounded,
        accentColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        route: inspection.route,
      ),
      _SapMenuItemData(
        title: 'Observation',
        subtitle: 'Observasi Perilaku K3',
        image: observation.image,
        fallbackIcon: Icons.visibility_rounded,
        accentColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
        route: observation.route,
      ),
      _SapMenuItemData(
        title: 'Safety Talk',
        subtitle: 'Briefing 5M Pra-shift',
        image: safetyTalk.image,
        fallbackIcon: Icons.record_voice_over_rounded,
        accentColor: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
        route: safetyTalk.route,
      ),
      _SapMenuItemData(
        title: 'Coaching',
        subtitle: 'Bimbingan Konseling K3',
        image: coaching.image,
        fallbackIcon: Icons.psychology_rounded,
        accentColor: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFF1F2),
        route: coaching.route,
      ),
      _SapMenuItemData(
        title: 'SAP Report',
        subtitle: 'Statistik & Rekapitulasi',
        image: sapReport.image,
        fallbackIcon: Icons.bar_chart_rounded,
        accentColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        route: sapReport.route,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Safety Accountability Program'),
      body: AmbientBackground(
        child: RefreshIndicator(
          onRefresh: _checkPendingSync,
          color: const Color(0xFF2563EB),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ALERT SYNC HANYA JIKA ADA DATA PENDING
                if (hasPending) ...[
                  _buildPendingAlertBar(),
                  const SizedBox(height: 16),
                ],

                // 2. SECTION HEADER (Clean Native Enterprise Title)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modul Akuntabilitas K3',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '6 Modul Aktif',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. CLEAN 2-COLUMN GRID OF SAP MODULES
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
      ),
    );
  }



  /// Baris Notifikasi Pending Data Ringkas & Bersih
  Widget _buildPendingAlertBar() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openPendingSyncPage,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_upload_outlined,
                  color: Color(0xFFD97706), size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_pendingCount data lokal siap disinkronkan',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
          TextButton(
            onPressed: _isSyncing ? null : _syncNow,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSyncing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Sinkronkan',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }

  /// Kartu Modul Bersih, Elegan, dan Proporsional
  Widget _buildModuleCard(_SapMenuItemData item) {
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

class _SapMenuItemData {
  final String title;
  final String subtitle;
  final String image;
  final IconData fallbackIcon;
  final Color accentColor;
  final Color bgColor;
  final String route;

  const _SapMenuItemData({
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
