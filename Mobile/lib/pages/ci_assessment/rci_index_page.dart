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
import 'rci_form_page.dart';
import 'rci_model.dart';
import 'rci_pdf_page.dart';

class RciIndexPage extends StatefulWidget {
  const RciIndexPage({super.key});

  @override
  State<RciIndexPage> createState() => _RciIndexPageState();
}

class _RciIndexPageState extends State<RciIndexPage> {
  final _api = ApiService();

  List<RciReportItem> _reports = [];
  RciSummaryStats _stats = RciSummaryStats();
  List<String> _roads = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedRoad;
  String? _selectedKategori;

  String _currentUserNik = '';
  String _currentUserNama = '';
  String _currentUserCompany = '';
  int _currentUserCompanyId = 0;
  String _selectedScope = 'my_history'; // 'my_history', 'my_approvals', 'my_joints', 'all'

  static const _blueColor = Color(0xFF1D4ED8);
  static const _blueAccent = Color(0xFF3B82F6);
  static const _emeraldColor = Color(0xFF10B981);

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

  Future<List<RciReportItem>> _loadPendingRciJobs() async {
    final List<RciReportItem> pending = [];
    try {
      final rows = await DatabaseService().rawQuery(
        "SELECT payload FROM offline_sync_jobs WHERE feature = 'rci' ORDER BY created_at DESC",
      );
      for (final r in rows) {
        final payloadRaw = r['payload']?.toString();
        if (payloadRaw == null || payloadRaw.isEmpty) continue;
        final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
        final map = Map<String, dynamic>.from(payload['map'] as Map? ?? {});
        final date = DateTime.tryParse(map['tanggal']?.toString() ?? '') ?? DateTime.now();
        pending.add(
          RciReportItem(
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
            namaJalan: map['nama_jalan']?.toString() ?? map['segmen_jalan']?.toString() ?? 'Jalur Tambang',
            segmentJalan: map['segmen_jalan']?.toString(),
            shift: map['shift']?.toString(),
            latitude: map['latitude']?.toString(),
            longitude: map['longitude']?.toString(),
            panjangSegment: double.tryParse(map['panjang_segment']?.toString() ?? '') ?? 100.0,
            defisitSurfacing: 0.0,
            defisitUndulation: 0.0,
            defisitSpoil: 0.0,
            defisitSafetyBerm: 0.0,
            defisitRoadAttachment: 0.0,
            defisitDust: 0.0,
            defisitCrossfall: 0.0,
            defisitDrainage: 0.0,
            skorSurfacing: double.tryParse(map['skor_surfacing']?.toString() ?? '') ?? 4.0,
            skorUndulation: double.tryParse(map['skor_undulation']?.toString() ?? '') ?? 4.0,
            skorSpoil: double.tryParse(map['skor_spoil']?.toString() ?? '') ?? 4.0,
            skorSafetyBerm: double.tryParse(map['skor_safety_berm']?.toString() ?? '') ?? 4.0,
            skorRoadAttachment: double.tryParse(map['skor_road_attachment']?.toString() ?? '') ?? 4.0,
            skorDust: double.tryParse(map['skor_dust']?.toString() ?? '') ?? 4.0,
            skorCrossfall: double.tryParse(map['skor_crossfall']?.toString() ?? '') ?? 4.0,
            skorDrainage: double.tryParse(map['skor_drainage']?.toString() ?? '') ?? 4.0,
            skorPermukaanGroup: 4.0,
            skorSafetyBermGroup: 4.0,
            skorDrainageGroup: 4.0,
            actualRoadScore: 4.0,
            targetScore: 4.0,
            achievement: 100.0,
            totalScore: 4.0,
            kategoriIndex: 'PENDING SYNC',
            catatan: map['catatan']?.toString(),
            tindakanPerbaikan: map['tindakan_perbaikan']?.toString(),
            pic: map['pic']?.toString(),
            fotoUrl: payload['photoPath']?.toString(),
            status: 'Pending',
            createdAt: DateTime.now(),
            members: [],
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
      final res = await _api.getRciList(
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        namaJalan: _selectedRoad,
        kategori: _selectedKategori,
        userNik: _currentUserNik.isNotEmpty ? _currentUserNik : null,
        userNama: _currentUserNama.isNotEmpty ? _currentUserNama : null,
        companyId: _currentUserCompanyId > 0 ? _currentUserCompanyId : null,
        companyName: _currentUserCompany.isNotEmpty ? _currentUserCompany : null,
        scope: _selectedScope,
      );

      final pendingJobs = await _loadPendingRciJobs();

      res.fold(
        (err) async {
          final prefs = await SharedPreferences.getInstance();
          final cacheRaw = prefs.getString('rci_cache_list');
          if (cacheRaw != null && cacheRaw.isNotEmpty) {
            try {
              final cachedData = jsonDecode(cacheRaw) as Map<String, dynamic>;
              final rawList = cachedData['data'] as List<dynamic>? ?? [];
              final reports = rawList.map((e) => RciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
              final stats = RciSummaryStats.fromJson(cachedData['stats'] as Map<String, dynamic>? ?? {});
              final roads = (cachedData['roads'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
              if (mounted) {
                setState(() {
                  _reports = [...pendingJobs, ...reports];
                  _stats = stats;
                  _roads = roads;
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
              _errorMessage = pendingJobs.isNotEmpty ? null : (err['message']?.toString() ?? 'Gagal memuat data RCI');
            });
          }
        },
        (data) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('rci_cache_list', jsonEncode(data));

          if (mounted) {
            final rawList = data['data'] as List<dynamic>? ?? [];
            final reports = rawList.map((e) => RciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
            final rawStats = data['stats'] as Map<String, dynamic>? ?? {};
            final stats = RciSummaryStats.fromJson(rawStats);
            final rawRoads = data['roads'] as List<dynamic>? ?? [];
            final roads = rawRoads.map((e) => e.toString()).toList();

            setState(() {
              _isLoading = false;
              _reports = [...pendingJobs, ...reports];
              _stats = stats;
              _roads = roads;
            });
          }
        },
      );
    } catch (e) {
      final pendingJobs = await _loadPendingRciJobs();
      final prefs = await SharedPreferences.getInstance();
      final cacheRaw = prefs.getString('rci_cache_list');
      if (cacheRaw != null && cacheRaw.isNotEmpty) {
        try {
          final cachedData = jsonDecode(cacheRaw) as Map<String, dynamic>;
          final rawList = cachedData['data'] as List<dynamic>? ?? [];
          final reports = rawList.map((e) => RciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          final stats = RciSummaryStats.fromJson(cachedData['stats'] as Map<String, dynamic>? ?? {});
          final roads = (cachedData['roads'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          if (mounted) {
            setState(() {
              _reports = [...pendingJobs, ...reports];
              _stats = stats;
              _roads = roads;
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
          _errorMessage = pendingJobs.isNotEmpty ? null : 'Mode Offline: Sambungkan jaringan untuk memuat riwayat terbaru.';
        });
      }
    }
  }

  Color _getScoreColor(double score, double achievement) {
    if (achievement >= 85 || score >= 3.6) return const Color(0xFF10B981);
    if (achievement >= 70 || score >= 3.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _openForm([RciReportItem? item]) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RciFormPage(editItem: item),
      ),
    );
    if (res == true) {
      _fetchData();
    }
  }

  void _confirmDelete(RciReportItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Laporan RCI?'),
          ],
        ),
        content: Text(
          'Laporan RCI untuk "${item.namaJalan ?? item.lokasi}" (${DateFormat('dd MMM yyyy').format(item.tanggal)}) akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await _api.deleteRciReport(item.id);
                res.fold(
                  (err) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err['message']?.toString() ?? 'Gagal menghapus laporan')),
                    );
                  },
                  (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Laporan RCI berhasil dihapus.')),
                    );
                  },
                );
              } catch (_) {}

              try {
                final db = await DatabaseService().database;
                await db.delete('tbl_t_rci_report', where: 'id = ?', whereArgs: [item.id]);
              } catch (_) {}

              _fetchData();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _openApprovalDialog(RciReportItem item) {
    final catatanController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _emeraldColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded, color: _emeraldColor, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Persetujuan RCI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda ditunjuk sebagai penyetuju laporan inspeksi jalan ini:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ruas Jalan: ${item.namaJalan ?? item.lokasi}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Pembuat: ${item.nama} (${item.nik})', style: const TextStyle(fontSize: 12)),
                  Text('Skor: ${item.actualRoadScore.toStringAsFixed(2)} / 4.00 (${item.achievement.toStringAsFixed(1)}%)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getScoreColor(item.actualRoadScore, item.achievement))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catatanController,
              decoration: InputDecoration(
                labelText: 'Catatan Persetujuan (Opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Tuliskan catatan perbaikan atau apresiasi...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _emeraldColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Setujui Sekarang'),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.approveRciReport(
                item.id,
                nik: _currentUserNik,
                nama: _currentUserNama,
                role: 'Approver',
                status: 'Approved',
                notes: catatanController.text.trim().isNotEmpty ? catatanController.text.trim() : null,
              );
              res.fold(
                (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err['message']?.toString() ?? 'Gagal menyetujui laporan')),
                  );
                },
                (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Laporan RCI berhasil disetujui!')),
                  );
                  _fetchData();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _shareWhatsApp(RciReportItem item) async {
    final tglStr = DateFormat('dd MMM yyyy').format(item.tanggal);
    final msg = '''*HASIL EVALUASI ROAD CONDITION INDEX (RCI)*
=================================
📍 *Ruas Jalan*: ${item.namaJalan ?? item.lokasi}
🚩 *Segmen/Sta*: ${item.segmentJalan ?? '-'}
📏 *Panjang Segmen*: ${item.panjangSegment?.toStringAsFixed(0) ?? '100'} Meter
📅 *Tanggal/Shift*: $tglStr ${item.waktu} • ${item.shift ?? '-'}
👤 *Tim Sidak*: ${item.creatorsSummary ?? item.nama}
🛡️ *Penyetuju*: ${item.approversSummary ?? '-'}

📊 *SKOR 3 PILAR & KETERCAPAIAN*:
• Permukaan (60%): ${item.skorPermukaanGroup.toStringAsFixed(2)}
• Safety Berm (20%): ${item.skorSafetyBermGroup.toStringAsFixed(2)}
• Drainage (20%): ${item.skorDrainageGroup.toStringAsFixed(2)}
🎯 *Actual Road Score*: ${item.actualRoadScore.toStringAsFixed(2)} / 4.00
📈 *Achievement*: ${item.achievement.toStringAsFixed(1)}% (${item.kategoriIndex.toUpperCase()})

📝 *Catatan*: ${item.catatan ?? '-'}
🛠️ *Rekomendasi*: ${item.tindakanPerbaikan ?? '-'}
👷 *PIC*: ${item.pic ?? '-'}
_Generated via SAP IndexSafe Evolution Mobile_''';

    final encoded = Uri.encodeComponent(msg);
    final uri = Uri.parse('whatsapp://send?text=$encoded');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: msg));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teks laporan berhasil disalin ke clipboard!')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teks laporan berhasil disalin ke clipboard!')),
        );
      }
    }
  }

  void _showDetailModal(RciReportItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _blueColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.alt_route_rounded, color: _blueColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.namaJalan ?? item.lokasi,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${item.segmentJalan ?? '-'} • ${item.shift ?? '-'}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final isDone = item.status == 'Approved' || item.status == 'Closed';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDone
                              ? _emeraldColor.withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDone ? _emeraldColor : const Color(0xFFF59E0B),
                          ),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: TextStyle(
                            color: isDone ? _emeraldColor : const Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Score highlight card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getScoreColor(item.actualRoadScore, item.achievement).withValues(alpha: 0.12),
                      _blueAccent.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getScoreColor(item.actualRoadScore, item.achievement).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Actual Road Score', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          '${item.actualRoadScore.toStringAsFixed(2)} / 4.00',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _getScoreColor(item.actualRoadScore, item.achievement),
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: Colors.grey.shade300),
                    Column(
                      children: [
                        const Text('Achievement', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          '${item.achievement.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _getScoreColor(item.actualRoadScore, item.achievement),
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: Colors.grey.shade300),
                    Column(
                      children: [
                        const Text('Kategori', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                          item.kategoriIndex,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _getScoreColor(item.actualRoadScore, item.achievement),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3 Pilar Breakdown Table
              const Text('Rekapitulasi 3 Pilar Utama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _pilarRow('1. Permukaan Jalan (Bobot 60%)', item.skorPermukaanGroup, _blueColor),
                    const Divider(height: 1),
                    _pilarRow('2. Safety Berm & Fasilitas (Bobot 20%)', item.skorSafetyBermGroup, _emeraldColor),
                    const Divider(height: 1),
                    _pilarRow('3. Drainage & Penirisan (Bobot 20%)', item.skorDrainageGroup, const Color(0xFF06B6D4)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 8 Parameters Deficit Breakdown
              const Text('Rincian 8 Parameter Standar SP3', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _paramTile('Surfacing & Material (20%)', item.skorSurfacing, item.defisitSurfacing, item.panjangSegment ?? 100),
              _paramTile('Undulation / Keriting (35%)', item.skorUndulation, item.defisitUndulation, item.panjangSegment ?? 100),
              _paramTile('Spoil Lebar Jalan 18m (5%)', item.skorSpoil, item.defisitSpoil, item.panjangSegment ?? 100),
              _paramTile('Tinggi Tanggul 3/4 Ban (10%)', item.skorSafetyBerm, item.defisitSafetyBerm, item.panjangSegment ?? 100),
              _paramTile('Road Attachment / Rambu (5%)', item.skorRoadAttachment, item.defisitRoadAttachment, item.panjangSegment ?? 100),
              _paramTile('Pengendalian Debu (5%)', item.skorDust, item.defisitDust, item.panjangSegment ?? 100),
              _paramTile('Crossfall Melintang 0.5-1% (10%)', item.skorCrossfall, item.defisitCrossfall, item.panjangSegment ?? 100),
              _paramTile('Parit / Tali Air Drainase (10%)', item.skorDrainage, item.defisitDrainage, item.panjangSegment ?? 100),

              const SizedBox(height: 16),

              // Team Signatures
              const Text('Berita Acara Tim SP3', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_rounded, size: 16, color: _blueColor),
                        const SizedBox(width: 6),
                        const Text('Dibuat Oleh: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(child: Text(item.creatorsSummary ?? item.nama, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, size: 16, color: _emeraldColor),
                        const SizedBox(width: 6),
                        const Text('Penyetuju: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(child: Text(item.approversSummary ?? '-', style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ],
                ),
              ),

              if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Catatan Observasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(item.catatan!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],

              if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Rekomendasi Tindakan Perbaikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.tindakanPerbaikan!, style: const TextStyle(fontSize: 13, color: Color(0xFFB45309))),
                      if (item.pic != null && item.pic!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('PIC: ${item.pic}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                      ],
                    ],
                  ),
                ),
              ],

              if (item.fotoUrl != null && item.fotoUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Dokumentasi Foto Jalan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.fotoUrl!.startsWith('http')
                        ? item.fotoUrl!
                        : '${ApiService().baseUrl}${item.fotoUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('Foto tidak dapat dimuat')),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              // Action Buttons: PDF and Share
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blueColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text(
                        'Lihat & Unduh PDF',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RciPdfPage(item)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF047857),
                        side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text(
                        'Bagikan WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _shareWhatsApp(item);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pilarRow(String title, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score.toStringAsFixed(2),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paramTile(String name, double score, double defisit, double totalLen) {
    final pct = totalLen > 0 ? ((totalLen - defisit) / totalLen * 100.0).clamp(0.0, 100.0) : 100.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Defisit: ${defisit.toStringAsFixed(0)}m (${pct.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: score >= 3.5 ? _emeraldColor.withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: score >= 3.5 ? _emeraldColor : const Color(0xFFD97706),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(
        title: 'Road Condition Index (RCI)',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _blueColor,
        icon: const Icon(Icons.add_road_rounded, color: Colors.white),
        label: const Text('Inspeksi RCI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Approval Alert Banner (matching web)
                    if (_stats.myPendingApprovalsCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFB45309), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pemberitahuan Persetujuan RCI!',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                                  ),
                                  Text(
                                    'Anda ditunjuk sebagai penyetuju pada ${_stats.myPendingApprovalsCount} laporan RCI pending.',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedScope = 'my_approvals';
                                });
                                _fetchData();
                              },
                              child: const Text('Setujui', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Top 4 Metrics Cards
                    Row(
                      children: [
                        _metricCard('TOTAL RCI', '${_stats.totalReports}', Icons.signpost_rounded, _blueColor),
                        const SizedBox(width: 10),
                        _metricCard('AVG SCORE', '${_stats.avgScore.toStringAsFixed(2)} / 4.00', Icons.speed_rounded,
                            _getScoreColor(_stats.avgScore, _stats.avgAchievement)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _metricCard('JALAN PRIMA', '${_stats.goodCount}', Icons.check_circle_rounded, _emeraldColor),
                        const SizedBox(width: 10),
                        _metricCard('PERLU PERBAIKAN', '${_stats.fairCount + _stats.poorCount}', Icons.warning_rounded,
                            const Color(0xFFEF4444)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Scope Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _scopeChip('Riwayat Saya', 'my_history'),
                          const SizedBox(width: 8),
                          _scopeChip('Perlu Persetujuan', 'my_approvals', count: _stats.myPendingApprovalsCount),
                          const SizedBox(width: 8),
                          _scopeChip('Sidak Saya', 'my_joints', count: _stats.myJointCount),
                          const SizedBox(width: 8),
                          _scopeChip('Semua Jalan (${_currentUserCompany.isNotEmpty ? _currentUserCompany : 'Semua'})', 'all'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search & Filters
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Cari nama jalan, lokasi, tim...',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            onChanged: (val) {
                              _searchQuery = val;
                              _fetchData();
                            },
                          ),
                        ),
                        if (_roads.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            tooltip: 'Pilih Ruas Jalan',
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(Icons.filter_list_rounded, color: _blueColor),
                            ),
                            onSelected: (val) {
                              setState(() {
                                _selectedRoad = val.isEmpty ? null : val;
                              });
                              _fetchData();
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: '', child: Text('Semua Ruas Jalan')),
                              ..._roads.map((r) => PopupMenuItem(value: r, child: Text(r))),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Kategori Chips
                    Row(
                      children: [
                        _kategoriFilterChip('Semua Kategori', null),
                        const SizedBox(width: 6),
                        _kategoriFilterChip('Baik', 'Baik'),
                        const SizedBox(width: 6),
                        _kategoriFilterChip('Sedang', 'Sedang'),
                        const SizedBox(width: 6),
                        _kategoriFilterChip('Kurang', 'Kurang'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content List
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_reports.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alt_route_rounded, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada data inspeksi RCI',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ketuk tombol "Inspeksi RCI" untuk mulai menilai segmen jalan.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _reportCard(_reports[i]),
                    childCount: _reports.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeChip(String label, String scope, {int count = 0}) {
    final active = _selectedScope == scope;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: active ? _blueColor : Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: active,
      selectedColor: _blueColor,
      labelStyle: TextStyle(color: active ? Colors.white : Colors.black87),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: active ? _blueColor : Colors.grey.shade300),
      ),
      onSelected: (_) {
        setState(() {
          _selectedScope = scope;
        });
        _fetchData();
      },
    );
  }

  Widget _kategoriFilterChip(String label, String? val) {
    final active = _selectedKategori == val;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: active,
      selectedColor: _blueColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: active ? _blueColor : Colors.grey.shade700,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: active ? _blueColor : Colors.grey.shade300),
      ),
      onSelected: (_) {
        setState(() {
          _selectedKategori = val;
        });
        _fetchData();
      },
    );
  }

  Widget _reportCard(RciReportItem item) {
    final scoreColor = _getScoreColor(item.actualRoadScore, item.achievement);
    final isApproved = item.status == 'Approved' || item.status == 'Closed';
    final isPendingApprover = !isApproved && item.members.any(
      (m) => m.role == 'Approver' && m.nik == _currentUserNik && m.status == 'Pending',
    );
    final canEdit = item.nik == _currentUserNik;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: isApproved ? _emeraldColor : const Color(0xFFF59E0B), width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailModal(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Road Name & Score Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.namaJalan ?? item.lokasi,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? _emeraldColor.withValues(alpha: 0.15)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isApproved ? _emeraldColor : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item.area} • ${item.segmentJalan ?? '-'} (${item.shift ?? '-'})',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${item.actualRoadScore.toStringAsFixed(2)} / 4.00',
                            style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.achievement.toStringAsFixed(1)}% (${item.kategoriIndex})',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scoreColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3 Pilar Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pilarPill('Permukaan 60%: ${item.skorPermukaanGroup.toStringAsFixed(2)}', _blueColor),
                    _pilarPill('Safety Berm 20%: ${item.skorSafetyBermGroup.toStringAsFixed(2)}', _emeraldColor),
                    _pilarPill('Drainage 20%: ${item.skorDrainageGroup.toStringAsFixed(2)}', const Color(0xFF06B6D4)),
                  ],
                ),
                const SizedBox(height: 8),

                // Signatures summary
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 14, color: _blueColor),
                          const SizedBox(width: 4),
                          const Text('Pembuat: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              item.creatorsSummary ?? item.nama,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.shield_rounded, size: 14, color: _emeraldColor),
                          const SizedBox(width: 4),
                          const Text('Penyetuju: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              item.approversSummary ?? 'Belum ada',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // If user is pending approver, show prominent action button
                if (isPendingApprover) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _emeraldColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Setujui Laporan Ini (Anda Ditunjuk)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _openApprovalDialog(item),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                // Footer: Date & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${DateFormat('dd MMM yyyy').format(item.tanggal)} ${item.waktu}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: _blueColor),
                          tooltip: 'Lihat & Unduh PDF',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RciPdfPage(item)),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, size: 19, color: _emeraldColor),
                          tooltip: 'Bagikan via WhatsApp',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _shareWhatsApp(item),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.orange),
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _openForm(item),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            tooltip: 'Hapus',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDelete(item),
                          ),
                        ],
                      ],
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

  Widget _pilarPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
