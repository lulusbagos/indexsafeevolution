import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/profile_model.dart';
import '../../services/preference.dart';
import '../../services/one_ev_service.dart';

class EmployeeHubPage extends StatefulWidget {
  const EmployeeHubPage({super.key});

  @override
  State<EmployeeHubPage> createState() => _EmployeeHubPageState();
}

class _EmployeeHubPageState extends State<EmployeeHubPage> {
  final OneEvService _oneEvService = OneEvService.instance;
  ProfileModel? _profile;

  // Profil Karyawan Aktif (Live dari ONE_DB_MITRA)
  bool _isLoading = true;
  String _nama = '';
  String _namaAlias = '';
  String _wargaNegara = '';
  String _nik = '';
  String _noKtp = '';
  String _noKk = '';
  String _jenisKelamin = '';
  String _tempatLahir = '';
  String _tanggalLahir = '';
  String _agama = '';
  int? _idAgama;
  String _statusNikah = '';
  int? _idStatusNikah;
  String? _golDarah;
  String _namaIbu = '';
  String _namaAyah = '';

  // Domisili
  String _provinsi = '';
  String _kabupaten = '';
  String _kecamatan = '';
  String _desa = '';
  String _rt = '';
  String _rw = '';
  String _kodePos = '';
  String _alamat = '';

  // Kontak Utama
  String _hp = '';
  String _hp2 = '';
  String _emailPribadi = '';
  String _emailKantor = '';

  // Kontak Darurat
  String _daruratNama = '';
  String _daruratTelp = '';
  String _daruratTelpLain = '';
  String _daruratRelasi = '';
  String _daruratKeterangan = '';

  // Jaminan & Pajak
  String _noNpwp = '';
  String _noBpjsTk = '';
  String _noBpjsKes = '';
  String _noBpjsPensiun = '';

  // Pendidikan
  int? _idPendidikan;
  String _jenjangPendidikan = '';
  String _namaSekolah = '';
  String _fakultas = '';
  String _jurusan = '';

  // Kepegawaian (Terkunci HR - Read Only)
  String _dept = '';
  String _seksi = '';
  String _perusahaan = '';
  String _posisi = '';
  String _jabatan = '';
  String _grade = '';
  String _roster = '';
  String _tanggalMasuk = '';
  String _statusKerja = '';
  String _minePermitNo = '';
  String _minePermitExp = '';
  String _simperClass = 'Tidak Ada / Belum Terdaftar';
  Map<String, dynamic>? _simperData;
  String? _pathFoto;

  // MCU dari tbl_t_karyawan_mcu
  String? _mcuTanggal;
  String? _mcuHasil;
  String? _mcuKeterangan;
  String? _mcuFile;

  // Data List dari ONE_DB_MITRA
  List<Map<String, dynamic>> _certificates = [];
  List<Map<String, dynamic>> _skillMatrix = [];

  // Pencarian
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profile = PreferenceService.getProfile();
    if (_profile != null) {
      _nama = _profile!.namaLengkap ?? '';
      _namaAlias = _profile!.namaAlias ?? '';
      _nik = _profile!.noNik ?? '';
      _noKtp = _profile!.noKtp ?? '';
      _noKk = _profile!.noKk ?? '';
      _jenisKelamin = _profile!.jk ?? '';
      _tempatLahir = _profile!.tmpLahir ?? '';
      _tanggalLahir = _profile!.tglLahir ?? '';
      _agama = _profile!.agama ?? '';
      _statusNikah = _profile!.statNikah ?? '';
      _wargaNegara = _profile!.wn ?? 'WNI';
      _namaIbu = _profile!.namaIbu ?? '';
      _namaAyah = _profile!.namaAyah ?? '';
      _emailPribadi = _profile!.emailPribadi ?? '';
      _hp = _profile!.hp ?? '';
      _emailKantor = _profile!.emailKantor ?? '';
      _noNpwp = _profile!.noNpwp ?? '';
      _noBpjsTk = _profile!.noBpjstk ?? '';
      _noBpjsKes = _profile!.noBpjskes ?? '';
      _noBpjsPensiun = _profile!.noBpjspensiun ?? '';
      _dept = _profile!.depart ?? '';
      _perusahaan = _profile!.company ?? '';
      _posisi = _profile!.jabatan ?? _profile!.posisi ?? '';
      _jabatan = _profile!.posisi ?? _profile!.jabatan ?? '';
      _grade = _profile!.grade ?? '';
      _roster = _profile!.roster != null ? '${_profile!.roster}' : '';
      _minePermitNo = _profile!.noNik ?? '';
      _pathFoto = _profile!.foto;
    }
    _loadLiveOneEvData();
  }

  String _resolvePhotoUrl(String? path) {
    if (path != null && path.trim().isNotEmpty) {
      final trimmed = path.trim();
      if (trimmed.startsWith('http')) return trimmed;
      final clean = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return 'https://oneev.indexim.id$clean';
    }
    final prefFoto = PreferenceService.getProfile()?.foto;
    if (prefFoto != null && prefFoto.trim().isNotEmpty) {
      final trimmed = prefFoto.trim();
      if (trimmed.startsWith('http')) return trimmed;
      final clean = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return 'https://oneev.indexim.id$clean';
    }
    return '';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLiveOneEvData() async {
    setState(() => _isLoading = true);
    try {
      final userNik = _nik.isNotEmpty ? _nik : PreferenceService.getProfile()?.noNik ?? '';
      
      // Ambil seluruh data secara simultan/paralel ke backend HTTPS resmi
      final results = await Future.wait([
        _oneEvService.fetchProfile(nik: userNik),
        _oneEvService.fetchCertificates(nik: userNik),
        _oneEvService.fetchSkillMatrix(nik: userNik),
        _oneEvService.fetchSimper(nik: userNik),
      ]);

      final profData = results[0] as Map<String, dynamic>;
      final certs = results[1] as List<Map<String, dynamic>>;
      final skills = results[2] as List<Map<String, dynamic>>;
      final simperData = results[3] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _nama = profData['nama_lengkap'] ?? _nama;
          _namaAlias = profData['nama_alias'] ?? '';
          _wargaNegara = profData['warga_negara'] ?? '';
          _nik = profData['no_nik'] ?? _nik;
          _noKtp = profData['no_ktp'] ?? '';
          _noKk = profData['no_kk'] ?? '';
          _jenisKelamin = profData['jenis_kelamin'] ?? '';
          _tempatLahir = profData['tempat_lahir'] ?? '';
          _tanggalLahir = profData['tanggal_lahir'] ?? '';
          _agama = profData['agama'] ?? '';
          _idAgama = profData['id_agama'];
          _statusNikah = profData['status_nikah'] ?? '';
          _idStatusNikah = profData['id_status_nikah'];
          _golDarah = profData['golongan_darah'];
          _namaIbu = profData['nama_ibu'] ?? '';
          _namaAyah = profData['nama_ayah'] ?? '';

          _provinsi = profData['provinsi'] ?? '';
          _kabupaten = profData['kabupaten'] ?? '';
          _kecamatan = profData['kecamatan'] ?? '';
          _desa = profData['desa'] ?? '';
          _rt = profData['rt'] ?? '';
          _rw = profData['rw'] ?? '';
          _kodePos = profData['kode_pos'] ?? '';
          _alamat = profData['alamat'] ?? '';

          _hp = profData['hp_1'] ?? _hp;
          _hp2 = profData['hp_2'] ?? '';
          _emailPribadi = profData['email_pribadi'] ?? '';
          _emailKantor = profData['email_kantor'] ?? _emailKantor;

          _daruratNama = profData['kontak_darurat_nama'] ?? '';
          _daruratTelp = profData['kontak_darurat_telp'] ?? '';
          _daruratTelpLain = profData['kontak_darurat_telp_lain'] ?? '';
          _daruratRelasi = profData['kontak_darurat_relasi'] ?? '';
          _daruratKeterangan = profData['kontak_darurat_keterangan'] ?? '';

          _noNpwp = profData['no_npwp'] ?? '';
          _noBpjsTk = profData['no_bpjs_tk'] ?? '';
          _noBpjsKes = profData['no_bpjs_kes'] ?? '';
          _noBpjsPensiun = profData['no_bpjs_pensiun'] ?? '';

          _idPendidikan = profData['id_pendidikan'];
          _jenjangPendidikan = profData['jenjang_pendidikan'] ?? '';
          _namaSekolah = profData['nama_sekolah'] ?? '';
          _fakultas = profData['fakultas'] ?? '';
          _jurusan = profData['jurusan'] ?? '';

          _perusahaan = profData['nama_perusahaan'] ?? _perusahaan;
          _dept = profData['nama_departemen'] ?? _dept;
          _seksi = profData['nama_seksi'] ?? '';
          _posisi = profData['nama_posisi'] ?? _posisi;
          _jabatan = profData['nama_jabatan'] ?? _jabatan;
          _grade = profData['grade'] ?? '';
          _roster = profData['roster_kerja'] ?? '';
          _tanggalMasuk = profData['tanggal_masuk'] ?? '';
          _minePermitNo = profData['no_nik'] ?? _nik;
          _minePermitExp = profData['permit_berakhir'] ?? '-';
          _pathFoto = profData['path_foto'];

          _mcuTanggal = profData['mcu_tanggal']?.toString();
          _mcuHasil = profData['mcu_hasil']?.toString();
          _mcuKeterangan = profData['mcu_keterangan']?.toString();
          _mcuFile = profData['mcu_file']?.toString();

          _certificates = certs;
          _skillMatrix = skills;
          _simperData = simperData;
          if (simperData != null && simperData['has_simper'] != false) {
            final noSimper = simperData['nomor']?.toString() ?? '';
            final units = (simperData['units'] as List?) ?? [];
            _simperClass = noSimper.isNotEmpty ? '$noSimper (${units.length} Unit Diizinkan)' : 'Belum Terdaftar';
          }
          _isLoading = false;
        });

        // Sinkronkan ke profile preference lokal agar formulir offline selalu lengkap
        try {
          final pref = PreferenceService.getProfile() ?? ProfileModel();
          pref.noKtp = _noKtp;
          pref.noKk = _noKk;
          pref.tmpLahir = _tempatLahir;
          pref.tglLahir = _tanggalLahir;
          pref.agama = _agama;
          pref.statNikah = _statusNikah;
          pref.namaIbu = _namaIbu;
          pref.namaAyah = _namaAyah;
          pref.noNpwp = _noNpwp;
          pref.noBpjstk = _noBpjsTk;
          pref.noBpjskes = _noBpjsKes;
          pref.noBpjspensiun = _noBpjsPensiun;
          if (_pathFoto != null && _pathFoto!.isNotEmpty) {
            pref.foto = _pathFoto;
          }
          await PreferenceService.setProfile(pref);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[OneEv] Error loading live data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            tooltip: 'Refresh Data Database',
            icon: const Icon(Icons.refresh_rounded, color: primaryColor),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadLiveOneEvData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memuat ulang data terbaru dari ONE Evolution...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Profil Saya',
            icon: const Icon(Icons.badge_rounded, color: primaryColor),
            onPressed: _showProfileDetailModal,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadLiveOneEvData,
            color: primaryColor,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              children: [
                // 1. Top Enterprise Workforce Banner (Live dari ONE_DB_MITRA)
                _buildWorkforceHeroBanner(),

                const SizedBox(height: 14),

                // 2. Search Bar
            _buildSearchFilterBar(),

            const SizedBox(height: 16),

            // 3. Section 1: Manajemen Profil & Karyawan (Fokus Personal & Administrasi)
            _buildSectionCard(
              title: 'Data Karyawan & Administrasi (One Evolution)',
              onTitleTap: () => _showFilterToast('Kategori: Data Karyawan One Evolution'),
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
                  title: 'Mine Permit ID',
                  icon: Icons.qr_code_2_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  badge: 'AKTIF',
                  onTap: _showMinePermitModal,
                ),
                _MenuItem(
                  title: 'SIMPER Tambang',
                  icon: Icons.drive_eta_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFDBEAFE),
                  onTap: _showSimperModal,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 4. Section 2: Kualifikasi, Sertifikasi & Matriks Skill (Fokus Kompetensi)
            _buildSectionCard(
              title: 'Sertifikasi & Kebugaran Kerja (One Evolution)',
              onTitleTap: () => _showFilterToast('Kategori: Sertifikasi & Kompetensi'),
              items: [
                _MenuItem(
                  title: 'Sertifikat POP & K3',
                  icon: Icons.military_tech_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFEF3C7),
                  badge: '${_certificates.length} Aktif',
                  onTap: _showCertificatesModal,
                ),
                _MenuItem(
                  title: 'Matriks Skill',
                  icon: Icons.psychology_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFEDE9FE),
                  badge: '${_skillMatrix.length} Skill',
                  onTap: _showSkillMatrixModal,
                ),
                _MenuItem(
                  title: 'Status Induksi',
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFD1FAE5),
                  badge: 'VALID',
                  onTap: () => _showFeatureDetail(
                    'Kepatuhan Induksi & Re-Induksi K3LH',
                    'Karyawan $_nama telah menyelesaikan Induksi Keselamatan Tambang PT Indexim Coalindo.\n'
                    'Status kepatuhan aktif sejak tanggal masuk $_tanggalMasuk pada departemen $_dept.',
                    Icons.verified_user_rounded,
                    const Color(0xFF10B981),
                  ),
                ),
                _MenuItem(
                  title: 'Fit to Work & MCU',
                  icon: Icons.medical_services_rounded,
                  iconColor: _mcuHasil == 'FIT TO WORK'
                      ? const Color(0xFF10B981)
                      : (_mcuHasil == 'UNFIT' ? const Color(0xFFEF4444) : const Color(0xFFEC4899)),
                  bgColor: _mcuHasil == 'FIT TO WORK'
                      ? const Color(0xFFD1FAE5)
                      : (_mcuHasil == 'UNFIT' ? const Color(0xFFFEE2E2) : const Color(0xFFFCE7F3)),
                  badge: _mcuHasil != null && _mcuHasil!.isNotEmpty ? _mcuHasil! : 'BELUM ADA',
                  onTap: _showMcuModal,
                ),
              ],
            ),
          ],
        ),
      ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. TOP HERO BANNER: DATA RESMI KARYAWAN ONE EVOLUTION
  // =========================================================================
  Widget _buildWorkforceHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Profil
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: const Color(0xFF4F46E5),
                ),
                child: ClipOval(
                  child: _resolvePhotoUrl(_pathFoto).isNotEmpty
                      ? Image.network(
                          _resolvePhotoUrl(_pathFoto),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 34),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _perusahaan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC7D2FE),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIK: $_nik • $_posisi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Quick Indicator Badges dari Database
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeroStatItem('SERTIFIKAT', '${_certificates.length} Terdaftar', Icons.verified_rounded, const Color(0xFFFBBF24)),
                Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2)),
                _buildHeroStatItem('MATRIKS SKILL', '${_skillMatrix.length} Kompeten', Icons.psychology_rounded, const Color(0xFFA78BFA)),
                Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2)),
                _buildHeroStatItem('MINE PERMIT', 'Aktif Valid', Icons.shield_rounded, const Color(0xFF34D399)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 0.3,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 2. SEARCH & FILTER BAR
  // =========================================================================
  Widget _buildSearchFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Cari modul, data pribadi, sertifikat, atau skill...',
          hintStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade400,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1), size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. SECTION CONTAINER & 4-COLUMN SUPER-APP GRID
  // =========================================================================
  Widget _buildSectionCard({
    required String title,
    required VoidCallback onTitleTap,
    required List<_MenuItem> items,
  }) {
    final filtered = _searchQuery.isEmpty
        ? items
        : items.where((it) => it.title.toLowerCase().contains(_searchQuery)).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 14,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filtered.map((item) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildTileItem(item),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTileItem(_MenuItem item) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        item.onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    color: item.iconColor.withOpacity(0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: item.iconColor.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(item.icon, size: 28, color: item.iconColor),
                ),
              ),
              if (item.badge != null)
                Positioned(
                  top: -5,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
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
          const SizedBox(height: 7),
          SizedBox(
            height: 32,
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. MODAL: PROFIL LENGKAP KARYAWAN (ONE EVOLUTION)
  // =========================================================================
  void _showProfileDetailModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Virtual ID Card Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.badge_rounded, color: Color(0xFF818CF8), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _perusahaan,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 2),
                          ),
                          child: ClipOval(
                            child: _resolvePhotoUrl(_pathFoto).isNotEmpty
                                ? Image.network(
                                    _resolvePhotoUrl(_pathFoto),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 30),
                                  )
                                : const Icon(Icons.person, color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nama,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'NIK: $_nik • $_posisi',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white70,
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
              const SizedBox(height: 16),
              const Text(
                'Rincian Data Tenaga Kerja Tambang (One Evolution)',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildInfoTile('Nomor NIK', _nik, Icons.pin_rounded),
                    _buildInfoTile('Nomor KTP', _noKtp, Icons.badge_outlined),
                    _buildInfoTile('Nomor KK', _noKk, Icons.family_restroom_rounded),
                    _buildInfoTile('Kewarganegaraan', _wargaNegara, Icons.flag_rounded),
                    _buildInfoTile('Tempat, Tanggal Lahir', '$_tempatLahir, $_tanggalLahir', Icons.cake_rounded),
                    _buildInfoTile('Agama & Pernikahan', '$_agama • Status: $_statusNikah', Icons.favorite_rounded),
                    _buildInfoTile('Nama Orang Tua', 'Ibu: $_namaIbu • Ayah: $_namaAyah', Icons.family_restroom_rounded),
                    _buildInfoTile('Perusahaan', _perusahaan, Icons.corporate_fare_rounded),
                    _buildInfoTile('Departemen', _dept, Icons.domain_rounded),
                    _buildInfoTile('Jabatan / Posisi', '$_jabatan / $_posisi', Icons.work_rounded),
                    _buildInfoTile('Grade / Klasifikasi', _grade.isNotEmpty ? _grade : '-', Icons.stars_rounded),
                    _buildInfoTile('Jadwal Roster', _roster.isNotEmpty ? _roster : '-', Icons.event_repeat_rounded),
                    _buildInfoTile('Tanggal Masuk', _tanggalMasuk.isNotEmpty ? _tanggalMasuk : '-', Icons.calendar_today_rounded),
                    _buildInfoTile('Status Kerja', _statusKerja.isNotEmpty ? _statusKerja : 'Karyawan Aktif', Icons.assignment_ind_rounded),
                    _buildInfoTile('No. Handphone (WA)', _hp.isNotEmpty ? _hp : '-', Icons.phone_android_rounded),
                    if (_hp2.isNotEmpty) _buildInfoTile('No. HP Alternatif', _hp2, Icons.phone_outlined),
                    _buildInfoTile('Email Kantor', _emailKantor.isNotEmpty ? _emailKantor : '-', Icons.mail_outline_rounded),
                    _buildInfoTile('Email Pribadi', _emailPribadi.isNotEmpty ? _emailPribadi : '-', Icons.alternate_email_rounded),
                    _buildInfoTile('Alamat KTP / Domisili', _alamat.isNotEmpty ? '$_alamat (Pos: $_kodePos)' : '-', Icons.location_on_rounded),
                    _buildInfoTile('Kontak Darurat', _daruratNama.isNotEmpty ? '$_daruratNama • $_daruratTelp ($_daruratRelasi)' : 'Belum Diatur', Icons.contact_phone_rounded),
                    _buildInfoTile('Jaminan Sosial & Pajak', 'NPWP: ${_noNpwp.isNotEmpty ? _noNpwp : "-"} • BPJS TK: ${_noBpjsTk.isNotEmpty ? _noBpjsTk : "-"} • BPJS Kes: ${_noBpjsKes.isNotEmpty ? _noBpjsKes : "-"}', Icons.credit_card_rounded),
                    _buildInfoTile('Pendidikan', _namaSekolah.isNotEmpty ? '$_jenjangPendidikan • $_namaSekolah ($_jurusan)' : '-', Icons.school_rounded),
                    _buildInfoTile('Mine Permit ID', '$_minePermitNo (Berlaku s/d $_minePermitExp)', Icons.qr_code_2_rounded),
                    _buildInfoTile('SIMPER Tambang', _simperClass.isNotEmpty ? _simperClass : 'Belum Terdaftar', Icons.drive_eta_rounded),
                    _buildInfoTile('Medical Check Up (MCU)', _mcuHasil != null && _mcuHasil!.isNotEmpty ? '$_mcuHasil (${_mcuTanggal ?? "-"})' : 'Belum Ada', Icons.medical_services_rounded),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 5. MODAL: EDIT DATA KARYAWAN (SESUAI FORM /KaryawanAdmin/Edit/28446)
  // =========================================================================
  void _showEditEmployeeModal() {
    // 1. Personal
    final namaCtrl = TextEditingController(text: _nama);
    final aliasCtrl = TextEditingController(text: _namaAlias);
    final wargaCtrl = TextEditingController(text: _wargaNegara);
    final ktpCtrl = TextEditingController(text: _noKtp);
    final kkCtrl = TextEditingController(text: _noKk);
    final jkCtrl = TextEditingController(text: _jenisKelamin);
    final tempatLahirCtrl = TextEditingController(text: _tempatLahir);
    final tglLahirCtrl = TextEditingController(text: _tanggalLahir);
    final nikahCtrl = TextEditingController(text: _statusNikah);
    final darahCtrl = TextEditingController(text: _golDarah);
    final ibuCtrl = TextEditingController(text: _namaIbu);
    final ayahCtrl = TextEditingController(text: _namaAyah);

    // 2. Domisili
    final alamatCtrl = TextEditingController(text: _alamat);
    final rtCtrl = TextEditingController(text: _rt);
    final rwCtrl = TextEditingController(text: _rw);
    final kodePosCtrl = TextEditingController(text: _kodePos);

    // 3. Kontak & Darurat
    final hpCtrl = TextEditingController(text: _hp);
    final hp2Ctrl = TextEditingController(text: _hp2);
    final emailPribadiCtrl = TextEditingController(text: _emailPribadi);
    final emailKantorCtrl = TextEditingController(text: _emailKantor);
    final kdNamaCtrl = TextEditingController(text: _daruratNama);
    final kdTelpCtrl = TextEditingController(text: _daruratTelp);
    final kdTelpLainCtrl = TextEditingController(text: _daruratTelpLain);
    final kdRelasiCtrl = TextEditingController(text: _daruratRelasi);
    final kdKetCtrl = TextEditingController(text: _daruratKeterangan);

    // 4. Pendidikan & Jaminan
    final sekolahCtrl = TextEditingController(text: _namaSekolah);
    final fakultasCtrl = TextEditingController(text: _fakultas);
    final jurusanCtrl = TextEditingController(text: _jurusan);
    final npwpCtrl = TextEditingController(text: _noNpwp);
    final bpjsTkCtrl = TextEditingController(text: _noBpjsTk);
    final bpjsKesCtrl = TextEditingController(text: _noBpjsKes);
    final bpjsPensiunCtrl = TextEditingController(text: _noBpjsPensiun);

    // Master Dropdown Options & State (Live Database ONE_DB_MITRA)
    List<Map<String, dynamic>> agamaOptions = [];
    List<Map<String, dynamic>> statusNikahOptions = [];
    List<Map<String, dynamic>> pendidikanOptions = [];
    List<Map<String, dynamic>> provinsiOptions = [];
    List<Map<String, dynamic>> kabupatenOptions = [];
    List<Map<String, dynamic>> kecamatanOptions = [];
    List<Map<String, dynamic>> desaOptions = [];

    int? curAgamaId = _idAgama;
    String curAgamaName = _agama;

    int? curStatusNikahId = _idStatusNikah;
    String curStatusNikahName = _statusNikah;

    int? curPendidikanId = _idPendidikan;
    String curJenjangName = _jenjangPendidikan;

    String? curGolDarah = (_golDarah != null && _golDarah!.trim().isNotEmpty) ? _golDarah!.trim().toUpperCase() : null;

    String? curProvinsi = _provinsi.trim().isNotEmpty ? _provinsi.trim() : null;
    String? curKabupaten = _kabupaten.trim().isNotEmpty ? _kabupaten.trim() : null;
    String? curKecamatan = _kecamatan.trim().isNotEmpty ? _kecamatan.trim() : null;
    String? curDesa = _desa.trim().isNotEmpty ? _desa.trim() : null;

    bool loadingProv = false;
    bool loadingKab = false;
    bool loadingKec = false;
    bool loadingDesa = false;
    bool masterInitialized = false;

    int activeTab = 0;
    bool isSaving = false;

    Future<void> loadMasterData(void Function(void Function()) setModalState) async {
      if (masterInitialized) return;
      masterInitialized = true;

      setModalState(() => loadingProv = true);
      try {
        final profileFuture = (_noKtp.isEmpty || _namaIbu.isEmpty || _tempatLahir.isEmpty)
            ? OneEvService.instance.fetchProfile(nik: _nik.isNotEmpty ? _nik : PreferenceService.getProfile()?.noNik)
            : Future.value(OneEvService.instance.cachedProfile ?? <String, dynamic>{});
        final agamasFuture = OneEvService.instance.fetchMasterAgama();
        final statusNikahsFuture = OneEvService.instance.fetchMasterStatusNikah();
        final pendidikansFuture = OneEvService.instance.fetchMasterPendidikan();
        final provsFuture = OneEvService.instance.fetchMasterProvinsi();

        final results = await Future.wait([
          profileFuture,
          agamasFuture,
          statusNikahsFuture,
          pendidikansFuture,
          provsFuture,
        ]);

        final prof = results[0] as Map<String, dynamic>;
        final agamas = results[1] as List<Map<String, dynamic>>;
        final statusNikahs = results[2] as List<Map<String, dynamic>>;
        final pendidikans = results[3] as List<Map<String, dynamic>>;
        final provs = results[4] as List<Map<String, dynamic>>;

        setModalState(() {
          agamaOptions = agamas;
          statusNikahOptions = statusNikahs;
          pendidikanOptions = pendidikans;
          provinsiOptions = provs;
          loadingProv = false;

          // Auto-sync form textfield controllers jika sebelumnya kosong
          if (prof.isNotEmpty) {
            if (namaCtrl.text.isEmpty && prof['nama_lengkap'] != null) namaCtrl.text = prof['nama_lengkap'].toString();
            if (aliasCtrl.text.isEmpty && prof['nama_alias'] != null) aliasCtrl.text = prof['nama_alias'].toString();
            if (wargaCtrl.text.isEmpty && prof['warga_negara'] != null) wargaCtrl.text = prof['warga_negara'].toString();
            if (ktpCtrl.text.isEmpty && prof['no_ktp'] != null) ktpCtrl.text = prof['no_ktp'].toString();
            if (kkCtrl.text.isEmpty && prof['no_kk'] != null) kkCtrl.text = prof['no_kk'].toString();
            if (jkCtrl.text.isEmpty && prof['jenis_kelamin'] != null) jkCtrl.text = prof['jenis_kelamin'].toString();
            if (tempatLahirCtrl.text.isEmpty && prof['tempat_lahir'] != null) tempatLahirCtrl.text = prof['tempat_lahir'].toString();
            if (tglLahirCtrl.text.isEmpty && prof['tanggal_lahir'] != null) tglLahirCtrl.text = prof['tanggal_lahir'].toString();
            if (nikahCtrl.text.isEmpty && prof['status_nikah'] != null) nikahCtrl.text = prof['status_nikah'].toString();
            if (darahCtrl.text.isEmpty && prof['golongan_darah'] != null) darahCtrl.text = prof['golongan_darah'].toString();
            if (ibuCtrl.text.isEmpty && prof['nama_ibu'] != null) ibuCtrl.text = prof['nama_ibu'].toString();
            if (ayahCtrl.text.isEmpty && prof['nama_ayah'] != null) ayahCtrl.text = prof['nama_ayah'].toString();

            if (alamatCtrl.text.isEmpty && prof['alamat'] != null) alamatCtrl.text = prof['alamat'].toString();
            if (rtCtrl.text.isEmpty && prof['rt'] != null) rtCtrl.text = prof['rt'].toString();
            if (rwCtrl.text.isEmpty && prof['rw'] != null) rwCtrl.text = prof['rw'].toString();
            if (kodePosCtrl.text.isEmpty && prof['kode_pos'] != null) kodePosCtrl.text = prof['kode_pos'].toString();

            if (hpCtrl.text.isEmpty && prof['hp_1'] != null) hpCtrl.text = prof['hp_1'].toString();
            if (hp2Ctrl.text.isEmpty && prof['hp_2'] != null) hp2Ctrl.text = prof['hp_2'].toString();
            if (emailPribadiCtrl.text.isEmpty && prof['email_pribadi'] != null) emailPribadiCtrl.text = prof['email_pribadi'].toString();
            if (emailKantorCtrl.text.isEmpty && prof['email_kantor'] != null) emailKantorCtrl.text = prof['email_kantor'].toString();

            if (kdNamaCtrl.text.isEmpty && prof['kontak_darurat_nama'] != null) kdNamaCtrl.text = prof['kontak_darurat_nama'].toString();
            if (kdTelpCtrl.text.isEmpty && prof['kontak_darurat_telp'] != null) kdTelpCtrl.text = prof['kontak_darurat_telp'].toString();
            if (kdTelpLainCtrl.text.isEmpty && prof['kontak_darurat_telp_lain'] != null) kdTelpLainCtrl.text = prof['kontak_darurat_telp_lain'].toString();
            if (kdRelasiCtrl.text.isEmpty && prof['kontak_darurat_relasi'] != null) kdRelasiCtrl.text = prof['kontak_darurat_relasi'].toString();
            if (kdKetCtrl.text.isEmpty && prof['kontak_darurat_keterangan'] != null) kdKetCtrl.text = prof['kontak_darurat_keterangan'].toString();

            if (sekolahCtrl.text.isEmpty && prof['nama_sekolah'] != null) sekolahCtrl.text = prof['nama_sekolah'].toString();
            if (fakultasCtrl.text.isEmpty && prof['fakultas'] != null) fakultasCtrl.text = prof['fakultas'].toString();
            if (jurusanCtrl.text.isEmpty && prof['jurusan'] != null) jurusanCtrl.text = prof['jurusan'].toString();
            if (npwpCtrl.text.isEmpty && prof['no_npwp'] != null) npwpCtrl.text = prof['no_npwp'].toString();
            if (bpjsTkCtrl.text.isEmpty && prof['no_bpjs_tk'] != null) bpjsTkCtrl.text = prof['no_bpjs_tk'].toString();
            if (bpjsKesCtrl.text.isEmpty && prof['no_bpjs_kes'] != null) bpjsKesCtrl.text = prof['no_bpjs_kes'].toString();
            if (bpjsPensiunCtrl.text.isEmpty && prof['no_bpjs_pensiun'] != null) bpjsPensiunCtrl.text = prof['no_bpjs_pensiun'].toString();

            if (curAgamaId == null && prof['id_agama'] != null) {
              curAgamaId = prof['id_agama'] as int?;
              curAgamaName = prof['agama']?.toString() ?? '';
            }
            if (curStatusNikahId == null && prof['id_status_nikah'] != null) {
              curStatusNikahId = prof['id_status_nikah'] as int?;
              curStatusNikahName = prof['status_nikah']?.toString() ?? '';
            }
            if (curPendidikanId == null && prof['id_pendidikan'] != null) {
              curPendidikanId = prof['id_pendidikan'] as int?;
              curJenjangName = prof['jenjang_pendidikan']?.toString() ?? '';
            }
            if (curProvinsi == null && prof['provinsi'] != null && prof['provinsi'].toString().isNotEmpty) {
              curProvinsi = prof['provinsi'].toString();
            }
            if (curKabupaten == null && prof['kabupaten'] != null && prof['kabupaten'].toString().isNotEmpty) {
              curKabupaten = prof['kabupaten'].toString();
            }
            if (curKecamatan == null && prof['kecamatan'] != null && prof['kecamatan'].toString().isNotEmpty) {
              curKecamatan = prof['kecamatan'].toString();
            }
            if (curDesa == null && prof['desa'] != null && prof['desa'].toString().isNotEmpty) {
              curDesa = prof['desa'].toString();
            }
            if (curGolDarah == null && prof['golongan_darah'] != null && prof['golongan_darah'].toString().isNotEmpty) {
              curGolDarah = prof['golongan_darah'].toString().toUpperCase();
            }

            if (_pathFoto == null || _pathFoto!.isEmpty) {
              _pathFoto = prof['path_foto']?.toString();
            }
          }

          // Sync Agama
          if (curAgamaId == null && curAgamaName.isNotEmpty) {
            final found = agamas.firstWhere(
              (a) => (a['nama']?.toString().toUpperCase() ?? '') == curAgamaName.toUpperCase(),
              orElse: () => {},
            );
            if (found.isNotEmpty) curAgamaId = found['id'] as int;
          }
          if (curAgamaId != null && !agamaOptions.any((a) => a['id'] == curAgamaId)) {
            agamaOptions.insert(0, {'id': curAgamaId, 'nama': curAgamaName.isNotEmpty ? curAgamaName : 'Agama $curAgamaId'});
          }

          // Sync Status Nikah
          if (curStatusNikahId == null && curStatusNikahName.isNotEmpty) {
            final foundS = statusNikahs.firstWhere(
              (s) => (s['nama']?.toString().toUpperCase() ?? '') == curStatusNikahName.toUpperCase(),
              orElse: () => {},
            );
            if (foundS.isNotEmpty) curStatusNikahId = foundS['id'] as int;
          }
          if (curStatusNikahId != null && !statusNikahOptions.any((s) => s['id'] == curStatusNikahId)) {
            statusNikahOptions.insert(0, {'id': curStatusNikahId, 'nama': curStatusNikahName.isNotEmpty ? curStatusNikahName : 'Status $curStatusNikahId'});
          }

          // Sync Pendidikan
          if (curPendidikanId == null && curJenjangName.isNotEmpty) {
            final found = pendidikans.firstWhere(
              (p) => (p['nama']?.toString().toUpperCase() ?? '') == curJenjangName.toUpperCase(),
              orElse: () => {},
            );
            if (found.isNotEmpty) curPendidikanId = found['id'] as int;
          }
          if (curPendidikanId != null && !pendidikanOptions.any((p) => p['id'] == curPendidikanId)) {
            pendidikanOptions.insert(0, {'id': curPendidikanId, 'nama': curJenjangName.isNotEmpty ? curJenjangName : 'Pendidikan $curPendidikanId'});
          }

          // Sync Provinsi
          if (curProvinsi != null && curProvinsi!.isNotEmpty) {
            final foundP = provs.firstWhere(
              (p) => (p['nama']?.toString().toUpperCase() ?? '') == curProvinsi!.toUpperCase(),
              orElse: () => {},
            );
            if (foundP.isNotEmpty) {
              curProvinsi = foundP['nama']?.toString();
            } else {
              provinsiOptions.insert(0, {'kode': '', 'nama': curProvinsi!});
            }
          }
        });

        // Pre-load Kabupaten if existing
        if (curProvinsi != null && curProvinsi!.isNotEmpty) {
          setModalState(() => loadingKab = true);
          final kabs = await OneEvService.instance.fetchMasterKabupaten(provinsi: curProvinsi);
          setModalState(() {
            kabupatenOptions = kabs;
            loadingKab = false;
            if (curKabupaten != null && curKabupaten!.isNotEmpty) {
              final foundK = kabs.firstWhere(
                (k) => (k['nama']?.toString().toUpperCase() ?? '') == curKabupaten!.toUpperCase(),
                orElse: () => {},
              );
              if (foundK.isNotEmpty) {
                curKabupaten = foundK['nama']?.toString();
              } else {
                kabupatenOptions.insert(0, {'kode': '', 'nama': curKabupaten!});
              }
            }
          });

          // Pre-load Kecamatan if existing
          if (curKabupaten != null && curKabupaten!.isNotEmpty) {
            setModalState(() => loadingKec = true);
            final kecs = await OneEvService.instance.fetchMasterKecamatan(kabupaten: curKabupaten);
            setModalState(() {
              kecamatanOptions = kecs;
              loadingKec = false;
              if (curKecamatan != null && curKecamatan!.isNotEmpty) {
                final foundKc = kecs.firstWhere(
                  (kc) => (kc['nama']?.toString().toUpperCase() ?? '') == curKecamatan!.toUpperCase(),
                  orElse: () => {},
                );
                if (foundKc.isNotEmpty) {
                  curKecamatan = foundKc['nama']?.toString();
                } else {
                  kecamatanOptions.insert(0, {'kode': '', 'nama': curKecamatan!});
                }
              }
            });

            // Pre-load Desa if existing
            if (curKecamatan != null && curKecamatan!.isNotEmpty) {
              setModalState(() => loadingDesa = true);
              final desas = await OneEvService.instance.fetchMasterKelurahan(kecamatan: curKecamatan);
              setModalState(() {
                desaOptions = desas;
                loadingDesa = false;
                if (curDesa != null && curDesa!.isNotEmpty) {
                  final foundD = desas.firstWhere(
                    (d) => (d['nama']?.toString().toUpperCase() ?? '') == curDesa!.toUpperCase(),
                    orElse: () => {},
                  );
                  if (foundD.isNotEmpty) {
                    curDesa = foundD['nama']?.toString();
                  } else {
                    desaOptions.insert(0, {'kode': '', 'nama': curDesa!});
                  }
                }
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[OneEv] Error loading master data: $e');
        setModalState(() {
          loadingProv = false;
          loadingKab = false;
          loadingKec = false;
          loadingDesa = false;
        });
      }
    }

    void onSelectProvinsi(String? newProv, void Function(void Function()) setModalState) async {
      setModalState(() {
        curProvinsi = newProv;
        curKabupaten = null;
        curKecamatan = null;
        curDesa = null;
        kabupatenOptions = [];
        kecamatanOptions = [];
        desaOptions = [];
        loadingKab = true;
      });
      if (newProv == null || newProv.isEmpty) {
        setModalState(() => loadingKab = false);
        return;
      }
      final kabs = await OneEvService.instance.fetchMasterKabupaten(provinsi: newProv);
      setModalState(() {
        kabupatenOptions = kabs;
        loadingKab = false;
      });
    }

    void onSelectKabupaten(String? newKab, void Function(void Function()) setModalState) async {
      setModalState(() {
        curKabupaten = newKab;
        curKecamatan = null;
        curDesa = null;
        kecamatanOptions = [];
        desaOptions = [];
        loadingKec = true;
      });
      if (newKab == null || newKab.isEmpty) {
        setModalState(() => loadingKec = false);
        return;
      }
      final kecs = await OneEvService.instance.fetchMasterKecamatan(kabupaten: newKab);
      setModalState(() {
        kecamatanOptions = kecs;
        loadingKec = false;
      });
    }

    void onSelectKecamatan(String? newKec, void Function(void Function()) setModalState) async {
      setModalState(() {
        curKecamatan = newKec;
        curDesa = null;
        desaOptions = [];
        loadingDesa = true;
      });
      if (newKec == null || newKec.isEmpty) {
        setModalState(() => loadingDesa = false);
        return;
      }
      final desas = await OneEvService.instance.fetchMasterKelurahan(kecamatan: newKec);
      setModalState(() {
        desaOptions = desas;
        loadingDesa = false;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadMasterData(setModalState);
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3), width: 1.5),
                        ),
                        child: ClipOval(
                          child: _resolvePhotoUrl(_pathFoto).isNotEmpty
                              ? Image.network(
                                  _resolvePhotoUrl(_pathFoto),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF0284C7), size: 24),
                                )
                              : const Icon(Icons.person, color: Color(0xFF0284C7), size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Data Karyawan (One Evolution)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Formulir resmi /KaryawanAdmin/Edit/ [ONE_DB_MITRA]',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Segmented Form Categories (Sesuai Tabs di Web One DB)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildSectionPill('1. Personal', 0, activeTab, () => setModalState(() => activeTab = 0)),
                        const SizedBox(width: 8),
                        _buildSectionPill('2. Domisili', 1, activeTab, () => setModalState(() => activeTab = 1)),
                        const SizedBox(width: 8),
                        _buildSectionPill('3. Kontak & Darurat', 2, activeTab, () => setModalState(() => activeTab = 2)),
                        const SizedBox(width: 8),
                        _buildSectionPill('4. Pendidikan & Pajak', 3, activeTab, () => setModalState(() => activeTab = 3)),
                        const SizedBox(width: 8),
                        _buildSectionPill('5. Kepegawaian (HR)', 4, activeTab, () => setModalState(() => activeTab = 4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Form Fields per Tab
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (activeTab == 0) ...[
                          // TAB 1: DATA PERSONAL
                          _buildInputField('Nama Lengkap (Wajib)', namaCtrl, Icons.person_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nama Panggilan / Alias', aliasCtrl, Icons.badge_outlined),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildInputField('Kewarganegaraan (WNI/WNA)', wargaCtrl, Icons.flag_rounded)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildInputField('Jenis Kelamin (LK/PR)', jkCtrl, Icons.wc_rounded)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor KTP (16 Digit)', ktpCtrl, Icons.badge_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor Kartu Keluarga (KK)', kkCtrl, Icons.family_restroom_rounded),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildInputField('Tempat Lahir', tempatLahirCtrl, Icons.location_city_rounded)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildInputField('Tanggal Lahir (YYYY-MM-DD)', tglLahirCtrl, Icons.cake_rounded)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField<int>(
                                  label: 'Agama',
                                  value: curAgamaId,
                                  icon: Icons.mosque_rounded,
                                  hint: '-- Pilih Agama --',
                                  items: agamaOptions.map((a) {
                                    return DropdownMenuItem<int>(
                                      value: a['id'] as int,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.mosque_rounded, size: 16, color: Color(0xFF6366F1)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              a['nama']?.toString() ?? '',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setModalState(() {
                                      curAgamaId = val;
                                      final matched = agamaOptions.firstWhere((a) => a['id'] == val, orElse: () => {});
                                      curAgamaName = matched['nama']?.toString() ?? '';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDropdownField<int>(
                                  label: 'Status Nikah',
                                  value: curStatusNikahId,
                                  icon: Icons.favorite_rounded,
                                  hint: '-- Status Nikah --',
                                  items: statusNikahOptions.map((s) {
                                    return DropdownMenuItem<int>(
                                      value: s['id'] as int,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFF6366F1)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              s['nama']?.toString() ?? '',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setModalState(() {
                                      curStatusNikahId = val;
                                      final matched = statusNikahOptions.firstWhere((s) => s['id'] == val, orElse: () => {});
                                      curStatusNikahName = matched['nama']?.toString() ?? '';
                                      nikahCtrl.text = curStatusNikahName;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField<String>(
                            label: 'Golongan Darah (A, B, AB, O)',
                            value: (curGolDarah != null && curGolDarah!.isNotEmpty) ? curGolDarah : null,
                            icon: Icons.bloodtype_rounded,
                            hint: '-- Pilih Golongan Darah --',
                            items: ['A', 'B', 'AB', 'O', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((g) {
                              return DropdownMenuItem<String>(
                                value: g,
                                child: Row(
                                  children: [
                                    const Icon(Icons.bloodtype_rounded, size: 16, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 8),
                                    Text(
                                      g,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() {
                                curGolDarah = val;
                                darahCtrl.text = val ?? '';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildInputField('Nama Ibu Kandung', ibuCtrl, Icons.person_outline_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nama Ayah Kandung', ayahCtrl, Icons.person_outline_rounded),
                        ] else if (activeTab == 1) ...[
                          // TAB 2: DOMISILI & ALAMAT
                          _buildDropdownField<String>(
                            label: 'Provinsi',
                            value: curProvinsi,
                            isLoading: loadingProv,
                            icon: Icons.map_rounded,
                            hint: '-- Pilih Provinsi (Database One EV) --',
                            items: provinsiOptions.map((p) {
                              final name = p['nama']?.toString() ?? '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Row(
                                  children: [
                                    const Icon(Icons.map_rounded, size: 16, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => onSelectProvinsi(val, setModalState),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField<String>(
                            label: 'Kabupaten / Kota',
                            value: curKabupaten,
                            isLoading: loadingKab,
                            icon: Icons.location_city_rounded,
                            hint: curProvinsi == null ? '-- Pilih Provinsi Terlebih Dahulu --' : '-- Pilih Kabupaten / Kota --',
                            items: kabupatenOptions.map((k) {
                              final name = k['nama']?.toString() ?? '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => onSelectKabupaten(val, setModalState),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField<String>(
                            label: 'Kecamatan',
                            value: curKecamatan,
                            isLoading: loadingKec,
                            icon: Icons.signpost_rounded,
                            hint: curKabupaten == null ? '-- Pilih Kabupaten Terlebih Dahulu --' : '-- Pilih Kecamatan --',
                            items: kecamatanOptions.map((kc) {
                              final name = kc['nama']?.toString() ?? '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Row(
                                  children: [
                                    const Icon(Icons.signpost_rounded, size: 16, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => onSelectKecamatan(val, setModalState),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField<String>(
                            label: 'Kelurahan / Desa',
                            value: curDesa,
                            isLoading: loadingDesa,
                            icon: Icons.home_work_rounded,
                            hint: curKecamatan == null ? '-- Pilih Kecamatan Terlebih Dahulu --' : '-- Pilih Kelurahan / Desa --',
                            items: desaOptions.map((d) {
                              final name = d['nama']?.toString() ?? '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Row(
                                  children: [
                                    const Icon(Icons.home_work_rounded, size: 16, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() => curDesa = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildInputField('Alamat Domisili / Tempat Tinggal', alamatCtrl, Icons.location_on_rounded, maxLines: 2),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildInputField('RT', rtCtrl, Icons.tag_rounded)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildInputField('RW', rwCtrl, Icons.tag_rounded)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildInputField('Kode Pos', kodePosCtrl, Icons.local_post_office_rounded)),
                            ],
                          ),
                        ] else if (activeTab == 2) ...[
                          // TAB 3: KONTAK UTAMA & DARURAT
                          _buildInputField('Nomor Handphone Utama (WhatsApp)', hpCtrl, Icons.phone_android_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor Handphone Alternatif', hp2Ctrl, Icons.phone_outlined),
                          const SizedBox(height: 12),
                          _buildInputField('Email Pribadi', emailPribadiCtrl, Icons.alternate_email_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Email Kantor / Korespondensi', emailKantorCtrl, Icons.email_rounded),
                          const SizedBox(height: 16),
                          const Text(
                            'Kontak Darurat (Emergency Contact)',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 10),
                          _buildInputField('Nama Kontak Darurat', kdNamaCtrl, Icons.person_outline_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor Telepon Darurat', kdTelpCtrl, Icons.phone_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor Telepon Lain (Alternatif)', kdTelpLainCtrl, Icons.phone_forwarded_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Hubungan / Relasi (cth: Istri, Orang Tua, Saudara)', kdRelasiCtrl, Icons.family_restroom_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Keterangan / Catatan Tambahan', kdKetCtrl, Icons.note_rounded, maxLines: 2),
                        ] else if (activeTab == 3) ...[
                          // TAB 4: PENDIDIKAN & JAMINAN
                          _buildDropdownField<int>(
                            label: 'Jenjang Pendidikan',
                            value: curPendidikanId,
                            icon: Icons.school_rounded,
                            hint: '-- Pilih Tingkat Pendidikan (Database One EV) --',
                            items: pendidikanOptions.map((p) {
                              final name = p['nama']?.toString() ?? '';
                              return DropdownMenuItem<int>(
                                value: p['id'] as int,
                                child: Row(
                                  children: [
                                    const Icon(Icons.school_rounded, size: 16, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() {
                                curPendidikanId = val;
                                final matched = pendidikanOptions.firstWhere((p) => p['id'] == val, orElse: () => {});
                                curJenjangName = matched['nama']?.toString() ?? '';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildInputField('Nama Sekolah / Universitas', sekolahCtrl, Icons.account_balance_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Fakultas', fakultasCtrl, Icons.apartment_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Jurusan / Program Studi', jurusanCtrl, Icons.menu_book_rounded),
                          const SizedBox(height: 16),
                          const Text(
                            'Jaminan Sosial & Pajak',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 10),
                          _buildInputField('Nomor NPWP', npwpCtrl, Icons.credit_card_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor BPJS Ketenagakerjaan (BPJS TK)', bpjsTkCtrl, Icons.security_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor BPJS Kesehatan (BPJS Kes)', bpjsKesCtrl, Icons.health_and_safety_rounded),
                          const SizedBox(height: 12),
                          _buildInputField('Nomor BPJS Pensiun', bpjsPensiunCtrl, Icons.savings_rounded),
                        ] else ...[
                          // TAB 5: KEPEGAWAIAN (TERKUNCI HR - READ ONLY)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Form Kepegawaian (Perusahaan, Departemen, Jabatan, Grade, Roster) dikelola khusus oleh HRD/HC PT Indexim Coalindo. Karyawan tidak dapat mengubah penempatan kepegawaian secara mandiri.',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E), height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildDisabledField('Perusahaan', _perusahaan, Icons.corporate_fare_rounded),
                          const SizedBox(height: 12),
                          _buildDisabledField('Departemen', _dept, Icons.domain_rounded),
                          const SizedBox(height: 12),
                          _buildDisabledField('Posisi / Jabatan', '$_posisi / $_jabatan', Icons.work_rounded),
                          const SizedBox(height: 12),
                          _buildDisabledField('Grade / Klasifikasi', _grade, Icons.stars_rounded),
                          const SizedBox(height: 12),
                          _buildDisabledField('Jadwal Roster Kerja', _roster, Icons.event_repeat_rounded),
                          const SizedBox(height: 12),
                          _buildDisabledField('Tanggal Masuk Bekerja', _tanggalMasuk, Icons.calendar_today_rounded),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              HapticFeedback.mediumImpact();

                              final success = await _oneEvService.updateProfile({
                                'no_nik': _nik,
                                'nama_lengkap': namaCtrl.text.trim(),
                                'nama_alias': aliasCtrl.text.trim(),
                                'warga_negara': wargaCtrl.text.trim(),
                                'no_ktp': ktpCtrl.text.trim(),
                                'no_kk': kkCtrl.text.trim(),
                                'jenis_kelamin': jkCtrl.text.trim(),
                                'tempat_lahir': tempatLahirCtrl.text.trim(),
                                'tanggal_lahir': tglLahirCtrl.text.trim(),
                                'id_agama': curAgamaId,
                                'agama': curAgamaName,
                                'id_status_nikah': curStatusNikahId,
                                'status_nikah': curStatusNikahName.isNotEmpty ? curStatusNikahName : nikahCtrl.text.trim(),
                                'golongan_darah': curGolDarah ?? darahCtrl.text.trim(),
                                'nama_ibu': ibuCtrl.text.trim(),
                                'nama_ayah': ayahCtrl.text.trim(),
                                'provinsi': curProvinsi ?? '',
                                'kabupaten': curKabupaten ?? '',
                                'kecamatan': curKecamatan ?? '',
                                'desa': curDesa ?? '',
                                'alamat': alamatCtrl.text.trim(),
                                'rt': rtCtrl.text.trim(),
                                'rw': rwCtrl.text.trim(),
                                'kode_pos': kodePosCtrl.text.trim(),
                                'hp_1': hpCtrl.text.trim(),
                                'hp_2': hp2Ctrl.text.trim(),
                                'email_pribadi': emailPribadiCtrl.text.trim(),
                                'email_kantor': emailKantorCtrl.text.trim(),
                                'kontak_darurat_nama': kdNamaCtrl.text.trim(),
                                'kontak_darurat_telp': kdTelpCtrl.text.trim(),
                                'kontak_darurat_telp_lain': kdTelpLainCtrl.text.trim(),
                                'kontak_darurat_relasi': kdRelasiCtrl.text.trim(),
                                'kontak_darurat_keterangan': kdKetCtrl.text.trim(),
                                'no_npwp': npwpCtrl.text.trim(),
                                'no_bpjs_tk': bpjsTkCtrl.text.trim(),
                                'no_bpjs_kes': bpjsKesCtrl.text.trim(),
                                'no_bpjs_pensiun': bpjsPensiunCtrl.text.trim(),
                                'id_pendidikan': curPendidikanId,
                                'jenjang_pendidikan': curJenjangName,
                                'nama_sekolah': sekolahCtrl.text.trim(),
                                'fakultas': fakultasCtrl.text.trim(),
                                'jurusan': jurusanCtrl.text.trim(),
                              });

                              if (mounted) {
                                setState(() {
                                  _nama = namaCtrl.text.trim();
                                  _namaAlias = aliasCtrl.text.trim();
                                  _wargaNegara = wargaCtrl.text.trim();
                                  _noKtp = ktpCtrl.text.trim();
                                  _noKk = kkCtrl.text.trim();
                                  _jenisKelamin = jkCtrl.text.trim();
                                  _tempatLahir = tempatLahirCtrl.text.trim();
                                  _tanggalLahir = tglLahirCtrl.text.trim();
                                  _idAgama = curAgamaId;
                                  _agama = curAgamaName;
                                  _idStatusNikah = curStatusNikahId;
                                  _statusNikah = curStatusNikahName.isNotEmpty ? curStatusNikahName : nikahCtrl.text.trim();
                                  _golDarah = curGolDarah ?? darahCtrl.text.trim();
                                  _namaIbu = ibuCtrl.text.trim();
                                  _namaAyah = ayahCtrl.text.trim();
                                  _provinsi = curProvinsi ?? '';
                                  _kabupaten = curKabupaten ?? '';
                                  _kecamatan = curKecamatan ?? '';
                                  _desa = curDesa ?? '';
                                  _alamat = alamatCtrl.text.trim();
                                  _rt = rtCtrl.text.trim();
                                  _rw = rwCtrl.text.trim();
                                  _kodePos = kodePosCtrl.text.trim();
                                  _hp = hpCtrl.text.trim();
                                  _hp2 = hp2Ctrl.text.trim();
                                  _emailKantor = emailKantorCtrl.text.trim();
                                  _emailPribadi = emailPribadiCtrl.text.trim();
                                  _daruratNama = kdNamaCtrl.text.trim();
                                  _daruratTelp = kdTelpCtrl.text.trim();
                                  _daruratTelpLain = kdTelpLainCtrl.text.trim();
                                  _daruratRelasi = kdRelasiCtrl.text.trim();
                                  _daruratKeterangan = kdKetCtrl.text.trim();
                                  _noNpwp = npwpCtrl.text.trim();
                                  _noBpjsTk = bpjsTkCtrl.text.trim();
                                  _noBpjsKes = bpjsKesCtrl.text.trim();
                                  _noBpjsPensiun = bpjsPensiunCtrl.text.trim();
                                  _idPendidikan = curPendidikanId;
                                  _jenjangPendidikan = curJenjangName;
                                  _namaSekolah = sekolahCtrl.text.trim();
                                  _fakultas = fakultasCtrl.text.trim();
                                  _jurusan = jurusanCtrl.text.trim();
                                });
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Semua form data karyawan berhasil disimpan ke database One Evolution!'
                                          : 'Gagal memperbarui database, data disimpan lokal.',
                                    ),
                                    backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFD97706),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Simpan Perubahan ke Database',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
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

  Widget _buildSectionPill(String title, int index, int activeIndex, VoidCallback onTap) {
    final isSelected = index == activeIndex;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
              const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 6. MODAL: SERTIFIKAT & PELATIHAN KARYAWAN (ONE_DB_MITRA)
  // =========================================================================
  void _showCertificatesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sertifikat & Pelatihan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${_certificates.length} sertifikat resmi di ONE Evolution',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Tambah Sertifikat',
                    icon: const Icon(Icons.add_circle_rounded, color: Color(0xFFF59E0B), size: 30),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showAddCertificateModal();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _certificates.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada riwayat sertifikat di database.',
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _certificates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final cert = _certificates[index];
                          final isExpired = cert['status'] == 'EXPIRED';
                          final isWarning = cert['status'] == 'PERLU PERPANJANGAN';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cert['nama_sertifikat'] ?? 'Sertifikat',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? const Color(0xFFFEE2E2)
                                            : (isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cert['status'] ?? 'AKTIF',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: isExpired
                                              ? const Color(0xFFDC2626)
                                              : (isWarning ? const Color(0xFFD97706) : const Color(0xFF059669)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Penyelenggara: ${cert['penyelenggara'] ?? '-'}',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Terbit: ${cert['tanggal_terbit'] ?? '-'}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.event_busy_rounded, size: 12, color: isExpired ? Colors.red : Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Expired: ${cert['tanggal_expired'] ?? 'Seumur Hidup'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isExpired ? Colors.red : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCertificateModal() {
    final namaCtrl = TextEditingController();
    final lembagaCtrl = TextEditingController();
    DateTime tglTerbit = DateTime.now();
    DateTime tglExp = DateTime.now().add(const Duration(days: 730));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Sertifikat Baru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              _buildInputField('Nama Sertifikat / Pelatihan', namaCtrl, Icons.military_tech_rounded),
              const SizedBox(height: 10),
              _buildInputField('Lembaga Penyelenggara / Penerbit', lembagaCtrl, Icons.corporate_fare_rounded),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () async {
                    if (namaCtrl.text.trim().isEmpty) return;
                    HapticFeedback.mediumImpact();
                    await _oneEvService.addCertificate({
                      'no_nik': _nik,
                      'nama_sertifikat': namaCtrl.text.trim(),
                      'penyelenggara': lembagaCtrl.text.trim().isEmpty ? 'Lembaga Diklat K3' : lembagaCtrl.text.trim(),
                      'tanggal_terbit': tglTerbit.toIso8601String().substring(0, 10),
                      'tanggal_expired': tglExp.toIso8601String().substring(0, 10),
                    });
                    await _loadLiveOneEvData();
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      _showCertificatesModal();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan Sertifikat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 7. MODAL: MATRIKS SKILL & KOMPETENSI (ONE_DB_MITRA)
  // =========================================================================
  void _showSkillMatrixModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Color(0xFF8B5CF6), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Matriks Skill & Kompetensi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${_skillMatrix.length} pemetaan keahlian di ONE Evolution',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Tambah Penilaian Skill',
                    icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF8B5CF6), size: 30),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showAddSkillModal();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _skillMatrix.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.psychology_outlined, size: 52, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada catatan matriks skill di ONE Evolution',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gunakan tombol + di kanan atas untuk menambahkan kompetensi resmi.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _skillMatrix.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final skill = _skillMatrix[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  skill['kategori'] ?? 'K3LH',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  skill['status'] ?? 'COMPETENT',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            skill['nama_kompetensi'] ?? 'Kompetensi',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Target: ${skill['level_target'] ?? 'Level 3'}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 8),
                              Text(
                                'Aktual: ${skill['level_aktual'] ?? 'Level 3'}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: const LinearProgressIndicator(
                              value: 1.0,
                              minHeight: 5,
                              backgroundColor: Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            ),
                          ),
                          if (skill['catatan'] != null && skill['catatan'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              skill['catatan'],
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddSkillModal() {
    final skillCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'K3LH Tambang');
    final catatanCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Matriks Kompetensi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              _buildInputField('Nama Kompetensi / Keahlian', skillCtrl, Icons.psychology_rounded),
              const SizedBox(height: 10),
              _buildInputField('Kategori (K3LH / Operasional / Manajemen)', catCtrl, Icons.category_rounded),
              const SizedBox(height: 10),
              _buildInputField('Catatan / Keterangan Pembuktian', catatanCtrl, Icons.note_alt_rounded),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () async {
                    if (skillCtrl.text.trim().isEmpty) return;
                    HapticFeedback.mediumImpact();
                    await _oneEvService.updateSkillMatrix({
                      'no_nik': _nik,
                      'nama_kompetensi': skillCtrl.text.trim(),
                      'kategori': catCtrl.text.trim(),
                      'level_target': 'Level 4',
                      'level_aktual': 'Level 4',
                      'status': 'COMPETENT',
                      'catatan': catatanCtrl.text.trim(),
                    });
                    await _loadLiveOneEvData();
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      _showSkillMatrixModal();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan Kompetensi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 8. MODAL: MINE PERMIT ID, SIMPER & MEDICAL CHECK UP (MCU)
  // =========================================================================
  void _showMinePermitModal() {
    final isValid = _minePermitExp != '-' && _minePermitExp.isNotEmpty;
    _showFeatureDetail(
      'Mine Permit ID (Izin Kerja Tambang IDC)',
      'Mine Permit ID: $_minePermitNo\n'
      'Status: ${isValid ? "VALID AKTIF" : "NON-AKTIF"}\n'
      'Masa Berlaku Kerja: Hingga $_minePermitExp\n'
      'Perusahaan: $_perusahaan\n'
      'Departemen: $_dept\n'
      'Seksi: $_seksi\n\n'
      'Karyawan berhak memasuki area operasional tambang dengan kepatuhan penuh APD & regulasi keselamatan K3LH IDC.',
      Icons.qr_code_2_rounded,
      const Color(0xFFD97706),
    );
  }

  void _showSimperModal() async {
    // Jika data SIMPER belum dimuat, muat terlebih dahulu secara live
    if (_simperData == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final res = await _oneEvService.fetchSimper(nik: _nik);
        if (mounted) Navigator.pop(context);
        if (mounted && res != null) {
          setState(() {
            _simperData = res;
            final noSimper = res['nomor']?.toString() ?? '';
            final units = (res['units'] as List?) ?? [];
            _simperClass = noSimper.isNotEmpty ? '$noSimper (${units.length} Unit Diizinkan)' : 'Belum Terdaftar';
          });
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
      }
    }
    if (!mounted) return;

    final simper = _simperData;
    if (simper == null || simper['has_simper'] == false) {
      _showFeatureDetail(
        'Surat Izin Mengemudi Perusahaan (SIMPER)',
        'Status: Belum Terdaftar / Non-SIMPER\n\n'
        'Karyawan dengan jabatan "$_jabatan" di departemen "$_dept" saat ini tidak memiliki lisensi SIMPER operasional alat/kendaraan tambang.\n\n'
        'Bagi karyawan yang memerlukan pengoperasian unit sarana atau alat berat, silakan berkoordinasi dengan Driver Training Center (DTC) dan Occupational Health & Safety (OHS).',
        Icons.drive_eta_rounded,
        const Color(0xFF64748B),
      );
      return;
    }

    final nomorSimper = simper['nomor']?.toString() ?? '-';
    final status = simper['status']?.toString() ?? 'WAITING';
    final jenisSimper = simper['jenis_simper']?.toString() ?? 'PERPANJANGAN';
    final nomorSim = simper['nomor_sim']?.toString() ?? '-';
    final jenisSim = simper['jenis_sim']?.toString() ?? 'A';
    final masaBerlaku = simper['masa_berlaku']?.toString() ?? '-';
    final expiredDate = simper['expired_date']?.toString() ?? '-';
    final kacamata = simper['kacamata']?.toString() ?? 'TIDAK';
    final ketentuanHauling = simper['ketentuan_hauling'] == true ? 'YA (Jalan Hauling)' : 'TIDAK';
    final nilaiTeori = simper['nilai_teori'] != null ? '${simper['nilai_teori']}' : '-';
    final nilaiPraktek = simper['nilai_praktek'] != null ? '${simper['nilai_praktek']}' : '-';
    final qrDecrypt = simper['qr_decrypt']?.toString() ?? '';
    final printedAt = simper['printed_at']?.toString() ?? '-';
    final printedCount = simper['printed_count']?.toString() ?? '0';
    final isActive = simper['is_simper_active'] == true;
    final List units = (simper['units'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.drive_eta_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIMPER Tambang',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Surat Izin Mengemudi Perusahaan • PT IDC',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isActive ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card 1: Informasi SIMPER Resmi
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'NOMOR SIMPER',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      nomorSimper,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    jenisSimper,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                            _buildSimperInfoRow('SIM Kepolisian', '$nomorSim (Gol. $jenisSim)'),
                            _buildSimperInfoRow('Masa Berlaku SIM', masaBerlaku),
                            _buildSimperInfoRow('Expired SIMPER', expiredDate.split(' ')[0]),
                            _buildSimperInfoRow('Ketentuan Kacamata', kacamata),
                            _buildSimperInfoRow('Izin Jalur Hauling', ketentuanHauling),
                            _buildSimperInfoRow('Nilai Uji', 'Teori: $nilaiTeori  |  Praktek: $nilaiPraktek'),
                            if (qrDecrypt.isNotEmpty)
                              _buildSimperInfoRow('Req ID / QR Decrypt', qrDecrypt),
                            if (printedAt != '-')
                              _buildSimperInfoRow('Riwayat Cetak', '$printedAt (${printedCount}x)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Header Unit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.car_repair_rounded, size: 20, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Text(
                                'Unit yang Diperbolehkan (${units.length})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Resmi tb_simper_unit',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (units.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada unit yang terdaftar di tb_simper_unit',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ...units.map((u) {
                          final unit = Map<String, dynamic>.from(u is Map ? u : {});
                          final kendaraan = unit['kendaraan']?.toString() ?? 'UNIT';
                          final eqType = unit['equipment_type']?.toString() ?? unit['equipment_model']?.toString() ?? '-';
                          final kewenangan = unit['kewenangan']?.toString() ?? 'RESTRICTED';
                          final jamMin = unit['jam_min']?.toString() ?? '0';
                          final jamAktual = unit['jam_aktual']?.toString() ?? '0';
                          final uTeori = unit['nilai_teori']?.toString();
                          final uPraktek = unit['nilai_praktek']?.toString();

                          final isFull = kewenangan.toUpperCase() == 'FULL';
                          final isProbation = kewenangan.toUpperCase() == 'PROBATION';

                          IconData unitIcon = Icons.directions_car_rounded;
                          if (kendaraan.toUpperCase().contains('HEAVY') || eqType.toUpperCase().contains('DOZER') || eqType.toUpperCase().contains('EXCAVATOR')) {
                            unitIcon = Icons.construction_rounded;
                          } else if (eqType.toUpperCase().contains('AMBULANCE')) {
                            unitIcon = Icons.emergency_rounded;
                          } else if (eqType.toUpperCase().contains('CRANE') || eqType.toUpperCase().contains('TRUCK')) {
                            unitIcon = Icons.local_shipping_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isFull
                                        ? const Color(0xFFDCFCE7)
                                        : (isProbation ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    unitIcon,
                                    size: 22,
                                    color: isFull
                                        ? const Color(0xFF16A34A)
                                        : (isProbation ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              eqType,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isFull
                                                  ? const Color(0xFFDCFCE7)
                                                  : (isProbation ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              kewenangan.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: isFull
                                                    ? const Color(0xFF15803D)
                                                    : (isProbation ? const Color(0xFF1D4ED8) : const Color(0xFFB45309)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        kendaraan,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.timer_outlined, size: 13, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Jam: $jamAktual Jam (Min. $jamMin Jam)',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                          if (uTeori != null && uTeori != 'null') ...[
                                            const SizedBox(width: 10),
                                            Text(
                                              '•  Nilai: T:$uTeori / P:$uPraktek',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 14),
                      // Golden Rules Reminder
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Pengemudi wajib mematuhi Golden Rules K3LH IDC, batas kecepatan, dan penggunaan sabuk keselamatan di area tambang.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Tutup Detail SIMPER',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
        );
      },
    );
  }

  Widget _buildSimperInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _showMcuModal() {
    if (_mcuHasil == null || _mcuHasil!.isEmpty) {
      _showFeatureDetail(
        'Medical Check Up (MCU) & Kesiapan Kerja',
        'Belum ada riwayat pemeriksaan Medical Check Up (MCU) yang tercatat di database ONE Evolution untuk NIK $_nik.\n\n'
        'Pemeriksaan MCU berkala dikoordinasikan secara terjadwal oleh Departemen OHS & Klinik Site IDC.',
        Icons.medical_services_rounded,
        const Color(0xFFEC4899),
      );
      return;
    }

    final isFit = _mcuHasil == 'FIT TO WORK';
    final isUnfit = _mcuHasil == 'UNFIT';
    final color = isFit
        ? const Color(0xFF10B981)
        : (isUnfit ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    _showFeatureDetail(
      'Medical Check Up (MCU) & Kesiapan Kerja',
      'Hasil MCU: $_mcuHasil\n'
      'Tanggal Pemeriksaan: ${_mcuTanggal ?? "-"}\n\n'
      'Anjuran & Catatan Dokter:\n${_mcuKeterangan != null && _mcuKeterangan!.isNotEmpty ? _mcuKeterangan : "-"}\n\n'
      'Lampiran Dokumen Rekam Medis:\n${_mcuFile != null && _mcuFile!.isNotEmpty ? _mcuFile : "-"}\n\n'
      'Status rekam medis ini tersinkronisasi langsung dari ONE Evolution.',
      Icons.medical_services_rounded,
      color,
    );
  }

  void _showFeatureDetail(String title, String desc, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required IconData icon,
    bool isLoading = false,
    String? hint,
  }) {
    final safeValue = items.any((i) => i.value == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            if (isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF6366F1)),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: safeValue,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint ?? '-- Pilih $label --',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
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
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  void _showFilterToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
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

  _MenuItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.badge,
    required this.onTap,
  });
}
