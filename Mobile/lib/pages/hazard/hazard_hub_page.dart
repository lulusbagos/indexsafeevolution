import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hazard_hub_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/hazard_pdf_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import 'hazard_create_page.dart';

enum HazardHubTab { summary, action, monitoring }

class HazardHubPage extends StatefulWidget {
  const HazardHubPage({
    this.initialTab = HazardHubTab.summary,
    super.key,
  });

  final HazardHubTab initialTab;

  @override
  State<HazardHubPage> createState() => _HazardHubPageState();
}

class _HazardHubPageState extends State<HazardHubPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();

  late HazardHubTab _currentTab;
  HazardSummary _summary = HazardSummary();
  List<HazardReportItem> _items = [];
  bool _isLoading = true;
  String _activeFilter = 'all'; // sub-filter within the tab
  int _offlineCount = 0;
  int _offlineOpenCount = 0;
  int _offlineClosedCount = 0;
  List<HazardReportItem> _allOfflineItems = [];
  bool _isSyncingOffline = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HazardReportItem> get _filteredItems {
    if (_activeFilter == 'offline_pending') {
      return _allOfflineItems;
    }
    if (_activeFilter == 'all') return _items;
    if (_activeFilter == 'open') {
      return _items
          .where((i) => i.statusTemuan.toLowerCase() == 'open')
          .toList();
    }
    if (_activeFilter == 'inprogress') {
      return _items
          .where((i) => i.statusTemuan.toLowerCase() == 'in progress')
          .toList();
    }
    if (_activeFilter == 'closed') {
      return _items
          .where((i) => i.statusTemuan.toLowerCase() == 'closed')
          .toList();
    }
    if (_activeFilter == 'my_reports') {
      return _items.where((i) => i.isMyReport).toList();
    }
    if (_activeFilter == 'pja_reports') {
      return _items.where((i) => !i.isMyReport).toList();
    }
    return _items;
  }

  Future<void> _ensureSimulatedOfflineDummy() async {
    try {
      final localRows = await _db.rawQuery(
        'SELECT count(1) as jml FROM hazard_trans WHERE deleted_at IS NULL AND sync_id IS NULL',
      );
      final count = (localRows.isNotEmpty && localRows.first['jml'] != null)
          ? (localRows.first['jml'] as int)
          : 0;

      if (count == 0) {
        final prefs = await SharedPreferences.getInstance();
        final alreadySeeded = prefs.getBool('hazard_offline_dummy_created_v2') ?? false;
        if (!alreadySeeded) {
          // Buat file dummy gambar offline yang valid di storage aplikasi
          final docDir = await getApplicationDocumentsDirectory();
          final dummyImageFile = File('${docDir.path}/simulated_hazard_offline.jpg');

          if (!await dummyImageFile.exists()) {
            try {
              final byteData = await rootBundle.load('assets/images/info1.jpg');
              final buffer = byteData.buffer;
              await dummyImageFile.writeAsBytes(
                buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
                flush: true,
              );
            } catch (_) {
              final dummyBytes = base64Decode(
                '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=',
              );
              await dummyImageFile.writeAsBytes(dummyBytes, flush: true);
            }
          }

          final profile = PreferenceService.getProfile();
          final profileId = profile?.id ?? 1;
          final profileNama = profile?.namaLengkap ?? 'LULUS HERMAWAN';
          final profileNik = profile?.noNik ?? '10888';
          final profileDepartemen = profile?.depart ?? 'IT & DIGITAL';

          // Cari PJA dari database SQLite jika ada
          String pjaNama = 'BAMBANG SUPRAPTO';
          String pjaNik = 'EMP-10492';
          String pjaDept = 'PRODUKSI';
          try {
            final empRows = await _db.rawQuery(
              "SELECT no_nik, nama_lengkap, depart FROM employees WHERE nama_lengkap != '' AND no_nik != '$profileNik' LIMIT 1",
            );
            if (empRows.isNotEmpty) {
              pjaNama = empRows.first['nama_lengkap']?.toString() ?? pjaNama;
              pjaNik = empRows.first['no_nik']?.toString() ?? pjaNik;
              pjaDept = empRows.first['depart']?.toString() ?? pjaDept;
            }
          } catch (_) {}

          final now = DateTime.now();
          final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          final code = 'HAZ-OFF-${now.millisecondsSinceEpoch.toString().substring(7)}';

          final Map<String, dynamic> fields = {
            'tanggal': dateStr,
            'waktu': timeStr,
            'nama': profileNama,
            'nik': profileNik,
            'departemen': profileDepartemen,
            'area': 'PIT UTARA',
            'lokasi': 'Loading Point Seam B',
            'detil_lokasi': 'Dekat Lampu Menara No. 4 KM 2.5 Jalur Hauling',
            'temuan': 'Ditemukan ceceran oli & solar tebal di jalur manuver dump truck, berpotensi unit tergelincir dan kecelakaan tambang.',
            'kategori_bahaya': 'Kondisi Tidak Aman',
            'jenis_bahaya': 'Bahan Kimia / B3',
            'jenis_ketidaksesuaian': 'Prosedur K3 Lingkungan',
            'tingkat_resiko': 'Tinggi',
            'tindakan_perbaikan': 'Beri rambu peringatan licin dan taburkan absorbent/pasir segera.',
            'pja': pjaNama,
            'nik_pja': pjaNik,
            'departemen_pja': pjaDept,
            'status_temuan': 'Open',
          };

          final Map<String, dynamic> row = {
            'code': code,
            'title': '${fields['kategori_bahaya']} - ${fields['jenis_bahaya']}',
            'location_detail': '${fields['lokasi']} ${fields['detil_lokasi']}'.trim(),
            'date': fields['tanggal'],
            'time': fields['waktu'],
            'remark': fields['temuan'],
            'image': dummyImageFile.path,
            'repair_remark': null,
            'repair_image': null,
            'status': 0, // 0 = Open
            'pja_id': 0,
            'employee_id': profileId,
            'sync_id': null,
            'area': fields['area'],
            'lokasi': fields['lokasi'],
            'kategori_bahaya': fields['kategori_bahaya'],
            'jenis_bahaya': fields['jenis_bahaya'],
            'jenis_ketidaksesuaian': fields['jenis_ketidaksesuaian'],
            'tingkat_resiko': fields['tingkat_resiko'],
            'tindakan_perbaikan': fields['tindakan_perbaikan'],
            'pja': fields['pja'],
            'nik_pja': fields['nik_pja'],
            'departemen_pja': fields['departemen_pja'],
            'payload_json': jsonEncode(fields),
            'created_at': now.toString(),
          };

          await _db.insert('hazard_trans', row);
          await prefs.setBool('hazard_offline_dummy_created_v2', true);
          await OfflineSyncService.instance.refresh();
        }
      }
    } catch (e) {
      debugPrint('[HazardHubPage] Error seeding dummy offline: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _ensureSimulatedOfflineDummy();

    // 1. Muat data offline lokal yang belum tersinkron
    List<HazardReportItem> offlineItems = [];
    try {
      final profile = PreferenceService.getProfile();
      final localRows = await _db.rawQuery(
        'SELECT * FROM hazard_trans WHERE deleted_at IS NULL AND sync_id IS NULL ORDER BY id DESC',
      );
      _offlineCount = localRows.length;
      offlineItems = localRows.map((row) {
        final localId = row['id'] as int;
        final payloadJson = row['payload_json']?.toString();
        Map<String, dynamic> payload = {};
        if (payloadJson != null && payloadJson.isNotEmpty) {
          try {
            payload = jsonDecode(payloadJson) as Map<String, dynamic>;
          } catch (_) {}
        }

        final isClosed = row['status'] == 2 || payload['status_temuan'] == 'Closed';

        return HazardReportItem(
          id: -localId, // ID negatif sebagai penanda item offline
          tanggal: row['date']?.toString() ?? payload['tanggal']?.toString() ?? '',
          waktu: row['time']?.toString() ?? payload['waktu']?.toString() ?? '',
          nama: profile?.namaLengkap ?? 'Saya',
          nik: profile?.noNik ?? '',
          departemen: profile?.depart ?? 'GENERAL',
          area: row['area']?.toString() ?? payload['area']?.toString() ?? 'PIT AREA',
          lokasi: row['lokasi']?.toString() ?? payload['lokasi']?.toString() ?? row['location_detail']?.toString() ?? '',
          detilLokasi: row['location_detail']?.toString() ?? payload['detil_lokasi']?.toString() ?? '',
          temuan: row['remark']?.toString() ?? payload['temuan']?.toString() ?? row['title']?.toString() ?? 'Temuan Hazard',
          kategoriBahaya: row['kategori_bahaya']?.toString() ?? payload['kategori_bahaya']?.toString() ?? 'Kondisi Tidak Aman',
          jenisBahaya: row['jenis_bahaya']?.toString() ?? payload['jenis_bahaya']?.toString() ?? 'Umum',
          jenisKetidaksesuaian: row['jenis_ketidaksesuaian']?.toString() ?? payload['jenis_ketidaksesuaian']?.toString() ?? '',
          tingkatResiko: row['tingkat_resiko']?.toString() ?? payload['tingkat_resiko']?.toString() ?? 'Sedang',
          perbaikan: row['repair_remark']?.toString() ?? payload['perbaikan']?.toString(),
          tindakanPerbaikan: row['tindakan_perbaikan']?.toString() ?? payload['tindakan_perbaikan']?.toString(),
          pja: row['pja']?.toString() ?? payload['pja']?.toString() ?? 'PJA Lapangan',
          nikPja: row['nik_pja']?.toString() ?? payload['nik_pja']?.toString() ?? '',
          departemenPja: row['departemen_pja']?.toString() ?? payload['departemen_pja']?.toString() ?? '',
          statusTemuan: isClosed ? 'Closed' : 'Open',
          fotoTemuan: row['image']?.toString(),
          fotoPerbaikan: row['repair_image']?.toString(),
          isMyReport: true,
          canDelete: true,
          isOfflinePending: true,
        );
      }).toList();
      _allOfflineItems = offlineItems;
      _offlineOpenCount = offlineItems.where((i) => i.statusTemuan.toLowerCase() != 'closed').length;
      _offlineClosedCount = offlineItems.where((i) => i.statusTemuan.toLowerCase() == 'closed').length;
    } catch (_) {
      _offlineCount = 0;
      _offlineOpenCount = 0;
      _offlineClosedCount = 0;
      _allOfflineItems = [];
    }

    String filterParam;
    switch (_currentTab) {
      case HazardHubTab.summary:
        filterParam = 'summary';
        break;
      case HazardHubTab.action:
        filterParam = 'action';
        break;
      case HazardHubTab.monitoring:
        filterParam = 'monitoring';
        break;
    }

    final res = await _api.getHazardHub(
      filter: filterParam,
      search: _searchCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    res.fold(
      (err) {
        // Jika offline atau gagal server, tetap tampilkan data offline lokal yang ada
        final msg = err['message']?.toString() ?? 'Gagal terhubung server pusat (Mode Offline).';
        SnackBarMsg.info(context, msg);
        if (offlineItems.isNotEmpty) {
          final tabOffline = offlineItems.where((i) {
            final isClosed = i.statusTemuan.toLowerCase() == 'closed';
            if (_currentTab == HazardHubTab.action) {
              return i.isAssignedToMe && !isClosed;
            }
            if (_currentTab == HazardHubTab.monitoring) {
              return !isClosed;
            }
            if (_currentTab == HazardHubTab.summary) {
              return isClosed;
            }
            return false;
          }).toList();
          setState(() => _items = tabOffline);
        }
      },
      (data) {
        if (data['summary'] is Map) {
          _summary = HazardSummary.fromJson(
              Map<String, dynamic>.from(data['summary'] as Map));
        }
        if (data['data'] is List) {
          final list = (data['data'] as List)
              .map((e) =>
                  HazardReportItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

          // Gabungkan item offline yang relevan ke atas list secara tegas
          final tabOffline = offlineItems.where((i) {
            final isClosed = i.statusTemuan.toLowerCase() == 'closed';
            if (_currentTab == HazardHubTab.action) {
              return i.isAssignedToMe && !isClosed;
            }
            if (_currentTab == HazardHubTab.monitoring) {
              return !isClosed;
            }
            if (_currentTab == HazardHubTab.summary) {
              return isClosed;
            }
            return false;
          }).toList();

          setState(() => _items = [...tabOffline, ...list]);
        }
      },
    );
  }

  Future<void> _syncAllOffline() async {
    setState(() => _isSyncingOffline = true);
    try {
      final res = await OfflineSyncService.instance.autoSyncPending();
      if (!mounted) return;
      if (res.success > 0) {
        SnackBarMsg.success(context, '${res.success} Laporan Hazard lokal berhasil disinkronkan ke server!');
      } else if (res.failed > 0) {
        SnackBarMsg.danger(context, 'Sebagian data belum berhasil disinkronkan. Periksa koneksi ke server.');
      } else {
        SnackBarMsg.info(context, 'Tidak ada data offline yang perlu disinkronkan.');
      }
    } catch (e) {
      if (mounted) SnackBarMsg.danger(context, 'Gagal sinkronisasi: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingOffline = false);
        _loadData();
      }
    }
  }

  Future<void> _syncSingleOfflineItem(HazardReportItem item) async {
    final localId = -item.id;
    setState(() => _isLoading = true);
    try {
      final ok = await syncTran(_db, _api, 'hazard', localId);
      if (!mounted) return;
      if (ok) {
        SnackBarMsg.success(context, 'Temuan #$localId berhasil disinkronkan ke server!');
        await OfflineSyncService.instance.refresh();
      } else {
        SnackBarMsg.danger(context, 'Gagal menyinkronkan temuan. Pastikan server/jaringan aktif.');
      }
    } catch (e) {
      if (mounted) SnackBarMsg.danger(context, 'Gagal sinkron: $e');
    } finally {
      if (mounted) _loadData();
    }
  }

  void _openCreateHazard([HazardReportItem? editItem]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HazardCreatePage(editItem: editItem)),
    );
    if (result == true && mounted) {
      setState(() {
        _currentTab = HazardHubTab.monitoring;
        _activeFilter = 'all';
      });
      _loadData();
    }
  }

  void _showImagePreview(String imageUrl, String title) {
    Widget buildErrorPlaceholder() => Container(
          height: 200,
          color: Colors.white,
          alignment: Alignment.center,
          child: const Text('Foto tidak dapat dimuat', style: TextStyle(color: Color(0xFF64748B))),
        );

    final isHttp = imageUrl.startsWith('http');
    final isLocalFile = !isHttp && File(imageUrl).existsSync();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(
                child: isHttp
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => buildErrorPlaceholder(),
                      )
                    : (isLocalFile
                        ? Image.file(
                            File(imageUrl),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => buildErrorPlaceholder(),
                          )
                        : Image.network(
                            '${ApiService().baseUrl}$imageUrl',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => buildErrorPlaceholder(),
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseModal(HazardReportItem item) {
    final tindakanCtrl = TextEditingController();
    File? fotoPerbaikan;
    final picker = ImagePicker();
    bool isSaving = false;
    String closeMode = item.isAssignedToMe ? 'self' : 'pja';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isPjaMode = closeMode == 'pja';
          final showModeSelector = item.isMyReport && !item.isAssignedToMe;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.isAssignedToMe ? 'Tuntaskan Tugas PJA' : 'Close Temuan Hazard',
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              item.isAssignedToMe
                                  ? 'Selesaikan temuan dan unggah bukti perbaikan.'
                                  : 'Pilih cara penutupan: kirim ke PJA atau selesaikan sendiri.',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (showModeSelector) ...[
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => closeMode = 'pja'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isPjaMode ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isPjaMode ? const Color(0xFFF97316) : const Color(0xFFE2E8F0),
                                  width: isPjaMode ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isPjaMode ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: isPjaMode ? const Color(0xFFF97316) : const Color(0xFF94A3B8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kirim ke PJA',
                                    style: TextStyle(
                                      color: isPjaMode ? const Color(0xFFC2410C) : const Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => closeMode = 'self'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isPjaMode ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isPjaMode ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                  width: !isPjaMode ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    !isPjaMode ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: !isPjaMode ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Selesaikan Sendiri',
                                    style: TextStyle(
                                      color: !isPjaMode ? const Color(0xFF047857) : const Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isPjaMode ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isPjaMode ? const Color(0xFFFFEDD5) : const Color(0xFFA7F3D0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPjaMode ? Icons.forward_to_inbox_rounded : Icons.task_alt_rounded,
                            color: isPjaMode ? const Color(0xFFEA580C) : const Color(0xFF059669),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPjaMode
                                  ? 'Temuan di-close di pelaporan Anda dan otomatis diteruskan ke PJA (${item.pja ?? "Penanggung Jawab"}) sebagai Action Plan.'
                                  : 'Temuan diselesaikan langsung oleh Anda sebagai pelapor dan langsung berstatus Closed permanen.',
                              style: TextStyle(
                                color: isPjaMode ? const Color(0xFF9A3412) : const Color(0xFF065F46),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  Text(
                    'Temuan: ${item.temuan}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isPjaMode ? 'Catatan Penutupan / Tindak Lanjut untuk PJA *' : 'Tindakan Koreksi / Perbaikan yang Dilakukan *',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: tindakanCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: isPjaMode
                            ? 'Tulis catatan penutupan / instruksi rencana tindak lanjut...'
                            : 'Jelaskan tindakan perbaikan yang telah dituntaskan...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!isPjaMode) ...[
                    const Text('Foto Bukti Perbaikan (After)',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (fotoPerbaikan != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              fotoPerbaikan!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: InkWell(
                              onTap: () => setModalState(() => fotoPerbaikan = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      InkWell(
                        onTap: () async {
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                          if (picked != null) {
                            setModalState(() => fotoPerbaikan = File(picked.path));
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 68,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Color(0xFF059669), size: 20),
                              SizedBox(width: 8),
                              Text('Ambil Foto Bukti Perbaikan', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                  ] else ...[
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPjaMode ? const Color(0xFFEA580C) : const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final text = tindakanCtrl.text.trim();
                              if (text.isEmpty) {
                                SnackBarMsg.danger(
                                  context,
                                  isPjaMode
                                      ? 'Catatan penutupan / instruksi untuk PJA wajib diisi.'
                                      : 'Uraian tindakan perbaikan wajib diisi.',
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);
                              final res = await _api.closeHazardDirect(
                                item.id,
                                text,
                                closeMode: closeMode,
                                fotoPerbaikan: fotoPerbaikan,
                              );

                              if (!mounted) return;
                              setModalState(() => isSaving = false);

                              res.fold(
                                (err) => SnackBarMsg.danger(context, err['message']?.toString() ?? 'Gagal menutup hazard.'),
                                (_) {
                                  Navigator.pop(ctx);
                                  SnackBarMsg.success(
                                    context,
                                    isPjaMode
                                        ? 'Hazard berhasil di-close dan diteruskan ke PJA!'
                                        : 'Temuan Hazard berhasil ditutup (Closed)!',
                                  );
                                  _loadData();
                                },
                              );
                            },
                      icon: isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(isPjaMode ? Icons.send_rounded : Icons.check_circle_rounded, size: 20),
                      label: Text(
                        isSaving
                            ? 'MEMPROSES...'
                            : isPjaMode
                                ? 'KIRIM KE PJA (ACTION PLAN)'
                                : 'TUTUP TEMUAN (CLOSE)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTakeUpModal(HazardReportItem item) {
    final noteCtrl = TextEditingController(text: 'Sedang ditindaklanjuti & disiapkan perbaikan.');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.touch_app_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Take Up Temuan Hazard',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Ambil alih tanggung jawab penanganan temuan bahaya ini.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.area ?? "-"} • ${item.lokasi ?? "-"}',
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.temuan,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Catatan Awal Penanganan / Rencana Tindakan (Opsional)',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Sudah dikoordinasikan dengan tim lapangan...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              final res = await _api.takeUpHazard(item.id, note: noteCtrl.text.trim());
                              if (!mounted) return;
                              setModalState(() => isSaving = false);
                              res.fold(
                                (err) => SnackBarMsg.danger(context, err['message']?.toString() ?? 'Gagal take up temuan.'),
                                (_) {
                                  Navigator.pop(ctx);
                                  SnackBarMsg.success(context, 'Temuan Hazard berhasil di-Take Up (In Progress)!');
                                  _loadData();
                                },
                              );
                            },
                      icon: isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(isSaving ? 'MEMPROSES...' : 'TAKE UP TEMUAN SEKARANG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<List<PjaSearchResult>> _searchPjaLocal(String query) async {
    try {
      final safeQ = query.replaceAll("'", "''").trim();
      final sqldb = await _db.database;
      final rows = await sqldb.rawQuery(
        "SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan FROM employees WHERE no_nik LIKE '%$safeQ%' OR nama_lengkap LIKE '%$safeQ%' LIMIT 30",
      );
      return rows.map((r) => PjaSearchResult(
        nik: r['no_nik']?.toString() ?? '',
        nama: r['nama_lengkap']?.toString() ?? '',
        departemen: (r['departemen'] ?? r['depart'])?.toString() ?? 'GENERAL',
        jabatan: (r['jabatan'] ?? r['posisi'])?.toString() ?? 'Karyawan',
        perusahaan: r['perusahaan']?.toString() ?? 'PT INDEXIM COALINDO',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  void _showReassignModal(HazardReportItem item) {
    final reasonCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    PjaSearchResult? selectedNewPja;
    List<PjaSearchResult> searchResults = [];
    bool isSearching = false;
    bool isSaving = false;
    bool modalLintasPerusahaan = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFFD97706), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alihkan PJA (Salah Sasaran)',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Arahkan tanggung jawab ke personil PJA yang berwenang.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PJA Saat Ini: ${item.pja ?? "Belum Ditunjuk"} (${item.nikPja ?? "-"})',
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pilih PJA Baru yang Dituju *',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            modalLintasPerusahaan = !modalLintasPerusahaan;
                          });
                          final q = searchCtrl.text.trim();
                          if (q.isNotEmpty) {
                            setModalState(() => isSearching = true);
                            _api.searchPja(q, lintasPerusahaan: modalLintasPerusahaan).then((res) {
                              if (!mounted) return;
                              res.fold(
                                (_) => setModalState(() => isSearching = false),
                                (data) {
                                  setModalState(() {
                                    isSearching = false;
                                    searchResults = data.map((e) => PjaSearchResult.fromJson(e)).toList();
                                  });
                                },
                              );
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: modalLintasPerusahaan ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: modalLintasPerusahaan ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                modalLintasPerusahaan ? Icons.corporate_fare_rounded : Icons.domain_rounded,
                                size: 12,
                                color: modalLintasPerusahaan ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                modalLintasPerusahaan ? 'Lintas Perusahaan' : 'Internal Saja',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: modalLintasPerusahaan ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (selectedNewPja == null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                        onChanged: (q) async {
                          final cleanQ = q.trim();
                          if (cleanQ.isEmpty) {
                            setModalState(() => searchResults.clear());
                            return;
                          }
                          // Tampilkan hasil database lokal SQLite seketika
                          final local = await _searchPjaLocal(cleanQ);
                          if (mounted && searchCtrl.text.trim() == cleanQ) {
                            setModalState(() => searchResults = local);
                          }
                          setModalState(() => isSearching = true);
                          try {
                            final res = await _api.searchPja(cleanQ, lintasPerusahaan: modalLintasPerusahaan);
                            if (!mounted) return;
                            res.fold(
                              (_) => setModalState(() => isSearching = false),
                              (data) {
                                if (mounted && searchCtrl.text.trim() == cleanQ) {
                                  setModalState(() {
                                    isSearching = false;
                                    if (data.isNotEmpty) {
                                      searchResults = data.map((e) => PjaSearchResult.fromJson(e)).toList();
                                    }
                                  });
                                }
                              },
                            );
                          } catch (_) {
                            if (mounted) setModalState(() => isSearching = false);
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                          hintText: modalLintasPerusahaan
                              ? 'Cari NIK, Nama, Dept, atau Perusahaan PJA...'
                              : 'Cari NIK/Nama PJA internal...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)))),
                      ),
                    if (searchCtrl.text.trim().isNotEmpty || searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            if (searchCtrl.text.trim().isNotEmpty) ...[
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedNewPja = PjaSearchResult(
                                      nik: 'MANUAL',
                                      nama: searchCtrl.text.trim().toUpperCase(),
                                      departemen: 'LAPANGAN',
                                      jabatan: 'PJA Offline',
                                      perusahaan: 'INTERNAL',
                                    );
                                    searchResults.clear();
                                    searchCtrl.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  color: const Color(0xFFEFF6FF),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Gunakan: "${searchCtrl.text.trim().toUpperCase()}" (Manual)',
                                          style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 16),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            ],
                            if (searchResults.isNotEmpty)
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: searchResults.length,
                                separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                                itemBuilder: (ctx, i) {
                                  final p = searchResults[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(p.nama, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${p.nik} • ${p.departemen} • ${p.jabatan}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            p.perusahaan,
                                            style: const TextStyle(color: Color(0xFF0284C7), fontSize: 9.5, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 12),
                                    onTap: () {
                                      setModalState(() {
                                        selectedNewPja = p;
                                        searchResults.clear();
                                      });
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF16A34A),
                            child: Text(
                              selectedNewPja!.nama.isNotEmpty ? selectedNewPja!.nama[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedNewPja!.nama,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${selectedNewPja!.nik} • ${selectedNewPja!.departemen}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 18),
                            onPressed: () => setModalState(() => selectedNewPja = null),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Alasan / Keterangan Pengalihan *',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Bukan area wewenang saya, mohon tindak lanjut tim terkait...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (selectedNewPja == null) {
                                if (searchCtrl.text.trim().isNotEmpty) {
                                  selectedNewPja = PjaSearchResult(
                                    nik: 'MANUAL',
                                    nama: searchCtrl.text.trim().toUpperCase(),
                                    departemen: 'LAPANGAN',
                                    jabatan: 'PJA Offline',
                                    perusahaan: 'INTERNAL',
                                  );
                                } else {
                                  SnackBarMsg.danger(context, 'PJA baru wajib dipilih atau diketik dari pencarian.');
                                  return;
                                }
                              }
                              final reason = reasonCtrl.text.trim();
                              if (reason.isEmpty) {
                                SnackBarMsg.danger(context, 'Alasan pengalihan wajib diisi.');
                                return;
                              }
                              setModalState(() => isSaving = true);
                              final res = await _api.reassignHazardPja(
                                item.id,
                                selectedNewPja!.nik,
                                selectedNewPja!.nama,
                                selectedNewPja!.departemen,
                                reason,
                              );
                              if (!mounted) return;
                              setModalState(() => isSaving = false);
                              res.fold(
                                (err) => SnackBarMsg.danger(context, err['message']?.toString() ?? 'Gagal mengalihkan PJA.'),
                                (_) {
                                  Navigator.pop(ctx);
                                  SnackBarMsg.success(context, 'PJA berhasil dialihkan kepada ${selectedNewPja!.nama}!');
                                  _loadData();
                                },
                              );
                            },
                      icon: isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.swap_horiz_rounded, size: 20),
                      label: Text(isSaving ? 'MENGALIHKAN...' : 'SIMPAN PENGALIHAN PJA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(HazardReportItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Temuan Hazard?', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Laporan #${item.id} (${item.lokasi}) akan dihapus secara permanen dari server.',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.deleteHazardDirect(item.id);
              if (!mounted) return;
              res.fold(
                (err) => SnackBarMsg.danger(context, err['message']?.toString() ?? 'Gagal menghapus laporan.'),
                (_) {
                  SnackBarMsg.success(context, 'Laporan Hazard berhasil dihapus.');
                  _loadData();
                },
              );
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String pageTitle;
    switch (_currentTab) {
      case HazardHubTab.summary:
        pageTitle = 'Summary Hazard';
        break;
      case HazardHubTab.action:
        pageTitle = 'Action Hazard (Tugas PJA)';
        break;
      case HazardHubTab.monitoring:
        pageTitle = 'Monitoring Hazard';
        break;
    }

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: TopBar(title: pageTitle),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Lapor Hazard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: () => _openCreateHazard(),
      ),
      body: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFFEA580C),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Clean Summary Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern 3-Tab Segmented Selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildTabItem(HazardHubTab.summary, 'Summary', _summary.totalSummary + _offlineClosedCount, const Color(0xFFEA580C), offlinePending: _offlineClosedCount),
                            _buildTabItem(HazardHubTab.action, 'Action', _summary.totalAction, const Color(0xFFF59E0B)),
                            _buildTabItem(HazardHubTab.monitoring, 'Monitoring', _summary.totalMonitoring + _offlineOpenCount, const Color(0xFF16A34A), offlinePending: _offlineOpenCount),
                          ],
                        ),
                      ),

                      if (_offlineCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD97706).withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_offlineCount Temuan Tersimpan di HP (Mode Offline)',
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tersimpan saat tidak ada sinyal. Tekan tombol ini atau otomatis terkirim saat tersambung internet.',
                                      style: TextStyle(color: Color(0xFFB45309), fontSize: 10.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isSyncingOffline ? null : _syncAllOffline,
                                icon: _isSyncingOffline
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.sync_rounded, size: 14),
                                label: Text(
                                  _isSyncingOffline ? 'Singkron...' : 'Singkronkan',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Contextual Header Card
                      _buildContextHeaderCard(),

                      const SizedBox(height: 12),

                      // Clean Search Box
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                          onSubmitted: (_) => _loadData(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                                    onPressed: () {
                                       _searchCtrl.clear();
                                      _loadData();
                                    },
                                  )
                                : null,
                            hintText: 'Cari lokasi, area, temuan, atau pelapor...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _buildFilterChipsForCurrentTab(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Hazard List
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFFEA580C))),
                )
              else if (_filteredItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded, size: 50, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 10),
                        Text(
                          _currentTab == HazardHubTab.action
                              ? 'Tidak ada tugas PJA aktif saat ini.'
                              : _currentTab == HazardHubTab.summary
                                  ? 'Belum ada temuan hazard yang Anda laporkan.'
                                  : 'Tidak ada temuan hazard ditemukan.',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tekan tombol Lapor Hazard di bawah untuk membuat laporan baru.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 84),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final item = _filteredItems[idx];
                        return _buildSimpleHazardCard(item);
                      },
                      childCount: _filteredItems.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(HazardHubTab tab, String label, int count, Color activeColor, {int offlinePending = 0}) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_currentTab != tab) {
            setState(() {
              _currentTab = tab;
              _activeFilter = 'all';
            });
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFCBD5E1).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count Data',
                      style: TextStyle(
                        color: isSelected ? activeColor : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (offlinePending > 0) ...[
                    const SizedBox(width: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 9),
                          const SizedBox(width: 1),
                          Text(
                            '+$offlinePending',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w900,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildContextHeaderCard() {
    IconData icon;
    Color iconColor;
    Color iconBg;
    String title;
    String subtitle;
    List<Widget> badges = [];

    switch (_currentTab) {
      case HazardHubTab.action:
        icon = Icons.assignment_turned_in_rounded;
        iconColor = const Color(0xFFF59E0B);
        iconBg = const Color(0xFFFFFBEB);
        title = 'Action (Tugas PJA Saya)';
        subtitle = 'Temuan yang diarahkan ke Anda dan perlu tindakan segera';
        final openActionCount = _items.where((i) => i.statusTemuan.toLowerCase() == 'open').length;
        final inProgressActionCount = _items.where((i) => i.statusTemuan.toLowerCase() == 'in progress').length;
        badges = [
          _buildMetricBadge(
            'Perlu Take Up (Open)',
            openActionCount,
            const Color(0xFFD97706),
            const Color(0xFFFFFBEB),
            const Color(0xFFFDE68A),
            Icons.assignment_ind_rounded,
            isSelected: _activeFilter == 'open',
            onTap: () {
              setState(() => _activeFilter = _activeFilter == 'open' ? 'all' : 'open');
            },
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            'Sedang Ditangani',
            inProgressActionCount,
            const Color(0xFF0284C7),
            const Color(0xFFF0F9FF),
            const Color(0xFFBAE6FD),
            Icons.engineering_rounded,
            isSelected: _activeFilter == 'inprogress',
            onTap: () {
              setState(() => _activeFilter = _activeFilter == 'inprogress' ? 'all' : 'inprogress');
            },
          ),
        ];
        break;
      case HazardHubTab.monitoring:
        icon = Icons.monitor_heart_rounded;
        iconColor = const Color(0xFF0284C7);
        iconBg = const Color(0xFFF0F9FF);
        title = 'Monitoring (Sedang Berproses)';
        subtitle = 'Pantau temuan yang Anda laporkan yang sedang ditangani PJA';
        final openCount = _items.where((i) => i.statusTemuan.toLowerCase() == 'open').length;
        final inProgressCount = _items.where((i) => i.statusTemuan.toLowerCase() == 'in progress').length;
        badges = [
          _buildMetricBadge(
            'Menunggu PJA (Open)',
            openCount,
            const Color(0xFF0284C7),
            const Color(0xFFF0F9FF),
            const Color(0xFFBAE6FD),
            Icons.hourglass_top_rounded,
            isSelected: _activeFilter == 'open',
            onTap: () {
              setState(() => _activeFilter = _activeFilter == 'open' ? 'all' : 'open');
            },
          ),
          const SizedBox(width: 8),
          _buildMetricBadge(
            'Diproses PJA',
            inProgressCount,
            const Color(0xFF059669),
            const Color(0xFFECFDF5),
            const Color(0xFFA7F3D0),
            Icons.run_circle_rounded,
            isSelected: _activeFilter == 'inprogress',
            onTap: () {
              setState(() => _activeFilter = _activeFilter == 'inprogress' ? 'all' : 'inprogress');
            },
          ),
        ];
        break;
      case HazardHubTab.summary:
        icon = Icons.task_alt_rounded;
        iconColor = const Color(0xFF16A34A);
        iconBg = const Color(0xFFECFDF5);
        title = 'Summary (Laporan Selesai)';
        subtitle = 'Arsip laporan bahaya yang sudah tuntas & bukti perbaikan';
        badges = [
          _buildMetricBadge('Selesai (Closed)', _summary.totalSummary, const Color(0xFF059669), const Color(0xFFECFDF5), const Color(0xFFA7F3D0), Icons.check_circle_rounded),
          const SizedBox(width: 8),
          _buildMetricBadge('Total Buatan Saya', _summary.totalInput, const Color(0xFFEA580C), const Color(0xFFFFF7ED), const Color(0xFFFFEDD5), Icons.summarize_rounded),
        ];
        break;
    }

    if (_offlineCount > 0) {
      badges.add(const SizedBox(width: 8));
      badges.add(
        _buildMetricBadge(
          'Belum Sinkron',
          _offlineCount,
          const Color(0xFFD97706),
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          Icons.cloud_off_rounded,
          isSelected: _activeFilter == 'offline_pending',
          onTap: () {
            setState(() => _activeFilter = _activeFilter == 'offline_pending' ? 'all' : 'offline_pending');
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: badges),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChipsForCurrentTab() {
    switch (_currentTab) {
      case HazardHubTab.action:
        return [
          _buildFilterChip('all', 'Semua Tugas PJA (${_summary.totalAction})'),
          const SizedBox(width: 6),
          _buildFilterChip('open', 'Open (Perlu Take Up)'),
          const SizedBox(width: 6),
          _buildFilterChip('inprogress', 'In Progress (Sedang Ditangani)'),
        ];
      case HazardHubTab.monitoring:
        return [
          _buildFilterChip('all', 'Semua Sedang Berproses (${_summary.totalMonitoring})'),
          const SizedBox(width: 6),
          _buildFilterChip('open', 'Menunggu PJA (Open)'),
          const SizedBox(width: 6),
          _buildFilterChip('inprogress', 'Diproses (In Progress)'),
        ];
      case HazardHubTab.summary:
        return [
          _buildFilterChip('all', 'Semua Selesai (${_summary.totalSummary})'),
          const SizedBox(width: 6),
          _buildFilterChip('my_reports', 'Laporan Saya Selesai'),
          const SizedBox(width: 6),
          _buildFilterChip('pja_reports', 'Tugas PJA Selesai'),
        ];
    }
  }

  Widget _buildMetricBadge(
    String label,
    int count,
    Color color,
    Color bg,
    Color border,
    IconData icon, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _activeFilter == key;
    return InkWell(
      onTap: () {
        setState(() => _activeFilter = key);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showOfflineItemDetailModal(HazardReportItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan Belum Tersinkron',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Data tersimpan di perangkat lokal HP (Draft)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.tingkatResiko.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            item.statusTemuan.toUpperCase(),
                            style: const TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${item.tanggal} ${item.waktu}',
                          style: const TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.area ?? "-"} • ${item.lokasi ?? "-"}',
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.temuan,
                      style: const TextStyle(color: Color(0xFF334155), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PJA: ${item.pja ?? "Belum Ditunjuk"}',
                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB45309)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Laporan ini belum masuk server pusat IndexSafe. Klik tombol di bawah untuk menyinkronkan data sekarang saat terhubung ke server/WiFi.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(item);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus Draft', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _syncSingleOfflineItem(item);
                      },
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Sinkronkan Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleHazardCard(HazardReportItem item) {
    final isClosed = item.statusTemuan.toLowerCase() == 'closed';
    final hasBeforePhoto = item.fotoTemuan != null && item.fotoTemuan!.isNotEmpty;
    final hasAfterPhoto = item.fotoPerbaikan != null && item.fotoPerbaikan!.isNotEmpty;

    // Risk level styling
    final isExtreme = item.tingkatResiko.toLowerCase().contains('ekstrim');
    final isHigh = item.tingkatResiko.toLowerCase().contains('tinggi');
    final isMedium = item.tingkatResiko.toLowerCase().contains('sedang');

    final riskColor = isExtreme
        ? const Color(0xFFDC2626)
        : isHigh
            ? const Color(0xFFEA580C)
            : isMedium
                ? const Color(0xFFD97706)
                : const Color(0xFF059669);

    final riskBg = isExtreme
        ? const Color(0xFFFEF2F2)
        : isHigh
            ? const Color(0xFFFFF7ED)
            : isMedium
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFECFDF5);

    final riskBorderColor = isExtreme
        ? const Color(0xFFFECACA)
        : isHigh
            ? const Color(0xFFFED7AA)
            : isMedium
                ? const Color(0xFFFDE68A)
                : const Color(0xFFA7F3D0);

    final riskIcon = isExtreme
        ? Icons.local_fire_department_rounded
        : isHigh
            ? Icons.warning_rounded
            : isMedium
                ? Icons.report_problem_rounded
                : Icons.shield_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isOfflinePending
              ? const Color(0xFFF59E0B)
              : (item.isAssignedToMe && !isClosed ? const Color(0xFF0284C7) : riskBorderColor),
          width: item.isOfflinePending ? 2.0 : ((item.isAssignedToMe && !isClosed) ? 1.5 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: item.isOfflinePending
                ? const Color(0xFFD97706).withValues(alpha: 0.12)
                : const Color(0xFF64748B).withValues(alpha: 0.04),
            blurRadius: item.isOfflinePending ? 8 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: item.isOfflinePending ? () => _showOfflineItemDetailModal(item) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Offline Belum Singkron (jika item disimpan lokal dan belum terkirim ke server)
              if (item.isOfflinePending)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFFDE68A), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 14),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BELUM SINKRON (DRAFT OFFLINE)',
                              style: TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Tersimpan di HP & belum masuk server pusat',
                              style: TextStyle(color: Color(0xFFB45309), fontSize: 9.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _syncSingleOfflineItem(item),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD97706).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Sinkronkan', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

          // Banner Penugasan PJA (jika ditugaskan ke user login)
          if (item.isAssignedToMe && !isClosed && !item.isOfflinePending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.assignment_ind_rounded, color: Color(0xFF0284C7), size: 13),
                  SizedBox(width: 6),
                  Text(
                    'TUGAS PJA UNTUK ANDA (HARAP DITINDAKLANJUTI)',
                    style: TextStyle(color: Color(0xFF0369A1), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Header Card Sesuai Tingkat Risiko
          ClipRRect(
            borderRadius: (item.isOfflinePending || (item.isAssignedToMe && !isClosed))
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(13)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: riskBg,
                border: Border(
                  bottom: BorderSide(color: riskBorderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Risk Badge (Icon + Text)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: riskColor.withValues(alpha: 0.28),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(riskIcon, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        item.tingkatResiko.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? const Color(0xFFECFDF5)
                        : (item.statusTemuan.toLowerCase().contains('progress')
                            ? const Color(0xFFEFF6FF)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isClosed
                          ? const Color(0xFFA7F3D0)
                          : (item.statusTemuan.toLowerCase().contains('progress')
                              ? const Color(0xFFBFDBFE)
                              : riskBorderColor),
                    ),
                  ),
                  child: Text(
                    item.statusTemuan.toUpperCase(),
                    style: TextStyle(
                      color: isClosed
                          ? const Color(0xFF059669)
                          : (item.statusTemuan.toLowerCase().contains('progress')
                              ? const Color(0xFF1D4ED8)
                              : riskColor),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Offline Pending Badge
                if (item.isOfflinePending) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 10),
                        SizedBox(width: 3),
                        Text(
                          'BELUM SINKRON',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),

                // Category
                Expanded(
                  child: Text(
                    item.kategoriBahaya ?? 'Hazard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Date
                Text(
                  item.tanggal,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),

                // 3-dot Popup Menu
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 18),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    switch (val) {
                      case 'pdf_share':
                        HazardPdfService.shareHazardPdf(item);
                        break;
                      case 'pdf_print':
                        HazardPdfService.printHazardPdf(item);
                        break;
                      case 'take_up':
                        _showTakeUpModal(item);
                        break;
                      case 'close':
                        _showCloseModal(item);
                        break;
                      case 'reassign':
                        _showReassignModal(item);
                        break;
                      case 'edit':
                        _openCreateHazard(item);
                        break;
                      case 'delete':
                        _confirmDelete(item);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'pdf_share',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, color: Color(0xFF0284C7), size: 16),
                          SizedBox(width: 8),
                          Text('Bagikan PDF', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pdf_print',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 16),
                          SizedBox(width: 8),
                          Text('Cetak PDF', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!isClosed && (item.isAssignedToMe || item.canTakeUp))
                      const PopupMenuItem(
                        value: 'take_up',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Color(0xFF0284C7), size: 16),
                            SizedBox(width: 8),
                            Text('Take Up Temuan', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                          ],
                        ),
                      ),
                    if (!isClosed && (item.canClose || item.isAssignedToMe || item.isMyReport))
                      const PopupMenuItem(
                        value: 'close',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 16),
                            SizedBox(width: 8),
                            Text('Close Hazard', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                          ],
                        ),
                      ),
                    if (!isClosed)
                      const PopupMenuItem(
                        value: 'reassign',
                        child: Row(
                          children: [
                            Icon(Icons.person_pin_circle_rounded, color: Color(0xFFD97706), size: 16),
                            SizedBox(width: 8),
                            Text('Alihkan PJA', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)),
                          ],
                        ),
                      ),
                    if (item.canDelete && !isClosed)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 16),
                            SizedBox(width: 8),
                            Text('Hapus Laporan', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 6),

                // Location Line
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFFEA580C), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${item.area ?? "-"} • ${item.lokasi ?? "-"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Finding Description
                Text(
                  item.temuan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 12, height: 1.35),
                ),

                // Compact Photo Badges (Simple & Clean)
                if (hasBeforePhoto || hasAfterPhoto) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (hasBeforePhoto)
                        _buildPhotoBadge(
                          url: item.fotoTemuan!,
                          title: 'Foto Temuan (Before)',
                          label: 'Foto Temuan',
                          color: const Color(0xFF475569),
                          bg: const Color(0xFFF1F5F9),
                          border: const Color(0xFFCBD5E1),
                        ),
                      if (hasAfterPhoto)
                        _buildPhotoBadge(
                          url: item.fotoPerbaikan!,
                          title: 'Foto Perbaikan (After)',
                          label: 'Bukti Perbaikan',
                          color: const Color(0xFF059669),
                          bg: const Color(0xFFECFDF5),
                          border: const Color(0xFFA7F3D0),
                        ),
                    ],
                  ),
                ],

                // Subtle Perbaikan Callout (Hanya jika ada)
                if (item.perbaikan != null && item.perbaikan!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 13),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.perbaikan!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF065F46), fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 6),

                // Footer Metadata & Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pelapor: ${item.nama}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                          Text('PJA: ${item.pja ?? "Belum Ditunjuk"}', style: const TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.w600)),
                          if (item.isOfflinePending)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_off_rounded, size: 10, color: Color(0xFFD97706)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Status: Belum Sinkron (Draft HP)',
                                    style: TextStyle(color: Color(0xFFD97706), fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.share_rounded, color: Color(0xFF64748B), size: 18),
                          tooltip: 'Bagikan PDF',
                          onPressed: () => HazardPdfService.shareHazardPdf(item),
                        ),
                        if (!isClosed) ...[
                          if (item.isAssignedToMe) ...[
                            if (item.canTakeUp) ...[
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  minimumSize: const Size(54, 28),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showTakeUpModal(item),
                                child: const Text(
                                  'Take Up',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                minimumSize: const Size(48, 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showReassignModal(item),
                              child: const Text('Alihkan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                minimumSize: const Size(54, 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showCloseModal(item),
                              child: const Text(
                                'Tuntaskan',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ] else if (item.isMyReport) ...[
                            const SizedBox(width: 6),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                minimumSize: const Size(48, 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showReassignModal(item),
                              child: const Text('Alihkan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                minimumSize: const Size(54, 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showCloseModal(item),
                              child: const Text(
                                'Close',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildPhotoBadge({
    required String url,
    required String title,
    required String label,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return InkWell(
      onTap: () => _showImagePreview(url, title),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
