import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

class P2hShareService {
  /// Mengunduh gambar untuk disematkan dalam PDF (lokal atau remote)
  static Future<Uint8List?> _fetchImageBytes(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    try {
      final file = File(imagePath.trim());
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      var url = imagePath.trim();
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
      debugPrint('[P2H-IMAGE-ERROR] $e');
    }
    return null;
  }

  /// Evaluasi kelayakan unit berdasarkan checklist
  static Map<String, dynamic> evaluateVehicleCondition(Map<String, dynamic> data) {
    List<dynamic> golA = _parseChecklist(data['gol_a_json'] ?? data['golA']);
    List<dynamic> golB = _parseChecklist(data['gol_b_json'] ?? data['golB']);
    List<dynamic> golC = _parseChecklist(data['gol_c_json'] ?? data['golC']);

    final defectsA = golA.where((item) => item['status'] == 'NOT_GOOD').toList();
    final defectsB = golB.where((item) => item['status'] == 'NOT_GOOD').toList();
    final defectsC = golC.where((item) => item['status'] == 'NOT_GOOD').toList();

    String statusText;
    Color statusColor;
    bool isOperational;

    if (defectsA.isNotEmpty) {
      statusText = 'TIDAK LAYAK OPERASI (STOP)';
      statusColor = const Color(0xFFDC2626); // Red
      isOperational = false;
    } else if (defectsB.isNotEmpty || defectsC.isNotEmpty) {
      statusText = 'PERLU PERBAIKAN';
      statusColor = const Color(0xFFD97706); // Amber
      isOperational = true;
    } else {
      statusText = 'LAYAK OPERASI';
      statusColor = const Color(0xFF16A34A); // Green
      isOperational = true;
    }

    return {
      'statusText': statusText,
      'statusColor': statusColor,
      'isOperational': isOperational,
      'defectsA': defectsA,
      'defectsB': defectsB,
      'defectsC': defectsC,
      'totalDefects': defectsA.length + defectsB.length + defectsC.length,
      'golA': golA,
      'golB': golB,
      'golC': golC,
    };
  }

  static List<dynamic> _parseChecklist(dynamic jsonVal) {
    if (jsonVal == null) return [];
    if (jsonVal is List) return jsonVal;
    try {
      final s = jsonVal.toString().trim();
      if (s.isEmpty) return [];
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded;
    } catch (_) {}
    return [];
  }

  /// Membuat format teks ringkasan untuk WhatsApp
  static String formatWhatsAppSummary(Map<String, dynamic> data) {
    final eval = evaluateVehicleCondition(data);
    final noLambung = (data['no_lambung_kendaraan'] ?? data['no_lambung'] ?? data['noLambung'] ?? '-').toString().toUpperCase();
    final merek = data['merek_kendaraan'] ?? data['merek'] ?? '-';
    final jenis = data['jenis_kendaraan'] ?? data['jenisKendaraan'] ?? '-';
    final km = (data['km'] ?? data['kilometer'] ?? 0) as num;
    final tanggal = data['date'] ?? data['tanggal'] ?? '-';
    final waktu = data['time'] ?? data['waktu'] ?? '-';
    final nama = data['nama'] ?? data['employee_name'] ?? 'Pemeriksa P2H';
    final nik = data['nik'] ?? data['employee_nik'] ?? '-';
    final simper = data['simper_kimper'] ?? ((data['simper'] == 1) ? 'YA' : 'TIDAK');

    final kmFormatted = NumberFormat("#,##0", "id_ID").format(km);

    final sb = StringBuffer();
    sb.writeln('📋 *FORM PEMERIKSAAN HARIAN KENDARAAN (P2H)*');
    sb.writeln('*PT INDEXIM COALINDO*');
    sb.writeln('----------------------------------------');
    sb.writeln('🚗 *No. Lambung:* $noLambung');
    sb.writeln('🏷️ *Merek / Tipe:* $merek');
    sb.writeln('🚙 *Jenis:* $jenis');
    sb.writeln('⚡ *Odometer / KM:* $kmFormatted KM');
    sb.writeln('🪪 *SIMPER / KIMPER Aktif:* $simper');
    sb.writeln('📅 *Waktu P2H:* $tanggal $waktu');
    sb.writeln('👤 *Pemeriksa:* $nama ($nik)');
    sb.writeln('----------------------------------------');
    sb.writeln('📊 *STATUS KELAYAKAN UNIT:*');
    if (eval['defectsA'].isNotEmpty) {
      sb.writeln('🔴 *${eval['statusText']}*');
    } else if (eval['totalDefects'] > 0) {
      sb.writeln('🟡 *${eval['statusText']}*');
    } else {
      sb.writeln('🟢 *${eval['statusText']}* (Semua Baik)');
    }

    if (eval['totalDefects'] > 0) {
      sb.writeln('\n⚠️ *Daftar Temuan Kerusakan (${eval['totalDefects']} Item):*');
      for (var d in eval['defectsA']) {
        sb.writeln('• [GOL A - Kritis] ${d['name'] ?? d['Name']}');
      }
      for (var d in eval['defectsB']) {
        sb.writeln('• [GOL B - Penting] ${d['name'] ?? d['Name']}');
      }
      for (var d in eval['defectsC']) {
        sb.writeln('• [GOL C - Umum] ${d['name'] ?? d['Name']}');
      }
    } else {
      sb.writeln('Semua 37 item checklist (Gol A, B, C) dalam kondisi BAIK.');
    }

    sb.writeln('----------------------------------------');
    sb.writeln('_Dikirim via Aplikasi Mobile Indexsafe Evolution_');
    return sb.toString();
  }

  /// Membagikan teks ringkasan langsung ke WhatsApp
  static Future<void> shareToWhatsApp(Map<String, dynamic> data) async {
    final text = formatWhatsAppSummary(data);
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

  /// Menghasilkan Dokumen PDF Lengkap Laporan P2H
  static Future<Uint8List> generateP2hPdfBytes(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final eval = evaluateVehicleCondition(data);

    final noLambung = (data['no_lambung_kendaraan'] ?? data['no_lambung'] ?? data['noLambung'] ?? '-').toString().toUpperCase();
    final merek = (data['merek_kendaraan'] ?? data['merek'] ?? '-').toString();
    final jenis = (data['jenis_kendaraan'] ?? data['jenisKendaraan'] ?? '-').toString();
    final km = (data['km'] ?? data['kilometer'] ?? 0) as num;
    final tanggal = (data['date'] ?? data['tanggal'] ?? '-').toString();
    final waktu = (data['time'] ?? data['waktu'] ?? '-').toString();
    final nama = (data['nama'] ?? data['employee_name'] ?? 'LULUS BAGOS HERMAWAN').toString();
    final nik = (data['nik'] ?? data['employee_nik'] ?? '-').toString();
    final simper = (data['simper_kimper'] ?? ((data['simper'] == 1) ? 'YA' : 'TIDAK')).toString();
    final speedoImgBytes = await _fetchImageBytes(data['foto_speedometer'] ?? data['image']);

    final kmFormatted = NumberFormat("#,##0", "id_ID").format(km);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PT INDEXIM COALINDO',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'FORM PEMERIKSAAN KELAYAKAN KENDARAAN (P2H)',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                      pw.Text(
                        'Standard OHS - Mobile & Web Integrated System',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: eval['defectsA'].isNotEmpty
                          ? PdfColors.red50
                          : (eval['totalDefects'] > 0 ? PdfColors.amber50 : PdfColors.green50),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(
                        color: eval['defectsA'].isNotEmpty
                            ? PdfColors.red700
                            : (eval['totalDefects'] > 0 ? PdfColors.amber700 : PdfColors.green700),
                      ),
                    ),
                    child: pw.Text(
                      eval['statusText'] as String,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: eval['defectsA'].isNotEmpty
                            ? PdfColors.red800
                            : (eval['totalDefects'] > 0 ? PdfColors.amber900 : PdfColors.green800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // Metadata Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfMetaRow('No. Lambung', noLambung, isBold: true),
                        _buildPdfMetaRow('Merek / Tipe', merek),
                        _buildPdfMetaRow('Jenis Kendaraan', jenis),
                        _buildPdfMetaRow('Odometer (KM)', '$kmFormatted KM', isBold: true),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfMetaRow('Tanggal / Jam', '$tanggal $waktu'),
                        _buildPdfMetaRow('Pemeriksa (Driver)', nama),
                        _buildPdfMetaRow('NIK Driver', nik),
                        _buildPdfMetaRow('SIMPER / KIMPER', simper),
                      ],
                    ),
                  ),
                  if (speedoImgBytes != null) ...[
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Image(pw.MemoryImage(speedoImgBytes), fit: pw.BoxFit.cover),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // Checklist Tables
            _buildPdfChecklistSection('GOLONGAN A - KRITIS (16 ITEM - STOP OPERASI BILA RUSAK)', eval['golA'] as List, PdfColors.red800),
            pw.SizedBox(height: 10),
            _buildPdfChecklistSection('GOLONGAN B - PENTING (10 ITEM)', eval['golB'] as List, PdfColors.amber800),
            pw.SizedBox(height: 10),
            _buildPdfChecklistSection('GOLONGAN C - UMUM (11 ITEM)', eval['golC'] as List, PdfColors.blue800),

            pw.SizedBox(height: 16),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  width: 180,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Pengemudi / Pemeriksa', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 35),
                      pw.Text(nama, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('NIK. $nik', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Container(
                  width: 180,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Pengawas / Foreman OHS', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 35),
                      pw.Text('_______________________', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Tanda Tangan & Cap', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildPdfMetaRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfChecklistSection(String title, List items, PdfColor accentColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: accentColor,
            borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text('KONDISI', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ],
          ),
        ),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: items.asMap().entries.map((e) {
              final idx = e.key + 1;
              final item = e.value as Map;
              final name = item['name'] ?? item['Name'] ?? '';
              final isGood = (item['status'] ?? item['Status']) == 'GOOD';
              final isEven = e.key % 2 == 0;

              return pw.Container(
                color: isEven ? PdfColors.white : PdfColors.grey50,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 20, child: pw.Text('$idx.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700))),
                    pw.Expanded(
                      child: pw.Text(name.toString(), style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: pw.BoxDecoration(
                        color: isGood ? PdfColors.green100 : PdfColors.red100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        isGood ? 'BAIK' : 'RUSAK',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: isGood ? PdfColors.green900 : PdfColors.red900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Membagikan PDF via Android native Share Intent
  static Future<void> shareP2hPdf(Map<String, dynamic> data) async {
    final pdfBytes = await generateP2hPdfBytes(data);
    final noLambung = (data['no_lambung_kendaraan'] ?? data['no_lambung'] ?? data['noLambung'] ?? 'Unit').toString().replaceAll(' ', '_');
    final date = (data['date'] ?? data['tanggal'] ?? 'Report').toString().replaceAll('-', '');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'P2H_${noLambung}_$date.pdf',
    );
  }

  /// Menampilkan modal bottom sheet berbagi lengkap
  static void showShareModal(BuildContext context, Map<String, dynamic> data) {
    final eval = evaluateVehicleCondition(data);
    final noLambung = (data['no_lambung_kendaraan'] ?? data['no_lambung'] ?? data['noLambung'] ?? '-').toString().toUpperCase();

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
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bagikan Laporan P2H: $noLambung',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Status: ${eval['statusText']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: eval['statusColor'] as Color,
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
                    shareToWhatsApp(data);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0284C7)),
                  ),
                  title: const Text('Bagikan Dokumen PDF Resmi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Format standar PT Indexim Coalindo (Cetak/WA/Email)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    shareP2hPdf(data);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
