import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'preference.dart';

class ViolationReceiptPdfService {
  static Future<String> create(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final reference =
        'PLG-${now.millisecondsSinceEpoch.toString().substring(5)}';
    final activeProfile = PreferenceService.getProfile();
    final enforcerName =
        (data['enforcerName'] ?? activeProfile?.namaLengkap ?? 'Petugas K3')
            .toString();
    final enforcerNik =
        (data['enforcerNik'] ?? activeProfile?.noNik ?? '-').toString();
    final enforcerPosition = (data['enforcerPosition'] ??
            activeProfile?.jabatan ??
            activeProfile?.posisi ??
            '-')
        .toString();
    final mbsLogo = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo_mbs_pdf.png'))
          .buffer
          .asUint8List(),
    );
    final indeximLogo = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo_indexim_pdf.png'))
          .buffer
          .asUint8List(),
    );
    final createdAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WITA';
    final rows = <List<String>>[
      ['Nomor dokumen', reference],
      ['Waktu dibuat', createdAt],
      ['Nama penindak', '$enforcerName ($enforcerNik)'],
      ['Jabatan penindak', enforcerPosition],
      [
        'Karyawan',
        '${data['violatorName'] ?? '-'} (${data['violatorNik'] ?? '-'})'
      ],
      ['Perusahaan', '${data['violatorCompany'] ?? '-'}'],
      ['Departemen', '${data['violatorDepartment'] ?? '-'}'],
      ['Mine Permit', '${data['permitNumber'] ?? '-'}'],
      [
        'Jenis pelanggaran',
        '${data['kriteriaNama'] ?? data['violationType'] ?? '-'}'
      ],
      [
        'Tingkat sanksi',
        '${data['jenisPelanggaranNama'] ?? data['severity'] ?? '-'}'
      ],
      ['Lokasi', '${data['violationLocation'] ?? '-'}'],
      ['Uraian', '${data['violationDescription'] ?? '-'}'],
      ['Tindakan awal', '${data['actionTaken'] ?? '-'}'],
    ];
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 28, 34, 30),
        header: (_) => pw.Column(
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 52,
                  height: 58,
                  child: pw.Image(mbsLogo, fit: pw.BoxFit.contain),
                ),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text('BUKTI PENCATATAN PELANGGARAN K3',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF102A43),
                          )),
                      pw.SizedBox(height: 3),
                      pw.Text('MBS • Menuju Budaya Safety',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColor.fromInt(0xFF527184),
                          )),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 106,
                  height: 42,
                  child: pw.Image(indeximLogo, fit: pw.BoxFit.contain),
                ),
              ],
            ),
            pw.SizedBox(height: 11),
            pw.Container(height: 3, color: PdfColor.fromInt(0xFF0E8B6A)),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey100)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Dokumen cadangan • Indexsafe Evolution',
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.blueGrey600)),
              pw.Text(
                  'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.blueGrey600)),
            ],
          ),
        ),
        build: (_) => [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEAF7F2),
              borderRadius: pw.BorderRadius.circular(7),
              border: pw.Border.all(color: PdfColor.fromInt(0xFF9CD8C4)),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 25,
                  height: 25,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF0E8B6A),
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Text('!',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LAPORAN TERSIMPAN DI PERANGKAT',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColor.fromInt(0xFF0A6951),
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Bukti ini dibuat saat laporan belum tersinkron ke server. Data akan dikirim otomatis saat koneksi tersedia.',
                        style: const pw.TextStyle(
                            fontSize: 8.5, color: PdfColors.blueGrey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('RINGKASAN PELANGGARAN',
              style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF0E8B6A),
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8)),
          pw.SizedBox(height: 7),
          pw.Table.fromTextArray(
            headers: const ['Rincian', 'Informasi'],
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromInt(0xFF102A43)),
            cellStyle:
                const pw.TextStyle(fontSize: 8.8, color: PdfColors.blueGrey800),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey50),
            border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: .6),
            columnWidths: {0: const pw.FixedColumnWidth(112)},
          ),
        ],
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/violation_receipts');
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File('${folder.path}/$reference.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file.path;
  }

  static Future<void> share(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.uri.pathSegments.last,
    );
  }
}
