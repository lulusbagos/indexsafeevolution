import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../../models/document_model.dart';
import '../../services/document_management_service.dart';

/// Halaman In-App Document Viewer resmi ONE EV / Indexsafe Evolution.
/// Memungkinkan pengguna melihat dan membaca dokumen PDF langsung di dalam aplikasi
/// tanpa harus mengunduh file secara manual ke penyimpanan HP terlebih dahulu.
class DocumentViewerPage extends StatefulWidget {
  final DocumentItemModel doc;

  const DocumentViewerPage({super.key, required this.doc});

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  final DocumentManagementService _service = DocumentManagementService.instance;

  bool _isLoading = true;
  String _loadingMessage = 'Menyiapkan berkas dokumen...';
  double _downloadProgress = 0.0;
  String? _errorMessage;

  Uint8List? _pdfBytes;
  String? _localFilePath;

  bool get _isPdf => widget.doc.fileType.toLowerCase() == 'pdf';

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
      _loadingMessage = 'Menghubungkan ke repositori ONE EV...';
    });

    try {
      // 1. Periksa apakah sudah ada di local cache
      if (widget.doc.localPath != null && widget.doc.localPath!.isNotEmpty) {
        final cached = File(widget.doc.localPath!);
        if (await cached.exists() && await cached.length() > 0) {
          _localFilePath = cached.path;
          if (_isPdf) {
            final bytes = await cached.readAsBytes();
            if (mounted) {
              setState(() {
                _pdfBytes = bytes;
                _isLoading = false;
              });
              return;
            }
          } else {
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }
      }

      // 2. Unduh stream berkas on-demand ke memory / temporary cache
      final path = await _service.downloadFile(
        widget.doc,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() {
              _downloadProgress = received / total;
              final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
              final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
              _loadingMessage = 'Membuka dokumen... $recMb MB / $totMb MB (${(_downloadProgress * 100).toInt()}%)';
            });
          }
        },
      );

      if (path != null && await File(path).exists()) {
        _localFilePath = path;
        widget.doc.localPath = path;
        widget.doc.isDownloaded = true;

        if (_isPdf) {
          final bytes = await File(path).readAsBytes();
          if (mounted) {
            setState(() {
              _pdfBytes = bytes;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Gagal memuat dokumen dari server. Periksa koneksi internet Anda.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Terjadi kendala saat membuka dokumen: $e';
        });
      }
    }
  }

  Future<void> _openExternalApp() async {
    if (_localFilePath != null && await File(_localFilePath!).exists()) {
      final res = await OpenFilex.open(_localFilePath!);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Keterangan: ${res.message}'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.doc.title.isNotEmpty ? widget.doc.title : widget.doc.fileName;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF334155)),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${widget.doc.fileType.toUpperCase()} • ${widget.doc.formattedSize} • Repositori Resmi',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          if (_localFilePath != null)
            IconButton(
              tooltip: 'Buka di Aplikasi Eksternal',
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.open_in_new_rounded, size: 17, color: Color(0xFF0284C7)),
              ),
              onPressed: _openExternalApp,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (_downloadProgress > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 220,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gagal Membuka Dokumen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDocument,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // A. Preview Dokumen PDF langsung di dalam aplikasi
    if (_isPdf && _pdfBytes != null) {
      return PdfPreview(
        build: (format) => _pdfBytes!,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: widget.doc.fileName,
        scrollViewDecoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
        ),
      );
    }

    // B. Dokumen Non-PDF (DOCX, XLSX)
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.description_rounded, color: Color(0xFF0284C7), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                widget.doc.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Berkas ${widget.doc.fileType.toUpperCase()} (${widget.doc.formattedSize}) siap dibuka di aplikasi dokumen HP Anda (Microsoft Office / Google Docs).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _openExternalApp,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Buka di Aplikasi Dokumen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
