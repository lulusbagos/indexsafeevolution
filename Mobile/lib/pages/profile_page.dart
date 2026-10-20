import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/background.dart';
import '../services/notification.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
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

class _ProfilePageState extends State<ProfilePage> {
  final _scrollCtrl = ScrollController();
  final _api = ApiService();
  ProfileModel? _profile = PreferenceService.getProfile();
  ImageProvider? _image;
  bool _isUploading = false;
  bool _isRefreshingProfile = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadProfileImage();
      _fetchLatestProfile();
    });
  }

  Future<void> _fetchLatestProfile() async {
    if (_isRefreshingProfile) return;
    setState(() => _isRefreshingProfile = true);
    try {
      final res = await _api.getProfile();
      res.fold((error) {
        debugPrint('Error fetching latest profile: ${error['message']}');
      }, (profile) async {
        await PreferenceService.setProfile(profile);
        if (mounted) {
          setState(() {
            _profile = profile;
          });
          _loadProfileImage();
        }
      });
    } catch (e) {
      debugPrint('Exception fetching profile: $e');
    } finally {
      if (mounted) setState(() => _isRefreshingProfile = false);
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final temp = '${(await getTemporaryDirectory()).path}/';

      if (_profile != null && _profile!.foto != null && _profile!.foto!.isNotEmpty) {
        final localFile = File(_profile!.foto!);
        final tempFile = File(temp + _profile!.foto!);

        if (localFile.existsSync()) {
          setState(() => _image = MemoryImage(localFile.readAsBytesSync()));
        } else if (tempFile.existsSync()) {
          setState(() => _image = MemoryImage(tempFile.readAsBytesSync()));
        } else {
          await _api.dio.download(
            '${_api.baseUrl}/image/${_profile!.foto}',
            temp + _profile!.foto!,
          );
          if (!mounted) return;
          if (tempFile.existsSync()) {
            setState(() => _image = MemoryImage(tempFile.readAsBytesSync()));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final file = await pickImage(source: source);
      if (file != null && _profile != null) {
        setState(() {
          _isUploading = true;
          _image = MemoryImage(file.readAsBytesSync());
        });

        _profile!.foto = file.path;
        await PreferenceService.setProfile(_profile!);

        final res = await _api.changeProfile(file);
        if (!mounted) return;
        res.fold((error) {
          SnackBarMsg.danger(context, error['message'].toString());
        }, (response) {
          SnackBarMsg.success(context, 'Foto profil berhasil diperbarui');
        });
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Ubah Foto Profil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih sumber foto untuk memperbarui avatar Anda',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndUploadPhoto(ImageSource.camera);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF009688).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF009688).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: Color(0xFF009688), size: 28),
                          SizedBox(height: 8),
                          Text(
                            'Kamera',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF009688),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndUploadPhoto(ImageSource.gallery);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_rounded, color: Color(0xFF1D4ED8), size: 28),
                          SizedBox(height: 8),
                          Text(
                            'Galeri',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
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

  void _confirmSyncMaster() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sync_rounded, color: Color(0xFF009688)),
            SizedBox(width: 10),
            Text(
              'Sinkronisasi Master',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Aplikasi akan mengunduh ulang seluruh master data dari server. Proses ini memastikan referensi area, lokasi, dan modul selalu mutakhir.\n\nLanjutkan?',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              globals.reSync = true;
              PreferenceService.setDataSync(<String, int>{});
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => SyncPage(_profile!)),
                (route) => false,
              );
            },
            child: const Text('Sinkronkan Sekarang'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi Indexsafe Evolution pada perangkat ini?',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _performLogout();
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    NotificationService.cancelAll();
    final isRunning = await BackgroundService.instance.isRunning();
    if (isRunning) BackgroundService.instance.stop();

    _api.logout().then((res) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('bgToken');
      await prefs.remove('bgProfile');

      PreferenceService.removeAuth();
      PreferenceService.removeProfile();

      if (!mounted) return;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nama = _profile?.namaLengkap?.trim() ?? 'PENGGUNA INDEXSAFE';
    final posisi = (_profile?.posisi?.trim().isNotEmpty == true)
        ? _profile!.posisi!.trim()
        : 'Staff';
    final jabatan = (_profile?.jabatan?.trim().isNotEmpty == true)
        ? _profile!.jabatan!.trim()
        : ((_profile?.level?.trim().isNotEmpty == true)
            ? _profile!.level!.trim()
            : ((_profile?.grade?.trim().isNotEmpty == true)
                ? _profile!.grade!.trim()
                : posisi));
    final depart = _profile?.depart?.trim() ?? '-';
    final nik = _profile?.noNik?.trim() ?? '-';
    final company = _profile?.company?.trim() ?? 'PT Indexim Coalindo';
    final permitNomor = _profile?.permitNomor?.trim() ?? '';
    final masaAktifPermit = _profile?.masaAktifPermit?.trim() ?? '';

    // Hitung status kedaluwarsa permit (peringatan merah jika <= 3 bulan / 90 hari)
    DateTime? permitExpiryDate;
    if (masaAktifPermit.isNotEmpty) {
      final parsed = DateTime.tryParse(masaAktifPermit);
      if (parsed != null) {
        permitExpiryDate = parsed;
      } else {
        final parts = masaAktifPermit.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) permitExpiryDate = DateTime(y, m, d);
          } else if (parts[2].length == 4) {
            final d = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final y = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) permitExpiryDate = DateTime(y, m, d);
          }
        }
      }
    }

    bool isPermitExpiringSoon = false;
    bool isPermitExpired = false;
    String permitWarningText = '';

    if (permitExpiryDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiryDay = DateTime(permitExpiryDate.year, permitExpiryDate.month, permitExpiryDate.day);
      final diff = expiryDay.difference(today).inDays;

      if (diff < 0) {
        isPermitExpired = true;
        isPermitExpiringSoon = true;
        permitWarningText = 'Masa berlaku permit telah kedaluwarsa (${diff.abs()} hari lalu). Segera lakukan perpanjangan permit!';
      } else if (diff <= 90) { // 3 bulan (~90 hari)
        isPermitExpiringSoon = true;
        final months = (diff / 30).ceil();
        permitWarningText = diff <= 30
            ? 'PERMIT MAU HABIS: Sisa $diff hari lagi! Segera ajukan perpanjangan permit.'
            : 'PERMIT MAU HABIS: Sisa ~$months bulan ($diff hari)! Segera ajukan perpanjangan permit.';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: RefreshIndicator(
        color: const Color(0xFF009688),
        onRefresh: _fetchLatestProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollCtrl,
        child: Column(
          children: [
            // Card Foto Profil & NIK dengan Gradien Modern
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFC2410C), // Deep Rust Orange
                        Color(0xFFEA580C), // Vibrant Safety Orange
                        Color(0xFFF97316), // Radiant Tangerine Orange
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Unsur Kuning - Pendar Cahaya Hangat di Kanan Atas (Seamless Feathering)
                      Positioned(
                        top: -60,
                        right: -50,
                        child: IgnorePointer(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFFDE047).withValues(alpha: 0.20),
                                  const Color(0xFFFDE047).withValues(alpha: 0.08),
                                  const Color(0xFFFDE047).withValues(alpha: 0.02),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35, 0.70, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Unsur Biru Muda Sedikit - Pendar Cahaya Lembut di Bagian Atas
                      Positioned(
                        top: -30,
                        left: 45,
                        child: IgnorePointer(
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF38BDF8).withValues(alpha: 0.16),
                                  const Color(0xFF38BDF8).withValues(alpha: 0.05),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.50, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Unsur Hijau Tipis - Pendar Cahaya Halus di Kiri Bawah
                      Positioned(
                        bottom: -45,
                        left: -35,
                        child: IgnorePointer(
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF34D399).withValues(alpha: 0.16),
                                  const Color(0xFF34D399).withValues(alpha: 0.04),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.50, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Column(
                        children: [
                          // Tag Header Card: Company & Departemen (Frosted Glassmorphism Clean)
                          Row(
                            children: [
                              // Company Pill
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.business_rounded, size: 12, color: Color(0xFF7DD3FC)),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          company.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Departemen Pill
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.work_outline_rounded, size: 12, color: Color(0xFF6EE7B7)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          depart.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Tombol i (QR Code NIK Modal)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showNikQrModal(
                                    context: context,
                                    nik: nik,
                                    nama: nama,
                                    posisi: posisi,
                                    jabatan: jabatan,
                                    company: company,
                                    depart: depart,
                                    permitNomor: permitNomor,
                                    masaAktif: masaAktifPermit,
                                    isPermitExpiringSoon: isPermitExpiringSoon,
                                    isPermitExpired: isPermitExpired,
                                    qrCode: _profile?.qrCode,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Profil Horizontal: Foto di Kiri, Detail di Kanan
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar di sebelah kiri (radius 34)
                              GestureDetector(
                                onTap: _showPhotoOptions,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 34,
                                        backgroundColor: const Color(0xFF1E293B),
                                        child: _isUploading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : _image != null
                                                ? ClipOval(
                                                    child: Image(
                                                      image: _image!,
                                                      width: 68,
                                                      height: 68,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.person_rounded,
                                                    size: 40,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEA580C),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.6),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Detail Identitas di Kanan
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nama.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      posisi,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFE2E8F0),
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        // Level / Jabatan Badge
                                        if (jabatan.isNotEmpty && jabatan.trim().toUpperCase() != posisi.trim().toUpperCase())
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.22),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFFDE047).withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              jabatan.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFFDE047),
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                        // NIK Chip (Tap untuk QR)
                                        InkWell(
                                          onTap: () => _showNikQrModal(
                                            context: context,
                                            nik: nik,
                                            nama: nama,
                                            posisi: posisi,
                                            jabatan: jabatan,
                                            company: company,
                                            depart: depart,
                                            permitNomor: permitNomor,
                                            masaAktif: masaAktifPermit,
                                            isPermitExpiringSoon: isPermitExpiringSoon,
                                            isPermitExpired: isPermitExpired,
                                            qrCode: _profile?.qrCode,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.badge_outlined, size: 11, color: Color(0xFF38BDF8)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  nik,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.qr_code_rounded, size: 11, color: Color(0xFF38BDF8)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Panel Digital Permit Tambang (Slim Horizontal Bar)
                          InkWell(
                            onTap: () => _showNikQrModal(
                              context: context,
                              nik: nik,
                              nama: nama,
                              posisi: posisi,
                              jabatan: jabatan,
                              company: company,
                              depart: depart,
                              permitNomor: permitNomor,
                              masaAktif: masaAktifPermit,
                              isPermitExpiringSoon: isPermitExpiringSoon,
                              isPermitExpired: isPermitExpired,
                              qrCode: _profile?.qrCode,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPermitExpiringSoon
                                      ? const Color(0xFFF87171).withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.14),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isPermitExpiringSoon
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                                          : const Color(0xFF34D399).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Icon(
                                      isPermitExpiringSoon
                                          ? Icons.notification_important_rounded
                                          : Icons.verified_user_rounded,
                                      size: 15,
                                      color: isPermitExpiringSoon
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFF34D399),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          permitNomor.isNotEmpty ? permitNomor : 'TIDAK ADA PERMIT',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: isPermitExpiringSoon ? const Color(0xFFFCA5A5) : Colors.white,
                                          ),
                                        ),
                                        Text(
                                          masaAktifPermit.isNotEmpty ? 'Masa Berlaku : $masaAktifPermit' : 'Masa Berlaku : -',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: isPermitExpiringSoon
                                                ? const Color(0xFFFCA5A5)
                                                : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Status Badge (Aktif / Mau Habis / Kedaluwarsa)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: isPermitExpired
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                          : (isPermitExpiringSoon
                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                              : const Color(0xFF059669).withValues(alpha: 0.35)),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: isPermitExpired
                                            ? const Color(0xFFF87171).withValues(alpha: 0.7)
                                            : (isPermitExpiringSoon
                                                ? const Color(0xFFFCD34D).withValues(alpha: 0.7)
                                                : const Color(0xFF34D399).withValues(alpha: 0.7)),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      isPermitExpired
                                          ? 'KEDALUWARSA'
                                          : (isPermitExpiringSoon
                                              ? 'MAU HABIS'
                                              : (permitNomor.isNotEmpty ? 'AKTIF ✓' : '-')),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                        color: isPermitExpired
                                            ? const Color(0xFFFCA5A5)
                                            : (isPermitExpiringSoon
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFF6EE7B7)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Peringatan Merah jika permit expired / mau habis <= 3 bulan
                          if (isPermitExpiringSoon) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF87171).withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.priority_high_rounded, color: Color(0xFFFCA5A5), size: 13),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      permitWarningText,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFEE2E2),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Body Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Target & Aktual SAP Periode Berjalan (1 s/d Akhir Bulan)
                  _buildSapPerformanceCard(),

                  const SizedBox(height: 22),

                  // Section 1: Akun & Keamanan
                  _buildSectionHeader('Akun & Keamanan'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: Icons.lock_outline_rounded,
                          iconColor: const Color(0xFF009688),
                          title: 'Ganti Password',
                          subtitle: 'Perbarui kata sandi login akun Anda',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChangePasswordPage(),
                              ),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.calendar_month_rounded,
                          iconColor: const Color(0xFF1D4ED8),
                          title: 'Pengaturan Roster Kerja',
                          subtitle: 'Jadwal dinas reguler & penugasan',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RosterSettingsPage(),
                              ),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.sync_rounded,
                          iconColor: const Color(0xFF0284C7),
                          title: 'Sinkronisasi Master Data',
                          subtitle: 'Unduh ulang database referensi & konfigurasi',
                          onTap: _confirmSyncMaster,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Section 2: Informasi & Legalitas
                  _buildSectionHeader('Informasi & Legalitas'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: const Color(0xFF4F46E5),
                          title: 'Tentang Aplikasi',
                          subtitle: 'Informasi versi dan pengembang Indexsafe',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutPage(),
                              ),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFF059669),
                          title: 'Kebijakan Privasi',
                          subtitle: 'Pedoman privasi dan perlindungan data',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PrivacyPolicyPage(),
                              ),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFFD97706),
                          title: 'Perjanjian Lisensi',
                          subtitle: 'Syarat & ketentuan penggunaan sistem',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LicenseAgreementPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 3: Sesi Keluar
                  InkWell(
                    onTap: _confirmLogout,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA), width: 1),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Keluar dari Akun (Logout)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Footer Version
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'Indexsafe Evolution • Mobile v2.0',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'PT Indexim Coalindo HSE Integrated System',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }



  void _showNikQrModal({
    required BuildContext context,
    required String nik,
    required String nama,
    required String posisi,
    required String jabatan,
    required String company,
    required String depart,
    required String permitNomor,
    required String masaAktif,
    required bool isPermitExpiringSoon,
    required bool isPermitExpired,
    String? qrCode,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final qrData = (qrCode != null && qrCode.isNotEmpty)
            ? qrCode
            : ((nik.isNotEmpty && nik != '-') ? nik : 'NO_NIK');

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // Modal Top Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: Color(0xFF009688),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KARTU IDENTITAS DIGITAL',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            'Verifikasi Data NIK Karyawan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // QR Code Showcase Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF134E4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF009688).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // QR Code Frame
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 175.0,
                        padding: const EdgeInsets.all(4),
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Monospace NIK pill with copy button
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: nik));
                        SnackBarMsg.success(context, 'NIK $nik disalin ke clipboard');
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              size: 14,
                              color: Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'NIK: $nik',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: Color(0xFFE2E8F0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Profile Credentials Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      nama.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      posisi,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$depart • $company',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (permitNomor.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPermitExpiringSoon
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: isPermitExpiringSoon
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF009688),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Permit: $permitNomor (Aktif s/d $masaAktif)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isPermitExpiringSoon
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Helper Footer Text
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: Color(0xFF009688)),
                  SizedBox(width: 6),
                  Text(
                    'QR Code resmi untuk verifikasi NIK di operasional lapangan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.8,
      indent: 56,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }

  Widget _buildSapPerformanceCard() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final periodStr = '1 - $lastDay ${months[now.month]} ${now.year}';

    final int targetHazard = _profile?.targetHazardReport ?? 0;
    final int actualHazard = _profile?.myHazards ?? 0;

    final int targetInspeksi = _profile?.targetInspeksi ?? 0;
    final int actualInspeksi = _profile?.myInspections ?? 0;

    final int targetSafetyTalk = _profile?.targetSafetyTalk ?? 0;
    final int actualSafetyTalk = _profile?.mySafetyTalks ?? 0;

    final int targetObservasi = _profile?.targetObservasi ?? 0;
    final int actualObservasi = _profile?.myObservasi ?? 0;

    final int targetCoaching = _profile?.targetCoaching ?? 0;
    final int actualCoaching = _profile?.myCoaching ?? 0;

    final int targetP5m = _profile?.targetP5m ?? 0;
    final int actualP5m = _profile?.myP5ms ?? 0;

    final double compliance = _profile?.complianceRate ?? 0.0;
    final int totalTarget = _profile?.totalTarget ?? (targetHazard + targetInspeksi + targetSafetyTalk + targetObservasi + targetCoaching + targetP5m);
    final int totalActual = (actualHazard > targetHazard ? targetHazard : actualHazard)
                          + (actualInspeksi > targetInspeksi ? targetInspeksi : actualInspeksi)
                          + (actualSafetyTalk > targetSafetyTalk ? targetSafetyTalk : actualSafetyTalk)
                          + (actualObservasi > targetObservasi ? targetObservasi : actualObservasi)
                          + (actualCoaching > targetCoaching ? targetCoaching : actualCoaching)
                          + (actualP5m > targetP5m ? targetP5m : actualP5m);

    final Color statusColor = compliance >= 100
        ? const Color(0xFF10B981)
        : (compliance >= 75 ? const Color(0xFF009688) : const Color(0xFFF59E0B));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Ringkas & Bersih
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Color(0xFF009688),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target & Capaian SAP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Periode $periodStr',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '${compliance.toStringAsFixed(0)}% Tercapai',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Mini Linear Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalTarget > 0 ? (totalActual / totalTarget).clamp(0.0, 1.0) : 1.0,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 12),

          // 3 Kolom x 2 Baris yang Ringkas & Efisien
          Row(
            children: [
              Expanded(
                child: _buildCompactMetric(
                  label: 'Hazard',
                  actual: actualHazard,
                  target: targetHazard,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMetric(
                  label: 'Inspeksi',
                  actual: actualInspeksi,
                  target: targetInspeksi,
                  color: const Color(0xFF009688),
                  icon: Icons.checklist_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMetric(
                  label: 'Safety Talk',
                  actual: actualSafetyTalk,
                  target: targetSafetyTalk,
                  color: const Color(0xFF6366F1),
                  icon: Icons.record_voice_over_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactMetric(
                  label: 'Observasi',
                  actual: actualObservasi,
                  target: targetObservasi,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.remove_red_eye_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMetric(
                  label: 'Coaching',
                  actual: actualCoaching,
                  target: targetCoaching,
                  color: const Color(0xFF0284C7),
                  icon: Icons.supervisor_account_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMetric(
                  label: 'P5M',
                  actual: actualP5m,
                  target: targetP5m,
                  color: const Color(0xFF10B981),
                  icon: Icons.groups_rounded,
                ),
              ),
            ],
          ),

          if (_profile?.kategoriPengawas != null && _profile!.kategoriPengawas!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Kategori: ${_profile!.kategoriPengawas}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
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

  Widget _buildCompactMetric({
    required String label,
    required int actual,
    required int target,
    required Color color,
    required IconData icon,
  }) {
    final bool isDone = target == 0 || actual >= target;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone ? color.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              if (isDone)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 11,
                  color: Color(0xFF10B981),
                ),
            ],
          ),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$actual',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDone ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                  ),
                ),
                TextSpan(
                  text: '/$target',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
