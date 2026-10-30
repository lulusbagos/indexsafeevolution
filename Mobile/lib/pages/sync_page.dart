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
    'simper',
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
    'simper': 'Data SIMPER (Siap Scan Offline)',
  };

  String _name = '';
  String _table = '...';
  int _currentStep = 1;

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

          if (name == 'simper') {
            try {
              final res = await _api.getMaster('simper');
              await res.fold(
                (err) async {
                  debugPrint('[SyncPage] Error simper: ${err['message']}');
                },
                (response) async {
                  final items = (response['data'] as List?) ?? [];
                  final count = await _db.saveOfflineSimpers(items);
                  debugPrint('[SyncPage] Saved $count offline SIMPERs');
                  _progress.value = 100;
                  master[name] = 1;
                  PreferenceService.setDataSync(master);
                },
              );
            } catch (e) {
              debugPrint('[SyncPage] Error syncing simper: $e');
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D5C75).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0D5C75).withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 16, color: Color(0xFF0D5C75)),
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
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: const Image(
                            image: AssetImage('assets/images/data-sync.gif'),
                            width: 200,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Sinkronisasi Otomatis Database Lokal',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. User Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Halo ${titleCase(_name)}, Semangat Pagi!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (globals.reSync == true)
                          ? 'Sedang melakukan sinkronisasi ulang seluruh master data tambang...'
                          : (_dataSync != null && _dataSync!.length < _masters.length)
                              ? 'Memperbarui master data referensi inspeksi yang belum lengkap...'
                              : 'Selamat datang di aplikasi MBS SAP! Menyiapkan data operasional tambang & referensi keselamatan kerja.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 4. Modern Active Progress Card
              ValueListenableBuilder(
                valueListenable: _progress,
                builder: (context, value, snapshot) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
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
                                    color: const Color(0xFF0D5C75).withOpacity(0.12),
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
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                'Tahap $_currentStep dari ${_masters.length}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Active Table / Module Name
                        Text(
                          _table,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Mengunduh & memvalidasi tabel referensi lokal...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Modern Progress Bar
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

                        const SizedBox(height: 8),

                        // Percentage & Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_progress.value}% Selesai',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _progress.value == 100 ? 'Data Tersinkron' : 'Sedang Memproses...',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _progress.value == 100 ? const Color(0xFF10B981) : const Color(0xFF0D5C75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // 5. Offline-Ready Assurance Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.offline_pin_rounded, size: 16, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Data tersimpan aman di HP untuk mode offline tanpa sinyal.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
