import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hazard_hub_model.dart';
import 'api.dart';

class HazardPdfService {
  /// Mengunduh gambar dari URL atau file lokal untuk disematkan dalam PDF
  static Future<Uint8List?> _fetchImageBytes(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    try {
      final trimmed = imageUrl.trim();
      final localFile = File(trimmed);
      if (await localFile.exists()) {
        return await localFile.readAsBytes();
      }
      var url = trimmed;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        final apiBase = ApiService().baseUrl;
        if (!url.startsWith('/')) url = '/$url';
        url = '$apiBase$url';
      }
      final dio = Dio(BaseOptions(
        responseType: ResponseType.bytes,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final res = await dio.get<List<int>>(url);
      if (res.data != null && res.data!.isNotEmpty) {
        return Uint8List.fromList(res.data!);
      }
    } catch (e) {
      debugPrint('[PDF-IMAGE-ERROR] $e');
    }
    return null;
  }

  /// Membuat dokumen PDF resmi Laporan Hazard PT Indexim Coalindo
  static Future<Uint8List> generateHazardPdfBytes(HazardReportItem item) async {
    final pdf = pw.Document();

    // Download bukti foto before dan after jika ada
    final fotoTemuanBytes = await _fetchImageBytes(item.fotoTemuan);
    final fotoPerbaikanBytes = await _fetchImageBytes(item.fotoPerbaikan);

    // Format tanggal
    String formattedDate = item.tanggal;
    try {
      final parsedDate = DateTime.parse(item.tanggal);
      formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(parsedDate);
    } catch (_) {
      // Fallback
    }

    // Tentukan warna risiko
    PdfColor riskColor = PdfColors.green700;
    final rLower = item.tingkatResiko.toLowerCase();
    if (rLower.contains('sedang')) {
      riskColor = PdfColors.orange700;
    } else if (rLower.contains('tinggi')) {
      riskColor = PdfColors.red700;
    } else if (rLower.contains('ekstrim')) {
      riskColor = PdfColors.red900;
    }

    // Tentukan warna status
    final isClosed = item.statusTemuan.toLowerCase() == 'closed';
    final statusColor = isClosed ? PdfColors.green700 : PdfColors.amber800;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER KOP SURAT
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PT INDEXIM COALINDO',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'SAFETY ACCOUNTABILITY PROGRAM (SAP)',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Text(
                            'NO: #HZR-${item.id}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // JUDUL LAPORAN & BADGE
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'LAPORAN TEMUAN HAZARD',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Row(
                    children: [
                      // Badge Status
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: statusColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          item.statusTemuan.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      // Badge Risiko
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: riskColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'RISIKO: ${item.tingkatResiko.toUpperCase()}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // TABEL DATA UTAMA
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  children: [
                    _buildPdfRow('Waktu Temuan', '$formattedDate, Pukul ${item.waktu} WITA'),
                    _buildPdfRow('Pelapor', '${item.nama} (NIK: ${item.nik}) - Dept: ${item.departemen ?? '-'}'),
                    _buildPdfRow('Area & Lokasi', '${item.area ?? '-'} / ${item.lokasi ?? '-'}'),
                    if (item.detilLokasi != null && item.detilLokasi!.isNotEmpty)
                      _buildPdfRow('Detil Lokasi', item.detilLokasi!),
                    _buildPdfRow('Kategori Bahaya', item.kategoriBahaya ?? '-'),
                    _buildPdfRow('Jenis Bahaya', '${item.jenisBahaya ?? '-'} ${item.jenisKetidaksesuaian != null && item.jenisKetidaksesuaian!.isNotEmpty ? "(${item.jenisKetidaksesuaian})" : ""}'),
                    _buildPdfRow('PJA Ditunjuk', '${item.pja ?? '-'} ${item.nikPja != null && item.nikPja!.isNotEmpty ? "(NIK: ${item.nikPja})" : ""} - Dept: ${item.departemenPja ?? '-'}'),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // URAIAN TEMUAN
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'URAIAN TEMUAN HAZARD:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      item.temuan,
                      style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.3),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // TINDAKAN PERBAIKAN / PENYELESAIAN
              if ((item.perbaikan != null && item.perbaikan!.isNotEmpty) ||
                  (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.isNotEmpty))
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: isClosed ? PdfColors.green50 : PdfColors.orange50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(
                      color: isClosed ? PdfColors.green200 : PdfColors.orange200,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isClosed ? 'TINDAKAN PERBAIKAN (CLOSED):' : 'RENCANA TINDAKAN LANJUTAN:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: isClosed ? PdfColors.green900 : PdfColors.orange900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        (item.perbaikan != null && item.perbaikan!.isNotEmpty)
                            ? item.perbaikan!
                            : (item.tindakanPerbaikan ?? '-'),
                        style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.3),
                      ),
                    ],
                  ),
                ),

              pw.SizedBox(height: 12),

              // DOKUMENTASI FOTO (BEFORE & AFTER)
              pw.Text(
                'DOKUMENTASI FOTO TEMUAN & PERBAIKAN:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Row(
                children: [
                  // Foto Before (Temuan)
                  pw.Expanded(
                    child: pw.Container(
                      height: 160,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            color: PdfColors.red50,
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'FOTO TEMUAN (BEFORE)',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red800,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: fotoTemuanBytes != null
                                ? pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Image(
                                      pw.MemoryImage(fotoTemuanBytes),
                                      fit: pw.BoxFit.contain,
                                    ),
                                  )
                                : pw.Center(
                                    child: pw.Text(
                                      'Tidak ada foto temuan',
                                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 12),

                  // Foto After (Perbaikan)
                  pw.Expanded(
                    child: pw.Container(
                      height: 160,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            color: isClosed ? PdfColors.green50 : PdfColors.grey200,
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              isClosed ? 'FOTO PERBAIKAN (AFTER)' : 'BELUM ADA PERBAIKAN',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: isClosed ? PdfColors.green800 : PdfColors.grey700,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: fotoPerbaikanBytes != null
                                ? pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Image(
                                      pw.MemoryImage(fotoPerbaikanBytes),
                                      fit: pw.BoxFit.contain,
                                    ),
                                  )
                                : pw.Center(
                                    child: pw.Text(
                                      isClosed
                                          ? 'Perbaikan diselesaikan tanpa foto'
                                          : 'Menunggu penanganan PJA',
                                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // FOOTER TANDA TANGAN
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Pelapor Temuan,', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 32),
                      pw.Text(
                        item.nama,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('NIK: ${item.nik}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Penanggung Jawab Area (PJA),', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 32),
                      pw.Text(
                        item.pja ?? 'Belum Ditunjuk',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('NIK: ${item.nikPja ?? "-"}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Dokumen digital resmi diterbitkan oleh Sistem Mobile Safety Indexsafe Evolution - PT Indexim Coalindo',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Membagikan PDF langsung via WhatsApp / Email / aplikasi lain
  static Future<void> shareHazardPdf(HazardReportItem item) async {
    final pdfBytes = await generateHazardPdfBytes(item);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Hazard_Report_HZR_${item.id}_${item.nik}.pdf',
    );
  }

  /// Menampilkan dialog preview cetak / simpan file
  static Future<void> printHazardPdf(HazardReportItem item) async {
    final pdfBytes = await generateHazardPdfBytes(item);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Hazard_Report_HZR_${item.id}',
    );
  }

  /// Format teks ringkasan untuk WhatsApp
  static String formatWhatsAppSummary(HazardReportItem item) {
    final sb = StringBuffer();
    sb.writeln('⚠️ *LAPORAN TEMUAN HAZARD (K3)*');
    sb.writeln('*PT INDEXIM COALINDO*');
    sb.writeln('----------------------------------------');
    sb.writeln('🆔 *No. Laporan:* #HZR-${item.id}');
    sb.writeln('📅 *Waktu Temuan:* ${item.tanggal} ${item.waktu}');
    sb.writeln('📍 *Area:* ${item.area ?? '-'}');
    sb.writeln('📌 *Lokasi:* ${item.lokasi ?? '-'}');
    if (item.detilLokasi != null && item.detilLokasi!.trim().isNotEmpty && item.detilLokasi != '-') {
      sb.writeln('🔍 *Detil Lokasi:* ${item.detilLokasi}');
    }
    sb.writeln('----------------------------------------');
    sb.writeln('⚡ *Tingkat Risiko:* ${item.tingkatResiko.toUpperCase()}');
    sb.writeln('🏷️ *Status:* ${item.statusTemuan.toUpperCase()}');
    if (item.kategoriBahaya != null && item.kategoriBahaya!.isNotEmpty) {
      sb.writeln('📂 *Kategori:* ${item.kategoriBahaya}');
    }
    if (item.jenisBahaya != null && item.jenisBahaya!.isNotEmpty) {
      sb.writeln('🔥 *Jenis Bahaya:* ${item.jenisBahaya}');
    }
    sb.writeln('----------------------------------------');
    sb.writeln('📝 *Deskripsi Temuan Bahaya:*');
    sb.writeln(item.temuan.trim());
    if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.trim().isNotEmpty) {
      sb.writeln('\n🛠️ *Tindakan Perbaikan:*');
      sb.writeln(item.tindakanPerbaikan!.trim());
    }
    sb.writeln('----------------------------------------');
    sb.writeln('👤 *Pelapor:* ${item.nama} (${item.nik})');
    if (item.pja != null && item.pja!.trim().isNotEmpty && item.pja != '-') {
      sb.writeln('👷 *PJA / PIC:* ${item.pja} (${item.nikPja ?? '-'}) - ${item.departemenPja ?? '-'}');
    }
    sb.writeln('----------------------------------------');
    sb.writeln('_Dikirim via Aplikasi Mobile Indexsafe Evolution_');
    return sb.toString();
  }

  /// Membagikan teks ringkasan langsung ke WhatsApp
  static Future<void> shareToWhatsApp(HazardReportItem item) async {
    final text = formatWhatsAppSummary(item);
    final encoded = Uri.encodeComponent(text);
    final whatsappUri = Uri.parse("whatsapp://send?text=$encoded");
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
        return;
      }
    } catch (_) {}

    final webUri = Uri.parse("https://api.whatsapp.com/send?text=$encoded");
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Menampilkan modal bottom sheet opsi berbagi lengkap
  static void showShareModal(BuildContext context, HazardReportItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share_rounded, color: Color(0xFFEA580C), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bagikan Laporan Hazard #HZR-${item.id}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Risiko: ${item.tingkatResiko} • Status: ${item.statusTemuan}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                  ),
                  title: const Text('Kirim Ringkasan Teks ke WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Format ringkas siap kirim ke grup atau atasan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    shareToWhatsApp(item);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEA580C)),
                  ),
                  title: const Text('Bagikan File PDF Lengkap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Kirim dokumen PDF resmi via WhatsApp / Email', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    shareHazardPdf(item);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.print_rounded, color: Color(0xFF64748B)),
                  ),
                  title: const Text('Cetak / Pratinjau PDF Langsung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Buka viewer cetak printer atau simpan dokumen', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    printHazardPdf(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
