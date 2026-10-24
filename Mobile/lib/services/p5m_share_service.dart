import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class P5mShareService {
  static const List<Map<String, String>> defaultFitToWorkQuestions = [
    {
      'id': '1',
      'question': 'Apakah Anda dalam keadaan sehat ?',
      'label': 'Kesehatan Fisik',
      'yesLabel': 'YES (SEHAT)',
      'noLabel': 'NO (UNFIT)',
    },
    {
      'id': '2',
      'question': 'Apakah Anda saat ini bebas dari masalah dan beban pikiran sebelum memulai aktivitas kerja ?',
      'label': 'Kesiapan Mental / Beban Pikiran',
      'yesLabel': 'YES (BEBAS)',
      'noLabel': 'NO (TERBEBAN)',
    },
    {
      'id': '3',
      'question': 'Apakah Anda cukup tidur (minimal 6 jam) sebelum memulai shift ?',
      'label': 'Kecukupan Istirahat / Tidur',
      'yesLabel': 'YES (CUKUP)',
      'noLabel': 'NO (KURANG)',
    },
    {
      'id': '4',
      'question': 'Apakah Anda memakai APD lengkap dan layak pakai?',
      'label': 'Kelengkapan & Kelayakan APD',
      'yesLabel': 'YES (LENGKAP)',
      'noLabel': 'NO (TIDAK)',
    },
  ];

  static Map<String, dynamic> evaluateFitStatus(Map<String, dynamic> data) {
    List<String> questions = [];
    List<String> answers = [];

    // Parse from questions_json / answers_json if available
    if (data['questions_json'] != null) {
      try {
        final q = jsonDecode(data['questions_json'].toString());
        if (q is List) questions = q.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    if (data['answers_json'] != null) {
      try {
        final a = jsonDecode(data['answers_json'].toString());
        if (a is List) answers = a.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    if (data['checklist'] is List && (data['checklist'] as List).isNotEmpty) {
      questions.clear();
      answers.clear();
      for (var item in (data['checklist'] as List)) {
        if (item is Map) {
          questions.add(item['question']?.toString() ?? '');
          answers.add(item['answer']?.toString() ?? 'Yes');
        }
      }
    } else if (data['checklist'] is String && (data['checklist'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(data['checklist'].toString());
        if (decoded is List) {
          questions.clear();
          answers.clear();
          for (var item in decoded) {
            if (item is Map) {
              questions.add(item['question']?.toString() ?? '');
              answers.add(item['answer']?.toString() ?? 'Yes');
            }
          }
        }
      } catch (_) {}
    }

    if (questions.isEmpty) {
      questions = defaultFitToWorkQuestions.map((e) => e['question']!).toList();
    }

    bool hasUnfit = false;
    List<Map<String, String>> parsedItems = [];

    for (int i = 0; i < questions.length; i++) {
      final qText = questions[i];
      final ans = (i < answers.length) ? answers[i].trim() : 'Yes';
      final isNo = ans.toLowerCase() == 'no' || ans.toLowerCase() == 'tidak' || ans == '0';
      if (isNo) hasUnfit = true;

      parsedItems.add({
        'question': qText,
        'answer': isNo ? 'NO' : 'YES',
        'isFit': (!isNo).toString(),
      });
    }

    // Direct status flag check if present
    if (data['fit_status'] != null && data['fit_status'].toString().toUpperCase() == 'UNFIT') {
      hasUnfit = true;
    }
    if (data['status'] != null && (data['status'] == 0 || data['status'] == '0')) {
      hasUnfit = true;
    }

    return {
      'isFit': !hasUnfit,
      'statusLabel': !hasUnfit ? 'FIT TO WORK (SIAP BEKERJA)' : 'UNFIT (PERLU TINDAK LANJUT / STOP)',
      'shortStatus': !hasUnfit ? 'FIT' : 'UNFIT',
      'color': !hasUnfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      'items': parsedItems,
    };
  }

  static String formatWhatsAppSummary(Map<String, dynamic> data) {
    final eval = evaluateFitStatus(data);
    final isFit = eval['isFit'] as bool;

    final dateStr = data['date'] ?? data['tanggal'] ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = data['time'] ?? data['waktu'] ?? DateFormat('HH:mm').format(DateTime.now());
    final nama = data['nama'] ?? data['employee_name'] ?? 'Driver/Karyawan';
    final nik = data['nik'] ?? data['no_nik'] ?? '-';
    final area = data['area'] ?? data['area_name'] ?? '-';
    final lokasi = data['lokasi'] ?? data['location_name'] ?? data['location_detail'] ?? '-';
    final topik = data['topik'] ?? data['topic_name'] ?? 'K3 Operasional';
    final judul = data['title'] ?? data['judul'] ?? 'P5M Awal Shift - Siap Bekerja';
    final catatan = data['catatan'] ?? data['remark'] ?? data['keterangan'] ?? '-';

    final buffer = StringBuffer();
    buffer.writeln('*PT INDEXIM COALINDO*');
    buffer.writeln('*LAPORAN FIT TO WORK & P5M (BRIEFING AWAL SHIFT)*');
    buffer.writeln('------------------------------------------');
    buffer.writeln('📅 *Tanggal/Jam*: $dateStr • $timeStr');
    buffer.writeln('👤 *Karyawan / Presenter*: $nama ($nik)');
    buffer.writeln('🏢 *Departemen*: ${data['departemen'] ?? 'OPERASIONAL'}');
    buffer.writeln('📍 *Area*: $area');
    buffer.writeln('🎯 *Lokasi/Benchmark*: $lokasi');
    buffer.writeln('📋 *Topik*: $topik');
    buffer.writeln('🏷️ *Judul*: $judul');
    buffer.writeln('------------------------------------------');
    buffer.writeln('*STATUS EVALUASI KESIAPAN KERJA:*');
    if (isFit) {
      buffer.writeln('🟢 *FIT TO WORK (SIAP BEKERJA)*');
      buffer.writeln('Pekerja dalam kondisi sehat, istirahat cukup, dan APD lengkap.');
    } else {
      buffer.writeln('🔴 *UNFIT (PERLU TINDAK LANJUT / STOP KERJA)*');
      buffer.writeln('⚠️ PERHATIAN: Terdapat kondisi tidak fit atau kurang istirahat/APD!');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('*CHECKLIST KESIAPAN KERJA:*');

    final items = eval['items'] as List<Map<String, String>>;
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      final itemFit = it['isFit'] == 'true';
      final icon = itemFit ? '✅' : '❌';
      buffer.writeln('${i + 1}. ${it['question']}');
      buffer.writeln('   Jawaban: $icon *${it['answer']}*');
    }

    if (catatan.isNotEmpty && catatan != '-' && catatan != '.') {
      buffer.writeln('------------------------------------------');
      buffer.writeln('📝 *Catatan / Tindakan Pencegahan Kecelakaan:*');
      buffer.writeln(catatan);
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('_Laporan dikirim otomatis via Indexsafe Evolution OHS System_');

    return buffer.toString();
  }

  static Future<void> shareToWhatsApp(Map<String, dynamic> data) async {
    final text = formatWhatsAppSummary(data);
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final fallbackUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<Uint8List> generateP5mPdfBytes(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final eval = evaluateFitStatus(data);
    final isFit = eval['isFit'] as bool;

    final dateStr = data['date'] ?? data['tanggal'] ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = data['time'] ?? data['waktu'] ?? DateFormat('HH:mm').format(DateTime.now());
    final nama = data['nama'] ?? data['employee_name'] ?? 'Karyawan';
    final nik = data['nik'] ?? data['no_nik'] ?? '-';
    final dept = data['departemen'] ?? 'OPERASIONAL';
    final area = data['area'] ?? data['area_name'] ?? '-';
    final lokasi = data['lokasi'] ?? data['location_name'] ?? data['location_detail'] ?? '-';
    final topik = data['topik'] ?? data['topic_name'] ?? 'K3 Operasional';
    final judul = data['title'] ?? data['judul'] ?? 'P5M Awal Shift - Siap Bekerja';
    final catatan = data['catatan'] ?? data['remark'] ?? data['keterangan'] ?? '-';

    pw.MemoryImage? photoImage;
    final photoPath = data['foto_kegiatan'] ?? data['image'];
    if (photoPath != null && photoPath.toString().isNotEmpty) {
      try {
        final f = File(photoPath.toString());
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          photoImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    final items = eval['items'] as List<Map<String, String>>;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PT INDEXIM COALINDO',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'FORMULIR FIT TO WORK & PERTEMUAN 5 MENIT (P5M)',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple800,
                        ),
                      ),
                      pw.Text(
                        'Standard OHS - Mobile & Web Integrated System',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: isFit ? PdfColors.green50 : PdfColors.red50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                        color: isFit ? PdfColors.green700 : PdfColors.red700,
                        width: 1.5,
                      ),
                    ),
                    child: pw.Text(
                      isFit ? 'FIT TO WORK' : 'UNFIT (STOP)',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: isFit ? PdfColors.green800 : PdfColors.red800,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),

              // Metadata Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfRow('Nama Karyawan', ': $nama'),
                          _buildPdfRow('NIK / ID', ': $nik'),
                          _buildPdfRow('Departemen', ': $dept'),
                          _buildPdfRow('Tanggal / Jam', ': $dateStr • $timeStr'),
                          _buildPdfRow('Area Utama', ': $area'),
                          _buildPdfRow('Lokasi / Benchmark', ': $lokasi'),
                          _buildPdfRow('Topik Briefing', ': $topik'),
                          _buildPdfRow('Judul P5M', ': $judul'),
                        ],
                      ),
                    ),
                    if (photoImage != null)
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              height: 90,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text('Foto Bukti Briefing P5M', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                'CHECKLIST KELAYAKAN & KESIAPAN KERJA (FIT TO WORK)',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
              ),
              pw.SizedBox(height: 6),

              // Questions Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(26),
                  1: const pw.FlexColumnWidth(8),
                  2: const pw.FixedColumnWidth(70),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Poin Pemeriksaan Kelayakan Kerja', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Jawaban', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                  for (int i = 0; i < items.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(items[i]['question'] ?? '', style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: items[i]['answer'] == 'YES' ? PdfColors.green100 : PdfColors.red100,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text(
                              items[i]['answer'] ?? 'YES',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: items[i]['answer'] == 'YES' ? PdfColors.green900 : PdfColors.red900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Catatan
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.yellow50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.yellow300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Catatan / Tindakan Pencegahan Kecelakaan:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow900)),
                    pw.SizedBox(height: 2),
                    pw.Text(catatan, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Karyawan / Peserta', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 32),
                      pw.Text(nama, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('NIK: $nik', style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Pengawas / Presenter Briefing', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 32),
                      pw.Text('____________________', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Tanda Tangan & Nama Terang', style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Dokumen ini dicetak otomatis dari Sistem Indexsafe Evolution OHS Mobile App PT Indexim Coalindo',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
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
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> shareP5mPdf(Map<String, dynamic> data) async {
    final bytes = await generateP5mPdfBytes(data);
    final nik = data['nik'] ?? data['no_nik'] ?? '000';
    final date = (data['date'] ?? data['tanggal'] ?? 'today').toString().replaceAll('-', '');
    final filename = 'P5M_${nik}_$date.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static void showShareModal(BuildContext context, Map<String, dynamic> data) {
    final eval = evaluateFitStatus(data);
    final statusLabel = eval['statusLabel'] as String;
    final color = eval['color'] as Color;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share_rounded, color: Color(0xFF7C3AED), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bagikan Laporan P5M',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Status: $statusLabel',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF22C55E)),
                ),
                title: const Text(
                  'Kirim Ringkasan Teks ke WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Format ringkas siap kirim ke grup atau atasan',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  shareToWhatsApp(data);
                },
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0284C7)),
                ),
                title: const Text(
                  'Bagikan Dokumen PDF Resmi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Format standar PT Indexim Coalindo (Cetak/WA/Email)',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  shareP5mPdf(data);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
