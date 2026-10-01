import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan',
                style: TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pindai barcode atau QR code untuk layanan operasional.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF155EEF), Color(0xFF0B4ACB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33155EEF),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white, size: 88),
                    SizedBox(height: 14),
                    Text(
                      'Arahkan kamera ke kode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Pastikan kode terlihat jelas dan berada di dalam area pemindaian.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFDCE6FF),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Pilih Jenis Scan',
                style: TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _ScanOptionCard(
                icon: Icons.badge_rounded,
                title: 'Mine Permit',
                subtitle: 'Verifikasi mine permit pekerja dengan cepat.',
                color: const Color(0xFF0F9F8F),
                onTap: () => _openScanner(context, 'Mine Permit'),
              ),
              const SizedBox(height: 12),
              _ScanOptionCard(
                icon: Icons.event_available_rounded,
                title: 'Absen Acara',
                subtitle: 'Catat kehadiran peserta pada kegiatan perusahaan.',
                color: const Color(0xFFF08A00),
                onTap: () => _openScanner(context, 'Absen Acara'),
              ),
            ],
          ),
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
          icon: const Icon(Icons.camera_alt_outlined,
              color: Color(0xFF155EEF), size: 36),
          title: const Text('Izin Kamera Diperlukan'),
          content: const Text(
            'Izinkan akses kamera agar MBS SAP dapat memindai barcode atau QR code.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Nanti'),
            ),
            if (permission.isPermanentlyDenied || permission.isRestricted)
              FilledButton(
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
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Memverifikasi ke server...'),
                  ] else ...[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isSuccess ? const Color(0xFFEAFBF3) : const Color(0xFFFEE4E2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: isSuccess ? const Color(0xFF12B76A) : const Color(0xFFD92D20),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$scanType • ${result.format}',
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    if (apiData != null && actionType == 'MinePermit') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF9),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFF99F6E0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              apiData!['nama']?.toString() ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(height: 4),
                            Text('NIK: ${apiData!['nik']} • ${apiData!['jabatan']}'),
                            Text('Perusahaan: ${apiData!['perusahaan']}'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (apiData!['status_aktif'] == 'AKTIF') ? const Color(0xFF12B76A) : const Color(0xFFF04438),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                apiData!['status_aktif']?.toString() ?? 'NONAKTIF',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                        ),
                        child: SelectableText(
                          result.value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF344054),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: result.value),
                            );
                            if (!sheetContext.mounted) return;
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                  content: Text('Kode berhasil disalin.')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Salin'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Selesai'),
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

class _ScanOptionCard extends StatelessWidget {
  const _ScanOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAECF0)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
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
