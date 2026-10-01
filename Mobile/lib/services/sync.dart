import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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
    if (!con.contains(ConnectivityResult.wifi) &&
        !con.contains(ConnectivityResult.mobile) &&
        !con.contains(ConnectivityResult.ethernet) &&
        !con.contains(ConnectivityResult.vpn)) {
      debugPrint('No internet access!');
      return false;
    }

    if (api.getToken.isEmpty) {
      final auth = PreferenceService.getAuth();
      if (auth != null && auth.token != null && auth.token!.isNotEmpty) {
        api.setToken = auth.token!;
      }
    }

    var res = await api.dio.post(
      '/tran/$name',
      data: FormData.fromMap(req),
      options: Options(
        headers: {
          'Authorization': 'Bearer ${api.getToken}',
        },
      ),
    );
    var src = Map<String, dynamic>.from(res.data['data'] as Map);
    var sync =
        await db.update('${name}_trans', {...row, 'sync_id': src['id']}, id);
    if (sync > 0) {
      if (name != 'hazard') {
        await db.execute(
            '''update ${name}_details set ref_id=${src['id']} where tran_id=$id''');
      }
      debugPrint('Sync success!');
      return true;
    }
    return false;
  } on DioException catch (err) {
    debugPrint(err.toString());
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
    'vehicle'
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

      var table = '';
      switch (name) {
        case 'employee':
          table = 'employees';
          break;
        case 'bridges':
          table = 'enum_bridges';
          break;
        case 'vehicle':
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
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                var row = Map<String, dynamic>.from(item);
                row.remove('created_by');
                row.remove('updated_by');
                row.remove('deleted_by');
                await db.insert(table, row);
              }
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
