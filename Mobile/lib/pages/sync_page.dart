import 'package:flutter/material.dart';
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
import 'login_page.dart';

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
  ];

  final _friendlyNames = {
    'enum': 'Master Status & Referensi',
    'bridges': 'Jembatan Referensi',
    'inspection': 'Format Inspeksi Tambang',
    'hazard': 'Kategori Bahaya & Resiko',
    'coaching': 'Modul Edukasi & Coaching',
    'k3': 'Standar Keselamatan K3',
    'observation': 'Pedoman Observasi Lapangan',
    'p2h': 'Pemeriksaan Harian Unit (P2H)',
    'p5m': 'Topik Keselamatan P5M',
    'safety': 'Aturan & Regulasi Safety',
    'employee': 'Otoritas & Pengawas Lapangan (PJA)',
    'vehicle': 'Daftar Alat Berat & Kendaraan',
    'areas': 'Area Utama Tambang',
    'benchmarks': 'Detail Lokasi & Benchmark',
  };

  String _name = '';
  String _table = '...';

  @override
  void initState() {
    super.initState();

    globals.currentPage = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(
          () => _name = (widget.profile?.namaLengkap?.split(' ')[0] ?? ''));
      try {
        final sqldb = await _db.database;
        var master = <String, int>{};

        for (int mIdx = 0; mIdx < _masters.length; mIdx++) {
          final name = _masters[mIdx];
          final friendly = _friendlyNames[name] ?? name;

          if (_dataSync != null && (_dataSync![name] ?? 0) == 1 && globals.reSync != true) {
            master[name] = 1;
            PreferenceService.setDataSync(master);
            continue;
          }

          if (mounted) {
            setState(() => _table = friendly);
          }
          _progress.value = 0;

          if (name == 'areas' || name == 'benchmarks') {
            try {
              final res = await _api.getMaster(name);
              await res.fold(
                (err) async {
                  debugPrint('[SyncPage] Error $name: ${err['message']}');
                },
                (response) async {
                  final items = (response['data'] as List?) ?? [];
                  final batch = sqldb.batch();
                  for (var item in items) {
                    if (name == 'areas') {
                      final areaName = (item is Map ? (item['name'] ?? item['namaArea']) : item)?.toString().trim() ?? '';
                      final compId = item is Map ? (item['company_id'] as int? ?? 1) : 1;
                      if (areaName.isNotEmpty && !areaName.toUpperCase().contains('CAMP EKSPLORASI')) {
                        batch.rawInsert(
                          'INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at) VALUES (?, ?, ?, ?)',
                          [compId, areaName, '', DateTime.now().toIso8601String()],
                        );
                      }
                    } else {
                      if (item is Map) {
                        final benchName = (item['namaBenchmark'] ?? item['name'])?.toString().trim() ?? '';
                        final areaName = (item['areaUtama'] ?? item['area'])?.toString().trim() ?? '';
                        final compId = item['perusahaanId'] as int? ?? (item['company_id'] as int? ?? 1);
                        if (benchName.isNotEmpty) {
                          batch.rawInsert(
                            'INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at) VALUES (?, ?, ?, ?)',
                            [compId, areaName, benchName, DateTime.now().toIso8601String()],
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
                debugPrint('[SyncPage] Sync Data $name Error: ${error['message']}');
                if (mounted) {
                  SnackBarMsg.danger(context, titleCase('Sync Data $name Gagal!'));
                }
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
                      final dept = (row['departemen'] ?? row['depart'])?.toString() ?? 'GENERAL';
                      final jab = (row['jabatan'] ?? row['posisi'])?.toString() ?? 'Karyawan';
                      final perush = (row['perusahaan'] ?? row['company'])?.toString() ?? 'PT INDEXIM COALINDO';
                      final nikVal = (row['no_nik'] ?? row['nik'] ?? row['id'])?.toString() ?? '';
                      final namaVal = (row['nama_lengkap'] ?? row['nama'])?.toString() ?? '';
                      final compIdVal = row['company_id'] ?? row['companyId'] ?? 1;

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
                      };
                      if (item['id'] != null && item['id'] is int) {
                        row['id'] = item['id'];
                      }
                    }

                    batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
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
    var dataSync = PreferenceService.getDataSync();
    if (dataSync != null && dataSync.length >= _masters.length) {
      if (!mounted) return;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Image(
                  image: AssetImage('assets/images/data-sync.gif'),
                  width: 300,
                ),
              ),
            ),
            Card.filled(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Text(
                      'Halo ${titleCase(_name)}, Semangat Pagi!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      (globals.reSync == true)
                          ? 'Kami sedang melakukan sinkronisasi ulang master data, mohon menunggu sebentar'
                          : (_dataSync != null &&
                                  _dataSync!.length < _masters.length)
                              ? 'Masih terdapat master data yang belum sinkron, mohon menunggu sebentar'
                              : 'Selamat datang di aplikasi MBS SAP, kami sedang melakukan sinkronisasi master data, mohon menunggu sebentar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ValueListenableBuilder(
              valueListenable: _progress,
              builder: (context, value, snapshot) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${_progress.value}%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Sync Data $_table'.toUpperCase(),
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 15),
                    LinearPercentIndicator(
                      barRadius: const Radius.circular(10),
                      lineHeight: 15,
                      percent: _progress.value / 100,
                      backgroundColor: Colors.grey.shade300,
                      progressColor: Colors.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
