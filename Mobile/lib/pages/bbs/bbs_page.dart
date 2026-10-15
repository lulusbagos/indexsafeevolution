import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../widgets/top_bar.dart';
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

  void _reload() {
    _future = BbsStorage.load();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    setState(_reload);
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
          final open = data.where((item) => item.status != 'Closed').length;
          final closed = data.where((item) => item.status == 'Closed').length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                _BbsHero(total: data.length, open: open, closed: closed),
                const SizedBox(height: 18),
                const Text(
                  'Pilih Aktivitas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 10),
                _BbsActionCard(
                  title: 'Observasi Perilaku',
                  subtitle:
                      'Catat perilaku aman dan berisiko, penyebab, risiko, serta coaching di lokasi.',
                  icon: Icons.visibility_rounded,
                  color: _bbsBlue,
                  onTap: () => _open(const BbsFormPage()),
                ),
                _BbsActionCard(
                  title: 'Follow Up Observasi',
                  subtitle:
                      'Pantau komitmen perbaikan dan selesaikan observasi yang masih terbuka.',
                  icon: Icons.fact_check_rounded,
                  color: const Color(0xFFF59E0B),
                  badge: open,
                  onTap: () => _open(const BbsListPage(followUpOnly: true)),
                ),
                _BbsActionCard(
                  title: 'Riwayat Observasi',
                  subtitle:
                      'Lihat kembali seluruh hasil observasi BBS beserta detail dan statusnya.',
                  icon: Icons.history_rounded,
                  color: const Color(0xFF6366F1),
                  badge: data.length,
                  onTap: () => _open(const BbsListPage()),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0F2FE), Color(0xFFECFDF5)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, color: _bbsBlue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Melihat perilaku, memahami penyebab, lalu membangun perubahan melalui percakapan yang positif.',
                          style: TextStyle(
                            color: Color(0xFF155E75),
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const BbsFormPage()),
        backgroundColor: _bbsBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Observasi'),
      ),
    );
  }
}

class _BbsHero extends StatelessWidget {
  const _BbsHero({
    required this.total,
    required this.open,
    required this.closed,
  });

  final int total;
  final int open;
  final int closed;

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
              _HeroMetric(label: 'Perlu Follow Up', value: open),
              _HeroMetric(label: 'Closed', value: closed),
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
  const BbsListPage({this.followUpOnly = false, super.key});

  final bool followUpOnly;

  @override
  State<BbsListPage> createState() => _BbsListPageState();
}

class _BbsListPageState extends State<BbsListPage> {
  String _filter = 'Semua';
  late Future<List<BbsObservation>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = BbsStorage.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bbsBackground,
      appBar: TopBar(
        title: widget.followUpOnly ? 'Follow Up BBS' : 'Riwayat BBS',
      ),
      body: FutureBuilder<List<BbsObservation>>(
        future: _future,
        builder: (context, snapshot) {
          var items = snapshot.data ?? const <BbsObservation>[];
          if (widget.followUpOnly) {
            items = items.where((item) => item.status != 'Closed').toList();
          } else if (_filter != 'Semua') {
            items = items.where((item) => item.status == _filter).toList();
          }
          return Column(
            children: [
              if (!widget.followUpOnly)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: ['Semua', 'Open', 'In Progress', 'Closed']
                        .map(
                          (filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? const _EmptyBbs()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ObservationTile(
                            observation: item,
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
                      ),
              ),
            ],
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
  const _ObservationTile({required this.observation, required this.onTap});

  final BbsObservation observation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (observation.status) {
      'Closed' => _bbsGreen,
      'In Progress' => const Color(0xFFF59E0B),
      _ => const Color(0xFFEF4444),
    };
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
                  color: observation.classification == 'Perilaku Aman'
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  observation.classification == 'Perilaku Aman'
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
                        observation.status,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
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

  Future<void> _updateStatus() async {
    var status = _observation.status;
    final notes = TextEditingController(text: _observation.followUpNotes);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Follow Up',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['Open', 'In Progress', 'Closed']
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setSheetState(() => status = value!),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notes,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Catatan tindak lanjut',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    final updated = _observation.copyWith(
      status: status,
      followUpNotes: notes.text.trim(),
    );
    await BbsStorage.update(updated);
    if (!mounted) return;
    setState(() => _observation = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Follow up BBS berhasil diperbarui.')),
    );
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
                  '${observation.riskLevel} | ${observation.status}',
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
              _pdfRow('Status', observation.status),
              if (observation.followUpNotes.isNotEmpty)
                _pdfRow('Catatan Follow Up', observation.followUpNotes),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _updateStatus,
            style: FilledButton.styleFrom(
              backgroundColor: _bbsBlue,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.update_rounded),
            label: const Text('Update Follow Up'),
          ),
        ),
      ),
    );
  }
}
