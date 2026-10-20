import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../utils/enums.dart';
import '../../utils/helpers.dart';
import '../../widgets/sap_module_ui.dart';
import '../../widgets/top_bar.dart';
import '../inspeksi/inspeksi_form_page.dart';
import 'history_page.dart';

class OptionPage extends StatefulWidget {
  const OptionPage(this.module, {this.statusMgmt = false, super.key});

  final Module module;
  final bool? statusMgmt;

  @override
  State<OptionPage> createState() => _OptionPageState();
}

class _OptionPageState extends State<OptionPage> {
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  int? _summary = 0;
  int? _action = 0;
  int? _monitor = 0;
  int _offlinePendingCount = 0;
  bool _isSyncing = false;
  bool _isSyncingOffline = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocalCounts();
      _syncAndFetch();
    });
  }

  Future<void> _loadLocalCounts() async {
    final profileId = _profile?.id ?? 0;

    String summaryQry;
    switch (widget.module) {
      case Module.inspection:
      case Module.inspectionDaily:
      case Module.inspectionWeekly:
      case Module.simama:
        summaryQry = '''
        select count(1) as jml from inspection_trans tr
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.employee_id is null or tr.employee_id=0)
          and (tr.category='${widget.module.name}' or tr.category is null)
        ''';
        break;
      default:
        summaryQry = '''
        select count(1) as jml from hazard_trans tr
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.employee_id is null or tr.employee_id=0)
        ''';
        break;
    }

    try {
      final summaryVal = await _db.rawQuery(summaryQry);
      if (summaryVal.isNotEmpty && mounted) {
        setState(() => _summary = summaryVal[0]['jml'] as int);
      }
    } catch (e) {
      debugPrint('[OptionPage] Error counting summary: $e');
    }

    // Action: assigned to PJA (status 0) or PIC (status 1) yang belum close (status < 2)
    try {
      final actionVal = await _db.rawQuery('''
        select count(1) as jml from action_plans tr
        where tr.deleted_at is null 
          and ((tr.pja_id=$profileId and tr.status<1) or (tr.pic_id=$profileId and tr.status<2))
          and (tr.category='${widget.module.name}' or tr.table='${widget.module.name}')
          and tr.status < 2
        ''');
      if (actionVal.isNotEmpty && mounted) {
        setState(() => _action = actionVal[0]['jml'] as int);
      }
    } catch (e) {
      debugPrint('[OptionPage] Error counting action: $e');
    }

    // Monitoring: pelapor, PJA, atau PIC memantau action yang belum close (status < 2), plus draft offline
    try {
      int count = 0;
      final monitorVal = await _db.rawQuery('''
        select count(1) as jml from action_plans tr
        where tr.deleted_at is null 
          and ((tr.pja_id=$profileId and tr.status>0) or (tr.pic_id=$profileId and tr.status>1) or tr.employee_id=$profileId)
          and (tr.category='${widget.module.name}' or tr.table='${widget.module.name}')
          and tr.status < 2
        ''');
      if (monitorVal.isNotEmpty) {
        count += (monitorVal[0]['jml'] as int);
      }

      if (widget.module == Module.inspection) {
        final offVal = await _db.rawQuery('''
          select count(1) as jml from inspection_trans tr
          where tr.deleted_at is null and tr.sync_id is null
        ''');
        if (offVal.isNotEmpty) {
          count += (offVal[0]['jml'] as int);
        }
      }

      if (mounted) {
        setState(() => _monitor = count);
      }
    } catch (e) {
      debugPrint('[OptionPage] Error counting monitor: $e');
    }

    // Hitung offline pending
    try {
      final table = (widget.module == Module.inspection ||
              widget.module == Module.inspectionDaily ||
              widget.module == Module.inspectionWeekly ||
              widget.module == Module.simama)
          ? 'inspection_trans'
          : 'hazard_trans';
      final offVal = await _db.rawQuery(
        "select count(1) as jml from $table where deleted_at is null and sync_id is null",
      );
      if (offVal.isNotEmpty && mounted) {
        setState(() => _offlinePendingCount = offVal[0]['jml'] as int);
      }
    } catch (e) {
      debugPrint('[OptionPage] Error counting offline: $e');
    }
  }

  Future<void> _syncOfflineNow() async {
    if (_isSyncingOffline) return;
    setState(() => _isSyncingOffline = true);
    try {
      final result = await OfflineSyncService.instance.syncAll();
      if (mounted) {
        if (result.success > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil menyinkronkan ${result.success} laporan!'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        } else if (result.failed > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyinkronkan data. Pastikan server terhubung.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[OptionPage] Error sync offline: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingOffline = false);
        await _loadLocalCounts();
      }
    }
  }

  Future<void> _syncAndFetch() async {
    if (_isSyncing) return;
    final isOnline = OfflineSyncService.instance.state.value.isOnline;
    if (!isOnline) {
      await _loadLocalCounts();
      return;
    }

    if (mounted) setState(() => _isSyncing = true);

    try {
      // 1. Sinkronkan semua data lokal yang pending
      await OfflineSyncService.instance.syncNow();

      final profileId = _profile?.id ?? 0;
      final userNik = _profile?.noNik ?? '';

      // 2. Unduh Action Plans aktif dari server dan simpan ke SQLite action_plans
      final actionRes = await _api.getAction(widget.module.name);
      await actionRes.fold(
        (err) async {},
        (response) async {
          final list = response['data'];
          if (list is List) {
            for (var raw in list) {
              if (raw is Map) {
                final item = Map<String, dynamic>.from(raw);
                final id = item['id'];
                if (id is int) {
                  final row = <String, dynamic>{
                    'id': id,
                    'code': item['code'] ?? 'AP-$id',
                    'title': item['title'] ?? item['detilTemuan'] ?? item['kategoriTemuan'] ?? 'Action',
                    'location_detail': item['location_detail'] ?? item['detilLokasi'] ?? item['lokasi'] ?? '',
                    'date': item['date'] ?? item['tanggal'] ?? '',
                    'time': item['time'] ?? item['waktu'] ?? '',
                    'remark': item['remark'] ?? item['detilTemuan'] ?? '',
                    'image': item['image'] ?? item['fotoTemuan'],
                    'status': item['status'] is int ? item['status'] : 0,
                    'pja_id': (item['nik_pja'] == userNik || item['nikPja'] == userNik) ? profileId : (item['pja_id'] ?? 0),
                    'pic_id': (item['nik_pic'] == userNik || item['nikPic'] == userNik) ? profileId : (item['pic_id'] ?? 0),
                    'employee_id': (item['nik'] == userNik) ? profileId : (item['employee_id'] ?? 0),
                    'plan': item['plan'] ?? item['rencanaPerbaikan'],
                    'plan_date': item['plan_date'] ?? item['tanggalRencanaPerbaikan'],
                    'action': item['action'] ?? item['perbaikan'],
                    'action_date': item['action_date'] ?? item['tanggalPerbaikan'],
                    'action_image': item['action_image'] ?? item['fotoPerbaikan'],
                    'table': widget.module.name,
                    'category': widget.module.name,
                    'created_at': item['created_at'] ?? DateTime.now().toString(),
                    'updated_at': DateTime.now().toString(),
                  };

                  final existing = await _db.get('action_plans', id);
                  if (existing == null) {
                    await _db.insert('action_plans', row);
                  } else {
                    await _db.update('action_plans', row, id);
                  }
                }
              }
            }
          }
        },
      );

      // 3. Unduh riwayat transaksi (misal: hazard_trans) dari server dan simpan ke SQLite
      if (widget.module == Module.hazard) {
        try {
          final res = await _api.dio.get('/tran/hazard?limit=100');
          if (res.data != null && res.data['data'] is List) {
            for (var raw in (res.data['data'] as List)) {
              if (raw is Map) {
                final item = Map<String, dynamic>.from(raw);
                final id = item['id'];
                if (id is int) {
                  final row = <String, dynamic>{
                    'id': id,
                    'code': item['code'] ?? 'HZ-$id',
                    'title': item['title'] ?? item['remark'] ?? 'Laporan Bahaya',
                    'location_detail': item['location_detail'] ?? item['lokasi'] ?? '',
                    'date': item['date'] ?? '',
                    'time': item['time'] ?? '',
                    'remark': item['remark'] ?? '',
                    'image': item['image'] ?? item['foto_temuan'],
                    'status': item['status'] is int ? item['status'] : 0,
                    'repair': item['repair'] is int ? item['repair'] : 0,
                    'repair_remark': item['repair_remark'] ?? item['perbaikan'],
                    'repair_image': item['repair_image'] ?? item['foto_perbaikan'],
                    'pja_id': (item['nik_pja'] == userNik) ? profileId : (item['pja_id'] ?? 0),
                    'employee_id': (item['nik'] == userNik) ? profileId : (item['employee_id'] ?? profileId),
                    'sync_id': id,
                    'created_at': item['created_at'] ?? DateTime.now().toString(),
                  };

                  final existing = await _db.get('hazard_trans', id);
                  if (existing == null) {
                    await _db.insert('hazard_trans', row);
                  } else {
                    await _db.update('hazard_trans', row, id);
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[OptionPage] Error fetching hazard_trans: $e');
        }
      } else if (widget.module == Module.inspection) {
        try {
          final res = await _api.dio.get('/tran/inspection?limit=100');
          if (res.data != null && res.data['data'] is List) {
            for (var raw in (res.data['data'] as List)) {
              if (raw is Map) {
                final item = Map<String, dynamic>.from(raw);
                final id = item['id'];
                if (id is int) {
                  final row = <String, dynamic>{
                    'id': id,
                    'code': item['code'] ?? 'INSP-$id',
                    'title': item['jenisInspeksi'] ?? item['title'] ?? 'Inspeksi K3',
                    'area': item['area'] ?? '',
                    'lokasi': item['lokasi'] ?? '',
                    'location_detail': item['detilLokasi'] ?? item['lokasi'] ?? '',
                    'date': (item['tanggal'] != null && item['tanggal'].toString().length >= 10)
                        ? item['tanggal'].toString().substring(0, 10)
                        : '',
                    'time': item['waktu']?.toString() ?? '',
                    'remark': item['catatan'] ?? '',
                    'image': item['lampiranJson'] ?? item['image'],
                    'status': 1,
                    'category': 'inspection',
                    'pja': item['pja'] ?? '',
                    'nik_pja': item['nikPja'] ?? '',
                    'departemen_pja': item['departemenPja'] ?? '',
                    'pja_id': (item['nikPja'] == userNik) ? profileId : (item['pjaId'] ?? 0),
                    'employee_id': (item['nik'] == userNik) ? profileId : (item['employeeId'] ?? profileId),
                    'sync_id': id,
                    'created_at': item['createdAt'] ?? DateTime.now().toString(),
                  };

                  final existing = await _db.get('inspection_trans', id);
                  if (existing == null) {
                    await _db.insert('inspection_trans', row);
                  } else {
                    await _db.update('inspection_trans', row, id);
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[OptionPage] Error fetching inspection_trans: $e');
        }
      }

      await _loadLocalCounts();
    } catch (e) {
      debugPrint('[OptionPage] Error in _syncAndFetch: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = moduleAccentColor(widget.module);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: TopBar(title: pageTitle(widget.module)),
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncAndFetch();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SapModuleHeader(module: widget.module),

              // Offline Pending Sync Banner jika ada laporan lokal yang belum tersinkron
              if (_offlinePendingCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
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
                              '$_offlinePendingCount Laporan Tersimpan di HP (Offline)',
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Data belum tersinkronkan ke database server.',
                              style: TextStyle(color: Color(0xFFB45309), fontSize: 11),
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
                        onPressed: _isSyncingOffline ? null : _syncOfflineNow,
                        icon: _isSyncingOffline
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.sync_rounded, size: 16),
                        label: Text(
                          _isSyncingOffline ? 'Sinkron...' : 'Singkronkan',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MiniCounter(
                      label: 'Summary',
                      value: _summary ?? 0,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniCounter(
                      label: 'Action',
                      value: _action ?? 0,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniCounter(
                      label: 'Monitor',
                      value: _monitor ?? 0,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Alur Kerja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  if (_isSyncing)
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Menyinkronkan...',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _OptionActionCard(
                title: 'Summary',
                subtitle: 'Lihat laporan yang sudah dibuat dan status sinkron.',
                count: _summary ?? 0,
                icon: Icons.summarize_rounded,
                color: accent,
                onTap: () => _openHistory(History.summary),
              ),
              _OptionActionCard(
                title: 'Action',
                subtitle:
                    'Tindak lanjuti action yang menjadi tanggung jawab Anda.',
                count: _action ?? 0,
                icon: Icons.assignment_turned_in_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => _openHistory(History.action),
              ),
              _OptionActionCard(
                title: 'Monitoring',
                subtitle: 'Pantau semua progres action sampai close.',
                count: _monitor ?? 0,
                icon: Icons.monitor_heart_rounded,
                color: const Color(0xFF16A34A),
                onTap: () => _openHistory(History.monitoring),
              ),

            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: () async {
          if (widget.module == Module.inspection) {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InspeksiFormPage(Module.inspection),
              ),
            );
            if (res == true) {
              await _loadLocalCounts();
              await _syncAndFetch();
            }
          } else {
            openPage(context, widget.module);
            await _loadLocalCounts();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Baru'),
      ),
    );
  }

  void _openHistory(History history) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryPage(widget.module, history),
      ),
    );
    await _loadLocalCounts();
  }
}

class _MiniCounter extends StatelessWidget {
  const _MiniCounter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionActionCard extends StatelessWidget {
  const _OptionActionCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SapSoftCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
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
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SapStatusPill(label: '$count Data', color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, color: Colors.blueGrey.shade300),
        ],
      ),
    );
  }
}
