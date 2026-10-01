import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

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

  /// Periksa apakah VPN sedang aktif (via connectivity_plus & NetworkInterface tun/ppp/tap/vpn)
  Future<Map<String, dynamic>> checkVpn() async {
    bool vpnDetected = false;
    String? interfaceDetected;

    try {
      final connectivityList = await Connectivity().checkConnectivity();
      if (connectivityList.contains(ConnectivityResult.vpn)) {
        vpnDetected = true;
        interfaceDetected = 'ConnectivityService: VPN';
      }
    } catch (_) {}

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
              name.contains('p2p') ||
              name.contains('tap') ||
              name.contains('vpn')) {
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
      final currentPos = await Geolocator.getLastKnownPosition();
      if (currentPos != null) {
        return currentPos.isMocked;
      }
    } catch (_) {}
    return false;
  }

  /// Status apakah dialog peringatan sedang aktif tampil di layar
  static bool isDialogOpen = false;

  /// Jalankan audit keamanan penuh
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

  /// HANYA munculkan dialog jika terdeteksi pelanggaran (VPN atau Mock Location)
  static Future<bool> checkAndShowIfViolation(
    BuildContext context, {
    Position? position,
    VoidCallback? onDismiss,
  }) async {
    if (isDialogOpen) return false;

    final status = await SecurityCheckService.instance.runFullAudit(position);
    if (status.hasViolation && context.mounted) {
      await showSecurityWarningDialog(
        context,
        forceAlert: true,
        currentStatus: status,
        onDismiss: onDismiss,
      );
      return true;
    }
    return false;
  }

  /// Menampilkan Pop-Up Peringatan VPN & Fake GPS
  static Future<void> showSecurityWarningDialog(
    BuildContext context, {
    bool forceAlert = false,
    SecurityStatus? currentStatus,
    VoidCallback? onDismiss,
  }) async {
    if (isDialogOpen) return;
    isDialogOpen = true;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final status = currentStatus ?? await SecurityCheckService.instance.runFullAudit();

    if (!context.mounted) {
      isDialogOpen = false;
      return;
    }

    try {
      await showDialog(
        context: context,
        barrierDismissible: !forceAlert,
        builder: (ctx) {
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
                  // Header Alert Berwarna Merah-Oranye Gradien
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: status.hasViolation
                            ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
                            : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
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
                          child: Icon(
                            status.hasViolation
                                ? Icons.warning_rounded
                                : Icons.shield_rounded,
                            color: status.hasViolation
                                ? const Color(0xFFFEF08A)
                                : const Color(0xFF38BDF8),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'PERINGATAN INTEGRITAS K3',
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
                          'Larangan Penggunaan Fake GPS & VPN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Isi Konten Edukasi & Deteksi Real-Time
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Real-Time Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: status.hasViolation
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: status.hasViolation
                                    ? const Color(0xFFFECACA)
                                    : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Column(
                              children: [
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
                                            ? 'Fake GPS / Mock Location: TERDETEKSI AKTIF!'
                                            : 'Lokasi GPS: Asli / Valid (Normal)',
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
                                const SizedBox(height: 6),
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
                                            ? 'Koneksi VPN: TERDETEKSI AKTIF (${status.vpnInterfaceName ?? "VPN"})!'
                                            : 'Koneksi Internet: Langsung / Resmi (Tanpa VPN)',
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
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Butir 1: Fake GPS
                          _buildRuleItem(
                            icon: Icons.wrong_location_rounded,
                            iconColor: const Color(0xFFDC2626),
                            title: '1. Dilarang Menggunakan Fake GPS (Mock Location)',
                            desc:
                                'SafeMap, Radar 20m Geofence, dan penutupan temuan bahaya K3 wajib menggunakan koordinat GPS riil lapangan tambang. Manipulasi lokasi merupakan pelanggaran integritas data keselamatan kerja.',
                          ),

                          const SizedBox(height: 12),

                          // Butir 2: VPN
                          _buildRuleItem(
                            icon: Icons.vpn_lock_rounded,
                            iconColor: const Color(0xFFD97706),
                            title: '2. Dilarang Menggunakan Layanan VPN',
                            desc:
                                'VPN dapat mengaburkan rute jaringan, menghambat verifikasi server operasional, dan mengganggu pelaporan darurat. Harap matikan VPN selama menggunakan aplikasi Indexsafe Evolution.',
                          ),

                          const SizedBox(height: 12),

                          // Catatan Kepatuhan PT Indexim
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 15, color: Color(0xFF64748B)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Sistem secara berkala mencatat integritas GPS & jaringan ke log kepatuhan operasional K3.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w500,
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

                  // Tombol Aksi
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (onDismiss != null) onDismiss();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status.hasViolation
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          status.hasViolation
                              ? 'Saya Mengerti, Matikan VPN / Fake GPS'
                              : 'Saya Mengerti & Patuhi Aturan K3',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
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
      },
    );
  } finally {
    isDialogOpen = false;
  }
}

  static Widget _buildRuleItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
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
