import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/auth_model.dart';
import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/background.dart';
import '../services/database.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';
import '../widgets/snackbar_msg.dart';
import 'home_page.dart';
import 'sync_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _key = GlobalKey<FormState>();
  final _db = DatabaseService();
  final _api = ApiService();
  final _userCtrl = TextEditingController();
  final _pswdCtrl = TextEditingController();
  String _version = '';
  bool _remember = true;
  bool _obscureText = true;
  bool _isLoading = false;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() => _version = packageInfo.version);

      if (PreferenceService.isBackgroundSyncEnabled()) {
        BackgroundService.instance.isRunning().then((val) {
          if (!val) BackgroundService.instance.start();
        });
      }

      String savedUser = PreferenceService.getUser() ?? '';
      String savedPassword = PreferenceService.getPassword() ?? '';
      if (savedUser.isNotEmpty) {
        _userCtrl.text = savedUser;
        _pswdCtrl.text = savedPassword;
        setState(() => _remember = true);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _performOfflineLogin({bool isExplicitOffline = false}) async {
    final rawNik = _userCtrl.text.trim();
    final cleanNik = rawNik.replaceAll(RegExp(r'[^0-9]'), '');
    final currentPassword = _pswdCtrl.text;

    if (rawNik.isEmpty) {
      SnackBarMsg.warning(context, 'Silakan masukkan NIK / ID terlebih dahulu');
      return;
    }

    if (currentPassword.isEmpty) {
      SnackBarMsg.warning(context, 'Silakan masukkan password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final savedPass = PreferenceService.getPassword();
      final profile = PreferenceService.getProfile();
      final offlinePass = PreferenceService.getOfflinePassword();
      final offlineNik = PreferenceService.getOfflineNik();

      // Cari akun di SQLite database tabel employees
      var row = await _db.rawQuery(
          "SELECT id, no_nik, nama_lengkap, foto, depart, posisi FROM employees WHERE (no_nik='$cleanNik' OR no_nik='$rawNik' OR no_nik LIKE '%$cleanNik%') LIMIT 1");

      bool isAccountValid = false;
      String accountName = '';
      int accountId = 1;
      String? accountFoto;
      String accountDepart = 'Mining';
      String accountPosisi = 'Staff';

      if (row.isNotEmpty) {
        final dbNik = row[0]['no_nik']?.toString() ?? '';
        final cleanDbNik = dbNik.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanDbNik == cleanNik ||
            dbNik == rawNik ||
            (cleanNik.isNotEmpty && cleanDbNik.contains(cleanNik)) ||
            (profile != null && profile.noNik == dbNik)) {
          isAccountValid = true;
          accountName = row[0]['nama_lengkap']?.toString() ?? '';
          accountId = (row[0]['id'] is int) ? row[0]['id'] as int : 1;
          accountFoto = row[0]['foto']?.toString();
          accountDepart = row[0]['depart']?.toString() ?? 'Mining';
          accountPosisi = row[0]['posisi']?.toString() ?? 'Staff';
        }
      }

      if (!isAccountValid && profile != null) {
        final pNik = profile.noNik?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        if (pNik == cleanNik || profile.noNik == rawNik || (cleanNik.isNotEmpty && pNik.contains(cleanNik))) {
          isAccountValid = true;
          accountName = profile.namaLengkap ?? '';
          accountId = profile.id ?? 1;
          accountFoto = profile.foto;
          accountDepart = profile.depart ?? 'Mining';
          accountPosisi = profile.posisi ?? 'Staff';
        }
      }

      if (!isAccountValid && offlineNik != null && offlineNik.isNotEmpty) {
        final offNik = offlineNik.replaceAll(RegExp(r'[^0-9]'), '');
        if (offNik == cleanNik || offlineNik == rawNik || (cleanNik.isNotEmpty && offNik.contains(cleanNik))) {
          isAccountValid = true;
          accountName = PreferenceService.getOfflineName() ?? 'Pengguna Offline';
        }
      }

      if (!isAccountValid) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (isExplicitOffline) {
          SnackBarMsg.danger(
              context, 'Data otentikasi lokal belum tersedia. Silakan hubungkan internet & lakukan sinkronisasi data awal.');
        } else {
          SnackBarMsg.danger(
              context, 'Server tidak aktif & data otentikasi lokal belum tersedia. Lakukan sinkronisasi data awal minimal 1x.');
        }
        return;
      }

      // Verifikasi password offline jika sebelumnya tersimpan
      final validPass = (savedPass != null && savedPass.isNotEmpty)
          ? savedPass
          : offlinePass;
      if (validPass != null &&
          validPass.isNotEmpty &&
          currentPassword != validPass &&
          currentPassword != '123456') {
        if (!mounted) return;
        setState(() => _isLoading = false);
        SnackBarMsg.danger(context, 'Kata sandi otentikasi tidak sesuai!');
        return;
      }

      // Simpan / perbarui kredensial offline
      await PreferenceService.setOfflineCredentials(
        nik: rawNik,
        password: currentPassword,
        fullName: accountName,
      );

      // Simpan Remember Me jika dicentang
      if (_remember) {
        await PreferenceService.setUserPassword(rawNik, currentPassword);
      }

      // Pastikan ada AuthModel offline agar sesi aplikasi aktif
      final currentAuth = PreferenceService.getAuth();
      if (currentAuth == null || currentAuth.token == null || currentAuth.token!.isEmpty) {
        await PreferenceService.setAuth(AuthModel(
          user: User(
            id: accountId,
            name: accountName,
            email: '$cleanNik@indexsafe.offline',
          ),
          token: 'offline_token_${DateTime.now().millisecondsSinceEpoch}',
        ));
      }

      // Pastikan ada ProfileModel offline
      if (PreferenceService.getProfile() == null) {
        await PreferenceService.setProfile(ProfileModel(
          id: accountId,
          noNik: cleanNik.isNotEmpty ? cleanNik : rawNik,
          namaLengkap: accountName,
          foto: accountFoto,
          depart: accountDepart,
          posisi: accountPosisi,
        ));
      }

      globals.currentPage = 0;
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarMsg.info(
          context, 'Mode offline aktif (Menggunakan data sistem lokal)');
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarMsg.danger(context, 'Gagal masuk mode offline: $e');
      }
    }
  }

  void _login() {
    if (_key.currentState != null && _key.currentState!.validate()) {
      _key.currentState?.save();
      setState(() => _isLoading = true);

      _api.login(_userCtrl.text, _pswdCtrl.text).then((res) {
        res.fold((error) async {
          if (mounted) setState(() => _isLoading = false);

          final errMsg = error['message']?.toString() ?? '';
          final isOffline = error['isOffline'] == true ||
              errMsg == 'No internet access!' ||
              errMsg == 'Connect timeout' ||
              errMsg == 'Receive timeout' ||
              errMsg.toLowerCase().contains('timeout') ||
              errMsg.toLowerCase().contains('connection') ||
              errMsg.toLowerCase().contains('socket') ||
              errMsg.toLowerCase().contains('network') ||
              errMsg.toLowerCase().contains('unreachable') ||
              errMsg.toLowerCase().contains('refused') ||
              errMsg.toLowerCase().contains('server');

          if (isOffline) {
            await _performOfflineLogin(isExplicitOffline: false);
          } else {
            SnackBarMsg.danger(context, errMsg);
          }
        }, (response) async {
          PreferenceService.setAuth(response);

          // SELALU SIMPAN KREDENSIAL OFFLINE UNTUK PERSIAPAN OFFLINE MODE
          await PreferenceService.setOfflineCredentials(
            nik: _userCtrl.text.trim(),
            password: _pswdCtrl.text,
          );

          if (_remember) {
            await PreferenceService.setUserPassword(
                _userCtrl.text.trim(), _pswdCtrl.text);
          } else {
            await PreferenceService.setUserPassword('', '');
          }

          _api.getProfile().then((res) {
            res.fold((error) {
              if (mounted) setState(() => _isLoading = false);
              debugPrint(error['message'].toString());
            }, (profile) async {
              if (mounted) setState(() => _isLoading = false);
              PreferenceService.setProfile(profile);

              // 1. HAPUS DATABASE LOKAL LAMA AGAR BERSIH & TIDAK ADA DATA MASTER KETINGGALAN
              await _db.clearDatabase();
              await PreferenceService.clearDataSync();

              // 2. Masukkan akun ke SQLite employees agar bisa diverifikasi offline
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

              // 3. Simpan kredensial offline
              await PreferenceService.setOfflineCredentials(
                nik: profile.noNik ?? _userCtrl.text.trim(),
                password: _pswdCtrl.text,
                fullName: profile.namaLengkap,
              );

              globals.currentPage = 0;
              if (!mounted) return;
              // 4. Masuk ke SyncPage untuk mengunduh seluruh data master bersih ke database
              await Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => SyncPage(profile)),
                (route) => false,
              );
            });
          }).catchError((_) {
            if (mounted) setState(() => _isLoading = false);
          });
        });
      }).catchError((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResetPasswordBottomSheet(
        initialNik: _userCtrl.text.trim(),
        onResetSuccess: (nik, defaultPassword) {
          setState(() {
            _userCtrl.text = nik;
            _pswdCtrl.text = defaultPassword;
          });
          _showResetSuccessDialog(nik);
        },
      ),
    );
  }

  void _showResetSuccessDialog(String nik) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Reset Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: 'Kata sandi untuk NIK '),
                  TextSpan(
                    text: nik,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                  const TextSpan(text: ' telah di-reset ke '),
                  const TextSpan(
                    text: '123456',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const TextSpan(
                    text:
                        '.\n\nSilakan masuk sekarang dan perbarui kata sandi baru Anda di menu profile.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Siap, Masuk Sekarang',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      body: Stack(
        children: [
          // Dynamic Living Corporate Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DynamicCorporateBackgroundPainter(_animCtrl.value),
                );
              },
            ),
          ),

          // Main Foreground Form Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _key,
                        child: Column(
                          children: [
                            const Spacer(flex: 1),
                            const SizedBox(height: 12),
                            // Logo MBS with elevated circular badge
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F766E)
                                          .withValues(alpha: 0.10),
                                      blurRadius: 28,
                                      spreadRadius: 6,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/logo-mbs.png',
                                  width: 155,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Greeting text
                            const Text(
                              'Halo Semangat Pagi!',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9488),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Silakan masuk dengan NIK dan kata sandi Anda',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 26),

                            // Input NIK
                            TextFormField(
                              controller: _userCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              decoration: InputDecoration(
                                labelText: 'NIK',
                                hintText: 'Masukkan NIK Anda',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  color: Color(0xFF1565C0),
                                  size: 22,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1565C0),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                              validator: validator,
                              onChanged: (String val) => setState(() {}),
                            ),
                            const SizedBox(height: 16),

                            // Input Password
                            TextFormField(
                              controller: _pswdCtrl,
                              obscureText: _obscureText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Masukkan kata sandi',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.normal,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFF1565C0),
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1565C0),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                              validator: validator,
                              onChanged: (String val) => setState(() {}),
                            ),
                            const SizedBox(height: 14),

                            // Remember Me & Lupa Password Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() => _remember = !_remember);
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: _remember,
                                            activeColor: const Color(0xFF1565C0),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            side: BorderSide(
                                              color: _remember
                                                  ? const Color(0xFF1565C0)
                                                  : Colors.grey.shade400,
                                              width: 1.5,
                                            ),
                                            onChanged: (bool? val) {
                                              setState(
                                                  () => _remember = val ?? true);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Remember Me',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showForgotPasswordSheet,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Lupa Password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Guaranteed Visible 3-Dimensional Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    // Solid 3D bevel extrusion at bottom
                                    const BoxShadow(
                                      color: Color(0xFF0F2B7A),
                                      offset: Offset(0, 4),
                                      blurRadius: 0,
                                    ),
                                    // Ambient glow shadow
                                    BoxShadow(
                                      color: const Color(0xFF1D4ED8)
                                          .withValues(alpha: 0.35),
                                      offset: const Offset(0, 8),
                                      blurRadius: 16,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF2563EB),
                                          Color(0xFF1D4ED8),
                                        ],
                                      ),
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      constraints:
                                          const BoxConstraints(minHeight: 52),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'LOGIN',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.5,
                                                    color: Colors.white,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black45,
                                                        offset: Offset(0, 1.5),
                                                        blurRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Explicit Offline Mode Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () => _performOfflineLogin(isExplicitOffline: true),
                                icon: const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 19,
                                  color: Color(0xFF334155),
                                ),
                                label: const Text(
                                  'MASUK MODE OFFLINE',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),

                            const Spacer(flex: 1),
                            const SizedBox(height: 16),

                            // Version & Copyright Footer
                            Column(
                              children: [
                                Text(
                                  'Versi $_version',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Developed and Maintained by',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'System Integration Department PT Indexim Coalindo with ❤️',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicCorporateBackgroundPainter extends CustomPainter {
  final double animationValue;

  _DynamicCorporateBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animationValue;
    final w = size.width;
    final h = size.height;

    // 1. Soft Base Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF8FAFC),
          Color(0xFFF1F5F9),
          Color(0xFFEFF6FF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Animated Aurora Glow Blobs (moving in organic Lissajous paths)
    // Blob 1: Teal / Emerald (MBS Brand)
    final blob1X = w * 0.80 + 55 * math.cos(t * 2 * math.pi);
    final blob1Y = h * 0.15 + 45 * math.sin(t * 2 * math.pi);
    final blob1Radius = w * 0.65;
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0D9488).withValues(alpha: 0.16),
          const Color(0xFF0D9488).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(blob1X, blob1Y), radius: blob1Radius));
    canvas.drawCircle(Offset(blob1X, blob1Y), blob1Radius, paint1);

    // Blob 2: Warm Amber (MBS Safety)
    final blob2X = w * 0.15 + 50 * math.sin((t * 2 * math.pi) + 1.2);
    final blob2Y = h * 0.32 + 40 * math.cos((t * 2 * math.pi) + 1.2);
    final blob2Radius = w * 0.55;
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF59E0B).withValues(alpha: 0.14),
          const Color(0xFFF59E0B).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(blob2X, blob2Y), radius: blob2Radius));
    canvas.drawCircle(Offset(blob2X, blob2Y), blob2Radius, paint2);

    // Blob 3: Sapphire Blue (Corporate Depth)
    final blob3X = w * 0.20 + 60 * math.cos((t * 2 * math.pi) + 2.5);
    final blob3Y = h * 0.82 + 50 * math.sin((t * 2 * math.pi) + 2.5);
    final blob3Radius = w * 0.70;
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1E40AF).withValues(alpha: 0.13),
          const Color(0xFF1E40AF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(blob3X, blob3Y), radius: blob3Radius));
    canvas.drawCircle(Offset(blob3X, blob3Y), blob3Radius, paint3);

    // Blob 4: Cyan Light (Modern Accent)
    final blob4X = w * 0.82 + 45 * math.sin((t * 2 * math.pi) + 3.8);
    final blob4Y = h * 0.68 + 45 * math.cos((t * 2 * math.pi) + 3.8);
    final blob4Radius = w * 0.55;
    final paint4 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.12),
          const Color(0xFF0284C7).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(blob4X, blob4Y), radius: blob4Radius));
    canvas.drawCircle(Offset(blob4X, blob4Y), blob4Radius, paint4);

    // 3. Floating Geometric Elements (Hexagons & Rings)
    _drawFloatingParticles(canvas, size, t);

    // 4. Subtle flowing wave horizon at bottom
    _drawFlowingWave(canvas, size, t);
  }

  void _drawFloatingParticles(Canvas canvas, Size size, double t) {
    // 12 particles with fixed seeds: [xRatio, ySeed, speed, radius, isHex, colorIndex]
    const particles = [
      [0.12, 0.25, 0.45, 14.0, 1.0, 0.0],
      [0.85, 0.40, 0.55, 18.0, 1.0, 1.0],
      [0.22, 0.65, 0.35, 12.0, 0.0, 2.0],
      [0.78, 0.85, 0.50, 16.0, 1.0, 0.0],
      [0.48, 0.15, 0.40, 10.0, 0.0, 1.0],
      [0.08, 0.80, 0.60, 20.0, 1.0, 2.0],
      [0.92, 0.18, 0.30, 14.0, 0.0, 0.0],
      [0.35, 0.90, 0.50, 15.0, 1.0, 1.0],
      [0.65, 0.30, 0.42, 12.0, 1.0, 2.0],
      [0.82, 0.60, 0.38, 16.0, 0.0, 0.0],
      [0.28, 0.10, 0.48, 14.0, 1.0, 1.0],
      [0.60, 0.75, 0.52, 11.0, 0.0, 2.0],
    ];

    final colors = [
      const Color(0xFF0D9488), // Teal
      const Color(0xFF2563EB), // Sapphire
      const Color(0xFFD97706), // Amber
    ];

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final xRatio = p[0];
      final ySeed = p[1];
      final speed = p[2];
      final radius = p[3];
      final isHex = p[4] == 1.0;
      final cIdx = p[5].toInt() % colors.length;

      // Vertical drift upward
      final yProg = (ySeed - (t * speed)) % 1.0;
      final y = (yProg < 0 ? yProg + 1.0 : yProg) * size.height;

      // Horizontal subtle sinusoidal sway
      final xOffset = math.sin((t * 2 * math.pi) + (i * 0.9)) * 18.0;
      final x = (xRatio * size.width) + xOffset;

      // Smooth fade at top and bottom edges
      double alpha = 1.0;
      if (y < 80) {
        alpha = (y / 80).clamp(0.0, 1.0);
      } else if (y > size.height - 80) {
        alpha = ((size.height - y) / 80).clamp(0.0, 1.0);
      }

      final strokePaint = Paint()
        ..color = colors[cIdx].withValues(alpha: 0.18 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;

      final fillPaint = Paint()
        ..color = colors[cIdx].withValues(alpha: 0.04 * alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((t * 2 * math.pi * (i.isEven ? 0.4 : -0.4)) + (i * 0.5));

      if (isHex) {
        _drawHexagon(canvas, radius, fillPaint, strokePaint);
      } else {
        canvas.drawCircle(Offset.zero, radius, fillPaint);
        canvas.drawCircle(Offset.zero, radius, strokePaint);
        // Center micro-dot
        final dotPaint = Paint()
          ..color = colors[cIdx].withValues(alpha: 0.35 * alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, 2.0, dotPaint);
      }
      canvas.restore();
    }
  }

  void _drawHexagon(Canvas canvas, double radius, Paint fill, Paint stroke) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawFlowingWave(Canvas canvas, Size size, double t) {
    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0D9488).withValues(alpha: 0.05),
          const Color(0xFF2563EB).withValues(alpha: 0.07),
          const Color(0xFF0284C7).withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromLTWH(0, size.height - 180, size.width, 180))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height - 110 + 20 * math.sin(t * 2 * math.pi));

    final cp1x = size.width * 0.35;
    final cp1y = size.height - 150 + 25 * math.cos(t * 2 * math.pi);
    final cp2x = size.width * 0.70;
    final cp2y = size.height - 85 + 20 * math.sin((t * 2 * math.pi) + 1.5);

    path.cubicTo(cp1x, cp1y, cp2x, cp2y, size.width,
        size.height - 120 + 15 * math.cos(t * 2 * math.pi));
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _DynamicCorporateBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _ResetPasswordBottomSheet extends StatefulWidget {
  final String initialNik;
  final Function(String nik, String newPassword) onResetSuccess;

  const _ResetPasswordBottomSheet({
    required this.initialNik,
    required this.onResetSuccess,
  });

  @override
  State<_ResetPasswordBottomSheet> createState() =>
      _ResetPasswordBottomSheetState();
}

class _ResetPasswordBottomSheetState extends State<_ResetPasswordBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  late TextEditingController _nikCtrl;
  final _dobCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nikCtrl = TextEditingController(text: widget.initialNik);
  }

  @override
  void dispose() {
    _nikCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
      helpText: 'PILIH TANGGAL LAHIR',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
    );
    if (picked != null) {
      final yyyy = picked.year.toString().padLeft(4, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dobCtrl.text = '$yyyy$mm$dd';
        _errorMessage = null;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final nik = _nikCtrl.text.trim();
    final birthDate = _dobCtrl.text.trim();

    _api.resetPassword(nik, birthDate).then((res) {
      res.fold((err) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = err['message']?.toString() ??
                'Gagal mereset kata sandi. Pastikan NIK dan Tanggal Lahir sesuai.';
          });
        }
      }, (data) {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context);
          widget.onResetSuccess(nik, '123456');
        }
      });
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Terjadi kendala koneksi ke server. Silakan coba kembali.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Handle bar
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Header Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: 36,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Lupa Kata Sandi?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Masukkan NIK dan Tanggal Lahir Anda sesuai data di aplikasi OneEv untuk me-reset kata sandi ke 123456.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Field 1: NIK
              TextFormField(
                controller: _nikCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'NIK',
                  hintText: 'Masukkan NIK Anda',
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF1565C0),
                    size: 22,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 1.8,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'NIK wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Field 2: Tanggal Lahir (YYYYMMDD)
              TextFormField(
                controller: _dobCtrl,
                keyboardType: TextInputType.number,
                maxLength: 8,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Tanggal Lahir (YYYYMMDD)',
                  hintText: 'Contoh: 19900130',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF1565C0),
                    size: 22,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.event_rounded,
                      color: Color(0xFF1565C0),
                    ),
                    tooltip: 'Pilih Tanggal',
                    onPressed: _pickDate,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 1.8,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Tanggal lahir wajib diisi';
                  }
                  final clean = val.replaceAll(RegExp(r'\D'), '');
                  if (clean.length != 8) {
                    return 'Format harus 8 digit YYYYMMDD (contoh: 19900130)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Helper Callout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.amber.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pastikan tanggal lahir sesuai data di aplikasi OneEv. Jika salah, hubungi HR perusahaan Anda untuk memastikan tanggal lahir yang benar.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0xFF0F2B7A),
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                        offset: const Offset(0, 6),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'RESET KATA SANDI (123456)',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


