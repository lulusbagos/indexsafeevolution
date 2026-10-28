import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import '../services/preference.dart';
import 'login_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Pindai QR, 1: Daftar Acara
  final ApiService _api = ApiService();

  // Camera & Scanner State
  MobileScannerController? _scannerController;
  bool _hasCameraPermission = false;
  bool _isPermissionChecking = true;
  bool _isTorchOn = false;
  bool _isProcessingScan = false;
  double _zoomScale = 0.0; // 0.0 to 1.0
  final String _selectedScanTarget = 'auto'; // 'auto', 'permit', 'event', 'vehicle'

  // User Scan Permissions (from Web Admin)
  bool _canScanAcara = true;
  bool _canScanMinePermit = false;
  bool _canScanPermitPelanggaran = false;
  bool _canScanPermitKeluarMasuk = false;
  bool _canScanSimper = false;
  bool _canScanCommissioning = false;
  bool _canScanSpecialPermit = false;
  bool _canScanOther = false;

  // Event List State & Search
  bool _isLoadingEvents = false;
  List<Map<String, dynamic>> _events = [];
  String _eventFilter = 'all'; // 'all', 'today', 'ongoing', 'attended'
  String? _eventsErrorMessage;
  final TextEditingController _eventSearchCtrl = TextEditingController();
  String _eventSearchQuery = '';

  // Animation for laser scan line
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _checkPermissionAndInit();
    _loadMyPermissions();
    _loadEvents();
  }

  @override
  void dispose() {
    _eventSearchCtrl.dispose();
    _animController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndInit() async {
    setState(() => _isPermissionChecking = true);
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _initScanner();
      setState(() {
        _hasCameraPermission = true;
        _isPermissionChecking = false;
      });
    } else {
      final req = await Permission.camera.request();
      if (req.isGranted) {
        _initScanner();
        setState(() {
          _hasCameraPermission = true;
          _isPermissionChecking = false;
        });
      } else {
        setState(() {
          _hasCameraPermission = false;
          _isPermissionChecking = false;
        });
      }
    }
  }

  void _initScanner() {
    _scannerController?.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  Future<void> _loadMyPermissions() async {
    final res = await _api.getMyScanPermissions();
    if (!mounted) return;
    res.fold(
      (_) {},
      (data) {
        setState(() {
          _canScanAcara = data['can_scan_acara'] ?? true;
          _canScanMinePermit = data['can_scan_minepermit'] ?? false;
          _canScanPermitPelanggaran = data['can_scan_permit_pelanggaran'] ?? false;
          _canScanPermitKeluarMasuk = data['can_scan_permit_keluar_masuk'] ?? false;
          _canScanSimper = data['can_scan_simper'] ?? false;
          _canScanCommissioning = data['can_scan_commissioning'] ?? false;
          _canScanSpecialPermit = data['can_scan_special_permit'] ?? false;
          _canScanOther = data['can_scan_other'] ?? false;
        });
      },
    );
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEvents = true;
      _eventsErrorMessage = null;
    });

    final res = await _api.getAttendanceEvents();
    if (!mounted) return;

    res.fold(
      (err) {
        setState(() {
          _isLoadingEvents = false;
          _eventsErrorMessage = err['message']?.toString() ?? 'Gagal memuat daftar acara.';
        });
      },
      (data) {
        final list = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() {
          _events = list;
          _isLoadingEvents = false;
        });
      },
    );
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          return null;
        }
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {
      return null;
    }
  }

  int? _extractDaysLeft(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['days_left'];
    if (raw is num) return raw.toInt();
    if (raw != null) {
      final p = int.tryParse(raw.toString());
      if (p != null) return p;
    }

    final dateCandidates = [
      data['masa_aktif_permit'],
      data['simper_masa_berlaku'],
      data['masa_berlaku'],
      data['berakhir_kerja'],
    ];

    for (final candidate in dateCandidates) {
      if (candidate == null) continue;
      final str = candidate.toString().trim();
      if (str.isEmpty || str == '-') continue;
      try {
        DateTime? dt;
        if (str.contains('-')) {
          final p = str.split('-');
          if (p.length == 3) {
            if (p[0].length == 4) {
              dt = DateTime.tryParse(str);
            } else {
              dt = DateTime.tryParse('${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}');
            }
          }
        } else if (str.contains('/')) {
          final p = str.split('/');
          if (p.length == 3) {
            if (p[2].length == 4) {
              dt = DateTime.tryParse('${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}');
            }
          }
        }
        if (dt != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final target = DateTime(dt.year, dt.month, dt.day);
          return target.difference(today).inDays;
        }
      } catch (_) {}
    }
    return null;
  }

  int? _extractSimperDaysLeft(Map<String, dynamic>? data) {
    if (data == null) return null;
    if (data['has_simper'] != true && (data['simper_nomor'] == null || data['simper_nomor'] == '-')) {
      return null;
    }
    final raw = data['simper_days_left'];
    if (raw is num) return raw.toInt();
    if (raw != null) {
      final p = int.tryParse(raw.toString());
      if (p != null) return p;
    }

    final rawDate = data['simper_masa_berlaku']?.toString() ?? '';
    if (rawDate.isNotEmpty && rawDate != '-') {
      try {
        DateTime? dt;
        if (rawDate.contains('-')) {
          final p = rawDate.split('-');
          if (p.length == 3) {
            if (p[0].length == 4) {
              dt = DateTime.tryParse(rawDate);
            } else {
              dt = DateTime.tryParse('${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}');
            }
          }
        } else if (rawDate.contains('/')) {
          final p = rawDate.split('/');
          if (p.length == 3) {
            if (p[2].length == 4) {
              dt = DateTime.tryParse('${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}');
            }
          }
        }
        if (dt != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final target = DateTime(dt.year, dt.month, dt.day);
          return target.difference(today).inDays;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _triggerWarningVibration() async {
    try {
      // 3 getaran berurutan yang terasa jelas di perangkat fisik (pattern peringatan K3)
      for (int i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await HapticFeedback.vibrate();
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    } catch (_) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  Future<void> _onDetectQr(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.trim().isEmpty) {
      return;
    }

    final rawCode = barcode.rawValue!.trim();
    setState(() => _isProcessingScan = true);
    HapticFeedback.mediumImpact();

    // Hentikan camera sementara agar tidak frame-spam atau freeze di latar belakang
    await _scannerController?.stop();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    Position? pos;
    try {
      pos = await _getCurrentLocation();
    } catch (_) {}

    final res = await _api.scanAttendanceQr(
      code: rawCode,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
      accuracy: pos?.accuracy,
      scanType: _getScanTypeParam(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    await res.fold(
      (err) async {
        final errMsg = err['message']?.toString() ?? 'QR tidak valid atau server bermasalah.';
        final isAuth = err['isAuthError'] == true || errMsg.toLowerCase().contains('sesi login') || errMsg.toLowerCase().contains('401');
        await _showResultDialog(
          isSuccess: false,
          title: 'Pemindaian Belum Berhasil',
          message: errMsg,
          actionType: isAuth ? 'AuthError' : 'Error',
        );
      },
      (data) async {
        final isSuccess = data['status'] == true;
        final msg = data['message']?.toString() ?? '';
        final actionType = data['actionType']?.toString() ?? 'Attendance';
        final payload = data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : null;

        // Cek apakah masa aktif permit / SIMPER kurang dari 30 hari atau sudah kadaluarsa
        if (isSuccess && payload != null && (actionType == 'MinePermit' || actionType == 'Simper')) {
          final daysLeft = _extractDaysLeft(payload);
          final bool hasSimper = payload['has_simper'] == true;
          final simperDaysLeft = hasSimper ? _extractSimperDaysLeft(payload) : null;

          final bool isPermitExpired = daysLeft != null && daysLeft < 0;
          final bool isSimperExpired = hasSimper && simperDaysLeft != null && simperDaysLeft < 0;
          final bool isExpired = payload['is_expired'] == true || isPermitExpired || isSimperExpired;

          // HANYA getar jika masa aktif permit <= 30 hari atau SIMPER aktif <= 30 hari
          final bool isPermitWarning30Days = daysLeft != null && daysLeft <= 30 && daysLeft >= 0;
          final bool isSimperWarning30Days = hasSimper && simperDaysLeft != null && simperDaysLeft <= 30 && simperDaysLeft >= 0;

          if (isExpired || isPermitWarning30Days || isSimperWarning30Days) {
            // Getarkan perangkat seketika saat terdeteksi masa aktif < 30 hari
            _triggerWarningVibration();
          }
        }

        if (actionType == 'MinePermit' && isSuccess && payload != null) {
          await _showResultDialog(
            isSuccess: true,
            title: 'Mine Permit Terverifikasi',
            message: msg.isNotEmpty ? msg : 'Data identitas karyawan & permit valid.',
            actionType: 'MinePermit',
            data: payload,
          );
        } else if (actionType == 'Simper' && isSuccess && payload != null) {
          await _showResultDialog(
            isSuccess: true,
            title: 'SIMPER Terverifikasi',
            message: msg.isNotEmpty ? msg : 'Data SIMPER & unit kewenangan valid.',
            actionType: 'Simper',
            data: payload,
          );
        } else if (actionType == 'Denied') {
          await _showResultDialog(
            isSuccess: false,
            title: 'Otorisasi Terbatas',
            message: msg,
            actionType: 'Denied',
            data: payload,
          );
        } else if (actionType == 'UnrecognizedQr' || actionType == 'General') {
          await _showResultDialog(
            isSuccess: false,
            title: payload?['is_url'] == true ? 'Tautan Web Terdeteksi' : 'Kode di Luar Sistem',
            message: msg,
            actionType: 'UnrecognizedQr',
            data: payload,
          );
        } else {
          await _showResultDialog(
            isSuccess: isSuccess,
            title: isSuccess
                ? (actionType == 'Vehicle'
                    ? 'Unit Kendaraan Ditemukan'
                    : 'Presensi Berhasil')
                : 'Informasi Pemindaian',
            message: msg,
            actionType: actionType,
            data: payload,
          );
        }

        // Refresh event list to update attendance state
        _loadEvents();
      },
    );

    // Setelah modal sheet ditutup (Back HP, tombol Tutup, atau swipe down):
    // Reset flag dan hidupkan kembali scanner kamera!
    if (mounted) {
      setState(() => _isProcessingScan = false);
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        await _scannerController?.start();
      }
    }
  }

  String _getScanTypeParam() {
    switch (_selectedScanTarget) {
      case 'permit':
        return 'Mine Permit';
      case 'event':
        return 'Absen Acara';
      case 'vehicle':
        return 'Vehicle';
      default:
        return 'Auto';
    }
  }

  Future<void> _showResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
    required String actionType,
    Map<String, dynamic>? data,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isAttendance = actionType == 'Attendance';
        final isMinePermit = actionType == 'MinePermit';
        final isSimper = actionType == 'Simper';
        final isVehicle = actionType == 'Vehicle';
        final isDenied = actionType == 'Denied';
        final isDuplicate = data?['is_duplicate'] == true;
        final isLate = data?['is_late'] == true;
        final eventName = data?['event_name']?.toString() ?? '';
        final eventLocation = data?['event_location']?.toString() ?? '';
        final attendeeName = data?['attendee_name']?.toString() ?? data?['nama']?.toString() ?? '';
        final attendeeNik = data?['attendee_nik']?.toString() ?? data?['nik']?.toString() ?? '';
        final scanTime = data?['scan_at']?.toString() ?? data?['recorded_at']?.toString() ?? '';

        Color primaryColor;
        IconData iconData;
        String statusBadgeText;

        final daysLeft = _extractDaysLeft(data);
        final bool hasSimper = data?['has_simper'] == true;
        final simperDaysLeft = hasSimper ? _extractSimperDaysLeft(data) : null;

        final bool isPermitExpired = daysLeft != null && daysLeft < 0;
        final bool isSimperExpired = hasSimper && simperDaysLeft != null && simperDaysLeft < 0;
        final isExpiredPermit = (isMinePermit || isSimper) &&
            (data?['is_expired'] == true || isPermitExpired || isSimperExpired);

        final bool isPermitExpiring = daysLeft != null && daysLeft <= 30 && daysLeft >= 0;
        final bool isSimperExpiring = hasSimper && simperDaysLeft != null && simperDaysLeft <= 30 && simperDaysLeft >= 0;
        final bool isExpiringSoon = (isMinePermit || isSimper) &&
            !isExpiredPermit && (isPermitExpiring || isSimperExpiring);

        // Strict permissions from backend scan payload, falling back to local fetched state
        final bool canPelanggaran = data != null && data.containsKey('can_input_pelanggaran')
            ? (data['can_input_pelanggaran'] == true)
            : _canScanPermitPelanggaran;
        final bool canKeluarMasuk = data != null && data.containsKey('can_input_keluar_masuk')
            ? (data['can_input_keluar_masuk'] == true)
            : _canScanPermitKeluarMasuk;

        final isUnrecognized = actionType == 'UnrecognizedQr';

        if (isDenied) {
          primaryColor = const Color(0xFFD97706); // Warm Amber 600 - Elegan K3 Security
          iconData = Icons.admin_panel_settings_rounded;
          statusBadgeText = 'OTORISASI TERBATAS';
        } else if (isUnrecognized) {
          primaryColor = const Color(0xFF64748B); // Slate 500 - Informatif Luar Sistem
          iconData = data?['is_url'] == true ? Icons.language_rounded : Icons.qr_code_2_rounded;
          statusBadgeText = data?['is_url'] == true ? 'TAUTAN EKSTERNAL' : 'DI LUAR SISTEM';
        } else if (isMinePermit) {
          if (isExpiredPermit) {
            primaryColor = const Color(0xFFEF4444);
            iconData = Icons.warning_amber_rounded;
            statusBadgeText = isPermitExpired ? 'MINE PERMIT KADALUARSA' : 'SIMPER KADALUARSA';
          } else if (isExpiringSoon) {
            primaryColor = const Color(0xFFF59E0B); // Amber Warning K3
            iconData = Icons.warning_amber_rounded;
            if (isPermitExpiring) {
              statusBadgeText = 'MASA AKTIF < 30 HARI ($daysLeft HARI LAGI)';
            } else {
              statusBadgeText = 'SIMPER < 30 HARI ($simperDaysLeft HARI LAGI)';
            }
          } else {
            primaryColor = const Color(0xFF10B981);
            iconData = Icons.verified_user_rounded;
            statusBadgeText = 'MINE PERMIT AKTIF';
          }
        } else if (isSimper) {
          if (isExpiredPermit) {
            primaryColor = const Color(0xFFEF4444);
            iconData = Icons.warning_amber_rounded;
            statusBadgeText = 'SIMPER KADALUARSA';
          } else if (isExpiringSoon) {
            primaryColor = const Color(0xFFF59E0B); // Amber Warning K3
            iconData = Icons.warning_amber_rounded;
            final d = daysLeft ?? 0;
            statusBadgeText = 'MASA BERLAKU < 30 HARI ($d HARI LAGI)';
          } else {
            primaryColor = const Color(0xFF0D9488);
            iconData = Icons.drive_eta_rounded;
            statusBadgeText = 'SIMPER AKTIF';
          }
        } else if (isVehicle) {
          primaryColor = const Color(0xFFF59E0B);
          iconData = Icons.directions_car_filled_rounded;
          statusBadgeText = 'UNIT KENDARAAN TERDETEKSI';
        } else if (!isSuccess) {
          primaryColor = const Color(0xFFEF4444);
          iconData = Icons.cancel_rounded;
          statusBadgeText = 'GAGAL';
        } else if (isDuplicate) {
          primaryColor = const Color(0xFF0284C7);
          iconData = Icons.info_rounded;
          statusBadgeText = 'SUDAH TERCATAT';
        } else if (isLate) {
          primaryColor = const Color(0xFFF59E0B);
          iconData = Icons.access_time_filled_rounded;
          statusBadgeText = 'TERLAMBAT (TOLERANSI)';
        } else {
          primaryColor = const Color(0xFF10B981);
          iconData = Icons.check_circle_rounded;
          statusBadgeText = 'TEPAT WAKTU';
        }

        final bottomPadding = MediaQuery.of(ctx).padding.bottom;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 24),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Indicator
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),

                // Status Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 40, color: primaryColor),
                ),
                const SizedBox(height: 14),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withValues(alpha: .3), width: 1.2),
                  ),
                  child: Text(
                    statusBadgeText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Warning Banner jika masa aktif < 30 hari atau kadaluarsa (Perangkat Bergetar)
                if (isExpiringSoon || isExpiredPermit) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: (isExpiredPermit ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (isExpiredPermit ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: .35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpiredPermit ? Icons.cancel_rounded : Icons.vibration_rounded,
                          size: 22,
                          color: isExpiredPermit ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isExpiredPermit
                                ? 'Peringatan: Masa aktif permit atau SIMPER telah KADALUARSA! Harap segera perpanjang.'
                                : (isPermitExpiring
                                    ? 'Peringatan Getar: Masa aktif Mine Permit tersisa $daysLeft hari (< 30 hari). Segera lakukan perpanjangan izin kerja!'
                                    : 'Peringatan Getar: Masa berlaku SIMPER tersisa $simperDaysLeft hari (< 30 hari). Segera perpanjang SIMPER!'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isExpiredPermit ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Detail Card if attendance event
                if (isAttendance && eventName.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.event_note_rounded, size: 18, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                eventName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (eventLocation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  eventLocation,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 22, color: Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Peserta', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                const SizedBox(height: 2),
                                Text(
                                  attendeeName.isNotEmpty ? attendeeName : 'Saya',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                ),
                                if (attendeeNik.isNotEmpty)
                                  Text('NIK: $attendeeNik', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                            if (scanTime.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Waktu Presensi', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDateTime(scanTime),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Detail Card if Mine Permit
                if (isMinePermit && data != null) ...[
                  _buildMinePermitResultCard(data),
                  const SizedBox(height: 22),
                ],

                // Detail Card if SIMPER
                if (isSimper && data != null) ...[
                  _buildSimperResultCard(data),
                  const SizedBox(height: 22),
                ],

                // Detail Card if Vehicle Unit
                if (isVehicle && data != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              data['no_lambung']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('COMMISSIONING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Jenis Unit', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                Text(data['jenis']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Merek', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                Text(data['merek']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Detail Card if Denied (Otorisasi Terbatas)
                if (isDenied) ...[
                  _buildDeniedCard(data),
                  const SizedBox(height: 22),
                ],

                // Detail Card if Unrecognized / External QR (Di Luar Sistem)
                if (isUnrecognized) ...[
                  _buildUnrecognizedQrCard(data),
                  const SizedBox(height: 22),
                ],

                // Actions for Mine Permit & SIMPER
                if ((isMinePermit || isSimper) && data != null) ...[
                  if (_canScanPermitPelanggaran && data['hierarchy_violation_allowed'] == false) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['hierarchy_restriction_reason']?.toString() ??
                                  'Otorisasi Terbatas: Tidak dapat mencatat pelanggaran terhadap karyawan perusahaan induk (Parent Company).',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), height: 1.35, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (canKeluarMasuk && canPelanggaran) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showInputGateLogSheet(data);
                            },
                            icon: const Icon(Icons.door_sliding_outlined, size: 18),
                            label: const Text(
                              'Keluar Masuk',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showInputViolationSheet(data);
                            },
                            icon: const Icon(Icons.report_problem_rounded, size: 18),
                            label: const Text(
                              'Pelanggaran K3',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else if (canKeluarMasuk) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showInputGateLogSheet(data);
                        },
                        icon: const Icon(Icons.door_sliding_outlined, size: 19),
                        label: const Text(
                          'Input Keluar Masuk',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (canPelanggaran) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showInputViolationSheet(data);
                        },
                        icon: const Icon(Icons.report_problem_rounded, size: 19),
                        label: const Text(
                          'Catat Pelanggaran K3',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _scannerController?.start();
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text(
                            'Pindai Lagi',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (actionType == 'Attendance') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedTab = 1); // Buka tab acara
                          },
                          child: const Text(
                            'Lihat Acara',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ] else if (actionType == 'AuthError') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await PreferenceService.removeAuth();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Login Ulang', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _scannerController?.start();
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text('Pindai Ulang', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeniedCard(Map<String, dynamic>? data) {
    final module = data?['module']?.toString() ?? 'Modul K3 Terbatas';
    final perm = data?['required_permission']?.toString() ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: .15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Otorisasi Keamanan Akses K3',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFFDE68A)),
          const SizedBox(height: 12),
          const Text(
            'Petunjuk Permohonan Akses:',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fitur pemindaian ini memerlukan wewenang verifikasi operasional. Hubungi Administrator HSE/K3 atau Pengawas Departemen Anda untuk mengaktifkan izin akun Anda di menu Manajemen User Scan.',
            style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.45),
          ),
          if (perm != '-') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 12, color: Color(0xFFB45309)),
                  const SizedBox(width: 5),
                  Text(
                    'Izin Terkait: $perm',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF78350F), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnrecognizedQrCard(Map<String, dynamic>? data) {
    final rawContent = data?['raw_content']?.toString() ?? '-';
    final category = data?['category']?.toString() ?? 'Kode Di Luar Sistem';
    final hint = data?['hint']?.toString() ?? 'Pastikan Anda memindai kode QR resmi operasional PT Indexim Coalindo.';
    final isUrl = data?['is_url'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isUrl ? Icons.language_rounded : Icons.qr_code_2_rounded,
                    size: 17,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: rawContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Isi kode berhasil disalin ke clipboard.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: Color(0xFF0284C7)),
                      SizedBox(width: 3),
                      Text(
                        'Salin',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              rawContent,
              style: const TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: Color(0xFF1E293B),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.35),
                ),
              ),
            ],
          ),
          if (isUrl) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final uri = Uri.tryParse(rawContent);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text(
                  'Buka Tautan di Browser',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMinePermitResultCard(Map<String, dynamic> data) {
    final nomor = data['nomor']?.toString() ?? '-';
    final nama = data['nama']?.toString() ?? '-';
    final nik = data['nik']?.toString() ?? '-';
    final perusahaan = data['perusahaan']?.toString() ?? '-';
    final departemen = data['departemen']?.toString() ?? '-';
    final jabatan = (data['jabatan']?.toString() ?? data['posisi']?.toString() ?? '-').trim();
    final tanggal = data['tanggal']?.toString() ?? '-';
    final masaAktif = data['masa_aktif_permit']?.toString() ?? '-';
    final berakhirKerja = data['berakhir_kerja']?.toString() ?? '-';
    final pengajuan = data['pengajuan']?.toString() ?? 'REGULER';
    final status = data['status']?.toString() ?? 'PRINTED';
    final daysLeft = _extractDaysLeft(data) ??
        (data['days_left'] is int
            ? data['days_left'] as int
            : int.tryParse(data['days_left']?.toString() ?? '0') ?? 0);
    final isExpired = data['is_expired'] == true || daysLeft < 0;
    final isWarning = !isExpired && daysLeft <= 30;
    final rawAkses = data['akses_lokasi']?.toString() ?? '';
    final zones = rawAkses
        .split(RegExp(r'[,;|\s]+'))
        .map((z) => z.trim())
        .where((z) => z.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExpired
              ? const Color(0xFFEF4444)
              : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired
                    ? const Color(0xFFEF4444)
                    : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF0284C7)))
                .withValues(alpha: .28),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Mine Badge & Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isExpired
                    ? [const Color(0xFF991B1B), const Color(0xFF7F1D1D)]
                    : (isWarning
                        ? [const Color(0xFFB45309), const Color(0xFF92400E)]
                        : [const Color(0xFF065F46), const Color(0xFF047857)]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: isExpired
                      ? const Color(0xFFFCA5A5)
                      : (isWarning ? const Color(0xFFFCD34D) : const Color(0xFF34D399)),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isExpired
                            ? Icons.warning_rounded
                            : (isWarning ? Icons.notification_important_rounded : Icons.verified_user_rounded),
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          perusahaan.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    isExpired
                        ? 'EXPIRED'
                        : (isWarning ? '< 30 HARI' : status.toUpperCase()),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nomor Permit Badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0EA5E9), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 19, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Text(
                            nomor.isNotEmpty && nomor != '-' ? nomor : 'NO PERMIT TIDAK TERDATA',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                        ),
                        child: Text(
                          pengajuan,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Employee Identity with Real Photo & Zoom Preview
                Builder(
                  builder: (context) {
                    final photoUrl = data['photo_url']?.toString() ?? '';
                    final fullPhotoUrl = photoUrl.startsWith('http')
                        ? photoUrl
                        : photoUrl.isNotEmpty
                            ? '${_api.baseUrl}$photoUrl'
                            : '';
                    final noHp = data['no_hp']?.toString() ?? '-';
                    final email = data['email']?.toString() ?? '-';
                    final gender = data['jenis_kelamin']?.toString() ?? '-';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Photo Squircle with tap to preview
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showPhotoPreviewDialog(
                                  context: context,
                                  photoUrl: fullPhotoUrl,
                                  name: nama,
                                  nik: nik,
                                  company: perusahaan,
                                  job: jabatan,
                                );
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isExpired
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF38BDF8),
                                        width: 2.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isExpired
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF38BDF8))
                                              .withValues(alpha: .35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: fullPhotoUrl.isNotEmpty
                                          ? Image.network(
                                              fullPhotoUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (ctx, child, loading) {
                                                if (loading == null) return child;
                                                return const Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFF38BDF8),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (ctx, error, stack) {
                                                return Center(
                                                  child: Text(
                                                    nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                                    style: const TextStyle(
                                                      fontSize: 26,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Center(
                                              child: Text(
                                                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  // Zoom badge hint
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3.5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0284C7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'NIK: $nik',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                      if (departemen.isNotEmpty && departemen != '-') ...[
                                        const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w900)),
                                        Flexible(
                                          child: Text(
                                            departemen,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFFF1F5F9), fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (jabatan.isNotEmpty && jabatan != '-') ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      jabatan,
                                      style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Contact & Gender Row if available
                        if ((noHp.isNotEmpty && noHp != '-') || (email.isNotEmpty && email != '-') || (gender.isNotEmpty && gender != '-')) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF475569)),
                            ),
                            child: Row(
                              children: [
                                if (noHp.isNotEmpty && noHp != '-') ...[
                                  const Icon(Icons.phone_iphone_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 5),
                                  Text(noHp, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 12),
                                ],
                                if (gender.isNotEmpty && gender != '-') ...[
                                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 4),
                                  Text(gender, style: const TextStyle(fontSize: 11.5, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 12),
                                ],
                                if (email.isNotEmpty && email != '-') ...[
                                  const Icon(Icons.mail_outline_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Masa Aktif & Validity Details Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF475569), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildPermitDateItem(
                              label: 'Tanggal Terbit',
                              value: _formatDateOnly(tanggal),
                              icon: Icons.event_available_rounded,
                              iconColor: const Color(0xFF38BDF8),
                            ),
                          ),
                          Container(width: 1, height: 38, color: const Color(0xFF475569)),
                          Expanded(
                            child: _buildPermitDateItem(
                              label: 'Masa Aktif Permit',
                              value: _formatDateOnly(masaAktif),
                              icon: isExpired ? Icons.event_busy_rounded : Icons.verified_rounded,
                              iconColor: isExpired ? const Color(0xFFEF4444) : const Color(0xFF34D399),
                              isHighlight: true,
                              highlightColor: isExpired ? const Color(0xFFEF4444) : const Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18, color: Color(0xFF475569)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isExpired
                                    ? Icons.timer_off_outlined
                                    : (isWarning ? Icons.notification_important_rounded : Icons.timer_outlined),
                                size: 15,
                                color: isExpired
                                    ? const Color(0xFFF87171)
                                    : (isWarning ? const Color(0xFFFBBF24) : const Color(0xFF34D399)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isExpired
                                    ? 'Kedaluwarsa (${daysLeft.abs()} hari lalu)'
                                    : (isWarning
                                        ? 'Sisa Masa Aktif: $daysLeft hari (Segera Habis)'
                                        : 'Sisa Masa Aktif: $daysLeft hari'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isExpired
                                      ? const Color(0xFFF87171)
                                      : (isWarning ? const Color(0xFFFBBF24) : const Color(0xFF34D399)),
                                ),
                              ),
                            ],
                          ),
                          if (berakhirKerja.isNotEmpty && berakhirKerja != '-')
                            Text(
                              'Kontrak: ${_formatDateOnly(berakhirKerja)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Connected SIMPER Section (if available)
                if (data['has_simper'] == true) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: data['is_simper_active'] == true
                            ? const Color(0xFF0EA5E9)
                            : const Color(0xFFEF4444),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.drive_eta_rounded, size: 17, color: Color(0xFF38BDF8)),
                                SizedBox(width: 6),
                                Text(
                                  'SIMPER TERDAFTAR',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (data['is_simper_active'] == true
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: .25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: data['is_simper_active'] == true
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                data['is_simper_active'] == true ? 'SIMPER AKTIF' : 'EXPIRED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: data['is_simper_active'] == true
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('No. SIMPER', style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    data['simper_nomor']?.toString() ?? '-',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Jenis SIM & No', style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${data['jenis_sim'] ?? '-'} (${data['nomor_sim'] ?? '-'})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 13, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 5),
                            Text(
                              'Masa Berlaku SIMPER: ${_formatDateOnly(data['simper_masa_berlaku']?.toString() ?? '-')}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Zonasi Akses Tambang - Desain Jelas, Informatif & Berstandar K3
                _buildZonasiAksesSection(zones),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimperResultCard(Map<String, dynamic> data) {
    final nomor = (data['nomor']?.toString() ?? data['simper_nomor']?.toString() ?? '-').trim();
    final nama = (data['nama']?.toString() ?? '-').trim();
    final nik = (data['employee_id']?.toString() ?? data['nik']?.toString() ?? '-').trim();
    final perusahaan = (data['perusahaan']?.toString() ?? 'PT INDEXIM COALINDO').trim();
    final departemen = (data['departemen']?.toString() ?? '-').trim();
    final jabatan = (data['jabatan']?.toString() ?? data['posisi']?.toString() ?? '-').trim();
    final jenisSimper = (data['jenis_simper']?.toString() ?? 'SIMPER').toUpperCase().trim();
    final jenisSim = (data['jenis_sim']?.toString() ?? '-').trim();
    final nomorSim = (data['nomor_sim']?.toString() ?? '-').trim();
    final masaBerlaku = (data['masa_berlaku']?.toString() ?? '-').trim();
    final expiredDate = (data['expired_date']?.toString() ?? '-').trim();
    final status = (data['status']?.toString() ?? 'PRINTED').trim();
    final kacamata = (data['kacamata']?.toString() ?? 'TIDAK').toUpperCase().trim();
    final bool wajibKacamata = kacamata.contains('WAJIB') || kacamata == 'YA';
    final nilaiTeori = data['nilai_teori'] != null ? data['nilai_teori'].toString() : '-';
    final nilaiPraktek = data['nilai_praktek'] != null ? data['nilai_praktek'].toString() : '-';
    final bool ketentuanHauling = data['ketentuan_hauling'] == true;
    final int daysLeft = _extractDaysLeft(data) ??
        (data['days_left'] is int
            ? data['days_left'] as int
            : int.tryParse(data['days_left']?.toString() ?? '0') ?? 0);
    final bool isExpired = data['is_expired'] == true || daysLeft < 0;
    final bool isWarning = !isExpired && daysLeft <= 30;

    final rawUnits = data['units'] as List? ?? data['simper_units'] as List? ?? [];
    final List<Map<String, dynamic>> units = rawUnits.map((u) {
      if (u is Map<String, dynamic>) return u;
      if (u is Map) return Map<String, dynamic>.from(u);
      return <String, dynamic>{};
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExpired
              ? const Color(0xFFEF4444)
              : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF0D9488)),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired
                    ? const Color(0xFFEF4444)
                    : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF0D9488)))
                .withValues(alpha: .28),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isExpired
                    ? [const Color(0xFF991B1B), const Color(0xFF7F1D1D)]
                    : (isWarning
                        ? [const Color(0xFFB45309), const Color(0xFF92400E)]
                        : [const Color(0xFF0F766E), const Color(0xFF115E59)]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: isExpired
                      ? const Color(0xFFFCA5A5)
                      : (isWarning ? const Color(0xFFFCD34D) : const Color(0xFF2DD4BF)),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isExpired
                            ? Icons.warning_rounded
                            : (isWarning ? Icons.notification_important_rounded : Icons.drive_eta_rounded),
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          perusahaan.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    isExpired
                        ? 'EXPIRED'
                        : (isWarning ? '< 30 HARI' : status.toUpperCase()),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nomor SIMPER Badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF134E4A).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF14B8A6), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_rounded, size: 19, color: Color(0xFF2DD4BF)),
                          const SizedBox(width: 8),
                          Text(
                            nomor.isNotEmpty && nomor != '-' ? nomor : 'NO SIMPER TIDAK TERDATA',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2DD4BF), width: 1),
                        ),
                        child: Text(
                          'SIMPER $jenisSimper',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2DD4BF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Employee Identity with Photo & Zoom Preview
                Builder(
                  builder: (context) {
                    final photoUrl = data['photo_url']?.toString() ?? data['foto']?.toString() ?? '';
                    final fullPhotoUrl = photoUrl.startsWith('http')
                        ? photoUrl
                        : photoUrl.isNotEmpty
                            ? '${_api.baseUrl}$photoUrl'
                            : '';
                    final noHp = data['no_hp']?.toString() ?? '-';
                    final email = data['email']?.toString() ?? '-';
                    final gender = data['jenis_kelamin']?.toString() ?? '-';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showPhotoPreviewDialog(
                                  context: context,
                                  photoUrl: fullPhotoUrl,
                                  name: nama,
                                  nik: nik,
                                  company: perusahaan,
                                  job: jabatan,
                                );
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isExpired
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF14B8A6),
                                        width: 2.2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: fullPhotoUrl.isNotEmpty
                                          ? Image.network(
                                              fullPhotoUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (ctx, child, loading) {
                                                if (loading == null) return child;
                                                return const Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFF14B8A6),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (ctx, error, stack) {
                                                return Center(
                                                  child: Text(
                                                    nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                                    style: const TextStyle(
                                                      fontSize: 26,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Center(
                                              child: Text(
                                                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isExpired ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        'NIK: $nik',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2DD4BF),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('•', style: TextStyle(color: Color(0xFF64748B))),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          departemen.toUpperCase(),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCBD5E1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    jabatan.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Contact Strip
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.phone_android_rounded, size: 12, color: Color(0xFF2DD4BF)),
                                  const SizedBox(width: 5),
                                  Text(noHp, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF2DD4BF)),
                                  const SizedBox(width: 4),
                                  Text(gender, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.email_outlined, size: 12, color: Color(0xFF2DD4BF)),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        email,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // SIM & Examination Detail Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      // SIM Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.credit_card_rounded, size: 16, color: Color(0xFF2DD4BF)),
                              const SizedBox(width: 6),
                              Text(
                                'SIM $jenisSim',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '($nomorSim)',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: wajibKacamata
                                  ? const Color(0xFFF59E0B).withValues(alpha: .18)
                                  : const Color(0xFF10B981).withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: wajibKacamata ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  wajibKacamata ? Icons.visibility_rounded : Icons.check_circle_outline_rounded,
                                  size: 11,
                                  color: wajibKacamata ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  wajibKacamata ? 'WAJIB KACAMATA' : 'BEBAS KACAMATA',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: wajibKacamata ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFF334155)),

                      // Validity & Scores Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildPermitDateItem(
                              label: 'Masa Berlaku SIMPER',
                              value: _formatDateOnly(masaBerlaku.isNotEmpty && masaBerlaku != '-' ? masaBerlaku : expiredDate),
                              icon: Icons.event_available_rounded,
                              iconColor: isExpired ? const Color(0xFFEF4444) : const Color(0xFF2DD4BF),
                              isHighlight: true,
                              highlightColor: isExpired ? const Color(0xFFEF4444) : const Color(0xFF2DD4BF),
                            ),
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFF334155)),
                          Expanded(
                            child: _buildPermitDateItem(
                              label: 'Masa Berlaku SIM',
                              value: _formatDateOnly(expiredDate.isNotEmpty && expiredDate != '-' ? expiredDate : masaBerlaku),
                              icon: Icons.verified_rounded,
                              iconColor: const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPermitDateItem(
                              label: 'Nilai Ujian',
                              value: 'Teori: $nilaiTeori • Praktek: $nilaiPraktek',
                              icon: Icons.fact_check_rounded,
                              iconColor: const Color(0xFFF59E0B),
                            ),
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFF334155)),
                          Expanded(
                            child: _buildPermitDateItem(
                              label: 'Jalur Hauling',
                              value: ketentuanHauling ? 'DIIJINKAN' : 'TIDAK DIIJINKAN',
                              icon: Icons.alt_route_rounded,
                              iconColor: ketentuanHauling ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Countdown strip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isExpired
                                  ? const Color(0xFFEF4444)
                                  : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF0D9488)))
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isExpired
                                    ? const Color(0xFFEF4444)
                                    : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF0D9488)))
                                .withValues(alpha: .3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isExpired
                                      ? Icons.cancel_outlined
                                      : (isWarning ? Icons.notification_important_rounded : Icons.timer_outlined),
                                  size: 13,
                                  color: isExpired
                                      ? const Color(0xFFEF4444)
                                      : (isWarning ? const Color(0xFFFBBF24) : const Color(0xFF2DD4BF)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isExpired
                                      ? 'Status SIMPER: Kadaluarsa'
                                      : (isWarning
                                          ? 'Sisa Masa Aktif: $daysLeft hari (Segera Habis)'
                                          : 'Sisa Masa Aktif: $daysLeft hari'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isExpired
                                        ? const Color(0xFFEF4444)
                                        : (isWarning ? const Color(0xFFFBBF24) : const Color(0xFF2DD4BF)),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Status: $status',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // DAFTAR UNIT & KEWENANGAN OPERASI (tb_simper_unit)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.commute_rounded, size: 15, color: Color(0xFF2DD4BF)),
                        const SizedBox(width: 6),
                        Text(
                          'KEWENANGAN OPERASI UNIT (${units.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF2DD4BF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (units.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Text(
                      'Tidak ada unit kendaraan / alat berat yang terdaftar pada SIMPER ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Column(
                    children: units.map((u) {
                      final unitName = (u['kendaraan']?.toString() ?? '-').toUpperCase().trim();
                      final kewenangan = (u['kewenangan']?.toString() ?? 'FULL').toUpperCase().trim();
                      final classification = (u['equipment_classification']?.toString() ?? u['equipment_type']?.toString() ?? 'UNIT').toUpperCase().trim();
                      final jamMin = u['jam_min'] ?? 0;
                      final jamAktual = u['jam_aktual'] ?? 0;

                      // Authority Badge Styling
                      Color badgeBg;
                      Color badgeBorder;
                      Color badgeText;
                      if (kewenangan == 'RESTRICTED') {
                        badgeBg = const Color(0xFF78350F).withValues(alpha: .5);
                        badgeBorder = const Color(0xFFF59E0B);
                        badgeText = const Color(0xFFFDE68A);
                      } else if (kewenangan == 'PROBATION') {
                        badgeBg = const Color(0xFF1E3A8A).withValues(alpha: .5);
                        badgeBorder = const Color(0xFF38BDF8);
                        badgeText = const Color(0xFFBAE6FD);
                      } else {
                        badgeBg = const Color(0xFF065F46).withValues(alpha: .5);
                        badgeBorder = const Color(0xFF10B981);
                        badgeText = const Color(0xFFA7F3D0);
                      }

                      // Unit Icon
                      IconData unitIcon = Icons.directions_car_rounded;
                      Color iconColor = const Color(0xFF2DD4BF);
                      final isHe = classification.contains('HEAVY') ||
                          unitName.contains('DOZER') ||
                          unitName.contains('EXCAVATOR') ||
                          unitName.contains('CRANE') ||
                          unitName.contains('LOADER') ||
                          unitName.contains('GRADER') ||
                          unitName.contains('TRUCK');
                      if (isHe) {
                        unitIcon = Icons.construction_rounded;
                        iconColor = const Color(0xFFF59E0B);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: iconColor.withValues(alpha: .3)),
                              ),
                              child: Icon(unitIcon, size: 20, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unitName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$classification • Min: $jamMin Jam | Aktual: $jamAktual Jam',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: badgeBorder, width: 1.2),
                              ),
                              child: Text(
                                kewenangan,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: badgeText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermitDateItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isHighlight ? (highlightColor ?? Colors.white) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonasiAksesSection(List<String> zones) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: .35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: .25),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                    ),
                    child: const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZONASI AKSES TAMBANG',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      Text(
                        'Izin Resmi Masuk Area Operasional',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: (zones.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: zones.isNotEmpty ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      zones.isNotEmpty ? Icons.verified_rounded : Icons.cancel_outlined,
                      size: 12,
                      color: zones.isNotEmpty ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      zones.isNotEmpty ? '${zones.length} AREA AKTIF' : 'TANPA AKSES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: zones.isNotEmpty ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (zones.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF87171)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tidak ada izin akses area tambang yang tercatat pada permit ini.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Distinct list of clear cards
            Column(
              children: zones.map((zone) => _buildDetailedZoneTile(zone)).toList(),
            ),
            const SizedBox(height: 8),
            // Security verification note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF34D399)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pemegang permit terverifikasi sah memasuki zona di atas.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFCBD5E1),
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

  Widget _buildDetailedZoneTile(String zone) {
    final info = _getZoneInfo(zone);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.borderColor.withValues(alpha: .6), width: 1.2),
      ),
      child: Row(
        children: [
          // Left Badge with Code & Icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: info.bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: info.borderColor, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(info.icon, size: 15, color: info.color),
                const SizedBox(width: 6),
                Text(
                  info.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: info.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Middle Details: Full Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  info.description,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          // Right Status Pill: AKSES ✓
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: .15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF34D399), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 11, color: Color(0xFF34D399)),
                SizedBox(width: 2),
                Text(
                  'AKSES',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: Color(0xFF34D399),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ZoneInfo _getZoneInfo(String zone) {
    final upper = zone.trim().toUpperCase();
    if (upper == 'PIT') {
      return const _ZoneInfo(
        code: 'PIT',
        title: 'Pit Tambang Aktif',
        description: 'Area Front Penambangan & Loading',
        icon: Icons.terrain_rounded,
        color: Color(0xFFFB923C),
        borderColor: Color(0xFFF97316),
        bgColor: Color(0xFF431407),
      );
    } else if (upper == 'PORT') {
      return const _ZoneInfo(
        code: 'PORT',
        title: 'Pelabuhan & Jetty',
        description: 'Terminal Khusus Muat Tongkang',
        icon: Icons.directions_boat_rounded,
        color: Color(0xFF38BDF8),
        borderColor: Color(0xFF0284C7),
        bgColor: Color(0xFF082F49),
      );
    } else if (upper.contains('CPP')) {
      return const _ZoneInfo(
        code: 'CPP 33',
        title: 'CPP KM 33 (Pabrik)',
        description: 'Pabrik Crushing & Processing Batubara',
        icon: Icons.factory_rounded,
        color: Color(0xFFC084FC),
        borderColor: Color(0xFF9333EA),
        bgColor: Color(0xFF3B0764),
      );
    } else if (upper == 'GNR' || upper == 'OFFICE') {
      return const _ZoneInfo(
        code: 'GNR',
        title: 'General & Office',
        description: 'Perkantoran, Mess & Fasilitas Umum',
        icon: Icons.apartment_rounded,
        color: Color(0xFF34D399),
        borderColor: Color(0xFF059669),
        bgColor: Color(0xFF022C22),
      );
    } else if (upper == 'GHND' || upper.contains('HAUL')) {
      return const _ZoneInfo(
        code: 'GHND',
        title: 'Jalur Hauling',
        description: 'Jalur Angkutan Khusus Batubara',
        icon: Icons.alt_route_rounded,
        color: Color(0xFFFDE047),
        borderColor: Color(0xFFEAB308),
        bgColor: Color(0xFF422006),
      );
    } else if (upper == 'BLAST' || upper.contains('PELEDAKAN')) {
      return const _ZoneInfo(
        code: 'BLAST',
        title: 'Area Peledakan',
        description: 'Zona Bahaya Peledakan (Blasting)',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFF87171),
        borderColor: Color(0xFFDC2626),
        bgColor: Color(0xFF450A0A),
      );
    } else if (upper == 'QRY' || upper.contains('QUARRY')) {
      return const _ZoneInfo(
        code: 'QRY',
        title: 'Quarry Batuan',
        description: 'Area Tambang Batu & Agregat',
        icon: Icons.landscape_rounded,
        color: Color(0xFFCBD5E1),
        borderColor: Color(0xFF94A3B8),
        bgColor: Color(0xFF1E293B),
      );
    } else if (upper == 'WKP' || upper == 'WS' || upper.contains('WORK')) {
      return const _ZoneInfo(
        code: 'WKP',
        title: 'Workshop Tambang',
        description: 'Bengkel Perawatan Alat Berat',
        icon: Icons.build_circle_outlined,
        color: Color(0xFF67E8F9),
        borderColor: Color(0xFF06B6D4),
        bgColor: Color(0xFF164E63),
      );
    } else {
      return _ZoneInfo(
        code: upper,
        title: 'Area $upper',
        description: 'Area Operasional Resmi Tambang',
        icon: Icons.place_rounded,
        color: const Color(0xFF94A3B8),
        borderColor: const Color(0xFF64748B),
        bgColor: const Color(0xFF1E293B),
      );
    }
  }


  void _showPhotoPreviewDialog({
    required BuildContext context,
    required String photoUrl,
    required String name,
    required String nik,
    required String company,
    required String job,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: .4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: .3),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIK: $nik • $company',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .1),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF334155)),

              // HD Photo Canvas
              Container(
                width: double.infinity,
                height: 320,
                color: const Color(0xFF020617),
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF38BDF8),
                              strokeWidth: 2.5,
                            ),
                          );
                        },
                        errorBuilder: (ctx, err, stack) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Foto profil fisik belum diunggah',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Foto profil fisik belum diunggah',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
              ),

              const Divider(height: 1, color: Color(0xFF334155)),

              // Modal Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          job,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w800)),
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

  String _formatDateOnly(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  void _showInputViolationSheet(Map<String, dynamic> permitData) {
    final formKey = GlobalKey<FormState>();
    final violatorNik = permitData['nik']?.toString() ?? '-';
    final violatorName = permitData['nama']?.toString() ?? '-';
    final violatorCompany = permitData['perusahaan']?.toString() ?? '-';
    final violatorDept = permitData['departemen']?.toString() ?? '-';
    final permitNumber = permitData['nomor']?.toString() ?? '-';

    final defaultKriteria = [
      {'id': 1, 'nama': 'Fatik (kelelahan kerja)'},
      {'id': 2, 'nama': 'Tidak pakai APD'},
      {'id': 3, 'nama': 'Tidak pakai seatbelt'},
      {'id': 4, 'nama': 'Bypass safety device'},
      {'id': 5, 'nama': 'Tidak ikut SOP kerja'},
      {'id': 6, 'nama': 'Tidak LOTO saat maintenance'},
      {'id': 7, 'nama': 'Kerja tanpa permit (PTW)'},
      {'id': 8, 'nama': 'Speeding alat berat'},
      {'id': 9, 'nama': 'Masuk area berbahaya tanpa izin'},
      {'id': 10, 'nama': 'Tidak isi checklist unit'},
      {'id': 11, 'nama': 'Other'},
    ];

    final defaultSanksi = [
      {'id': 9, 'kode': 'TVC', 'nama': 'Teguran Verbal / Coaching', 'durasi': null, 'jenis_durasi': ''},
      {'id': 6, 'kode': 'L1', 'nama': 'Lubang 1 / SP-1', 'durasi': 6, 'jenis_durasi': 'month'},
      {'id': 7, 'kode': 'L2', 'nama': 'Lubang 2 / SP-2', 'durasi': 6, 'jenis_durasi': 'month'},
      {'id': 8, 'kode': 'L3', 'nama': 'Lubang 3 / SP-3', 'durasi': 6, 'jenis_durasi': 'month'},
      {'id': 10, 'kode': 'TERM', 'nama': 'Terminated', 'durasi': null, 'jenis_durasi': ''},
    ];

    List<Map<String, dynamic>> kriteriaList = List<Map<String, dynamic>>.from(defaultKriteria);
    List<Map<String, dynamic>> sanksiList = List<Map<String, dynamic>>.from(defaultSanksi);
    int? selectedKriteriaId = 1;
    int? selectedSanksiId = 9;

    final locationController = TextEditingController();
    final descController = TextEditingController();
    final actionController = TextEditingController();
    bool isSubmitting = false;
    bool hasLoadedMaster = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            if (!hasLoadedMaster) {
              hasLoadedMaster = true;
              _api.getPermitViolationMaster().then((res) {
                res.fold((_) {}, (data) {
                  if (modalCtx.mounted) {
                    setModalState(() {
                      if (data['kriteria'] is List && (data['kriteria'] as List).isNotEmpty) {
                        kriteriaList = (data['kriteria'] as List)
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .toList();
                      }
                      if (data['jenis_sanksi'] is List && (data['jenis_sanksi'] as List).isNotEmpty) {
                        sanksiList = (data['jenis_sanksi'] as List)
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .toList();
                      }
                    });
                  }
                });
              });
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catat Pelanggaran K3',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Safety Enforcement (ONE_DB_MITRA)',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 16,
                        bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Violator Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: .15),
                                    child: const Icon(Icons.person_outline_rounded, color: Color(0xFFDC2626)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          violatorName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          'NIK: $violatorNik • $violatorCompany',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                        if (permitNumber.isNotEmpty && permitNumber != '-')
                                          Text(
                                            'Permit: $permitNumber',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 1. Kriteria Pelanggaran Dropdown
                            const Text('Kriteria Pelanggaran (Safety / HSE) *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              initialValue: selectedKriteriaId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: kriteriaList.map((k) {
                                return DropdownMenuItem<int>(
                                  value: k['id'] as int,
                                  child: Text(
                                    k['nama']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedKriteriaId = val);
                              },
                            ),
                            const SizedBox(height: 18),

                            // 2. Jenis Sanksi Pelanggaran Dropdown (Safety Only)
                            const Text('Jenis Sanksi Pelanggaran (Safety) *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              initialValue: selectedSanksiId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: sanksiList.map((s) {
                                final kode = s['kode']?.toString() ?? '';
                                final nama = s['nama']?.toString() ?? '';
                                final durasi = s['durasi'];
                                final durasiStr = durasi != null && durasi > 0 ? ' ($durasi Bulan)' : '';
                                return DropdownMenuItem<int>(
                                  value: s['id'] as int,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626).withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          kode,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$nama$durasiStr',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedSanksiId = val);
                              },
                            ),
                            const SizedBox(height: 18),

                            // Lokasi Kejadian
                            const Text('Lokasi Kejadian *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: locationController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Contoh: Pit West KM 14 / Workshop Central',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.place_outlined, size: 20, color: Color(0xFF64748B)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Lokasi kejadian wajib diisi.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Deskripsi / Kronologi
                            const Text('Kronologi / Uraian Pelanggaran *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: descController,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Jelaskan tindakan tidak aman, kondisi, atau pelanggaran yang ditemukan...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length < 5) return 'Uraikan pelanggaran minimal 5 karakter.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Tindakan Langsung / Action Taken
                            const Text('Tindakan Langsung Diambil (Opsional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: actionController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Contoh: Pekerjaan dihentikan, diberikan briefing K3 langsung...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!(formKey.currentState?.validate() ?? false)) return;
                                        setModalState(() => isSubmitting = true);
                                        HapticFeedback.mediumImpact();

                                        final selK = kriteriaList.firstWhere(
                                          (k) => k['id'] == selectedKriteriaId,
                                          orElse: () => kriteriaList.first,
                                        );
                                        final selS = sanksiList.firstWhere(
                                          (s) => s['id'] == selectedSanksiId,
                                          orElse: () => sanksiList.first,
                                        );

                                        final payload = {
                                          'violatorNik': violatorNik,
                                          'violatorName': violatorName,
                                          'violatorCompany': violatorCompany,
                                          'violatorDepartment': violatorDept,
                                          'permitNumber': permitNumber,
                                          'idKriteria': selK['id'],
                                          'kriteriaNama': selK['nama'],
                                          'idPelanggaranJenis': selS['id'],
                                          'jenisPelanggaranNama': selS['nama'],
                                          'violationType': selK['nama'],
                                          'severity': selS['kode']?.toString() ?? 'SAFETY',
                                          'violationLocation': locationController.text.trim(),
                                          'violationDescription': descController.text.trim(),
                                          'actionTaken': actionController.text.trim(),
                                        };

                                        final res = await _api.recordPermitViolation(payload);
                                        if (!mounted) return;
                                        setModalState(() => isSubmitting = false);

                                        res.fold(
                                          (err) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(err['message']?.toString() ?? 'Gagal mencatat pelanggaran.'),
                                                backgroundColor: const Color(0xFFDC2626),
                                              ),
                                            );
                                          },
                                          (success) {
                                            Navigator.pop(modalCtx);
                                            HapticFeedback.heavyImpact();
                                            _showViolationRecordedDialog(
                                              violatorName,
                                              selK['nama']?.toString() ?? '',
                                              '${selS['nama']} (${selS['kode']})',
                                            );
                                          },
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.send_rounded, size: 18),
                                label: Text(
                                  isSubmitting ? 'Menyimpan ke Sistem...' : 'Kirim & Catat Pelanggaran',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
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

  void _showViolationRecordedDialog(String violatorName, String type, String severity) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Pelanggaran Tercatat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan pelanggaran K3 atas nama $violatorName telah resmi dicatat dan disinkronkan ke database sistem.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kategori: $type', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text('Tingkat Keparahan: $severity', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showInputGateLogSheet(Map<String, dynamic> permitData) {
    final formKey = GlobalKey<FormState>();
    final nik = permitData['nik']?.toString() ?? '-';
    final nama = permitData['nama']?.toString() ?? '-';
    final perusahaan = permitData['perusahaan']?.toString() ?? '-';
    final departemen = permitData['departemen']?.toString() ?? '-';
    final nomorPermit = permitData['nomor']?.toString() ?? '-';

    String selectedDirection = 'MASUK'; // 'MASUK' or 'KELUAR'
    final unitController = TextEditingController();
    int jumlahPenumpang = 0;
    final penumpangController = TextEditingController(text: '0');
    final keperluanController = TextEditingController();
    final posController = TextEditingController(text: 'Pos Security Utama');
    bool isSubmitting = false;

    Position? currentGps;
    bool isLoadingGps = true;
    bool hasFetchedGps = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            if (!hasFetchedGps) {
              hasFetchedGps = true;
              _getCurrentLocation().then((pos) {
                if (modalCtx.mounted) {
                  setModalState(() {
                    currentGps = pos;
                    isLoadingGps = false;
                  });
                }
              });
            }
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.door_sliding_outlined, color: Color(0xFF0D9488), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cek Keluar Masuk',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Pencatatan Gerbang & Movement',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 16,
                        bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Worker Identity Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: .15),
                                    child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0D9488)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nama,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          'NIK: $nik • $perusahaan',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                        if (nomorPermit.isNotEmpty && nomorPermit != '-')
                                          Text(
                                            'Permit: $nomorPermit',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.w700),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Real-time GPS Location Box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFDCFCE7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF16A34A)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Lokasi GPS Titik Gerbang *',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isLoadingGps
                                              ? 'Mendeteksi koordinat GPS satelit...'
                                              : currentGps != null
                                                  ? '${currentGps!.latitude.toStringAsFixed(6)}, ${currentGps!.longitude.toStringAsFixed(6)} (±${currentGps!.accuracy.toStringAsFixed(1)}m)'
                                                  : 'GPS belum terdeteksi (Gunakan lokasi Pos)',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: currentGps != null ? const Color(0xFF166534) : const Color(0xFF94A3B8),
                                            fontFamily: currentGps != null ? 'monospace' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isLoadingGps)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                                    )
                                  else if (currentGps != null)
                                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Arah Pergerakan (Direction Selector)
                            const Text('Arah Pergerakan *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => selectedDirection = 'MASUK'),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedDirection == 'MASUK'
                                            ? const Color(0xFF10B981).withValues(alpha: .12)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selectedDirection == 'MASUK'
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFE2E8F0),
                                          width: selectedDirection == 'MASUK' ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.login_rounded,
                                            size: 18,
                                            color: selectedDirection == 'MASUK' ? const Color(0xFF059669) : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'MASUK (IN)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: selectedDirection == 'MASUK' ? const Color(0xFF059669) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => selectedDirection = 'KELUAR'),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedDirection == 'KELUAR'
                                            ? const Color(0xFFEF4444).withValues(alpha: .14)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selectedDirection == 'KELUAR'
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFE2E8F0),
                                          width: selectedDirection == 'KELUAR' ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.logout_rounded,
                                            size: 18,
                                            color: selectedDirection == 'KELUAR' ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'KELUAR (OUT)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: selectedDirection == 'KELUAR' ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Input Nomor Unit
                            const Text('Nomor Unit Kendaraan *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: unitController,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.directions_car_filled_rounded, size: 20, color: Color(0xFF0D9488)),
                                hintText: 'Contoh: DT-104, LV-02, Bus Karyawan, Motor...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Nomor unit wajib diisi.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Input Jumlah Penumpang
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.group_outlined,
                                      size: 17,
                                      color: selectedDirection == 'KELUAR' ? const Color(0xFFDC2626) : const Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Jumlah Penumpang',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: selectedDirection == 'KELUAR' ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: selectedDirection == 'KELUAR' ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: selectedDirection == 'KELUAR' ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    selectedDirection == 'KELUAR' ? 'Keluar (OUT) Merah' : 'Di luar pengemudi',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: selectedDirection == 'KELUAR' ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedDirection == 'KELUAR'
                                    ? const Color(0xFFFEF2F2).withValues(alpha: .5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedDirection == 'KELUAR'
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFCBD5E1),
                                  width: selectedDirection == 'KELUAR' ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Decrement Button
                                      Material(
                                        color: selectedDirection == 'KELUAR'
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            if (jumlahPenumpang > 0) {
                                              setModalState(() {
                                                jumlahPenumpang--;
                                                penumpangController.text = jumlahPenumpang.toString();
                                              });
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Icon(
                                              Icons.remove_rounded,
                                              size: 20,
                                              color: selectedDirection == 'KELUAR'
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Number Display / Input
                                      Expanded(
                                        child: Column(
                                          children: [
                                            TextFormField(
                                              controller: penumpangController,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: selectedDirection == 'KELUAR'
                                                    ? const Color(0xFFDC2626)
                                                    : const Color(0xFF0F172A),
                                              ),
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                                hintText: '0',
                                                hintStyle: TextStyle(
                                                  color: selectedDirection == 'KELUAR'
                                                      ? const Color(0xFFF87171)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              onChanged: (val) {
                                                final p = int.tryParse(val) ?? 0;
                                                setModalState(() {
                                                  jumlahPenumpang = p < 0 ? 0 : p;
                                                });
                                              },
                                            ),
                                            Text(
                                              jumlahPenumpang == 0
                                                  ? 'Hanya Sopir/Driver (0 Penumpang)'
                                                  : '$jumlahPenumpang Orang Penumpang',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: selectedDirection == 'KELUAR'
                                                    ? const Color(0xFFDC2626)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Increment Button
                                      Material(
                                        color: selectedDirection == 'KELUAR'
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF0D9488),
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            setModalState(() {
                                              jumlahPenumpang++;
                                              penumpangController.text = jumlahPenumpang.toString();
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Quick Chips
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [0, 1, 2, 3, 4, 5].map((count) {
                                      final isSelected = jumlahPenumpang == count;
                                      final isOut = selectedDirection == 'KELUAR';
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          setModalState(() {
                                            jumlahPenumpang = count;
                                            penumpangController.text = count.toString();
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (isOut ? const Color(0xFFDC2626) : const Color(0xFF0D9488))
                                                : (isOut ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? (isOut ? const Color(0xFFDC2626) : const Color(0xFF0D9488))
                                                  : (isOut ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            count == 0 ? 'Driver Saja (0)' : '$count Org',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isOut ? const Color(0xFFDC2626) : const Color(0xFF475569)),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Input Keperluan Keluar/Masuk
                            const Text('Keperluan Keluar / Masuk *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: keperluanController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 24),
                                  child: Icon(Icons.assignment_outlined, size: 20, color: Color(0xFF0D9488)),
                                ),
                                hintText: 'Contoh: Operasional Pit, Ganti Shift, Antar Logistik, Izin Pribadi...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Keperluan keluar masuk wajib diisi.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Input Lokasi Pos / Gate
                            const Text('Lokasi Pos / Gate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: posController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.security_rounded, size: 20, color: Color(0xFF64748B)),
                                hintText: 'Contoh: Pos Security Utama, Pos KM 0, Pos Pit...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!(formKey.currentState?.validate() ?? false)) return;
                                        setModalState(() => isSubmitting = true);
                                        HapticFeedback.mediumImpact();

                                        final gpsStr = currentGps != null
                                            ? '${currentGps!.latitude.toStringAsFixed(6)}, ${currentGps!.longitude.toStringAsFixed(6)}'
                                            : null;

                                        final payload = {
                                          'nik': nik,
                                          'nama': nama,
                                          'perusahaan': perusahaan,
                                          'departemen': departemen,
                                          'nomorPermit': nomorPermit,
                                          'direction': selectedDirection,
                                          'nomorUnit': unitController.text.trim(),
                                          'jumlahPenumpang': jumlahPenumpang,
                                          'jumlah_penumpang': jumlahPenumpang,
                                          'keperluan': keperluanController.text.trim(),
                                          'lokasiPos': posController.text.trim(),
                                          'latitude': currentGps?.latitude,
                                          'longitude': currentGps?.longitude,
                                          'detilLokasi': gpsStr != null
                                              ? 'Pos: ${posController.text.trim()} [GPS: $gpsStr]'
                                              : posController.text.trim(),
                                        };

                                        final res = await _api.recordPermitMovement(payload);
                                        if (!mounted) return;
                                        setModalState(() => isSubmitting = false);

                                        res.fold(
                                          (err) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(err['message']?.toString() ?? 'Gagal mencatat log keluar masuk.'),
                                                backgroundColor: const Color(0xFFDC2626),
                                              ),
                                            );
                                          },
                                          (success) {
                                            Navigator.pop(modalCtx);
                                            HapticFeedback.heavyImpact();
                                            _showMovementRecordedDialog(
                                              nama,
                                              selectedDirection,
                                              unitController.text.trim(),
                                              keperluanController.text.trim(),
                                              jumlahPenumpang,
                                              gpsStr != null ? '$gpsStr (${posController.text.trim()})' : posController.text.trim(),
                                            );
                                          },
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedDirection == 'KELUAR' ? const Color(0xFFDC2626) : const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Icon(selectedDirection == 'KELUAR' ? Icons.logout_rounded : Icons.login_rounded, size: 20),
                                label: Text(
                                  isSubmitting
                                      ? (selectedDirection == 'KELUAR' ? 'Menyimpan Log Keluar...' : 'Menyimpan Log Masuk...')
                                      : (selectedDirection == 'KELUAR' ? 'Simpan Data Keluar (OUT)' : 'Simpan Data Masuk (IN)'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
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

  void _showMovementRecordedDialog(
    String nama,
    String direction,
    String unit,
    String keperluan,
    int jumlahPenumpang, [
    String? lokasiDetail,
  ]) {
    final isMasuk = direction == 'MASUK';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isMasuk ? const Color(0xFF0D9488) : const Color(0xFFDC2626)).withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMasuk ? Icons.verified_rounded : Icons.logout_rounded,
                color: isMasuk ? const Color(0xFF0D9488) : const Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Log Gerbang Dicatat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMasuk
                        ? const Color(0xFF10B981).withValues(alpha: .2)
                        : const Color(0xFFEF4444).withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isMasuk ? 'MASUK TAMBANG (IN)' : 'KELUAR TAMBANG (OUT)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isMasuk ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Pergerakan atas nama $nama berhasil dicatat pada sistem pemeriksaan gerbang.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Kendaraan: $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Penumpang: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: !isMasuk ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: !isMasuk ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          jumlahPenumpang == 0 ? '0 (Hanya Sopir)' : '$jumlahPenumpang Orang Penumpang',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: !isMasuk ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Keperluan: $keperluan', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  if (lokasiDetail != null && lokasiDetail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.my_location_rounded, size: 14, color: isMasuk ? const Color(0xFF0D9488) : const Color(0xFFDC2626)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Lokasi GPS: $lokasiDetail',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isMasuk ? const Color(0xFF0D9488) : const Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isMasuk ? const Color(0xFF0D9488) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEventQrModal(Map<String, dynamic> event) {
    final token = event['qr_token']?.toString() ?? '';
    final name = event['event_name']?.toString() ?? 'Acara K3';
    final location = event['event_location']?.toString() ?? '-';
    final startAt = event['start_at']?.toString() ?? '';
    final endAt = event['end_at']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // QR Image Frame
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: token,
                      version: QrVersions.auto,
                      size: 220,
                      gapless: false,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatTime(startAt)} - ${_formatTime(endAt)} WITA',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: token));
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Token QR Acara disalin.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin Token', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatAttendedDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Tercatat';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${DateFormat('HH:mm').format(dt)} WITA';
      }
      return DateFormat('dd MMM, HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  void _showAttendanceProofModal(Map<String, dynamic> item) {
    final name = item['event_name']?.toString() ?? 'Acara K3';
    final location = item['event_location']?.toString() ?? '-';
    final attendedAt = item['attended_at']?.toString() ?? '-';
    final totalAttendees = item['total_attendees'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, size: 36, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bukti Kehadiran K3',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kehadiran Anda telah terekam resmi di sistem SAP.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildProofRow('Kegiatan', name, isBold: true),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  _buildProofRow('Waktu Hadir', _formatDateTime(attendedAt), color: const Color(0xFF059669)),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  _buildProofRow('Lokasi', location),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  _buildProofRow('Total Hadir', '$totalAttendees Peserta'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredEvents {
    final now = DateTime.now();
    final q = _eventSearchQuery.trim().toLowerCase();

    return _events.where((e) {
      if (q.isNotEmpty) {
        final name = (e['event_name'] ?? '').toString().toLowerCase();
        final loc = (e['event_location'] ?? '').toString().toLowerCase();
        final desc = (e['event_description'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !loc.contains(q) && !desc.contains(q)) {
          return false;
        }
      }

      if (_eventFilter == 'all') return true;

      final start = DateTime.tryParse(e['start_at']?.toString() ?? '');
      final end = DateTime.tryParse(e['end_at']?.toString() ?? '');
      final isAttended = e['is_attended'] == true;
      final isToday = e['is_today'] == true ||
          (start != null && start.year == now.year && start.month == now.month && start.day == now.day) ||
          (end != null && end.year == now.year && end.month == now.month && end.day == now.day);
      final isOngoing = e['is_ongoing'] == true ||
          e['status_state'] == 'ongoing' ||
          e['status_state'] == 'late_allowed' ||
          (start != null && end != null && now.isAfter(start) && now.isBefore(end.add(const Duration(hours: 12))));

      if (_eventFilter == 'today') return isToday;
      if (_eventFilter == 'ongoing') return isOngoing;
      if (_eventFilter == 'attended') return isAttended;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _selectedTab == 0;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopAppBar(isDark),
            Expanded(
              child: _selectedTab == 0 ? _buildScannerView() : _buildEventsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: .35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presensi & Scan K3',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          if (_canScanMinePermit)
                            _buildRolePill('Mine Permit', const Color(0xFF10B981)),
                          if (_canScanPermitPelanggaran) ...[
                            if (_canScanMinePermit) const SizedBox(width: 4),
                            _buildRolePill('Pelanggaran', const Color(0xFFEF4444)),
                          ],
                          if (_canScanPermitKeluarMasuk) ...[
                            if (_canScanMinePermit || _canScanPermitPelanggaran) const SizedBox(width: 4),
                            _buildRolePill('Keluar Masuk', const Color(0xFF0D9488)),
                          ],
                          if (_canScanSimper) ...[
                            const SizedBox(width: 4),
                            _buildRolePill('SIMPER', const Color(0xFF0EA5E9)),
                          ],
                          if (_canScanCommissioning) ...[
                            const SizedBox(width: 4),
                            _buildRolePill('Commissioning', const Color(0xFFF59E0B)),
                          ],
                          if (_canScanSpecialPermit) ...[
                            const SizedBox(width: 4),
                            _buildRolePill('Special Permit', const Color(0xFFA855F7)),
                          ],
                          if (_canScanOther) ...[
                            const SizedBox(width: 4),
                            _buildRolePill('Custom Scan', const Color(0xFF0D9488)),
                          ],
                          if (!_canScanMinePermit &&
                              !_canScanPermitPelanggaran &&
                              !_canScanPermitKeluarMasuk &&
                              !_canScanSimper &&
                              !_canScanCommissioning &&
                              !_canScanSpecialPermit &&
                              !_canScanOther)
                            Text(
                              _canScanAcara ? 'Scan QR Acara & Mine Permit' : 'Akses Scan Terbatas',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Refresh button
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _loadMyPermissions();
                  _loadEvents();
                  if (_hasCameraPermission && _scannerController != null) {
                    _scannerController?.start();
                  }
                },
                tooltip: 'Refresh Izin & Acara',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Modern Segmented Tab Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155).withValues(alpha: .5) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    index: 0,
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Pindai QR',
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    index: 1,
                    icon: Icons.event_available_rounded,
                    label: 'Daftar Acara K3',
                    badgeCount: _events.length,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePill(String roleName, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            'Petugas $roleName',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
    int? badgeCount,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      },
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: .35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: .25)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF475569)),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: SCANNER VIEW (/QrCode/Index)
  // ==========================================
  Widget _buildScannerView() {
    if (_isPermissionChecking) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0284C7)),
      );
    }

    if (!_hasCameraPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: .15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_outlined, size: 38, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 18),
              const Text(
                'Izin Kamera Diperlukan',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplikasi membutuhkan izin akses kamera untuk memindai QR Code kegiatan & verifikasi presensi K3.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _checkPermissionAndInit,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Beri Izin Kamera', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = (constraints.maxWidth * 0.74).clamp(240.0, 320.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Camera Stream
            if (_scannerController != null)
              MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetectQr,
              ),

            // Semi-transparent Overlay Mask
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: .65),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Target Reticle & Laser
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Stack(
                  children: [
                    // Reticle Border Corners
                    _buildReticleCorners(),

                    // Center subtle watermarked QR target
                    Center(
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        size: 48,
                        color: const Color(0xFF38BDF8).withValues(alpha: .15),
                      ),
                    ),

                    // Animated Laser Scanning Line
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: boxSize * _laserAnimation.value,
                          left: 14,
                          right: 14,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xFF38BDF8),
                                  Color(0xFF0284C7),
                                  Color(0xFF38BDF8),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: .75),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Camera Controls Bar (Safely above bottom navigation bar)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 95,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: .15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Flash Toggle
                        IconButton(
                          tooltip: 'Senter',
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await _scannerController?.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: _isTorchOn
                                ? const Color(0xFFF59E0B)
                                : Colors.white.withValues(alpha: .10),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            size: 20,
                          ),
                        ),

                        // Quick Zoom Preset Buttons (1x & 2x) & Fine Tune Slider
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildZoomPresetPill('1x', 0.0),
                                const SizedBox(width: 6),
                                _buildZoomPresetPill('2x', 0.5),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF0284C7),
                                      inactiveTrackColor: Colors.white.withValues(alpha: .15),
                                      thumbColor: const Color(0xFF38BDF8),
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      trackHeight: 3,
                                    ),
                                    child: Slider(
                                      value: _zoomScale,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (val) {
                                        setState(() => _zoomScale = val);
                                        _scannerController?.setZoomScale(val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Switch Camera
                        IconButton(
                          tooltip: 'Ganti Kamera',
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await _scannerController?.switchCamera();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: .10),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.cameraswitch_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // High-Tech Professional Processing Overlay with Loading Bar
            if (_isProcessingScan)
              Positioned.fill(
                child: _buildProfessionalProcessingOverlay(boxSize),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProfessionalProcessingOverlay(double boxSize) {
    return Container(
      color: Colors.black.withValues(alpha: .6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: Container(
            width: (boxSize + 40).clamp(280.0, 340.0),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: .45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: .35),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Glowing Shield Scanner Icon
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: .5),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // System Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: .4),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'VERIFIKASI SISTEM K3',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Headline
                const Text(
                  'Memproses & Memvalidasi QR...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),

                // Subtitle
                const Text(
                  'Mengecek identitas, masa berlaku permit, dan otorisasi kerja ke server MBS SAP...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF94A3B8),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),

                // Professional Sleek Progress Bar with Rounded Ends
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const LinearProgressIndicator(
                      minHeight: 6,
                      backgroundColor: Color(0xFF334155),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // High-Tech Status Micro-row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_tethering_rounded, size: 12, color: Color(0xFF38BDF8)),
                        SizedBox(width: 4),
                        Text(
                          'MBS API Link',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Mengambil Data...',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomPresetPill(String label, double scale) {
    final isSelected = (_zoomScale - scale).abs() < 0.15;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _zoomScale = scale);
        _scannerController?.setZoomScale(scale);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: .12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildReticleCorners() {
    const cornerSize = 28.0;
    const cornerThickness = 4.0;
    const color = Color(0xFF38BDF8);

    return Stack(
      children: [
        // Top-Left
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: cornerThickness),
                left: BorderSide(color: color, width: cornerThickness),
              ),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(18)),
            ),
          ),
        ),
        // Top-Right
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: cornerThickness),
                right: BorderSide(color: color, width: cornerThickness),
              ),
              borderRadius: BorderRadius.only(topRight: Radius.circular(18)),
            ),
          ),
        ),
        // Bottom-Left
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: cornerThickness),
                left: BorderSide(color: color, width: cornerThickness),
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(18)),
            ),
          ),
        ),
        // Bottom-Right
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: cornerThickness),
                right: BorderSide(color: color, width: cornerThickness),
              ),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(18)),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: EVENTS LIST VIEW (/EventQr/Index)
  // ==========================================
  Widget _buildEventsView() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: _loadEvents,
        color: const Color(0xFF0284C7),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _eventSearchCtrl,
                        onChanged: (val) => setState(() => _eventSearchQuery = val),
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Cari nama acara, topik, atau lokasi...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 20),
                          suffixIcon: _eventSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _eventSearchCtrl.clear();
                                    setState(() => _eventSearchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips
                    Builder(
                      builder: (context) {
                        final totalAll = _events.length;
                        final totalOngoing = _events.where((e) {
                          final now = DateTime.now();
                          final start = DateTime.tryParse(e['start_at']?.toString() ?? '');
                          final end = DateTime.tryParse(e['end_at']?.toString() ?? '');
                          return e['is_ongoing'] == true ||
                              e['status_state'] == 'ongoing' ||
                              e['status_state'] == 'late_allowed' ||
                              (start != null && end != null && now.isAfter(start) && now.isBefore(end.add(const Duration(hours: 12))));
                        }).length;
                        final totalToday = _events.where((e) {
                          final now = DateTime.now();
                          final start = DateTime.tryParse(e['start_at']?.toString() ?? '');
                          final end = DateTime.tryParse(e['end_at']?.toString() ?? '');
                          return e['is_today'] == true ||
                              (start != null && start.year == now.year && start.month == now.month && start.day == now.day) ||
                              (end != null && end.year == now.year && end.month == now.month && end.day == now.day);
                        }).length;
                        final totalAttended = _events.where((e) => e['is_attended'] == true).length;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip('all', 'Semua Acara', Icons.all_inclusive_rounded, count: totalAll),
                              const SizedBox(width: 8),
                              _buildFilterChip('ongoing', 'Sedang Berlangsung', Icons.play_circle_filled_rounded, count: totalOngoing),
                              const SizedBox(width: 8),
                              _buildFilterChip('today', 'Hari Ini', Icons.today_rounded, count: totalToday),
                              const SizedBox(width: 8),
                              _buildFilterChip('attended', 'Sudah Hadir', Icons.check_circle_rounded, count: totalAttended),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Quick Summary Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _eventFilter == 'attended'
                              ? 'Riwayat Acara Dihadiri (${_filteredEvents.length})'
                              : _eventFilter == 'ongoing'
                                  ? 'Acara Sedang Berlangsung (${_filteredEvents.length})'
                                  : _eventFilter == 'today'
                                      ? 'Acara Jadwal Hari Ini (${_filteredEvents.length})'
                                      : 'Kegiatan K3 Terjadwal (${_filteredEvents.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedTab = 0);
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, size: 14, color: Color(0xFF0284C7)),
                              SizedBox(width: 4),
                              Text(
                                'Scan Sekarang',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
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
            ),

            if (_isLoadingEvents)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                ),
              )
            else if (_eventsErrorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          _eventsErrorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: _loadEvents,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_filteredEvents.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _eventFilter == 'attended' ? Icons.event_available_rounded : Icons.event_busy_rounded,
                            size: 32,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _eventFilter == 'attended' ? 'Belum Ada Acara Dihadiri' : 'Tidak Ada Acara',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _eventFilter == 'attended'
                              ? 'Anda belum memiliki riwayat presensi acara K3 yang terekam.'
                              : (_eventSearchQuery.isNotEmpty
                                  ? 'Tidak ditemukan kegiatan dengan kata kunci "$_eventSearchQuery".'
                                  : 'Belum ada kegiatan yang sesuai filter saat ini.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _filteredEvents[index];
                      return _buildEventCard(item);
                    },
                    childCount: _filteredEvents.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String title, IconData icon, {int? count}) {
    final isSelected = _eventFilter == key;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _eventFilter = key);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? .1 : .02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: .22)
                      : (key == 'attended' && count > 0
                          ? const Color(0xFF10B981).withValues(alpha: .15)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : (key == 'attended' && count > 0
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> item) {
    final name = item['event_name']?.toString() ?? 'Acara K3';
    final location = item['event_location']?.toString() ?? 'Lokasi belum ditentukan';
    final desc = item['event_description']?.toString() ?? '';
    final startAt = item['start_at']?.toString() ?? '';
    final endAt = item['end_at']?.toString() ?? '';
    final isAttended = item['is_attended'] == true;
    final attendedAt = item['attended_at']?.toString();
    final totalAttendees = item['total_attendees'] ?? 0;
    final statusState = item['status_state']?.toString() ?? 'upcoming';

    Color stateColor;
    String stateLabel;
    if (statusState == 'ongoing') {
      stateColor = const Color(0xFF10B981);
      stateLabel = 'BERLANGSUNG';
    } else if (statusState == 'upcoming') {
      stateColor = const Color(0xFF0284C7);
      stateLabel = 'AKAN DATANG';
    } else if (statusState == 'late_allowed') {
      stateColor = const Color(0xFFF59E0B);
      stateLabel = 'TOLERANSI SELESAI';
    } else {
      stateColor = const Color(0xFF64748B);
      stateLabel = 'SELESAI';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAttended ? const Color(0xFF10B981).withValues(alpha: .4) : const Color(0xFFE2E8F0),
          width: isAttended ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Event State Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stateColor.withValues(alpha: .25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: stateColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stateLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: stateColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Attendance Status Badge
                if (isAttended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: .3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          attendedAt != null ? 'Hadir ${_formatAttendedDate(attendedAt)}' : 'Sudah Hadir',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Belum Absen',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Event Title
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.3,
              ),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
              ),
            ],
            const SizedBox(height: 12),

            // Meta Details
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Text(
                  _formatDateTime(startAt),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Text(
                  '${_formatTime(startAt)} - ${_formatTime(endAt)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '👥 $totalAttendees Hadir',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bottom Action Buttons
            Row(
              children: [
                if (isAttended) ...[
                  // Button Lihat Bukti Hadir
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        foregroundColor: const Color(0xFF059669),
                      ),
                      onPressed: () => _showAttendanceProofModal(item),
                      icon: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                      label: const Text(
                        'Bukti Hadir',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Button Lihat QR Acara
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showEventQrModal(item),
                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                      label: const Text(
                        'QR Acara',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ] else ...[
                  // Belum Hadir: Button Tampilkan QR Acara
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => _showEventQrModal(item),
                      icon: const Icon(Icons.qr_code_rounded, size: 16, color: Color(0xFF0284C7)),
                      label: const Text(
                        'Lihat QR Acara',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Button Absen Sekarang
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedTab = 0);
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text(
                        'Absen Sekarang',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneInfo {
  final String code;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final Color bgColor;

  const _ZoneInfo({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.bgColor,
  });
}
