import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../services/database.dart';
import '../services/offline_sync_service.dart';
import '../services/violation_receipt_pdf_service.dart';

class ViolationQueuePage extends StatefulWidget {
  final int initialIndex;
  const ViolationQueuePage({super.key, this.initialIndex = 0});

  @override
  State<ViolationQueuePage> createState() => _ViolationQueuePageState();
}

class _ViolationQueuePageState extends State<ViolationQueuePage>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  final _api = ApiService();

  late TabController _tabController;

  // Tab 0: Laporan Saya
  bool _loadingMyViolations = true;
  bool _syncingOffline = false;
  List<Map<String, dynamic>> _offlineItems = [];
  List<Map<String, dynamic>> _myOnlineViolations = [];

  // Tab 1: Persetujuan PJA
  bool _loadingApprovals = true;
  List<Map<String, dynamic>> _pendingApprovals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 1),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMyViolations(),
      _loadPendingApprovals(),
    ]);
  }

  Future<void> _loadMyViolations() async {
    setState(() => _loadingMyViolations = true);
    final offline = await _db.getOfflineViolationHistory();

    final res = await _api.getMyPermitViolations(limit: 50);
    List<Map<String, dynamic>> online = [];
    res.fold((_) {}, (data) {
      online = data;
    });

    if (mounted) {
      setState(() {
        _offlineItems = offline;
        _myOnlineViolations = online;
        _loadingMyViolations = false;
      });
    }
  }

  Future<void> _loadPendingApprovals() async {
    setState(() => _loadingApprovals = true);
    final res = await _api.getPendingPermitViolationApprovals(limit: 50);
    List<Map<String, dynamic>> pending = [];
    res.fold((_) {}, (data) {
      pending = data;
    });

    if (mounted) {
      setState(() {
        _pendingApprovals = pending;
        _loadingApprovals = false;
      });
    }
  }

  Future<void> _syncOfflineQueue() async {
    setState(() => _syncingOffline = true);
    await OfflineSyncService.instance.syncPermitViolationQueue();
    await _loadMyViolations();
    if (mounted) setState(() => _syncingOffline = false);
  }

  Map<String, dynamic> _payload(Map<String, dynamic> row) {
    try {
      final data = jsonDecode(row['payload']?.toString() ?? '{}');
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingOfflineCount =
        _offlineItems.where((e) => e['is_synced'] != 1).length;
    final approvalCount = _pendingApprovals.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pelanggaran & Persetujuan PJA',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Segarkan Data',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0F766E),
          indicatorWeight: 3,
          labelColor: const Color(0xFF0F766E),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Laporan Saya'),
                  if (pendingOfflineCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingOfflineCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Persetujuan PJA'),
                  if (approvalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$approvalCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyViolationsTab(pendingOfflineCount),
          _buildPendingApprovalsTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: LAPORAN SAYA (OFFLINE + ONLINE TRACKING)
  // ==========================================
  Widget _buildMyViolationsTab(int pendingOfflineCount) {
    if (_loadingMyViolations) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadMyViolations,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Banner Status Antrean Offline
          if (pendingOfflineCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined,
                          color: Color(0xFFEA580C), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$pendingOfflineCount laporan offline tersimpan di HP',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _syncingOffline ? null : _syncOfflineQueue,
                      icon: _syncingOffline
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(_syncingOffline
                          ? 'Mengirim laporan...'
                          : 'Kirim Antrean Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Header Laporan Online
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat & Status Laporan',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A)),
              ),
              Text(
                '${_myOnlineViolations.length} Laporan',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_myOnlineViolations.isEmpty && _offlineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada laporan pelanggaran yang diajukan.',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // Render Online Reports
          ..._myOnlineViolations.map((v) => _buildOnlineViolationCard(v)),

          // Render Offline Queue Reports
          if (_offlineItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Arsip Laporan di Perangkat Ini',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            ..._offlineItems.map((row) => _buildOfflineCard(row)),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineViolationCard(Map<String, dynamic> v) {
    final status = v['status']?.toString().toUpperCase() ?? 'PENDING';
    final violatorName = v['violator_name']?.toString() ?? 'Karyawan';
    final violatorNik = v['violator_nik']?.toString() ?? '-';
    final violationType = v['violation_type']?.toString() ?? 'Pelanggaran K3';
    final company = v['violator_company']?.toString() ?? '-';
    final createdAt = v['created_at']?.toString() ?? '-';
    final totalApp = v['total_approvers'] ?? 0;
    final approvedCount = v['approved_count'] ?? 0;
    final approvers = (v['approvers'] as List?) ?? [];

    Color badgeColor;
    Color badgeTextColor;
    String badgeText;
    IconData badgeIcon;

    if (status == 'APPROVED') {
      badgeColor = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF047857);
      badgeText = 'DISETUJUI (MASUK SISTEM)';
      badgeIcon = Icons.verified_rounded;
    } else if (status == 'REJECTED') {
      badgeColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFDC2626);
      badgeText = 'DITOLAK PJA';
      badgeIcon = Icons.cancel_rounded;
    } else {
      badgeColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
      badgeText = 'MENUNGGU PJA ($approvedCount/$totalApp)';
      badgeIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'APPROVED'
              ? const Color(0xFFA7F3D0)
              : (status == 'REJECTED'
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE2E8F0)),
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
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showViolationDetailSheet(v),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: badgeColor,
                      child: Icon(badgeIcon, color: badgeTextColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            violatorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'NIK: $violatorNik • $company',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  violationType,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dibuat $createdAt',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeTextColor),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: badgeTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (approvers.isNotEmpty) ...[
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'PJA Penanggung Jawab ($totalApp orang):',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: approvers.map((app) {
                      final appStatus =
                          app['status']?.toString().toUpperCase() ?? 'PENDING';
                      final appName =
                          app['approver_name']?.toString() ?? 'PJA';
                      Color stColor = appStatus == 'APPROVED'
                          ? const Color(0xFF059669)
                          : (appStatus == 'REJECTED'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFD97706));
                      IconData stIcon = appStatus == 'APPROVED'
                          ? Icons.check_circle_rounded
                          : (appStatus == 'REJECTED'
                              ? Icons.cancel_rounded
                              : Icons.schedule_rounded);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: stColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: stColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(stIcon, size: 11, color: stColor),
                            const SizedBox(width: 4),
                            Text(
                              appName,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: stColor),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineCard(Map<String, dynamic> row) {
    final data = _payload(row);
    final synced = row['is_synced'] == 1;
    final name = data['violatorName']?.toString() ?? 'Karyawan';
    final type = data['kriteriaNama']?.toString() ?? 'Pelanggaran K3';
    final created = row['created_at']
            ?.toString()
            .replaceFirst('T', ' ')
            .split('.')
            .first ??
        '-';
    final pdfPath = data['localReceiptPath']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                synced
                    ? Icons.check_circle_rounded
                    : Icons.schedule_send_rounded,
                color: synced
                    ? const Color(0xFF059669)
                    : const Color(0xFFEA580C),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: synced
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  synced ? 'TERSINKRON' : 'ANTREAN OFFLINE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: synced
                        ? const Color(0xFF047857)
                        : const Color(0xFFC2410C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(type,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text('Tercatat $created',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          if (pdfPath.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final latestPdf =
                    await ViolationReceiptPdfService.create(data);
                await ViolationReceiptPdfService.share(latestPdf);
              },
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Bagikan Bukti PDF',
                  style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PERSETUJUAN PJA (APPROVAL INBOX)
  // ==========================================
  Widget _buildPendingApprovalsTab() {
    if (_loadingApprovals) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadPendingApprovals,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: Color(0xFF0F766E), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pendingApprovals.isEmpty
                        ? 'Tidak ada permohonan persetujuan pelanggaran saat ini.'
                        : '${_pendingApprovals.length} laporan pelanggaran membutuhkan persetujuan Anda sebagai PJA.',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF0F766E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_pendingApprovals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 60, color: Colors.teal.shade200),
                    const SizedBox(height: 12),
                    const Text(
                      'Semua Laporan Telah Diproses',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Anda tidak memiliki antrean persetujuan pelanggaran yang tertunda.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          ..._pendingApprovals.map((item) => _buildApprovalCard(item)),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> item) {
    final violationId = item['violation_id'] as int;
    final violatorName = item['violator_name']?.toString() ?? 'Karyawan';
    final violatorNik = item['violator_nik']?.toString() ?? '-';
    final company = item['violator_company']?.toString() ?? '-';
    final department = item['violator_department']?.toString() ?? '-';
    final permitNumber = item['permit_number']?.toString() ?? '-';
    final violationType =
        item['violation_type']?.toString() ?? 'Pelanggaran K3';
    final desc = item['violation_description']?.toString() ?? '-';
    final location = item['violation_location']?.toString() ?? 'Area Tambang';
    final actionTaken = item['action_taken']?.toString() ?? '-';
    final reportedByName = item['reported_by_name']?.toString() ?? 'Pengawas';
    final createdAt = item['created_at']?.toString() ?? '-';
    final totalApp = item['total_approvers'] ?? 1;
    final approvedCount = item['approved_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar Pelanggaran
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    violationType,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFFDC2626)),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'PJA: $approvedCount/$totalApp',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Violator Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      child: const Icon(Icons.person_rounded,
                          color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            violatorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'NIK: $violatorNik • $company',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          if (department.isNotEmpty && department != '-')
                            Text('Dept: $department',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
                          if (permitNumber.isNotEmpty && permitNumber != '-')
                            Text('No Permit: $permitNumber',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                _detailRow('Lokasi Kejadian', location),
                const SizedBox(height: 6),
                _detailRow('Uraian Kejadian', desc),
                const SizedBox(height: 6),
                _detailRow('Tindakan Awal', actionTaken),
                const SizedBox(height: 6),
                _detailRow('Dilaporkan Oleh', '$reportedByName ($createdAt)'),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmAction(
                          violationId: violationId,
                          action: 'REJECT',
                          violatorName: violatorName,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Tolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmAction(
                          violationId: violationId,
                          action: 'APPROVE',
                          violatorName: violatorName,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Setujui Pelanggaran'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B))),
        const SizedBox(height: 1),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B))),
      ],
    );
  }

  // ==========================================
  // CONFIRM ACTION (APPROVE / REJECT)
  // ==========================================
  void _confirmAction({
    required int violationId,
    required String action,
    required String violatorName,
  }) {
    final bool isReject = action == 'REJECT';
    final notesCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              isReject
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline_rounded,
              color: isReject ? const Color(0xFFDC2626) : const Color(0xFF059669),
            ),
            const SizedBox(width: 8),
            Text(
              isReject ? 'Tolak Pelanggaran' : 'Setujui Pelanggaran',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReject
                  ? 'Apakah Anda yakin ingin menolak laporan pelanggaran atas nama $violatorName?'
                  : 'Dengan menyetujui laporan ini, jika seluruh PJA yang ditunjuk telah menyetujui, catatan pelanggaran akan resmi masuk ke database sistem.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isReject
                    ? 'Wajib berikan alasan penolakan...'
                    : 'Catatan PJA (opsional)...',
                hintStyle: const TextStyle(fontSize: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (isReject && notesCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan penolakan wajib diisi.'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                return;
              }

              Navigator.pop(dialogCtx);
              HapticFeedback.mediumImpact();

              final res = await _api.actionPermitViolationApproval(
                violationId,
                action,
                notes: notesCtrl.text.trim(),
              );

              res.fold(
                (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err['message']?.toString() ??
                          'Gagal memproses persetujuan.'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                },
                (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success['message']?.toString() ??
                          'Persetujuan berhasil disimpan.'),
                      backgroundColor: isReject
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                  );
                  _loadAll();
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isReject
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: Text(isReject ? 'Ya, Tolak' : 'Ya, Setujui'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DETAIL BOTTOM SHEET
  // ==========================================
  void _showViolationDetailSheet(Map<String, dynamic> v) {
    final violatorName = v['violator_name']?.toString() ?? 'Karyawan';
    final violatorNik = v['violator_nik']?.toString() ?? '-';
    final company = v['violator_company']?.toString() ?? '-';
    final dept = v['violator_department']?.toString() ?? '-';
    final permit = v['permit_number']?.toString() ?? '-';
    final type = v['violation_type']?.toString() ?? 'Pelanggaran K3';
    final desc = v['violation_description']?.toString() ?? '-';
    final location = v['violation_location']?.toString() ?? 'Area Tambang';
    final action = v['action_taken']?.toString() ?? '-';
    final status = v['status']?.toString().toUpperCase() ?? 'PENDING';
    final approvers = (v['approvers'] as List?) ?? [];
    final rejectionReason = v['rejection_reason']?.toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detail Status Pelanggaran',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  _detailRow('Karyawan Pelanggar', '$violatorName ($violatorNik)'),
                  const SizedBox(height: 10),
                  _detailRow('Perusahaan & Departemen', '$company • $dept'),
                  const SizedBox(height: 10),
                  if (permit.isNotEmpty && permit != '-') ...[
                    _detailRow('Nomor Mine Permit', permit),
                    const SizedBox(height: 10),
                  ],
                  _detailRow('Kriteria Pelanggaran', type),
                  const SizedBox(height: 10),
                  _detailRow('Lokasi Kejadian', location),
                  const SizedBox(height: 10),
                  _detailRow('Kronologi / Uraian', desc),
                  const SizedBox(height: 10),
                  _detailRow('Tindakan Diambil', action),
                  const SizedBox(height: 14),

                  if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFDC2626), size: 16),
                              SizedBox(width: 6),
                              Text('Alasan Penolakan:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(rejectionReason,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // PJA Status List
                  const Text(
                    'Status Persetujuan PJA Lapangan:',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),

                  ...approvers.map((app) {
                    final appStatus =
                        app['status']?.toString().toUpperCase() ?? 'PENDING';
                    final appName = app['approver_name']?.toString() ?? 'PJA';
                    final appNik = app['approver_nik']?.toString() ?? '-';
                    final appPos = app['approver_position']?.toString() ??
                        app['approver_department']?.toString() ??
                        'Pengawas';
                    final notes = app['notes']?.toString();
                    final actionAt = app['action_at']?.toString();

                    Color stColor = appStatus == 'APPROVED'
                        ? const Color(0xFF059669)
                        : (appStatus == 'REJECTED'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706));
                    String stLabel = appStatus == 'APPROVED'
                        ? 'Disetujui'
                        : (appStatus == 'REJECTED'
                            ? 'Ditolak'
                            : 'Menunggu Persetujuan');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: stColor.withValues(alpha: 0.15),
                            child: Icon(
                              appStatus == 'APPROVED'
                                  ? Icons.check_circle_rounded
                                  : (appStatus == 'REJECTED'
                                      ? Icons.cancel_rounded
                                      : Icons.schedule_rounded),
                              size: 18,
                              color: stColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                                Text('NIK: $appNik • $appPos',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF64748B))),
                                if (notes != null && notes.isNotEmpty)
                                  Text('Catatan: "$notes"',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic)),
                                if (actionAt != null && actionAt.isNotEmpty)
                                  Text('Diproses $actionAt',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: stColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: stColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
