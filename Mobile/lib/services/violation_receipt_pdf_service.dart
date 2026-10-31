import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ViolationReceiptPdfService {
  static Future<String> create(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final reference =
        'PLG-${now.millisecondsSinceEpoch.toString().substring(5)}';
    final rows = <List<String>>[
      ['Nomor bukti', reference],
      [
        'Waktu dibuat',
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
      ],
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
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BUKTI PENCATATAN PELANGGARAN K3',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('IndexSafe Evolution',
                style: const pw.TextStyle(color: PdfColors.blueGrey700)),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                border: pw.Border.all(color: PdfColors.orange300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Status: tersimpan di perangkat. Dokumen akan tercatat resmi setelah laporan berhasil dikirim ke server.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Table.fromTextArray(
              data: rows,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              border: pw.TableBorder.all(color: PdfColors.blueGrey200),
              columnWidths: {0: const pw.FixedColumnWidth(105)},
            ),
            pw.Spacer(),
            pw.Text('Dokumen cadangan dibuat otomatis oleh aplikasi.',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
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
