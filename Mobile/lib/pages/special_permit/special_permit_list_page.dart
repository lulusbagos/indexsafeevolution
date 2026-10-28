import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/preference.dart';
import 'special_permit_followup_page.dart';

class SpecialPermitListPage extends StatefulWidget {
  const SpecialPermitListPage({super.key});

  @override
  State<SpecialPermitListPage> createState() => _SpecialPermitListPageState();
}

class _SpecialPermitListPageState extends State<SpecialPermitListPage> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  List<dynamic> _permits = [];
  String _selectedFilter = 'ALL'; // ALL, WAITING_INSPECTION, INSPECTED
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPermits();
  }

  Future<void> _loadPermits() async {
    setState(() => _isLoading = true);
    final res = await _api.getSpecialPermits(
      search: _searchQuery,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    final profile = PreferenceService.getProfile();
    final user = PreferenceService.getUser();
    final myNik = (user ?? profile?.noNik ?? PreferenceService.getOfflineNik() ?? '').trim();

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message']?.toString() ?? 'Gagal memuat daftar special permit'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      },
      (data) {
        final list = (data['data'] as List<dynamic>?) ?? [];
        setState(() {
          // Hanya tampilkan permit yang NIK kita terdaftar jadi inspector_nik atau pjo_nik
          if (myNik.isNotEmpty) {
            _permits = list.where((p) {
              final pjo = (p['pjoNik'] ?? '').toString().trim();
              final insp = (p['inspectorNik'] ?? '').toString().trim();
              return pjo == myNik || pjo.endsWith(myNik) || myNik.endsWith(pjo) ||
                     insp == myNik || insp.endsWith(myNik) || myNik.endsWith(insp);
            }).toList();
          } else {
            _permits = [];
          }
        });
      },
    );
  }

  List<dynamic> get _filteredPermits {
    if (_selectedFilter == 'WAITING_INSPECTION') {
      return _permits.where((p) => p['hasFollowup'] != true).toList();
    }
    if (_selectedFilter == 'INSPECTED') {
      return _permits.where((p) => p['hasFollowup'] == true).toList();
    }
    return _permits;
  }

  Color _getActivityColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('KETINGGIAN')) return const Color(0xFFDC2626); // Merah
    if (t.contains('AIR')) return const Color(0xFF0284C7); // Biru
    if (t.contains('TERBATAS') || t.contains('CONFINED')) return const Color(0xFFD97706); // Amber
    if (t.contains('PANAS') || t.contains('HOT')) return const Color(0xFFEA580C); // Orange
    return const Color(0xFF7C3AED); // Ungu
  }

  @override
  Widget build(BuildContext context) {
    final displayedList = _filteredPermits;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Special Permit & High Risk',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Segarkan',
            onPressed: _loadPermits,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Peringatan High Risk
          _buildHighRiskBanner(),

          // Filter Chips & Search Bar
          _buildSearchAndFilters(),

          // List Special Permit
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D4ED8)))
                : displayedList.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPermits,
                        color: const Color(0xFF1D4ED8),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                          itemCount: displayedList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = displayedList[index] as Map<String, dynamic>;
                            return _buildSpecialPermitCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighRiskBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peringatan Pekerjaan Risiko Tinggi',
                    style: TextStyle(color: Color(0xFF991B1B), fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PJO & Inspector wajib melakukan inspeksi lapangan sebelum & selama pekerjaan berlangsung.',
                    style: TextStyle(color: Color(0xFFB91C1C), fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: [
          // Search Input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (val) {
                setState(() => _searchQuery = val.trim());
                _loadPermits();
              },
              decoration: InputDecoration(
                hintText: 'Cari Req ID, Lokasi, Kontraktor...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadPermits();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filter Segmented Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Semua (${_permits.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'WAITING_INSPECTION',
                  'Perlu Inspeksi (${_permits.where((p) => p['hasFollowup'] != true).length})',
                  isUrgent: true,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'INSPECTED',
                  'Sudah Diinspeksi (${_permits.where((p) => p['hasFollowup'] == true).length})',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isUrgent = false}) {
    final isSelected = _selectedFilter == key;
    Color activeBg = isUrgent ? const Color(0xFFEF4444) : const Color(0xFF1D4ED8);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBg : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeBg.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialPermitCard(Map<String, dynamic> item) {
    final activityType = (item['activityType'] ?? 'SPECIAL PERMIT').toString().replaceAll('_', ' ');
    final actColor = _getActivityColor(activityType);
    final reqId = item['reqId']?.toString() ?? '-';
    final location = item['workLocation']?.toString() ?? '-';
    final contractor = item['implementingContractor']?.toString() ?? '-';
    final pjoName = item['pjoName']?.toString() ?? '-';
    final inspectorName = item['inspectorName']?.toString() ?? '-';
    final hasFollowup = item['hasFollowup'] == true;
    final latestStatus = item['latestInspectionStatus']?.toString();
    final latestInspector = (item['latestInspectorName']?.toString().isNotEmpty == true)
        ? item['latestInspectorName'].toString()
        : (item['inspectorName']?.toString() ?? '-');
    final latestRole = item['latestInspectorRole']?.toString() ?? 'INSPECTOR';

    DateTime? startDate;
    if (item['startDate'] != null) {
      startDate = DateTime.tryParse(item['startDate'].toString());
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openFollowupForm(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasFollowup ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5),
              width: hasFollowup ? 1.2 : 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Tag Aktivitas & Status Inspeksi
              Row(
                children: [
                  Flexible(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: actColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: actColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: actColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              activityType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: actColor, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 6,
                    child: _buildInspectionStatusBadge(hasFollowup, latestStatus, latestInspector),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Req ID & Waktu
              Row(
                children: [
                  Text(
                    reqId,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  if (startDate != null)
                    Text(
                      '• ${DateFormat('dd MMM yyyy, HH:mm').format(startDate)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Detail Lokasi & Kontraktor
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.business_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      contractor,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),

              // Info PJO & Inspector
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'PJO: $pjoName\nInspector: $inspectorName',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (hasFollowup) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Observasi Selesai • Diperiksa oleh $latestInspector ($latestRole)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action Buttons: Alihkan ke Orang Lain & Observasi Sekarang
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onPressed: () => _showReassignDialog(item),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                      label: const Text(
                        'Alihkan',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasFollowup ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onPressed: () => _openFollowupForm(item),
                      icon: Icon(
                        hasFollowup ? Icons.fact_check_rounded : Icons.assignment_turned_in_rounded,
                        size: 14,
                      ),
                      label: Text(
                        hasFollowup ? 'Cek Observasi' : 'Observasi Sekarang',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionStatusBadge(bool hasFollowup, String? latestStatus, String? inspectorName) {
    if (!hasFollowup) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 12, color: Color(0xFFDC2626)),
            SizedBox(width: 4),
            Text(
              'Belum Diinspeksi',
              style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    final byName = (inspectorName != null && inspectorName.trim().isNotEmpty) ? inspectorName.trim() : 'Inspector';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Sudah Diinspeksi oleh $byName',
              style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.shield_rounded, size: 44, color: Color(0xFF0284C7)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada Special Permit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Hanya pekerjaan khusus risiko tinggi di mana NIK Anda terdaftar sebagai Inspector atau PJO yang ditampilkan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFollowupForm(Map<String, dynamic> item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialPermitFollowupPage(permit: item),
      ),
    );
    if (result == true) {
      _loadPermits();
    }
  }

  void _showReassignDialog(Map<String, dynamic> permit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReassignInspectorModal(
        permit: permit,
        onReassigned: () {
          Navigator.pop(ctx);
          _loadPermits();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Penugasan inspeksi berhasil dialihkan!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        },
      ),
    );
  }
}

class _ReassignInspectorModal extends StatefulWidget {
  final Map<String, dynamic> permit;
  final VoidCallback onReassigned;

  const _ReassignInspectorModal({
    required this.permit,
    required this.onReassigned,
  });

  @override
  State<_ReassignInspectorModal> createState() => _ReassignInspectorModalState();
}

class _ReassignInspectorModalState extends State<_ReassignInspectorModal> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();

  List<Map<String, dynamic>> _candidates = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedInspector;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await _api.searchInspectors(query);
    if (!mounted) return;
    setState(() {
      _candidates = results;
      _isSearching = false;
    });
  }

  Future<void> _submitReassign() async {
    if (_selectedInspector == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih Inspector baru terlebih dahulu.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final permitId = widget.permit['id']?.toString() ?? '';
    final newNik = _selectedInspector!['nik']?.toString() ?? '';
    final newName = _selectedInspector!['nama']?.toString() ?? '';

    final res = await _api.reassignSpecialPermitInspector(
      permitId: permitId,
      newInspectorNik: newNik,
      newInspectorName: newName,
      reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : 'Dialihkan oleh PJO/Pengawas',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message']?.toString() ?? 'Gagal mengalihkan inspektur'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      },
      (_) {
        widget.onReassigned();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reqId = widget.permit['reqId']?.toString() ?? '-';
    final actType = (widget.permit['activityType'] ?? 'Special Permit').toString().replaceAll('_', ' ');
    final currentInspector = widget.permit['inspectorName']?.toString() ?? '-';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alihkan Penugasan Inspeksi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '$reqId • $actType',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Info Inspector Saat Ini
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Inspector Saat Ini: $currentInspector',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search Box
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => _performSearch(val.trim()),
            decoration: InputDecoration(
              hintText: 'Cari Nama / NIK Pengawas...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          // Candidate List
          Flexible(
            child: _isSearching
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : _candidates.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Tidak ditemukan pengawas / inspector.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _candidates.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final cand = _candidates[idx];
                          final nik = cand['nik']?.toString() ?? '';
                          final name = cand['nama']?.toString() ?? '-';
                          final dept = cand['departemen']?.toString() ?? '-';
                          final isSelected = _selectedInspector != null && _selectedInspector!['nik'] == nik;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            tileColor: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Text(
                              'NIK: $nik • $dept',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedInspector = cand;
                              });
                            },
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),

          // Konfirmasi Alihkan Tombol
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submitReassign,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _selectedInspector != null
                    ? 'Tugaskan ${_selectedInspector!['nama']}'
                    : 'Pilih Inspector di Atas',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
