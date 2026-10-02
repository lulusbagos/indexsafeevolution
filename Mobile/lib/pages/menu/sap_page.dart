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

    final groupReporting = [
      _FioriItemData(
        title: 'Hazard Report',
        subtitle: 'Pelaporan Bahaya KTA & TTA',
        description: 'Formulir pelaporan temuan kondisi dan tindakan tidak aman secara langsung di lapangan.',
        tag: 'PRIORITAS K3',
        tagColor: const Color(0xFFDC2626),
        tagBgColor: const Color(0xFFFEF2F2),
        image: hazard.image,
        fallbackIcon: Icons.warning_amber_rounded,
        route: hazard.route,
      ),
      _FioriItemData(
        title: 'Observation',
        subtitle: 'Observasi Perilaku K3 (BBS)',
        description: 'Observasi interaksi kerja selamat dan pembudayaan kebiasaan aman antar karyawan.',
        tag: 'BEHAVIOR SAFETY',
        tagColor: const Color(0xFF0D9488),
        tagBgColor: const Color(0xFFF0FDFA),
        image: observation.image,
        fallbackIcon: Icons.visibility_rounded,
        route: observation.route,
      ),
    ];

    final groupInspection = [
      _FioriItemData(
        title: 'Inspection',
        subtitle: 'Inspeksi Keselamatan Terencana',
        description: 'Pemeriksaan standar keselamatan kerja dan kepatuhan prosedur operasional tambang.',
        tag: 'AUDIT TERENCANA',
        tagColor: const Color(0xFF059669),
        tagBgColor: const Color(0xFFECFDF5),
        image: inspection.image,
        fallbackIcon: Icons.fact_check_rounded,
        route: inspection.route,
      ),
      _FioriItemData(
        title: 'Safety Talk',
        subtitle: 'Briefing 5M Pra-Shift',
        description: 'Penyampaian materi komunikasi K3, pengenalan bahaya harian, dan absensi tim shift.',
        tag: 'BRIEFING PRA-SHIFT',
        tagColor: const Color(0xFF4F46E5),
        tagBgColor: const Color(0xFFEEF2FF),
        image: safetyTalk.image,
        fallbackIcon: Icons.record_voice_over_rounded,
        route: safetyTalk.route,
      ),
    ];

    final groupReview = [
      _FioriItemData(
        title: 'Coaching',
        subtitle: 'Bimbingan Konseling K3',
        description: 'Program pendampingan, konseling personal, dan evaluasi kepatuhan keselamatan kerja.',
        tag: 'EDUKASI & COACHING',
        tagColor: const Color(0xFFE11D48),
        tagBgColor: const Color(0xFFFFF1F2),
        image: coaching.image,
        fallbackIcon: Icons.psychology_rounded,
        route: coaching.route,
      ),
      _FioriItemData(
        title: 'SAP Report',
        subtitle: 'Statistik & Rekapitulasi',
        description: 'Laporan komprehensif, evaluasi tren kinerja, dan riwayat akuntabilitas K3 departemen.',
        tag: 'ANALYTICS & REKAP',
        tagColor: const Color(0xFF2563EB),
        tagBgColor: const Color(0xFFEFF6FF),
        image: sapReport.image,
        fallbackIcon: Icons.bar_chart_rounded,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ALERT SYNC HANYA JIKA ADA DATA PENDING
                if (hasPending) ...[
                  _buildPendingAlertBar(),
                  const SizedBox(height: 14),
                ],

                // 2. DOMAIN 1: PELAPORAN BAHAYA & OBSERVASI
                _buildDomainSection(
                  domainTitle: 'Pelaporan & Temuan Lapangan',
                  domainCount: '2 Modul',
                  items: groupReporting,
                ),

                const SizedBox(height: 20),

                // 3. DOMAIN 2: INSPEKSI & EDUKASI K3
                _buildDomainSection(
                  domainTitle: 'Inspeksi & Komunikasi K3',
                  domainCount: '2 Modul',
                  items: groupInspection,
                ),

                const SizedBox(height: 20),

                // 4. DOMAIN 3: PEMBINAAN & REKAPITULASI
                _buildDomainSection(
                  domainTitle: 'Pembinaan & Evaluasi Program',
                  domainCount: '2 Modul',
                  items: groupReview,
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

  /// Section Header & List of Fiori Tiles
  Widget _buildDomainSection({
    required String domainTitle,
    required String domainCount,
    required List<_FioriItemData> items,
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
  Widget _buildFioriWorklistCard(_FioriItemData item) {
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
                        color: const Color(0xFF1E3A8A),
                        size: 26,
                      ),
                    )
                  : Icon(
                      item.fallbackIcon,
                      color: const Color(0xFF1E3A8A),
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

class _FioriItemData {
  final String title;
  final String subtitle;
  final String description;
  final String tag;
  final Color tagColor;
  final Color tagBgColor;
  final String image;
  final IconData fallbackIcon;
  final String route;

  const _FioriItemData({
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

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapCancel: _onTapCancel,
      onTap: () {
        setState(() => _isPressed = false);
        widget.onTap();
      },
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
