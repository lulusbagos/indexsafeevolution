import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';

class ApprovalCenterPage extends StatefulWidget {
  const ApprovalCenterPage({super.key});

  @override
  State<ApprovalCenterPage> createState() => _ApprovalCenterPageState();
}

class _ApprovalCenterPageState extends State<ApprovalCenterPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  late TabController _tabController;
  bool _isLoadingStatus = true;
  bool _isLoadingPending = false;
  bool _isLoadingSubmissions = false;

  Map<String, dynamic>? _userBima;
  List<dynamic> _pendingList = [];
  List<dynamic> _submissionList = [];

  String _selectedModule = 'ALL';
  final List<String> _modules = ['ALL', 'PERMIT', 'SIMPER', 'SPECIAL_PERMIT'];

  // State untuk Batch Approval (Approve Beberapa Dokumen Sekaligus)
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};
  bool _isBatchSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _loadStatus();
    await Future.wait([
      _loadPending(),
      _loadSubmissions(),
    ]);
    if (mounted && _pendingList.isEmpty && _submissionList.isNotEmpty && _tabController.index == 0) {
      _tabController.animateTo(1);
    }
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoadingStatus = true);
    final res = await _api.checkApprovalCenterStatus();
    res.fold(
      (err) {
        if (mounted) setState(() => _isLoadingStatus = false);
      },
      (data) {
        if (mounted) {
          setState(() {
            _userBima = data['data'] as Map<String, dynamic>?;
            _isLoadingStatus = false;
          });
        }
      },
    );
  }

  Future<void> _loadPending() async {
    setState(() => _isLoadingPending = true);
    final res = await _api.getPendingApprovals(
      module: _selectedModule,
    );
    res.fold(
      (err) {
        if (mounted) setState(() => _isLoadingPending = false);
      },
      (data) {
        if (mounted) {
          setState(() {
            _pendingList = (data['data'] as List<dynamic>?) ?? [];
            _isLoadingPending = false;
          });
        }
      },
    );
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoadingSubmissions = true);
    final res = await _api.getMySubmissions(
      module: _selectedModule,
    );
    res.fold(
      (err) {
        if (mounted) setState(() => _isLoadingSubmissions = false);
      },
      (data) {
        if (mounted) {
          setState(() {
            _submissionList = (data['data'] as List<dynamic>?) ?? [];
            _isLoadingSubmissions = false;
          });
        }
      },
    );
  }

  void _onModuleSelected(String module) {
    if (_selectedModule == module) return;
    setState(() {
      _selectedModule = module;
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    _loadPending();
    _loadSubmissions();
  }

  Color _getModuleColor(String module) {
    switch (module.toUpperCase()) {
      case 'PERMIT':
        return const Color(0xFF059669); // Emerald
      case 'SIMPER':
        return const Color(0xFF2563EB); // Royal Blue
      case 'SPECIAL_PERMIT':
        return const Color(0xFFD97706); // Amber
      case 'COMMISSIONING':
        return const Color(0xFF7C3AED); // Violet
      default:
        return const Color(0xFF0D9488); // Teal
    }
  }

  String _getModuleLabel(String module) {
    switch (module.toUpperCase()) {
      case 'PERMIT':
        return 'Mine Permit';
      case 'SIMPER':
        return 'SIMPER';
      case 'SPECIAL_PERMIT':
        return 'Special Permit';
      case 'COMMISSIONING':
        return 'Commissioning';
      default:
        return module;
    }
  }

  void _openDetailModal(Map<String, dynamic> item, {bool isPendingTab = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ApprovalDetailBottomSheet(
        approvalId: item['approvalId'] as int? ?? 0,
        isPendingTab: isPendingTab,
        onActionCompleted: () {
          Navigator.pop(ctx);
          _loadAllData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0F2628);

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
          'Approval Center',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Segarkan',
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header profil approver Bima
          _buildUserProfileHeader(),

          // Segmented Tabs
          _buildSegmentedTabs(),

          // Module Filter Chips
          _buildModuleFilters(),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(),
                _buildSubmissionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileHeader() {
    if (_isLoadingStatus) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF0F2628),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
      );
    }

    final fullname = _userBima?['fullname'] as String? ?? 'Pengguna Bima';
    final roleName = _userBima?['roleName'] as String? ?? 'Approver';
    final dept = _userBima?['department'] as String? ?? '-';
    final company = _userBima?['companyName'] as String? ?? 'PT INDEXIM COALINDO';
    final pendingCount = _userBima?['pendingCount'] as int? ?? _pendingList.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F2628),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          roleName,
                          style: const TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$dept • $company',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '$pendingCount Menunggu',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF0F2628),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2628).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions_rounded, size: 18),
                const SizedBox(width: 6),
                const Text('Perlu Persetujuan'),
                if (_pendingList.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_pendingList.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                const Icon(Icons.outbox_rounded, size: 18),
                const SizedBox(width: 6),
                const Text('Proses Pengajuan'),
                if (_submissionList.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_submissionList.length}',
                      style: const TextStyle(color: Color(0xFF334155), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: _modules.map((m) {
          final isSelected = _selectedModule == m;
          String label;
          IconData icon;
          switch (m) {
            case 'PERMIT':
              label = 'Mine Permit';
              icon = Icons.badge_rounded;
              break;
            case 'SIMPER':
              label = 'SIMPER';
              icon = Icons.drive_eta_rounded;
              break;
            case 'SPECIAL_PERMIT':
              label = 'Special Permit';
              icon = Icons.security_rounded;
              break;
            default:
              label = 'Semua Modul';
              icon = Icons.apps_rounded;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              label: Text(label),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
              selected: isSelected,
              onSelected: (_) => _onModuleSelected(m),
              selectedColor: const Color(0xFF0F2628),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0F2628) : const Color(0xFFE2E8F0),
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_isLoadingPending) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2628)));
    }

    if (_pendingList.isEmpty) {
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
              child: const Icon(Icons.task_alt_rounded, size: 44, color: Color(0xFF0284C7)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak Ada Dokumen Menunggu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tidak ada permohonan yang memerlukan persetujuan dari role Anda saat ini. Silakan pantau status permohonan departemen pada tab Proses Pengajuan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Batch Selection Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              if (_isSelectionMode) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _toggleSelectAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedIds.length == _pendingList.length
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: const Color(0xFF059669),
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedIds.length == _pendingList.length
                              ? 'Batal Semua'
                              : 'Pilih Semua (${_pendingList.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _toggleSelectionMode,
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                  label: const Text('Batal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Text(
                  '${_pendingList.length} Permohonan Menunggu',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _toggleSelectionMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 5),
                        Text(
                          'Pilih Banyak (Batch)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPending,
            color: const Color(0xFF0F2628),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 80),
              itemCount: _pendingList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _pendingList[index] as Map<String, dynamic>;
                return _buildApprovalCard(item, isPending: true);
              },
            ),
          ),
        ),

        // Floating Bottom Bar for Batch Approve
        if (_isSelectionMode && _selectedIds.isNotEmpty)
          _buildBatchActionBar(),
      ],
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _pendingList.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        for (final item in _pendingList) {
          final id = item['approvalId'] as int? ?? 0;
          if (id > 0) _selectedIds.add(id);
        }
      }
    });
  }

  void _toggleSelectItem(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Widget _buildBatchActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_selectedIds.length} Dokumen Dipilih',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F2628)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Siap untuk persetujuan batch',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isBatchSubmitting ? null : _showBatchApprovalDialog,
              icon: _isBatchSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.done_all_rounded, size: 18),
              label: Text(
                _isBatchSubmitting ? 'Memproses...' : 'Setujui Sekaligus (${_selectedIds.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBatchApprovalDialog() async {
    if (_selectedIds.isEmpty) return;
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.done_all_rounded, color: Color(0xFF059669), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Setujui Sekaligus',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan menyetujui ${_selectedIds.length} permohonan yang dipilih secara bersamaan.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Catatan Verifikasi (Opsional):',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Contoh: Disetujui lengkap secara batch...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text('Setujui (${_selectedIds.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeBatchApproval(notesCtrl.text.trim());
    }
  }

  Future<void> _executeBatchApproval(String notes) async {
    setState(() => _isBatchSubmitting = true);
    final ids = _selectedIds.toList();
    final res = await _api.processBatchApprovalAction(
      approvalIds: ids,
      action: 'APPROVED',
      notes: notes.isNotEmpty ? notes : 'Disetujui secara bersamaan (Batch Approval)',
    );

    if (!mounted) return;
    setState(() {
      _isBatchSubmitting = false;
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message']?.toString() ?? 'Gagal memproses batch approval'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      },
      (data) {
        final msg = data['message']?.toString() ?? 'Batch approval berhasil diproses';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _loadAllData();
      },
    );
  }

  Widget _buildSubmissionsList() {
    if (_isLoadingSubmissions) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F2628)));
    }

    if (_submissionList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.folder_open_rounded, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Pengajuan Terpantau',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Pengajuan yang dibuat untuk departemen dan perusahaan Anda akan tampil di sini untuk pelacakan alur persetujuan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      color: const Color(0xFF0F2628),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: _submissionList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _submissionList[index] as Map<String, dynamic>;
          return _buildApprovalCard(item, isPending: false);
        },
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> item, {required bool isPending}) {
    final approvalId = item['approvalId'] as int? ?? 0;
    final isSelected = isPending && _isSelectionMode && _selectedIds.contains(approvalId);

    final module = item['module'] as String? ?? 'PERMIT';
    final modColor = _getModuleColor(module);
    final modLabel = _getModuleLabel(module);
    final nomor = item['nomor'] as String? ?? '-';
    final applicantName = item['applicantName'] as String? ?? 'Pemohon';
    final applicantNik = item['applicantNik'] as String? ?? '-';
    final company = item['companyName'] as String? ?? '-';
    final department = item['department'] as String? ?? '-';
    final submissionType = item['submissionType'] as String? ?? '-';
    final subDetail = item['subDetail'] as String?;
    final level = item['level'] as int? ?? 1;
    final roleName = item['roleName'] as String? ?? 'Approver';
    final reqStatus = item['reqStatus'] as String? ?? 'WAITING';

    DateTime? reqDate;
    if (item['reqTime'] != null) {
      reqDate = DateTime.tryParse(item['reqTime'].toString());
    }

    return Material(
      color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (isPending && _isSelectionMode) {
            _toggleSelectItem(approvalId);
          } else {
            _openDetailModal(item, isPendingTab: isPending);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? const Color(0xFF059669).withValues(alpha: 0.1) : const Color(0x08000000),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Tag Modul & Status / Checkbox
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: modColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: modColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: modColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          modLabel,
                          style: TextStyle(color: modColor, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isPending && _isSelectionMode)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF059669) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                          width: 1.8,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.transparent,
                      ),
                    )
                  else
                    _buildStatusBadge(reqStatus),
                ],
              ),
              const SizedBox(height: 10),

              // Nomor & Pemohon
              Text(
                nomor,
                style: const TextStyle(
                  color: Color(0xFF0F2628),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '$applicantName ($applicantNik)',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
                      '$department • $company',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),

              // Detail Tipe & Level
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subDetail != null && subDetail.isNotEmpty
                              ? '$submissionType ($subDetail)'
                              : submissionType,
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Level $level: $roleName',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (reqDate != null)
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(reqDate),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                    ),
                ],
              ),

              if (isPending && !_isSelectionMode) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2628),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => _openDetailModal(item, isPendingTab: true),
                    icon: const Icon(Icons.rate_review_rounded, size: 16),
                    label: const Text(
                      'Tinjau & Beri Keputusan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status.toUpperCase()) {
      case 'WAITING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        text = 'Menunggu';
        break;
      case 'APPROVED':
      case 'COMPLETE':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        text = 'Disetujui';
        break;
      case 'READY_TO_PRINT':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        text = 'Siap Cetak';
        break;
      case 'PRINTED':
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF334155);
        text = 'Dicetak';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        text = 'Ditolak';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

// ==========================================
// BOTTOM SHEET DETAIL & ACTION
// ==========================================

class _ApprovalDetailBottomSheet extends StatefulWidget {
  final int approvalId;
  final bool isPendingTab;
  final VoidCallback onActionCompleted;

  const _ApprovalDetailBottomSheet({
    required this.approvalId,
    required this.isPendingTab,
    required this.onActionCompleted,
  });

  @override
  State<_ApprovalDetailBottomSheet> createState() => _ApprovalDetailBottomSheetState();
}

class _ApprovalDetailBottomSheetState extends State<_ApprovalDetailBottomSheet> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _detail;

  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    final res = await _api.getApprovalDetail(widget.approvalId);
    res.fold(
      (err) {
        if (mounted) setState(() => _isLoading = false);
      },
      (data) {
        if (mounted) {
          setState(() {
            _detail = data['data'] as Map<String, dynamic>?;
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _submitAction(String action) async {
    if (action == 'REJECTED' && _notesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap masukkan catatan penolakan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'APPROVED' ? 'Setujui Pengajuan?' : 'Tolak Pengajuan?'),
        content: Text(
          action == 'APPROVED'
              ? 'Pengajuan ini akan disetujui dan dilanjutkan ke tahap berikutnya.'
              : 'Pengajuan ini akan ditolak dan proses approval dihentikan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'APPROVED' ? const Color(0xFF059669) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action == 'APPROVED' ? 'Ya, Setujui' : 'Ya, Tolak'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    final res = await _api.postApprovalAction(
      approvalId: widget.approvalId,
      action: action,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    res.fold(
      (err) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['message']?.toString() ?? 'Gagal memproses approval'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (data) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']?.toString() ?? 'Approval berhasil diproses'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
          widget.onActionCompleted();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.article_rounded, color: Color(0xFF0F2628), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Detail Pengajuan Approval',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2628),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2628)))
                : _detail == null
                    ? const Center(child: Text('Data tidak ditemukan'))
                    : _buildContent(),
          ),

          // Action Buttons (hanya jika berwenang approve)
          if (_detail != null) ...[
            if (_detail!['canApprove'] == true && ((_detail!['header'] as Map?)?['reqStatus'] == 'WAITING'))
              _buildActionBar()
            else
              _buildMonitoringBanner(),
          ],
        ],
      ),
    );
  }

  Widget _buildMonitoringBanner() {
    final header = _detail!['header'] as Map<String, dynamic>? ?? {};
    final status = header['reqStatus'] as String? ?? 'WAITING';
    final level = header['level'] as int? ?? 1;
    final roleName = header['roleName'] as String? ?? 'Approver';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF0F2628), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status == 'WAITING'
                      ? 'Mode Pantau: Menunggu persetujuan Level $level: $roleName.'
                      : 'Status pengajuan saat ini: $status.',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final header = _detail!['header'] as Map<String, dynamic>? ?? {};
    final history = (_detail!['history'] as List<dynamic>?) ?? [];
    final docs = (_detail!['documents'] as List<dynamic>?) ?? [];
    final canApprove = _detail!['canApprove'] == true && header['reqStatus'] == 'WAITING';

    final nomor = header['nomor'] as String? ?? '-';
    final reqId = header['reqId'] as String? ?? '-';
    final module = header['module'] as String? ?? '-';
    final applicantName = header['applicantName'] as String? ?? '-';
    final applicantNik = header['applicantNik'] as String? ?? '-';
    final company = header['companyName'] as String? ?? '-';
    final dept = header['department'] as String? ?? '-';
    final submissionType = header['submissionType'] as String? ?? '-';
    final subDetail = header['subDetail'] as String?;
    final level = header['level'] as int? ?? 1;
    final roleName = header['roleName'] as String? ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identitas Pengajuan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2628),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        module,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nomor,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInfoRow('Req ID', reqId),
                _buildInfoRow('Pemohon', '$applicantName ($applicantNik)'),
                _buildInfoRow('Perusahaan', company),
                _buildInfoRow('Departemen', dept),
                _buildInfoRow('Tipe Pengajuan', submissionType),
                if (subDetail != null && subDetail.isNotEmpty)
                  _buildInfoRow('Detail / Unit', subDetail),
                _buildInfoRow('Tahap Sekarang', 'Level $level: $roleName'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Riwayat Alur Approval (Timeline)
          const Text(
            'Alur & Riwayat Persetujuan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text('Belum ada riwayat approval.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))
          else
            ...history.asMap().entries.map((entry) {
              final idx = entry.key;
              final h = entry.value as Map<String, dynamic>;
              final isLast = idx == history.length - 1;
              return _buildTimelineStep(h, isLast: isLast);
            }),

          const SizedBox(height: 20),

          // Dokumen Terlampir
          if (docs.isNotEmpty) ...[
            const Text(
              'Dokumen Terlampir',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F2628)),
            ),
            const SizedBox(height: 10),
            ...docs.map((d) {
              final doc = d as Map<String, dynamic>;
              final docName = doc['documentName'] as String? ?? 'Dokumen';
              final fileName = doc['fileName'] as String? ?? '-';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(docName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          Text(fileName, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          // Catatan Approval (hanya jika berwenang approve)
          if (canApprove) ...[
            const Text(
              'Catatan Keputusan (Opsional untuk Setuju, Wajib untuk Tolak)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tuliskan catatan verifikasi di sini...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F2628)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(Map<String, dynamic> step, {required bool isLast}) {
    final level = step['levelApproval'] as int? ?? 1;
    final roleName = step['roleName'] as String? ?? '-';
    final status = step['reqStatus'] as String? ?? 'WAITING';
    final actionBy = step['actionByName'] as String?;
    final notes = step['notes'] as String?;
    DateTime? date;
    if (step['actionTime'] != null) {
      date = DateTime.tryParse(step['actionTime'].toString());
    }

    final isDone = status == 'APPROVED' || status == 'COMPLETE';
    final isRejected = status == 'REJECTED';

    Color dotColor = const Color(0xFFCBD5E1);
    IconData icon = Icons.circle;
    if (isDone) {
      dotColor = const Color(0xFF059669);
      icon = Icons.check_circle_rounded;
    } else if (isRejected) {
      dotColor = const Color(0xFFEF4444);
      icon = Icons.cancel_rounded;
    } else {
      dotColor = const Color(0xFFF59E0B);
      icon = Icons.hourglass_top_rounded;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: dotColor, size: 20),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Level $level: $roleName',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F2628)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: dotColor, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              if (actionBy != null && actionBy.isNotEmpty)
                Text(
                  'Oleh: $actionBy',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              if (date != null)
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              if (notes != null && notes.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Catatan: $notes',
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : () => _submitAction('REJECTED'),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : () => _submitAction('APPROVED'),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Memproses...' : 'Setujui Pengajuan',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
