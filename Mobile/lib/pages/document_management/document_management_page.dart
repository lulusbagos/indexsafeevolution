import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/document_model.dart';
import '../../services/document_management_service.dart';
import '../../services/preference.dart';

class DocumentManagementPage extends StatefulWidget {
  const DocumentManagementPage({super.key});

  @override
  State<DocumentManagementPage> createState() => _DocumentManagementPageState();
}

class _DocumentManagementPageState extends State<DocumentManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DocumentManagementService _service = DocumentManagementService.instance;

  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, dynamic>? _summary;
  List<DocumentFolderModel> _folders = [];
  List<DocumentItemModel> _files = [];

  // Navigation state for Drive folder hierarchy
  DocumentFolderModel? _currentFolder;

  // Active user profile
  String _myName = '';
  String _myDept = '';

  @override
  void initState() {
    super.initState();
    final profile = PreferenceService.getProfile();
    _myName = profile?.namaLengkap ?? 'LULUS BAGOS HERMAWAN';
    _myDept = profile?.depart ?? 'SYSTEM INTEGRATIONS';

    // Instant initial state from local cache
    _folders = _service.cachedFolders;
    _files = _service.getLocalFiles();
    _summary = _service.cachedSummary;
    _isLoading = false;

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _service.getSummary(department: _myDept),
        _service.getFolders(),
        _service.getFiles(
          folderId: _currentFolder?.id,
          search: _searchQuery,
        ),
      ]);

      final summary = results[0] as Map<String, dynamic>;
      final folders = results[1] as List<DocumentFolderModel>;
      final files = results[2] as List<DocumentItemModel>;

      if (mounted) {
        setState(() {
          _summary = summary;
          _folders = folders;
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onFolderTap(DocumentFolderModel folder) {
    setState(() {
      _currentFolder = folder;
      _files = _service.getLocalFiles(folderId: folder.id, search: _searchQuery);
    });
    _fetchData();
  }

  void _onNavigateUp() {
    setState(() {
      _currentFolder = null;
      _files = _service.getLocalFiles(folderId: null, search: _searchQuery);
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0284C7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dokumen Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _myDept.isNotEmpty ? 'Dept: $_myDept • $_myName' : 'Cloud Drive Tambang',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155)),
            onPressed: _fetchData,
          ),
          IconButton(
            tooltip: 'Tambah',
            icon: const Icon(Icons.add_circle_outline_rounded, color: primaryColor),
            onPressed: _showAddActionBottomSheet,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              tabs: [
                const Tab(
                  child: Row(
                    children: [
                      Icon(Icons.folder_open_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Drive Dokumen'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined, size: 18),
                      const SizedBox(width: 6),
                      const Text('Pengajuan & Izin'),
                      if ((_summary?['pendingApprovals'] ?? 0) > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_summary!['pendingApprovals']}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('SOP & Standar'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.rate_review_outlined, size: 18),
                      const SizedBox(width: 6),
                      const Text('Approval Center'),
                      if ((_summary?['pendingApprovals'] ?? 0) > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_summary!['pendingApprovals']}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: primaryColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDriveTab(),
                  _buildPengajuanTab(),
                  _buildSopTab(),
                  _buildApprovalTab(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        elevation: 4,
        onPressed: _showAddActionBottomSheet,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Tambah Dokumen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: DRIVE DOKUMEN (Google Drive Style)
  // ==========================================
  Widget _buildDriveTab() {
    final displayFiles = _files.where((f) {
      if (_currentFolder != null) return f.folderId == _currentFolder!.id;
      return true;
    }).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStorageBanner(),
          const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildBreadcrumbs(),
          const SizedBox(height: 12),

          // Folders section (only show when at root)
          if (_currentFolder == null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Folder Utama',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showCreateFolderDialog,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0284C7),
                  ),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: const Text('+ Folder Baru', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFolderGrid(),
            const SizedBox(height: 20),
          ],

          // File List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentFolder != null ? 'Isi Folder: ${_currentFolder!.name}' : 'Semua File Dokumen',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${displayFiles.length} file',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (displayFiles.isEmpty)
            _buildEmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Folder Kosong',
              subtitle: 'Belum ada dokumen yang diunggah ke dalam folder ini.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayFiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildFileItemCard(displayFiles[index]);
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PENGAJUAN & PERIZINAN (Permit / PTW)
  // ==========================================
  Widget _buildPengajuanTab() {
    final pengajuanFiles = _files.where((f) => f.category == 'Pengajuan' || f.approvalStatus != 'Approved').toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_turned_in, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Pengajuan & Perizinan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Permit to Work (PTW), JSA, Dispensasi, & Izin Khusus Operasional.',
                        style: TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Pengajuan Anda',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreatePengajuanDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Buat Izin Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pengajuanFiles.isEmpty)
            _buildEmptyState(
              icon: Icons.assignment_outlined,
              title: 'Belum Ada Pengajuan',
              subtitle: 'Tekan tombol "Buat Izin Baru" untuk mengajukan izin kerja atau verifikasi dokumen.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pengajuanFiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildFileItemCard(pengajuanFiles[index]);
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: SOP & STANDAR K3LH
  // ==========================================
  Widget _buildSopTab() {
    final sopFiles = _files.where((f) => f.category == 'SOP' || f.title.toLowerCase().contains('sop') || f.title.toLowerCase().contains('wi-')).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified_user, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direktori SOP & Golden Rules',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Standar operasional prosedur terverifikasi untuk keselamatan tambang PT Indexim Coalindo.',
                        style: TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SOP Aktif & Regulasi K3LH',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(
                      '${sopFiles.length} SOP Aktif',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sopFiles.isEmpty)
            _buildEmptyState(
              icon: Icons.shield_outlined,
              title: 'Belum Ada SOP Terdaftar',
              subtitle: 'Dokumen SOP akan otomatis disinkronkan dari server HSE.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sopFiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildFileItemCard(sopFiles[index]);
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: APPROVAL CENTER DOKUMEN
  // ==========================================
  Widget _buildApprovalTab() {
    final pendingFiles = _files.where((f) => f.approvalStatus == 'Submitted' || f.approvalStatus == 'UnderReview').toList();
    final approvedFiles = _files.where((f) => f.approvalStatus == 'Approved').toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C2D12), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.rate_review, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Persetujuan Dokumen & Perizinan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Verifikasi dan setujui permohonan dokumen izin kerja dari staf dan kontraktor.',
                        style: TextStyle(
                          color: Colors.orange.shade100,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Menunggu Persetujuan Anda',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${pendingFiles.length} antrean',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingFiles.isEmpty)
            _buildEmptyState(
              icon: Icons.task_alt,
              title: 'Semua Dokumen Beres!',
              subtitle: 'Tidak ada dokumen perizinan yang menunggu persetujuan Anda saat ini.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingFiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildApprovalCard(pendingFiles[index]);
              },
            ),
          const SizedBox(height: 24),
          const Text(
            'Riwayat Dokumen yang Disetujui',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: approvedFiles.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildFileItemCard(approvedFiles[index]);
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED WIDGETS
  // ==========================================

  Widget _buildStorageBanner() {
    final storage = _summary?['storageFormatted'] ?? '23.4 MB';
    final totalDocs = _summary?['totalDocuments'] ?? _files.length;
    final totalFolders = _summary?['totalFolders'] ?? _folders.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF0284C7), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Penyimpanan Dokumen Tambang',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalDocs Dokumen • $totalFolders Folder • $storage Digunakan',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.28,
              minHeight: 6,
              backgroundColor: Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
        decoration: InputDecoration(
          hintText: 'Cari nama dokumen, nomor SOP, perizinan...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            onTap: _currentFolder != null ? _onNavigateUp : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_circle_outlined,
                    size: 18,
                    color: _currentFolder == null ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Drive Utama',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _currentFolder == null ? FontWeight.w800 : FontWeight.w600,
                      color: _currentFolder == null ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_currentFolder != null) ...[
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                _currentFolder!.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _folders.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) {
        final folder = _folders[index];
        final folderColor = _parseColor(folder.color);

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _onFolderTap(folder),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: folderColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.folder_rounded, color: folderColor, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${folder.filesCount} file',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileItemCard(DocumentItemModel file) {
    final extColor = _getFileTypeColor(file.fileType);
    final extIcon = _getFileTypeIcon(file.fileType);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showDocumentDetailModal(file),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: extColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(extIcon, color: extColor, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (file.docNumber != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.docNumber!,
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.version,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ),
                          const Spacer(),
                          _buildStatusBadge(file.approvalStatus),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.25),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          file.department ?? 'All Dept',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                        Text(
                          file.formattedSize,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                        Text(
                          DateFormat('dd MMM yyyy').format(file.updatedAt),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF94A3B8)),
                onPressed: () => _showDocumentActions(file),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalCard(DocumentItemModel file) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  file.docNumber ?? 'PERMIT-REQ',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ),
              const Spacer(),
              _buildStatusBadge(file.approvalStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            file.title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          if (file.description != null && file.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              file.description!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.3),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Diajukan oleh: ${file.uploaderName ?? "Karyawan"} (${file.department ?? "-"})',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleRejectDialog(file),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Tolak / Revisi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleApproveDialog(file),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Setujui Dokumen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = const Color(0xFFDEF7EC);
        fg = const Color(0xFF03543F);
        label = 'Disetujui';
        break;
      case 'submitted':
        bg = const Color(0xFFFEF08A);
        fg = const Color(0xFF854D0E);
        label = 'Menunggu';
        break;
      case 'underreview':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        label = 'Ditinjau';
        break;
      case 'rejected':
        bg = const Color(0xFFFDE8E8);
        fg = const Color(0xFF9B1C1C);
        label = 'Ditolak';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 54, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.3),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  void _showAddActionBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah ke Dokumen Management',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.assignment_add, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Buat Pengajuan Dokumen / Izin Kerja', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Permit to work, JSA, dispensasi, SIMPER'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePengajuanDialog();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.create_new_folder, color: Color(0xFF059669)),
                  ),
                  title: const Text('Buat Folder Baru', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Kelompokkan dokumen per kategori / unit'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateFolderDialog();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFDF4FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.upload_file, color: Color(0xFF9333EA)),
                  ),
                  title: const Text('Upload File Dokumen', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Unggah berkas PDF, Word, atau Excel'),
                  onTap: () {
                    Navigator.pop(context);
                    _showUploadFileDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDocumentDetailModal(DocumentItemModel file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getFileTypeColor(file.fileType).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getFileTypeIcon(file.fileType), color: _getFileTypeColor(file.fileType), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              file.docNumber ?? 'No Document Number',
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(file.approvalStatus),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Informasi Dokumen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  const SizedBox(height: 10),
                  _buildDetailRow('Kategori', file.category),
                  _buildDetailRow('Versi Dokumen', file.version),
                  _buildDetailRow('Ukuran Berkas', file.formattedSize),
                  _buildDetailRow('Format', file.fileType.toUpperCase()),
                  _buildDetailRow('Departemen', file.department ?? '-'),
                  _buildDetailRow('Perusahaan', file.company ?? 'PT INDEXIM COALINDO'),
                  _buildDetailRow('Pengunggah', '${file.uploaderName ?? "-"} (${file.uploaderNik ?? "-"})'),
                  _buildDetailRow('Tanggal Dibuat', DateFormat('dd MMMM yyyy HH:mm').format(file.createdAt)),
                  if (file.approverName != null) ...[
                    _buildDetailRow('Disetujui Oleh', file.approverName!),
                    if (file.approvedAt != null)
                      _buildDetailRow('Tanggal Persetujuan', DateFormat('dd MMMM yyyy HH:mm').format(file.approvedAt!)),
                  ],
                  if (file.description != null && file.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Keterangan / Deskripsi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(file.description!, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35)),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tautan dokumen ${file.title} disalin ke clipboard!'),
                                backgroundColor: const Color(0xFF0F172A),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Bagikan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Membuka dokumen ${file.fileName ?? file.title}...'),
                                backgroundColor: const Color(0xFF0284C7),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Buka / Unduh File'),
                        ),
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  void _showDocumentActions(DocumentItemModel file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Lihat Detail Dokumen'),
                onTap: () {
                  Navigator.pop(context);
                  _showDocumentDetailModal(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Unduh Berkas'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Mengunduh ${file.fileName ?? file.title}...')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus Dokumen', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _service.deleteDocument(file.id);
                  _fetchData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dokumen berhasil dihapus')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog() {
    final nameCtrl = TextEditingController();
    String selectedColor = '#3B82F6';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Buat Folder Baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nama Folder',
                      hintText: 'Misal: Dokumen Port 2026',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Pilih Warna Folder:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      '#3B82F6',
                      '#059669',
                      '#D97706',
                      '#7C3AED',
                      '#DC2626',
                    ].map((c) {
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDState(() => selectedColor = c),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _parseColor(c),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.black, width: 2.5) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    await _service.createFolder(
                      name: nameCtrl.text.trim(),
                      color: selectedColor,
                      parentId: _currentFolder?.id,
                    );
                    _fetchData();
                  },
                  child: const Text('Buat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreatePengajuanDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCategory = 'Pengajuan';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buat Pengajuan Dokumen & Perizinan',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Dokumen akan dikirim ke antrean persetujuan Atasan / Safety Officer.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Judul Pengajuan *',
                    hintText: 'Misal: Izin Kerja Panas Jetty Port Conveyor',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategori Dokumen',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Pengajuan', child: Text('Izin Kerja (PTW / Permit)')),
                    DropdownMenuItem(value: 'SOP', child: Text('Standard Operating Procedure (SOP)')),
                    DropdownMenuItem(value: 'Drive', child: Text('Dokumen Umum / Kebijakan')),
                  ],
                  onChanged: (v) => selectedCategory = v ?? 'Pengajuan',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Keterangan / Rincian Pengajuan',
                    hintText: 'Tuliskan deskripsi area, potensi bahaya, atau perlengkapan mitigasi...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(context);
                      await _service.submitPengajuan(
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        category: selectedCategory,
                        folderId: _currentFolder?.id ?? 2,
                      );
                      _fetchData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pengajuan dokumen berhasil dikirim ke antrean approval!'),
                            backgroundColor: Color(0xFF059669),
                          ),
                        );
                      }
                    },
                    child: const Text('Kirim Pengajuan Dokumen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUploadFileDialog() {
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Upload File Dokumen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama / Judul File',
                  hintText: 'Misal: Laporan_Audit_K3_Q3.pdf',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF0284C7)),
                    SizedBox(height: 6),
                    Text('Pilih Berkas dari Perangkat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
                    Text('PDF, DOCX, XLSX hingga 25 MB', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                await _service.submitPengajuan(
                  title: titleCtrl.text.trim(),
                  category: 'Drive',
                  folderId: _currentFolder?.id ?? 1,
                );
                _fetchData();
              },
              child: const Text('Unggah'),
            ),
          ],
        );
      },
    );
  }

  void _handleApproveDialog(DocumentItemModel file) {
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Setujui Dokumen?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin menyetujui dokumen "${file.title}"?'),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan Persetujuan (Opsional)',
                  hintText: 'Misal: Disetujui dengan APD lengkap',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                await _service.approveDocument(file.id, notes: notesCtrl.text.trim());
                _fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dokumen "${file.title}" berhasil disetujui!'), backgroundColor: const Color(0xFF059669)),
                  );
                }
              },
              child: const Text('Setujui'),
            ),
          ],
        );
      },
    );
  }

  void _handleRejectDialog(DocumentItemModel file) {
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Tolak Dokumen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tuliskan alasan penolakan atau revisi untuk "${file.title}":'),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Alasan / Catatan Revisi *',
                  hintText: 'Misal: JSA belum menyertakan mitigasi gas beracun',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                await _service.rejectDocument(file.id, notes: notesCtrl.text.trim());
                _fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dokumen "${file.title}" ditolak dengan catatan.'), backgroundColor: const Color(0xFFDC2626)),
                  );
                }
              },
              child: const Text('Tolak Dokumen'),
            ),
          ],
        );
      },
    );
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF3B82F6);
    try {
      final hex = hexString.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  Color _getFileTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'docx':
      case 'doc':
        return const Color(0xFF2563EB);
      case 'xlsx':
      case 'xls':
        return const Color(0xFF059669);
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF475569);
    }
  }

  IconData _getFileTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
