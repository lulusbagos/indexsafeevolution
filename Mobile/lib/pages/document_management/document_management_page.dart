import 'package:flutter/material.dart';
import '../../models/document_model.dart';
import '../../services/document_management_service.dart';
import '../../services/preference.dart';

class DocumentManagementPage extends StatefulWidget {
  const DocumentManagementPage({super.key});

  @override
  State<DocumentManagementPage> createState() => _DocumentManagementPageState();
}

class _DocumentManagementPageState extends State<DocumentManagementPage> {
  final DocumentManagementService _service = DocumentManagementService.instance;

  String _myName = 'LULUS BAGOS HERMAWAN';
  String _myDept = 'SYSTEM INTEGRATIONS';

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, dynamic>? _summary;
  List<DocumentFolderModel> _folders = [];
  List<DocumentItemModel> _files = [];

  @override
  void initState() {
    super.initState();
    final profile = PreferenceService.getProfile();
    _myName = profile?.namaLengkap ?? _myName;
    _myDept = profile?.depart ?? _myDept;

    _folders = _service.cachedFolders;
    _files = _service.getLocalFiles();
    _summary = _service.cachedSummary;

    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _service.getSummary(department: _myDept),
        _service.getFolders(),
        _service.getFiles(search: _searchQuery),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _folders = results[1] as List<DocumentFolderModel>;
          _files = results[2] as List<DocumentItemModel>;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0284C7); // Sky Blue Doc Management Accent

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
                    'DOCS',
                    style: TextStyle(
                      fontSize: 12,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Perizinan • SOP • Approval & Drive Tambang • $_myDept',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Dokumen',
            icon: const Icon(Icons.add_circle_outline_rounded, color: primaryColor),
            onPressed: _showUploadModal,
          ),
          IconButton(
            tooltip: 'Folder Arsip',
            icon: const Icon(Icons.folder_shared_rounded, color: Color(0xFF64748B)),
            onPressed: _showFolderBrowserModal,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          // 1. Top Enterprise Storage Hero Banner
          _buildStorageHeroBanner(),

          const SizedBox(height: 14),

          // 2. Search Bar
          _buildSearchBar(),

          const SizedBox(height: 16),

          // 3. Section 1: Perizinan Tambang & Legalitas (Mine Permits & Legal)
          _buildSectionCard(
            title: 'Perizinan Tambang & Legalitas',
            onTitleTap: () => _showToast('Kategori: Perizinan & Legalitas Tambang'),
            items: [
              _MenuItem(
                title: 'IUP & PKP2B',
                icon: Icons.gavel_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                badge: 'LEGAL',
                onTap: () => _showDocumentDetail(
                  'IUP Operasi Produksi & PKP2B',
                  'SK Izin Usaha Pertambangan Operasi Produksi resmi dari Kementerian ESDM & batas koordinat konsesi tambang PT Indexim Coalindo.',
                  'LEGAL-IDC-2024-001',
                  '2.4 MB (PDF Resmi)',
                ),
              ),
              _MenuItem(
                title: 'AMDAL & RKL',
                icon: Icons.eco_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFD1FAE5),
                onTap: () => _showDocumentDetail(
                  'Dokumen AMDAL & RKL-RPL Tambang',
                  'Persetujuan kelayakan lingkungan, izin pembuangan air limbah tambang ke sungai, dan kepatuhan baku mutu lingkungan hidup.',
                  'ENV-AMDAL-2023',
                  '8.6 MB (Dokumen AMDAL)',
                ),
              ),
              _MenuItem(
                title: 'Legalitas KTT',
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                badge: 'KTT',
                onTap: () => _showDocumentDetail(
                  'Pengesahan Kepala Teknik Tambang (KTT)',
                  'Surat penetapan KTT resmi dari KaIT (Direktur Jenderal Mineral & Batubara) dan Buku Tambang register PT Indexim Coalindo.',
                  'SK-KAIT-KTT-088',
                  '1.2 MB (SK Resmi)',
                ),
              ),
              _MenuItem(
                title: 'Izin Handak',
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                badge: 'RESTRICTED',
                onTap: () => _showDocumentDetail(
                  'Izin Gudang & Peledakan (Handak)',
                  'Izin kepemilikan dan penyimpanan bahan peledak dari Mabes Polri serta sertifikasi kompetensi juru ledak (KIM) kelas II.',
                  'POLRI-HANDAK-904',
                  '3.1 MB (Izin Khusus)',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Section 2: Standar Operasional Prosedur (SOP & Safety)
          _buildSectionCard(
            title: 'Standar Operasional Prosedur (SOP & K3LH)',
            onTitleTap: () => _showToast('Kategori: SOP & Standar K3LH'),
            items: [
              _MenuItem(
                title: 'SOP Operasi Pit',
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFDBEAFE),
                onTap: () => _showDocumentDetail(
                  'SOP Operasional Penambangan Pit',
                  'Prosedur baku penggalian overburden (OB), pemuatan batubara bersih (CCM), penataan ramp jalan pit, dan radio calling pit.',
                  'SOP-MGE-001-v2',
                  '1.8 MB (Standar Baku)',
                ),
              ),
              _MenuItem(
                title: 'Golden Rules',
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                badge: 'MUTLAK',
                onTap: () => _showDocumentDetail(
                  'Golden Safety Rules PT Indexim Coalindo',
                  '7 Aturan Keselamatan Tambang Mutlak: Penggunaan APD, Isolasi Energi (LOTO), Bekerja di Ketinggian, Fatigue, dan Kecepatan Hauling.',
                  'K3-GOLDEN-RULES',
                  '1.4 MB (Pedoman K3)',
                ),
              ),
              _MenuItem(
                title: 'Katalog JSA',
                icon: Icons.assignment_turned_in_rounded,
                iconColor: const Color(0xFF0F766E),
                bgColor: const Color(0xFFCCFBF1),
                onTap: () => _showDocumentDetail(
                  'Katalog Job Safety Analysis (JSA)',
                  'Kumpulan analisis keselamatan kerja terstandarisasi untuk pekerjaan perbaikan alat berat, pengelasan, dan survei medan terjal.',
                  'JSA-CATALOG-2026',
                  '4.5 MB (Kompilasi JSA)',
                ),
              ),
              _MenuItem(
                title: 'Tanggap Darurat',
                icon: Icons.emergency_rounded,
                iconColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEE2E2),
                badge: '24 JAM',
                onTap: () => _showDocumentDetail(
                  'Emergency Response Plan (ERP)',
                  'Prosedur evakuasi insiden tambang, alur panggilan darurat Emergency Call (0811-555-911), dan peta titik kumpul (muster point).',
                  'ERP-SITE-KLR-24',
                  '2.8 MB (Prosedur Darurat)',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5. Section 3: Pengajuan, Izin Khusus & Approval
          _buildSectionCard(
            title: 'Pengajuan & Izin Kerja Khusus',
            onTitleTap: () => _showToast('Kategori: Pengajuan & Izin Khusus'),
            items: [
              _MenuItem(
                title: 'Izin Khusus',
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFEDD5),
                badge: 'HOT WORK',
                onTap: () => _showDocumentDetail(
                  'Izin Pekerjaan Berisiko Tinggi (Special Permit)',
                  'Pengajuan izin kerja panas (pengelasan pit/plant), ruang terbatas (confined space), dan pekerjaan dekat air/tebing rawan longsor.',
                  'PERMIT-HW-2026-09',
                  'Formulir Digital Aktif',
                ),
              ),
              _MenuItem(
                title: 'Izin Melintas',
                icon: Icons.commute_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => _showDocumentDetail(
                  'Izin Mobilisasi & Melintas Jalan Hauling',
                  'Pengajuan izin mobilisasi alat berat oversized (Excavator PC2000, Dozer D375) dengan pengawalan safety escort vehicle.',
                  'PERMIT-ESCORT-11',
                  'Formulir Pengawalan',
                ),
              ),
              _MenuItem(
                title: 'Formulir SIMPER',
                icon: Icons.drive_eta_rounded,
                iconColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFCCFBF1),
                onTap: () => _showDocumentDetail(
                  'Permohonan Pembuatan & Perpanjangan SIMPER',
                  'Formulir pengajuan tes teori, tes praktik simulator, dan verifikasi MCU untuk lisensi mengemudi unit tambang.',
                  'FORM-SIMPER-IDC',
                  'Formulir Layanan HR/K3',
                ),
              ),
              _MenuItem(
                title: 'Approval Center',
                icon: Icons.fact_check_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFEDE9FE),
                badge: '2 PENDING',
                onTap: _showApprovalCenterModal,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 6. Section 4: Arsip Dokumen & Drive Cloud Tambang
          _buildSectionCard(
            title: 'Arsip Dokumen & Drive Cloud Tambang',
            onTitleTap: () => _showToast('Kategori: Arsip Dokumen & Drive'),
            items: [
              _MenuItem(
                title: 'Drive Utama',
                icon: Icons.cloud_done_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                badge: 'CLOUD',
                onTap: _showFolderBrowserModal,
              ),
              _MenuItem(
                title: 'Folder Dept',
                icon: Icons.folder_rounded,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                onTap: _showFolderBrowserModal,
              ),
              _MenuItem(
                title: 'Dokumen Mitra',
                icon: Icons.corporate_fare_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFD1FAE5),
                onTap: () => _showDocumentDetail(
                  'Arsip Legalitas Kontraktor Tambang',
                  'Kumpulan sertifikat CSMS, perjanjian subkontrak, struktur organisasi, dan daftar pengawas operasional kontraktor mitra.',
                  'CSMS-MITRA-ALL',
                  'Folder Mitra Terverifikasi',
                ),
              ),
              _MenuItem(
                title: 'Pedoman PKB',
                icon: Icons.library_books_rounded,
                iconColor: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
                onTap: () => _showDocumentDetail(
                  'Buku PKB & Pedoman Disiplin Tambang',
                  'Perjanjian Kerja Bersama Periode 2025–2027 memuat hak, tunjangan site, dan tata tertib keselamatan pekerja tambang.',
                  'PKB-IDC-2025-2027',
                  '142 Halaman PDF',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGETS
  // --------------------------------------------------------------------------

  Widget _buildStorageHeroBanner() {
    final totalFiles = _summary?['total_files'] ?? _files.length;
    final totalFolders = _summary?['total_folders'] ?? _folders.length;
    final usedStorage = _summary?['used_storage'] ?? '25.8 MB';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_queue_rounded, color: Color(0xFF7DD3FC), size: 14),
                    SizedBox(width: 5),
                    Text(
                      'MINE CLOUD STORAGE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Tersinkronisasi',
                style: TextStyle(fontSize: 11, color: Color(0xFFBAE6FD)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Penyimpanan Dokumen Tambang',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SOP, perizinan, dan arsip legalitas resmi terintegrasi cloud',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade100),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricCard('TOTAL DOKUMEN', '$totalFiles File', const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              _buildMetricCard('FOLDER ARSIP', '$totalFolders Folder', const Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              _buildMetricCard('TERPAKAI', '$usedStorage', const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
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
        onChanged: (val) {
          setState(() => _searchQuery = val);
          _fetchData();
        },
        decoration: InputDecoration(
          hintText: 'Cari SOP, regulasi, dokumen izin kerja, atau SK...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                    _fetchData();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required VoidCallback onTitleTap,
    required List<_MenuItem> items,
  }) {
    final filteredItems = _searchQuery.isEmpty
        ? items
        : items.where((i) => i.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filteredItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTitleTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filteredItems.map((item) {
              return Expanded(
                child: _buildGridItemTile(item),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItemTile(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: item.iconColor.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.iconColor.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: item.iconColor,
                      size: 28,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                height: 1.18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MODALS
  // --------------------------------------------------------------------------

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDocumentDetail(String title, String desc, String code, String size) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0284C7), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text('Nomor Reg: $code • $size', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                desc,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showToast('Dokumen $code siap dibagikan.');
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Bagikan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showToast('Mengunduh dokumen $code...');
                    },
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                    label: const Text('Unduh File', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 1. Folder Browser Modal
  void _showFolderBrowserModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.folder_shared_rounded, color: Color(0xFF0284C7), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Folder Arsip & Cloud Drive Tambang',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Struktur penyimpanan dokumen digital PT Indexim Coalindo.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              ..._folders.map((f) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.folder_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.name,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${f.filesCount} file tersimpan • Folder ${f.category}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Upload Document Modal
  void _showUploadModal() {
    final titleCtrl = TextEditingController();
    final noRegCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: Color(0xFF0284C7), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Unggah Dokumen Tambang Baru',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Nama / Judul Dokumen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  hintText: 'Contoh: JSA Penanganan Swa-Bakar ROM Stockpile',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 14),
              const Text('Nomor Dokumen / Registrasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: noRegCtrl,
                decoration: InputDecoration(
                  hintText: 'Contoh: JSA-MBS-2026-088',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dokumen berhasil diunggah ke Mine Cloud Drive dan menunggu verifikasi pengawas.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: const Text('Unggah Sekarang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Approval Center Modal
  void _showApprovalCenterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.fact_check_rounded, color: Color(0xFF7C3AED), size: 24),
                SizedBox(width: 8),
                Text(
                  'Approval Center Dokumen Tambang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildApprovalItem('Special Permit: Hot Work Pengelasan Hopper', 'Pengajuan oleh PT PAMA', 'Menunggu PJA', const Color(0xFFD97706)),
            _buildApprovalItem('Izin Melintas: Excavator PC2000 KM 12', 'Pengajuan oleh PT BUMA', 'Disetujui KTT', const Color(0xFF10B981)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tutup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalItem(String title, String subtitle, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.badge,
    required this.onTap,
  });
}
