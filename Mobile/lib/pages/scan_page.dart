import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api.dart';
import '../widgets/ambient_background.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    const scanServices = [
      _ScanServiceItem(
        title: 'Mine Permit',
        subtitle: 'Verifikasi ID & Akses K3',
        icon: Icons.badge_rounded,
        accentColor: Color(0xFF0D9488),
        bgColor: Color(0xFFF0FDFA),
        scanType: 'Mine Permit',
      ),
      _ScanServiceItem(
        title: 'Absen Acara',
        subtitle: 'Presensi Rapat & Briefing',
        icon: Icons.event_available_rounded,
        accentColor: Color(0xFFD97706),
        bgColor: Color(0xFFFFFBEB),
        scanType: 'Absen Acara',
      ),
      _ScanServiceItem(
        title: 'P2H Sarana',
        subtitle: 'Validasi Barcode Armada',
        icon: Icons.car_repair_rounded,
        accentColor: Color(0xFF2563EB),
        bgColor: Color(0xFFEFF6FF),
        scanType: 'P2H Unit & LV',
      ),
      _ScanServiceItem(
        title: 'Tagging Lokasi',
        subtitle: 'Validasi Titik Pantau',
        icon: Icons.fmd_good_rounded,
        accentColor: Color(0xFF7C3AED),
        bgColor: Color(0xFFF5F3FF),
        scanType: 'Lokasi & Area',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. EXECUTIVE HEADER BANNER (Consistent Corporate Theme)
                _buildHeaderBanner(),

                const SizedBox(height: 16),

                // 2. QUICK CAMERA LAUNCHER CARD
                _buildQuickScannerCard(context),

                const SizedBox(height: 20),

                // 3. SECTION TITLE
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Kategori Pemindaian',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 4. CLEAN 2-COLUMN GRID (Identical to SAP, OHS, Performance Hub)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 136,
                  ),
                  itemCount: scanServices.length,
                  itemBuilder: (context, index) {
                    final item = scanServices[index];
                    return _buildServiceCard(context, item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header Banner yang Simpel, Bersih, dan Profesional
  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 12, color: Color(0xFF60A5FA)),
                    SizedBox(width: 5),
                    Text(
                      'PT INDEXIM COALINDO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF34D399),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Scanner Siap',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Barcode & QR Scanner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Pindai cepat kode Mine Permit, presensi kegiatan, dan validasi sarana operasional secara instan.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Quick Scanner Interaktif
  Widget _buildQuickScannerCard(BuildContext context) {
    return _AnimatedPressable(
      onTap: () => _openScanner(context, 'General Scan'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF2563EB),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mulai Pemindaian Cepat',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Buka kamera untuk membaca QR code & barcode otomatis.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pindai',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu Modul Pemindaian (Identik dengan tema SAP & OHS)
  Widget _buildServiceCard(BuildContext context, _ScanServiceItem item) {
    return _AnimatedPressable(
      onTap: () => _openScanner(context, item.scanType),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    item.icon,
                    color: item.accentColor,
                    size: 24,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openScanner(BuildContext context, String scanType) async {
    var permission = await Permission.camera.status;
    if (!permission.isGranted) {
      permission = await Permission.camera.request();
    }

    if (!permission.isGranted) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.camera_alt_outlined,
              color: Color(0xFF1E3A8A), size: 36),
          title: const Text('Izin Kamera Diperlukan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: const Text(
            'Izinkan akses kamera agar aplikasi dapat memindai barcode atau QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Nanti'),
            ),
            if (permission.isPermanentlyDenied || permission.isRestricted)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                ),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await openAppSettings();
                },
                child: const Text('Buka Pengaturan'),
              ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final result = await Navigator.push<_ScanResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _BarcodeScannerPage(scanType: scanType),
      ),
    );
    if (result == null || !context.mounted) return;
    await _showScanResult(context, scanType, result);
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
                    const Text('Memverifikasi ke server...',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

class _ScanServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final String scanType;

  const _ScanServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.scanType,
  });
}

/// Widget Interaktif: Animasi Bouncing Scale saat disentuh + Haptic Feedback
class _AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedPressable({
    required this.child,
    required this.onTap,
  });

  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuad,
        child: widget.child,
      ),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage({required this.scanType});

  final String scanType;

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _returningResult = false;
  double _zoomAtGestureStart = 0;

  @override
  void initState() {
    super.initState();
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
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
        BarcodeFormat.aztec,
        BarcodeFormat.codabar,
        BarcodeFormat.itf14,
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_returningResult) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _returningResult = true;
      await _controller.stop();
      if (!mounted) return;
      Navigator.pop(
        context,
        _ScanResult(value: value, format: barcode.format.name.toUpperCase()),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) {
              _zoomAtGestureStart = _controller.value.zoomScale;
            },
            onScaleUpdate: (details) {
              final zoom = (_zoomAtGestureStart + (details.scale - 1) * .5)
                  .clamp(0.0, 1.0);
              _controller.setZoomScale(zoom);
            },
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      _ScannerButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Scan ${widget.scanType}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _ScannerButton(
                        icon: Icons.flash_on_rounded,
                        tooltip: 'Lampu flash',
                        onPressed: _controller.toggleTorch,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 0, 28, 42),
                  child: Text(
                    'Arahkan kamera ke barcode atau QR code. Cubit layar untuk memperbesar atau memperkecil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: SafeArea(
        child: FloatingActionButton.small(
          heroTag: 'switch-scanner-camera',
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF101828),
          onPressed: _controller.switchCamera,
          tooltip: 'Ganti kamera',
          child: const Icon(Icons.cameraswitch_rounded),
        ),
      ),
    );
  }
}

class _ScannerButton extends StatelessWidget {
  const _ScannerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: .42),
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
    );
  }
}

class _ScanResult {
  const _ScanResult({required this.value, required this.format});

  final String value;
  final String format;
}
