import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../services/preference.dart';

class EmployeeHubPage extends StatefulWidget {
  const EmployeeHubPage({super.key});

  @override
  State<EmployeeHubPage> createState() => _EmployeeHubPageState();
}

class _EmployeeHubPageState extends State<EmployeeHubPage> {
  ProfileModel? _profile;

  // Profil Karyawan Aktif
  String _nama = 'LULUS BAGOS HERMAWAN';
  String _nik = '24051940986';
  String _dept = 'SYSTEM INTEGRATIONS';
  String _perusahaan = 'PT INDEXIM COALINDO';
  String _posisi = 'OFFICER PRODUCT & SYSTEM DEVELOPMENT';
  String _hp = '0812-3456-7890';
  String _email = 'lulus.hermawan@indexim.id';
  String _darurat = '0812-9876-5432 (Keluarga Inti)';
  String _daruratNama = 'Keluarga Inti';
  String _daruratHub = 'Istri';
  String _golDarah = 'O+';
  String _lokasiKerja = 'Kaliorang Site & Pit Central';
  String _statusKerja = 'PKWTT / Karyawan Tetap';
  String _minePermitNo = 'MP-IDC-2024-00892';
  String _simperClass = 'Kelas II (LV & Light Truck)';

  // Pencarian
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Daftar Mitra Kerja Tambang
  final List<Map<String, dynamic>> _mitraList = [
    {
      'kode': 'IDC',
      'nama': 'PT INDEXIM COALINDO',
      'tipe': 'Principal / Owner',
      'headcount': 842,
      'color': const Color(0xFF0F766E),
      'lokasi': 'Kaliorang Site Office',
    },
    {
      'kode': 'PAMA',
      'nama': 'PT PAMAPERSADA NUSANTARA',
      'tipe': 'Mining Contractor (OB & Coal)',
      'headcount': 2340,
      'color': const Color(0xFF2563EB),
      'lokasi': 'Pit Central & Pit West',
    },
    {
      'kode': 'BUMA',
      'nama': 'PT BUKIT MAKMUR MANDIRI UTAMA',
      'tipe': 'Mining Contractor (OB Removal)',
      'headcount': 1680,
      'color': const Color(0xFFD97706),
      'lokasi': 'Pit South & Dump East',
    },
    {
      'kode': 'KPP',
      'nama': 'PT KALIMANTAN PRIMA PERSADA',
      'tipe': 'Hauling & Road Maintenance',
      'headcount': 620,
      'color': const Color(0xFF7C3AED),
      'lokasi': 'Hauling Road KM 0 - KM 48',
    },
    {
      'kode': 'SIMS',
      'nama': 'PT SIMS JAYA KALTIM',
      'tipe': 'Coal Hauling & Stockpile Operator',
      'headcount': 510,
      'color': const Color(0xFFEA580C),
      'lokasi': 'ROM Stockpile & Port',
    },
    {
      'kode': 'RPP',
      'nama': 'PT RIZKI PATRA PRATAMA',
      'tipe': 'Crushing & Barge Loading',
      'headcount': 428,
      'color': const Color(0xFF059669),
      'lokasi': 'Port & Conveyor Jet Jetty',
    },
  ];

  @override
  void initState() {
    super.initState();
    _profile = PreferenceService.getProfile();
    if (_profile != null) {
      _nama = _profile!.namaLengkap ?? _nama;
      _nik = _profile!.noNik ?? _nik;
      _dept = _profile!.depart ?? _dept;
      _perusahaan = _profile!.company ?? _perusahaan;
      _posisi = _profile!.jabatan ?? _posisi;
      _hp = _profile!.hp ?? _hp;
      _email = _profile!.emailKantor ?? _email;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6366F1); // Indigo One EV Accent

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
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ONE EV',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Workforce Platform',
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
              'PT Indexim Coalindo & Mitra Kerja Tambang',
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
            tooltip: 'Profil Saya',
            icon: const Icon(Icons.badge_rounded, color: primaryColor),
            onPressed: _showProfileDetailModal,
          ),
          IconButton(
            tooltip: 'Mitra Kerja',
            icon: const Icon(Icons.corporate_fare_rounded, color: Color(0xFF64748B)),
            onPressed: _showMitraDirectoryModal,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          // 1. Top Enterprise Workforce Banner
          _buildWorkforceHeroBanner(),

          const SizedBox(height: 14),

          // 2. Search Bar
          _buildSearchFilterBar(),

          const SizedBox(height: 16),

          // 3. Section 1: Manajemen Profil & Karyawan Mitra
          _buildSectionCard(
            title: 'Profil & Data Karyawan Multi-Mitra',
            onTitleTap: () => _showFilterToast('Kategori: Data Karyawan Multi-Mitra'),
            items: [
              _MenuItem(
                title: 'Profil Karyawan',
                icon: Icons.account_box_rounded,
                iconColor: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
                onTap: _showProfileDetailModal,
              ),
              _MenuItem(
                title: 'Edit Data Karyawan',
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                badge: 'REVISI',
                onTap: _showEditEmployeeModal,
              ),
              _MenuItem(
                title: 'Database Mitra',
                icon: Icons.domain_rounded,
                iconColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFCCFBF1),
                badge: '18 Mitra',
                onTap: _showMitraDirectoryModal,
              ),
              _MenuItem(
                title: 'Mine Permit ID',
                icon: Icons.qr_code_2_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                onTap: _showMinePermitModal,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Section 2: Kualifikasi, SIMPER & Sertifikasi Tambang
          _buildSectionCard(
            title: 'Kualifikasi, SIMPER & Sertifikasi',
            onTitleTap: () => _showFilterToast('Kategori: SIMPER & Sertifikasi'),
            items: [
              _MenuItem(
                title: 'SIMPER Tambang',
                icon: Icons.drive_eta_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFDBEAFE),
                onTap: () => _showFeatureDetail(
                  'SIMPER (Surat Izin Mengemudi Perusahaan)',
                  'SIMPER aktif berlaku untuk unit LV Toyota Hilux & Light Hauler di area operasional Pit & Hauling Road PT Indexim Coalindo. Masa berlaku hingga 31 Desember 2026.',
                  Icons.drive_eta_rounded,
                  const Color(0xFF2563EB),
                ),
              ),
              _MenuItem(
                title: 'Sertifikat POP',
                icon: Icons.military_tech_rounded,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => _showFeatureDetail(
                  'Sertifikasi Pengawas Operasional Pertama (POP)',
                  'Sertifikasi kompetensi resmi Kementerian ESDM & BNSP untuk pengawasan teknis dan keselamatan operasional pertambangan mineral & batubara.',
                  Icons.military_tech_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
              _MenuItem(
                title: 'Status Induksi',
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFD1FAE5),
                badge: 'VALID',
                onTap: () => _showFeatureDetail(
                  'Kepatuhan Induksi & Re-Induksi K3LH',
                  'Seluruh pekerja PT Indexim dan mitra kerja wajib mengikuti induksi keselamatan umum dan re-induksi periodik setiap awal bulan.',
                  Icons.verified_user_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              _MenuItem(
                title: 'Matriks Skill',
                icon: Icons.psychology_rounded,
                iconColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFEDE9FE),
                onTap: () => _showFeatureDetail(
                  'Matriks Kompetensi & Lisensi Operator',
                  'Pemetaan skill operator alat berat, mekanik maintenance, surveyor, dan juru ledak (blasting) dari seluruh perusahaan mitra.',
                  Icons.psychology_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5. Section 3: Kesehatan Kerja & Fit to Work (OHS)
          _buildSectionCard(
            title: 'Kesehatan Kerja & Fit to Work (OHS)',
            onTitleTap: () => _showFilterToast('Kategori: Kesehatan Kerja & OHS'),
            items: [
              _MenuItem(
                title: 'MCU Berkala',
                icon: Icons.medical_services_rounded,
                iconColor: const Color(0xFFEC4899),
                bgColor: const Color(0xFFFCE7F3),
                badge: 'FIT 1',
                onTap: () => _showFeatureDetail(
                  'Medical Check Up (MCU) Tahunan',
                  'Pemeriksaan kesehatan menyeluruh meliputi Spirometri (paru), Audiometri (pendengaran), Darah Lengkap, dan Rontgen Thorax dengan hasil FIT TO WORK.',
                  Icons.medical_services_rounded,
                  const Color(0xFFEC4899),
                ),
              ),
              _MenuItem(
                title: 'Fatigue P5M',
                icon: Icons.bedtime_rounded,
                iconColor: const Color(0xFF0F766E),
                bgColor: const Color(0xFFCCFBF1),
                onTap: () => _showFeatureDetail(
                  'Fatigue Assessment & Jam Tidur Karyawan',
                  'Pengecekan kesiapan kerja harian melalui form P5M. Karyawan wajib memiliki durasi tidur minimal 6 jam untuk diizinkan beroperasi di pit.',
                  Icons.bedtime_rounded,
                  const Color(0xFF0F766E),
                ),
              ),
              _MenuItem(
                title: 'Klinik Site',
                icon: Icons.local_hospital_rounded,
                iconColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEE2E2),
                onTap: () => _showFeatureDetail(
                  'Klinik Darurat Tambang 24 Jam',
                  'Layanan pertolongan pertama, rawat jalan darurat, dan ambulans 4x4 siaga di Central Site Office & Pit Station.',
                  Icons.local_hospital_rounded,
                  const Color(0xFFEF4444),
                ),
              ),
              _MenuItem(
                title: 'BPJS & Asuransi',
                icon: Icons.health_and_safety_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => _showFeatureDetail(
                  'Jaminan Sosial & Proteksi Kerja',
                  'Nomor BPJS Ketenagakerjaan (JKK, JKM, JHT, JP) dan BPJS Kesehatan terintegrasi untuk seluruh karyawan internal dan kontraktor.',
                  Icons.health_and_safety_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 6. Section 4: Hubungan Industrial, Tata Tertib & Onboarding
          _buildSectionCard(
            title: 'Hubungan Industrial & Tata Tertib',
            onTitleTap: () => _showFilterToast('Kategori: Hubungan Industrial & Regulasi'),
            items: [
              _MenuItem(
                title: 'Mutasi & Roster',
                icon: Icons.swap_horiz_rounded,
                iconColor: const Color(0xFF475569),
                bgColor: const Color(0xFFF1F5F9),
                onTap: () => _showFeatureDetail(
                  'Jadwal Roster & Penempatan Area Tambang',
                  'Pengaturan jadwal kerja roster (6 minggu on : 2 minggu off / 5:2) dan rotasi area pit tambang antar mitra.',
                  Icons.swap_horiz_rounded,
                  const Color(0xFF475569),
                ),
              ),
              _MenuItem(
                title: 'PKB & Disiplin',
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF0369A1),
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => _showFeatureDetail(
                  'Perjanjian Kerja Bersama & Tata Tertib Tambang',
                  'Buku pedoman hak dan kewajiban pekerja, standar sanksi pelanggaran keselamatan, dan kode etik pertambangan PT Indexim Coalindo.',
                  Icons.menu_book_rounded,
                  const Color(0xFF0369A1),
                ),
              ),
              _MenuItem(
                title: 'Onboarding Site',
                icon: Icons.how_to_reg_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFD1FAE5),
                onTap: () => _showFeatureDetail(
                  'Prosedur Onboarding Karyawan Mitra',
                  'Alur pendaftaran personil baru mitra kerja: verifikasi KTP, MCU pra-kerja, safety induction, hingga penerbitan Mine Permit resmi.',
                  Icons.how_to_reg_rounded,
                  const Color(0xFF059669),
                ),
              ),
              _MenuItem(
                title: 'Whistleblower',
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                badge: 'RAHASIA',
                onTap: () => _showFeatureDetail(
                  'Saluran Whistleblowing & Konseling Karyawan',
                  'Kanal pelaporan rahasia untuk dugaan pelanggaran integritas, diskriminasi, bullying, atau ketidaksesuaian norma keselamatan kerja tambang.',
                  Icons.campaign_rounded,
                  const Color(0xFFDC2626),
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

  Widget _buildWorkforceHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.3),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_rounded, color: Color(0xFF818CF8), size: 14),
                    SizedBox(width: 5),
                    Text(
                      'TOTAL WORKFORCE SITE',
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
                'Live Monitoring',
                style: TextStyle(fontSize: 11, color: Color(0xFFA5B4FC)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '6,420 Tenaga Kerja Aktif',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tersebar di PT Indexim Coalindo & 18 Perusahaan Mitra Kerja Tambang',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFC7D2FE),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMiniMetric('PT INDEXIM', '842 Org', const Color(0xFF34D399)),
              const SizedBox(width: 8),
              _buildMiniMetric('KONTRAKTOR', '5,578 Org', const Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              _buildMiniMetric('MINE PERMIT', '99.4% Valid', const Color(0xFF60A5FA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
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
            Text(
              label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterBar() {
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
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Cari modul, NIK, nama karyawan, atau mitra...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
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
    // Filter items based on search query
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
          // Section Header row with title & arrow
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

          // 4-column Grid matching the reference screenshot
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
            // Rounded square container icon with badge
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
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
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

            // Item Label below
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
  // MODAL DIALOGS
  // --------------------------------------------------------------------------

  void _showFilterToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFeatureDetail(String title, String desc, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Modul Manajemen Tenaga Kerja Tambang',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
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
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Profil Karyawan Modal
  void _showProfileDetailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
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

              // ID Card Visual Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KARTU IDENTITAS PEKERJA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFA5B4FC),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  _perusahaan,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AKTIF',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _nama,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIK: $_nik • $_posisi',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC7D2FE),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildIdCardDetail('DEPARTEMEN', _dept),
                          _buildIdCardDetail('LOKASI', _lokasiKerja),
                          _buildIdCardDetail('GOL. DARAH', _golDarah),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Rincian Data Tenaga Kerja Tambang',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),

              _buildInfoRow('Perusahaan', _perusahaan, Icons.domain_rounded),
              _buildInfoRow('Nomor NIK', _nik, Icons.pin_rounded),
              _buildInfoRow('Jabatan / Posisi', _posisi, Icons.work_rounded),
              _buildInfoRow('Departemen', _dept, Icons.apartment_rounded),
              _buildInfoRow('Status Kerja', _statusKerja, Icons.assignment_ind_rounded),
              _buildInfoRow('Nomor Handphone', _hp, Icons.phone_android_rounded),
              _buildInfoRow('Email Resmi', _email, Icons.mail_outline_rounded),
              _buildInfoRow('Kontak Darurat', _darurat, Icons.emergency_rounded),
              _buildInfoRow('Nomor Mine Permit', _minePermitNo, Icons.qr_code_2_rounded),
              _buildInfoRow('Lisensi SIMPER', _simperClass, Icons.drive_eta_rounded),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditEmployeeModal();
                  },
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                  label: const Text(
                    'Perbarui Data Karyawan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
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

  Widget _buildIdCardDetail(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF818CF8))),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Edit Data Karyawan Modal
  void _showEditEmployeeModal() {
    final hpCtrl = TextEditingController(text: _hp);
    final emailCtrl = TextEditingController(text: _email);
    final daruratNamaCtrl = TextEditingController(text: _daruratNama);
    final daruratTelpCtrl = TextEditingController(text: '0812-9876-5432');
    String currentGolDarah = _golDarah;

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
          child: SingleChildScrollView(
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Data Karyawan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '$_nama ($_nik)',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                const Text('Nomor Handphone Aktif (WhatsApp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: hpCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 14),
                const Text('Email Kantor / Korespondensi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 14),
                const Text('Nama Kontak Darurat (Emergency)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: daruratNamaCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 14),
                const Text('Nomor Telepon Darurat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: daruratTelpCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.emergency_rounded, size: 20),
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
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hp = hpCtrl.text.trim();
                        _email = emailCtrl.text.trim();
                        _daruratNama = daruratNamaCtrl.text.trim();
                        _darurat = '$daruratNamaCtrl.text (${daruratTelpCtrl.text})';
                        _golDarah = currentGolDarah;
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data profil pekerja tambang berhasil diperbarui dan disinkronkan ke server.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Simpan Perubahan Data',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. Database Mitra Kerja Modal
  void _showMitraDirectoryModal() {
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
                  Icon(Icons.domain_rounded, color: Color(0xFF0D9488), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Direktori Perusahaan Mitra Kerja',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Kontraktor dan subkontraktor resmi yang beroperasi di wilayah konsesi PT Indexim Coalindo.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              ..._mitraList.map((m) {
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
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: (m['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            m['kode'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: m['color'] as Color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['nama'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m['tipe'] as String,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 3),
                                Text(
                                  m['lokasi'] as String,
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${m['headcount']} Org',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
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
    );
  }

  // 4. Mine Permit Modal
  void _showMinePermitModal() {
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
            const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: Color(0xFFD97706), size: 26),
                SizedBox(width: 10),
                Text(
                  'Kartu Mine Permit Tambang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'STATUS KEPATUHAN GATE PIT',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AUTHORIZED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Icon(Icons.fingerprint_rounded, size: 36, color: Color(0xFFD97706)),
                          SizedBox(height: 4),
                          Text('Biometrik Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.nfc_rounded, size: 36, color: Color(0xFF0284C7)),
                          SizedBox(height: 4),
                          Text('RFID Gate Valid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(Icons.health_and_safety_rounded, size: 36, color: Color(0xFF059669)),
                          SizedBox(height: 4),
                          Text('Fit to Work OK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
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
