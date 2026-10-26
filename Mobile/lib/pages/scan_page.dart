import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api.dart';

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
  String _selectedScanTarget = 'auto'; // 'auto', 'permit', 'event', 'vehicle'

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

  Future<void> _onDetectQr(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.trim().isEmpty) {
      return;
    }

    final rawCode = barcode.rawValue!.trim();
    setState(() => _isProcessingScan = true);
    HapticFeedback.mediumImpact();

    // Show temporary scanning overlay
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 14),
            Text('Memverifikasi QR & Kehadiran...', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );

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
    setState(() => _isProcessingScan = false);

    res.fold(
      (err) {
        _showResultDialog(
          isSuccess: false,
          title: 'Pemindaian Belum Berhasil',
          message: err['message']?.toString() ?? 'QR tidak valid atau server bermasalah.',
          actionType: 'Error',
        );
      },
      (data) {
        final isSuccess = data['status'] == true;
        final msg = data['message']?.toString() ?? '';
        final actionType = data['actionType']?.toString() ?? 'Attendance';
        final payload = data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : null;

        if (actionType == 'MinePermit' && isSuccess && payload != null) {
          _showResultDialog(
            isSuccess: true,
            title: 'Mine Permit Terverifikasi',
            message: msg.isNotEmpty ? msg : 'Data identitas karyawan & permit valid.',
            actionType: 'MinePermit',
            data: payload,
          );
        } else {
          _showResultDialog(
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

  void _showResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
    required String actionType,
    Map<String, dynamic>? data,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isAttendance = actionType == 'Attendance';
        final isMinePermit = actionType == 'MinePermit';
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

        final isExpiredPermit = isMinePermit &&
            (data?['is_expired'] == true ||
                (data?['days_left'] is int && (data?['days_left'] as int) < 0) ||
                (int.tryParse(data?['days_left']?.toString() ?? '0') ?? 0) < 0);

        final canPelanggaran = data?['can_input_pelanggaran'] == true || _canScanPermitPelanggaran;
        final canKeluarMasuk = data?['can_input_keluar_masuk'] == true || _canScanPermitKeluarMasuk;

        if (isDenied) {
          primaryColor = const Color(0xFFEF4444);
          iconData = Icons.gpp_bad_rounded;
          statusBadgeText = 'AKSES DIBATASI';
        } else if (isMinePermit) {
          if (isExpiredPermit) {
            primaryColor = const Color(0xFFEF4444);
            iconData = Icons.warning_amber_rounded;
            statusBadgeText = 'MINE PERMIT KADALUARSA';
          } else {
            primaryColor = const Color(0xFF10B981);
            iconData = Icons.verified_user_rounded;
            statusBadgeText = 'MINE PERMIT AKTIF';
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

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: SingleChildScrollView(
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
                const SizedBox(height: 20),

                // Status Icon
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 44, color: primaryColor),
                ),
                const SizedBox(height: 16),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withValues(alpha: .25)),
                  ),
                  child: Text(
                    statusBadgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

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

                // Actions
                if (isMinePermit && data != null) ...[
                  if (canKeluarMasuk) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showInputGateLogSheet(data);
                        },
                        icon: const Icon(Icons.door_sliding_outlined, size: 20),
                        label: const Text(
                          'Input Keluar Masuk Karyawan',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canPelanggaran) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showInputViolationSheet(data);
                        },
                        icon: const Icon(Icons.report_problem_rounded, size: 20),
                        label: const Text(
                          'Catat Pelanggaran K3',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!canPelanggaran && !canKeluarMasuk) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Data permit hanya untuk validasi identitas dan masa berlaku.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    ),
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
    final daysLeft = data['days_left'] is int
        ? data['days_left'] as int
        : int.tryParse(data['days_left']?.toString() ?? '0') ?? 0;
    final isExpired = data['is_expired'] == true || daysLeft < 0;
    final rawAkses = data['akses_lokasi']?.toString() ?? '';
    final zones = rawAkses
        .split(RegExp(r'[,;|\s]+'))
        .map((z) => z.trim())
        .where((z) => z.isNotEmpty)
        .toList();

    final statusColor = isExpired ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExpired ? const Color(0xFFEF4444) : const Color(0xFF38BDF8).withValues(alpha: .35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? const Color(0xFFEF4444) : const Color(0xFF0284C7)).withValues(alpha: .2),
            blurRadius: 18,
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
              color: isExpired
                  ? const Color(0xFF7F1D1D).withValues(alpha: .4)
                  : const Color(0xFF064E3B).withValues(alpha: .35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: (isExpired ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: .3),
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
                        isExpired ? Icons.warning_rounded : Icons.verified_user_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          perusahaan.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: isExpired ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    isExpired ? 'EXPIRED' : status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Text(
                            nomor.isNotEmpty && nomor != '-' ? nomor : 'NO PERMIT TIDAK TERDATA',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pengajuan,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
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
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isExpired
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF38BDF8),
                                        width: 1.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isExpired
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF38BDF8))
                                              .withValues(alpha: .25),
                                          blurRadius: 10,
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
                                                      fontSize: 24,
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
                                                  fontSize: 24,
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
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0284C7),
                                        shape: BoxShape.circle,
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
                                    nama,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
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
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                      if (departemen.isNotEmpty && departemen != '-') ...[
                                        const Text(' • ', style: TextStyle(color: Color(0xFF64748B))),
                                        Flexible(
                                          child: Text(
                                            departemen,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (jabatan.isNotEmpty && jabatan != '-') ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      jabatan,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: .7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                if (noHp.isNotEmpty && noHp != '-') ...[
                                  const Icon(Icons.phone_iphone_rounded, size: 13, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 5),
                                  Text(noHp, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 12),
                                ],
                                if (gender.isNotEmpty && gender != '-') ...[
                                  const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(gender, style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                                  const SizedBox(width: 12),
                                ],
                                if (email.isNotEmpty && email != '-') ...[
                                  const Icon(Icons.mail_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
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
                    border: Border.all(color: const Color(0xFF334155)),
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
                          Container(width: 1, height: 36, color: const Color(0xFF334155)),
                          Expanded(
                            child: _buildPermitDateItem(
                              label: 'Masa Aktif Permit',
                              value: _formatDateOnly(masaAktif),
                              icon: isExpired ? Icons.event_busy_rounded : Icons.verified_rounded,
                              iconColor: statusColor,
                              isHighlight: true,
                              highlightColor: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18, color: Color(0xFF334155)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 6),
                              Text(
                                isExpired
                                    ? 'Kedaluwarsa (${daysLeft.abs()} hari lalu)'
                                    : 'Sisa Masa Aktif: $daysLeft hari',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isExpired ? const Color(0xFFF87171) : const Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                          if (berakhirKerja.isNotEmpty && berakhirKerja != '-')
                            Text(
                              'Kontrak: ${_formatDateOnly(berakhirKerja)}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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
                            ? const Color(0xFF0EA5E9).withValues(alpha: .5)
                            : const Color(0xFFEF4444).withValues(alpha: .5),
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
                                Icon(Icons.drive_eta_rounded, size: 16, color: Color(0xFF38BDF8)),
                                SizedBox(width: 6),
                                Text(
                                  'SIMPER TERDAFTAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (data['is_simper_active'] == true
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: .2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data['is_simper_active'] == true ? 'SIMPER AKTIF' : 'EXPIRED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: data['is_simper_active'] == true
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('No. SIMPER', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  Text(
                                    data['simper_nomor']?.toString() ?? '-',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Jenis SIM & No', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  Text(
                                    '${data['jenis_sim'] ?? '-'} (${data['nomor_sim'] ?? '-'})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFCBD5E1)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              'Masa Berlaku SIMPER: ${_formatDateOnly(data['simper_masa_berlaku']?.toString() ?? '-')}',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Zonasi Akses Tambang
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: Color(0xFF38BDF8)),
                    SizedBox(width: 6),
                    Text(
                      'ZONASI AKSES TAMBANG',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (zones.isEmpty)
                  const Text('Tidak ada izin akses area yang tercatat', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: zones.map((zone) => _buildZoneChip(zone)).toList(),
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
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isHighlight ? (highlightColor ?? Colors.white) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneChip(String zone) {
    Color chipBg;
    Color chipText;
    IconData chipIcon;

    final upper = zone.toUpperCase();
    if (upper == 'PIT') {
      chipBg = const Color(0xFFEA580C).withValues(alpha: .2);
      chipText = const Color(0xFFFB923C);
      chipIcon = Icons.terrain_rounded;
    } else if (upper == 'PORT') {
      chipBg = const Color(0xFF0284C7).withValues(alpha: .2);
      chipText = const Color(0xFF38BDF8);
      chipIcon = Icons.directions_boat_rounded;
    } else if (upper.contains('CPP')) {
      chipBg = const Color(0xFF7C3AED).withValues(alpha: .2);
      chipText = const Color(0xFFA78BFA);
      chipIcon = Icons.factory_rounded;
    } else if (upper == 'GNR' || upper == 'OFFICE') {
      chipBg = const Color(0xFF059669).withValues(alpha: .2);
      chipText = const Color(0xFF34D399);
      chipIcon = Icons.domain_rounded;
    } else {
      chipBg = const Color(0xFF334155);
      chipText = const Color(0xFFE2E8F0);
      chipIcon = Icons.place_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipText.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, size: 12, color: chipText),
          const SizedBox(width: 5),
          Text(
            zone,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: chipText,
            ),
          ),
        ],
      ),
    );
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
    final keperluanController = TextEditingController();
    final posController = TextEditingController(text: 'Pos Security Utama');
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
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
                                            ? const Color(0xFF0284C7).withValues(alpha: .12)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selectedDirection == 'KELUAR'
                                              ? const Color(0xFF0284C7)
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
                                            color: selectedDirection == 'KELUAR' ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'KELUAR (OUT)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: selectedDirection == 'KELUAR' ? const Color(0xFF0284C7) : const Color(0xFF64748B),
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

                                        final payload = {
                                          'nik': nik,
                                          'nama': nama,
                                          'perusahaan': perusahaan,
                                          'departemen': departemen,
                                          'nomorPermit': nomorPermit,
                                          'direction': selectedDirection,
                                          'nomorUnit': unitController.text.trim(),
                                          'keperluan': keperluanController.text.trim(),
                                          'lokasiPos': posController.text.trim(),
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
                                            );
                                          },
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
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
                                    : const Icon(Icons.check_rounded, size: 20),
                                label: Text(
                                  isSubmitting ? 'Menyimpan Log...' : 'Simpan Data Keluar Masuk',
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

  void _showMovementRecordedDialog(String nama, String direction, String unit, String keperluan) {
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
                color: const Color(0xFF0D9488).withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: Color(0xFF0D9488), size: 24),
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
                        : const Color(0xFF0284C7).withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isMasuk ? 'MASUK TAMBANG' : 'KELUAR TAMBANG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isMasuk ? const Color(0xFF059669) : const Color(0xFF0284C7),
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
                  Text('Keperluan: $keperluan', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
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

            // Top Scan Target Mode Selector & Instructions
            _buildScanTargetModeSelector(),

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
          ],
        );
      },
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

  Widget _buildScanTargetModeSelector() {
    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: Column(
        children: [
          // Mode Chips Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: .15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildScanTargetChip(
                        target: 'auto',
                        label: 'Otomatis',
                        icon: Icons.auto_awesome_rounded,
                        activeColor: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 5),
                      _buildScanTargetChip(
                        target: 'permit',
                        label: 'Mine Permit',
                        icon: Icons.badge_rounded,
                        activeColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 5),
                      _buildScanTargetChip(
                        target: 'event',
                        label: 'Acara K3',
                        icon: Icons.event_available_rounded,
                        activeColor: const Color(0xFF0EA5E9),
                      ),
                      if (_canScanCommissioning) ...[
                        const SizedBox(width: 5),
                        _buildScanTargetChip(
                          target: 'vehicle',
                          label: 'Kendaraan',
                          icon: Icons.agriculture_rounded,
                          activeColor: const Color(0xFFF59E0B),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Sub-guidance Pill
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: .70),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedScanTarget == 'permit'
                          ? Icons.badge_rounded
                          : _selectedScanTarget == 'event'
                              ? Icons.event_available_rounded
                              : _selectedScanTarget == 'vehicle'
                                  ? Icons.directions_car_rounded
                                  : Icons.center_focus_strong_rounded,
                      size: 13,
                      color: _selectedScanTarget == 'permit'
                          ? const Color(0xFF10B981)
                          : _selectedScanTarget == 'event'
                              ? const Color(0xFF0EA5E9)
                              : _selectedScanTarget == 'vehicle'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedScanTarget == 'permit'
                          ? 'Fokus scan Mine Permit, SIMPER & Karyawan'
                          : _selectedScanTarget == 'event'
                              ? 'Fokus scan Barcode Presensi Acara K3'
                              : _selectedScanTarget == 'vehicle'
                                  ? 'Fokus scan Commissioning Kendaraan / Unit'
                                  : 'Mode Cerdas: Mendeteksi Acara, Permit, atau Unit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
  }

  Widget _buildScanTargetChip({
    required String target,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedScanTarget == target;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedScanTarget = target);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: .22) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
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
