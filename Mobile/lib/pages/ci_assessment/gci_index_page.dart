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
import 'gci_form_page.dart';
import 'gci_model.dart';

class GciIndexPage extends StatefulWidget {
  const GciIndexPage({super.key});

  @override
  State<GciIndexPage> createState() => _GciIndexPageState();
}

class _GciIndexPageState extends State<GciIndexPage> {
  final _api = ApiService();

  List<GciReportItem> _reports = [];
  GciSummaryStats _stats = GciSummaryStats();
  List<String> _pits = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedPit;
  String? _selectedTarp;

  String _currentUserNik = '';
  String _currentUserNama = '';
  String _currentUserCompany = '';
  int _currentUserCompanyId = 0;
  String _selectedScope = 'my_history'; // 'my_history', 'pic', 'created', 'all'
  final _searchController = TextEditingController();

  static const _blueColor = Color(0xFF0284C7);

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

  Future<List<GciReportItem>> _loadPendingGciJobs() async {
    final List<GciReportItem> pending = [];
    try {
      final rows = await DatabaseService().rawQuery(
        "SELECT payload FROM offline_sync_jobs WHERE feature = 'gci' ORDER BY created_at DESC",
      );
      for (final r in rows) {
        final payloadRaw = r['payload']?.toString();
        if (payloadRaw == null || payloadRaw.isEmpty) continue;
        final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
        final map = Map<String, dynamic>.from(payload['map'] as Map? ?? {});
        final date = DateTime.tryParse(map['tanggal']?.toString() ?? '') ?? DateTime.now();
        pending.add(
          GciReportItem(
            id: -1,
            tanggal: date,
            waktu: map['waktu']?.toString() ?? '12:00',
            nik: map['nik']?.toString() ?? '',
            nama: map['nama']?.toString() ?? '',
            departemen: map['departemen']?.toString(),
            perusahaan: map['perusahaan']?.toString(),
            perusahaanId: map['perusahaan_id'] as int?,
            judulTemuan: map['judul_temuan']?.toString() ?? 'Inspeksi Geoteknik Offline',
            dueDate: DateTime.tryParse(map['due_date']?.toString() ?? ''),
            jenisInspeksi: map['jenis_inspeksi']?.toString() ?? 'Inspeksi Rutin',
            pit: map['pit']?.toString() ?? 'Pit Offline',
            area: map['area']?.toString() ?? 'Area Tambang',
            namaLereng: map['nama_lereng']?.toString(),
            areaType: map['area_type']?.toString() ?? 'Highwall',
            lokasi: map['lokasi']?.toString() ?? '',
            detilLokasi: map['detil_lokasi']?.toString(),
            shift: map['shift']?.toString(),
            latitude: map['latitude']?.toString(),
            longitude: map['longitude']?.toString(),
            skorGeometriLereng: int.tryParse(map['skor_geometri_lereng']?.toString() ?? '') ?? 100,
            skorKondisiCrestToe: int.tryParse(map['skor_kondisi_crest_toe']?.toString() ?? '') ?? 100,
            skorTensionCrack: int.tryParse(map['skor_tension_crack']?.toString() ?? '') ?? 100,
            skorKestabilanBatuan: int.tryParse(map['skor_kestabilan_batuan']?.toString() ?? '') ?? 100,
            skorRembesanDrainase: int.tryParse(map['skor_rembesan_drainase']?.toString() ?? '') ?? 100,
            skorPemantauanSensor: int.tryParse(map['skor_pemantauan_sensor']?.toString() ?? '') ?? 100,
            skorDemarkasiZona: int.tryParse(map['skor_demarkasi_zona']?.toString() ?? '') ?? 100,
            skorKepatuhanRekomendasi: int.tryParse(map['skor_kepatuhan_rekomendasi']?.toString() ?? '') ?? 100,
            totalScore: 100.0,
            kategoriIndex: 'PENDING SYNC',
            tarpLevel: map['manual_tarp_level']?.toString() ?? 'GREEN',
            catatan: map['catatan']?.toString(),
            tindakanPerbaikan: map['tindakan_perbaikan']?.toString(),
            pic: map['pic']?.toString(),
            picNik: map['pic_nik']?.toString(),
            pjaNama: map['pja_nama']?.toString(),
            pjaNik: map['pja_nik']?.toString(),
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
      final res = await _api.getGciList(
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        pit: _selectedPit,
        tarpLevel: _selectedTarp,
        userNik: _currentUserNik.isNotEmpty ? _currentUserNik : null,
        userNama: _currentUserNama.isNotEmpty ? _currentUserNama : null,
        companyId: _currentUserCompanyId > 0 ? _currentUserCompanyId : null,
        companyName: _currentUserCompany.isNotEmpty ? _currentUserCompany : null,
        scope: _selectedScope,
      );

      final pendingJobs = await _loadPendingGciJobs();

      res.fold(
        (err) async {
          final prefs = await SharedPreferences.getInstance();
          final cacheRaw = prefs.getString('gci_cache_list');
          if (cacheRaw != null && cacheRaw.isNotEmpty) {
            try {
              final cachedData = jsonDecode(cacheRaw) as Map<String, dynamic>;
              final rawList = cachedData['data'] as List<dynamic>? ?? [];
              final reports = rawList.map((e) => GciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
              final stats = GciSummaryStats.fromJson(cachedData['stats'] as Map<String, dynamic>? ?? {});
              final pits = (cachedData['pitList'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
              if (mounted) {
                setState(() {
                  _reports = [...pendingJobs, ...reports];
                  _stats = stats;
                  _pits = pits;
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
          final listRaw = data['data'] as List? ?? [];
          final items = listRaw.map((e) => GciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

          GciSummaryStats stats = GciSummaryStats();
          if (data['stats'] != null) {
            stats = GciSummaryStats.fromJson(Map<String, dynamic>.from(data['stats'] as Map));
          }

          final pitList = (data['pitList'] as List?)?.map((e) => e.toString()).toList() ?? [];

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('gci_cache_list', jsonEncode(data));
          } catch (_) {}

          if (mounted) {
            setState(() {
              _reports = [...pendingJobs, ...items];
              _stats = stats;
              _pits = pitList;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      final localReports = await _loadLocalReports();
      final pendingJobs = await _loadPendingGciJobs();
      if (mounted) {
        setState(() {
          _reports = [...pendingJobs, ...localReports];
          _isLoading = false;
        });
      }
    }
  }

  Future<List<GciReportItem>> _loadLocalReports() async {
    try {
      final sqldb = await DatabaseService().database;
      final rows = await sqldb.rawQuery(
        'SELECT * FROM tbl_t_gci_report ORDER BY id DESC LIMIT 50',
      );
      return rows.map((r) => GciReportItem(
        id: r['id'] as int? ?? 0,
        tanggal: DateTime.tryParse(r['tanggal']?.toString() ?? '') ?? DateTime.now(),
        waktu: r['waktu']?.toString() ?? '12:00',
        nik: r['nik']?.toString() ?? '',
        nama: r['nama']?.toString() ?? '',
        departemen: r['departemen']?.toString(),
        perusahaan: r['perusahaan']?.toString(),
        perusahaanId: r['perusahaan_id'] as int?,
        judulTemuan: r['judul_temuan']?.toString(),
        dueDate: DateTime.tryParse(r['due_date']?.toString() ?? ''),
        jenisInspeksi: r['jenis_inspeksi']?.toString() ?? 'Inspeksi Rutin',
        pit: r['pit']?.toString(),
        area: r['area']?.toString() ?? '',
        namaLereng: r['nama_lereng']?.toString(),
        areaType: r['area_type']?.toString() ?? 'Highwall',
        lokasi: r['lokasi']?.toString() ?? '',
        detilLokasi: r['detil_lokasi']?.toString(),
        shift: r['shift']?.toString(),
        latitude: r['latitude']?.toString(),
        longitude: r['longitude']?.toString(),
        skorGeometriLereng: r['skor_geometri_lereng'] as int? ?? 100,
        skorKondisiCrestToe: r['skor_kondisi_crest_toe'] as int? ?? 100,
        skorTensionCrack: r['skor_tension_crack'] as int? ?? 100,
        skorKestabilanBatuan: r['skor_kestabilan_batuan'] as int? ?? 100,
        skorRembesanDrainase: r['skor_rembesan_drainase'] as int? ?? 100,
        skorPemantauanSensor: r['skor_pemantauan_sensor'] as int? ?? 100,
        skorDemarkasiZona: r['skor_demarkasi_zona'] as int? ?? 100,
        skorKepatuhanRekomendasi: r['skor_kepatuhan_rekomendasi'] as int? ?? 100,
        totalScore: (r['total_score'] as num?)?.toDouble() ?? 100.0,
        kategoriIndex: r['kategori_index']?.toString() ?? 'Baik',
        tarpLevel: r['tarp_level']?.toString() ?? 'GREEN',
        catatan: r['catatan']?.toString(),
        tindakanPerbaikan: r['tindakan_perbaikan']?.toString(),
        pic: r['pic']?.toString(),
        picNik: r['pic_nik']?.toString(),
        pjaNama: r['pja_nama']?.toString(),
        pjaNik: r['pja_nik']?.toString(),
        fotoUrl: r['foto_url']?.toString(),
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Color _getTarpColor(String tarp) {
    switch (tarp.toUpperCase()) {
      case 'RED':
        return const Color(0xFFEF4444);
      case 'ORANGE':
        return const Color(0xFFEA580C);
      case 'YELLOW':
        return const Color(0xFFEAB308);
      case 'GREEN':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _deleteReport(GciReportItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Hapus Laporan GCI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin menghapus laporan GCI ini?'),
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
                    item.judulTemuan ?? item.namaLereng ?? item.pit ?? item.lokasi,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.pit ?? item.area} • TARP ${item.tarpLevel} • Skor: ${item.totalScore.toStringAsFixed(0)}%',
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
          final res = await _api.deleteGciReport(item.id);
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
                    content: Text('Laporan GCI berhasil dihapus dari server.'),
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
        await db.delete('tbl_t_gci_report', where: 'id = ?', whereArgs: [item.id]);
      } catch (_) {}

      _fetchData();
    }
  }

  Future<void> _editReport(GciReportItem item) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GciFormPage(editData: item)),
    );
    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan GCI berhasil diperbarui.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _fetchData();
    }
  }

  String _buildReportShareText(GciReportItem item) {
    final tglStr = DateFormat('dd MMM yyyy').format(item.tanggal);
    final text = StringBuffer();
    text.writeln('📋 *HASIL EVALUASI GEOTECHNICAL CONDITION INDEX (GCI)*');
    text.writeln('=================================');
    text.writeln('📍 *Judul / Lokasi*: ${item.judulTemuan ?? item.namaLereng ?? item.lokasi}');
    text.writeln('🚩 *Pit / Lereng*: ${item.pit ?? item.area} • ${item.areaType ?? "Highwall"}${item.namaLereng != null && item.namaLereng!.isNotEmpty ? " (${item.namaLereng!})" : ""}');
    if (item.perusahaan != null && item.perusahaan!.isNotEmpty) {
      text.writeln('🏢 *Perusahaan*: ${item.perusahaan}');
    }
    text.writeln('📅 *Waktu*: $tglStr ${item.waktu} • ${item.shift ?? "Shift 1"}');
    text.writeln('👤 *Pelapor*: ${item.nama.isNotEmpty ? item.nama : item.nik}');
    text.writeln('---------------------------------');
    text.writeln('🚨 *STATUS TARP*: *TARP ${item.tarpLevel}* | Skor: ${item.totalScore.toStringAsFixed(1)}% (${item.kategoriIndex.toUpperCase()})');
    text.writeln('• GEO-01. Geometri & Lereng (15%): ${item.skorGeometriLereng}');
    text.writeln('• GEO-02. Kondisi Crest & Toe (15%): ${item.skorKondisiCrestToe}');
    text.writeln('• GEO-03. Bebas Tension Crack (15%): ${item.skorTensionCrack}');
    text.writeln('• GEO-04. Kestabilan Batuan (15%): ${item.skorKestabilanBatuan}');
    text.writeln('• HYD-01. Rembesan Air & Drainase (10%): ${item.skorRembesanDrainase}');
    text.writeln('• MON-01. Pemantauan Sensor (10%): ${item.skorPemantauanSensor}');
    text.writeln('• CTL-01. Demarkasi Exclusion Zone (10%): ${item.skorDemarkasiZona}');
    text.writeln('• CTL-02. Kepatuhan Mitigasi (10%): ${item.skorKepatuhanRekomendasi}');
    text.writeln('---------------------------------');
    if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
      text.writeln('📝 *Catatan*: ${item.catatan!.trim()}');
    }
    if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.trim().isNotEmpty) {
      text.writeln('🛠️ *Rekomendasi Tindakan*: ${item.tindakanPerbaikan!.trim()}');
    }
    if (item.pic != null && item.pic!.trim().isNotEmpty) {
      text.writeln('👷 *PIC Penanggung Jawab*: ${item.pic!.trim()}');
    }
    if (item.pjaNama != null && item.pjaNama!.trim().isNotEmpty) {
      text.writeln('🧑‍💼 *PJA Geoteknik*: ${item.pjaNama!.trim()}');
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

  Future<void> _shareWhatsApp(GciReportItem item) async {
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

  Future<void> _copyReportText(GciReportItem item) async {
    final msg = _buildReportShareText(item);
    await Clipboard.setData(ClipboardData(text: msg));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teks ringkasan laporan GCI berhasil disalin ke clipboard!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _showShareOptions(GciReportItem item) {
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
                    'Bagikan Laporan GCI',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.judulTemuan ?? item.namaLereng ?? item.pit} • TARP ${item.tarpLevel} • Skor: ${item.totalScore.toStringAsFixed(0)}%',
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
                subtitle: const Text('Salin ringkasan evaluasi GCI ke clipboard perangkat', style: TextStyle(fontSize: 11.5)),
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

  void _showDetailSheet(GciReportItem item) {
    final tarpColor = _getTarpColor(item.tarpLevel);

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
                              color: _blueColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.landscape_rounded, color: _blueColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text('Detail Laporan GCI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                color: tarpColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: tarpColor.withOpacity(0.3), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  item.tarpLevel,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: tarpColor),
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
                                          item.judulTemuan ?? '${item.pit ?? item.area} - ${item.areaType ?? "Lereng"}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: tarpColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: tarpColor.withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          'TARP ${item.tarpLevel}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: tarpColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.pit ?? item.area} • ${item.areaType ?? "Highwall"}${item.namaLereng != null && item.namaLereng!.isNotEmpty ? " (${item.namaLereng})" : ""}',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Skor: ${item.totalScore.toStringAsFixed(0)}% (${item.kategoriIndex})',
                                    style: TextStyle(fontSize: 12, color: tarpColor, fontWeight: FontWeight.bold),
                                  ),
                                  if (item.perusahaan != null && item.perusahaan!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        item.perusahaan!,
                                        style: const TextStyle(fontSize: 11.5, color: _blueColor, fontWeight: FontWeight.w600),
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
                        'Breakdown 8 Parameter Geoteknik (GCI)',
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
                            _detailParamRow('GEO-01. Geometri & Lereng (15%)', item.skorGeometriLereng),
                            const Divider(height: 1),
                            _detailParamRow('GEO-02. Kondisi Crest & Toe (15%)', item.skorKondisiCrestToe),
                            const Divider(height: 1),
                            _detailParamRow('GEO-03. Bebas Tension Crack (15%)', item.skorTensionCrack),
                            const Divider(height: 1),
                            _detailParamRow('GEO-04. Kestabilan Batuan (15%)', item.skorKestabilanBatuan),
                            const Divider(height: 1),
                            _detailParamRow('HYD-01. Rembesan Air & Drainase (10%)', item.skorRembesanDrainase),
                            const Divider(height: 1),
                            _detailParamRow('MON-01. Pemantauan Sensor (10%)', item.skorPemantauanSensor),
                            const Divider(height: 1),
                            _detailParamRow('CTL-01. Demarkasi Exclusion Zone (10%)', item.skorDemarkasiZona),
                            const Divider(height: 1),
                            _detailParamRow('CTL-02. Kepatuhan Mitigasi (10%)', item.skorKepatuhanRekomendasi),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Catatan Observasi
                      if (item.catatan != null && item.catatan!.trim().isNotEmpty) ...[
                        const Text('Catatan Observasi Geoteknik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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

                      // Rekomendasi Mitigasi
                      if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.trim().isNotEmpty) ...[
                        const Text('Rekomendasi Tindakan Mitigasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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

                      // PIC & PJA
                      if ((item.pic != null && item.pic!.trim().isNotEmpty) || (item.pjaNama != null && item.pjaNama!.trim().isNotEmpty)) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              if (item.pic != null && item.pic!.trim().isNotEmpty)
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: _blueColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person_rounded, color: _blueColor, size: 18),
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
                              if (item.pic != null && item.pic!.trim().isNotEmpty && item.pjaNama != null && item.pjaNama!.trim().isNotEmpty)
                                const Divider(height: 16),
                              if (item.pjaNama != null && item.pjaNama!.trim().isNotEmpty)
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.supervisor_account_rounded, color: Colors.amber, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('PJA Geoteknik', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                          Text(item.pjaNama!.trim(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Foto Dokumentasi
                      if (resolvedPhotoUrl != null) ...[
                        const Text('Dokumentasi Foto Lereng Lapangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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
    final Color color = score >= 100
        ? const Color(0xFF10B981)
        : (score >= 70 ? const Color(0xFFF59E0B) : (score >= 40 ? const Color(0xFFF97316) : const Color(0xFFEF4444)));

    String statusText = 'Optimal';
    if (score >= 70 && score < 100) statusText = 'Cukup';
    if (score >= 40 && score < 70) statusText = 'Kurang';
    if (score < 40) statusText = 'Kritis';

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
      appBar: const TopBar(title: 'Geotechnical Condition Index (GCI)'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blueColor,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Penilaian GCI', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GciFormPage()),
          );
          if (res == true) _fetchData();
        },
      ),
      body: RefreshIndicator(
        color: _blueColor,
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [
            // Top Metrics (2x2 Grid)
            _buildTopMetrics(),
            const SizedBox(height: 14),

            // Scope Tabs & Search & TARP Filter Bar
            _buildFilterBar(),
            const SizedBox(height: 14),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedScope == 'all' && _currentUserCompany.isNotEmpty
                        ? 'Semua Lereng - $_currentUserCompany (${_reports.length})'
                        : 'Riwayat Inspeksi GCI (${_reports.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _blueColor)),
              ],
            ),
            const SizedBox(height: 10),

            // Content List
            if (_isLoading && _reports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: _blueColor),
                ),
              )
            else if (_errorMessage != null)
              _buildErrorState()
            else if (_reports.isEmpty)
              _buildEmptyState()
            else
              ..._reports.map((item) => _buildGciCard(item)),
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
                accentColor: _blueColor,
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
                title: 'TARP Normal (Green)',
                value: '${_stats.tarpGreenCount}',
                subtitle: 'Kondisi Lereng Aman',
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Perlu Perhatian',
                value: '${_stats.tarpRedCount + _stats.tarpOrangeCount + _stats.tarpYellowCount}',
                subtitle: '${_stats.tarpRedCount} Red, ${_stats.tarpOrangeCount} Orange, ${_stats.tarpYellowCount} Yellow',
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
                _buildScopeTab('Semua Lereng', 'all', Icons.landscape_rounded),
              ],
            ),
          ),

          if (_selectedScope == 'all' && _currentUserCompany.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _blueColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 14, color: _blueColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Menampilkan seluruh lereng: $_currentUserCompany',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _blueColor),
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
                hintText: 'Cari pit, lereng, judul temuan, atau nama...',
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

          // TARP & Pit Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChipPill('Semua TARP', _selectedTarp == null, () {
                  setState(() => _selectedTarp = null);
                  _fetchData();
                }),
                const SizedBox(width: 6),
                _buildFilterChipPill('TARP 0 (GREEN)', _selectedTarp == 'GREEN', () {
                  setState(() => _selectedTarp = _selectedTarp == 'GREEN' ? null : 'GREEN');
                  _fetchData();
                }, const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildFilterChipPill('TARP 1 (YELLOW)', _selectedTarp == 'YELLOW', () {
                  setState(() => _selectedTarp = _selectedTarp == 'YELLOW' ? null : 'YELLOW');
                  _fetchData();
                }, const Color(0xFFEAB308)),
                const SizedBox(width: 6),
                _buildFilterChipPill('TARP 2 (ORANGE)', _selectedTarp == 'ORANGE', () {
                  setState(() => _selectedTarp = _selectedTarp == 'ORANGE' ? null : 'ORANGE');
                  _fetchData();
                }, const Color(0xFFEA580C)),
                const SizedBox(width: 6),
                _buildFilterChipPill('TARP 3 (RED)', _selectedTarp == 'RED', () {
                  setState(() => _selectedTarp = _selectedTarp == 'RED' ? null : 'RED');
                  _fetchData();
                }, const Color(0xFFEF4444)),

                if (_pits.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                  const SizedBox(width: 10),
                  ..._pits.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildFilterChipPill(p, _selectedPit == p, () {
                        setState(() => _selectedPit = _selectedPit == p ? null : p);
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
                color: isSelected ? _blueColor : const Color(0xFF64748B),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? _blueColor : const Color(0xFF64748B),
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

  Widget _buildFilterChipPill(String label, bool isSelected, VoidCallback onTap, [Color? activeColor]) {
    final Color color = activeColor ?? _blueColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
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

  Widget _buildGciCard(GciReportItem item) {
    final bool isOfflinePending = item.id == -1;
    final Color tarpColor = _getTarpColor(item.tarpLevel);

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
                // Top Row: Title & TARP Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: tarpColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          isOfflinePending ? 'SYNC' : item.tarpLevel,
                          style: TextStyle(
                            fontSize: isOfflinePending ? 9 : 10,
                            fontWeight: FontWeight.w900,
                            color: tarpColor,
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
                                  item.judulTemuan ?? '${item.pit ?? item.area} - ${item.areaType ?? "Lereng"}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tarpColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: tarpColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'TARP ${item.tarpLevel}',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tarpColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.pit ?? item.area} • ${item.areaType ?? "Highwall"}${item.namaLereng != null && item.namaLereng!.isNotEmpty ? " (${item.namaLereng})" : ""}',
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
                    _paramBadge('Geometri', item.skorGeometriLereng),
                    _paramBadge('Crest/Toe', item.skorKondisiCrestToe),
                    _paramBadge('Crack', item.skorTensionCrack),
                    _paramBadge('Rockfall', item.skorKestabilanBatuan),
                    _paramBadge('Drainase', item.skorRembesanDrainase),
                    _paramBadge('Sensor', item.skorPemantauanSensor),
                    _paramBadge('Zona', item.skorDemarkasiZona),
                    _paramBadge('Kepatuhan', item.skorKepatuhanRekomendasi),
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
                      const Icon(Icons.photo_camera_rounded, size: 16, color: _blueColor),
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
    final Color color = score >= 100
        ? const Color(0xFF10B981)
        : (score >= 70 ? const Color(0xFFF59E0B) : (score >= 40 ? const Color(0xFFF97316) : const Color(0xFFEF4444)));

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
              color: _blueColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.landscape_outlined, size: 32, color: _blueColor),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Laporan Inspeksi GCI',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lakukan evaluasi Geotechnical Condition Index (GCI) untuk kestabilan lereng, crest, toe, dan sistem TARP.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blueColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Buat Inspeksi Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GciFormPage()),
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
            _errorMessage ?? 'Terjadi kesalahan memuat data GCI',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blueColor,
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
