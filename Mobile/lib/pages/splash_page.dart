import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/api.dart';
import '../services/database.dart';
import '../services/preference.dart';
import '../services/sync.dart';
import '../utils/globals.dart' as globals;
import 'package:url_launcher/url_launcher.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'permission_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  final _api = ApiService();
  final _db = DatabaseService();
  final _auth = PreferenceService.getAuth();
  String _version = '';
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  double _syncProgress = 0.05;
  String _syncStatus = 'Menghubungkan ke server...';

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeIn,
    );

    _animCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initStartupAndSync();
    });
  }

  Future<void> _initStartupAndSync() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      globals.appName = packageInfo.appName;
      globals.packageName = packageInfo.packageName;
      globals.version = packageInfo.version;
      globals.buildNumber = packageInfo.buildNumber;

      if (mounted) {
        setState(() => _version = packageInfo.version);
      }
    } catch (_) {}

    if (_auth != null && _auth!.token != null) {
      _api.setToken = _auth!.token!;
    }

    // Periksa konektivitas jaringan
    bool isOnline = false;
    try {
      final con = await Connectivity().checkConnectivity();
      isOnline = con.contains(ConnectivityResult.wifi) ||
          con.contains(ConnectivityResult.mobile);
    } catch (_) {}

    if (isOnline) {
      if (mounted) {
        setState(() {
          _syncProgress = 0.08;
          _syncStatus = 'Memeriksa versi aplikasi...';
        });
      }

      // 1. Verifikasi Versi Aplikasi: Force update jika versi di HP lebih rendah dari batas minimum server
      try {
        final versionConfig = await _api.checkAppVersion();
        if (versionConfig != null) {
          final bool forceUpdate = versionConfig['force_update'] == true;
          final String minVer =
              versionConfig['min_version']?.toString() ?? '1.0.5';
          final String latestVer =
              versionConfig['latest_version']?.toString() ?? '1.0.5';
          final int minBuild = (versionConfig['min_build'] is int)
              ? versionConfig['min_build'] as int
              : int.tryParse(versionConfig['min_build']?.toString() ?? '0') ??
                  0;
          final int latestBuild = (versionConfig['latest_build'] is int)
              ? versionConfig['latest_build'] as int
              : int.tryParse(versionConfig['latest_build']?.toString() ?? '0') ??
                  0;
          final int currentBuild = int.tryParse(globals.buildNumber) ?? 0;
          final String currentVer =
              (globals.version.isNotEmpty) ? globals.version : '1.0.5';
          final String playStoreUrl = versionConfig['playstore_url']
                  ?.toString() ??
              'https://play.google.com/store/apps/details?id=id.indexim.mbs&hl=id';
          final String dialogTitle = versionConfig['title']?.toString() ??
              'Update Aplikasi Tersedia';
          final String dialogMsg = versionConfig['message']?.toString() ??
              'Versi aplikasi Anda saat ini sudah usang. Harap perbarui ke versi terbaru di Google Play Store untuk dapat melanjutkan penggunaan MBS SAP.';
          final String releaseNotes =
              versionConfig['release_notes']?.toString() ?? '';

          final bool isMandatory = _isVersionLower(currentVer, minVer) ||
              (currentBuild > 0 && minBuild > 0 && currentBuild < minBuild) ||
              (forceUpdate && (_isVersionLower(currentVer, latestVer) || (currentBuild > 0 && latestBuild > 0 && currentBuild < latestBuild)));

          final bool isOptional = !isMandatory && (
              _isVersionLower(currentVer, latestVer) ||
              (currentBuild > 0 && latestBuild > 0 && currentBuild < latestBuild)
          );

          if (isMandatory && mounted) {
            await _showForceUpdateDialog(
              currentVersion: currentVer,
              targetVersion: minVer.isNotEmpty ? minVer : latestVer,
              playStoreUrl: playStoreUrl,
              title: dialogTitle,
              message: dialogMsg,
              releaseNotes: releaseNotes,
              isMandatory: true,
            );
            return; // Hentikan inisialisasi agar user wajib update ke Play Store
          } else if (isOptional && mounted) {
            await _showForceUpdateDialog(
              currentVersion: currentVer,
              targetVersion: latestVer,
              playStoreUrl: playStoreUrl,
              title: 'Pembaruan Tersedia',
              message: 'Versi terbaru Indexsafe Evolution v$latestVer telah tersedia di Play Store. Anda dapat memperbarui sekarang untuk mendapatkan fitur terbaru.',
              releaseNotes: releaseNotes,
              isMandatory: false,
            );
          }
        }
      } catch (err) {
        debugPrint('[SplashPage] Gagal memeriksa versi aplikasi: $err');
      }

      if (mounted) {
        setState(() {
          _syncProgress = 0.12;
          _syncStatus = 'Memeriksa kesiapan data offline tambang...';
        });
      }

      // Dataset kartu berisi data personal karyawan. Sinkronisasi penuh hanya
      // boleh dilakukan setelah sesi akun tervalidasi, bukan dari endpoint
      // anonim sebelum login. Setelah sekali login, cache tetap dipakai penuh
      // ketika perangkat offline.
      final isSynced = PreferenceService.isMasterDataSynced();
      final hasAuthenticatedSession = _auth?.token != null &&
          _auth!.token!.isNotEmpty &&
          !_auth!.token!.startsWith('offline_token_');
      if (!isSynced && hasAuthenticatedSession) {
        if (mounted) {
          setState(() {
            _syncProgress = 0.18;
            _syncStatus =
                'Mengunduh data master keselamatan untuk offline mode...';
          });
        }

        // Unduh seluruh master data ke database lokal SQLite
        await syncAllMasterData(
          db: _db,
          api: _api,
          onProgress: (masterName, percent, statusText) {
            if (mounted) {
              setState(() {
                _syncProgress = 0.18 + (percent / 100.0) * 0.65;
                _syncStatus = statusText;
              });
            }
          },
        );
      } else if (isSynced) {
        if (mounted) {
          setState(() {
            _syncProgress = 0.80;
            _syncStatus = 'Konfigurasi sistem lokal terverifikasi';
          });
        }
        await Future.delayed(const Duration(milliseconds: 350));
      } else if (mounted) {
        setState(() {
          _syncProgress = 0.80;
          _syncStatus = 'Login diperlukan untuk menyiapkan data offline';
        });
      }

      // Validasi akun & profil login untuk persiapan offline
      if (_auth != null && _auth!.token != null) {
        if (mounted) {
          setState(() {
            _syncProgress = 0.90;
            _syncStatus =
                'Sedang melakukan sinkronisasi data awal sebelum aplikasi berjalan...';
          });
        }

        try {
          final pRes = await _api.getProfile();
          await pRes.fold((_) async {}, (profile) async {
            PreferenceService.setProfile(profile);

            // Simpan akun ke SQLite employees agar bisa verifikasi offline
            try {
              await _db.insert('employees', {
                'id': profile.id,
                'no_nik': profile.noNik,
                'nama_lengkap': profile.namaLengkap,
                'foto': profile.foto,
                'depart': profile.depart,
                'posisi': profile.posisi,
              });
            } catch (_) {}

            final pwd = PreferenceService.getPassword() ??
                PreferenceService.getOfflinePassword() ??
                '';
            if (pwd.isNotEmpty) {
              await PreferenceService.setOfflineCredentials(
                nik: profile.noNik ?? '',
                password: pwd,
                fullName: profile.namaLengkap,
              );
            }
          });
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _syncProgress = 1.0;
          _syncStatus = 'Selesai! Sistem siap digunakan';
        });
      }
    } else {
      // PERANGKAT DALAM MODE OFFLINE
      if (mounted) {
        setState(() {
          _syncProgress = 1.0;
          _syncStatus = 'Mode Siaga Offline (Data lokal siap)';
        });
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final Widget targetPage = (_auth != null && _auth!.token != null)
        ? const HomePage()
        : const LoginPage();

    if (_auth != null && _auth!.token != null) {
      globals.currentPage = 0;
    }

    // Wajibkan seluruh izin penting K3 terpenuhi saat awal aplikasi dibuka/diinstal
    final hasAllPermissions = await PermissionPage.hasAllRequiredPermissions();
    if (!mounted) return;

    if (!hasAllPermissions) {
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => PermissionPage(nextDestination: targetPage),
        ),
        (route) => false,
      );
    } else {
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => targetPage),
        (route) => false,
      );
    }
  }

  bool _isVersionLower(String current, String target) {
    try {
      final cParts =
          current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final tParts =
          target.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final t = i < tParts.length ? tParts[i] : 0;
        if (c < t) return true;
        if (c > t) return false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _openPlayStore(String playStoreUrl) async {
    const fallback =
        'https://play.google.com/store/apps/details?id=id.indexim.mbs&hl=id';
    try {
      final marketUri = Uri.parse('market://details?id=id.indexim.mbs');
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final webUri = Uri.parse(playStoreUrl);
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final fallbackUri = Uri.parse(fallback);
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWebPortal() async {
    const webUrl = 'https://mbssap.indexim.id/';
    try {
      final uri = Uri.parse(webUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _showForceUpdateDialog({
    required String currentVersion,
    required String targetVersion,
    required String playStoreUrl,
    required String title,
    required String message,
    required String releaseNotes,
    bool isMandatory = true,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: !isMandatory,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
            elevation: 20,
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Sleek Modern Squircle Header Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: Color(0xFF38BDF8),
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Title & Version Badge
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Versi Anda: v$currentVersion',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        Text(
                          isMandatory ? 'Wajib: v$targetVersion' : 'Tersedia: v$targetVersion',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isMandatory ? const Color(0xFF0284C7) : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Informative Message
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  // 4. Clean Release Notes Container
                  if (releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0284C7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Catatan Pembaruan:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            releaseNotes,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // 5. Opsi 1: Update Sekarang di Play Store (Primary High-Contrast Button)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openPlayStore(playStoreUrl),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.32),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shop_two_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Update di Google Play Store',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'Download versi mobile resmi terbaru',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFFCCFBF1),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 6. Modern Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ATAU PILIH WEB PORTAL',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                      ],
                    ),
                  ),

                  // 7. Opsi 2: Buka Portal Web MBS SAP (Clean Modern Corporate Card)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openWebPortal,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.language_rounded,
                                color: Color(0xFF0284C7),
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Gunakan Web MBS SAP',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 13,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Pengerjaan via https://mbssap.indexim.id',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 8. Dismiss / Nanti Saja (Hanya jika update opsional)
                  if (!isMandatory) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Nanti Saja, Masuk ke Aplikasi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_syncProgress * 100).clamp(0, 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Ambient background glow
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0D9488).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E40AF).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Center Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated MBS Logo
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F766E)
                                  .withValues(alpha: 0.14),
                              blurRadius: 36,
                              spreadRadius: 8,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo-mbs.png',
                          width: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App Title
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        const Text(
                          'INDEXSAFE EVOLUTION',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mining Safety Operations & Behavior System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Executive Animated Loading System
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sleek Progress Track
                      Container(
                        width: 220,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            width: 220 * _syncProgress.clamp(0.0, 1.0),
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: const Color(0xFF2563EB),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0D9488)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dynamic Status Text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _syncStatus,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Footer Info
                  Text(
                    'PT INDEXIM COALINDO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Versi $_version',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
