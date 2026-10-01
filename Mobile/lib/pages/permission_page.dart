import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/preference.dart';
import '../widgets/ambient_background.dart';
import 'home_page.dart';
import 'login_page.dart';

class PermissionPage extends StatefulWidget {
  final Widget? nextDestination;

  const PermissionPage({super.key, this.nextDestination});

  /// Cek cepat apakah seluruh izin wajib sudah terpenuhi
  static Future<bool> hasAllRequiredPermissions() async {
    final locationGranted = await Permission.location.isGranted;
    final cameraGranted = await Permission.camera.isGranted;
    final notifGranted = await Permission.notification.isGranted;
    return locationGranted && cameraGranted && notifGranted;
  }

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationGranted = false;
  bool _storageGranted = false;
  bool _isPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCurrentPermissions();
    }
  }

  Future<void> _checkCurrentPermissions() async {
    setState(() => _isChecking = true);

    final loc = await Permission.location.isGranted;
    final cam = await Permission.camera.isGranted;
    final notif = await Permission.notification.isGranted;
    final storage = await Permission.storage.isGranted || await Permission.photos.isGranted;

    final locPermanent = await Permission.location.isPermanentlyDenied;
    final camPermanent = await Permission.camera.isPermanentlyDenied;
    final notifPermanent = await Permission.notification.isPermanentlyDenied;

    final allReady = loc && cam && notif;

    if (!mounted) return;

    setState(() {
      _locationGranted = loc;
      _cameraGranted = cam;
      _notificationGranted = notif;
      _storageGranted = storage;
      _isPermanentlyDenied = locPermanent || camPermanent || notifPermanent;
      _isChecking = false;
    });

    if (allReady) {
      _proceedToApp();
    }
  }

  Future<void> _requestAllPermissions() async {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    setState(() => _isChecking = true);

    // Minta izin secara berurutan agar dialog native Android tampil jelas
    if (!_locationGranted) {
      await Permission.location.request();
    }
    if (!_cameraGranted) {
      await Permission.camera.request();
    }
    if (!_notificationGranted) {
      await Permission.notification.request();
    }
    if (!_storageGranted) {
      await Permission.storage.request();
      await Permission.photos.request();
    }

    await _checkCurrentPermissions();
  }

  void _proceedToApp() {
    if (!mounted) return;

    final auth = PreferenceService.getAuth();
    final Widget destination = widget.nextDestination ??
        ((auth != null && auth.token != null)
            ? const HomePage()
            : const LoginPage());

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _locationGranted && _cameraGranted && _notificationGranted;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AmbientBackground(
        child: SafeArea(
          child: _isChecking
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF2563EB),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Header Icon & Judul
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Center(
                        child: Text(
                          'Izin Operasional K3',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Untuk mengaktifkan radar bahaya 20m, pelaporan temuan, dan peringatan darurat tambang PT Indexim Coalindo, izinkan akses berikut:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // List Kartu Izin
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildPermissionCard(
                              title: 'Lokasi Presisi (GPS & Radar 20m)',
                              desc: 'Wajib untuk mendeteksi radius bahaya K3 (≤20m), SafeMap satelit, dan verifikasi geofence area tambang.',
                              icon: Icons.location_on_rounded,
                              iconColor: const Color(0xFFDC2626),
                              isGranted: _locationGranted,
                            ),
                            const SizedBox(height: 12),
                            _buildPermissionCard(
                              title: 'Kamera Foto Bukti Temuan',
                              desc: 'Wajib untuk mengambil foto temuan bahaya (Hazard), dokumentasi inspeksi lapangan, dan scan QR code badge.',
                              icon: Icons.camera_alt_rounded,
                              iconColor: const Color(0xFF2563EB),
                              isGranted: _cameraGranted,
                            ),
                            const SizedBox(height: 12),
                            _buildPermissionCard(
                              title: 'Notifikasi & Getar Bahaya',
                              desc: 'Wajib untuk mengirim sinyal getar darurat saat memasuki radius 20m dari temuan terbuka serta broadcast insiden.',
                              icon: Icons.notifications_active_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              isGranted: _notificationGranted,
                            ),
                            const SizedBox(height: 12),
                            _buildPermissionCard(
                              title: 'Penyimpanan & Media Offline',
                              desc: 'Diperlukan untuk menyimpan antrian data offline di pit dan mengunduh berkas laporan keselamatan SAP.',
                              icon: Icons.folder_special_rounded,
                              iconColor: const Color(0xFF059669),
                              isGranted: _storageGranted,
                            ),
                          ],
                        ),
                      ),

                      // Bagian Tombol Tindakan
                      if (_isPermanentlyDenied) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFDC2626), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Beberapa izin ditolak permanen. Buka pengaturan HP untuk mengaktifkan izin yang diperlukan.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => openAppSettings(),
                            icon: const Icon(Icons.settings_rounded, size: 18),
                            label: const Text('Buka Pengaturan HP'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: allGranted
                              ? _proceedToApp
                              : _requestAllPermissions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allGranted
                                ? const Color(0xFF059669)
                                : const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: (allGranted
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF2563EB))
                                .withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allGranted
                                    ? Icons.check_circle_rounded
                                    : Icons.verified_user_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                allGranted
                                    ? 'Semua Izin Siap • Masuk Aplikasi'
                                    : 'Izinkan Semua Akses Aplikasi',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color iconColor,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGranted ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          width: isGranted ? 1.5 : 1.0,
        ),
        boxShadow: isGranted
            ? [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFFECFDF5)
                  : iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isGranted ? const Color(0xFF059669) : iconColor,
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
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isGranted
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isGranted
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGranted ? Icons.check_circle : Icons.circle_outlined,
                            size: 11,
                            color: isGranted
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3.5),
                          Text(
                            isGranted ? 'Diizinkan' : 'Wajib',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isGranted
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.35,
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
