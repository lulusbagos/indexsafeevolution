import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/api.dart';
import '../services/database.dart';
import '../services/preference.dart';
import '../services/sync.dart';
import '../utils/globals.dart' as globals;
import 'home_page.dart';
import 'login_page.dart';
import 'permission_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
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
          _syncProgress = 0.12;
          _syncStatus = 'Memeriksa kesiapan data offline tambang...';
        });
      }

      // Periksa apakah data master sudah tersinkronisasi
      final isSynced = PreferenceService.isMasterDataSynced();
      if (!isSynced) {
        if (mounted) {
          setState(() {
            _syncProgress = 0.18;
            _syncStatus = 'Mengunduh data master keselamatan untuk offline mode...';
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
      } else {
        if (mounted) {
          setState(() {
            _syncProgress = 0.80;
            _syncStatus = 'Konfigurasi sistem lokal terverifikasi';
          });
        }
        await Future.delayed(const Duration(milliseconds: 350));
      }

      // Validasi akun & profil login untuk persiapan offline
      if (_auth != null && _auth!.token != null) {
        if (mounted) {
          setState(() {
            _syncProgress = 0.90;
            _syncStatus = 'Sedang melakukan sinkronisasi data awal sebelum aplikasi berjalan...';
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
                              color: const Color(0xFF0F766E).withValues(alpha: 0.14),
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
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0D9488),
                                  Color(0xFF2563EB),
                                  Color(0xFFF59E0B),
                                ],
                              ),
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
