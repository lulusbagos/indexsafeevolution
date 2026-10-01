import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/background.dart';
import '../services/preference.dart';
import '../utils/helpers.dart';
import '../widgets/snackbar_msg.dart';
import 'about_page.dart';
import 'change_password_page.dart';
import 'license_agreement_page.dart';
import 'login_page.dart';
import 'privacy_policy_page.dart';
import 'roster_settings_page.dart';
import 'sync_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  final _api = ApiService();
  ProfileModel? _profile;
  ImageProvider? _image;
  bool _isUploadingPhoto = false;
  bool _showAllTime = false;
  bool _isBackgroundSyncEnabled = false;
  bool _isPowerSaverEnabled = true;
  bool _isAutoNotifEnabled = false;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _profile = PreferenceService.getProfile();
    _isBackgroundSyncEnabled = PreferenceService.isBackgroundSyncEnabled();
    _isPowerSaverEnabled = PreferenceService.isPowerSaverEnabled();
    _isAutoNotifEnabled = PreferenceService.isAutoNotifEnabled();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _loadProfilePhoto();
    _fetchLatestProfile();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestProfile() async {
    try {
      final res = await _api.getProfile();
      res.fold(
        (err) => debugPrint('[ProfilePage] Fetch profile warning: $err'),
        (updated) {
          if (!mounted) return;
          setState(() {
            _profile = updated;
          });
          PreferenceService.setProfile(updated);
          _loadProfilePhoto();
        },
      );
    } catch (e) {
      debugPrint('[ProfilePage] Fetch profile exception: $e');
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final foto = _profile?.foto;
      if (foto == null || foto.trim().isEmpty) return;

      // 1. Direct local file check
      final file = File(foto);
      if (await file.exists()) {
        if (!mounted) return;
        setState(() => _image = FileImage(file));
        return;
      }

      // 2. Local app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/$foto');
      if (await localFile.exists()) {
        if (!mounted) return;
        setState(() => _image = FileImage(localFile));
        return;
      }

      // 3. Server URL (Full HTTP or Relative /uploads from MBS_SAP / Evolution)
      if (foto.startsWith('http')) {
        if (!mounted) return;
        setState(() => _image = NetworkImage(foto));
        return;
      }

      if (foto.startsWith('/uploads')) {
        final serverUrl = '${_api.baseUrl}$foto';
        if (!mounted) return;
        setState(() => _image = NetworkImage(serverUrl));
        return;
      }
    } catch (e) {
      debugPrint('[ProfilePage] Error loading profile photo: $e');
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Perbarui Foto Profil',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Foto tersinkronisasi ke server & direktori MBS_SAP Web',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF9333EA),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Ambil dari Kamera',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Buka kamera dan ambil foto potret baru',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _processPickedPhoto(ImageSource.camera);
                },
              ),
              const Divider(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Gunakan foto dari galeri penyimpanan perangkat',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _processPickedPhoto(ImageSource.gallery);
                },
              ),
              if (_image != null) ...[
                const Divider(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Hapus Foto Profil',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  subtitle: const Text(
                    'Kembalikan ke avatar inisial nama',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (_profile != null) {
                      _profile!.foto = '';
                      PreferenceService.setProfile(_profile!);
                    }
                    setState(() => _image = null);
                    SnackBarMsg.info(context, 'Foto profil dihapus.');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPickedPhoto(ImageSource source) async {
    try {
      final picked = await pickImage(source: source);
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final fileName =
          'avatar_${_profile?.id ?? 0}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final permanentFile = await picked.copy('${appDir.path}/$fileName');

      // Update immediate local state
      if (_profile != null) {
        _profile!.foto = permanentFile.path;
        PreferenceService.setProfile(_profile!);
      }

      if (!mounted) return;
      setState(() {
        _image = FileImage(permanentFile);
        _isUploadingPhoto = true;
      });

      // Synchronize to Server (MBS_SAP / Evolution Server)
      try {
        final uploadRes = await _api.changeProfile(permanentFile);
        uploadRes.fold(
          (err) {
            debugPrint('[ProfilePage] Upload error: $err');
            if (mounted) {
              SnackBarMsg.warning(context,
                  'Foto tersimpan lokal (sinkronisasi server ditunda).');
            }
          },
          (data) {
            final serverFoto = data['foto']?.toString();
            if (serverFoto != null && _profile != null) {
              _profile!.foto = serverFoto;
              PreferenceService.setProfile(_profile!);
            }
            if (mounted) {
              SnackBarMsg.success(context,
                  'Foto profil berhasil disinkronkan ke server MBS SAP!');
            }
          },
        );
      } catch (e) {
        debugPrint('[ProfilePage] Upload exception: $e');
      } finally {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
        }
      }
    } catch (e) {
      debugPrint('[ProfilePage] Error picking image: $e');
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        SnackBarMsg.danger(context, 'Gagal memproses foto: $e');
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'IS';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
  }

  void _copyNikToClipboard() {
    final nik = _profile?.noNik ?? '';
    if (nik.isNotEmpty && nik != '-') {
      Clipboard.setData(ClipboardData(text: nik));
      SnackBarMsg.success(context, 'NIK $nik disalin ke clipboard!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomClearance = 130.0 + MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Animated Ambient Aurora Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                final val = _animCtrl.value;
                return Stack(
                  children: [
                    // Shifting ambient glow orb 1 (Violet)
                    Positioned(
                      top: -60 + (val * 40),
                      left: -50 + (val * 30),
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFA855F7).withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    // Shifting ambient glow orb 2 (Rose/Pink)
                    Positioned(
                      top: 40 - (val * 30),
                      right: -60 + (val * 40),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                    // Ambient glow orb 3 (Cyan/Emerald)
                    Positioned(
                      top: 240 + (val * 20),
                      left: 20 - (val * 30),
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Main Scrollable Content with Pull-To-Refresh
          RefreshIndicator(
            color: const Color(0xFF7C3AED),
            backgroundColor: Colors.white,
            onRefresh: _fetchLatestProfile,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.only(
                top: topPadding + 10,
                bottom: bottomClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Animated Banner & Overlapping Avatar Header
                  _buildAnimatedHeaderCard(),

                  const SizedBox(height: 16),

                  // Name & Identity Info with One-Tap Copy NIK
                  _buildIdentitySection(),

                  const SizedBox(height: 18),

                  // Pencapaian Saya di Liga dan Perusahaan (Menggantikan 3 card lama)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildLeaguePerformanceCard(),
                  ),

                  const SizedBox(height: 22),

                  // Target & Achievements Card (Hazard, Inspeksi, Observasi, Talk, Coaching, P5M)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildSafetyAchievementsCard(),
                  ),

                  const SizedBox(height: 22),

                  // Grouped Cards: Informasi Karyawan
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildEmployeeInfoCard(),
                  ),

                  const SizedBox(height: 16),

                  // Grouped Cards: Keamanan & Preferensi
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildSecurityCard(),
                  ),

                  const SizedBox(height: 16),

                  // Grouped Cards: Legalitas & Informasi
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildLegalCard(),
                  ),

                  const SizedBox(height: 20),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildLogoutCard(),
                  ),

                  const SizedBox(height: 16),

                  // Footer credits
                  Center(
                    child: Text(
                      'Indexsafe Evolution • Terhubung ke MBS SAP Server',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400,
                        letterSpacing: 0.3,
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
  }

  // Animated Banner & Overlapping Avatar
  Widget _buildAnimatedHeaderCard() {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        final val = _animCtrl.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Vibrant Animated Gradient Banner
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + (val * 0.4), -1.0),
                    end: Alignment(1.0 - (val * 0.4), 1.0),
                    colors: const [
                      Color(0xFF7C3AED), // Vivid Royal Violet
                      Color(0xFFA855F7), // Purple
                      Color(0xFFE11D48), // Rose
                      Color(0xFFF43F5E), // Coral Red
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle geometric rings
                    Positioned(
                      top: -30,
                      right: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -25,
                      left: -20,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Header Title & Sync Indicator
                    Positioned(
                      top: 18,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'PROFIL SAYA',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Refresh Button on Top Right
                    Positioned(
                      top: 12,
                      right: 14,
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                        tooltip: 'Muat ulang data',
                        onPressed: _fetchLatestProfile,
                      ),
                    ),
                  ],
                ),
              ),

              // Overlapping Avatar with Camera Badge
              Positioned(
                bottom: -46,
                child: GestureDetector(
                  onTap: _showPhotoSourceSheet,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gradient ring
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFA855F7),
                              Color(0xFFF43F5E),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                      // White border ring
                      Container(
                        width: 98,
                        height: 98,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: _image != null
                              ? Image(
                                  image: _image!,
                                  fit: BoxFit.cover,
                                  width: 98,
                                  height: 98,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildInitialsFallback(),
                                )
                              : _buildInitialsFallback(),
                        ),
                      ),
                      // Uploading spinner overlay
                      if (_isUploadingPhoto)
                        Container(
                          width: 98,
                          height: 98,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      // Camera Icon Badge
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9333EA), Color(0xFFA855F7)],
                            ),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: Colors.white,
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

  Widget _buildInitialsFallback() {
    final initials = _getInitials(_profile?.namaLengkap);
    return Container(
      color: const Color(0xFFF3E8FF),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Color(0xFF7C3AED),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Name, Title, and NIK Chip with One-Tap Copy
  Widget _buildIdentitySection() {
    final name = (_profile?.namaLengkap != null &&
            _profile!.namaLengkap!.trim().isNotEmpty)
        ? _profile!.namaLengkap!.trim()
        : 'Pengguna Indexsafe';
    final role = (_profile?.posisi != null && _profile!.posisi!.trim().isNotEmpty)
        ? _profile!.posisi!.trim()
        : 'FOREMAN/OFFICER';
    final nik = _profile?.noNik ?? '-';

    return Padding(
      padding: const EdgeInsets.only(top: 36, left: 20, right: 20),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(height: 6),
          // Company Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  size: 14,
                  color: Color(0xFF0D9488),
                ),
                const SizedBox(width: 6),
                Text(
                  (_profile?.company != null &&
                          _profile!.company!.trim().isNotEmpty)
                      ? _profile!.company!.trim()
                      : 'PT Indexim Coalindo',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Interactive One-Tap Copy NIK Chip
          InkWell(
            onTap: _copyNikToClipboard,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 15,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'NIK: $nik',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pencapaian Saya di Liga dan Perusahaan (Menggantikan 3 card statis lama)
  Widget _buildLeaguePerformanceCard() {
    final isCompliant = _profile?.isMyWeekCompliant ?? true;
    final totalSubmissions = _profile?.totalSubmissions ?? 0;
    final totalTarget = _profile?.totalTarget ?? 0;
    final deptName = _profile?.userDeptName ?? _profile?.depart ?? 'SYSTEM INTEGRATIONS';
    final deptRank = _profile?.userDeptRank ?? 19;
    final deptTotal = _profile?.userDeptTotalCount ?? 24;
    final deptMtd = (_profile?.userDeptMtdRate ?? 0.0).toStringAsFixed(1);
    final empDeptRank = _profile?.userEmpDeptRank ?? 5;
    final empDeptTotal = _profile?.userEmpDeptTotalCount ?? 5;
    final empCompanyRank = _profile?.userEmpCompanyRank;
    final empCompanyTotal = _profile?.userEmpCompanyTotalCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCompliant ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompliant ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Motivation Alert Banner (Gradient Header)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompliant
                    ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                    : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Trophy / Alert
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isCompliant
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isCompliant ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCompliant ? Icons.emoji_events_rounded : Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompliant ? 'Target Minggu Ini Tercapai!' : 'Belum Memenuhi Target Kepatuhan!',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isCompliant ? const Color(0xFF065F46) : const Color(0xFF92400E),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isCompliant
                            ? 'Luar biasa! Anda telah mengunggah laporan SAP untuk minggu ini. Terima kasih atas komitmen Anda dalam menjaga keselamatan kerja.'
                            : 'Ayo! Anda belum memenuhi minimal target laporan minggu ini. Segera buat laporan untuk memenuhi target!',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: isCompliant ? const Color(0xFF047857) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Useful 3 Metric Cards (Replacing 3 old static cards)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                // Card 1: Laporan Saya Bulan Ini
                Expanded(
                  child: _buildUsefulStatCard(
                    icon: Icons.assignment_turned_in_rounded,
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    borderColor: const Color(0xFFBAE6FD),
                    stat: '$totalSubmissions / $totalTarget',
                    label: 'LAPORAN SAYA',
                    subtitle: 'Bulan Ini',
                  ),
                ),
                const SizedBox(width: 8),
                // Card 2: Departemen di Liga
                Expanded(
                  child: _buildUsefulStatCard(
                    icon: Icons.military_tech_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                    stat: '#$deptRank / $deptTotal',
                    label: 'LIGA DEPT',
                    subtitle: 'MTD: $deptMtd%',
                  ),
                ),
                const SizedBox(width: 8),
                // Card 3: Rank Saya di Dept
                Expanded(
                  child: _buildUsefulStatCard(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                    borderColor: const Color(0xFFDDD6FE),
                    stat: '#$empDeptRank / $empDeptTotal',
                    label: 'RANK DI DEPT',
                    subtitle: 'Karyawan',
                  ),
                ),
              ],
            ),
          ),

          // 3. Information Badges / Summary Chips (from /Performance/Index)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                // Dept Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Departemen $deptName: Peringkat #$deptRank dari $deptTotal (MTD: $deptMtd%)',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_rounded, color: Color(0xFF7C3AED), size: 15),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Rank Saya di Dept: #$empDeptRank / $empDeptTotal',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (empCompanyRank != null && empCompanyTotal != null) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Perusahaan: #$empCompanyRank / $empCompanyTotal',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
  }

  Widget _buildUsefulStatCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String stat,
    required String label,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 5),
          Text(
            stat,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // Safety Achievements Card with Targets from vw_r_karyawan_jabatan_mapping_preview
  Widget _buildSafetyAchievementsCard() {
    // Targets
    final targetH = _profile?.targetHazardReport ?? 1;
    final targetI = _profile?.targetInspeksi ?? 2;
    final targetO = _profile?.targetObservasi ?? 2;
    final targetST = _profile?.targetSafetyTalk ?? 1;
    final targetC = _profile?.targetCoaching ?? 1;
    final targetP = _profile?.targetP5m ?? 1;

    // Monthly Actuals
    final actH = _profile?.myHazards ?? 0;
    final actI = _profile?.myInspections ?? 0;
    final actO = _profile?.myObservasi ?? 0;
    final actST = _profile?.mySafetyTalks ?? 0;
    final actC = _profile?.myCoaching ?? 0;
    final actP = _profile?.myP5ms ?? 0;

    // Lifetime Totals
    final totH = _profile?.myHazardsTotal ?? actH;
    final totI = _profile?.myInspectionsTotal ?? actI;
    final totO = _profile?.myObservasiTotal ?? actO;
    final totST = _profile?.mySafetyTalksTotal ?? actST;
    final totC = _profile?.myCoachingTotal ?? actC;
    final totP = _profile?.myP5msTotal ?? actP;

    final kategori = _profile?.kategoriPengawas ?? 'Target Mapping Standar';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Mode Switch (Bulan Ini / Semua Waktu)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showAllTime
                          ? 'TOTAL KONTRIBUSI SAYA'
                          : 'PENCAPAIAN SAFETY (BULAN INI)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kategori,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Toggle Button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton(
                      label: 'Bulan Ini',
                      isSelected: !_showAllTime,
                      onTap: () => setState(() => _showAllTime = false),
                    ),
                    _buildToggleButton(
                      label: 'Total',
                      isSelected: _showAllTime,
                      onTap: () => setState(() => _showAllTime = true),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Row 1: Hazard, Inspeksi, Observasi
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  count: _showAllTime ? '$totH' : '$actH',
                  target: _showAllTime ? null : '$targetH',
                  label: 'Hazard',
                  textColor: const Color(0xFFF43F5E),
                  bgColor: const Color(0xFFFFF1F2),
                  borderColor: const Color(0xFFFECDD3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  count: _showAllTime ? '$totI' : '$actI',
                  target: _showAllTime ? null : '$targetI',
                  label: 'Inspeksi',
                  textColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  count: _showAllTime ? '$totO' : '$actO',
                  target: _showAllTime ? null : '$targetO',
                  label: 'Observasi',
                  textColor: const Color(0xFF0EA5E9),
                  bgColor: const Color(0xFFF0F9FF),
                  borderColor: const Color(0xFFBAE6FD),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Safety Talk, Coaching, P5M
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  count: _showAllTime ? '$totST' : '$actST',
                  target: _showAllTime ? null : '$targetST',
                  label: 'Safety Talk',
                  textColor: const Color(0xFFA855F7),
                  bgColor: const Color(0xFFFAF5FF),
                  borderColor: const Color(0xFFE9D5FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  count: _showAllTime ? '$totC' : '$actC',
                  target: _showAllTime ? null : '$targetC',
                  label: 'Coaching',
                  textColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  count: _showAllTime ? '$totP' : '$actP',
                  target: _showAllTime ? null : '$targetP',
                  label: 'P5M',
                  textColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0),
                ),
              ),
            ],
          ),

          if (!_showAllTime && _profile?.alasanTargetZero != null &&
              _profile!.alasanTargetZero!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ket: ${_profile!.alasanTargetZero}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String count,
    String? target,
    required String label,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              if (target != null) ...[
                Text(
                  ' / $target',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: textColor.withValues(alpha: 0.85),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // Informasi Karyawan Card
  Widget _buildEmployeeInfoCard() {
    final company = _profile?.company ?? 'PT INDEXIM COALINDO';
    final depart = _profile?.depart ?? 'GENERAL';
    final position = _profile?.posisi ?? 'FOREMAN/OFFICER';
    final email = _profile?.emailPribadi ??
        (_profile?.noNik != null ? 'IC${_profile!.noNik}' : '-');
    final phone = _profile?.hp ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 16, bottom: 8),
            child: Text(
              'INFORMASI KARYAWAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildInfoRow(
            icon: Icons.business_rounded,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
            label: 'Perusahaan / Mitra',
            value: company,
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.account_tree_rounded,
            iconColor: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFEDD5),
            label: 'Departemen / Bagian',
            value: depart,
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.work_rounded,
            iconColor: const Color(0xFFCA8A04),
            bgColor: const Color(0xFFFEF9C3),
            label: 'Jabatan / Posisi',
            value: position,
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.email_rounded,
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFD1FAE5),
            label: 'Email Akun',
            value: email,
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.phone_rounded,
            iconColor: const Color(0xFF9333EA),
            bgColor: const Color(0xFFF3E8FF),
            label: 'Kontak / Telepon',
            value: phone,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Keamanan & Preferensi Card
  Widget _buildSecurityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 16, bottom: 8),
            child: Text(
              'PENGATURAN AKUN & ROSTER KERJA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildActionItem(
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF9333EA),
            bgColor: const Color(0xFFF3E8FF),
            title: 'Pengaturan Roster Kerja & Tugas',
            subtitle: 'Jadwal dinas, cuti & penugasan target SAP',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RosterSettingsPage()),
              );
              if (result == true || mounted) {
                _fetchLatestProfile();
              }
            },
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: Icons.lock_reset_rounded,
            iconColor: const Color(0xFF4F46E5),
            bgColor: const Color(0xFFEEF2FF),
            title: 'Ganti Kata Sandi',
            subtitle: 'Perbarui sandi akses akun mobile & web',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ChangePasswordPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: Icons.sync_rounded,
            iconColor: const Color(0xFF0D9488),
            bgColor: const Color(0xFFF0FDFA),
            title: 'Sinkronisasi Data Master',
            subtitle: 'Sinkronisasi database offline ke server',
            onTap: _showSyncDialog,
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: _isPowerSaverEnabled
                ? Icons.energy_savings_leaf_rounded
                : Icons.speed_rounded,
            iconColor: _isPowerSaverEnabled
                ? const Color(0xFF0D9488)
                : const Color(0xFF64748B),
            bgColor: _isPowerSaverEnabled
                ? const Color(0xFFF0FDFA)
                : const Color(0xFFF8FAFC),
            title: 'Efisiensi Daya & Termal Perangkat',
            subtitle: _isPowerSaverEnabled
                ? 'Aktif (Disarankan): Warna latar statis elegan tanpa animasi beban GPU'
                : 'Nonaktif: Animasi fluid grafis kontinu 60fps aktif',
            trailing: Switch.adaptive(
              value: _isPowerSaverEnabled,
              activeTrackColor: const Color(0xFF0D9488),
              onChanged: (val) async {
                setState(() => _isPowerSaverEnabled = val);
                await PreferenceService.setPowerSaverEnabled(val);
                if (mounted) {
                  SnackBarMsg.info(
                    context,
                    val
                        ? 'Efisiensi Daya & Termal diaktifkan: Animasi dihentikan untuk menjaga kestabilan perangkat.'
                        : 'Mode Performa Grafis Dinamis diaktifkan.',
                  );
                }
              },
            ),
            onTap: () async {
              final newVal = !_isPowerSaverEnabled;
              setState(() => _isPowerSaverEnabled = newVal);
              await PreferenceService.setPowerSaverEnabled(newVal);
              if (mounted) {
                SnackBarMsg.info(
                  context,
                  newVal
                      ? 'Efisiensi Daya & Termal diaktifkan: Animasi dihentikan untuk menjaga kestabilan perangkat.'
                      : 'Mode Performa Grafis Dinamis diaktifkan.',
                );
              }
            },
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: _isAutoNotifEnabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined,
            iconColor: _isAutoNotifEnabled
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B),
            bgColor: _isAutoNotifEnabled
                ? const Color(0xFFECFDF5)
                : const Color(0xFFF8FAFC),
            title: 'Peringatan Hazard & Notifikasi Berkala',
            subtitle: _isAutoNotifEnabled
                ? 'Aktif: Pemantauan update berkala & indikator getar aktif'
                : 'Nonaktif (Optimal): Efisiensi sensor harian tanpa polling latar',
            trailing: Switch.adaptive(
              value: _isAutoNotifEnabled,
              activeTrackColor: const Color(0xFF10B981),
              onChanged: (val) async {
                setState(() => _isAutoNotifEnabled = val);
                await PreferenceService.setAutoNotifEnabled(val);
                if (mounted) {
                  SnackBarMsg.info(
                    context,
                    val
                        ? 'Peringatan berkala diaktifkan.'
                        : 'Peringatan berkala dinonaktifkan demi efisiensi baterai.',
                  );
                }
              },
            ),
            onTap: () async {
              final newVal = !_isAutoNotifEnabled;
              setState(() => _isAutoNotifEnabled = newVal);
              await PreferenceService.setAutoNotifEnabled(newVal);
              if (mounted) {
                SnackBarMsg.info(
                  context,
                  newVal
                      ? 'Peringatan berkala diaktifkan.'
                      : 'Peringatan berkala dinonaktifkan demi efisiensi baterai.',
                );
              }
            },
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: _isBackgroundSyncEnabled
                ? Icons.cloud_sync_rounded
                : Icons.cloud_off_rounded,
            iconColor: _isBackgroundSyncEnabled
                ? const Color(0xFF0284C7)
                : const Color(0xFF64748B),
            bgColor: _isBackgroundSyncEnabled
                ? const Color(0xFFF0F9FF)
                : const Color(0xFFF8FAFC),
            title: 'Layanan Sinkronisasi Latar Belakang',
            subtitle: _isBackgroundSyncEnabled
                ? 'Aktif: Sinkronisasi otomatis berjalan di latar belakang'
                : 'Nonaktif (Optimal): Mencegah konsumsi baterai saat aplikasi ditutup',
            trailing: Switch.adaptive(
              value: _isBackgroundSyncEnabled,
              activeTrackColor: const Color(0xFF0284C7),
              onChanged: (val) async {
                setState(() => _isBackgroundSyncEnabled = val);
                await PreferenceService.setBackgroundSyncEnabled(val);
                if (val) {
                  BackgroundService.instance.start();
                  if (mounted) {
                    SnackBarMsg.info(
                        context, 'Layanan sinkronisasi latar belakang diaktifkan.');
                  }
                } else {
                  BackgroundService.instance.stop();
                  if (mounted) {
                    SnackBarMsg.info(context,
                        'Layanan latar belakang dinonaktifkan demi efisiensi daya.');
                  }
                }
              },
            ),
            onTap: () async {
              final newVal = !_isBackgroundSyncEnabled;
              setState(() => _isBackgroundSyncEnabled = newVal);
              await PreferenceService.setBackgroundSyncEnabled(newVal);
              if (newVal) {
                BackgroundService.instance.start();
                if (mounted) {
                  SnackBarMsg.info(
                      context, 'Layanan sinkronisasi latar belakang diaktifkan.');
                }
              } else {
                BackgroundService.instance.stop();
                if (mounted) {
                  SnackBarMsg.info(context,
                      'Layanan latar belakang dinonaktifkan demi efisiensi daya.');
                }
              }
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // Legalitas & Informasi Card
  Widget _buildLegalCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 16, bottom: 8),
            child: Text(
              'INFORMASI & KETENTUAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildActionItem(
            icon: Icons.privacy_tip_rounded,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFF0F9FF),
            title: 'Kebijakan Privasi',
            subtitle: 'Ketentuan privasi dan keamanan data karyawan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: Icons.verified_rounded,
            iconColor: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
            title: 'Lisensi & Ketentuan',
            subtitle: 'Perjanjian lisensi pengguna akhir aplikasi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LicenseAgreementPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF64748B),
            bgColor: const Color(0xFFF8FAFC),
            title: 'Tentang Aplikasi',
            subtitle: 'Indexsafe Evolution v1.1.8',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'v1.1.8',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
          ],
        ),
      ),
    );
  }

  // Logout Card
  Widget _buildLogoutCard() {
    return InkWell(
      onTap: _showLogoutConfirmDialog,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFEE2E2), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keluar Akun',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Akhiri sesi aktif pada perangkat ini',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFFF87171),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSyncDialog() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sinkronisasi Data Master',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'Apakah Anda ingin menyinkronkan data master terbaru dari server IndexSafe?',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mulai Sinkron',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SyncPage(_profile),
        ),
      );
    }
  }

  Future<void> _showLogoutConfirmDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Keluar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini? Sesi login Anda akan diakhiri.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeLogout();
    }
  }

  Future<void> _executeLogout() async {
    try {
      // 0. Hentikan total background service saat logout agar tidak ada proses berjalan & hemat baterai
      try {
        BackgroundService.instance.stop();
      } catch (_) {}

      // 1. Panggil endpoint logout jika online
      try {
        await _api.logout();
      } catch (_) {}

      // 2. Pertahankan database lokal SQLite & kredensial offline agar mode offline tetap bisa digunakan
      // Hanya hapus token sesi online aktif
      await PreferenceService.removeAuth();
      _api.setToken = '';

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[ProfilePage] Error logging out: $e');
    }
  }
}
