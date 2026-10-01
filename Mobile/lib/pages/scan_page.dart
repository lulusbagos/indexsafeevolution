import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _scanAnimCtrl;
  bool _isPermissionGranted = false;
  bool _isCheckingPermission = true;
  bool _isProcessing = false;
  String _selectedCategory = 'Semua';
  double _zoomScale = 0.0;
  double _zoomAtGestureStart = 0.0;

  final List<String> _categories = const [
    'Semua',
    'Mine Permit',
    'Absen Acara',
    'P2H Sarana',
    'Tagging Lokasi',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
      ],
    );

    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _checkPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isPermissionGranted) return;
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (mounted) {
      setState(() {
        _isPermissionGranted = status.isGranted;
        _isCheckingPermission = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _isPermissionGranted = status.isGranted;
      });
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;

      setState(() => _isProcessing = true);
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}

      await _controller.stop();

      if (!mounted) return;

      final scanResult = _ScanResult(
        value: value,
        format: barcode.format.name.toUpperCase(),
      );

      final scanType = _selectedCategory == 'Semua' ? 'General Scan' : _selectedCategory;
      await _showScanResult(context, scanType, scanResult);

      if (mounted) {
        setState(() => _isProcessing = false);
        await _controller.start();
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (!_isPermissionGranted) {
      return _buildPermissionView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview with Pinch-to-Zoom
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) {
              _zoomAtGestureStart = _zoomScale;
            },
            onScaleUpdate: (details) {
              final newZoom = (_zoomAtGestureStart + (details.scale - 1.0) * 0.5)
                  .clamp(0.0, 1.0);
              setState(() => _zoomScale = newZoom);
              _controller.setZoomScale(newZoom);
            },
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),

          // 2. High-Tech Industrial Reticle & Viewfinder Cutout
          _buildReticleOverlay(),

          // 3. Top Floating Enterprise Header & Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopHeader(),
          ),

          // 4. Bottom Category Selector & Context Info
          Positioned(
            left: 0,
            right: 0,
            bottom: 110, // Memberikan ruang di atas BottomNav
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  /// Tampilan ketika izin kamera belum diberikan
  Widget _buildPermissionView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF38BDF8),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Izin Kamera Diperlukan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Aplikasi membutuhkan izin kamera untuk memindai barcode Mine Permit, presensi kegiatan briefing, dan validasi unit sarana operasional di lapangan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _requestPermission,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text(
                  'Aktifkan Akses Kamera',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reticle Viewfinder & Animasi Laser Scanning
  Widget _buildReticleOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = math.min(constraints.maxWidth * 0.76, 280.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Darkened vignette background with center transparent hole
            Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
            Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // 4 Corner Brackets
                  Positioned(top: 0, left: 0, child: _buildCornerBracket(top: true, left: true)),
                  Positioned(top: 0, right: 0, child: _buildCornerBracket(top: true, left: false)),
                  Positioned(bottom: 0, left: 0, child: _buildCornerBracket(top: false, left: true)),
                  Positioned(bottom: 0, right: 0, child: _buildCornerBracket(top: false, left: false)),

                  // Animated Scanning Laser Bar
                  AnimatedBuilder(
                    animation: _scanAnimCtrl,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanAnimCtrl.value * (boxSize - 4),
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF38BDF8),
                                Color(0xFF60A5FA),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
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
          ],
        );
      },
    );
  }

  Widget _buildCornerBracket({required bool top, required bool left}) {
    const size = 26.0;
    const thickness = 3.5;
    const color = Color(0xFF38BDF8);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          bottom: !top ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          left: left ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          right: !left ? const BorderSide(color: color, width: thickness) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(16) : Radius.zero,
          topRight: top && !left ? const Radius.circular(16) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(16) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(16) : Radius.zero,
        ),
      ),
    );
  }

  /// Top Bar: Title & Quick Torch / Switch Controls
  Widget _buildTopHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Corporate Title Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'SafeScan Enterprise',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // Controls: Torch & Camera Switch
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCircleButton(
                  icon: Icons.flash_on_rounded,
                  tooltip: 'Flash',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.toggleTorch();
                  },
                ),
                const SizedBox(width: 10),
                _buildCircleButton(
                  icon: Icons.cameraswitch_rounded,
                  tooltip: 'Ganti Kamera',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.switchCamera();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Bottom Category Chips & Operational Instruction
  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Horizontal Operational Category Filter
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selectedCategory;

              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                },
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                selectedColor: const Color(0xFF2563EB),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Contextual Mining Field Instruction
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _getCategoryInstruction(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getCategoryInstruction() {
    switch (_selectedCategory) {
      case 'Mine Permit':
        return 'Arahkan kamera ke QR Code Mine Permit untuk validasi izin & status K3 karyawan.';
      case 'Absen Acara':
        return 'Pindai barcode/QR presensi briefing 5M, toolbox meeting, atau pelatihan.';
      case 'P2H Sarana':
        return 'Pindai stiker barcode unit armada atau LV untuk validasi kelaikan operasional.';
      case 'Tagging Lokasi':
        return 'Pindai plat QR titik pantau keselamatan di area kerja tambang.';
      default:
        return 'Arahkan kamera ke barcode atau QR code untuk pemindaian instan.';
    }
  }

  Future<void> _showScanResult(
    BuildContext context,
    String scanType,
    _ScanResult result,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: FutureBuilder(
          future: ApiService().scanQr(result.value, scanType: scanType),
          builder: (context, snapshot) {
            Map? apiData;
            String message = 'Kode Berhasil Dipindai';
            String actionType = 'General';
            bool isSuccess = true;

            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              snapshot.data?.fold((err) {
                isSuccess = false;
                message = err['message']?.toString() ?? 'Gagal memproses kode';
              }, (data) {
                apiData = data['data'] as Map?;
                message = data['message']?.toString() ?? 'Kode Berhasil Dipindai';
                actionType = data['actionType']?.toString() ?? 'General';
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                4,
                22,
                22 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                    const SizedBox(height: 16),
                    const Text(
                      'Memverifikasi ke server...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$scanType • ${result.format}',
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (apiData != null && actionType == 'MinePermit') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    apiData!['nama']?.toString() ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (apiData!['status_aktif'] == 'AKTIF')
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (apiData!['status_aktif'] == 'AKTIF')
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Text(
                                    apiData!['status_aktif']?.toString() ?? 'NONAKTIF',
                                    style: TextStyle(
                                      color: (apiData!['status_aktif'] == 'AKTIF')
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFDC2626),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'NIK: ${apiData!['nik']} • ${apiData!['jabatan']}',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Perusahaan: ${apiData!['perusahaan']}',
                              style: TextStyle(
                                color: Colors.blueGrey.shade600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SelectableText(
                          result.value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: result.value),
                            );
                            if (!sheetContext.mounted) return;
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Kode berhasil disalin.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Salin', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScanResult {
  const _ScanResult({required this.value, required this.format});

  final String value;
  final String format;
}
