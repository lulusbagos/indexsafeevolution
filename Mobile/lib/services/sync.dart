import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'api.dart';
import 'database.dart';
import 'preference.dart';

Future<bool> _hasVerifiedInternet() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    final request = await client
        .getUrl(Uri.parse('https://clients3.google.com/generate_204'));
    final response = await request.close().timeout(const Duration(seconds: 5));
    final ok = response.statusCode >= 200 && response.statusCode < 400;
    await response.drain();
    client.close(force: true);
    return ok;
  } catch (_) {
    return false;
  }
}

Future<bool> syncTran(
    DatabaseService db, ApiService api, String name, int id) async {
  debugPrint('--- sync tran: $name id: $id ---');
  final tableName = (name == 'simama') ? 'inspection_trans' : '${name}_trans';
  var row = await db.get(tableName, id);
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
    // Never send an offline draft merely because a USB/localhost backend is
    // reachable. The user must have an actual network transport first.
    if (!hasNet || !await _hasVerifiedInternet()) {
      debugPrint(
          '[syncTran] Offline/unverified network: transaction remains in local outbox.');
      return false;
    }

    if (api.getToken.isEmpty || api.getToken.startsWith('offline_token_')) {
      final auth = PreferenceService.getAuth();
      if (auth != null &&
          auth.token != null &&
          auth.token!.isNotEmpty &&
          !auth.token!.startsWith('offline_token_')) {
        api.setToken = auth.token!;
      } else {
        final bg = PreferenceService.getBgToken();
        if (bg != null && bg.isNotEmpty) {
          api.setToken = bg;
        }
      }
    }

    Response? res;
    final observationDetailServerIds = <int, int>{};
    if (name == 'hazard') {
      final cleanMap = <String, dynamic>{};
      if (row['payload_json'] != null &&
          row['payload_json'].toString().isNotEmpty) {
        try {
          final payload = jsonDecode(row['payload_json'].toString()) as Map;
          for (var kv in payload.entries) {
            if (kv.value != null) {
              cleanMap[kv.key.toString()] = kv.value.toString();
            }
          }
        } catch (_) {}
      }

      cleanMap['tanggal'] ??=
          (row['date'] ?? DateTime.now().toString().substring(0, 10))
              .toString();
      cleanMap['waktu'] ??= (row['time'] ?? '12:00').toString();
      cleanMap['area'] ??= (row['area'] ?? 'AREA OPERASIONAL').toString();
      cleanMap['lokasi'] ??=
          (row['lokasi'] ?? row['location_detail'] ?? 'LOKASI KERJA')
              .toString();
      cleanMap['detil_lokasi'] ??= (row['location_detail'] ?? '').toString();
      cleanMap['temuan'] ??= (row['remark'] ?? row['title'] ?? '').toString();
      cleanMap['kategori_bahaya'] ??=
          (row['kategori_bahaya'] ?? 'Kondisi Tidak Aman').toString();
      cleanMap['jenis_bahaya'] ??=
          (row['jenis_bahaya'] ?? 'Dan lain-lain').toString();
      if (row['jenis_ketidaksesuaian'] != null) {
        cleanMap['jenis_ketidaksesuaian'] =
            row['jenis_ketidaksesuaian'].toString();
      }
      cleanMap['tingkat_resiko'] ??=
          (row['tingkat_resiko'] ?? 'Sedang').toString();
      if (row['tindakan_perbaikan'] != null) {
        cleanMap['tindakan_perbaikan'] = row['tindakan_perbaikan'].toString();
      }
      if (row['perbaikan'] != null) {
        cleanMap['perbaikan'] = row['perbaikan'].toString();
      }
      if (row['pja'] != null) {
        cleanMap['pja'] = row['pja'].toString();
      }
      if (row['nik_pja'] != null) {
        cleanMap['nik_pja'] = row['nik_pja'].toString();
      }
      if (row['departemen_pja'] != null) {
        cleanMap['departemen_pja'] = row['departemen_pja'].toString();
      }
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
    } else if (name == 'inspection' || name == 'simama') {
      final cleanMap = <String, dynamic>{};
      if (row['payload_json'] != null &&
          row['payload_json'].toString().isNotEmpty) {
        try {
          final payload = jsonDecode(row['payload_json'].toString()) as Map;
          for (var kv in payload.entries) {
            if (kv.value != null) {
              cleanMap[kv.key.toString()] = kv.value.toString();
            }
          }
        } catch (_) {}
      }

      final defaultJenis = (name == 'simama')
          ? 'Sidak Malam Management (SiMaMa)'
          : 'INSPEKSI K3 LAPANGAN';
      cleanMap['tanggal'] ??=
          (row['date'] ?? DateTime.now().toString().substring(0, 10))
              .toString();
      cleanMap['waktu'] ??=
          (row['time'] ?? ((name == 'simama') ? '21:00' : '12:00')).toString();
      cleanMap['jenis_inspeksi'] ??=
          (row['jenis_inspeksi'] ?? row['title'] ?? defaultJenis).toString();
      cleanMap['area'] ??= (row['area'] ?? 'AREA OPERASIONAL').toString();
      cleanMap['lokasi'] ??=
          (row['lokasi'] ?? row['location_detail'] ?? 'LOKASI KERJA')
              .toString();
      cleanMap['detil_lokasi'] ??= (row['location_detail'] ?? '').toString();
      cleanMap['catatan'] ??= (row['remark'] ?? '').toString();
      if (row['pja'] != null) {
        cleanMap['pja'] = row['pja'].toString();
      }
      if (row['nik_pja'] != null) {
        cleanMap['nik_pja'] = row['nik_pja'].toString();
      }
      if (row['departemen_pja'] != null) {
        cleanMap['departemen_pja'] = row['departemen_pja'].toString();
      }

      for (int m = 1; m <= 6; m++) {
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

      final endpoint = (name == 'simama') ? '/tran/simama' : '/tran/inspection';
      res = await api.dio.post(
        endpoint,
        data: FormData.fromMap(cleanMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${api.getToken}',
          },
        ),
      );
    } else if (name == 'p2h') {
      final cleanMap = <String, dynamic>{};
      cleanMap['tanggal'] = (row['date'] ?? DateTime.now().toString().substring(0, 10)).toString();
      cleanMap['waktu'] = (row['time'] ?? '12:00').toString();
      cleanMap['no_lambung'] = (row['no_lambung'] ?? 'LV-001').toString();
      cleanMap['jenis_kendaraan'] = (row['jenis_kendaraan'] ?? 'LIGHT VEHICLE').toString();
      cleanMap['merek'] = (row['merek'] ?? 'TOYOTA').toString();
      cleanMap['kilometer'] = (row['km'] ?? 0).toString();
      cleanMap['simper_kimper'] = (row['simper_kimper'] ?? ((row['simper'] == 1) ? 'YA' : 'TIDAK')).toString();
      cleanMap['gol_a_json'] = (row['gol_a_json'] ?? '[]').toString();
      cleanMap['gol_b_json'] = (row['gol_b_json'] ?? '[]').toString();
      cleanMap['gol_c_json'] = (row['gol_c_json'] ?? '[]').toString();

      // Foto Speedometer
      final speedoPath = row['foto_speedometer'] ?? row['image'];
      if (speedoPath != null && speedoPath.toString().isNotEmpty) {
        final f = File(speedoPath.toString());
        if (await f.exists()) {
          cleanMap['foto_speedometer'] = await MultipartFile.fromFile(f.path);
        }
      }

      // Check defect photos in Gol A, B, C
      for (var group in ['golA', 'golB', 'golC']) {
        final jsonStr = (group == 'golA' ? row['gol_a_json'] : (group == 'golB' ? row['gol_b_json'] : row['gol_c_json']))?.toString();
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final items = jsonDecode(jsonStr) as List;
            for (int i = 0; i < items.length; i++) {
              final it = items[i];
              if (it is Map && it['photoUrl'] != null) {
                final photoPath = it['photoUrl'].toString();
                final f = File(photoPath);
                if (await f.exists()) {
                  cleanMap['${group}_photo_$i'] = await MultipartFile.fromFile(f.path);
                }
              }
            }
          } catch (_) {}
        }
      }

      res = await api.dio.post(
        '/p2h',
        data: FormData.fromMap(cleanMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${api.getToken}',
          },
        ),
      );
    } else if (name == 'p5m') {
      final cleanMap = <String, dynamic>{};
      cleanMap['tanggal'] = (row['date'] ?? DateTime.now().toString().substring(0, 10)).toString();
      cleanMap['waktu'] = (row['time'] ?? '08:00').toString();
      cleanMap['area'] = (row['area'] ?? row['area_name'] ?? 'AREA OPERASIONAL').toString();
      cleanMap['lokasi'] = (row['lokasi'] ?? row['location_name'] ?? row['location_detail'] ?? 'LOKASI KERJA').toString();
      cleanMap['detil_lokasi'] = (row['location_detail'] ?? '').toString();
      cleanMap['topik'] = (row['topik'] ?? row['topic'] ?? 'K3 Operasional').toString();
      cleanMap['judul'] = (row['title'] ?? row['judul'] ?? 'P5M Awal Shift - Siap Bekerja').toString();
      cleanMap['keterangan'] = (row['remark'] ?? row['keterangan'] ?? '.').toString();
      cleanMap['catatan'] = (row['catatan'] ?? row['remark'] ?? '').toString();

      // Attach questions & answers from p5m_details or row['questions_json']
      final sqldb = await db.database;
      final details = await sqldb.rawQuery('SELECT * FROM p5m_details WHERE tran_id = ? ORDER BY id ASC', [id]);
      if (details.isNotEmpty) {
        final questions = details.map((d) => d['name']?.toString() ?? '').toList();
        final answers = details.map((d) => (d['yesno'] == 1 || d['status'] == 1) ? 'Yes' : 'No').toList();
        cleanMap['questions_json'] = jsonEncode(questions);
        cleanMap['answers_json'] = jsonEncode(answers);
      } else if (row['questions_json'] != null) {
        cleanMap['questions_json'] = row['questions_json'].toString();
        cleanMap['answers_json'] = row['answers_json']?.toString() ?? '[]';
      }

      // Upload photo
      final photoPath = row['foto_kegiatan'] ?? row['image'];
      if (photoPath != null && photoPath.toString().isNotEmpty) {
        final file = File(photoPath.toString());
        if (await file.exists()) {
          cleanMap['foto_kegiatan'] = await MultipartFile.fromFile(file.path);
        }
      }

      res = await api.dio.post(
        '/tran/p5m',
        data: FormData.fromMap(cleanMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${api.getToken}',
          },
        ),
      );
    } else if (name == 'observation') {
      // MBS stores one result per tbl_t_observation row.  Preserve every
      // mobile result (and its photo) by submitting the shared header once
      // for each detail, just like the web form's result array.
      final cleanMap = <String, dynamic>{
        'tanggal': (row['date'] ?? DateTime.now().toString().substring(0, 10))
            .toString(),
        'waktu': (row['time'] ?? '12:00').toString(),
        'area': (row['area'] ?? '').toString(),
        'lokasi': (row['lokasi'] ?? row['location_detail'] ?? '').toString(),
        'detil_lokasi': (row['location_detail'] ?? '').toString(),
        'kegiatan_yang_diamati':
            (row['subject'] ?? row['title'] ?? '').toString(),
        'perusahaan_id': (row['company_id'] ?? '').toString(),
        'perusahaan_yang_diamati': (row['company_name'] ?? '').toString(),
        'departemen_yang_diamati': (row['dept_name'] ?? '').toString(),
        'dokumen_pendukung':
            (row['doc_name'] ?? row['remark'] ?? '').toString(),
        'resiko_kritis': (row['risk_name'] ?? '').toString(),
        'tingkat_resiko': (row['risk_level'] ?? '').toString(),
      };
      final details = await _observationDetails(db, id);
      if (details.isEmpty) return false;
      for (final detail in details) {
        final detailMap = Map<String, dynamic>.from(cleanMap);
        detailMap['perihal_yang_diamati'] =
            (detail['point'] ?? detail['name'] ?? '').toString();
        detailMap['hasil_observasi'] =
            _observationResult((detail['type'] ?? '').toString());
        detailMap['keterangan'] = (detail['remark'] ?? '').toString();
        final image = detail['image']?.toString();
        if (image != null && image.isNotEmpty && await File(image).exists()) {
          detailMap['image'] = await MultipartFile.fromFile(image);
        }
        res = await api.dio.post('/tran/observation',
            data: FormData.fromMap(detailMap),
            options:
                Options(headers: {'Authorization': 'Bearer ${api.getToken}'}));
        final responseData = res.data is Map ? res.data['data'] : null;
        final serverId = responseData is Map
            ? int.tryParse(responseData['id'].toString())
            : null;
        final localDetailId = detail['id'] is int
            ? detail['id'] as int
            : int.tryParse(detail['id'].toString());
        if (localDetailId != null && serverId != null) {
          observationDetailServerIds[localDetailId] = serverId;
        }
      }
    } else if (name == 'safety') {
      final cleanMap = <String, dynamic>{};
      cleanMap['tanggal'] = (row['date'] ?? DateTime.now().toString().substring(0, 10)).toString();
      cleanMap['waktu'] = (row['time'] ?? '08:00').toString();
      cleanMap['area'] = (row['area'] ?? row['area_name'] ?? 'AREA OPERASIONAL').toString();
      cleanMap['lokasi'] = (row['lokasi'] ?? row['location_name'] ?? row['location_detail'] ?? 'LOKASI KERJA').toString();
      cleanMap['detil_lokasi'] = (row['location_detail'] ?? '').toString();
      cleanMap['judul'] = (row['judul'] ?? row['title'] ?? 'Safety Talk Rutin').toString();
      cleanMap['keterangan'] = (row['keterangan'] ?? row['remark'] ?? '').toString();

      final selfImg = row['self_image'] ?? row['foto_diri'] ?? row['image'];
      if (selfImg != null && selfImg.toString().isNotEmpty) {
        final f = File(selfImg.toString());
        if (await f.exists()) {
          cleanMap['foto_diri'] = await MultipartFile.fromFile(f.path);
        }
      }
      final evtImg = row['event_image'] ?? row['foto_kegiatan'] ?? row['repair_image'];
      if (evtImg != null && evtImg.toString().isNotEmpty) {
        final f = File(evtImg.toString());
        if (await f.exists()) {
          cleanMap['foto_kegiatan'] = await MultipartFile.fromFile(f.path);
        }
      }

      res = await api.dio.post(
        '/tran/safety',
        data: FormData.fromMap(cleanMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${api.getToken}',
          },
        ),
      );
    } else if (name == 'coaching') {
      final cleanMap = <String, dynamic>{};
      cleanMap['tanggal'] = (row['date'] ?? DateTime.now().toString().substring(0, 10)).toString();
      cleanMap['waktu'] = (row['time'] ?? '08:00').toString();
      cleanMap['area'] = (row['area'] ?? row['area_name'] ?? 'AREA OPERASIONAL').toString();
      cleanMap['lokasi'] = (row['lokasi'] ?? row['location_name'] ?? row['location_detail'] ?? 'LOKASI KERJA').toString();
      cleanMap['detil_lokasi'] = (row['location_detail'] ?? row['detil_lokasi'] ?? '').toString();
      cleanMap['tema'] = (row['tema'] ?? row['purpose'] ?? row['title'] ?? 'Safety Coaching').toString();
      cleanMap['komitmen'] = (row['komitmen'] ?? row['title'] ?? '').toString();
      cleanMap['feedback'] = (row['feedback'] ?? row['remark'] ?? '').toString();

      final sqldb = await db.database;
      final details = await sqldb.rawQuery('SELECT * FROM coaching_details WHERE tran_id = ? ORDER BY id ASC', [id]);
      if (details.isNotEmpty) {
        final list = details.map((d) {
          final rawName = d['name']?.toString() ?? '';
          var nik = d['no_nik']?.toString() ?? d['nik']?.toString() ?? '';
          var nama = d['nama_lengkap']?.toString() ?? d['nama']?.toString() ?? '';
          if (nik.isEmpty && rawName.contains('-')) {
            final parts = rawName.split('-');
            nik = parts[0].trim();
            nama = parts.length > 1 ? parts.sublist(1).join('-').trim() : nik;
          } else if (nama.isEmpty) {
            nama = rawName;
          }
          return {
            'no_nik': nik,
            'nik': nik,
            'nama_lengkap': nama,
            'nama': nama,
            'posisi': d['posisi']?.toString() ?? d['remark']?.toString() ?? '',
            'departemen': d['departemen']?.toString() ?? '',
            'perusahaan': d['perusahaan']?.toString() ?? '',
          };
        }).toList();
        cleanMap['participants_json'] = jsonEncode(list);
      } else if (row['participants_json'] != null && row['participants_json'].toString().isNotEmpty) {
        cleanMap['participants_json'] = row['participants_json'].toString();
      }

      final coachImg = row['foto'] ?? row['image'];
      if (coachImg != null && coachImg.toString().isNotEmpty) {
        final f = File(coachImg.toString());
        if (await f.exists()) {
          cleanMap['image'] = await MultipartFile.fromFile(f.path);
        }
      }

      res = await api.dio.post(
        '/tran/coaching',
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
    if (res?.data is Map) {
      final dataObj = res!.data['data'];
      if (dataObj is Map && dataObj['id'] != null) {
        syncedId = int.tryParse(dataObj['id'].toString());
      }
    }

    final sqldb = await db.database;
    final sync = await sqldb.rawUpdate(
      'UPDATE $tableName SET sync_id = ? WHERE id = ?',
      [syncedId ?? 1, id],
    );
    if (sync > 0) {
      if (name != 'hazard') {
        final detailsTable = (name == 'simama') ? 'inspection_details' : '${name}_details';
        await sqldb.rawUpdate(
          'UPDATE $detailsTable SET ref_id = ? WHERE tran_id = ?',
          [syncedId ?? id, id],
        );
      }
      if (name == 'observation') {
        for (final entry in observationDetailServerIds.entries) {
          await sqldb.update('observation_details',
              {'ref_id': entry.value, 'sync_id': entry.value},
              where: 'id = ?', whereArgs: [entry.key]);
        }
        // Foto tambahan dari UploadFiles disimpan sebagai lampiran per detail.
        // Kirim setelah detail punya ref_id/sync_id server agar setiap foto
        // melekat pada hasil Observasi yang benar.
        final attachments = await sqldb.query('files',
            columns: ['id'],
            where: 'tran_id = ? AND sync_id IS NULL',
            whereArgs: [id]);
        for (final attachment in attachments) {
          final fileId = attachment['id'] as int?;
          if (fileId != null) {
            await syncFiles(db, api, 'observation', fileId);
          }
        }
      }
      if (name == 'coaching') {
        // Peserta Coaching disimpan sebagai detail. Kirim setelah transaksi
        // memperoleh ID server agar setiap peserta melekat ke sesi yang benar.
        final details = await sqldb.query(
          'coaching_details',
          columns: ['id'],
          where: 'tran_id = ? AND sync_id IS NULL',
          whereArgs: [id],
        );
        for (final detail in details) {
          final detailId = detail['id'] as int?;
          if (detailId != null) {
            await syncDetail(db, api, 'coaching', detailId);
          }
        }
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

String _observationResult(String value) {
  switch (value.trim().toUpperCase()) {
    case 'P':
      return 'Positive';
    case 'I':
      return 'Improvement';
    case 'V':
      return 'Violation';
    default:
      return value;
  }
}

Future<List<Map<String, Object?>>> _observationDetails(
    DatabaseService db, int tranId) async {
  final database = await db.database;
  return database.query('observation_details',
      where: 'tran_id = ?', whereArgs: [tranId], orderBy: 'id ASC');
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
    // Wajib tersedia bahkan sebelum login agar scanner siap offline sejak
    // pemakaian pertama. Payload tidak membawa foto karyawan.
    'permit',
    'simper',
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
    'permit': 'Kartu Mine Permit untuk Scan Offline',
    'simper': 'Kartu SIMPER untuk Scan Offline',
    'vehicle': 'Daftar Alat Berat & Kendaraan',
    'areas': 'Area Utama Kerja Tambang',
    'benchmarks': 'Detail Lokasi & Benchmark',
  };

  try {
    var con = await Connectivity().checkConnectivity();
    if (con.contains(ConnectivityResult.wifi) == false &&
        con.contains(ConnectivityResult.mobile) == false) {
      debugPrint(
          '[Sync] Offline: tidak ada koneksi internet untuk download master data.');
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

      if (name == 'permit') {
        try {
          final res = await api.getPermitOfflineDataset();
          await res.fold(
            (err) async =>
                debugPrint('[Sync] Dataset Mine Permit: ${err['message']}'),
            (items) async {
              await db.saveOfflinePermits(items);
              dataSync[name] = 1;
              await PreferenceService.setDataSync(dataSync);
              completed++;
            },
          );
        } catch (e) {
          debugPrint('[Sync] Error syncing Mine Permit: $e');
        }
        continue;
      }

      if (name == 'simper') {
        try {
          final res = await api.getSimperOfflineDataset();
          await res.fold(
            (err) async =>
                debugPrint('[Sync] Dataset SIMPER: ${err['message']}'),
            (items) async {
              await db.saveOfflineSimpers(items);
              dataSync[name] = 1;
              await PreferenceService.setDataSync(dataSync);
              completed++;
            },
          );
        } catch (e) {
          debugPrint('[Sync] Error syncing SIMPER: $e');
        }
        continue;
      }

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
            (err) async =>
                debugPrint('[Sync] Info master $name: ${err['message']}'),
            (response) async {
              final items = (response['data'] as List?) ?? [];
              final batch = sqldb.batch();
              for (var item in items) {
                if (item is Map<String, dynamic>) {
                  if (name == 'areas') {
                    final areaName = item['name']?.toString().trim() ?? '';
                    final compId = item['company_id'] as int? ?? 1;
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
                    final benchName = item['name']?.toString().trim() ?? '';
                    final areaName = item['area']?.toString().trim() ?? '';
                    final compId = item['company_id'] as int? ?? 1;
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
                  final dept =
                      (row['departemen'] ?? row['depart'])?.toString() ??
                          'GENERAL';
                  final jab = (row['jabatan'] ?? row['posisi'])?.toString() ??
                      'Karyawan';
                  final perush =
                      (row['perusahaan'] ?? row['company'])?.toString() ??
                          'PT INDEXIM COALINDO';
                  final nikVal =
                      (row['no_nik'] ?? row['nik'] ?? row['id'])?.toString() ??
                          '';
                  final namaVal =
                      (row['nama_lengkap'] ?? row['nama'])?.toString() ?? '';
                  final compIdVal = row['company_id'] ?? row['companyId'] ?? 1;
                  final fotoVal = (row['foto'] ?? row['path_foto'] ?? row['pathFoto'] ?? row['url_foto'])?.toString() ?? '';

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
                    'foto': fotoVal,
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
