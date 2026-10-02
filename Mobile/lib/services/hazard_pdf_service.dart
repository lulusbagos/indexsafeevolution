import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/hazard_hub_model.dart';
import 'api.dart';

class HazardPdfService {
  /// Mengunduh gambar dari URL untuk disematkan dalam PDF
  static Future<Uint8List?> _fetchImageBytes(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    try {
      var url = imageUrl.trim();
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
}
