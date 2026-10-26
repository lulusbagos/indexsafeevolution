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

const _bbsBlue = Color(0xFF0284C7);
const _bbsGreen = Color(0xFF16A34A);
const _bbsBackground = Color(0xFFF8FAFC);

class BbsPage extends StatefulWidget {
  const BbsPage({this.initialClassification, super.key});

  final String? initialClassification;

  @override
  State<BbsPage> createState() => _BbsPageState();
}

class _BbsPageState extends State<BbsPage> {
  late Future<List<BbsObservation>> _future;
  String _filter = 'Semua';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialClassification != null) {
      _filter = widget.initialClassification!;
    }
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = BbsStorage.load();
    });
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BbsFormPage()),
    );
    if (mounted) _reload();
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
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Laporan dihapus dari perangkat.'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = _bbsBlue;

    return Scaffold(
      backgroundColor: _bbsBackground,
      appBar: const TopBar(title: 'Behaviour Based Safety'),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Buat Observasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: FutureBuilder<List<BbsObservation>>(
        future: _future,
        builder: (context, snapshot) {
          final allItems = snapshot.data ?? const <BbsObservation>[];
          final totalCount = allItems.length;
          final safeCount = allItems.where((e) => e.classification == 'Perilaku Aman').length;
          final atRiskCount = allItems.where((e) => e.classification != 'Perilaku Aman').length;

          // Filter by status
          var items = allItems;
          if (_filter == 'Perilaku Aman') {
            items = items.where((e) => e.classification == 'Perilaku Aman').toList();
          } else if (_filter == 'Perilaku Berisiko') {
            items = items.where((e) => e.classification != 'Perilaku Aman').toList();
          }

          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            items = items.where((e) {
              return e.observedPerson.toLowerCase().contains(q) ||
                  e.observerNik.toLowerCase().contains(q) ||
                  e.location.toLowerCase().contains(q) ||
                  e.category.toLowerCase().contains(q) ||
                  e.department.toLowerCase().contains(q);
            }).toList();
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            color: accent,
            child: Column(
              children: [
                // Top Search & Quick Filter Segment
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    children: [
                      // Search box
                      if (allItems.isNotEmpty || _searchQuery.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Cari pekerja, NIK, lokasi, kategori...',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),

                      // Segmented Filters
                      Row(
                        children: [
                          _FilterSegmentPill(
                            label: 'Semua',
                            count: totalCount,
                            isSelected: _filter == 'Semua',
                            activeColor: _bbsBlue,
                            onTap: () => setState(() => _filter = 'Semua'),
                          ),
                          const SizedBox(width: 8),
                          _FilterSegmentPill(
                            label: 'Aman',
                            count: safeCount,
                            isSelected: _filter == 'Perilaku Aman',
                            activeColor: const Color(0xFF16A34A),
                            onTap: () => setState(() => _filter = 'Perilaku Aman'),
                          ),
                          const SizedBox(width: 8),
                          _FilterSegmentPill(
                            label: 'Berisiko',
                            count: atRiskCount,
                            isSelected: _filter == 'Perilaku Berisiko',
                            activeColor: const Color(0xFFDC2626),
                            onTap: () => setState(() => _filter = 'Perilaku Berisiko'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Observations List
                Expanded(
                  child: items.isEmpty
                      ? _EmptyBbs(
                          isFiltered: _filter != 'Semua' || _searchQuery.isNotEmpty,
                          onResetFilter: () {
                            _searchCtrl.clear();
                            setState(() {
                              _filter = 'Semua';
                              _searchQuery = '';
                            });
                          },
                          onCreate: _openCreate,
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
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
                                if (mounted) _reload();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

typedef BbsListPage = BbsPage;

class _FilterSegmentPill extends StatelessWidget {
  const _FilterSegmentPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeColor : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBbs extends StatelessWidget {
  const _EmptyBbs({
    this.isFiltered = false,
    this.onResetFilter,
    this.onCreate,
  });

  final bool isFiltered;
  final VoidCallback? onResetFilter;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off_rounded : Icons.groups_2_outlined,
                size: 54,
                color: Colors.blueGrey.shade300,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'Tidak ada observasi yang cocok' : 'Belum Ada Observasi BBS',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Coba gunakan kata kunci pencarian lain atau reset filter.'
                  : 'Catat pengamatan perilaku aman dan berisiko pekerja di lapangan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            if (isFiltered)
              OutlinedButton.icon(
                onPressed: onResetFilter,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filter'),
              )
            else if (onCreate != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bbsBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Buat Observasi Pertama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
