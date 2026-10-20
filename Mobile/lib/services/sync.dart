import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'api.dart';
import 'database.dart';
import 'preference.dart';

Future<bool> syncTran(
    DatabaseService db, ApiService api, String name, int id) async {
  debugPrint('--- sync tran: $name id: $id ---');
  var row = await db.get('${name}_trans', id);
  if (row == null) return false;

  var req = Map.of(row as Map<String, dynamic>);
  if ((row['image'] ?? '') != '') {
    final file = File(row['image']);
    if (await file.exists()) {
      req['image'] = await MultipartFile.fromFile(row['image']);
    } else {
      req.remove('image');
    }
  }
  if ((row['repair_image'] ?? '') != '') {
    final file = File(row['repair_image']);
    if (await file.exists()) {
      req['repair_image'] = await MultipartFile.fromFile(row['repair_image']);
    } else {
      req.remove('repair_image');
    }
  }
  if ((row['action_image'] ?? '') != '') {
    final file = File(row['action_image']);
    if (await file.exists()) {
      req['action_image'] = await MultipartFile.fromFile(row['action_image']);
    } else {
      req.remove('action_image');
    }
  }
  try {
    var con = await Connectivity().checkConnectivity();
    final hasNet = con.contains(ConnectivityResult.wifi) ||
        con.contains(ConnectivityResult.mobile) ||
        con.contains(ConnectivityResult.ethernet) ||
        con.contains(ConnectivityResult.vpn);
    if (!api.isLocalDev && !hasNet) {
      debugPrint('[syncTran] No internet access!');
      return false;
    }

    if (api.getToken.isEmpty || api.getToken.startsWith('offline_token_')) {
      final auth = PreferenceService.getAuth();
      if (auth != null && auth.token != null && auth.token!.isNotEmpty && !auth.token!.startsWith('offline_token_')) {
        api.setToken = auth.token!;
      } else {
        final bg = PreferenceService.getBgToken();
        if (bg != null && bg.isNotEmpty) {
          api.setToken = bg;
        }
      }
    }

    Response res;
    if (name == 'hazard') {
      final cleanMap = <String, dynamic>{};
      if (row['payload_json'] != null && row['payload_json'].toString().isNotEmpty) {
        try {
          final payload = jsonDecode(row['payload_json'].toString()) as Map;
          for (var kv in payload.entries) {
            if (kv.value != null) {
              cleanMap[kv.key.toString()] = kv.value.toString();
            }
          }
        } catch (_) {}
      }

      cleanMap['tanggal'] ??= (row['date'] ?? DateTime.now().toString().substring(0, 10)).toString();
      cleanMap['waktu'] ??= (row['time'] ?? '12:00').toString();
      cleanMap['area'] ??= (row['area'] ?? 'AREA OPERASIONAL').toString();
      cleanMap['lokasi'] ??= (row['lokasi'] ?? row['location_detail'] ?? 'LOKASI KERJA').toString();
      cleanMap['detil_lokasi'] ??= (row['location_detail'] ?? '').toString();
      cleanMap['temuan'] ??= (row['remark'] ?? row['title'] ?? '').toString();
      cleanMap['kategori_bahaya'] ??= (row['kategori_bahaya'] ?? 'Kondisi Tidak Aman').toString();
      cleanMap['jenis_bahaya'] ??= (row['jenis_bahaya'] ?? 'Dan lain-lain').toString();
      if (row['jenis_ketidaksesuaian'] != null) cleanMap['jenis_ketidaksesuaian'] = row['jenis_ketidaksesuaian'].toString();
      cleanMap['tingkat_resiko'] ??= (row['tingkat_resiko'] ?? 'Sedang').toString();
      if (row['tindakan_perbaikan'] != null) cleanMap['tindakan_perbaikan'] = row['tindakan_perbaikan'].toString();
      if (row['perbaikan'] != null) cleanMap['perbaikan'] = row['perbaikan'].toString();
      if (row['pja'] != null) cleanMap['pja'] = row['pja'].toString();
      if (row['nik_pja'] != null) cleanMap['nik_pja'] = row['nik_pja'].toString();
      if (row['departemen_pja'] != null) cleanMap['departemen_pja'] = row['departemen_pja'].toString();
      cleanMap['status_temuan'] ??= (row['status'] == 1 ? 'Closed' : 'Open');

      // Upload file foto (hanya 1 instance MultipartFile, jangan duplikat)
      if ((row['image'] ?? '') != '') {
        final file = File(row['image'].toString());
        if (await file.exists()) {
          cleanMap['foto_temuan'] = await MultipartFile.fromFile(file.path);
        }
      }
      if ((row['repair_image'] ?? '') != '') {
        final file = File(row['repair_image'].toString());
        if (await file.exists()) {
          cleanMap['foto_perbaikan'] = await MultipartFile.fromFile(file.path);
        }
      }

      res = await api.dio.post(
        '/hazard/create',
        data: FormData.fromMap(cleanMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${api.getToken}',
          },
        ),
      );
    } else if (name == 'inspection') {
      final cleanMap = <String, dynamic>{};
      if (row['payload_json'] != null && row['payload_json'].toString().isNotEmpty) {
        try {
          final payload = jsonDecode(row['payload_json'].toString()) as Map;
          for (var kv in payload.entries) {
            if (kv.value != null) {
              cleanMap[kv.key.toString()] = kv.value.toString();
            }
          }
        } catch (_) {}
      }

      cleanMap['tanggal'] ??= (row['date'] ?? DateTime.now().toString().substring(0, 10)).toString();
      cleanMap['waktu'] ??= (row['time'] ?? '12:00').toString();
      cleanMap['jenis_inspeksi'] ??= (row['jenis_inspeksi'] ?? row['title'] ?? 'INSPEKSI K3 LAPANGAN').toString();
      cleanMap['area'] ??= (row['area'] ?? 'AREA OPERASIONAL').toString();
      cleanMap['lokasi'] ??= (row['lokasi'] ?? row['location_detail'] ?? 'LOKASI KERJA').toString();
      cleanMap['detil_lokasi'] ??= (row['location_detail'] ?? '').toString();
      cleanMap['catatan'] ??= (row['remark'] ?? '').toString();
      if (row['pja'] != null) cleanMap['pja'] = row['pja'].toString();
      if (row['nik_pja'] != null) cleanMap['nik_pja'] = row['nik_pja'].toString();
      if (row['departemen_pja'] != null) cleanMap['departemen_pja'] = row['departemen_pja'].toString();

      for (int m = 1; m <= 5; m++) {
        for (int q = 1; q <= 3; q++) {
          final k = 'q${m}_$q';
          if (!cleanMap.containsKey(k) && row[k] != null) {
            cleanMap[k] = row[k].toString();
          }
        }
      }

      if ((row['image'] ?? '') != '') {
        final file = File(row['image'].toString());
        if (await file.exists()) {
          cleanMap['image'] = await MultipartFile.fromFile(file.path);
        }
      }

      res = await api.dio.post(
        '/tran/inspection',
        data: FormData.fromMap(cleanMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${api.getToken}',
          },
        ),
      );
    } else {
      res = await api.dio.post(
        '/tran/$name',
        data: FormData.fromMap(req),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${api.getToken}',
          },
        ),
      );
    }

    int? syncedId;
    if (res.data is Map) {
      final dataObj = res.data['data'];
      if (dataObj is Map && dataObj['id'] != null) {
        syncedId = int.tryParse(dataObj['id'].toString());
      }
    }

    final sqldb = await db.database;
    final sync = await sqldb.rawUpdate(
      'UPDATE ${name}_trans SET sync_id = ? WHERE id = ?',
      [syncedId ?? 1, id],
    );
    if (sync > 0) {
      if (name != 'hazard') {
        await sqldb.rawUpdate(
          'UPDATE ${name}_details SET ref_id = ? WHERE tran_id = ?',
          [syncedId ?? id, id],
        );
      }
      debugPrint('[syncTran] Sync $name success! ID: $syncedId');
      return true;
    }
    return false;
  } catch (err) {
    debugPrint('[syncTran] Error syncing $name:$id -> $err');
    return false;
  }
}

Future<bool> syncDetail(
    DatabaseService db, ApiService api, String name, int id) async {
  debugPrint('--- sync detail: $name id: $id ---');
  var row = await db.get('${name}_details', id);
  if (row == null) return false;

  var req = Map.of(row as Map<String, dynamic>);
  if ((row['image'] ?? '') != '') {
    req['image'] = await MultipartFile.fromFile(row['image']);
  }
  if ((row['repair_image'] ?? '') != '') {
    req['repair_image'] = await MultipartFile.fromFile(row['repair_image']);
  }
  if ((row['action_image'] ?? '') != '') {
    req['action_image'] = await MultipartFile.fromFile(row['action_image']);
  }
  try {
    var con = await Connectivity().checkConnectivity();
    if (con.contains(ConnectivityResult.wifi) == false &&
        con.contains(ConnectivityResult.mobile) == false) {
      debugPrint('No internet access!');
      return false;
    }

    var res = await api.dio.post(
      '/detail/$name',
      data: FormData.fromMap(req),
      options: Options(
        headers: {
          'Authorization': 'Bearer ${api.getToken}',
        },
      ),
    );
    var src = Map<String, dynamic>.from(res.data['data'] as Map);
    var sync =
        await db.update('${name}_details', {...row, 'sync_id': src['id']}, id);
    if (sync > 0) {
      debugPrint('Sync success!');
      return true;
    }
    return false;
  } on DioException catch (err) {
    debugPrint(err.toString());
    return false;
  }
}

Future<bool> syncAction(
    DatabaseService db, ApiService api, String name, int id) async {
  debugPrint('--- sync action: $name id: $id ---');
  var row = await db.get('action_plans', id);
  if (row == null) return false;

  var req = Map.of(row as Map<String, dynamic>);
  if ((row['repair_image'] ?? '') != '') {
    req['repair_image'] = await MultipartFile.fromFile(row['repair_image']);
  }
  if ((row['action_image'] ?? '') != '') {
    req['action_image'] = await MultipartFile.fromFile(row['action_image']);
  }
  try {
    var con = await Connectivity().checkConnectivity();
    if (con.contains(ConnectivityResult.wifi) == false &&
        con.contains(ConnectivityResult.mobile) == false) {
      debugPrint('No internet access!');
      return false;
    }

    var res = await api.dio.post(
      '/action/$name',
      data: FormData.fromMap(req),
      options: Options(
        headers: {
          'Authorization': 'Bearer ${api.getToken}',
        },
      ),
    );
    var src = Map<String, dynamic>.from(res.data['data'] as Map);
    var sync = await db.update(
        'action_plans', {...row, 'updated_at': src['updated_at']}, id);
    if (sync > 0) {
      debugPrint('Sync success!');
      return true;
    }
    return false;
  } on DioException catch (err) {
    debugPrint(err.toString());
    return false;
  }
}

Future<bool> syncFiles(
    DatabaseService db, ApiService api, String name, int id) async {
  debugPrint('--- sync file: $name id: $id ---');
  var row = await db.get('files', id);
  if (row == null) return false;

  var req = Map.of(row as Map<String, dynamic>);
  if ((row['name'] ?? '') != '') {
    req['name'] = await MultipartFile.fromFile(row['name']);
  }

  if (row['detail_id'] != null && row['detail_id'] > 0) {
    var detail = await db.get('${name}_details', row['detail_id']);
    if (detail == null) return false;

    req['tran_id'] = detail['ref_id'];
    req['detail_id'] = detail['sync_id'];
  } else if (row['tran_id'] != null && row['tran_id'] > 0) {
    var tran = await db.get('${name}_trans', row['tran_id']);
    if (tran == null) return false;

    req['tran_id'] = tran['sync_id'];
  }

  if (req['tran_id'] == null && req['detail_id'] == null) {
    return false;
  }

  try {
    var con = await Connectivity().checkConnectivity();
    if (con.contains(ConnectivityResult.wifi) == false &&
        con.contains(ConnectivityResult.mobile) == false) {
      debugPrint('No internet access!');
      return false;
    }

    var res = await api.dio.post(
      '/files',
      data: FormData.fromMap(req),
      options: Options(
        headers: {
          'Authorization': 'Bearer ${api.getToken}',
        },
      ),
    );
    var src = Map<String, dynamic>.from(res.data['data'] as Map);
    var sync = await db.update('files', {...row, 'sync_id': src['id']}, id);
    if (sync > 0) {
      debugPrint('Sync success!');
      return true;
    }
    return false;
  } on DioException catch (err) {
    debugPrint(err.toString());
    return false;
  }
}

/// Unduh dan simpan seluruh data master ke database SQLite lokal
/// Digunakan pada Splash Screen (loading awal) & Login pertama kali untuk persiapan offline mode
Future<bool> syncAllMasterData({
  required DatabaseService db,
  required ApiService api,
  Function(String masterName, int percent, String statusText)? onProgress,
}) async {
  final masters = [
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

  final friendlyNames = {
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
    'employee': 'Otoritas & Pengawas Lapangan',
    'vehicle': 'Daftar Alat Berat & Kendaraan',
    'areas': 'Area Utama Kerja Tambang',
    'benchmarks': 'Detail Lokasi & Benchmark',
  };

  try {
    var con = await Connectivity().checkConnectivity();
    if (con.contains(ConnectivityResult.wifi) == false &&
        con.contains(ConnectivityResult.mobile) == false) {
      debugPrint('[Sync] Offline: tidak ada koneksi internet untuk download master data.');
      return false;
    }

    final dataSync = PreferenceService.getDataSync() ?? <String, dynamic>{};
    int total = masters.length;
    int completed = 0;

    for (int i = 0; i < masters.length; i++) {
      final name = masters[i];
      final friendly = friendlyNames[name] ?? name;
      final percent = (((i + 1) / total) * 100).toInt();

      onProgress?.call(name, percent, 'Sinkronisasi $friendly...');

      if (name == 'areas' || name == 'benchmarks') {
        try {
          final sqldb = await db.database;
          await sqldb.execute('''
            CREATE TABLE IF NOT EXISTS tbl_m_benchmark (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              perusahaan_id INTEGER,
              area_utama TEXT,
              nama_benchmark TEXT,
              created_by_nik TEXT,
              created_by_name TEXT,
              created_at TEXT
            )
          ''');
          final res = await api.getMaster(name);
          await res.fold(
            (err) async => debugPrint('[Sync] Info master $name: ${err['message']}'),
            (response) async {
              final items = (response['data'] as List?) ?? [];
              final batch = sqldb.batch();
              for (var item in items) {
                if (item is Map<String, dynamic>) {
                  if (name == 'areas') {
                    final areaName = item['name']?.toString().trim() ?? '';
                    final compId = item['company_id'] as int? ?? 1;
                    if (areaName.isNotEmpty && !areaName.toUpperCase().contains('CAMP EKSPLORASI')) {
                      batch.rawInsert(
                        'INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at) VALUES (?, ?, ?, ?)',
                        [compId, areaName, '', DateTime.now().toIso8601String()],
                      );
                    }
                  } else {
                    final benchName = item['name']?.toString().trim() ?? '';
                    final areaName = item['area']?.toString().trim() ?? '';
                    final compId = item['company_id'] as int? ?? 1;
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
              dataSync[name] = 1;
              await PreferenceService.setDataSync(dataSync);
              completed++;
            },
          );
        } catch (e) {
          debugPrint('[Sync] Error syncing master $name: $e');
        }
        await Future.delayed(const Duration(milliseconds: 100));
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
        final res = await api.getMaster(name);
        await res.fold(
          (err) async {
            debugPrint('[Sync] Info master $name: ${err['message']}');
          },
          (response) async {
            final items = (response['data'] as List?) ?? [];
            final sqldb = await db.database;
            var batch = sqldb.batch();
            int count = 0;
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                var row = Map<String, dynamic>.from(item);
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
                }
              }
            }
            if (count % 400 != 0) {
              await batch.commit(noResult: true);
            }
            dataSync[name] = 1;
            await PreferenceService.setDataSync(dataSync);
            completed++;
          },
        );
      } catch (e) {
        debugPrint('[Sync] Error syncing master $name: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    return completed > 0;
  } catch (e) {
    debugPrint('[Sync] Error umum sync master: $e');
    return false;
  }
}
