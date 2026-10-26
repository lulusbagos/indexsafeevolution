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
import 'spi_form_page.dart';
import 'spi_model.dart';

class SpiIndexPage extends StatefulWidget {
  const SpiIndexPage({super.key});

  @override
  State<SpiIndexPage> createState() => _SpiIndexPageState();
}

class _SpiIndexPageState extends State<SpiIndexPage> {
  final _api = ApiService();

  List<SpiReportItem> _reports = [];
  SpiSummaryStats _stats = SpiSummaryStats();
  List<String> _kolams = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedKolam;
  String? _selectedKategori;

  String _currentUserNik = '';
  String _currentUserNama = '';
  String _currentUserCompany = '';
  int _currentUserCompanyId = 0;
  String _selectedScope = 'my_history'; // 'my_history', 'pic', 'created', 'all'
  final _searchController = TextEditingController();

  static const _tealColor = Color(0xFF0D9488);

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

  Future<List<SpiReportItem>> _loadPendingSpiJobs() async {
    final List<SpiReportItem> pending = [];
    try {
      final rows = await DatabaseService().rawQuery(
        "SELECT payload FROM offline_sync_jobs WHERE feature = 'spi' ORDER BY created_at DESC",
      );
      for (final r in rows) {
        final payloadRaw = r['payload']?.toString();
        if (payloadRaw == null || payloadRaw.isEmpty) continue;
        final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
        final map = Map<String, dynamic>.from(payload['map'] as Map? ?? {});
        final date = DateTime.tryParse(map['tanggal']?.toString() ?? '') ?? DateTime.now();
        pending.add(
          SpiReportItem(
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
            namaKolam: map['nama_kolam']?.toString() ?? 'Kolam Offline',
            titikPenaatan: map['titik_penaatan']?.toString(),
            shift: map['shift']?.toString(),
            latitude: map['latitude']?.toString(),
            longitude: map['longitude']?.toString(),
            skorKapasitasEndapan: int.tryParse(map['skor_kapasitas_endapan']?.toString() ?? '') ?? 100,
            skorKondisiTanggul: int.tryParse(map['skor_kondisi_tanggul']?.toString() ?? '') ?? 100,
            skorSekatBaffle: int.tryParse(map['skor_sekat_baffle']?.toString() ?? '') ?? 100,
            skorPelimpahSpillway: int.tryParse(map['skor_pelimpah_spillway']?.toString() ?? '') ?? 100,
            skorFasilitasDosing: int.tryParse(map['skor_fasilitas_dosing']?.toString() ?? '') ?? 100,
            skorKualitasAirFisik: int.tryParse(map['skor_kualitas_air_fisik']?.toString() ?? '') ?? 100,
            skorTitikPenaatanDebit: int.tryParse(map['skor_titik_penaatan_debit']?.toString() ?? '') ?? 100,
            skorRambuPengaman: int.tryParse(map['skor_rambu_pengaman']?.toString() ?? '') ?? 100,
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
      final res = await _api.getSpiList(
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        kolam: _selectedKolam,
        kategori: _selectedKategori,
        userNik: _currentUserNik.isNotEmpty ? _currentUserNik : null,
        userNama: _currentUserNama.isNotEmpty ? _currentUserNama : null,
        companyId: _currentUserCompanyId > 0 ? _currentUserCompanyId : null,
        companyName: _currentUserCompany.isNotEmpty ? _currentUserCompany : null,
        scope: _selectedScope,
      );

      final pendingJobs = await _loadPendingSpiJobs();

      res.fold(
        (err) async {
          final prefs = await SharedPreferences.getInstance();
          final cacheRaw = prefs.getString('spi_cache_list');
          if (cacheRaw != null && cacheRaw.isNotEmpty) {
            try {
              final cachedData = jsonDecode(cacheRaw) as Map<String, dynamic>;
              final rawList = cachedData['data'] as List<dynamic>? ?? [];
              final reports = rawList.map((e) => SpiReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
              final stats = SpiSummaryStats.fromJson(cachedData['stats'] as Map<String, dynamic>? ?? {});
              final kolams = (cachedData['kolamList'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
              if (mounted) {
                setState(() {
                  _reports = [...pendingJobs, ...reports];
                  _stats = stats;
                  _kolams = kolams;
                  _isLoading = false;
                  _errorMessage = null;
                });
                return;
              }
            } catch (_) {}
          }
          final localReports = await _loadLocalReports();
          if (mounted) {
            setState(() {
              _reports = [...pendingJobs, ...localReports];
              _isLoading = false;
              _errorMessage = null;
            });
          }
        },
        (data) async {
          final rawList = data['data'] as List? ?? [];
          final items = rawList.map((e) => SpiReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

          SpiSummaryStats stats = SpiSummaryStats();
          if (data['stats'] != null) {
            stats = SpiSummaryStats.fromJson(Map<String, dynamic>.from(data['stats'] as Map));
          }

          final kolamList = (data['kolamList'] as List?)?.map((e) => e.toString()).toList() ?? [];

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('spi_cache_list', jsonEncode(data));
          } catch (_) {}

          if (mounted) {
            setState(() {
              _reports = [...pendingJobs, ...items];
              _stats = stats;
              _kolams = kolamList;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      final localReports = await _loadLocalReports();
      final pendingJobs = await _loadPendingSpiJobs();
      if (mounted) {
        setState(() {
          _reports = [...pendingJobs, ...localReports];
          _isLoading = false;
        });
      }
    }
  }

  Future<List<SpiReportItem>> _loadLocalReports() async {
    try {
      final sqldb = await DatabaseService().database;
      final rows = await sqldb.rawQuery(
        'SELECT * FROM tbl_t_spi_report ORDER BY id DESC LIMIT 50',
      );
      return rows.map((r) => SpiReportItem(
        id: r['id'] as int? ?? 0,
        tanggal: DateTime.tryParse(r['tanggal']?.toString() ?? '') ?? DateTime.now(),
        waktu: r['waktu']?.toString() ?? '12:00',
        nik: r['nik']?.toString() ?? '',
        nama: r['nama']?.toString() ?? '',
        departemen: r['departemen']?.toString(),
        perusahaan: r['perusahaan']?.toString(),
        perusahaanId: r['perusahaan_id'] as int?,
        area: r['area']?.toString() ?? '',
        lokasi: r['lokasi']?.toString() ?? '',
        detilLokasi: r['detil_lokasi']?.toString(),
        namaKolam: r['nama_kolam']?.toString(),
        titikPenaatan: r['titik_penaatan']?.toString(),
        shift: r['shift']?.toString(),
        latitude: r['latitude']?.toString(),
        longitude: r['longitude']?.toString(),
        skorKapasitasEndapan: r['skor_kapasitas_endapan'] as int? ?? 100,
        skorKondisiTanggul: r['skor_kondisi_tanggul'] as int? ?? 100,
        skorSekatBaffle: r['skor_sekat_baffle'] as int? ?? 100,
        skorPelimpahSpillway: r['skor_pelimpah_spillway'] as int? ?? 100,
        skorFasilitasDosing: r['skor_fasilitas_dosing'] as int? ?? 100,
        skorKualitasAirFisik: r['skor_kualitas_air_fisik'] as int? ?? 100,
        skorTitikPenaatanDebit: r['skor_titik_penaatan_debit'] as int? ?? 100,
        skorRambuPengaman: r['skor_rambu_pengaman'] as int? ?? 100,
        totalScore: (r['total_score'] as num?)?.toDouble() ?? 100.0,
        kategoriIndex: r['kategori_index']?.toString() ?? 'Baik',
        catatan: r['catatan']?.toString(),
        tindakanPerbaikan: r['tindakan_perbaikan']?.toString(),
        pic: r['pic']?.toString(),
        fotoUrl: r['foto_url']?.toString(),
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Color _getCategoryColor(String kat, double score) {
    if (kat.toUpperCase() == 'PENDING SYNC') return const Color(0xFF64748B);
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _deleteReport(SpiReportItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Hapus Laporan SPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin menghapus laporan SPI ini?'),
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
                    item.namaKolam ?? item.lokasi,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.area} • Skor: ${item.totalScore.toStringAsFixed(0)}% (${item.kategoriIndex})',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (item.id > 0) {
        try {
          final res = await _api.deleteSpiReport(item.id);
          res.fold(
            (err) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menghapus di server: ${err['message'] ?? err}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Laporan SPI berhasil dihapus dari server.'),
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
        await db.delete('tbl_t_spi_report', where: 'id = ?', whereArgs: [item.id]);
      } catch (_) {}

      _fetchData();
    }
  }

  Future<void> _editReport(SpiReportItem item) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SpiFormPage(editData: item)),
    );
    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan SPI berhasil diperbarui.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _fetchData();
    }
  }

  String _buildReportShareText(SpiReportItem item) {
    final tglStr = DateFormat('dd MMM yyyy').format(item.tanggal);
    final text = StringBuffer();
    text.writeln('📋 *HASIL EVALUASI SEDIMENT POND INDEX (SPI)*');
    text.writeln('=================================');
    text.writeln('📍 *Kolam Sedimen*: ${item.namaKolam ?? item.lokasi}');
    text.writeln('🚩 *Area / Titik*: ${item.area}${item.titikPenaatan != null && item.titikPenaatan!.isNotEmpty ? " • ${item.titikPenaatan!}" : ""}');
    if (item.perusahaan != null && item.perusahaan!.isNotEmpty) {
      text.writeln('🏢 *Perusahaan*: ${item.perusahaan}');
    }
    text.writeln('📅 *Waktu*: $tglStr ${item.waktu} • ${item.shift ?? "Shift 1"}');
    text.writeln('👤 *Pelapor*: ${item.nama.isNotEmpty ? item.nama : item.nik}');
    text.writeln('---------------------------------');
    text.writeln('⭐ *SKOR SPI*: ${item.totalScore.toStringAsFixed(1)}% (${item.kategoriIndex.toUpperCase()})');
    text.writeln('• P01. Kapasitas Endapan Sedimen (15%): ${item.skorKapasitasEndapan}');
    text.writeln('• P02. Tanggul & Kestabilan Dike (15%): ${item.skorKondisiTanggul}');
    text.writeln('• P03. Sekat Baffle & Kompartemen (15%): ${item.skorSekatBaffle}');
    text.writeln('• P04. Saluran Pelimpah Spillway (15%): ${item.skorPelimpahSpillway}');
    text.writeln('• P05. Fasilitas Dosing Koagulan (10%): ${item.skorFasilitasDosing}');
    text.writeln('• P06. Kualitas Air Fisik & TSS (10%): ${item.skorKualitasAirFisik}');
    text.writeln('• P07. Titik Pantau & Ukur Debit (10%): ${item.skorTitikPenaatanDebit}');
    text.writeln('• P08. Rambu Keselamatan & Pengaman (10%): ${item.skorRambuPengaman}');
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

  Future<void> _shareWhatsApp(SpiReportItem item) async {
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

  Future<void> _copyReportText(SpiReportItem item) async {
    final msg = _buildReportShareText(item);
    await Clipboard.setData(ClipboardData(text: msg));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teks ringkasan laporan SPI berhasil disalin ke clipboard!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _showShareOptions(SpiReportItem item) {
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
                    'Bagikan Laporan SPI',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.namaKolam ?? item.lokasi} • Skor: ${item.totalScore.toStringAsFixed(0)}% (${item.kategoriIndex})',
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
                subtitle: const Text('Salin ringkasan evaluasi SPI ke clipboard perangkat', style: TextStyle(fontSize: 11.5)),
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

  void _showDetailSheet(SpiReportItem item) {
    final Color catColor = _getCategoryColor(item.kategoriIndex, item.totalScore);

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
                              color: _tealColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.water_drop_rounded, color: _tealColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text('Detail Laporan SPI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                          item.namaKolam ?? item.lokasi,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: catColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: catColor.withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          item.kategoriIndex,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: catColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.area}${item.titikPenaatan != null && item.titikPenaatan!.isNotEmpty ? " • ${item.titikPenaatan}" : ""}',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                                  ),
                                  if (item.perusahaan != null && item.perusahaan!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        item.perusahaan!,
                                        style: const TextStyle(fontSize: 11.5, color: _tealColor, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('dd MMM yyyy').format(item.tanggal)} • ${item.waktu} • ${item.shift ?? "Shift 1"}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Parameter Breakdown
                      const Text(
                        'Breakdown 8 Parameter Sediment Pond (SPI)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _detailParamRow('P01. Kapasitas Endapan Sedimen (15%)', item.skorKapasitasEndapan),
                            const Divider(height: 1),
                            _detailParamRow('P02. Tanggul & Kestabilan Dike (15%)', item.skorKondisiTanggul),
                            const Divider(height: 1),
                            _detailParamRow('P03. Sekat Baffle & Kompartemen (15%)', item.skorSekatBaffle),
                            const Divider(height: 1),
                            _detailParamRow('P04. Saluran Pelimpah Spillway (15%)', item.skorPelimpahSpillway),
                            const Divider(height: 1),
                            _detailParamRow('P05. Fasilitas Dosing & Koagulan (10%)', item.skorFasilitasDosing),
                            const Divider(height: 1),
                            _detailParamRow('P06. Kualitas Air Fisik & TSS (10%)', item.skorKualitasAirFisik),
                            const Divider(height: 1),
                            _detailParamRow('P07. Titik Pantau & Ukur Debit (10%)', item.skorTitikPenaatanDebit),
                            const Divider(height: 1),
                            _detailParamRow('P08. Rambu Keselamatan & Pengaman (10%)', item.skorRambuPengaman),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Catatan Observasi
                      if (item.catatan != null && item.catatan!.trim().isNotEmpty) ...[
                        const Text('Catatan Observasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(item.catatan!.trim(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Tindakan Perbaikan
                      if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.trim().isNotEmpty) ...[
                        const Text('Tindakan Perbaikan (Corrective Action)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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
                            item.tindakanPerbaikan!.trim(),
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // PIC
                      if (item.pic != null && item.pic!.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _tealColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded, color: _tealColor, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PIC Penanggung Jawab', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                    Text(item.pic!.trim(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Foto Dokumentasi
                      if (resolvedPhotoUrl != null) ...[
                        const Text('Dokumentasi Foto Lapangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      maxScale: 4.0,
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
      appBar: const TopBar(title: 'Sediment Pond Index (SPI)'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _tealColor,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Penilaian SPI', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SpiFormPage()),
          );
          if (res == true) _fetchData();
        },
      ),
      body: RefreshIndicator(
        color: _tealColor,
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
                        ? 'Semua Kolam - $_currentUserCompany (${_reports.length})'
                        : 'Riwayat Inspeksi SPI (${_reports.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _tealColor)),
              ],
            ),
            const SizedBox(height: 10),

            // Content List
            if (_isLoading && _reports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: _tealColor),
                ),
              )
            else if (_errorMessage != null)
              _buildErrorState()
            else if (_reports.isEmpty)
              _buildEmptyState()
            else
              ..._reports.map((item) => _buildSpiCard(item)),
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
                accentColor: _tealColor,
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
                _buildScopeTab('Semua Kolam', 'all', Icons.water_drop_rounded),
              ],
            ),
          ),

          if (_selectedScope == 'all' && _currentUserCompany.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _tealColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 14, color: _tealColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Menampilkan seluruh kolam sedimen: $_currentUserCompany',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tealColor),
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
                hintText: 'Cari kolam, titik penaatan, lokasi, atau nama...',
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

          // Kategori & Kolam Chips
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

                if (_kolams.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                  const SizedBox(width: 10),
                  ..._kolams.map(
                    (k) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildFilterChipPill(k, _selectedKolam == k, () {
                        setState(() => _selectedKolam = _selectedKolam == k ? null : k);
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
                color: isSelected ? _tealColor : const Color(0xFF64748B),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? _tealColor : const Color(0xFF64748B),
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
          color: isSelected ? _tealColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _tealColor : const Color(0xFFE2E8F0),
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

  Widget _buildSpiCard(SpiReportItem item) {
    final bool isOfflinePending = item.id == -1;
    final Color catColor = _getCategoryColor(item.kategoriIndex, item.totalScore);

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
                // Top Row: Title & Score Gauge
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
                                  item.namaKolam ?? 'Kolam Sedimen',
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
                            '${item.area}${item.titikPenaatan != null && item.titikPenaatan!.isNotEmpty ? " • ${item.titikPenaatan}" : ""}',
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
                    _paramBadge('Endapan', item.skorKapasitasEndapan),
                    _paramBadge('Tanggul', item.skorKondisiTanggul),
                    _paramBadge('Baffle', item.skorSekatBaffle),
                    _paramBadge('Spillway', item.skorPelimpahSpillway),
                    _paramBadge('Dosing', item.skorFasilitasDosing),
                    _paramBadge('Kualitas Air', item.skorKualitasAirFisik),
                    _paramBadge('Debit', item.skorTitikPenaatanDebit),
                    _paramBadge('Rambu', item.skorRambuPengaman),
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
                      const Icon(Icons.photo_camera_rounded, size: 16, color: _tealColor),
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
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _tealColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop_outlined, size: 32, color: _tealColor),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Laporan Inspeksi SPI',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lakukan evaluasi Sediment Pond Index (SPI) untuk memantau kualitas air dan kolam sedimen tambang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Buat Inspeksi Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SpiFormPage()),
              );
              if (res == true) _fetchData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Terjadi kesalahan memuat data SPI',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _fetchData,
          ),
        ],
      ),
    );
  }
}
