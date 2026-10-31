import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../models/profile_model.dart';
import 'package:sqflite/sqflite.dart';
import '../services/api.dart';
import '../services/database.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';
import '../widgets/snackbar_msg.dart';
import 'home_page.dart';

class SyncPage extends StatefulWidget {
  const SyncPage(this.profile, {super.key});

  final ProfileModel? profile;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final _progress = ValueNotifier(0);
  final _db = DatabaseService();
  final _api = ApiService();
  final _dataSync = PreferenceService.getDataSync();
  final _masters = [
    'enum',
    'bridges',
    'inspection',
    'hazard',
    'coaching',
    'k3',
    'observation',
    'p2h',
    'p5m',
    'safety',
    'employee',
    'vehicle',
    'areas',
    'benchmarks',
    'simper',
    'permit',
  ];

  final _friendlyNames = {
    'enum': 'Status & Referensi',
    'bridges': 'Data Jembatan',
    'inspection': 'Format Inspeksi',
    'hazard': 'Kategori Bahaya & Resiko',
    'coaching': 'Modul Coaching',
    'k3': 'Standar Keselamatan K3',
    'observation': 'Pedoman Observasi',
    'p2h': 'Pemeriksaan Harian Unit (P2H)',
    'p5m': 'Topik Keselamatan P5M',
    'safety': 'Aturan & Regulasi K3',
    'employee': 'Data Karyawan & Pengawas',
    'vehicle': 'Daftar Kendaraan & Unit',
    'areas': 'Area Utama Tambang',
    'benchmarks': 'Detail Lokasi & Benchmark',
    'simper': 'Data SIMPER',
    'permit': 'Data Mine Permit',
  };

  String _table = '...';
  int _currentStep = 1;
  bool _offlineScanDataMissing = false;

  Future<void> _cacheOfflinePhotos() async {
    final db = await _db.database;
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(path.join(root.path, 'offline_employee_photos'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final client = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15)));

    Future<void> cacheTable(
        String table, String idColumn, String photoColumn) async {
      final rows = await db.query(table, columns: [idColumn, photoColumn]);
      for (final row in rows) {
        final raw = row[photoColumn]?.toString() ?? '';
        if (raw.isEmpty) continue;
        if (raw.startsWith('/') && File(raw).existsSync()) {
          // Cache lama dari versi sebelumnya ikut diperkecil saat sync ulang.
          try {
            final local = File(raw);
            final source = img.decodeImage(await local.readAsBytes());
            if (source != null && (source.width > 256 || source.height > 256)) {
              await local.writeAsBytes(
                img.encodeJpg(img.copyResize(source, width: 256), quality: 72),
                flush: true,
              );
            }
          } catch (_) {}
          continue;
        }
        final url = raw.startsWith('http')
            ? raw
            : '${_api.baseUrl}${raw.startsWith('/') ? '' : '/'}$raw';
        final id = row[idColumn]?.toString() ?? '';
        if (id.isEmpty) continue;
        try {
          final file = File(path.join(folder.path, '${table}_$id.jpg'));
          final res = await client.get<List<int>>(url,
              options: Options(responseType: ResponseType.bytes));
          if (res.data != null && res.data!.isNotEmpty) {
            // Avatar scan hanya tampil kecil. Simpan thumbnail 256px, bukan
            // foto kamera asli, supaya sinkron awal tetap ringan.
            final source = img.decodeImage(Uint8List.fromList(res.data!));
            final bytes = source == null
                ? res.data!
                : img.encodeJpg(img.copyResize(source, width: 256),
                    quality: 72);
            await file.writeAsBytes(bytes, flush: true);
            await db.update(table, {photoColumn: file.path},
                where: '$idColumn = ?', whereArgs: [row[idColumn]]);
          }
        } catch (_) {}
      }
    }

    // Jangan tarik seluruh foto direktori karyawan (bisa puluhan ribu dan
    // memperlambat login pertama). Cache hanya foto pada credential yang
    // benar-benar dipakai hasil scanner offline.
    await cacheTable('tbl_m_permit_offline', 'id', 'photo_url');
    await cacheTable('tbl_m_simper_offline', 'id', 'photo_url');
  }

  @override
  void initState() {
    super.initState();

    globals.currentPage = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final sqldb = await _db.database;
        var master = <String, int>{};

        for (int mIdx = 0; mIdx < _masters.length; mIdx++) {
          final name = _masters[mIdx];
          final friendly = _friendlyNames[name] ?? name;

          if (_dataSync != null &&
              (_dataSync![name] ?? 0) == 1 &&
              globals.reSync != true) {
            master[name] = 1;
            PreferenceService.setDataSync(master);
            continue;
          }

          if (mounted) {
            setState(() {
              _table = friendly;
              _currentStep = mIdx + 1;
            });
          }
          _progress.value = 0;

          if (name == 'areas' || name == 'benchmarks') {
            try {
              final res = await _api.getMaster(name);
              await res.fold(
                (err) async {
                  debugPrint('[SyncPage] Error $name: ${err['message']}');
                  master[name] = 1;
                  PreferenceService.setDataSync(master);
                },
                (response) async {
                  final items = response as List<dynamic>;
                  final batch = sqldb.batch();
                  for (var item in items) {
                    if (name == 'areas') {
                      final areaName = (item is Map
                                  ? (item['name'] ?? item['namaArea'])
                                  : item)
                              ?.toString()
                              .trim() ??
                          '';
                      final compId =
                          item is Map ? (item['company_id'] as int? ?? 1) : 1;
                      if (areaName.isNotEmpty &&
                          !areaName.toUpperCase().contains('CAMP EKSPLORASI')) {
                        batch.rawInsert(
                          'INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at) VALUES (?, ?, ?, ?)',
                          [
                            compId,
                            areaName,
                            '',
                            DateTime.now().toIso8601String()
                          ],
                        );
                      }
                    } else {
                      if (item is Map) {
                        final benchName =
                            (item['namaBenchmark'] ?? item['name'])
                                    ?.toString()
                                    .trim() ??
                                '';
                        final areaName = (item['areaUtama'] ?? item['area'])
                                ?.toString()
                                .trim() ??
                            '';
                        final compId = item['perusahaanId'] as int? ??
                            (item['company_id'] as int? ?? 1);
                        if (benchName.isNotEmpty) {
                          batch.rawInsert(
                            'INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at) VALUES (?, ?, ?, ?)',
                            [
                              compId,
                              areaName,
                              benchName,
                              DateTime.now().toIso8601String()
                            ],
                          );
                        }
                      }
                    }
                  }
                  await batch.commit(noResult: true);
                  _progress.value = 100;
                  master[name] = 1;
                  PreferenceService.setDataSync(master);
                },
              );
            } catch (e) {
              debugPrint('[SyncPage] Error syncing $name: $e');
            }
            continue;
          }

          if (name == 'simper') {
            try {
              final res = await _api.getSimperOfflineDataset();
              await res.fold(
                (err) async {
                  debugPrint('[SyncPage] Error simper: ${err['message']}');
                  if (mounted) {
                    setState(() {
                      _offlineScanDataMissing = true;
                      _table = 'Data SIMPER belum berhasil diunduh';
                    });
                  }
                },
                (response) async {
                  final count = await _db.saveOfflineSimpers(response);
                  debugPrint('[SyncPage] Saved $count offline SIMPERs');
                  if (count > 0) {
                    _progress.value = 100;
                    master[name] = 1;
                    PreferenceService.setDataSync(master);
                  } else if (mounted) {
                    setState(() {
                      _offlineScanDataMissing = true;
                      _table = 'Data SIMPER kosong, sinkronisasi perlu diulang';
                    });
                  }
                },
              );
            } catch (e) {
              debugPrint('[SyncPage] Error syncing simper: $e');
              if (mounted) setState(() => _offlineScanDataMissing = true);
            }
            continue;
          }

          if (name == 'permit') {
            try {
              final res = await _api.getPermitOfflineDataset();
              await res.fold(
                (err) async {
                  debugPrint('[SyncPage] Error permit: ${err['message']}');
                  if (mounted) {
                    setState(() {
                      _offlineScanDataMissing = true;
                      _table = 'Data Mine Permit belum berhasil diunduh';
                    });
                  }
                },
                (response) async {
                  final count = await _db.saveOfflinePermits(response);
                  debugPrint('[SyncPage] Saved $count offline Mine Permits');
                  if (count > 0) {
                    _progress.value = 100;
                    master[name] = 1;
                    PreferenceService.setDataSync(master);
                  } else if (mounted) {
                    setState(() {
                      _offlineScanDataMissing = true;
                      _table =
                          'Data Mine Permit kosong, sinkronisasi perlu diulang';
                    });
                  }
                },
              );
            } catch (e) {
              debugPrint('[SyncPage] Error syncing permit: $e');
              if (mounted) setState(() => _offlineScanDataMissing = true);
            }
            continue;
          }

          var table = '';
          switch (name) {
            case 'employee':
            case 'employees':
              table = 'employees';
              break;
            case 'bridges':
              table = 'enum_bridges';
              break;
            case 'vehicle':
            case 'vehicles':
              table = 'vehicle_masters';
              break;
            default:
              table = '${name}_masters';
              break;
          }

          try {
            final res = await _api.getMaster(name);
            await res.fold(
              (error) async {
                debugPrint(
                    '[SyncPage] Sync Data $name Error: ${error['message']}');
                if (mounted) {
                  SnackBarMsg.danger(
                      context, titleCase('Sync Data $name Gagal!'));
                }
                master[name] = 1;
                PreferenceService.setDataSync(master);
              },
              (response) async {
                final items = (response['data'] as List?) ?? [];
                final n = items.length;
                if (n == 0) {
                  _progress.value = 100;
                  master[name] = 1;
                  PreferenceService.setDataSync(master);
                  return;
                }

                var batch = sqldb.batch();
                int count = 0;

                for (var item in items) {
                  if (item is Map<String, dynamic>) {
                    var row = <String, dynamic>{};
                    for (var e in item.entries) {
                      if (e.value != null) {
                        row[e.key] = e.value;
                      }
                    }
                    row.remove('created_by');
                    row.remove('updated_by');
                    row.remove('deleted_by');

                    if (name == 'employee' || name == 'employees') {
                      final dept =
                          (row['departemen'] ?? row['depart'])?.toString() ??
                              'GENERAL';
                      final jab =
                          (row['jabatan'] ?? row['posisi'])?.toString() ??
                              'Karyawan';
                      final perush =
                          (row['perusahaan'] ?? row['company'])?.toString() ??
                              'PT INDEXIM COALINDO';
                      final nikVal = (row['no_nik'] ?? row['nik'] ?? row['id'])
                              ?.toString() ??
                          '';
                      final namaVal =
                          (row['nama_lengkap'] ?? row['nama'])?.toString() ??
                              '';
                      final compIdVal =
                          row['company_id'] ?? row['companyId'] ?? 1;

                      row = <String, dynamic>{
                        'no_nik': nikVal,
                        'nik': nikVal,
                        'nama_lengkap': namaVal,
                        'depart': dept,
                        'departemen': dept,
                        'posisi': jab,
                        'jabatan': jab,
                        'perusahaan': perush,
                        'company_id': compIdVal,
                        // Do not cache employee photos in the offline scanner
                        // dataset; only the identity and QR mapping are needed.
                        'foto': '',
                        'qr_code':
                            (item['qr_code'] ?? item['qrCode'])?.toString() ??
                                '',
                        'qr_encrypt': item['qr_encrypt']?.toString() ?? '',
                        'qr_decrypt': item['qr_decrypt']?.toString() ?? '',
                      };
                      if (item['id'] != null && item['id'] is int) {
                        row['id'] = item['id'];
                      }
                    }

                    batch.insert(table, row,
                        conflictAlgorithm: ConflictAlgorithm.replace);
                    count++;

                    if (count % 400 == 0) {
                      await batch.commit(noResult: true);
                      batch = sqldb.batch();
                      _progress.value = (count / n * 100).floor();
                    }
                  }
                }
                if (count % 400 != 0) {
                  await batch.commit(noResult: true);
                }
                _progress.value = 100;
                master[name] = 1;
                PreferenceService.setDataSync(master);
              },
            );
          } catch (e) {
            debugPrint('[SyncPage] Exception syncing $name: $e');
          }

          await Future.delayed(const Duration(milliseconds: 150));
        }

        // Mine Permit & SIMPER adalah data wajib agar scanner dapat bekerja
        // tanpa jaringan sejak pemakaian pertama.
        final permitCount = await _db.getOfflinePermitCount();
        final simperCount = await _db.getOfflineSimperCount();
        if (permitCount == 0 || simperCount == 0) {
          if (mounted) {
            setState(() {
              _offlineScanDataMissing = true;
              _table = 'Data scan offline belum lengkap';
            });
          }
          return;
        }

        // Selesai seluruh master data
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _complete();
          });
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _complete() async {
    globals.reSync = false;
    if (!mounted) return;
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // 1. Top Brand Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D5C75).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF0D5C75).withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded,
                            size: 16, color: Color(0xFF0D5C75)),
                        SizedBox(width: 8),
                        Text(
                          'MBS SAP • MINING SAFETY SYSTEM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF0D5C75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Center Illustration Card
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        child: Image(
                          image: AssetImage('assets/images/data-sync.gif'),
                          width: 220,
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Progress Card
              ValueListenableBuilder(
                valueListenable: _progress,
                builder: (context, value, snapshot) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFCBD5E1), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Step pill & status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D5C75)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.sync_rounded,
                                    size: 16,
                                    color: Color(0xFF0D5C75),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'SINKRONISASI DATA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D5C75),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                'Tahap $_currentStep dari ${_masters.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Active Table / Module Name
                        Text(
                          _table,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Memperbarui data referensi...',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Progress Bar
                        LinearPercentIndicator(
                          padding: EdgeInsets.zero,
                          barRadius: const Radius.circular(8),
                          lineHeight: 10,
                          percent: (_progress.value / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFF1F5F9),
                          linearGradient: const LinearGradient(
                            colors: [Color(0xFF0D5C75), Color(0xFF10B981)],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Percentage & Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_progress.value}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _progress.value == 100
                                  ? 'Selesai'
                                  : 'Sedang Memproses...',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _progress.value == 100
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF0D5C75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),
              if (_offlineScanDataMissing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SyncPage(widget.profile)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Coba sinkronisasi lagi',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
