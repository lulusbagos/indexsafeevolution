import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../widgets/top_bar.dart';
import 'rci_model.dart';

class RciPdfPage extends StatelessWidget {
  const RciPdfPage(this.item, {super.key});

  final RciReportItem item;

  @override
  Widget build(BuildContext context) {
    final title = 'Laporan RCI #${item.id > 0 ? item.id : 'DRAFT'}';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TopBar(title: title, back: 2),
      body: PdfPreview(
        build: _buildPdf,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'RCI_${item.id > 0 ? item.id : 'DRAFT'}_${DateFormat('yyyyMMdd').format(item.tanggal)}.pdf',
      ),
    );
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/indexsafe-logo-text.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pw.MemoryImage? roadPhoto;
    if (item.fotoUrl != null && item.fotoUrl!.isNotEmpty) {
      try {
        final path = item.fotoUrl!;
        if (File(path).existsSync()) {
          roadPhoto = pw.MemoryImage(await File(path).readAsBytes());
        }
      } catch (_) {}
    }

    const navy = PdfColor.fromInt(0xFF123B63);
    const blue = PdfColor.fromInt(0xFF1D4ED8);
    const emerald = PdfColor.fromInt(0xFF10B981);
    const amber = PdfColor.fromInt(0xFFF59E0B);
    const rose = PdfColor.fromInt(0xFFEF4444);
    const grey = PdfColor.fromInt(0xFF64748B);
    const line = PdfColor.fromInt(0xFFE2E8F0);
    const bgSoft = PdfColor.fromInt(0xFFF8FAFC);

    PdfColor scoreColor;
    if (item.achievement >= 85 || item.actualRoadScore >= 3.6) {
      scoreColor = emerald;
    } else if (item.achievement >= 70 || item.actualRoadScore >= 3.0) {
      scoreColor = amber;
    } else {
      scoreColor = rose;
    }

    final doc = pw.Document(
      title: 'Laporan RCI #${item.id}',
      author: 'SAP - PT INDEXIM COALINDO',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logo != null) pw.Image(logo, width: 120) else pw.Text('INDEXSAFE', style: pw.TextStyle(color: navy, fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('STANDAR SP3 - ROAD CONDITION INDEX', style: const pw.TextStyle(color: grey, fontSize: 8)),
                  pw.Text('No: RCI-${item.id > 0 ? item.id : 'DRAFT'}-${DateFormat('yyyyMMdd').format(item.tanggal)}', style: pw.TextStyle(color: navy, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
        footer: (c) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: line))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dokumen Resmi Penilaian Kondisi Jalan Angkut • PT INDEXIM COALINDO',
                style: const pw.TextStyle(color: grey, fontSize: 7),
              ),
              pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(color: grey, fontSize: 8)),
            ],
          ),
        ),
        build: (_) => [
          // Title Banner
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'BERITA ACARA EVALUASI KONDISI JALAN (RCI)',
                  style: pw.TextStyle(color: navy, fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Road Condition Index Assessment Sesuai Ketentuan SP3',
                  style: const pw.TextStyle(color: grey, fontSize: 9),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Score Highlight Card
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgSoft,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: line),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('ACTUAL ROAD SCORE', style: const pw.TextStyle(color: grey, fontSize: 8)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${item.actualRoadScore.toStringAsFixed(2)} / 4.00',
                      style: pw.TextStyle(color: scoreColor, fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Container(width: 1, height: 32, color: line),
                pw.Column(
                  children: [
                    pw.Text('ACHIEVEMENT', style: const pw.TextStyle(color: grey, fontSize: 8)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${item.achievement.toStringAsFixed(1)}%',
                      style: pw.TextStyle(color: scoreColor, fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Container(width: 1, height: 32, color: line),
                pw.Column(
                  children: [
                    pw.Text('PREDIKAT KONDISI', style: const pw.TextStyle(color: grey, fontSize: 8)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      item.kategoriIndex.toUpperCase(),
                      style: pw.TextStyle(color: scoreColor, fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Container(width: 1, height: 32, color: line),
                pw.Column(
                  children: [
                    pw.Text('STATUS LAPORAN', style: const pw.TextStyle(color: grey, fontSize: 8)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      item.status.toUpperCase(),
                      style: pw.TextStyle(
                        color: (item.status == 'Approved' || item.status == 'Closed') ? emerald : amber,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // 3 Pilar Weights Summary
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFEFF6FF),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('Pilar 1 - Permukaan (60%): ${item.skorPermukaanGroup.toStringAsFixed(2)}', style: pw.TextStyle(color: blue, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Pilar 2 - Safety Berm (20%): ${item.skorSafetyBermGroup.toStringAsFixed(2)}', style: pw.TextStyle(color: emerald, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Pilar 3 - Drainage (20%): ${item.skorDrainageGroup.toStringAsFixed(2)}', style: pw.TextStyle(color: const PdfColor.fromInt(0xFF0284C7), fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Informasi Segmen Jalan
          _pdfSection('IDENTITAS RUAS JALAN & SEGMEN', [
            _pdfRow('Ruas / Jalur Hauling', item.namaJalan ?? item.lokasi),
            _pdfRow('Segmen / Sta', item.segmentJalan ?? '-'),
            _pdfRow('Panjang Segmen', '${item.panjangSegment?.toStringAsFixed(0) ?? '100'} Meter (Standar SP3)'),
            _pdfRow('Shift Operasional', item.shift ?? '-'),
            _pdfRow('Tanggal & Waktu Sidak', '${DateFormat('dd MMMM yyyy').format(item.tanggal)} • ${item.waktu} WITA'),
            _pdfRow('Area / Lokasi GPS', '${item.area} • GPS: ${item.latitude ?? '-'}, ${item.longitude ?? '-'}'),
            _pdfRow('Perusahaan Pengawas', '${item.perusahaan ?? '-'} (${item.departemen ?? '-'})'),
          ]),
          pw.SizedBox(height: 12),

          // Technical Parameter Details Table
          pw.Text('RINCIAN PENILAIAN 8 PARAMETER TEKNIS', style: pw.TextStyle(color: navy, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: line),
            columnWidths: const {
              0: pw.FixedColumnWidth(25),
              1: pw.FlexColumnWidth(3),
              2: pw.FixedColumnWidth(45),
              3: pw.FixedColumnWidth(55),
              4: pw.FixedColumnWidth(65),
              5: pw.FixedColumnWidth(40),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
                children: [
                  _cell('No', bold: true, align: pw.TextAlign.center),
                  _cell('Parameter Teknis', bold: true),
                  _cell('Bobot', bold: true, align: pw.TextAlign.center),
                  _cell('Defisit (m)', bold: true, align: pw.TextAlign.center),
                  _cell('% Bebas Def', bold: true, align: pw.TextAlign.center),
                  _cell('Skor', bold: true, align: pw.TextAlign.center),
                ],
              ),
              _paramPdfRow(1, 'Surfacing and Material', '20%', item.defisitSurfacing, item.panjangSegment ?? 100, item.skorSurfacing),
              _paramPdfRow(2, 'Undulation / Corrugation (Keriting)', '35%', item.defisitUndulation, item.panjangSegment ?? 100, item.skorUndulation),
              _paramPdfRow(3, 'Spoil / Spillage Batubara/Mud', '5%', item.defisitSpoil, item.panjangSegment ?? 100, item.skorSpoil),
              _paramPdfRow(4, 'Safety Berm (Tinggi, Kemiringan, Rapi)', '10%', item.defisitSafetyBerm, item.panjangSegment ?? 100, item.skorSafetyBerm),
              _paramPdfRow(5, 'Road Attachment / Rambu & Reflektor', '5%', item.defisitRoadAttachment, item.panjangSegment ?? 100, item.skorRoadAttachment),
              _paramPdfRow(6, 'Pengendalian Debu & Water Truck', '5%', item.defisitDust, item.panjangSegment ?? 100, item.skorDust),
              _paramPdfRow(7, 'Crossfall Melintang (0.5% - 1%)', '10%', item.defisitCrossfall, item.panjangSegment ?? 100, item.skorCrossfall),
              _paramPdfRow(8, 'Parit & Tali Air Drainase', '10%', item.defisitDrainage, item.panjangSegment ?? 100, item.skorDrainage),
            ],
          ),
          pw.SizedBox(height: 14),

          // Observasi & Rekomendasi
          _pdfSection('TEMUAN OBSERVASI & TINDAKAN PERBAIKAN', [
            _pdfRow('Catatan Kondisi Lapangan', item.catatan ?? '-'),
            _pdfRow('Rekomendasi Tindakan', item.tindakanPerbaikan ?? '-'),
            _pdfRow('PIC Tindakan (Data SAP)', item.pic ?? '-'),
          ]),
          pw.SizedBox(height: 12),

          // Foto Dokumentasi (jika ada)
          if (roadPhoto != null) ...[
            pw.Text('DOKUMENTASI FOTO KONDISI JALAN', style: pw.TextStyle(color: navy, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Container(
              height: 160,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: line),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Center(child: pw.Image(roadPhoto, fit: pw.BoxFit.contain)),
            ),
            pw.SizedBox(height: 14),
          ],

          // Lembar Pengesahan Berita Acara
          pw.Text('LEMBAR PENGESAHAN TIM SIDAK & PENYETUJU (STANDAR SP3)', style: pw.TextStyle(color: navy, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: line), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Creator column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DIBUAT OLEH (TIM SIDAK):', style: const pw.TextStyle(color: grey, fontSize: 8)),
                      pw.SizedBox(height: 4),
                      pw.Text(item.creatorsSummary ?? item.nama, style: pw.TextStyle(color: navy, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text('Perusahaan: ${item.perusahaan ?? '-'}', style: const pw.TextStyle(color: grey, fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 140, height: 1, color: line),
                      pw.SizedBox(height: 2),
                      pw.Text('Status: Confirmed / Diajukan', style: pw.TextStyle(color: blue, fontSize: 7, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                ),
                pw.Container(width: 1, height: 70, color: line),
                pw.SizedBox(width: 16),
                // Approver column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DISETUJUI OLEH (APPROVER):', style: const pw.TextStyle(color: grey, fontSize: 8)),
                      pw.SizedBox(height: 4),
                      pw.Text(item.approversSummary ?? 'Belum Ditentukan', style: pw.TextStyle(color: navy, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      if (item.approvedAt != null)
                        pw.Text('Tanggal Setuju: ${DateFormat('dd MMM yyyy, HH:mm').format(item.approvedAt!)} WITA', style: const pw.TextStyle(color: grey, fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 140, height: 1, color: line),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        (item.status == 'Approved' || item.status == 'Closed') ? 'Status: ✓ DISETUJUI & CLOSED' : 'Status: ⏳ MENUNGGU PERSETUJUAN',
                        style: pw.TextStyle(
                          color: (item.status == 'Approved' || item.status == 'Closed') ? emerald : amber,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.TableRow _paramPdfRow(int no, String name, String weight, double defisit, double totalLen, double score) {
    final pct = totalLen > 0 ? ((totalLen - defisit) / totalLen * 100.0).clamp(0.0, 100.0) : 100.0;
    return pw.TableRow(
      children: [
        _cell('$no', align: pw.TextAlign.center),
        _cell(name),
        _cell(weight, align: pw.TextAlign.center),
        _cell('${defisit.toStringAsFixed(0)} m', align: pw.TextAlign.center),
        _cell('${pct.toStringAsFixed(1)}%', align: pw.TextAlign.center),
        _cell(score.toStringAsFixed(1), bold: true, align: pw.TextAlign.center),
      ],
    );
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> rows) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFFCFDFE),
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF1F5F9),
            borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(color: const PdfColor.fromInt(0xFF1E293B), fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        ...rows,
      ],
    ),
  );

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(label, style: const pw.TextStyle(color: PdfColor.fromInt(0xFF64748B), fontSize: 8)),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(color: const PdfColor.fromInt(0xFF0F172A), fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  pw.Widget _cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: const PdfColor.fromInt(0xFF0F172A),
      ),
    ),
  );
}
