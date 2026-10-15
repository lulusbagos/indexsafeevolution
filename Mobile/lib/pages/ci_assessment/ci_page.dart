import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/offline_sync_service.dart';
import '../../widgets/top_bar.dart';
import 'ci_form_page.dart';
import 'ci_model.dart';

const _ciNavy = Color(0xFF123B63);
const _ciBg = Color(0xFFF4F7FA);

class CiAssessmentPage extends StatefulWidget {
  const CiAssessmentPage({super.key});
  @override
  State<CiAssessmentPage> createState() => _CiAssessmentPageState();
}

class _CiAssessmentPageState extends State<CiAssessmentPage> {
  late Future<List<CiAssessment>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = CiStorage.load();
  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _ciBg,
        appBar: const TopBar(title: 'Index Condition'),
        body: FutureBuilder<List<CiAssessment>>(
            future: _future,
            builder: (_, snapshot) {
              final data = snapshot.data ?? const <CiAssessment>[];
              return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _future;
                  },
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                      children: [
                        _hero(data),
                        const SizedBox(height: 20),
                        const Text('Pilih Jenis Assessment',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF172033))),
                        const SizedBox(height: 10),
                        _typeCard(
                            'FCI',
                            'Front Condition Index',
                            'Kesiapan dan kondisi area loading front.',
                            Icons.landscape_rounded,
                            const Color(0xFF0284C7)),
                        _typeCard(
                            'RCI',
                            'Road Condition Index',
                            'Kondisi dan kelayakan ruas jalan operasional.',
                            Icons.add_road_rounded,
                            const Color(0xFFF59E0B)),
                        _typeCard(
                            'DCI',
                            'Disposal Condition Index',
                            'Kesiapan dan kondisi area disposal/dumping.',
                            Icons.terrain_rounded,
                            const Color(0xFF7C3AED)),
                        _typeCard(
                            'SPI',
                            'Sediment Pond Index',
                            'Kondisi kolam sediment, tanggul, dan aliran air.',
                            Icons.water_drop_rounded,
                            const Color(0xFF0EA5A8)),
                        const SizedBox(height: 18),
                        Row(children: [
                          const Expanded(
                              child: Text('Assessment Terbaru',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900))),
                          if (data.isNotEmpty)
                            TextButton(
                                onPressed: () => _open(CiHistoryPage(data)),
                                child: const Text('Lihat Semua'))
                        ]),
                        if (data.isEmpty)
                          _empty()
                        else
                          ...data.take(4).map((e) => _historyTile(e)),
                      ]));
            }),
      );

  Widget _hero(List<CiAssessment> data) {
    final open = data.where((e) => e.status != 'Closed').length;
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_ciNavy, Color(0xFF087A88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33123B63),
                  blurRadius: 18,
                  offset: Offset(0, 8))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.analytics_rounded, color: Colors.white)),
            SizedBox(width: 10),
            Expanded(
                child: Text('Index Condition',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)))
          ]),
          const SizedBox(height: 9),
          const Text(
              'Keputusan operasional berbasis kondisi aktual, kontrol kritis, dan standar teknis aktif.',
              style: TextStyle(color: Color(0xFFD9F4F5), height: 1.4)),
          const SizedBox(height: 18),
          Row(children: [
            _metric('${data.length}', 'Total'),
            _metric('$open', 'Open'),
            _metric(
                '${data.where((e) => e.status == 'Closed').length}', 'Closed')
          ]),
        ]));
  }

  Widget _metric(String value, String label) => Expanded(
      child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13)),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Color(0xFFD9F4F5), fontSize: 11))
          ])));
  Widget _typeCard(String code, String title, String subtitle, IconData icon,
          Color color) =>
      Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: Colors.white,
          child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _open(CiFormPage(code)),
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(children: [
                    Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(16)),
                        child: Icon(icon, color: color, size: 28)),
                    const SizedBox(width: 13),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                  height: 1.3))
                        ])),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.blueGrey)
                  ]))));
  Widget _historyTile(CiAssessment item) {
    final color = _resultColor(item);
    return Card(
        margin: const EdgeInsets.only(bottom: 9),
        elevation: 0,
        child: ListTile(
            onTap: () => _open(CiDetailPage(item)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: .1),
                child: Icon(_typeIcon(item.type), color: color)),
            title: Text(_typeLong(item.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
                '${item.location}\n${DateFormat('dd MMM yyyy, HH:mm').format(item.assessedAt)} • ${item.operationalStatus}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            titleAlignment: ListTileTitleAlignment.center,
            trailing: SizedBox(
              width: 78,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(item.index.toStringAsFixed(0),
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  _ciSyncBadge(item, compact: true),
                ],
              ),
            )));
  }

  Widget _empty() => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: const Column(children: [
        Icon(Icons.assignment_outlined, size: 36, color: Colors.blueGrey),
        SizedBox(height: 8),
        Text('Belum ada assessment',
            style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 3),
        Text(
            'Pilih Front Condition Index, Road Condition Index, atau Disposal Condition Index untuk memulai.',
            style: TextStyle(color: Colors.blueGrey))
      ]));
}

class CiHistoryPage extends StatelessWidget {
  const CiHistoryPage(this.items, {super.key});
  final List<CiAssessment> items;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _ciBg,
        appBar: const TopBar(title: 'Riwayat Condition Index', back: 2),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            final color = _resultColor(item);
            return Card(
              elevation: 0,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CiDetailPage(item)),
                ),
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: .1),
                  child: Icon(_typeIcon(item.type), color: color),
                ),
                title: Text(
                  _typeLong(item.type),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${item.location}\n${DateFormat('dd MMM yyyy, HH:mm').format(item.assessedAt)} • ${item.operationalStatus} • ${item.status}',
                ),
                trailing: SizedBox(
                  width: 78,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(item.index.toStringAsFixed(0),
                          style: TextStyle(
                              fontSize: 20,
                              color: color,
                              fontWeight: FontWeight.w900)),
                      _ciSyncBadge(item, compact: true),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class CiDetailPage extends StatefulWidget {
  const CiDetailPage(this.assessment, {super.key});
  final CiAssessment assessment;
  @override
  State<CiDetailPage> createState() => _CiDetailPageState();
}

class _CiDetailPageState extends State<CiDetailPage> {
  late final CiAssessment _item = widget.assessment;

  @override
  Widget build(BuildContext context) {
    final color = _resultColor(_item);
    final params = CiCatalog.forType(_item.type);
    return Scaffold(
        backgroundColor: _ciBg,
        appBar: TopBar(title: 'Hasil ${_typeLong(_item.type)}', back: 2),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_item.band,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(_item.operationalStatus,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ]),
                    const Spacer(),
                    Text(_item.index.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900))
                  ])),
              const SizedBox(height: 13),
              _ciSyncStatusCard(_item),
              const SizedBox(height: 13),
              _section('Informasi Assessment', [
                _row('Nomor', _item.id),
                _row('Jenis', _typeLong(_item.type)),
                _row(
                    'Assessor', '${_item.assessorName} (${_item.assessorNik})'),
                _row('Waktu',
                    DateFormat('dd MMM yyyy, HH:mm').format(_item.assessedAt)),
                _row('Lokasi', '${_item.location}\n${_item.coordinate}'),
                _row('Area Owner', _item.areaOwner),
                _row('Konteks', _item.context),
                _row('Rule Set', _item.ruleVersion)
              ]),
              _section('Tindakan', [
                _row('Kontrol Sementara', _item.temporaryControls),
                _row('Corrective Action', _item.action),
                _row('PIC', _item.actionOwner),
                _row('Target', DateFormat('dd MMM yyyy').format(_item.dueDate)),
                _row('Validitas',
                    DateFormat('dd MMM yyyy').format(_item.validUntil)),
                _row('Status', _item.status),
              ]),
              _section(
                  'Parameter Teknis',
                  _item.answers.map((a) {
                    final p = params.firstWhere((e) => e.id == a.parameterId);
                    return _row(
                        '${p.id} • ${p.title}',
                        a.score == null
                            ? 'N/A'
                            : '${_scoreText(_item.type, a.score!)}, ${_scoreLabel(_item.type, a.score!)}${a.value.isNotEmpty && a.value != '__NA__' ? ' • ${a.value} ${a.unit}' : ''}${a.note.isNotEmpty ? '\n${a.note}' : ''}');
                  }).toList()),
              if (_item.answers
                  .any((answer) => answer.evidencePaths.isNotEmpty)) ...[
                const Text('Foto per Parameter',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ..._item.answers
                    .where((answer) => answer.evidencePaths.isNotEmpty)
                    .map((answer) {
                  final parameter =
                      params.firstWhere((e) => e.id == answer.parameterId);
                  return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${parameter.id} • ${parameter.title}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            SizedBox(
                                height: 90,
                                child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: answer.evidencePaths.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 7),
                                    itemBuilder: (_, index) => ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                            File(answer.evidencePaths[index]),
                                            width: 105,
                                            height: 90,
                                            fit: BoxFit.cover))))
                          ]));
                }),
              ],
              if (_item.evidencePaths.isNotEmpty) ...[
                const Text('Bukti Foto',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SizedBox(
                    height: 110,
                    child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _item.evidencePaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(File(_item.evidencePaths[i]),
                                width: 130, fit: BoxFit.cover))))
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CiPdfPage(_item))),
                  style: FilledButton.styleFrom(
                      backgroundColor: _ciNavy,
                      minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Lihat Laporan PDF')),
            ]));
  }
}

class CiPdfPage extends StatelessWidget {
  const CiPdfPage(this.item, {super.key});
  final CiAssessment item;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: TopBar(title: 'Laporan ${_typeLong(item.type)}', back: 2),
      body: PdfPreview(
          build: _buildPdf,
          canChangePageFormat: false,
          canDebug: false,
          pdfFileName: '${item.id}.pdf'));

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final logoData =
        await rootBundle.load('assets/images/indexsafe-logo-text.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final photos = <pw.MemoryImage>[];
    for (final path in item.evidencePaths) {
      if (File(path).existsSync()) {
        photos.add(pw.MemoryImage(await File(path).readAsBytes()));
      }
    }
    final parameterPhotos = <String, List<pw.MemoryImage>>{};
    for (final answer in item.answers) {
      final images = <pw.MemoryImage>[];
      for (final path in answer.evidencePaths) {
        if (File(path).existsSync()) {
          images.add(pw.MemoryImage(await File(path).readAsBytes()));
        }
      }
      if (images.isNotEmpty) parameterPhotos[answer.parameterId] = images;
    }
    final params = CiCatalog.forType(item.type);
    const navy = PdfColor.fromInt(0xFF123B63),
        cyan = PdfColor.fromInt(0xFF0EA5A8),
        grey = PdfColor.fromInt(0xFF667085),
        line = PdfColor.fromInt(0xFFE2E8F0);
    final doc = pw.Document(
        title: 'Laporan ${item.type} ${item.id}',
        author: 'MBS SAP - System Integration Department PT INDEXIM COALINDO');
    doc.addPage(pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(34, 28, 34, 34),
        header: (_) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logo, width: 115),
                  pw.Text(item.id,
                      style: const pw.TextStyle(color: grey, fontSize: 8))
                ])),
        footer: (c) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: line))),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Developed & maintained by System Integration Department - PT INDEXIM COALINDO',
                      style: const pw.TextStyle(color: grey, fontSize: 7)),
                  pw.Text('${c.pageNumber}/${c.pagesCount}',
                      style: const pw.TextStyle(color: grey, fontSize: 8))
                ])),
        build: (_) => [
              pw.Center(
                  child: pw.Column(children: [
                pw.Text('${_typeLong(item.type).toUpperCase()} ASSESSMENT',
                    style: pw.TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(_typeLong(item.type),
                    style: const pw.TextStyle(color: grey, fontSize: 10))
              ])),
              pw.SizedBox(height: 14),
              pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                      color: cyan.shade(.9),
                      borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.band,
                                  style: pw.TextStyle(
                                      color: navy,
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(item.operationalStatus,
                                  style: const pw.TextStyle(
                                      color: navy, fontSize: 10))
                            ]),
                        pw.Text(item.index.toStringAsFixed(1),
                            style: pw.TextStyle(
                                color: navy,
                                fontSize: 26,
                                fontWeight: pw.FontWeight.bold))
                      ])),
              pw.SizedBox(height: 12),
              _pdfSection('INFORMASI', [
                _pdfRow('Nomor', item.id),
                _pdfRow(
                    'Assessor', '${item.assessorName} (${item.assessorNik})'),
                _pdfRow('Tanggal',
                    DateFormat('dd MMMM yyyy, HH:mm').format(item.assessedAt)),
                _pdfRow('Lokasi / GPS', '${item.location}\n${item.coordinate}'),
                _pdfRow('Area Owner', item.areaOwner),
                _pdfRow('Konteks', item.context),
                _pdfRow('Rule Set', item.ruleVersion)
              ]),
              _pdfSection('KEPUTUSAN, RISIKO & ACTION', [
                _pdfRow('Kontrol Sementara', item.temporaryControls),
                _pdfRow('Corrective Action', item.action),
                _pdfRow('PIC / Target',
                    '${item.actionOwner} • ${DateFormat('dd MMM yyyy').format(item.dueDate)}'),
                _pdfRow('Berlaku Sampai',
                    DateFormat('dd MMM yyyy').format(item.validUntil))
              ]),
              pw.Text('HASIL PARAMETER TEKNIS',
                  style: pw.TextStyle(
                      color: navy,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                  border: pw.TableBorder.all(color: line),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(30),
                    1: pw.FlexColumnWidth(3),
                    2: pw.FixedColumnWidth(34),
                    3: pw.FlexColumnWidth(2)
                  },
                  children: [
                    pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFEAF2F7)),
                        children: [
                          _cell('ID', bold: true),
                          _cell('Parameter', bold: true),
                          _cell('Skor', bold: true),
                          _cell('Hasil / Catatan', bold: true)
                        ]),
                    ...item.answers.map((a) {
                      final p = params.firstWhere((e) => e.id == a.parameterId);
                      return pw.TableRow(children: [
                        _cell(p.id),
                        _cell(p.title),
                        _cell(a.score == null
                            ? 'N/A'
                            : '${_scoreText(item.type, a.score!)} ${_scoreLabel(item.type, a.score!)}'),
                        _cell(
                            '${a.value == '__NA__' ? '' : a.value} ${a.unit}\n${a.note}')
                      ]);
                    })
                  ]),
              if (parameterPhotos.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text('FOTO PER PARAMETER',
                    style: pw.TextStyle(
                        color: navy,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                ...item.answers
                    .where((answer) =>
                        parameterPhotos.containsKey(answer.parameterId))
                    .map((answer) {
                  final parameter =
                      params.firstWhere((e) => e.id == answer.parameterId);
                  return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('${parameter.id} • ${parameter.title}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: parameterPhotos[answer.parameterId]!
                                    .map((photo) => pw.Container(
                                        width: 145,
                                        height: 100,
                                        child: pw.Image(photo,
                                            fit: pw.BoxFit.cover)))
                                    .toList())
                          ]));
                }),
              ],
              if (photos.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text('BUKTI FOTO',
                    style: pw.TextStyle(
                        color: navy,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: photos
                        .map((p) => pw.Container(
                            width: 150,
                            height: 105,
                            child: pw.Image(p, fit: pw.BoxFit.cover)))
                        .toList())
              ],
            ]));
    return doc.save();
  }
}

Color _resultColor(CiAssessment item) => item.index < 50
    ? const Color(0xFFDC2626)
    : item.index < 80
        ? const Color(0xFFF59E0B)
        : const Color(0xFF059669);
String _typeLong(String type) => switch (type) {
      'RCI' => 'Road Condition Index',
      'DCI' => 'Disposal Condition Index',
      'SPI' => 'Sediment Pond Index',
      _ => 'Front Condition Index'
    };
IconData _typeIcon(String type) => switch (type) {
      'RCI' => Icons.add_road_rounded,
      'DCI' => Icons.terrain_rounded,
      'SPI' => Icons.water_drop_rounded,
      _ => Icons.landscape_rounded,
    };
String _scoreText(String type, double score) =>
    type == 'FCI' || type == 'DCI' || type == 'SPI'
        ? score == 5
            ? '100'
            : score == 3.5
                ? '70'
                : '40'
        : type == 'RCI'
            ? score.toStringAsFixed(1)
            : score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1);
String _scoreLabel(String type, double score) =>
    type == 'FCI' || type == 'DCI' || type == 'SPI'
        ? score == 5
            ? 'Standar'
            : score == 3.5
                ? 'Perhatian'
                : 'Kritis'
        : type == 'RCI'
            ? '/4'
            : '/5';
Widget _section(String title, List<Widget> rows) => Container(
    margin: const EdgeInsets.only(bottom: 13),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              color: _ciNavy, fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...rows
    ]));
Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 112,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey))),
      Expanded(
          child: Text(value.isEmpty ? '-' : value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, height: 1.35)))
    ]));

Widget _ciSyncBadge(CiAssessment item, {bool compact = false}) =>
    FutureBuilder<bool>(
      future: OfflineSyncService.instance.isPending('condition-index', item.id),
      builder: (_, snapshot) {
        final pending = snapshot.data != false;
        final color =
            pending ? const Color(0xFFDC2626) : const Color(0xFF059669);
        return Container(
          margin: const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                pending
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                size: compact ? 11 : 15,
                color: color),
            const SizedBox(width: 3),
            Text(
                pending ? (compact ? 'Lokal' : 'Belum tersinkron') : 'Terkirim',
                style: TextStyle(
                    color: color,
                    fontSize: compact ? 8 : 11,
                    fontWeight: FontWeight.w800)),
          ]),
        );
      },
    );

Widget _ciSyncStatusCard(CiAssessment item) => FutureBuilder<bool>(
      future: OfflineSyncService.instance.isPending('condition-index', item.id),
      builder: (_, snapshot) {
        final pending = snapshot.data != false;
        final color =
            pending ? const Color(0xFFDC2626) : const Color(0xFF059669);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Row(children: [
            Icon(
                pending
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      pending
                          ? 'Tersimpan lokal • belum tersinkron'
                          : 'Terkirim ke server',
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                      pending
                          ? 'Laporan aman di perangkat dan akan dikirim saat sinkronisasi tersedia.'
                          : 'Laporan sudah berhasil disimpan di server.',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.blueGrey)),
                ])),
          ]),
        );
      },
    );

pw.Widget _pdfSection(String title, List<pw.Widget> rows) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        borderRadius: pw.BorderRadius.circular(6)),
    child:
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title,
          style: pw.TextStyle(
              color: const PdfColor.fromInt(0xFF123B63),
              fontSize: 10,
              fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 5),
      ...rows
    ]));
pw.Widget _pdfRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(
          width: 95,
          child: pw.Text(label,
              style: const pw.TextStyle(
                  color: PdfColor.fromInt(0xFF667085), fontSize: 8))),
      pw.Expanded(
          child: pw.Text(value.isEmpty ? '-' : value,
              style: const pw.TextStyle(fontSize: 8.5)))
    ]));
pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(text.trim(),
        style: pw.TextStyle(
            fontSize: 7,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));
