import 'package:flutter/material.dart';

import '../../models/hazard_hub_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/enums.dart';
import '../../widgets/sap_module_ui.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import 'hazard_create_page.dart';
import 'hazard_hub_page.dart';

class HazardPage extends StatefulWidget {
  const HazardPage({super.key});

  @override
  State<HazardPage> createState() => _HazardPageState();
}

class _HazardPageState extends State<HazardPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  HazardSummary _summary = HazardSummary();
  bool _isLoading = true;
  int _offlinePendingCount = 0;
  bool _isSyncingOffline = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);

    // Hitung data lokal yang belum tersinkron
    try {
      final offlineRows = await _db.rawQuery(
        'SELECT count(1) as jml FROM hazard_trans WHERE deleted_at IS NULL AND sync_id IS NULL',
      );
      if (offlineRows.isNotEmpty && offlineRows.first['jml'] != null) {
        _offlinePendingCount = (offlineRows.first['jml'] as int?) ?? 0;
      } else {
        _offlinePendingCount = 0;
      }
    } catch (_) {
      _offlinePendingCount = 0;
    }

    final res = await _api.getHazardHub();

    if (!mounted) return;
    setState(() => _isLoading = false);

    res.fold(
      (_) {},
      (data) {
        if (data['summary'] is Map) {
          setState(() {
            _summary = HazardSummary.fromJson(
              Map<String, dynamic>.from(data['summary'] as Map),
            );
          });
        }
      },
    );
  }

  Future<void> _syncOfflineNow() async {
    setState(() => _isSyncingOffline = true);
    try {
      final res =
          await OfflineSyncService.instance.autoSyncPending(force: true);
      if (!mounted) return;
      if (res.success > 0) {
        SnackBarMsg.success(context,
            '${res.success} Laporan Hazard offline berhasil disinkronkan ke server!');
      } else if (res.failed > 0) {
        SnackBarMsg.danger(context,
            'Sebagian data belum berhasil disinkronkan. Pastikan koneksi ke server stabil.');
      } else {
        SnackBarMsg.info(
            context, 'Tidak ada data offline yang perlu disinkronkan.');
      }
    } catch (e) {
      if (mounted) SnackBarMsg.danger(context, 'Gagal sinkronisasi: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingOffline = false);
        _loadSummary();
      }
    }
  }

  void _openWorkflow(HazardHubTab tab) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HazardHubPage(initialTab: tab),
      ),
    );
    if (mounted) {
      _loadSummary();
    }
  }

  void _openCreateHazard() async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const HazardCreatePage(),
      ),
    );
    if (res == true && mounted) {
      _loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF97316);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TopBar(title: 'Hazard Report'),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _openCreateHazard,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Buat Baru',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        color: accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    child: LinearProgressIndicator(
                      color: accent,
                      backgroundColor: Color(0xFFFED7AA),
                      minHeight: 3,
                    ),
                  ),
                ),

              // Offline Pending Sync Banner jika ada data yang belum tersinkron
              if (_offlinePendingCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_off_rounded,
                            color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_offlinePendingCount Temuan Tersimpan Offline',
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Data belum terkirim ke server.',
                              style: TextStyle(
                                  color: Color(0xFFB45309), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSyncingOffline ? null : _syncOfflineNow,
                        icon: _isSyncingOffline
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.sync_rounded, size: 14),
                        label: Text(
                          _isSyncingOffline ? 'Singkron...' : 'Singkronkan',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // Clean Header (Tanpa background banner pekat)
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Laporan Bahaya',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pantau tugas PJA, proses monitoring, dan riwayat temuan selesai.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // 3 Mini Counters
              Row(
                children: [
                  Expanded(
                    child: _HazardMiniCounter(
                      label: 'Action PJA',
                      value: _summary.totalAction,
                      color: const Color(0xFFF59E0B),
                      onTap: () => _openWorkflow(HazardHubTab.action),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HazardMiniCounter(
                      label: 'Monitoring',
                      value: _summary.totalMonitoring,
                      color: const Color(0xFF0284C7),
                      onTap: () => _openWorkflow(HazardHubTab.monitoring),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HazardMiniCounter(
                      label: 'Summary',
                      value: _summary.totalSummary,
                      color: const Color(0xFF16A34A),
                      onTap: () => _openWorkflow(HazardHubTab.summary),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Section Header
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Alur Kerja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kelola tugas PJA, pantau temuan aktif, dan lihat laporan selesai.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Alur Kerja Card: Action
              _HazardActionCard(
                title: 'Action (Tugas PJA)',
                subtitle:
                    'Tindak lanjuti temuan bahaya yang diarahkan kepada Anda.',
                count: _summary.totalAction,
                icon: Icons.assignment_turned_in_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => _openWorkflow(HazardHubTab.action),
              ),

              // Alur Kerja Card: Monitoring
              _HazardActionCard(
                title: 'Monitoring (Sedang Berproses)',
                subtitle:
                    'Pantau progres temuan Anda yang sedang ditangani PJA.',
                count: _summary.totalMonitoring,
                icon: Icons.monitor_heart_rounded,
                color: const Color(0xFF0284C7),
                onTap: () => _openWorkflow(HazardHubTab.monitoring),
              ),

              // Alur Kerja Card: Summary
              _HazardActionCard(
                title: 'Summary (Laporan Selesai)',
                subtitle:
                    'Arsip riwayat temuan yang sudah tuntas & bukti perbaikan.',
                count: _summary.totalSummary,
                icon: Icons.task_alt_rounded,
                color: const Color(0xFF16A34A),
                onTap: () => _openWorkflow(HazardHubTab.summary),
              ),

              const SizedBox(height: 80), // Padding for FAB
            ],
          ),
        ),
      ),
    );
  }
}

class _HazardMiniCounter extends StatelessWidget {
  const _HazardMiniCounter({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HazardActionCard extends StatelessWidget {
  const _HazardActionCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SapSoftCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SapStatusPill(label: '$count Data', color: color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: Colors.blueGrey.shade300),
          ],
        ),
      ),
    );
  }
}
