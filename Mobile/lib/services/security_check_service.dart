import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class SecurityStatus {
  final bool isVpnActive;
  final bool isMockGps;
  final String? vpnInterfaceName;
  final Position? position;

  const SecurityStatus({
    required this.isVpnActive,
    required this.isMockGps,
    this.vpnInterfaceName,
    this.position,
  });

  bool get hasViolation => isVpnActive || isMockGps;
}

class SecurityCheckService {
  static final SecurityCheckService instance = SecurityCheckService._internal();
  factory SecurityCheckService() => instance;
  SecurityCheckService._internal();

  static const MethodChannel _platform = MethodChannel('id.indexim.mbs/security');

  /// Status apakah dialog pemblokiran sedang aktif tampil di layar
  static bool isDialogOpen = false;

  /// Periksa apakah VPN sedang aktif (Native Android + Connectivity + NetworkInterface)
  Future<Map<String, dynamic>> checkVpn() async {
    bool vpnDetected = false;
    String? interfaceDetected;

    // 1. Cek Native Android NetworkCapabilities TRANSPORT_VPN
    try {
      final nativeVpn = await _platform.invokeMethod<bool>('checkVpnNative');
      if (nativeVpn == true) {
        vpnDetected = true;
        interfaceDetected = 'Android System: Active VPN';
      }
    } catch (_) {}

    // 2. Cek via connectivity_plus
    if (!vpnDetected) {
      try {
        final connectivityList = await Connectivity().checkConnectivity();
        if (connectivityList.contains(ConnectivityResult.vpn)) {
          vpnDetected = true;
          interfaceDetected = 'ConnectivityService: VPN';
        }
      } catch (_) {}
    }

    // 3. Cek via NetworkInterface tun/ppp/tap/vpn/wg
    if (!vpnDetected) {
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.any,
        );
        for (var iface in interfaces) {
          final name = iface.name.toLowerCase();
          if (name.contains('tun') ||
              name.contains('ppp') ||
              name.contains('tap') ||
              name.contains('vpn') ||
              name.contains('wg')) {
            vpnDetected = true;
            interfaceDetected = iface.name;
            break;
          }
        }
      } catch (_) {}
    }

    return {
      'isVpn': vpnDetected,
      'interface': interfaceDetected,
    };
  }

  /// Periksa apakah Fake GPS (Mock Location) sedang digunakan pada perangkat
  Future<bool> checkMockLocation([Position? pos]) async {
    try {
      if (pos != null) {
        return pos.isMocked;
      }
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && lastPos.isMocked) {
        return true;
      }
      final currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );
      return currentPos.isMocked;
    } catch (_) {}
    return false;
  }

  /// Buka menu Pengaturan VPN perangkat
  static Future<void> openVpnSettings() async {
    try {
      final opened = await _platform.invokeMethod<bool>('openVpnSettings');
      if (opened != true) {
        await openAppSettings();
      }
    } catch (_) {
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  /// Buka menu Opsi Pengembang / Pengaturan Lokasi untuk mematikan Fake GPS
  static Future<void> openDeveloperSettings() async {
    try {
      final opened = await _platform.invokeMethod<bool>('openDeveloperSettings');
      if (opened != true) {
        await Geolocator.openLocationSettings();
      }
    } catch (_) {
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
    }
  }

  /// Jalankan audit keamanan penuh terhadap VPN dan Fake GPS
  Future<SecurityStatus> runFullAudit([Position? livePosition]) async {
    final vpnResult = await checkVpn();
    final isMock = await checkMockLocation(livePosition);

    return SecurityStatus(
      isVpnActive: vpnResult['isVpn'] == true,
      vpnInterfaceName: vpnResult['interface'] as String?,
      isMockGps: isMock,
      position: livePosition,
    );
  }

  /// Munculkan pop-up pemblokiran jika terdeteksi pelanggaran (VPN atau Fake GPS).
  /// Pop-up TIDAK BISA DITUTUP sampai kedua layanan tersebut dinonaktifkan!
  static Future<bool> checkAndShowIfViolation(
    BuildContext context, {
    Position? position,
    VoidCallback? onCleared,
  }) async {
    if (isDialogOpen) return false;

    final status = await SecurityCheckService.instance.runFullAudit(position);
    if (status.hasViolation && context.mounted) {
      await showBlockingSecurityDialog(
        context,
        initialStatus: status,
        onCleared: onCleared,
      );
      return true;
    }
    return false;
  }

  /// Menampilkan Pop-Up Pemblokiran VPN & Fake GPS (Modal Terkunci)
  static Future<void> showBlockingSecurityDialog(
    BuildContext context, {
    required SecurityStatus initialStatus,
    VoidCallback? onCleared,
  }) async {
    if (isDialogOpen) return;
    isDialogOpen = true;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    if (!context.mounted) {
      isDialogOpen = false;
      return;
    }

    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Tidak bisa ditutup dengan klik luar
        builder: (ctx) {
          return PopScope(
            canPop: false, // Tidak bisa ditutup dengan tombol Back
            child: _SecurityBlockingDialogContent(
              initialStatus: initialStatus,
              onCleared: onCleared,
            ),
          );
        },
      );
    } finally {
      isDialogOpen = false;
    }
  }
}

class _SecurityBlockingDialogContent extends StatefulWidget {
  final SecurityStatus initialStatus;
  final VoidCallback? onCleared;

  const _SecurityBlockingDialogContent({
    required this.initialStatus,
    this.onCleared,
  });

  @override
  State<_SecurityBlockingDialogContent> createState() =>
      _SecurityBlockingDialogContentState();
}

class _SecurityBlockingDialogContentState
    extends State<_SecurityBlockingDialogContent> with WidgetsBindingObserver {
  late SecurityStatus _currentStatus;
  bool _isChecking = false;
  String? _feedbackMessage;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;
    WidgetsBinding.instance.addObserver(this);

    // Otomatis re-check setiap 2.5 detik (misal saat user matikan VPN dari status bar)
    _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted && !_isChecking) {
        _runAuditSilently();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isChecking) {
      _runAuditSilently();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _runAuditSilently() async {
    final status = await SecurityCheckService.instance.runFullAudit();
    if (!mounted) return;

    if (!status.hasViolation) {
      // Pelanggaran telah tuntas/dimatikan! Tutup popup dan izinkan akses.
      HapticFeedback.mediumImpact();
      if (widget.onCleared != null) widget.onCleared!();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Integritas K3 Terpenuhi: VPN & Fake GPS telah dinonaktifkan.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _currentStatus = status;
      });
    }
  }

  Future<void> _manualRecheck() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isChecking = true;
      _feedbackMessage = null;
    });

    final status = await SecurityCheckService.instance.runFullAudit();
    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _currentStatus = status;
    });

    if (!status.hasViolation) {
      HapticFeedback.mediumImpact();
      if (widget.onCleared != null) widget.onCleared!();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses Dibuka: VPN dan Fake GPS telah berhasil dimatikan.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        if (status.isVpnActive && status.isMockGps) {
          _feedbackMessage = 'VPN dan Fake GPS masih terdeteksi aktif!';
        } else if (status.isVpnActive) {
          _feedbackMessage = 'Layanan VPN masih terdeteksi aktif!';
        } else {
          _feedbackMessage = 'Aplikasi Fake GPS / Mock Location masih aktif!';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Alert Berwarna Merah Kritis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.gpp_bad_rounded,
                        color: Color(0xFFFEF08A),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'AKSES DIBLOKIR: INTEGRITAS K3',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dilarang Menggunakan VPN atau Fake GPS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Isi Konten & Status Deteksi Real-Time
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Real-Time Status Cards
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            // Status VPN
                            Row(
                              children: [
                                Icon(
                                  status.isVpnActive
                                      ? Icons.cancel_rounded
                                      : Icons.check_circle_rounded,
                                  size: 18,
                                  color: status.isVpnActive
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status.isVpnActive
                                        ? 'Layanan VPN: TERDETEKSI AKTIF (${status.vpnInterfaceName ?? "VPN Protocol"})'
                                        : 'Layanan VPN: Nonaktif (Aman)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: status.isVpnActive
                                          ? const Color(0xFF991B1B)
                                          : const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Color(0xFFFEE2E2)),
                            // Status Fake GPS
                            Row(
                              children: [
                                Icon(
                                  status.isMockGps
                                      ? Icons.cancel_rounded
                                      : Icons.check_circle_rounded,
                                  size: 18,
                                  color: status.isMockGps
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status.isMockGps
                                        ? 'Fake GPS: TERDETEKSI AKTIF (Mock Location)'
                                        : 'Lokasi GPS: Riil Tambang (Valid)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: status.isMockGps
                                          ? const Color(0xFF991B1B)
                                          : const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (_feedbackMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _feedbackMessage!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Penjelasan Aturan K3
                      _buildRuleBullet(
                        icon: Icons.wrong_location_rounded,
                        title: '1. Larangan Fake GPS (Mock Location)',
                        desc:
                            'SafeMap, Geofence Radar 20m, dan inspeksi K3LH wajib menggunakan koordinat GPS riil lapangan tambang. Dilarang menggunakan aplikasi pemalsu lokasi.',
                      ),
                      const SizedBox(height: 10),
                      _buildRuleBullet(
                        icon: Icons.vpn_lock_rounded,
                        title: '2. Larangan Menggunakan Layanan VPN',
                        desc:
                            'VPN dapat memanipulasi rute jaringan dan mengganggu verifikasi server operasional PT Indexim Coalindo. Harap putuskan koneksi VPN sekarang.',
                      ),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aplikasi terkunci sampai VPN dan Fake GPS dimatikan dari perangkat Anda.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tombol-Tombol Aksi
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  children: [
                    // Tombol 1: Periksa Ulang Sekarang
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _manualRecheck,
                        icon: _isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isChecking ? 'Memeriksa Sistem...' : 'Periksa Ulang & Buka Akses',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tombol 2: Buka Pengaturan VPN / GPS
                    Row(
                      children: [
                        if (status.isVpnActive)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: SecurityCheckService.openVpnSettings,
                              icon: const Icon(Icons.settings_ethernet_rounded, size: 14),
                              label: const Text('Setelan VPN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        if (status.isVpnActive && status.isMockGps) const SizedBox(width: 8),
                        if (status.isMockGps)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: SecurityCheckService.openDeveloperSettings,
                              icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                              label: const Text('Setelan GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Tombol 3: Keluar Aplikasi
                    TextButton.icon(
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                      icon: const Icon(Icons.exit_to_app_rounded, size: 14, color: Color(0xFF64748B)),
                      label: const Text(
                        'Keluar dari Aplikasi',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleBullet({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFFDC2626)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF475569),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
