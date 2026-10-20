import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/inspection_hub_model.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../utils/enums.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import 'inspeksi_form_page.dart';

enum InspectionHubTab { summary, myReports, pjaArea }

class InspectionHubPage extends StatefulWidget {
  const InspectionHubPage({
    this.initialTab = InspectionHubTab.summary,
    super.key,
  });

  final InspectionHubTab initialTab;

  @override
  State<InspectionHubPage> createState() => _InspectionHubPageState();
}

class _InspectionHubPageState extends State<InspectionHubPage> {
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  final _searchCtrl = TextEditingController();

  late InspectionHubTab _currentTab;
  InspectionSummary _summary = InspectionSummary();
  List<InspectionReportItem> _items = [];
  bool _isLoading = true;
  String _activeFilter = 'all'; // sub-filter within the tab
  int _offlineCount = 0;
  bool _isSyncingOffline = false;

  static const Color primaryGreen = Color(0xFF0F766E); // Deep Teal / Emerald

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final profileId = _profile?.id ?? 0;
    final userNik = _profile?.noNik ?? '';

    try {
      final db = await _db.database;

      // 1. Hitung jumlah pending offline
      final offlineRows = await db.rawQuery(
        "SELECT count(1) as jml FROM inspection_trans WHERE deleted_at IS NULL AND sync_id IS NULL",
      );
      _offlineCount = (offlineRows.isNotEmpty && offlineRows.first['jml'] != null)
          ? (offlineRows.first['jml'] as int)
          : 0;

      // 2. Hitung metrics KPI inspeksi:
      // a. Saya Buat (Pelapor / Auditor)
      final myInspectionsRows = await db.rawQuery('''
        SELECT count(1) as jml FROM inspection_trans 
        WHERE deleted_at IS NULL 
          AND (employee_id = $profileId OR employee_id IS NULL OR employee_id = 0 OR nik = '$userNik')
      ''');
      final int totalMyInspections = (myInspectionsRows.isNotEmpty && myInspectionsRows.first['jml'] != null)
          ? (myInspectionsRows.first['jml'] as int)
          : 0;

      // b. Sebagai PJA (Area saya yang diinspeksi - Murni nilai kepatuhan, tanpa alur tindakan)
      final pjaRows = await db.rawQuery('''
        SELECT count(1) as jml FROM inspection_trans 
        WHERE deleted_at IS NULL 
          AND (nik_pja = '$userNik' OR pja_id = $profileId)
      ''');
      final int totalPjaInspections = (pjaRows.isNotEmpty && pjaRows.first['jml'] != null)
          ? (pjaRows.first['jml'] as int)
          : 0;

      // c. Total keseluruhan inspeksi yang tersimpan
      final summaryRows = await db.rawQuery('''
        SELECT count(1) as jml FROM inspection_trans 
        WHERE deleted_at IS NULL
      ''');
      final int totalSummary = (summaryRows.isNotEmpty && summaryRows.first['jml'] != null)
          ? (summaryRows.first['jml'] as int)
          : 0;

      // 3. Baca daftar data sesuai tab aktif
      String filterQuery = '';
      switch (_currentTab) {
        case InspectionHubTab.summary:
          filterQuery = ''; // Seluruh inspeksi
          break;
        case InspectionHubTab.myReports:
          filterQuery = "AND (employee_id = $profileId OR employee_id IS NULL OR employee_id = 0 OR nik = '$userNik')";
          break;
        case InspectionHubTab.pjaArea:
          filterQuery = "AND (nik_pja = '$userNik' OR pja_id = $profileId)";
          break;
      }

      final rows = await db.rawQuery('''
        SELECT * FROM inspection_trans 
        WHERE deleted_at IS NULL 
        $filterQuery
        ORDER BY id DESC
        LIMIT 150
      ''');

      final List<InspectionReportItem> loaded = [];
      for (var r in rows) {
        final scores = <String, int>{};
        for (int m = 1; m <= 5; m++) {
          for (int q = 1; q <= 3; q++) {
            final k = 'q${m}_$q';
            if (r[k] != null) {
              scores[k] = int.tryParse(r[k].toString()) ?? 1;
            }
          }
        }

        List<Map<String, dynamic>> customQuestions = [];
        if (r['payload_json'] != null && r['payload_json'].toString().isNotEmpty) {
          try {
            final payload = jsonDecode(r['payload_json'].toString()) as Map;
            if (payload['custom_questions'] is List) {
              customQuestions = List<Map<String, dynamic>>.from(payload['custom_questions']);
            }
          } catch (_) {}
        }

        final isOffline = r['sync_id'] == null;
        final myNik = _profile?.noNik ?? '';
        final isMine = r['nik'] == myNik || r['employee_id'] == profileId;
        final isPja = r['nik_pja'] == myNik || r['pja_id'] == profileId;

        loaded.add(InspectionReportItem(
          id: r['id'] as int,
          code: r['code']?.toString() ?? 'INSP-${r['id']}',
          tanggal: r['date']?.toString() ?? r['tanggal']?.toString() ?? '',
          waktu: r['time']?.toString() ?? r['waktu']?.toString() ?? '',
          nama: r['nama']?.toString() ?? _profile?.namaLengkap ?? 'Pengawas',
          nik: r['nik']?.toString() ?? _profile?.noNik ?? '00000',
          departemen: r['departemen_pja']?.toString(),
          area: r['area']?.toString() ?? 'PIT AREA',
          lokasi: r['lokasi']?.toString() ?? 'LOKASI KERJA',
          detilLokasi: r['location_detail']?.toString() ?? r['detil_lokasi']?.toString(),
          jenisInspeksi: r['title']?.toString() ?? r['jenis_inspeksi']?.toString() ?? 'INSPEKSI TERENCANA',
          pja: r['pja']?.toString(),
          nikPja: r['nik_pja']?.toString(),
          departemenPja: r['departemen_pja']?.toString(),
          catatan: r['remark']?.toString() ?? r['catatan']?.toString(),
          image: r['image']?.toString(),
          scores: scores,
          customQuestions: customQuestions,
          isOfflinePending: isOffline,
          isMyReport: isMine,
          isAssignedToMe: isPja,
          createdAt: r['created_at']?.toString(),
        ));
      }

      int sumScore = 0;
      int totalItemsWithScore = 0;
      int allFindings = 0;
      for (var item in loaded) {
        sumScore += item.compliancePercent;
        totalItemsWithScore++;
        allFindings += item.totalFindings;
      }
      final avg = totalItemsWithScore > 0 ? (sumScore / totalItemsWithScore).round() : 100;

      _summary = InspectionSummary(
        totalSummary: totalSummary,
        totalMyInspections: totalMyInspections,
        totalPjaInspections: totalPjaInspections,
        totalFindings: allFindings,
        averageScore: avg,
      );

      if (mounted) {
        setState(() {
          _items = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[InspectionHub] Error loading: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<InspectionReportItem> get _filteredItems {
    var list = _items;

    // Sub-filters
    if (_activeFilter == 'offline_pending') {
      list = list.where((i) => i.isOfflinePending).toList();
    } else if (_activeFilter == 'my_reports') {
      list = list.where((i) => i.isMyReport).toList();
    } else if (_activeFilter == 'pja_reports') {
      list = list.where((i) => i.isAssignedToMe).toList();
    } else if (_activeFilter == 'findings') {
      list = list.where((i) => i.totalFindings > 0).toList();
    } else if (_activeFilter == 'perfect') {
      list = list.where((i) => i.totalFindings == 0).toList();
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;

    return list.where((i) {
      return i.jenisInspeksi.toLowerCase().contains(q) ||
          i.area.toLowerCase().contains(q) ||
          i.lokasi.toLowerCase().contains(q) ||
          (i.pja?.toLowerCase().contains(q) ?? false) ||
          (i.catatan?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _syncAllOffline() async {
    setState(() => _isSyncingOffline = true);
    try {
      final res = await OfflineSyncService.instance.autoSyncPending();
      if (!mounted) return;
      if (res.success > 0) {
        SnackBarMsg.success(context, '${res.success} Laporan Inspeksi lokal berhasil disinkronkan ke server!');
      } else if (res.failed > 0) {
        SnackBarMsg.danger(context, 'Sebagian data belum berhasil disinkronkan. Periksa koneksi ke server.');
      } else {
        SnackBarMsg.info(context, 'Tidak ada data offline yang perlu disinkronkan.');
      }
    } catch (e) {
      if (mounted) SnackBarMsg.danger(context, 'Gagal sinkronisasi: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingOffline = false);
        _loadData();
      }
    }
  }

  void _openCreateInspeksi() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const InspeksiFormPage(Module.inspection)),
    );
    if (result == true && mounted) {
      setState(() {
        _currentTab = InspectionHubTab.myReports;
        _activeFilter = 'all';
      });
      _loadData();
    }
  }

  // --- UI BUILDER METHODS IDENTIK DENGAN HAZARD HUB ---

  Widget _buildTabItem(InspectionHubTab tab, String label, int count, Color activeColor, {int offlinePending = 0}) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_currentTab != tab) {
            setState(() {
              _currentTab = tab;
              _activeFilter = 'all';
            });
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFCBD5E1).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count Data',
                      style: TextStyle(
                        color: isSelected ? activeColor : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (offlinePending > 0) ...[
                    const SizedBox(width: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 9),
                          const SizedBox(width: 1),
                          Text(
                            '+$offlinePending',
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge(
    String label,
    int count,
    Color color,
    Color bg,
    Color border,
    IconData icon, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextHeaderCard() {
    IconData icon;
    Color iconColor;
    Color iconBg;
    String title;
    String subtitle;
    List<Widget> badges = [];

    switch (_currentTab) {
      case InspectionHubTab.summary:
        icon = Icons.task_alt_rounded;
        iconColor = primaryGreen;
        iconBg = const Color(0xFFECFDF5);
        title = 'Summary (Rekapitulasi Kepatuhan)';
        subtitle = 'Kompilasi audit K3 & persentase kepatuhan operasional';
        badges = [
          _buildMetricBadge(
            'Rata-rata Nilai',
            _summary.averageScore,
            primaryGreen,
            const Color(0xFFECFDF5),
            const Color(0xFFA7F3D0),
            Icons.verified_rounded,
            isSelected: _activeFilter == 'all',
            onTap: () => setState(() => _activeFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            'Saya Buat',
            _summary.totalMyInspections,
            const Color(0xFF0284C7),
            const Color(0xFFF0F9FF),
            const Color(0xFFBAE6FD),
            Icons.summarize_rounded,
            isSelected: _activeFilter == 'my_reports',
            onTap: () => setState(() => _activeFilter = _activeFilter == 'my_reports' ? 'all' : 'my_reports'),
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            'PJA Area',
            _summary.totalPjaInspections,
            const Color(0xFF0F766E),
            const Color(0xFFF0FDFA),
            const Color(0xFF99F6E4),
            Icons.fact_check_rounded,
            isSelected: _activeFilter == 'pja_reports',
            onTap: () => setState(() => _activeFilter = _activeFilter == 'pja_reports' ? 'all' : 'pja_reports'),
          ),
        ];
        break;

      case InspectionHubTab.myReports:
        icon = Icons.assignment_ind_rounded;
        iconColor = const Color(0xFF0284C7);
        iconBg = const Color(0xFFF0F9FF);
        title = 'Laporan Saya (Auditor)';
        subtitle = 'Inspeksi yang Anda laksanakan sebagai pemeriksa di lapangan';
        badges = [
          _buildMetricBadge(
            'Total Laporan',
            _summary.totalMyInspections,
            const Color(0xFF0284C7),
            const Color(0xFFF0F9FF),
            const Color(0xFFBAE6FD),
            Icons.assignment_turned_in_rounded,
            isSelected: _activeFilter == 'all',
            onTap: () => setState(() => _activeFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            '100% Sesuai',
            _items.where((i) => i.isMyReport && i.totalFindings == 0).length,
            primaryGreen,
            const Color(0xFFECFDF5),
            const Color(0xFFA7F3D0),
            Icons.verified_rounded,
            isSelected: _activeFilter == 'perfect',
            onTap: () => setState(() => _activeFilter = _activeFilter == 'perfect' ? 'all' : 'perfect'),
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            'Ada Temuan',
            _items.where((i) => i.isMyReport && i.totalFindings > 0).length,
            const Color(0xFFDC2626),
            const Color(0xFFFEF2F2),
            const Color(0xFFFECACA),
            Icons.warning_amber_rounded,
            isSelected: _activeFilter == 'findings',
            onTap: () => setState(() => _activeFilter = _activeFilter == 'findings' ? 'all' : 'findings'),
          ),
        ];
        break;

      case InspectionHubTab.pjaArea:
        icon = Icons.fact_check_rounded;
        iconColor = const Color(0xFF0F766E);
        iconBg = const Color(0xFFF0FDFA);
        title = 'PJA Area Saya (Yang Diinspeksi)';
        subtitle = 'Pemeriksaan kepatuhan K3 di area kerja Anda sebagai PJA';
        badges = [
          _buildMetricBadge(
            'Inspeksi Area',
            _summary.totalPjaInspections,
            const Color(0xFF0F766E),
            const Color(0xFFF0FDFA),
            const Color(0xFF99F6E4),
            Icons.pin_drop_rounded,
            isSelected: _activeFilter == 'all',
            onTap: () => setState(() => _activeFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            '100% Sesuai',
            _items.where((i) => i.isAssignedToMe && i.totalFindings == 0).length,
            primaryGreen,
            const Color(0xFFECFDF5),
            const Color(0xFFA7F3D0),
            Icons.check_circle_rounded,
            isSelected: _activeFilter == 'perfect',
            onTap: () => setState(() => _activeFilter = _activeFilter == 'perfect' ? 'all' : 'perfect'),
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            'Ada Temuan',
            _items.where((i) => i.isAssignedToMe && i.totalFindings > 0).length,
            const Color(0xFFD97706),
            const Color(0xFFFFFBEB),
            const Color(0xFFFDE68A),
            Icons.warning_amber_rounded,
            isSelected: _activeFilter == 'findings',
            onTap: () => setState(() => _activeFilter = _activeFilter == 'findings' ? 'all' : 'findings'),
          ),
        ];
        break;
    }

    if (_offlineCount > 0) {
      badges.add(const SizedBox(width: 8));
      badges.add(
        _buildMetricBadge(
          'Belum Sinkron',
          _offlineCount,
          const Color(0xFFD97706),
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          Icons.cloud_off_rounded,
          isSelected: _activeFilter == 'offline_pending',
          onTap: () {
            setState(() => _activeFilter = _activeFilter == 'offline_pending' ? 'all' : 'offline_pending');
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: badges),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryGreen : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFilterChipsForCurrentTab() {
    switch (_currentTab) {
      case InspectionHubTab.summary:
        return [
          _buildFilterChip('all', 'Semua Data (${_summary.totalSummary})'),
          const SizedBox(width: 6),
          _buildFilterChip('my_reports', 'Saya Buat (${_summary.totalMyInspections})'),
          const SizedBox(width: 6),
          _buildFilterChip('pja_reports', 'Sebagai PJA (${_summary.totalPjaInspections})'),
          const SizedBox(width: 6),
          _buildFilterChip('findings', 'Ada Temuan K3'),
          const SizedBox(width: 6),
          _buildFilterChip('perfect', '100% Sesuai'),
          if (_offlineCount > 0) ...[
            const SizedBox(width: 6),
            _buildFilterChip('offline_pending', 'Draft Offline ($_offlineCount)'),
          ],
        ];
      case InspectionHubTab.myReports:
        return [
          _buildFilterChip('all', 'Semua Laporan (${_summary.totalMyInspections})'),
          const SizedBox(width: 6),
          _buildFilterChip('perfect', '100% Sesuai'),
          const SizedBox(width: 6),
          _buildFilterChip('findings', 'Ada Temuan K3'),
          if (_offlineCount > 0) ...[
            const SizedBox(width: 6),
            _buildFilterChip('offline_pending', 'Draft Offline ($_offlineCount)'),
          ],
        ];
      case InspectionHubTab.pjaArea:
        return [
          _buildFilterChip('all', 'Semua Area Saya (${_summary.totalPjaInspections})'),
          const SizedBox(width: 6),
          _buildFilterChip('perfect', '100% Sesuai'),
          const SizedBox(width: 6),
          _buildFilterChip('findings', 'Ada Temuan di Area'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    String pageTitle;
    switch (_currentTab) {
      case InspectionHubTab.summary:
        pageTitle = 'Summary Inspeksi';
        break;
      case InspectionHubTab.myReports:
        pageTitle = 'Inspeksi Saya (Auditor)';
        break;
      case InspectionHubTab.pjaArea:
        pageTitle = 'PJA Area Saya';
        break;
    }

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: TopBar(title: pageTitle),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text('Inspeksi Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          onPressed: _openCreateInspeksi,
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: primaryGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Clean Summary Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern 3-Tab Segmented Selector Identik dengan Hazard
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildTabItem(InspectionHubTab.summary, 'Summary', _summary.totalSummary, primaryGreen),
                            _buildTabItem(InspectionHubTab.myReports, 'Saya Buat', _summary.totalMyInspections, const Color(0xFF0284C7), offlinePending: _offlineCount),
                            _buildTabItem(InspectionHubTab.pjaArea, 'Sebagai PJA', _summary.totalPjaInspections, const Color(0xFF0F766E)),
                          ],
                        ),
                      ),

                      if (_offlineCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
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
                                child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_offlineCount Laporan Tersimpan di HP (Mode Offline)',
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tersimpan saat tidak ada sinyal. Tekan tombol ini atau otomatis terkirim saat online.',
                                      style: TextStyle(color: Color(0xFFB45309), fontSize: 10.5),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isSyncingOffline ? null : _syncAllOffline,
                                icon: _isSyncingOffline
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.sync_rounded, size: 14),
                                label: Text(
                                  _isSyncingOffline ? 'Singkron...' : 'Singkronkan',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Contextual Header Card (Ringkasan Tab Dinamis)
                      _buildContextHeaderCard(),

                      const SizedBox(height: 12),

                      // Search Box Identik dengan Hazard
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                          onSubmitted: (_) => _loadData(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _loadData();
                                    },
                                  )
                                : null,
                            hintText: 'Cari jenis inspeksi, area, lokasi, PJA...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Filter Chips Horizontal
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _buildFilterChipsForCurrentTab(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Inspection Items List
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                )
              else if (_filteredItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded, size: 50, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 10),
                        Text(
                          _currentTab == InspectionHubTab.pjaArea
                              ? 'Belum ada riwayat inspeksi di area kerja Anda.'
                              : _currentTab == InspectionHubTab.myReports
                                  ? 'Anda belum membuat laporan inspeksi.'
                                  : 'Belum ada data pemeriksaan inspeksi tercatat.',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tekan tombol Inspeksi Baru di bawah untuk memulai.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 84),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final item = _filteredItems[idx];
                        return _buildInspectionCard(item);
                      },
                      childCount: _filteredItems.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionCard(InspectionReportItem item) {
    final pct = item.compliancePercent;
    final isOffline = item.isOfflinePending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffline ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isOffline ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showDetailModal(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Jenis & Sync Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fact_check_rounded, color: primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.jenisInspeksi.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.tanggal} • ${item.waktu}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOffline ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                            size: 11,
                            color: isOffline ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isOffline ? 'Draft Offline' : 'Sinkron',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOffline ? const Color(0xFFB45309) : const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Area & Lokasi
                Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 14, color: primaryGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.area} • ${item.lokasi}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (item.pja != null && item.pja!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'PJA: ${item.pja}${item.departemenPja != null ? ' (${item.departemenPja})' : ''}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Bottom Row: Kepatuhan Badge & Lihat Detail
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.totalFindings == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.totalFindings == 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Text(
                        item.totalFindings == 0 ? '100% Sesuai' : '${item.totalFindings} Temuan K3 (${pct.toInt()}%)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: item.totalFindings == 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const Row(
                      children: [
                        Text('Lihat Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryGreen)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 12, color: primaryGreen),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailModal(InspectionReportItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.assignment_turned_in_rounded, color: primaryGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.jenisInspeksi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                            Text('${item.area} • ${item.lokasi}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 14),

                  // Detail Field Info
                  _buildDetailRow('Tanggal & Waktu', '${item.tanggal} ${item.waktu}'),
                  _buildDetailRow('Area Utama', item.area),
                  _buildDetailRow('Detail Lokasi', item.lokasi),
                  if (item.detilLokasi != null) _buildDetailRow('Lokasi Spesifik', item.detilLokasi!),
                  if (item.pja != null) _buildDetailRow('PJA', '${item.pja} (${item.departemenPja ?? '-'})'),
                  if (item.catatan != null && item.catatan!.isNotEmpty) _buildDetailRow('Catatan', item.catatan!),

                  const SizedBox(height: 16),
                  const Text('Evaluasi Checkpoint K3', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  ...item.scores.entries.map((e) {
                    final isYes = e.value == 2;
                    final isNa = e.value == 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text('Pertanyaan Checkpoint ${e.key}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isYes ? const Color(0xFFECFDF5) : (isNa ? const Color(0xFFF1F5F9) : const Color(0xFFFEF2F2)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isYes ? 'YA' : (isNa ? 'N/A' : 'TIDAK'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isYes ? const Color(0xFF059669) : (isNa ? const Color(0xFF64748B) : const Color(0xFFDC2626)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (item.image != null && item.image!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('Foto Lampiran Bukti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.image!.startsWith('http')
                          ? Image.network(item.image!, height: 160, width: double.infinity, fit: BoxFit.cover)
                          : Image.file(File(item.image!), height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }
}
