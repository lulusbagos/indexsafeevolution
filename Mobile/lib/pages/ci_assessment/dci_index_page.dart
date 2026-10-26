import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../widgets/top_bar.dart';
import 'dci_form_page.dart';
import 'dci_model.dart';

class DciIndexPage extends StatefulWidget {
  const DciIndexPage({super.key});

  @override
  State<DciIndexPage> createState() => _DciIndexPageState();
}

class _DciIndexPageState extends State<DciIndexPage> {
  final _api = ApiService();

  List<DciReportItem> _reports = [];
  DciSummaryStats _stats = DciSummaryStats();
  List<String> _disposals = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedDisposal;
  String? _selectedKategori;

  String _currentUserNik = '';
  String _currentUserNama = '';
  String _currentUserCompany = '';
  int _currentUserCompanyId = 0;
  String _selectedScope = 'my_history'; // 'my_history', 'pic', 'created', 'all'
  final _searchController = TextEditingController();

  static const _orangeColor = Color(0xFFEA580C);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await _loadUser();
    _fetchData();
  }

  Future<void> _loadUser() async {
    final profile = PreferenceService.getProfile();
    final nik = profile?.noNik ?? PreferenceService.getUser() ?? '';
    final nama = profile?.namaLengkap ?? '';
    final company = profile?.company ?? '';
    final companyId = profile?.companyId ?? 0;
    if (mounted) {
      setState(() {
        _currentUserNik = nik;
        _currentUserNama = nama;
        _currentUserCompany = company;
        _currentUserCompanyId = companyId;
      });
    }
  }

  Future<List<DciReportItem>> _loadPendingDciJobs() async {
    final List<DciReportItem> pending = [];
    try {
      final rows = await DatabaseService().rawQuery(
        "SELECT payload FROM offline_sync_jobs WHERE feature = 'dci' ORDER BY created_at DESC",
      );
      for (final r in rows) {
        final payloadRaw = r['payload']?.toString();
        if (payloadRaw == null || payloadRaw.isEmpty) continue;
        final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
        final map = Map<String, dynamic>.from(payload['map'] as Map? ?? {});
        final date = DateTime.tryParse(map['tanggal']?.toString() ?? '') ?? DateTime.now();
        pending.add(
          DciReportItem(
            id: -1,
            tanggal: date,
            waktu: map['waktu']?.toString() ?? '12:00',
            nik: map['nik']?.toString() ?? '',
            nama: map['nama']?.toString() ?? '',
            departemen: map['departemen']?.toString(),
            perusahaan: map['perusahaan']?.toString(),
            perusahaanId: map['perusahaan_id'] as int?,
            area: map['area']?.toString() ?? 'Area Tambang',
            lokasi: map['lokasi']?.toString() ?? '',
            detilLokasi: map['detil_lokasi']?.toString(),
            disposal: map['disposal']?.toString(),
            namaDump: map['nama_dump']?.toString() ?? 'Dump Offline',
            pad: map['pad']?.toString(),
            shift: map['shift']?.toString(),
            latitude: map['latitude']?.toString(),
            longitude: map['longitude']?.toString(),
            skorLantaiDump: int.tryParse(map['skor_lantai_dump']?.toString() ?? '') ?? 100,
            skorSafetyBerm: int.tryParse(map['skor_safety_berm']?.toString() ?? '') ?? 100,
            skorKondisiCrest: int.tryParse(map['skor_kondisi_crest']?.toString() ?? '') ?? 100,
            skorGradeDumping: int.tryParse(map['skor_grade_dumping']?.toString() ?? '') ?? 100,
            skorDrainaseDump: int.tryParse(map['skor_drainase_dump']?.toString() ?? '') ?? 100,
            skorPenataanSpillage: int.tryParse(map['skor_penataan_spillage']?.toString() ?? '') ?? 100,
            skorRambuPenerangan: int.tryParse(map['skor_rambu_penerangan']?.toString() ?? '') ?? 100,
            skorSpotterManuver: int.tryParse(map['skor_spotter_manuver']?.toString() ?? '') ?? 100,
            totalScore: 100.0,
            kategoriIndex: 'PENDING SYNC',
            catatan: map['catatan']?.toString(),
            tindakanPerbaikan: map['tindakan_perbaikan']?.toString(),
            pic: map['pic']?.toString(),
            fotoUrl: payload['photoPath']?.toString(),
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {}
    return pending;
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.getDciList(
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        disposal: _selectedDisposal,
        kategori: _selectedKategori,
        userNik: _currentUserNik.isNotEmpty ? _currentUserNik : null,
        userNama: _currentUserNama.isNotEmpty ? _currentUserNama : null,
        companyId: _currentUserCompanyId > 0 ? _currentUserCompanyId : null,
        companyName: _currentUserCompany.isNotEmpty ? _currentUserCompany : null,
        scope: _selectedScope,
      );

      final pendingJobs = await _loadPendingDciJobs();

      res.fold(
        (err) async {
          final prefs = await SharedPreferences.getInstance();
          final cacheRaw = prefs.getString('dci_cache_list');
          if (cacheRaw != null && cacheRaw.isNotEmpty) {
            try {
              final cachedData = jsonDecode(cacheRaw) as Map<String, dynamic>;
              final rawList = cachedData['data'] as List<dynamic>? ?? [];
              final reports = rawList.map((e) => DciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
              final stats = DciSummaryStats.fromJson(cachedData['stats'] as Map<String, dynamic>?);
              final disposals = (cachedData['disposals'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
              if (mounted) {
                setState(() {
                  _reports = [...pendingJobs, ...reports];
                  _stats = stats;
                  _disposals = disposals;
                  _isLoading = false;
                  _errorMessage = null;
                });
                return;
              }
            } catch (_) {}
          }
          if (mounted) {
            setState(() {
              _reports = pendingJobs;
              _isLoading = false;
              _errorMessage = err['message']?.toString() ?? 'Gagal memuat data DCI.';
            });
          }
        },
        (data) async {
          final rawList = data['data'] as List<dynamic>? ?? [];
          final reports = rawList.map((e) => DciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          final stats = DciSummaryStats.fromJson(data['stats'] as Map<String, dynamic>?);
          final disposals = (data['disposals'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('dci_cache_list', jsonEncode(data));
          } catch (_) {}

          if (mounted) {
            setState(() {
              _reports = [...pendingJobs, ...reports];
              _stats = stats;
              _disposals = disposals;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _deleteReport(DciReportItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Hapus Laporan DCI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin menghapus laporan DCI ini?'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.disposal ?? item.lokasi,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.area} • ${item.namaDump ?? "-"} • Skor: ${item.totalScore.toStringAsFixed(0)}% (${item.kategoriIndex})',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(item.tanggal)} • ${item.waktu}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (item.id > 0) {
        try {
          final res = await _api.deleteDciReport(item.id);
          res.fold(
            (err) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err['message']?.toString() ?? 'Gagal menghapus laporan dari server.')),
                );
              }
            },
            (data) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Laporan DCI berhasil dihapus.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
          );
        } catch (_) {}
      }

      try {
        final db = await DatabaseService().database;
        await db.delete('tbl_t_dci_report', where: 'id = ?', whereArgs: [item.id]);
      } catch (_) {}

      _fetchData();
    }
  }

  Future<void> _editReport(DciReportItem item) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DciFormPage(editData: item)),
    );
    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan DCI berhasil diperbarui.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _fetchData();
    }
  }

  String _buildReportShareText(DciReportItem item) {
    final tglStr = DateFormat('dd MMM yyyy').format(item.tanggal);
    final text = StringBuffer();
    text.writeln('📋 *HASIL EVALUASI DISPOSAL CONDITION INDEX (DCI)*');
    text.writeln('=================================');
    text.writeln('📍 *Disposal*: ${item.disposal ?? item.lokasi}');
    text.writeln('🚩 *Area / Dump*: ${item.area} • ${item.namaDump ?? "-"}${item.pad != null && item.pad!.isNotEmpty ? " (Pad ${item.pad})" : ""}');
    if (item.perusahaan != null && item.perusahaan!.isNotEmpty) {
      text.writeln('🏢 *Perusahaan*: ${item.perusahaan}');
    }
    text.writeln('📅 *Waktu*: $tglStr ${item.waktu} • ${item.shift ?? "Shift 1"}');
    text.writeln('👤 *Pelapor*: ${item.nama.isNotEmpty ? item.nama : item.nik}');
    text.writeln('---------------------------------');
    text.writeln('⭐ *SKOR DCI*: ${item.totalScore.toStringAsFixed(1)}% (${item.kategoriIndex.toUpperCase()})');
    text.writeln('• D01. Lantai Dump (15%): ${item.skorLantaiDump}');
    text.writeln('• D02. Safety Berm (15%): ${item.skorSafetyBerm}');
    text.writeln('• D03. Kondisi Crest (15%): ${item.skorKondisiCrest}');
    text.writeln('• D04. Counter Grade (15%): ${item.skorGradeDumping}');
    text.writeln('• D05. Drainase Dump (10%): ${item.skorDrainaseDump}');
    text.writeln('• D06. Penataan Spillage (10%): ${item.skorPenataanSpillage}');
    text.writeln('• D07. Rambu & Lampu (10%): ${item.skorRambuPenerangan}');
    text.writeln('• D08. Spotter & Manuver (10%): ${item.skorSpotterManuver}');
    text.writeln('---------------------------------');
    if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
      text.writeln('📝 *Catatan*: ${item.catatan!.trim()}');
    }
    if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.trim().isNotEmpty) {
      text.writeln('🛠️ *Tindakan Perbaikan*: ${item.tindakanPerbaikan!.trim()}');
    }
    if (item.pic != null && item.pic!.trim().isNotEmpty) {
      text.writeln('👷 *PIC Penanggung Jawab*: ${item.pic!.trim()}');
    }
    if (item.fotoUrl != null && item.fotoUrl!.isNotEmpty) {
      final photo = item.fotoUrl!.startsWith('http')
          ? item.fotoUrl!
          : '${_api.baseUrl}${item.fotoUrl!.startsWith('/') ? '' : '/'}${item.fotoUrl!}';
      text.writeln('📸 *Dokumentasi*: $photo');
    }
    text.writeln('\n_Dilaporkan via SAP Mobile - Indexsafe Evolution_');
    return text.toString();
  }

  Future<void> _shareWhatsApp(DciReportItem item) async {
    final msg = _buildReportShareText(item);
    final encoded = Uri.encodeComponent(msg);
    final waUri = Uri.parse('whatsapp://send?text=$encoded');
    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri);
        return;
      }
      final webWaUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
      if (await canLaunchUrl(webWaUri)) {
        await launchUrl(webWaUri, mode: LaunchMode.externalApplication);
        return;
      }
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp tidak ditemukan. Teks laporan telah disalin ke clipboard!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teks laporan berhasil disalin ke clipboard!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _copyReportText(DciReportItem item) async {
    final msg = _buildReportShareText(item);
    await Clipboard.setData(ClipboardData(text: msg));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teks ringkasan laporan DCI berhasil disalin ke clipboard!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _showShareOptions(DciReportItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.share_rounded, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Bagikan Laporan DCI',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.disposal ?? item.lokasi} • Skor: ${item.totalScore.toStringAsFixed(0)}% (${item.kategoriIndex})',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFFF0FDF4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Kirim ke WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Kirim format ringkasan pesan ke kontak atau grup WhatsApp', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareWhatsApp(item);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFFF8FAFC),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Salin Teks Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Salin ringkasan evaluasi DCI ke clipboard perangkat', style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyReportText(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showDetailSheet(DciReportItem item) {
    final Color catColor = item.totalScore >= 85
        ? const Color(0xFF10B981)
        : (item.totalScore >= 70 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    final String? resolvedPhotoUrl = item.fotoUrl != null && item.fotoUrl!.isNotEmpty
        ? (item.fotoUrl!.startsWith('http')
            ? item.fotoUrl!
            : '${_api.baseUrl}${item.fotoUrl!.startsWith('/') ? '' : '/'}${item.fotoUrl!}')
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.96,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _orangeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.terrain_rounded, color: _orangeColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text('Detail Laporan DCI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: catColor.withOpacity(0.3), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.totalScore.toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: catColor),
                                ),
                              ),
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
                                          item.disposal ?? 'Disposal Tambang',
                                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: catColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          item.kategoriIndex.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.area} • ${item.namaDump ?? "-"}${item.pad != null && item.pad!.isNotEmpty ? " • ${item.pad}" : ""}',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  if (item.perusahaan != null && item.perusahaan!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        item.perusahaan!,
                                        style: const TextStyle(fontSize: 12, color: _orangeColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('dd MMM yyyy').format(item.tanggal)} • ${item.waktu} • ${item.shift ?? "Shift 1"}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                  ),
                                  Text(
                                    'Pelapor: ${item.nama.isNotEmpty ? item.nama : item.nik}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Breakdown 8 Parameter Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.analytics_outlined, color: _orangeColor, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Breakdown 8 Parameter Disposal',
                                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                            const Divider(height: 18, color: Color(0xFFF1F5F9)),
                            _detailParamRow('D01. Lantai Dump (15%)', item.skorLantaiDump),
                            _detailParamRow('D02. Safety Berm (15%)', item.skorSafetyBerm),
                            _detailParamRow('D03. Kondisi Crest (15%)', item.skorKondisiCrest),
                            _detailParamRow('D04. Counter Grade (15%)', item.skorGradeDumping),
                            _detailParamRow('D05. Drainase Dump (10%)', item.skorDrainaseDump),
                            _detailParamRow('D06. Penataan Spillage (10%)', item.skorPenataanSpillage),
                            _detailParamRow('D07. Rambu & Lampu (10%)', item.skorRambuPenerangan),
                            _detailParamRow('D08. Spotter & Manuver (10%)', item.skorSpotterManuver),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // PIC Penanggung Jawab
                      if (item.pic != null && item.pic!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _orangeColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.assignment_ind_rounded, color: _orangeColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Penanggung Jawab Tindakan (PIC)',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.pic!,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Catatan Pengawas
                      if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                        const Text('Catatan Pengawas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(item.catatan!, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155))),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Rekomendasi Tindakan Perbaikan
                      if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.isNotEmpty) ...[
                        const Text('Rekomendasi Tindakan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            item.tindakanPerbaikan!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFB45309), height: 1.4, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Foto Dokumentasi
                      if (resolvedPhotoUrl != null) ...[
                        const Text('Dokumentasi Foto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.black,
                                insetPadding: const EdgeInsets.all(12),
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      child: Center(
                                        child: Image.network(
                                          resolvedPhotoUrl,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              resolvedPhotoUrl,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 32),
                                    SizedBox(height: 6),
                                    Text('Foto tidak dapat dimuat', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // Bottom Action Buttons: Share, Edit, Delete
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, -4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.share_rounded, size: 19),
                          label: const Text(
                            'Bagikan Laporan ke WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _shareWhatsApp(item);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text(
                                'Ubah Laporan',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _editReport(item);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text(
                                'Hapus Laporan',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteReport(item);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailParamRow(String label, int score) {
    final Color color = score == 100
        ? const Color(0xFF10B981)
        : (score == 70 ? const Color(0xFFF59E0B) : (score == 40 ? const Color(0xFFF97316) : const Color(0xFFEF4444)));

    String statusText = 'Optimal';
    if (score == 70) statusText = 'Cukup';
    if (score == 40) statusText = 'Kurang';
    if (score == 0) statusText = 'Kritis';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                ),
                const SizedBox(width: 4),
                Text(
                  '($statusText)',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Disposal Condition Index (DCI)'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orangeColor,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Penilaian DCI', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DciFormPage()),
          );
          if (res == true) _fetchData();
        },
      ),
      body: RefreshIndicator(
        color: _orangeColor,
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [
            // Top Metrics (2x2 Grid)
            _buildTopMetrics(),
            const SizedBox(height: 14),

            // Scope Tabs & Search & Category Filter Bar
            _buildFilterBar(),
            const SizedBox(height: 14),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedScope == 'all' && _currentUserCompany.isNotEmpty
                        ? 'Semua Disposal - $_currentUserCompany (${_reports.length})'
                        : 'Riwayat Inspeksi DCI (${_reports.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _orangeColor)),
              ],
            ),
            const SizedBox(height: 10),

            // Content List
            if (_isLoading && _reports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: _orangeColor),
                ),
              )
            else if (_errorMessage != null)
              _buildErrorState()
            else if (_reports.isEmpty)
              _buildEmptyState()
            else
              ..._reports.map((item) => _buildDciCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Inspeksi',
                value: '${_stats.totalReports}',
                subtitle: '30 Hari Terakhir',
                icon: Icons.assignment_turned_in_rounded,
                accentColor: _orangeColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Rata-rata Skor',
                value: '${_stats.avgScore.toStringAsFixed(1)}%',
                subtitle: 'Target: ≥ 85%',
                icon: Icons.speed_rounded,
                accentColor: _stats.avgScore >= 85
                    ? const Color(0xFF10B981)
                    : (_stats.avgScore >= 70 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Kondisi Baik',
                value: '${_stats.goodCount}',
                subtitle: 'Skor ≥ 85%',
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Perlu Perbaikan',
                value: '${_stats.fairCount + _stats.poorCount}',
                subtitle: '${_stats.poorCount} Kritis, ${_stats.fairCount} Sedang',
                icon: Icons.warning_amber_rounded,
                accentColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accentColor)),
                Text(subtitle, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HISTORY SCOPE SELECTOR TABS
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildScopeTab('Riwayat Saya', 'my_history', Icons.history_rounded),
                _buildScopeTab('Sebagai PIC', 'pic', Icons.assignment_ind_rounded),
                _buildScopeTab('Dibuat Saya', 'created', Icons.edit_note_rounded),
                _buildScopeTab('Semua Disposal', 'all', Icons.terrain_rounded),
              ],
            ),
          ),

          if (_selectedScope == 'all' && _currentUserCompany.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _orangeColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 14, color: _orangeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Menampilkan seluruh disposal: $_currentUserCompany',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _orangeColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Search Box
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: (val) {
                _searchQuery = val;
                _fetchData();
              },
              decoration: InputDecoration(
                hintText: 'Cari disposal, pit, lokasi, atau nama...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchData();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Kategori & Disposal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChipPill('Semua Kategori', _selectedKategori == null, () {
                  setState(() => _selectedKategori = null);
                  _fetchData();
                }),
                const SizedBox(width: 6),
                _buildFilterChipPill('Baik (≥85%)', _selectedKategori == 'Baik', () {
                  setState(() => _selectedKategori = _selectedKategori == 'Baik' ? null : 'Baik');
                  _fetchData();
                }),
                const SizedBox(width: 6),
                _buildFilterChipPill('Sedang (70-84%)', _selectedKategori == 'Sedang', () {
                  setState(() => _selectedKategori = _selectedKategori == 'Sedang' ? null : 'Sedang');
                  _fetchData();
                }),
                const SizedBox(width: 6),
                _buildFilterChipPill('Kurang (<70%)', _selectedKategori == 'Kurang', () {
                  setState(() => _selectedKategori = _selectedKategori == 'Kurang' ? null : 'Kurang');
                  _fetchData();
                }),

                if (_disposals.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                  const SizedBox(width: 10),
                  ..._disposals.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildFilterChipPill(d, _selectedDisposal == d, () {
                        setState(() => _selectedDisposal = _selectedDisposal == d ? null : d);
                        _fetchData();
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTab(String label, String value, IconData icon) {
    final isSelected = _selectedScope == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedScope != value) {
            setState(() => _selectedScope = value);
            _fetchData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? _orangeColor : const Color(0xFF64748B),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? _orangeColor : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChipPill(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _orangeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _orangeColor : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildDciCard(DciReportItem item) {
    final bool isOfflinePending = item.id == -1;
    final Color catColor = isOfflinePending
        ? const Color(0xFF64748B)
        : (item.totalScore >= 85
            ? const Color(0xFF10B981)
            : (item.totalScore >= 70 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
        border: Border.all(color: isOfflinePending ? Colors.amber.shade400 : const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailSheet(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Disposal Title & Score Gauge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          isOfflinePending ? 'SYNC' : '${item.totalScore.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: isOfflinePending ? 9 : 13,
                            fontWeight: FontWeight.w900,
                            color: catColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.disposal ?? 'Disposal Tambang',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: catColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  item.kategoriIndex,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: catColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.area} • ${item.namaDump ?? "-"}${item.pad != null && item.pad!.isNotEmpty ? " (${item.pad})" : ""}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (item.perusahaan != null && item.perusahaan!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item.perusahaan!,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isOfflinePending)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        onSelected: (val) async {
                          if (val == 'detail') {
                            _showDetailSheet(item);
                          } else if (val == 'share') {
                            _showShareOptions(item);
                          } else if (val == 'edit') {
                            _editReport(item);
                          } else if (val == 'delete') {
                            _deleteReport(item);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'detail',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                                SizedBox(width: 10),
                                Text('Lihat Detail', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_rounded, size: 18, color: Color(0xFF10B981)),
                                SizedBox(width: 10),
                                Text(
                                  'Bagikan Laporan',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                                SizedBox(width: 10),
                                Text('Ubah Laporan', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                SizedBox(width: 10),
                                Text('Hapus Laporan', style: TextStyle(fontSize: 13, color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Parameter Scores Chips Row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _paramBadge('Lantai', item.skorLantaiDump),
                    _paramBadge('Berm', item.skorSafetyBerm),
                    _paramBadge('Crest', item.skorKondisiCrest),
                    _paramBadge('Grade', item.skorGradeDumping),
                    _paramBadge('Drainase', item.skorDrainaseDump),
                    _paramBadge('Spillage', item.skorPenataanSpillage),
                    _paramBadge('Rambu', item.skorRambuPenerangan),
                    _paramBadge('Spotter', item.skorSpotterManuver),
                  ],
                ),
                const SizedBox(height: 10),

                // Footer: Date, Shift, Creator & Quick Actions
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(item.tanggal)} ${item.waktu}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCBD5E1))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Oleh: ${item.nama.isNotEmpty ? item.nama : item.nik}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.fotoUrl != null && item.fotoUrl!.isNotEmpty) ...[
                      const Icon(Icons.photo_camera_rounded, size: 16, color: _orangeColor),
                      const SizedBox(width: 6),
                    ],
                    if (!isOfflinePending)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showShareOptions(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share_rounded, size: 13, color: Color(0xFF10B981)),
                              SizedBox(width: 3),
                              Text(
                                'Share',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paramBadge(String name, int score) {
    final Color color = score == 100
        ? const Color(0xFF10B981)
        : (score == 70 ? const Color(0xFFF59E0B) : (score == 40 ? const Color(0xFFF97316) : const Color(0xFFEF4444)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        '$name: $score',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          const Text('Belum ada data inspeksi DCI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Klik tombol di bawah untuk membuat penilaian disposal baru',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DciFormPage()),
              );
              if (res == true) _fetchData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _orangeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Buat Penilaian DCI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 10),
            Text(_errorMessage ?? 'Terjadi kesalahan memuat data',
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _fetchData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
