import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
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
        setState(() {
          _permits = (data['data'] as List<dynamic>?) ?? [];
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
    const bgDark = Color(0xFF0F2628);
    final displayedList = _filteredPermits;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F7),
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Special Permit & High Risk',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2628)))
                : displayedList.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPermits,
                        color: const Color(0xFF0F2628),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F2628),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peringatan Pekerjaan Risiko Tinggi',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'PJO & Inspector wajib melakukan inspeksi lapangan sebelum & selama pekerjaan berlangsung.',
                    style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 11, height: 1.3),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
    Color activeBg = isUrgent ? const Color(0xFFEF4444) : const Color(0xFF0F2628);

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
              color: hasFollowup ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
              width: hasFollowup ? 1.0 : 1.4,
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
              // Baris Tag Aktivitas & Req ID
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: actColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: actColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: actColor),
                        const SizedBox(width: 5),
                        Text(
                          activityType,
                          style: TextStyle(color: actColor, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildInspectionStatusBadge(hasFollowup, latestStatus),
                ],
              ),
              const SizedBox(height: 10),

              // Req ID & Lokasi Kerja
              Row(
                children: [
                  Text(
                    reqId,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F2628)),
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
                children: [
                  Expanded(
                    child: Text(
                      'PJO: $pjoName\nInspector: $inspectorName',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasFollowup ? const Color(0xFF0F2628) : const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _openFollowupForm(item),
                    icon: Icon(
                      hasFollowup ? Icons.fact_check_rounded : Icons.add_task_rounded,
                      size: 14,
                    ),
                    label: Text(
                      hasFollowup ? 'Cek / Follow-Up' : 'Inspeksi Sekarang',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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

  Widget _buildInspectionStatusBadge(bool hasFollowup, String? latestStatus) {
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

    final isSafe = latestStatus == 'AMAN';
    final isStopped = latestStatus == 'DIHENTIKAN';

    Color bg = isSafe ? const Color(0xFFECFDF5) : (isStopped ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB));
    Color fg = isSafe ? const Color(0xFF059669) : (isStopped ? const Color(0xFFDC2626) : const Color(0xFFD97706));
    IconData icon = isSafe ? Icons.check_circle_rounded : (isStopped ? Icons.cancel_rounded : Icons.warning_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            isSafe ? 'Sudah Diinspeksi (Aman)' : (isStopped ? 'Dihentikan' : 'Ada Temuan'),
            style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w900),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Tidak ditemukan kegiatan pekerjaan khusus risiko tinggi yang terdaftar atau memerlukan inspeksi saat ini.',
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
}
