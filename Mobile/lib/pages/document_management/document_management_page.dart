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

  // Folder navigation hierarchy stack (Breadcrumbs)
  // Default root is folder ID 9: "PT Indexim Coalindo"
  final List<DocumentFolderModel> _folderStack = [
    DocumentFolderModel(
      id: 9,
      name: 'PT Indexim Coalindo',
      path: 'PT Indexim Coalindo',
      color: '#f50000',
      isBold: true,
      subfolderCount: 10,
      fileCount: 0,
    ),
  ];

  // Current folder content
  bool _isLoading = true;
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
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
    // Jika sedang mendownload dokumen lain, abaikan
    if (_downloadingDocId != null) return;

    // Cek apakah sudah pernah didownload ke cache
    if (doc.isDownloaded && doc.localPath != null) {
      _showToast('Membuka ${doc.title} dari cache lokal...');
      final opened = await _service.openDocument(doc);
      if (!opened && mounted) {
        _showToast('Gagal membuka dokumen, mencoba tautan online...');
      }
      return;
    }

    // Unduh on-demand dengan dialog progress
    setState(() {
      _downloadingDocId = doc.id;
      _downloadProgress = 0.0;
      _downloadStatusText = 'Menghubungkan ke server...';
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
        Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog progress
        setState(() {
          _downloadingDocId = null;
        });

        if (success) {
          _showToast('Dokumen berhasil dibuka & tersimpan di cache.');
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.downloading_rounded, color: Color(0xFF0284C7), size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mengunduh Dokumen On-Demand',
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
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _downloadStatusText.isNotEmpty ? _downloadStatusText : 'Mengunduh file...',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
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

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ONE EV',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Dokumen Management',
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
            Text(
              'Repositori Dokumen Resmi • ONE_DB_MITRA /DocumentManagement',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Dokumen',
            icon: const Icon(Icons.refresh_rounded, color: primaryColor),
            onPressed: () {
              _loadSummary();
              _loadFolderContent(_currentFolder.id);
              _showToast('Memperbarui repositori dokumen...');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadSummary();
          await _loadFolderContent(_currentFolder.id);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // 1. Enterprise Storage Banner
            _buildEnterpriseBanner(),

            const SizedBox(height: 14),

            // 2. Fast Instant Search Box
            _buildSearchBox(),

            const SizedBox(height: 14),

            // Jika sedang mode pencarian aktif
            if (_searchQuery.isNotEmpty) ...[
              _buildSearchResultsSection(),
            ] else ...[
              // 3. Hierarchical Breadcrumb Navigation Bar
              _buildBreadcrumbBar(),

              const SizedBox(height: 12),

              // 4. Folder Content Area (Folders & Files)
              if (_isLoading)
                _buildLoadingState()
              else
                _buildFolderAndFilesView(),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGETS
  // --------------------------------------------------------------------------

  Widget _buildEnterpriseBanner() {
    final totalDocs = _summary?['totalDocuments'] ?? 4141;
    final totalFolders = _summary?['totalFolders'] ?? 896;
    final formattedStorage = _summary?['storageFormatted'] ?? '5.98 GB';
    final sopCount = _summary?['activeSopCount'] ?? 521;
    final jsaCount = _summary?['jsaCount'] ?? 1556;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF075985), Color(0xFF0C4A6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done_rounded, color: Color(0xFF7DD3FC), size: 14),
                    SizedBox(width: 5),
                    Text(
                      'DATABASE LIVE TERVERIFIKASI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFFFDE047), size: 14),
                  SizedBox(width: 3),
                  Text(
                    'On-Demand Download',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFBAE6FD),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Document Management Explorer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Koleksi dokumen SOP, HIRADC, JSA, Form & Kebijakan PT Indexim Coalindo. File hanya diunduh saat Anda mengetuknya.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol('$totalDocs', 'Dokumen Aktif'),
                _buildMetricDivider(),
                _buildMetricCol('$totalFolders', 'Folder Arsip'),
                _buildMetricDivider(),
                _buildMetricCol(formattedStorage, 'Penyimpanan'),
                _buildMetricDivider(),
                _buildMetricCol('$sopCount SOP / $jsaCount JSA', 'Katalog Utama'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 22,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
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
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_rounded, size: 16, color: Color(0xFF0284C7)),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            folder.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                              color: isLast ? const Color(0xFF0F172A) : const Color(0xFF0284C7),
                              decoration: isLast ? TextDecoration.none : TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (_folderStack.length > 1)
            InkWell(
              onTap: () => _navigateUpToFolder(_folderStack.length - 2),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFF475569)),
                    SizedBox(width: 3),
                    Text(
                      'Naik',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFF0284C7), strokeWidth: 2.5),
          const SizedBox(height: 14),
          Text(
            'Memuat folder & file dokumen...',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
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
        padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text(
              'Folder Ini Kosong',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              'Belum ada subfolder atau file dokumen di dalam direktori ini.',
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
        // Daftar Subfolder
        if (hasFolders) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subfolder (${_currentFolders.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Ketuk untuk membuka',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'File Dokumen (${_currentFiles.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                  letterSpacing: -0.2,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF0284C7)),
                  SizedBox(width: 3),
                  Text(
                    'Ketuk untuk baca',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
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

  Widget _buildFolderCard(DocumentFolderModel folder) {
    Color folderColor;
    try {
      folderColor = Color(int.parse(folder.color.replaceAll('#', '0xFF')));
    } catch (_) {
      folderColor = const Color(0xFF0284C7);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () => _navigateToFolder(folder),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: folderColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(Icons.folder_rounded, color: folderColor, size: 24),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontWeight: folder.isBold ? FontWeight.w900 : FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (folder.subfolderCount > 0) ...[
                          Icon(Icons.folder_copy_outlined, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            '${folder.subfolderCount} subfolder',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.description_outlined, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          '${folder.fileCount} file dokumen',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(DocumentItemModel doc) {
    // Determine icon and color based on file type
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () => _openOrDownloadDocument(doc),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: doc.isDownloaded ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
              width: doc.isDownloaded ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          Text(
                            'On-Demand',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
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
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0284C7)),
                )
              else
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: doc.isDownloaded ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
    );
  }

  Widget _buildSearchResultsSection() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF0284C7), strokeWidth: 2.5),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text(
              'Tidak Ditemukan Dokumen',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada dokumen yang cocok dengan kata kunci "$_searchQuery". Coba cari kata kunci SOP, HIRADC, JSA, atau nomor dokumen.',
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
                color: Color(0xFF334155),
              ),
            ),
            InkWell(
              onTap: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              },
              child: const Text(
                'Tutup Pencarian',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
