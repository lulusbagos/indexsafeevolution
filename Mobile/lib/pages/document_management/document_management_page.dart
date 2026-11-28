import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/document_model.dart';
import '../../services/document_management_service.dart';

class DocumentManagementPage extends StatefulWidget {
  const DocumentManagementPage({super.key});

  @override
  State<DocumentManagementPage> createState() => _DocumentManagementPageState();
}

class _DocumentManagementPageState extends State<DocumentManagementPage> {
  final DocumentManagementService _service = DocumentManagementService.instance;

  // Search state
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isSearching = false;
  List<DocumentItemModel> _searchResults = [];

  // Quick category filters
  final List<String> _categoryFilters = [
    'Semua',
    'SOP',
    'JSA',
    'HIRADC',
    'Kebijakan',
    'IK (WI)',
    'Form',
    'Manual',
  ];
  String _selectedCategory = 'Semua';

  // Folder navigation hierarchy stack (Breadcrumbs)
  final List<DocumentFolderModel> _folderStack = [
    DocumentFolderModel(
      id: 9,
      name: 'PT Indexim Coalindo',
      path: 'PT Indexim Coalindo',
      color: '#0284C7',
      isBold: true,
      subfolderCount: 10,
      fileCount: 0,
    ),
  ];

  // Current folder content
  bool _isLoading = true;
  bool _isAccessDenied = false;
  String _accessDeniedMsg = '';
  List<DocumentFolderModel> _currentFolders = [];
  List<DocumentItemModel> _currentFiles = [];
  Map<String, dynamic>? _summary;

  // Downloading progress tracking
  int? _downloadingDocId;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';

  DocumentFolderModel get _currentFolder => _folderStack.last;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadFolderContent(_currentFolder.id);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _service.getSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFolderContent(int folderId) async {
    setState(() {
      _isLoading = true;
      _isAccessDenied = false;
      _accessDeniedMsg = '';
    });

    try {
      final foldersFuture = _service.getFolders(parentId: folderId);
      final filesFuture = _service.getFiles(folderId: folderId);

      final results = await Future.wait([foldersFuture, filesFuture]);

      if (mounted) {
        setState(() {
          _currentFolders = results[0] as List<DocumentFolderModel>;
          _currentFiles = results[1] as List<DocumentItemModel>;
          _isLoading = false;
          _isAccessDenied = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e is DocumentAccessDeniedException) {
            _isAccessDenied = true;
            _accessDeniedMsg = e.message;
            _currentFolders = [];
            _currentFiles = [];
          }
        });
      }
    }
  }

  void _navigateToFolder(DocumentFolderModel folder) {
    _folderStack.add(folder);
    _loadFolderContent(folder.id);
  }

  void _navigateUpToFolder(int index) {
    if (index < _folderStack.length - 1) {
      _folderStack.removeRange(index + 1, _folderStack.length);
      _loadFolderContent(_currentFolder.id);
    }
  }

  void _onCategorySelected(String cat) {
    setState(() {
      _selectedCategory = cat;
    });

    if (cat == 'Semua') {
      _searchCtrl.clear();
      _onSearchChanged('');
    } else {
      _searchCtrl.text = cat;
      _onSearchChanged(cat);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final term = query.trim();
      if (term.length < 2) {
        setState(() {
          _searchQuery = term;
          _isSearching = false;
          _searchResults = [];
        });
        return;
      }

      setState(() {
        _searchQuery = term;
        _isSearching = true;
      });

      final results = await _service.searchDocuments(term);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _openOrDownloadDocument(DocumentItemModel doc) async {
    if (_downloadingDocId != null) return;

    if (doc.isDownloaded && doc.localPath != null) {
      _showToast('Membuka ${doc.title} dari cache HP...');
      final opened = await _service.openDocument(doc);
      if (!opened && mounted) {
        _showToast('Gagal membuka dokumen, mencoba tautan online...');
      }
      return;
    }

    setState(() {
      _downloadingDocId = doc.id;
      _downloadProgress = 0.0;
      _downloadStatusText = 'Menghubungkan ke repositori...';
    });

    _showDownloadProgressDialog(doc);

    try {
      final success = await _service.openDocument(
        doc,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              if (total > 0) {
                _downloadProgress = received / total;
                _downloadStatusText =
                    '${(received / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB (${(_downloadProgress * 100).toInt()}%)';
              } else {
                _downloadStatusText = '${(received / 1024).toStringAsFixed(0)} KB terunduh';
              }
            });
          }
        },
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _downloadingDocId = null;
        });

        if (success) {
          _showToast('Dokumen berhasil dibuka & tersimpan offline.');
        } else {
          _showToast('Gagal mengunduh atau membuka file.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _downloadingDocId = null;
        });
        _showToast('Terjadi kesalahan: $e');
      }
    }
  }

  void _showDownloadProgressDialog(DocumentItemModel doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 16,
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.downloading_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Mengunduh Dokumen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    doc.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _downloadStatusText.isNotEmpty ? _downloadStatusText : 'Menyiapkan berkas...',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAccessInfoSheet() {
    final userScope = _service.lastUserScope;
    final roleName = userScope?['roleName'] ?? 'Pengguna Terdaftar';
    final companyName = userScope?['companyName'] ?? 'PT Indexim Coalindo';
    final deptName = userScope?['departmentName'] ?? 'Operasional & Keselamatan';
    final userName = userScope?['fullName'] ?? 'Pengguna';
    final userNik = userScope?['username'] ?? '-';
    final isOwner = userScope?['isOwner'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hak Akses Terverifikasi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tersinkronisasi otomatis dengan akun ONE EV',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Nama Lengkap', userName),
                _buildInfoRow('NIK / Username', userNik),
                _buildInfoRow('Peran Akses', roleName, isHighlight: true),
                _buildInfoRow('Perusahaan', companyName),
                if (deptName.toString().isNotEmpty)
                  _buildInfoRow('Departemen', deptName.toString()),
                _buildInfoRow('Akses Folder', isOwner ? 'Akses Penuh Seluruh Repositori' : 'Sesuai Kebijakan ONE EV'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isHighlight ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildExecutiveAppBar(),
      body: RefreshIndicator(
        color: const Color(0xFF0284C7),
        onRefresh: () async {
          await _loadSummary();
          await _loadFolderContent(_currentFolder.id);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // 1. Sleek Executive Hero Card
            _buildExecutiveHero(),

            const SizedBox(height: 14),

            // 2. Modern Capsule Search Bar
            _buildSearchBox(),

            const SizedBox(height: 10),

            // 3. Quick Category Filter Chips
            _buildCategoryChips(),

            const SizedBox(height: 14),

            // Search results or Folder Content
            if (_searchQuery.isNotEmpty) ...[
              _buildSearchResultsSection(),
            ] else ...[
              // 4. Apple-Style Breadcrumbs Navigation Bar
              _buildBreadcrumbBar(),

              const SizedBox(height: 12),

              // 5. Folder Content View (Folders & Files)
              if (_isLoading)
                _buildLoadingState()
              else if (_isAccessDenied)
                _buildAccessDeniedState()
              else
                _buildFolderAndFilesView(),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EXECUTIVE APP BAR
  // --------------------------------------------------------------------------

  PreferredSizeWidget _buildExecutiveAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF334155)),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ONE EV',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Dokumen Manajemen',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
              Text(
                'Repositori Resmi PT Indexim Coalindo',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Hak Akses Anda',
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF16A34A)),
          ),
          onPressed: _showAccessInfoSheet,
        ),
        IconButton(
          tooltip: 'Segarkan Dokumen',
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0284C7)),
          ),
          onPressed: () {
            _loadSummary();
            _loadFolderContent(_currentFolder.id);
            _showToast('Memperbarui repositori dokumen...');
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // EXECUTIVE HERO CARD
  // --------------------------------------------------------------------------

  Widget _buildExecutiveHero() {
    final totalDocs = _summary?['totalDocuments'] ?? 4141;
    final totalFolders = _summary?['totalFolders'] ?? 896;
    final formattedStorage = _summary?['storageFormatted'] ?? '5.98 GB';
    final sopCount = _summary?['activeSopCount'] ?? 521;
    final jsaCount = _summary?['jsaCount'] ?? 1556;

    final userScope = _service.lastUserScope;
    final roleName = userScope?['roleName'] ?? 'Pengguna Terverifikasi';
    final companyName = userScope?['companyName'] ?? 'PT Indexim Coalindo';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Micro Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 13),
                    SizedBox(width: 5),
                    Text(
                      'DATABASE LIVE TERVERIFIKASI',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_download_outlined, color: Color(0xFF7DD3FC), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      formattedStorage,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE0F2FE),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Main Header Title
          const Text(
            'Document Management Explorer',
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Koleksi dokumen SOP, HIRADC, JSA, Form & Kebijakan resmi. Berkas diunduh otomatis ke memori HP saat Anda mengetuknya.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade300,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 16),

          // 3 Sleek Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: '$totalDocs',
                  subtitle: 'Dokumen Aktif',
                  icon: Icons.description_rounded,
                  accentColor: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: '$totalFolders',
                  subtitle: 'Folder Arsip',
                  icon: Icons.folder_copy_rounded,
                  accentColor: const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: '$sopCount / $jsaCount',
                  subtitle: 'SOP & JSA Utama',
                  icon: Icons.verified_user_rounded,
                  accentColor: const Color(0xFFFBBF24),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // User Scope Bar
          GestureDetector(
            onTap: _showAccessInfoSheet,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_rounded, size: 13, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Akses Akun: $roleName • $companyName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SEARCH & CATEGORY CHIPS
  // --------------------------------------------------------------------------

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Cari 4.100+ dokumen (SOP, JSA, HIRADC, Form, Nomor Dokumen)...',
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 22),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                    setState(() => _selectedCategory = 'Semua');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categoryFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final cat = _categoryFilters[idx];
          final isSelected = _selectedCategory == cat;

          return InkWell(
            onTap: () => _onCategorySelected(cat),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BREADCRUMB NAVIGATION
  // --------------------------------------------------------------------------

  Widget _buildBreadcrumbBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_shared_rounded, size: 16, color: Color(0xFF0284C7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_folderStack.length, (index) {
                  final folder = _folderStack[index];
                  final isLast = index == _folderStack.length - 1;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: isLast ? null : () => _navigateUpToFolder(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: isLast
                              ? BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : null,
                          child: Text(
                            folder.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                              color: isLast ? const Color(0xFF0F172A) : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (_folderStack.length > 1)
            Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => _navigateUpToFolder(_folderStack.length - 2),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFF334155)),
                      SizedBox(width: 4),
                      Text(
                        'Naik',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CONTENT & EMPTY STATES
  // --------------------------------------------------------------------------

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(color: Color(0xFF0284C7), strokeWidth: 2.8),
          ),
          const SizedBox(height: 16),
          Text(
            'Menyiapkan repositori dokumen...',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedState() {
    final userScope = _service.lastUserScope;
    final roleName = userScope?['roleName'] ?? 'Pengguna';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 30),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Akses Folder Dibatasi',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _accessDeniedMsg.isNotEmpty
                ? _accessDeniedMsg
                : 'Folder ini dibatasi sesuai kebijakan keamanan ONE EV untuk peran akun Anda ($roleName). Hubungi Administrator ONE EV jika memerlukan akses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (_folderStack.length > 1)
            ElevatedButton.icon(
              onPressed: () => _navigateUpToFolder(_folderStack.length - 2),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Kembali ke Folder Sebelumnya'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderAndFilesView() {
    final hasFolders = _currentFolders.isNotEmpty;
    final hasFiles = _currentFiles.isNotEmpty;

    if (!hasFolders && !hasFiles) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Icon(Icons.folder_open_rounded, size: 36, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Dokumen di Folder Ini',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Direktori ini belum memiliki subfolder atau file dokumen yang dipublikasikan dari sistem One Evolution.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_folderStack.length > 1) ...[
                  ElevatedButton.icon(
                    onPressed: () => _navigateUpToFolder(_folderStack.length - 2),
                    icon: const Icon(Icons.arrow_back_rounded, size: 15),
                    label: const Text('Folder Sebelumnya'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    _loadFolderContent(_currentFolder.id);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Segarkan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daftar Subfolder
        if (hasFolders) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_copy_rounded, size: 15, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Text(
                      'Subfolder Direktori (${_currentFolders.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Ketuk untuk membuka',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _currentFolders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) => _buildFolderCard(_currentFolders[idx]),
          ),
          const SizedBox(height: 18),
        ],

        // Daftar File Dokumen
        if (hasFiles) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.file_present_rounded, size: 15, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Text(
                      'File Dokumen Resmi (${_currentFiles.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Ketuk untuk baca',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _currentFiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) => _buildFileCard(_currentFiles[idx]),
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------------------------------
  // MODERN FOLDER CARD
  // --------------------------------------------------------------------------

  Widget _buildFolderCard(DocumentFolderModel folder) {
    Color folderColor;
    try {
      folderColor = Color(int.parse(folder.color.replaceAll('#', '0xFF')));
    } catch (_) {
      folderColor = const Color(0xFF0284C7);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToFolder(folder),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        folderColor.withValues(alpha: 0.15),
                        folderColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: folderColor.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Icon(Icons.folder_rounded, color: folderColor, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: folder.isBold ? FontWeight.w800 : FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (folder.subfolderCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_copy_outlined, size: 10.5, color: Colors.grey.shade600),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${folder.subfolderCount} subfolder',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_outlined, size: 10.5, color: Colors.grey.shade600),
                                const SizedBox(width: 3),
                                Text(
                                  '${folder.fileCount} file',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MODERN FILE CARD
  // --------------------------------------------------------------------------

  Widget _buildFileCard(DocumentItemModel doc) {
    IconData fileIcon = Icons.picture_as_pdf_rounded;
    Color iconColor = const Color(0xFFDC2626);
    Color bgColor = const Color(0xFFFEE2E2);
    String typeBadge = 'PDF';

    if (doc.fileType.contains('doc')) {
      fileIcon = Icons.description_rounded;
      iconColor = const Color(0xFF2563EB);
      bgColor = const Color(0xFFDBEAFE);
      typeBadge = 'DOCX';
    } else if (doc.fileType.contains('xls')) {
      fileIcon = Icons.table_chart_rounded;
      iconColor = const Color(0xFF059669);
      bgColor = const Color(0xFFD1FAE5);
      typeBadge = 'XLSX';
    }

    final isDownloadingThis = _downloadingDocId == doc.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: doc.isDownloaded ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: doc.isDownloaded ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openOrDownloadDocument(doc),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(fileIcon, color: iconColor, size: 20),
                      const SizedBox(height: 1),
                      Text(
                        typeBadge,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: iconColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: doc.isBold ? FontWeight.w800 : FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              doc.formattedSize,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (doc.createdAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              doc.createdAt!.split(' ').first,
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                            ),
                          ],
                          const Spacer(),
                          if (doc.isDownloaded) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF16A34A)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Tersimpan',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'On-Demand',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isDownloadingThis)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0284C7)),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: doc.isDownloaded ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: doc.isDownloaded ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Icon(
                      doc.isDownloaded ? Icons.visibility_rounded : Icons.download_rounded,
                      size: 18,
                      color: doc.isDownloaded ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SEARCH RESULTS
  // --------------------------------------------------------------------------

  Widget _buildSearchResultsSection() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(color: Color(0xFF0284C7), strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            Text(
              'Mencari "$_searchQuery" di seluruh dokumen tambang...',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Tidak Ditemukan Dokumen',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada dokumen yang cocok dengan "$_searchQuery". Coba cari kata kunci SOP, HIRADC, JSA, atau nomor dokumen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hasil Pencarian (${_searchResults.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () {
                _searchCtrl.clear();
                _onSearchChanged('');
                setState(() => _selectedCategory = 'Semua');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Tutup Pencarian',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) => _buildFileCard(_searchResults[idx]),
        ),
      ],
    );
  }
}
