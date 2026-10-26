import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/profile_model.dart';
import '../../services/api.dart';
import '../../services/preference.dart';
import '../../widgets/sap_form_widgets.dart';

class ActionTrackerPage extends StatefulWidget {
  const ActionTrackerPage({super.key});

  @override
  State<ActionTrackerPage> createState() => _ActionTrackerPageState();
}

class _ActionTrackerPageState extends State<ActionTrackerPage> {
  final ApiService _api = ApiService();
  ProfileModel? _profile;

  bool _isLoading = true;
  String? _errorMessage;

  // KPI summary counters
  int _countOutstanding = 0;
  int _countProgress = 0;
  int _countClosed = 0;
  int _countTotal = 0;

  // Active filters
  // Penugasan: 'all', 'assigned' (Saya), 'created' (Dibuat Saya), 'dept_assigned' (Departemen Saya), 'dept_created' (Dibuat Dept)
  String _selectedOwnershipFilter = 'all';
  // Status: 'all', 'outstanding', 'progress', 'closed'
  String _selectedStatusFilter = 'all';
  // Tipe: 'all', 'hazard', 'inspection'
  String _selectedTypeFilter = 'all';

  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _profile = PreferenceService.getProfile();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final nik = _profile?.noNik?.trim() ?? '';

    final res = await _api.getActionTracker(
      nik: nik,
      filter: _selectedOwnershipFilter,
      status: _selectedStatusFilter,
      type: _selectedTypeFilter,
      search: _searchController.text.trim(),
      startDate: _startDate != null ? _formatDateYmd(_startDate!) : null,
      endDate: _endDate != null ? _formatDateYmd(_endDate!) : null,
    );

    if (!mounted) return;

    res.fold(
      (err) {
        setState(() {
          _isLoading = false;
          _errorMessage = err['message']?.toString() ?? 'Gagal memuat Action Tracker.';
        });
      },
      (data) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final summary = payload['summary'] as Map<String, dynamic>?;
          final items = (payload['items'] as List<dynamic>?) ?? [];

          setState(() {
            _isLoading = false;
            _items = items;
            _countOutstanding = (summary?['outstanding'] as num?)?.toInt() ?? 0;
            _countProgress = (summary?['progress'] as num?)?.toInt() ?? 0;
            _countClosed = (summary?['closed'] as num?)?.toInt() ?? 0;
            _countTotal = (summary?['total'] as num?)?.toInt() ?? (_countOutstanding + _countProgress + _countClosed);
          });
        } else {
          setState(() {
            _isLoading = false;
            _items = [];
          });
        }
      },
    );
  }

  String _formatDateYmd(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '${_api.baseUrl}$path';
    return '${_api.baseUrl}/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF0284C7),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header Banner ──
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // ── Sleek 3-Tab Segmented KPI Summary Cards ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: _buildCompactKpiBar(),
                ),
              ),

              // ── Modern Clean Filter Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildFilterSection(),
                ),
              ),

              // ── Content List / States ──
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0284C7)),
                        SizedBox(height: 14),
                        Text(
                          'Memuat Action Tracker...',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4))
                              ],
                            ),
                            child: const Icon(Icons.assignment_turned_in_rounded, size: 48, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tidak Ada Temuan Sesuai Filter',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Coba ubah status, penugasan, atau tanggal untuk melihat temuan lainnya.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFFBAE6FD)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedOwnershipFilter = 'all';
                                _selectedStatusFilter = 'all';
                                _selectedTypeFilter = 'all';
                                _searchController.clear();
                                _startDate = null;
                                _endDate = null;
                              });
                              _loadData();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset Filter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _items[index] as Map<String, dynamic>;
                        return _buildActionCard(item);
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Banner ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Action Plan Temuan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                      ),
                      child: Text(
                        '$_countTotal Total',
                        style: const TextStyle(
                          color: Color(0xFFBAE6FD),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Monitor & Tindak Lanjut Resolusi K3',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _loadData,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sleek 3-Column Interactive KPI Segment Bar ────────────────────────────
  Widget _buildCompactKpiBar() {
    return Row(
      children: [
        // 1. Outstanding (Perlu Tindakan)
        Expanded(
          child: _buildMetricTile(
            label: 'Outstanding',
            count: _countOutstanding,
            sublabel: 'Perlu Tindak Lanjut',
            color: const Color(0xFFF43F5E),
            icon: Icons.warning_amber_rounded,
            isSelected: _selectedStatusFilter == 'outstanding',
            onTap: () {
              setState(() {
                _selectedStatusFilter = _selectedStatusFilter == 'outstanding' ? 'all' : 'outstanding';
              });
              _loadData();
            },
          ),
        ),
        const SizedBox(width: 8),

        // 2. In Progress (Sedang Dikerjakan)
        Expanded(
          child: _buildMetricTile(
            label: 'In Progress',
            count: _countProgress,
            sublabel: 'Sedang Berjalan',
            color: const Color(0xFFF59E0B),
            icon: Icons.construction_rounded,
            isSelected: _selectedStatusFilter == 'progress',
            onTap: () {
              setState(() {
                _selectedStatusFilter = _selectedStatusFilter == 'progress' ? 'all' : 'progress';
              });
              _loadData();
            },
          ),
        ),
        const SizedBox(width: 8),

        // 3. Closed (Tuntas)
        Expanded(
          child: _buildMetricTile(
            label: 'Closed',
            count: _countClosed,
            sublabel: 'Selesai Tuntas',
            color: const Color(0xFF10B981),
            icon: Icons.check_circle_rounded,
            isSelected: _selectedStatusFilter == 'closed',
            onTap: () {
              setState(() {
                _selectedStatusFilter = _selectedStatusFilter == 'closed' ? 'all' : 'closed';
              });
              _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required String sublabel,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.18) : const Color(0x06000000),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? color : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isSelected ? color : const Color(0xFF0F172A),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? color.withOpacity(0.9) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Streamlined Filter & Search Section ────────────────────────────────────
  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SEARCH BAR & DATE PICKER INLINE ──
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadData(),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Cari temuan, nama, lokasi...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                _loadData();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: (_startDate != null || _endDate != null)
                        ? const Color(0xFFE0F2FE)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_startDate != null || _endDate != null)
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 15,
                        color: (_startDate != null || _endDate != null)
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _startDate != null ? '${_startDate!.day}/${_startDate!.month}' : 'Periode',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (_startDate != null || _endDate != null)
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF475569),
                        ),
                      ),
                      if (_startDate != null || _endDate != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                            _loadData();
                          },
                          child: const Icon(Icons.cancel_rounded, size: 14, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // ── QUICK FILTER PENUGASAN (HORIZONTAL SCROLL) ──
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, size: 14, color: Color(0xFF0284C7)),
              const SizedBox(width: 4),
              const Text(
                'PENUGASAN:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_selectedStatusFilter != 'all' || _selectedOwnershipFilter != 'all' || _selectedTypeFilter != 'all')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedOwnershipFilter = 'all';
                      _selectedStatusFilter = 'all';
                      _selectedTypeFilter = 'all';
                    });
                    _loadData();
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPill(
                  label: 'Semua',
                  isSelected: _selectedOwnershipFilter == 'all',
                  activeColor: const Color(0xFF0284C7),
                  onTap: () => _updateOwnershipFilter('all'),
                ),
                _buildPill(
                  label: 'Ditugaskan ke Saya',
                  icon: Icons.assignment_ind_rounded,
                  isSelected: _selectedOwnershipFilter == 'assigned',
                  activeColor: const Color(0xFF0284C7),
                  onTap: () => _updateOwnershipFilter('assigned'),
                ),
                _buildPill(
                  label: 'Dibuat Saya',
                  icon: Icons.edit_note_rounded,
                  isSelected: _selectedOwnershipFilter == 'created',
                  activeColor: const Color(0xFFD97706),
                  onTap: () => _updateOwnershipFilter('created'),
                ),
                _buildPill(
                  label: 'Departemen Saya',
                  icon: Icons.apartment_rounded,
                  isSelected: _selectedOwnershipFilter == 'dept_assigned',
                  activeColor: const Color(0xFF4F46E5),
                  onTap: () => _updateOwnershipFilter('dept_assigned'),
                ),
                _buildPill(
                  label: 'Dibuat Dept',
                  icon: Icons.domain_rounded,
                  isSelected: _selectedOwnershipFilter == 'dept_created',
                  activeColor: const Color(0xFF7C3AED),
                  onTap: () => _updateOwnershipFilter('dept_created'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── PROGRAM TYPE & ITEM COUNTER ──
          Row(
            children: [
              _buildTypeChip('Semua', 'all'),
              const SizedBox(width: 6),
              _buildTypeChip('Hazard', 'hazard'),
              const SizedBox(width: 6),
              _buildTypeChip('Inspeksi', 'inspection'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_items.length} item',
                  style: const TextStyle(
                    color: Color(0xFF0369A1),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _selectedTypeFilter == value;
    return InkWell(
      onTap: () => _updateTypeFilter(value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPill({
    required String label,
    IconData? icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: isSelected ? Colors.white : const Color(0xFF64748B)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateOwnershipFilter(String val) {
    if (_selectedOwnershipFilter == val) return;
    setState(() => _selectedOwnershipFilter = val);
    _loadData();
  }

  void _updateTypeFilter(String val) {
    if (_selectedTypeFilter == val) return;
    setState(() => _selectedTypeFilter = val);
    _loadData();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0284C7),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  // ── Action Plan Card: Ultra-Professional & Intuitive Layout ───────────────
  Widget _buildActionCard(Map<String, dynamic> item) {
    final id = item['id'] as int? ?? 0;
    final statusKey = item['statusKey']?.toString() ?? 'outstanding';
    final isClosed = statusKey == 'closed';
    final isProgress = statusKey == 'progress';

    final displayType = item['displayType']?.toString() ?? 'HAZARD';
    final tingkatResiko = item['tingkatResiko']?.toString() ?? 'Sedang';
    final kategori = item['kategoriTemuan']?.toString() ?? 'Temuan';
    final detilTemuan = item['detilTemuan']?.toString() ?? '-';
    final lokasi = item['lokasi']?.toString() ?? 'General Area';
    final tanggalFormatted = item['tanggalFormatted']?.toString() ?? '';

    final directionBadge = item['directionBadge']?.toString() ?? 'UMUM';
    final directionType = item['directionType']?.toString() ?? 'general';

    final dueDateDisplay = item['dueDateDisplay']?.toString();
    final dueDateStatus = item['dueDateStatus']?.toString();
    final dueDateStatusColor = item['dueDateStatusColor']?.toString() ?? '#10B981';
    final recommendedDays = item['recommendedDays'] as int? ?? 7;

    final isReassigned = item['isReassigned'] as bool? ?? false;
    final reassignedFrom = item['reassignedFrom']?.toString();
    final reassignedTo = item['reassignedTo']?.toString();
    final reassignedAt = item['reassignedAt']?.toString();
    final reassignNote = item['reassignNote']?.toString();

    final fotoTemuan = item['fotoTemuan']?.toString();
    final fotoPerbaikan = item['fotoPerbaikan']?.toString();

    final namaPelapor = item['nama']?.toString() ?? '-';
    final nikPelapor = item['nik']?.toString() ?? '-';
    final deptPelapor = item['departemen']?.toString() ?? '-';
    final compPelapor = item['perusahaanPelapor']?.toString() ?? '';

    final pja = item['pja']?.toString() ?? '-';
    final nikPja = item['nikPja']?.toString() ?? '-';
    final deptPja = item['departemenPja']?.toString() ?? '-';
    final compPja = item['perusahaanPja']?.toString() ?? '';

    final pic = item['pic']?.toString() ?? '';
    final nikPic = item['nikPic']?.toString() ?? '';
    final deptPic = item['departemenPic']?.toString() ?? '';
    final compPic = item['perusahaanPic']?.toString() ?? '';

    final rencanaPerbaikan = item['rencanaPerbaikan']?.toString();
    final tanggalRencana = item['tanggalRencanaPerbaikan']?.toString();
    final perbaikan = item['perbaikan']?.toString();
    final tanggalPerbaikan = item['tanggalPerbaikan']?.toString();

    final aiAnalysis = item['aiAnalysis'] as Map<String, dynamic>?;

    // Card accent color
    final accentColor = isClosed
        ? const Color(0xFF10B981)
        : (isProgress ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Status Bar
              Container(width: 4.5, color: accentColor),

              // Main Card Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── ROW 1: BADGES (Tipe, Resiko, Direction, Status) ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$id • $displayType',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 5),
                          _buildRiskBadge(tingkatResiko),
                          const Spacer(),
                          _buildDirectionBadge(directionBadge, directionType),
                          const SizedBox(width: 5),
                          _buildStatusBadge(statusKey),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ── TITLE / KATEGORI TEMUAN ──
                      Text(
                        kategori,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ── LOKASI & TANGGAL TEMUAN ──
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 3),
                          Text(
                            tanggalFormatted,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),

                      // ── DUE DATE / SLA ALERT ──
                      if (dueDateDisplay != null && dueDateDisplay.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _parseHexColor(dueDateStatusColor).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _parseHexColor(dueDateStatusColor).withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.alarm_rounded, size: 13, color: _parseHexColor(dueDateStatusColor)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Batas: $dueDateDisplay • $dueDateStatus',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _parseHexColor(dueDateStatusColor),
                                  ),
                                ),
                              ),
                              Text(
                                'SLA $recommendedDays Hari',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _parseHexColor(dueDateStatusColor).withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── REASSIGNED BANNER (IF ANY) ──
                      if (isReassigned) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Dialihkan: ${reassignedFrom ?? ""} → ${reassignedTo ?? ""} ${reassignedAt != null ? "($reassignedAt)" : ""} ${reassignNote != null ? "($reassignNote)" : ""}',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // ── DESKRIPSI TEMUAN (CLEAN CALLOUT) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 16,
                              margin: const EdgeInsets.only(right: 8, top: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF1E293B)),
                                  children: [
                                    const TextSpan(
                                      text: 'Temuan: ',
                                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                                    ),
                                    TextSpan(text: detilTemuan),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── PHOTOS THUMBNAILS (ELEGANT SIDE-BY-SIDE) ──
                      if ((fotoTemuan != null && fotoTemuan.isNotEmpty) || (fotoPerbaikan != null && fotoPerbaikan.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (fotoTemuan != null && fotoTemuan.isNotEmpty)
                              Expanded(
                                child: _buildPhotoThumbnail(
                                  url: fotoTemuan,
                                  label: 'Foto Temuan (Before)',
                                  badgeColor: const Color(0xFFEA580C),
                                ),
                              ),
                            if (fotoTemuan != null && fotoTemuan.isNotEmpty && fotoPerbaikan != null && fotoPerbaikan.isNotEmpty)
                              const SizedBox(width: 8),
                            if (fotoPerbaikan != null && fotoPerbaikan.isNotEmpty)
                              Expanded(
                                child: _buildPhotoThumbnail(
                                  url: fotoPerbaikan,
                                  label: 'Bukti Selesai (After)',
                                  badgeColor: const Color(0xFF059669),
                                ),
                              ),
                          ],
                        ),
                      ],

                      // ── AI ANALYSIS ──
                      if (aiAnalysis != null && (aiAnalysis['reasoning'] != null || aiAnalysis['recommendation'] != null)) ...[
                        const SizedBox(height: 8),
                        _buildAiAnalysisBox(aiAnalysis),
                      ],

                      const SizedBox(height: 8),

                      // ── PIHAK TERKAIT (STAKEHOLDERS STRIP) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pelapor
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.person_pin_circle_rounded, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                      children: [
                                        const TextSpan(text: 'Pelapor: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: '$namaPelapor ($nikPelapor) • $deptPelapor ${compPelapor.isNotEmpty ? "• $compPelapor" : ""}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // PJA
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.badge_rounded, size: 14, color: Color(0xFF0284C7)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                      children: [
                                        const TextSpan(text: 'PJA: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: '$pja ($nikPja) • $deptPja ${compPja.isNotEmpty ? "• $compPja" : ""}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // PIC Eksekutor
                            if (pic.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.engineering_rounded, size: 14, color: Color(0xFF059669)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF065F46)),
                                        children: [
                                          const TextSpan(text: 'PIC: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                          TextSpan(text: '$pic ($nikPic) • $deptPic ${compPic.isNotEmpty ? "• $compPic" : ""}'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ── STATUS RESOLUSI (Rencana vs Selesai) ──
                      if (isClosed && perbaikan != null && perbaikan.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Perbaikan Tuntas:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$perbaikan ${tanggalPerbaikan != null ? "($tanggalPerbaikan)" : ""}',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF047857), height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (rencanaPerbaikan != null && rencanaPerbaikan.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.pending_actions_rounded, size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Rencana Perbaikan:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$rencanaPerbaikan ${tanggalRencana != null ? "($tanggalRencana)" : ""}',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── ACTION BUTTON: TAKE UP & TINDAK LANJUT ──
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isClosed
                                ? const Color(0xFFF1F5F9)
                                : (isProgress ? const Color(0xFF0284C7) : const Color(0xFFF43F5E)),
                            foregroundColor: isClosed ? const Color(0xFF475569) : Colors.white,
                            elevation: isClosed ? 0 : 2,
                            shadowColor: isClosed
                                ? Colors.transparent
                                : (isProgress ? const Color(0x400284C7) : const Color(0x40F43F5E)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openUpdateActionPlanSheet(item),
                          icon: Icon(
                            isClosed ? Icons.visibility_rounded : (isProgress ? Icons.edit_note_rounded : Icons.rocket_launch_rounded),
                            size: 16,
                          ),
                          label: Text(
                            isClosed
                                ? 'LIHAT DETAIL PERBAIKAN'
                                : (isProgress ? 'UPDATE PROGRESS / TUTUP LAPORAN' : 'AMBIL & TINDAK LANJUTI'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: isClosed ? const Color(0xFF334155) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SUB-WIDGETS FOR CARDS ─────────────────────────────────────────────────
  Widget _buildRiskBadge(String risk) {
    Color bg = const Color(0xFF0284C7);
    Color fg = Colors.white;
    final r = risk.toLowerCase();

    if (r.contains('ekstrim') || r.contains('kritis')) {
      bg = const Color(0xFF991B1B);
    } else if (r.contains('tinggi') || r.contains('high')) {
      bg = const Color(0xFFDC2626);
    } else if (r.contains('sedang') || r.contains('medium')) {
      bg = const Color(0xFFD97706);
    } else if (r.contains('rendah') || r.contains('low')) {
      bg = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        risk.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildDirectionBadge(String label, String directionType) {
    Color bg = const Color(0xFFE0F2FE);
    Color fg = const Color(0xFF0369A1);
    IconData icon = Icons.info_outline_rounded;

    if (directionType == 'assigned_to_me') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
      icon = Icons.inbox_rounded;
    } else if (directionType == 'created_by_me') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
      icon = Icons.outbox_rounded;
    } else if (directionType == 'dept_internal') {
      bg = const Color(0xFFF5F3FF);
      fg = const Color(0xFF7C3AED);
      icon = Icons.sync_alt_rounded;
    } else if (directionType == 'dept_out') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
      icon = Icons.logout_rounded;
    } else if (directionType == 'dept_in') {
      bg = const Color(0xFFECFEFF);
      fg = const Color(0xFF0891B2);
      icon = Icons.login_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String statusKey) {
    Color bg = const Color(0xFF10B981);
    Color fg = Colors.white;
    String text = 'CLOSED';
    IconData icon = Icons.check_circle_rounded;

    if (statusKey == 'outstanding') {
      bg = const Color(0xFFF43F5E);
      text = 'OUTSTANDING';
      icon = Icons.warning_amber_rounded;
    } else if (statusKey == 'progress') {
      bg = const Color(0xFFF59E0B);
      text = 'IN PROGRESS';
      icon = Icons.construction_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(color: fg, fontSize: 8.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required String url,
    required String label,
    required Color badgeColor,
  }) {
    final fullUrl = _resolveImageUrl(url);

    return InkWell(
      onTap: () => _showPhotoViewer(fullUrl, label),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 100,
          color: const Color(0xFF0F172A),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                fullUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 24),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9),
                      ),
                    ],
                  ),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  );
                },
              ),
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 2),
                      Text('Perbesar', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiAnalysisBox(Map<String, dynamic> ai) {
    final reasoning = ai['reasoning']?.toString() ?? '';
    final recommendation = ai['recommendation']?.toString() ?? '';
    final isGolden = ai['isGoldenRule'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF0284C7), size: 16),
          ),
          title: Row(
            children: [
              const Text(
                'ANALISA AI K3',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0369A1),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              if (isGolden)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Golden Rule',
                    style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reasoning.isNotEmpty) ...[
                    const Text(
                      'Diagnosa Risiko:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reasoning,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.4),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (recommendation.isNotEmpty) ...[
                    const Text(
                      'Rekomendasi Tindakan:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recommendation,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoViewer(String fullUrl, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Container(
                  color: Colors.black,
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: InteractiveViewer(
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Gagal memuat foto.', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── UPDATE ACTION PLAN BOTTOM SHEET ───────────────────────────────────────
  void _openUpdateActionPlanSheet(Map<String, dynamic> item) {
    final id = item['id'] as int? ?? 0;
    final statusKey = item['statusKey']?.toString() ?? 'outstanding';

    // Smart default: If item PIC is empty, automatically prefill from logged-in user profile
    final existingPic = (item['pic']?.toString() ?? '').trim();
    final existingNik = (item['nikPic']?.toString() ?? item['nik']?.toString() ?? '').trim();
    final existingDept = (item['departemenPic']?.toString() ?? item['departemen']?.toString() ?? '').trim();

    final picCtrl = TextEditingController(
      text: existingPic.isNotEmpty ? existingPic : (_profile?.namaLengkap ?? '').trim(),
    );
    final nikPicCtrl = TextEditingController(
      text: existingNik.isNotEmpty ? existingNik : (_profile?.noNik ?? '').trim(),
    );
    final deptPicCtrl = TextEditingController(
      text: existingDept.isNotEmpty ? existingDept : (_profile?.depart ?? '').trim(),
    );
    final planCtrl = TextEditingController(text: item['rencanaPerbaikan']?.toString() ?? '');
    final perbaikanCtrl = TextEditingController(text: item['perbaikan']?.toString() ?? '');

    String selectedStatus = statusKey == 'closed' ? '2' : (statusKey == 'progress' ? '2' : '1');
    File? pickedPhoto;
    bool isSubmitting = false;
    bool isResolvingPic = false;
    String? picVerifiedStatus;
    Timer? debounceTimer;
    bool hasInitializedLookup = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Function to resolve PIC and Department from system by NIK
            Future<void> resolvePic(String rawNik) async {
              final qNik = rawNik.trim();
              if (qNik.length < 4) return;
              setModalState(() {
                isResolvingPic = true;
              });
              try {
                final res = await _api.searchPja(qNik, lintasPerusahaan: true);
                res.fold((_) {
                  setModalState(() => isResolvingPic = false);
                }, (list) {
                  if (list.isNotEmpty) {
                    final match = list.firstWhere(
                      (e) => (e['nik']?.toString().trim().toLowerCase() == qNik.toLowerCase()),
                      orElse: () => list.first,
                    );
                    final nama = match['nama']?.toString().trim() ?? '';
                    final dept = (match['departemen'] ?? match['depart'])?.toString().trim() ?? '';
                    if (nama.isNotEmpty) picCtrl.text = nama;
                    if (dept.isNotEmpty) deptPicCtrl.text = dept;
                    setModalState(() {
                      isResolvingPic = false;
                      picVerifiedStatus = '$nama ($dept)';
                    });
                  } else {
                    setModalState(() => isResolvingPic = false);
                  }
                });
              } catch (_) {
                setModalState(() => isResolvingPic = false);
              }
            }

            // Auto-resolve department on first open if missing
            if (!hasInitializedLookup) {
              hasInitializedLookup = true;
              if (nikPicCtrl.text.isNotEmpty && deptPicCtrl.text.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  resolvePic(nikPicCtrl.text);
                });
              }
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tindak Lanjut Action Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            debounceTimer?.cancel();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#$id — ${item['kategoriTemuan'] ?? "Temuan K3"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),

                    // Status Radio Pills
                    const Text(
                      'Pilih Status Tindak Lanjut:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedStatus = '1'),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: selectedStatus == '1' ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'In Progress (Rencana)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: selectedStatus == '1' ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedStatus = '2'),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: selectedStatus == '2' ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Selesai & Tutup (Closed)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: selectedStatus == '2' ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Header PIC & Smart Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Penanggung Jawab PIC (Sistem):',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                final myNik = (_profile?.noNik ?? '').trim();
                                final myName = (_profile?.namaLengkap ?? '').trim();
                                final myDept = (_profile?.depart ?? '').trim();
                                nikPicCtrl.text = myNik;
                                picCtrl.text = myName;
                                deptPicCtrl.text = myDept;
                                if (myDept.isEmpty && myNik.isNotEmpty) {
                                  resolvePic(myNik);
                                } else {
                                  setModalState(() {
                                    picVerifiedStatus = '$myName ($myDept)';
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF0284C7)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Gunakan Saya',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () async {
                                final selected = await SapEmployeePickerModal.show(context, title: 'Cari PIC dari Sistem');
                                if (selected != null) {
                                  nikPicCtrl.text = selected.nik;
                                  picCtrl.text = selected.nama;
                                  deptPicCtrl.text = selected.departemen;
                                  setModalState(() {
                                    picVerifiedStatus = '${selected.nama} (${selected.departemen})';
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF7DD3FC)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.person_search_rounded, size: 12, color: Color(0xFF0369A1)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Cari Sistem',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // NIK PIC with smart auto-complete & search icon
                    _buildModalTextField(
                      controller: nikPicCtrl,
                      label: 'NIK PIC (Ketik untuk lookup otomatis)',
                      hint: 'Contoh: 24051940986',
                      suffixIcon: isResolvingPic
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.person_search_rounded, color: Color(0xFF0284C7), size: 19),
                              tooltip: 'Cari PIC dari Sistem',
                              onPressed: () async {
                                final selected = await SapEmployeePickerModal.show(context, title: 'Cari PIC dari Sistem');
                                if (selected != null) {
                                  nikPicCtrl.text = selected.nik;
                                  picCtrl.text = selected.nama;
                                  deptPicCtrl.text = selected.departemen;
                                  setModalState(() {
                                    picVerifiedStatus = '${selected.nama} (${selected.departemen})';
                                  });
                                }
                              },
                            ),
                      onChanged: (val) {
                        debounceTimer?.cancel();
                        debounceTimer = Timer(const Duration(milliseconds: 450), () {
                          resolvePic(val);
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Nama PIC & Departemen PIC (Auto-populated)
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalTextField(
                            controller: picCtrl,
                            label: 'Nama PIC (Otomatis)',
                            hint: 'Nama PIC Perbaikan',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildModalTextField(
                            controller: deptPicCtrl,
                            label: 'Departemen PIC (Otomatis)',
                            hint: 'Departemen PIC',
                          ),
                        ),
                      ],
                    ),

                    if (picVerifiedStatus != null || (deptPicCtrl.text.isNotEmpty && picCtrl.text.isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'PIC Terverifikasi: ${picCtrl.text} • ${deptPicCtrl.text}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Rencana Perbaikan
                    _buildModalTextField(
                      controller: planCtrl,
                      label: 'Rencana Perbaikan',
                      hint: 'Langkah rencana perbaikan yang akan dikerjakan...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),

                    // Tindakan Perbaikan (Jika Closed atau ada perbaikan)
                    if (selectedStatus == '2') ...[
                      _buildModalTextField(
                        controller: perbaikanCtrl,
                        label: 'Tindakan Perbaikan (Selesai)*',
                        hint: 'Jelaskan bukti perbaikan yang sudah tuntas dikerjakan...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Foto Perbaikan Picker
                    const Text(
                      'Unggah Foto Bukti Perbaikan:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
                        if (picked != null) {
                          setModalState(() => pickedPhoto = File(picked.path));
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 90,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                        ),
                        child: pickedPhoto != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(pickedPhoto!, width: double.infinity, height: 90, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => pickedPhoto = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7), size: 28),
                                  SizedBox(height: 4),
                                  Text(
                                    'Ambil Foto Kamera Bukti Perbaikan',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedStatus == '2' ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                final res = await _api.updateActionPlan(
                                  id: id,
                                  status: selectedStatus,
                                  pic: picCtrl.text.trim(),
                                  nikPic: nikPicCtrl.text.trim(),
                                  departemenPic: deptPicCtrl.text.trim(),
                                  rencanaPerbaikan: planCtrl.text.trim(),
                                  perbaikan: perbaikanCtrl.text.trim(),
                                  photoPath: pickedPhoto?.path,
                                );
                                setModalState(() => isSubmitting = false);

                                res.fold(
                                  (err) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(err['message']?.toString() ?? 'Gagal memperbarui Action Plan.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                                  (_) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Action Plan berhasil diperbarui!'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                    _loadData();
                                  },
                                );
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                selectedStatus == '2' ? 'Simpan & Selesaikan Temuan' : 'Simpan Rencana Perbaikan',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    Widget? suffixIcon,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            suffixIcon: suffixIcon,
            helperText: helperText,
            helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0284C7)),
            ),
          ),
        ),
      ],
    );
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      } else if (clean.length == 8) {
        return Color(int.parse('0x$clean'));
      }
    } catch (_) {}
    return const Color(0xFF10B981);
  }
}
