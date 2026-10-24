import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../widgets/top_bar.dart';
import '../../services/offline_sync_service.dart';
import 'bbs_form_page.dart';
import 'bbs_model.dart';

const _bbsBlue = Color(0xFF075985);
const _bbsGreen = Color(0xFF059669);
const _bbsBackground = Color(0xFFF4F7FB);

class BbsPage extends StatefulWidget {
  const BbsPage({super.key});

  @override
  State<BbsPage> createState() => _BbsPageState();
}

class _BbsPageState extends State<BbsPage> {
  late Future<List<BbsObservation>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = BbsStorage.load();

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() {
        _reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bbsBackground,
      appBar: const TopBar(title: 'Behaviour Based Safety'),
      body: FutureBuilder<List<BbsObservation>>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const <BbsObservation>[];
          return ListView(padding: const EdgeInsets.all(20), children: [
            _BbsHero(
              total: data.length,
              safe: data.where((e) => e.classification == 'Perilaku Aman').length,
              atRisk: data.where((e) => e.classification != 'Perilaku Aman').length,
            ),
            const SizedBox(height: 18),
            _BbsActionCard(title: 'Observasi Perilaku', subtitle: 'Catat perilaku aman dan berisiko di lapangan.', icon: Icons.visibility_rounded, color: _bbsBlue, onTap: () => _open(const BbsFormPage())),
            _BbsActionCard(title: 'Riwayat Observasi', subtitle: 'Lihat hasil observasi BBS Anda.', icon: Icons.history_rounded, color: const Color(0xFF6366F1), badge: data.length, onTap: () => _open(const BbsListPage())),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open(const BbsFormPage()), backgroundColor: _bbsBlue, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Buat Observasi')),
    );
  }
}

class _BbsHero extends StatelessWidget {
  const _BbsHero({
    required this.total,
    required this.safe,
    required this.atRisk,
  });

  final int total;
  final int safe;
  final int atRisk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF075985), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33075985),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0x33FFFFFF),
                child: Icon(Icons.groups_2_rounded, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BBS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Behaviour Based Safety',
                      style: TextStyle(color: Color(0xFFD7F2FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroMetric(label: 'Total', value: total),
              _HeroMetric(label: 'Aman', value: safe),
              _HeroMetric(label: 'Berisiko', value: atRisk),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFD7F2FF), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BbsActionCard extends StatelessWidget {
  const _BbsActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF172033),
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$badge',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          height: 1.35,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BbsListPage extends StatefulWidget {
  const BbsListPage({super.key});

  @override
  State<BbsListPage> createState() => _BbsListPageState();
}

class _BbsListPageState extends State<BbsListPage> {
  late Future<List<BbsObservation>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = BbsStorage.load();
  }

  Future<void> _deleteLocal(BbsObservation observation) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Hapus dari perangkat?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                observation.syncStatus == 'Pending'
                    ? 'Laporan belum terkirim. Menghapusnya akan membatalkan antrean sinkronisasi.'
                    : 'Riwayat akan dihapus dari perangkat. Salinan yang sudah masuk ke MBS tetap aman.',
                style: const TextStyle(color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)), onPressed: () => Navigator.pop(context, true), child: const Text('Hapus'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await OfflineSyncService.instance.discard(feature: 'bbs', localId: observation.id);
    await BbsStorage.remove(observation.id);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Laporan dihapus dari perangkat.'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bbsBackground,
      appBar: const TopBar(title: 'Riwayat BBS'),
      body: FutureBuilder<List<BbsObservation>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <BbsObservation>[];
          return items.isEmpty
              ? const _EmptyBbs()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ObservationTile(
                      observation: item,
                      onDelete: () => _deleteLocal(item),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BbsDetailPage(item),
                          ),
                        );
                        if (mounted) setState(_reload);
                      },
                    );
                  },
                );
        },
      ),
    );
  }
}

class _EmptyBbs extends StatelessWidget {
  const _EmptyBbs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded,
                size: 64, color: Colors.blueGrey.shade200),
            const SizedBox(height: 12),
            const Text(
              'Belum ada observasi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Observasi BBS yang disimpan akan tampil di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationTile extends StatelessWidget {
  const _ObservationTile({required this.observation, required this.onTap, required this.onDelete});

  final BbsObservation observation;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final isSafe = observation.classification == 'Perilaku Aman';
    final color = isSafe ? _bbsGreen : const Color(0xFFDC2626);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isSafe
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSafe
                      ? Icons.thumb_up_alt_rounded
                      : Icons.warning_amber_rounded,
                  color: observation.classification == 'Perilaku Aman'
                      ? _bbsGreen
                      : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      observation.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${observation.location} • ${DateFormat('dd MMM yyyy, HH:mm').format(observation.observedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isSafe ? 'Aman' : 'Berisiko',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (observation.syncStatus == 'Pending')
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text('Menunggu sinkron', style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus dari perangkat',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BbsDetailPage extends StatefulWidget {
  const BbsDetailPage(this.observation, {super.key});

  final BbsObservation observation;

  @override
  State<BbsDetailPage> createState() => _BbsDetailPageState();
}

class _BbsDetailPageState extends State<BbsDetailPage> {
  late BbsObservation _observation;

  @override
  void initState() {
    super.initState();
    _observation = widget.observation;
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final observation = _observation;
    final logoData = await rootBundle.load(
      'assets/images/indexsafe-logo-text.png',
    );
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final evidence = <pw.MemoryImage>[];
    for (final path in observation.evidencePaths) {
      if (File(path).existsSync()) {
        evidence.add(pw.MemoryImage(await File(path).readAsBytes()));
      }
    }

    final document = pw.Document(
      version: PdfVersion.pdf_1_5,
      compress: true,
      title: 'Laporan BBS ${observation.id}',
      author: 'MBS SAP - System Integration Department PT INDEXIM COALINDO',
    );
    const blue = PdfColor.fromInt(0xFF075985);
    const green = PdfColor.fromInt(0xFF059669);
    const red = PdfColor.fromInt(0xFFDC2626);
    const grey = PdfColor.fromInt(0xFF667085);
    const line = PdfColor.fromInt(0xFFE2E8F0);
    final classificationColor =
        observation.classification == 'Perilaku Aman' ? green : red;

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 34),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 120),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'MBS SAP',
                    style: pw.TextStyle(
                      color: blue,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    observation.id,
                    style: const pw.TextStyle(color: grey, fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: line)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Developed & maintained by System Integration Department - PT INDEXIM COALINDO',
                style: const pw.TextStyle(color: grey, fontSize: 7),
              ),
              pw.Text(
                'Halaman ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(color: grey, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'LAPORAN OBSERVASI BBS',
                  style: pw.TextStyle(
                    color: blue,
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'BEHAVIOUR BASED SAFETY',
                  style: const pw.TextStyle(color: grey, fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: classificationColor.shade(0.92),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: classificationColor, width: .8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 10,
                  height: 10,
                  decoration: pw.BoxDecoration(
                    color: classificationColor,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 9),
                pw.Expanded(
                  child: pw.Text(
                    observation.classification,
                    style: pw.TextStyle(
                      color: classificationColor,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  observation.riskLevel,
                  style: pw.TextStyle(
                    color: classificationColor,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfSection(
            'INFORMASI OBSERVASI',
            [
              _pdfRow('Nomor Laporan', observation.id),
              _pdfRow('Jenis Observasi', observation.observationType),
              _pdfRow(
                'Tanggal / Waktu',
                DateFormat('dd MMMM yyyy, HH:mm')
                    .format(observation.observedAt),
              ),
              _pdfRow(
                'Observer',
                '${observation.observerName} (${observation.observerNik})',
              ),
              _pdfRow('Pekerja Diamati', observation.observedPerson),
              _pdfRow('Jabatan / Peran', observation.observedPosition),
              _pdfRow('Unit / Departemen', observation.department),
              _pdfRow('Lokasi', observation.location),
            ],
          ),
          _pdfSection(
            'PERILAKU & KONTEKS',
            [
              _pdfRow('Kategori', observation.category),
              _pdfRow('Perilaku Diamati', observation.behaviors.join('\n- '),
                  list: true),
              _pdfRow('Kondisi Jalan / Area', observation.roadCondition),
              _pdfRow('Cuaca', observation.weatherCondition),
              _pdfRow('Traffic / Aktivitas', observation.trafficCondition),
              _pdfRow(
                'Faktor Pemicu',
                observation.triggerFactors.isEmpty
                    ? '-'
                    : observation.triggerFactors.join('\n- '),
                list: observation.triggerFactors.isNotEmpty,
              ),
            ],
          ),
          _pdfSection(
            'RISIKO, TINDAKAN & COACHING',
            [
              _pdfRow('Level Risiko', observation.riskLevel),
              _pdfRow(
                  'Konsekuensi Potensial', observation.potentialConsequence),
              _pdfRow(
                'Tindakan Langsung',
                observation.immediateActions.join('\n- '),
                list: true,
              ),
              _pdfRow('Respons Pekerja', observation.workerResponse),
              _pdfRow('Catatan Coaching', observation.coachingNotes),
              _pdfRow('Komitmen Perbaikan', observation.commitment),
              _pdfRow(
                'Target Follow Up',
                observation.dueDate == null
                    ? '-'
                    : DateFormat('dd MMMM yyyy').format(observation.dueDate!),
              ),
            ],
          ),
          if (evidence.isNotEmpty)
            _pdfSection(
              'BUKTI FOTO (${evidence.length})',
              [
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: evidence
                      .asMap()
                      .entries
                      .map(
                        (entry) => pw.Container(
                          width: 220,
                          padding: const pw.EdgeInsets.all(5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: line),
                            borderRadius: pw.BorderRadius.circular(5),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Foto ${entry.key + 1}',
                                style: const pw.TextStyle(
                                  color: grey,
                                  fontSize: 7,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Container(
                                height: 145,
                                alignment: pw.Alignment.center,
                                child: pw.Image(
                                  entry.value,
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF8FAFC),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'Laporan ini dibuat melalui aplikasi MBS SAP dan merupakan catatan observasi perilaku keselamatan di lapangan.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: grey, fontSize: 8),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> children) {
    const blue = PdfColor.fromInt(0xFF075985);
    const line = PdfColor.fromInt(0xFFE2E8F0);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: line),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE0F2FE),
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: blue,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(children: children),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfRow(String label, String value, {bool list = false}) {
    const grey = PdfColor.fromInt(0xFF667085);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 125,
            child: pw.Text(
              label,
              style: const pw.TextStyle(color: grey, fontSize: 9),
            ),
          ),
          pw.Text(':  ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '-' : '${list ? '- ' : ''}$value',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                lineSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TopBar(title: 'Laporan Observasi BBS'),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        initialPageFormat: PdfPageFormat.a4,
        padding: EdgeInsets.zero,
        scrollViewDecoration: const BoxDecoration(color: Colors.white),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Colors.transparent)],
        ),
        pdfFileName: 'BBS-${_observation.id}.pdf',
        build: _generatePdf,
      ),
    );
  }
}
