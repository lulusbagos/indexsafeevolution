import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/notification_item_model.dart';

class DatabaseService {
  static DatabaseService? _instance;
  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  DatabaseService._internal();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _ensureHazardTransColumns(_database!);
    await _ensureInspectionTransColumns(_database!);
    await _ensureObservationTransColumns(_database!);
    await _ensureEmployeeColumns(_database!);
    await _ensureBenchmarkTable(_database!);
    await _ensureP2hTransColumns(_database!);
    await _ensureP5mTransColumns(_database!);
    await _ensureDciTable(_database!);
    await _ensureSpiTable(_database!);
    await _ensureGciTable(_database!);
    await _ensureSafetyTransColumns(_database!);
    await _ensureCoachingTransColumns(_database!);
    await _ensureNotificationsTable(_database!);
    await _ensureSimperOfflineTable(_database!);
    await _ensurePermitOfflineTable(_database!);
    await _ensureOfflineQueues(_database!);
    return _database!;
  }

  _initDatabase() async {
    var dbPath = await getDatabasesPath();
    var path = join(dbPath, 'isafe18.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createOfflineSyncJobsTable(db);
    await _ensureHazardTransColumns(db);
    await _ensureInspectionTransColumns(db);
    await _ensureObservationTransColumns(db);
    await _ensureEmployeeColumns(db);
    await _ensureBenchmarkTable(db);
    await _ensureP2hTransColumns(db);
    await _ensureP5mTransColumns(db);
    await _ensureDciTable(db);
    await _ensureSpiTable(db);
    await _ensureGciTable(db);
    await _ensureSafetyTransColumns(db);
    await _ensureCoachingTransColumns(db);
    await _ensureNotificationsTable(db);
    await _ensureSimperOfflineTable(db);
    await _ensurePermitOfflineTable(db);
    await _ensureOfflineQueues(db);
  }

  static Future<void> _ensureNotificationsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_t_notifications (
          id INTEGER PRIMARY KEY,
          title TEXT,
          message TEXT,
          url TEXT,
          notif_type TEXT,
          logo TEXT,
          category TEXT,
          sender_name TEXT,
          priority TEXT,
          payload TEXT,
          action_text TEXT,
          is_read INTEGER DEFAULT 0,
          is_actioned INTEGER DEFAULT 0,
          is_action_required INTEGER DEFAULT 0,
          created_at TEXT
        );
      ''');
    } catch (_) {}
  }

  Future<List<NotificationItemModel>> getLocalNotifications({int months = 3}) async {
    final db = await database;
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: months * 30));
      final cutoff = cutoffDate.toIso8601String().substring(0, 10); // 'YYYY-MM-DD'
      final rows = await db.rawQuery(
        'SELECT * FROM tbl_t_notifications '
        'WHERE (created_at IS NULL OR created_at = \'\' OR substr(created_at, 1, 10) >= ? OR replace(created_at, \'T\', \' \') >= ?) '
        'ORDER BY id DESC',
        [cutoff, cutoff],
      );
      return rows.map((r) => NotificationItemModel.fromSqlite(r)).toList();
    } catch (e) {
      debugPrint('[DatabaseService] Error getLocalNotifications: \$e');
      return [];
    }
  }

  Future<int> getOfflineUnreadNotificationCount({int months = 3}) async {
    final db = await database;
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: months * 30));
      final cutoff = cutoffDate.toIso8601String().substring(0, 10);
      final res = await db.rawQuery(
        'SELECT count(*) as cnt FROM tbl_t_notifications '
        'WHERE (created_at IS NULL OR created_at = \'\' OR substr(created_at, 1, 10) >= ? OR replace(created_at, \'T\', \' \') >= ?) '
        'AND is_read = 0 AND is_actioned = 0 '
        'AND notif_type NOT LIKE \'%completed%\' '
        'AND notif_type NOT LIKE \'%closed%\'',
        [cutoff, cutoff],
      );
      if (res.isNotEmpty && res.first['cnt'] != null) {
        return (res.first['cnt'] as num).toInt();
      }
    } catch (e) {
      debugPrint('[DatabaseService] Error getOfflineUnreadNotificationCount: \$e');
    }
    return 0;
  }

  Future<void> markAllLocalNotificationsRead() async {
    final db = await database;
    try {
      await db.update(
        'tbl_t_notifications',
        {'is_read': 1},
      );
    } catch (_) {}
  }

  Future<int> getMaxNotificationId() async {
    final db = await database;
    try {
      final res = await db.rawQuery('SELECT MAX(id) as max_id FROM tbl_t_notifications');
      if (res.isNotEmpty && res.first['max_id'] != null) {
        return (res.first['max_id'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> saveLocalNotifications(List<NotificationItemModel> items) async {
    if (items.isEmpty) return;
    final db = await database;
    try {
      final batch = db.batch();
      for (var item in items) {
        batch.insert(
          'tbl_t_notifications',
          item.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[DatabaseService] Error saveLocalNotifications: \$e');
    }
  }

  Future<void> purgeOldNotifications({int months = 3}) async {
    final db = await database;
    try {
      final cutoff = DateTime.now().subtract(Duration(days: months * 30)).toIso8601String();
      await db.delete(
        'tbl_t_notifications',
        where: 'created_at < ?',
        whereArgs: [cutoff],
      );
    } catch (_) {}
  }

  static Future<void> _ensureSimperOfflineTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_m_simper_offline (
          id INTEGER PRIMARY KEY,
          nomor TEXT,
          employee_id TEXT,
          nama TEXT,
          perusahaan TEXT,
          departemen TEXT,
          jabatan TEXT,
          jenis_simper TEXT,
          jenis_sim TEXT,
          nomor_sim TEXT,
          masa_berlaku TEXT,
          expired_date TEXT,
          status TEXT,
          kacamata TEXT,
          qr_encrypt TEXT,
          qr_decrypt TEXT,
          days_left INTEGER,
          is_expired INTEGER,
          units_json TEXT,
          photo_url TEXT,
          updated_at TEXT
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_simper_qr_enc ON tbl_m_simper_offline(qr_encrypt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_simper_qr_dec ON tbl_m_simper_offline(qr_decrypt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_simper_nomor ON tbl_m_simper_offline(nomor);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_simper_emp ON tbl_m_simper_offline(employee_id);');
    } catch (e) {
      debugPrint('[DatabaseService] _ensureSimperOfflineTable error: $e');
    }
  }

  Future<int> saveOfflineSimpers(List<dynamic> items) async {
    if (items.isEmpty) return 0;
    final db = await database;
    int saved = 0;
    try {
      final nowStr = DateTime.now().toIso8601String();
      const batchSize = 500;
      for (var i = 0; i < items.length; i += batchSize) {
        final end = (i + batchSize < items.length) ? i + batchSize : items.length;
        final chunk = items.sublist(i, end);
        final batch = db.batch();
        for (var item in chunk) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final id = m['id'];
            if (id == null) continue;

            String unitsJson = '';
            if (m['units_json'] != null && m['units_json'].toString().isNotEmpty) {
              unitsJson = m['units_json'].toString();
            } else if (m['units'] is List) {
              unitsJson = jsonEncode(m['units']);
            }

            final row = <String, dynamic>{
              'id': id is num ? id.toInt() : int.tryParse(id.toString()) ?? 0,
              'nomor': m['nomor']?.toString(),
              'employee_id': m['employee_id']?.toString(),
              'nama': m['nama']?.toString(),
              'perusahaan': m['perusahaan']?.toString(),
              'departemen': m['departemen']?.toString(),
              'jabatan': m['jabatan']?.toString(),
              'jenis_simper': m['jenis_simper']?.toString(),
              'jenis_sim': m['jenis_sim']?.toString(),
              'nomor_sim': m['nomor_sim']?.toString(),
              'masa_berlaku': m['masa_berlaku']?.toString(),
              'expired_date': m['expired_date']?.toString(),
              'status': m['status']?.toString() ?? 'PRINTED',
              'kacamata': m['kacamata']?.toString(),
              'qr_encrypt': m['qr_encrypt']?.toString(),
              'qr_decrypt': m['qr_decrypt']?.toString(),
              'days_left': m['days_left'] is num ? (m['days_left'] as num).toInt() : int.tryParse(m['days_left']?.toString() ?? '0') ?? 0,
              'is_expired': (m['is_expired'] == true || m['is_expired'] == 1) ? 1 : 0,
              'units_json': unitsJson,
              'photo_url': m['photo_url']?.toString(),
              'updated_at': nowStr,
            };

            batch.insert(
              'tbl_m_simper_offline',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            saved++;
          }
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('[DatabaseService] Error saveOfflineSimpers: $e');
    }
    return saved;
  }

  Future<int> getOfflineSimperCount() async {
    final db = await database;
    try {
      final res = await db.rawQuery('SELECT count(*) as cnt FROM tbl_m_simper_offline');
      if (res.isNotEmpty && res.first['cnt'] != null) {
        return (res.first['cnt'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<Map<String, dynamic>?> getOfflineSimperByQr(String rawCode) async {
    final rawTrim = rawCode.trim();
    if (rawTrim.isEmpty) return null;
    var clean = rawTrim;

    if (clean.contains('/') && !clean.contains('/QrAttendance/Scan/')) {
      final segs = clean.split('/').where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) {
        var last = segs.last.trim();
        if (last.contains('?')) last = last.substring(0, last.indexOf('?')).trim();
        if (last.isNotEmpty) clean = last;
      }
    }
    if (clean.contains(':')) clean = clean.split(':').last.trim();
    if (clean.contains('|')) clean = clean.split('|').last.trim();
    if (clean.toUpperCase().startsWith('IC')) clean = clean.substring(2).trim();

    final cleanNoZero = clean.replaceFirst(RegExp(r'^0+'), '');

    final db = await database;
    try {
      final rows = await db.rawQuery(
        'SELECT * FROM tbl_m_simper_offline '
        'WHERE qr_encrypt = ? '
        '   OR qr_decrypt = ? '
        '   OR qr_encrypt = ? '
        '   OR qr_decrypt = ? '
        '   OR nomor = ? '
        '   OR nomor = ? '
        '   OR employee_id = ? '
        '   OR (? != \'\' AND (employee_id = ? OR ltrim(employee_id, \'0\') = ?)) '
        'ORDER BY id DESC LIMIT 1',
        [rawTrim, rawTrim, clean, clean, rawTrim, clean, clean, cleanNoZero, cleanNoZero, cleanNoZero],
      );

      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first);

        List<Map<String, dynamic>> units = [];
        final unitsStr = row['units_json']?.toString() ?? '';
        if (unitsStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(unitsStr);
            if (decoded is List) {
              units = decoded.map((u) => u is Map ? Map<String, dynamic>.from(u) : <String, dynamic>{}).toList();
            }
          } catch (_) {}
        }

        final masaBerlakuStr = row['masa_berlaku']?.toString() ?? row['expired_date']?.toString() ?? '';
        int daysLeft = 999;
        bool isExpired = false;
        if (masaBerlakuStr.isNotEmpty && masaBerlakuStr != '-') {
          try {
            DateTime? expDate;
            if (masaBerlakuStr.contains('-')) {
              final parts = masaBerlakuStr.split('-');
              if (parts.length == 3) {
                if (parts[0].length == 4) {
                  expDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                } else {
                  expDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                }
              }
            } else if (masaBerlakuStr.contains('/')) {
              final parts = masaBerlakuStr.split('/');
              if (parts.length == 3) {
                expDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            }
            if (expDate != null) {
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              daysLeft = expDate.difference(todayDate).inDays;
              isExpired = daysLeft < 0;
            }
          } catch (_) {}
        }

        final empNik = row['employee_id']?.toString() ?? clean;
        final photoUrl = (row['photo_url']?.toString().isNotEmpty == true)
            ? row['photo_url'].toString()
            : '/api/qr/permit/photo/$empNik';

        final result = <String, dynamic>{
          'id': row['id'],
          'nomor': row['nomor'],
          'employee_id': empNik,
          'nik': empNik,
          'nama': row['nama'] ?? 'Karyawan Tambang',
          'perusahaan': row['perusahaan'] ?? 'PT INDEXIM COALINDO',
          'departemen': row['departemen'] ?? '-',
          'jabatan': row['jabatan'] ?? '-',
          'posisi': row['jabatan'] ?? '-',
          'jenis_simper': row['jenis_simper'] ?? '-',
          'jenis_sim': row['jenis_sim'] ?? '-',
          'nomor_sim': row['nomor_sim'] ?? '-',
          'masa_berlaku': row['masa_berlaku'] ?? masaBerlakuStr,
          'expired_date': row['expired_date'] ?? masaBerlakuStr,
          'simper_masa_berlaku': row['masa_berlaku'] ?? masaBerlakuStr,
          'status': row['status'] ?? 'PRINTED',
          'kacamata': row['kacamata'] ?? 'TIDAK',
          'qr_encrypt': row['qr_encrypt'],
          'qr_decrypt': row['qr_decrypt'],
          'days_left': daysLeft,
          'simper_days_left': daysLeft,
          'is_expired': isExpired,
          'simper_is_expired': isExpired,
          'has_simper': true,
          'is_simper_active': !isExpired,
          'is_offline_verified': true,
          'units': units,
          'simper_units': units,
          'photo_url': photoUrl,
          'foto': photoUrl,
        };

        return result;
      }
    } catch (e) {
      debugPrint('[DatabaseService] Error getOfflineSimperByQr: $e');
    }
    return null;
  }

  static Future<void> _ensurePermitOfflineTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_m_permit_offline (
          id INTEGER PRIMARY KEY,
          nomor TEXT,
          nik TEXT,
          qr_code TEXT,
          nama TEXT,
          perusahaan TEXT,
          departemen TEXT,
          jabatan TEXT,
          posisi TEXT,
          status TEXT,
          akses_lokasi TEXT,
          mulai_kerja TEXT,
          berakhir_kerja TEXT,
          last_expired TEXT,
          masa_aktif_permit TEXT,
          days_left INTEGER,
          is_expired INTEGER,
          photo_url TEXT,
          updated_at TEXT
        );
      ''');
      try {
        await db.execute('ALTER TABLE tbl_m_permit_offline ADD COLUMN qr_code TEXT;');
      } catch (_) {}
      await db.execute('CREATE INDEX IF NOT EXISTS idx_permit_qr ON tbl_m_permit_offline(qr_code);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_permit_nik ON tbl_m_permit_offline(nik);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_permit_nomor ON tbl_m_permit_offline(nomor);');
    } catch (e) {
      debugPrint('[DatabaseService] _ensurePermitOfflineTable error: $e');
    }
  }

  static Future<void> _ensureOfflineQueues(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_t_offline_movements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT,
          created_at TEXT,
          is_synced INTEGER DEFAULT 0
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_t_offline_violations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT,
          created_at TEXT,
          is_synced INTEGER DEFAULT 0
        );
      ''');
    } catch (e) {
      debugPrint('[DatabaseService] _ensureOfflineQueues error: $e');
    }
  }

  Future<int> saveOfflinePermits(List<dynamic> items) async {
    if (items.isEmpty) return 0;
    final db = await database;
    int saved = 0;
    try {
      final nowStr = DateTime.now().toIso8601String();
      const batchSize = 500;
      for (var i = 0; i < items.length; i += batchSize) {
        final end = (i + batchSize < items.length) ? i + batchSize : items.length;
        final chunk = items.sublist(i, end);
        final batch = db.batch();
        for (var item in chunk) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final id = m['id'];
            final nik = m['nik']?.toString().trim();
            if (id == null || nik == null || nik.isEmpty) continue;

            final row = <String, dynamic>{
              'id': id is num ? id.toInt() : int.tryParse(id.toString()) ?? 0,
              'nomor': m['nomor']?.toString(),
              'nik': nik,
              'qr_code': m['qr_code']?.toString() ?? m['qrCode']?.toString() ?? '',
              'nama': m['nama']?.toString(),
              'perusahaan': m['perusahaan']?.toString(),
              'departemen': m['departemen']?.toString(),
              'jabatan': m['jabatan']?.toString(),
              'posisi': m['posisi']?.toString(),
              'status': m['status']?.toString() ?? 'PRINTED',
              'akses_lokasi': m['akses_lokasi']?.toString(),
              'mulai_kerja': m['mulai_kerja']?.toString(),
              'berakhir_kerja': m['berakhir_kerja']?.toString(),
              'last_expired': m['last_expired']?.toString(),
              'masa_aktif_permit': m['masa_aktif_permit']?.toString() ?? m['berakhir_kerja']?.toString() ?? m['last_expired']?.toString(),
              'days_left': m['days_left'] is num ? (m['days_left'] as num).toInt() : int.tryParse(m['days_left']?.toString() ?? '0') ?? 0,
              'is_expired': (m['is_expired'] == true || m['is_expired'] == 1) ? 1 : 0,
              'photo_url': m['photo_url']?.toString(),
              'updated_at': nowStr,
            };

            batch.insert(
              'tbl_m_permit_offline',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            saved++;
          }
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('[DatabaseService] Error saveOfflinePermits: $e');
    }
    return saved;
  }

  Future<int> getOfflinePermitCount() async {
    final db = await database;
    try {
      final res = await db.rawQuery('SELECT count(*) as cnt FROM tbl_m_permit_offline');
      if (res.isNotEmpty && res.first['cnt'] != null) {
        return (res.first['cnt'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  Future<Map<String, dynamic>?> getOfflinePermitByQr(String rawCode) async {
    var clean = rawCode.trim();
    if (clean.isEmpty) return null;

    if (clean.contains('/') && !clean.contains('/QrAttendance/Scan/')) {
      final segs = clean.split('/').where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) {
        var last = segs.last.trim();
        if (last.contains('?')) last = last.substring(0, last.indexOf('?')).trim();
        if (last.isNotEmpty) clean = last;
      }
    }
    if (clean.contains(':')) clean = clean.split(':').last.trim();
    if (clean.contains('|')) clean = clean.split('|').last.trim();
    if (clean.toUpperCase().startsWith('IC')) clean = clean.substring(2).trim();

    final cleanNoZero = clean.replaceFirst(RegExp(r'^0+'), '');

    final db = await database;
    try {
      final rawTrim = rawCode.trim();
      final rows = await db.rawQuery(
        'SELECT * FROM tbl_m_permit_offline '
        'WHERE qr_code = ? '
        '   OR qr_code = ? '
        '   OR nik = ? '
        '   OR nomor = ? '
        '   OR nomor = ? '
        '   OR (? != \'\' AND (nik = ? OR ltrim(nik, \'0\') = ?)) '
        'ORDER BY id DESC LIMIT 1',
        [rawTrim, clean, clean, rawTrim, clean, cleanNoZero, cleanNoZero, cleanNoZero],
      );

      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first);
        final nikVal = row['nik']?.toString() ?? clean;

        final expStr = row['masa_aktif_permit']?.toString() ?? row['berakhir_kerja']?.toString() ?? row['last_expired']?.toString() ?? '';
        int daysLeft = 999;
        bool isExpired = false;
        if (expStr.isNotEmpty && expStr != '-') {
          try {
            DateTime? expDate;
            if (expStr.contains('-')) {
              final parts = expStr.split('-');
              if (parts.length == 3) {
                if (parts[0].length == 4) {
                  expDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                } else {
                  expDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                }
              }
            } else if (expStr.contains('/')) {
              final parts = expStr.split('/');
              if (parts.length == 3) {
                expDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            }
            if (expDate != null) {
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              daysLeft = expDate.difference(todayDate).inDays;
              isExpired = daysLeft < 0;
            }
          } catch (_) {}
        }

        Map<String, dynamic>? offlineSimper;
        try {
          offlineSimper = await getOfflineSimperByQr(nikVal);
        } catch (_) {}

        final photoUrl = (row['photo_url']?.toString().isNotEmpty == true)
            ? row['photo_url'].toString()
            : '/api/qr/permit/photo/$nikVal';

        final result = <String, dynamic>{
          'id': row['id'],
          'nomor': row['nomor'],
          'nik': nikVal,
          'employee_id': nikVal,
          'nama': row['nama'] ?? 'Karyawan Tambang',
          'perusahaan': row['perusahaan'] ?? 'PT INDEXIM COALINDO',
          'departemen': row['departemen'] ?? '-',
          'jabatan': row['jabatan'] ?? '-',
          'posisi': row['posisi'] ?? row['jabatan'] ?? '-',
          'status': row['status'] ?? 'PRINTED',
          'akses_lokasi': row['akses_lokasi'] ?? '',
          'mulai_kerja': row['mulai_kerja'] ?? '-',
          'berakhir_kerja': row['berakhir_kerja'] ?? expStr,
          'last_expired': row['last_expired'] ?? expStr,
          'masa_aktif_permit': expStr,
          'days_left': daysLeft,
          'is_expired': isExpired,
          'photo_url': photoUrl,
          'foto': photoUrl,
          'is_offline_verified': true,
          'has_simper': offlineSimper != null,
          'simper_nomor': offlineSimper?['nomor'] ?? '-',
          'jenis_simper': offlineSimper?['jenis_simper'] ?? '-',
          'jenis_sim': offlineSimper?['jenis_sim'] ?? '-',
          'nomor_sim': offlineSimper?['nomor_sim'] ?? '-',
          'simper_masa_berlaku': offlineSimper?['masa_berlaku'] ?? '-',
          'is_simper_active': offlineSimper?['is_simper_active'] ?? false,
          'simper_days_left': offlineSimper?['days_left'],
          'simper_is_expired': offlineSimper?['is_expired'] ?? false,
          'simper_units': offlineSimper?['units'] ?? [],
          'can_input_pelanggaran': true,
          'can_input_keluar_masuk': true,
        };

        return result;
      }
    } catch (e) {
      debugPrint('[DatabaseService] Error getOfflinePermitByQr: $e');
    }
    return null;
  }

  Future<int> queueOfflineMovement(Map<String, dynamic> payload) async {
    final db = await database;
    try {
      return await db.insert('tbl_t_offline_movements', {
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });
    } catch (e) {
      debugPrint('[DatabaseService] queueOfflineMovement error: $e');
      return 0;
    }
  }

  Future<int> queueOfflineViolation(Map<String, dynamic> payload) async {
    final db = await database;
    try {
      return await db.insert('tbl_t_offline_violations', {
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });
    } catch (e) {
      debugPrint('[DatabaseService] queueOfflineViolation error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineMovements() async {
    final db = await database;
    try {
      final rows = await db.query(
        'tbl_t_offline_movements',
        where: 'is_synced = 0',
        orderBy: 'id ASC',
      );
      return rows;
    } catch (e) {
      debugPrint('[DatabaseService] getPendingOfflineMovements error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineViolations() async {
    final db = await database;
    try {
      final rows = await db.query(
        'tbl_t_offline_violations',
        where: 'is_synced = 0',
        orderBy: 'id ASC',
      );
      return rows;
    } catch (e) {
      debugPrint('[DatabaseService] getPendingOfflineViolations error: $e');
      return [];
    }
  }

  Future<int> deleteOfflineMovement(int id) async {
    final db = await database;
    try {
      return await db.delete('tbl_t_offline_movements', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      return 0;
    }
  }

  Future<int> deleteOfflineViolation(int id) async {
    final db = await database;
    try {
      return await db.delete('tbl_t_offline_violations', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      return 0;
    }
  }

  Future<int> getPendingOfflineQueueCount() async {
    final db = await database;
    int count = 0;
    try {
      final m = await db.rawQuery('SELECT count(*) as cnt FROM tbl_t_offline_movements WHERE is_synced = 0');
      if (m.isNotEmpty && m.first['cnt'] != null) count += (m.first['cnt'] as num).toInt();
      final v = await db.rawQuery('SELECT count(*) as cnt FROM tbl_t_offline_violations WHERE is_synced = 0');
      if (v.isNotEmpty && v.first['cnt'] != null) count += (v.first['cnt'] as num).toInt();
    } catch (_) {}
    return count;
  }

  Future<void> updateLocalNotificationRead(int id, bool isRead) async {
    final db = await database;
    try {
      await db.update(
        'tbl_t_notifications',
        {'is_read': isRead ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  Future<void> updateLocalNotificationActioned(int id, bool isActioned) async {
    final db = await database;
    try {
      await db.update(
        'tbl_t_notifications',
        {'is_actioned': isActioned ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  static Future<void> _ensureSpiTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_t_spi_report (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          tanggal TEXT,
          waktu TEXT,
          nik TEXT,
          nama TEXT,
          departemen TEXT,
          perusahaan TEXT,
          perusahaan_id INTEGER,
          area TEXT,
          lokasi TEXT,
          detil_lokasi TEXT,
          nama_kolam TEXT,
          titik_penaatan TEXT,
          shift TEXT,
          latitude TEXT,
          longitude TEXT,
          skor_kapasitas_endapan INTEGER,
          skor_kondisi_tanggul INTEGER,
          skor_sekat_baffle INTEGER,
          skor_pelimpah_spillway INTEGER,
          skor_fasilitas_dosing INTEGER,
          skor_kualitas_air_fisik INTEGER,
          skor_titik_penaatan_debit INTEGER,
          skor_rambu_pengaman INTEGER,
          total_score REAL,
          kategori_index TEXT,
          catatan TEXT,
          tindakan_perbaikan TEXT,
          pic TEXT,
          foto_url TEXT,
          created_at TEXT
        );
      ''');
    } catch (_) {}
  }

  static Future<void> _ensureGciTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_t_gci_report (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          tanggal TEXT,
          waktu TEXT,
          nik TEXT,
          nama TEXT,
          departemen TEXT,
          perusahaan TEXT,
          perusahaan_id INTEGER,
          area TEXT,
          lokasi TEXT,
          detil_lokasi TEXT,
          pit TEXT,
          nama_lereng TEXT,
          area_type TEXT,
          shift TEXT,
          latitude TEXT,
          longitude TEXT,
          skor_geometri_lereng INTEGER,
          skor_kondisi_crest_toe INTEGER,
          skor_tension_crack INTEGER,
          skor_kestabilan_batuan INTEGER,
          skor_rembesan_drainase INTEGER,
          skor_pemantauan_sensor INTEGER,
          skor_demarkasi_zona INTEGER,
          skor_kepatuhan_rekomendasi INTEGER,
          total_score REAL,
          kategori_index TEXT,
          tarp_level TEXT,
          catatan TEXT,
          tindakan_perbaikan TEXT,
          pic TEXT,
          pic_nik TEXT,
          judul_temuan TEXT,
          due_date TEXT,
          foto_url TEXT,
          jenis_inspeksi TEXT,
          pja_nama TEXT,
          pja_nik TEXT,
          created_at TEXT
        );
      ''');
    } catch (_) {}
  }

  static Future<void> _ensureDciTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_t_dci_report (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          tanggal TEXT,
          waktu TEXT,
          nik TEXT,
          nama TEXT,
          departemen TEXT,
          perusahaan TEXT,
          perusahaan_id INTEGER,
          area TEXT,
          lokasi TEXT,
          detil_lokasi TEXT,
          disposal TEXT,
          nama_dump TEXT,
          pad TEXT,
          shift TEXT,
          latitude TEXT,
          longitude TEXT,
          skor_lantai_dump INTEGER,
          skor_safety_berm INTEGER,
          skor_kondisi_crest INTEGER,
          skor_grade_dumping INTEGER,
          skor_drainase_dump INTEGER,
          skor_penataan_spillage INTEGER,
          skor_rambu_penerangan INTEGER,
          skor_spotter_manuver INTEGER,
          total_score REAL,
          kategori_index TEXT,
          catatan TEXT,
          tindakan_perbaikan TEXT,
          pic TEXT,
          foto_url TEXT,
          created_at TEXT
        );
      ''');
      try {
        await db.execute('ALTER TABLE tbl_t_dci_report ADD COLUMN pad TEXT;');
      } catch (_) {}
    } catch (_) {}
  }

  static Future<void> _ensureP5mTransColumns(Database db) async {
    final cols = [
      'area',
      'lokasi',
      'topik',
      'judul',
      'catatan',
      'foto_kegiatan',
      'questions_json',
      'answers_json',
      'fit_status',
      'nik',
      'nama',
    ];
    for (var col in cols) {
      try {
        await db.execute('ALTER TABLE p5m_trans ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }
  }

  static Future<void> _ensureSafetyTransColumns(Database db) async {
    final cols = [
      'area',
      'lokasi',
      'detil_lokasi',
      'judul',
      'keterangan',
      'self_image',
      'event_image',
      'foto_diri',
      'foto_kegiatan',
      'nik',
      'nama',
    ];
    for (var col in cols) {
      try {
        await db.execute('ALTER TABLE safety_trans ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }
  }

  static Future<void> _ensureCoachingTransColumns(Database db) async {
    final cols = [
      'area',
      'lokasi',
      'detil_lokasi',
      'tema',
      'komitmen',
      'feedback',
      'participants_json',
      'nik',
      'nama',
      'foto',
    ];
    for (var col in cols) {
      try {
        await db.execute('ALTER TABLE coaching_trans ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }

    final detailCols = [
      'no_nik',
      'nik',
      'nama_lengkap',
      'posisi',
      'departemen',
      'perusahaan',
    ];
    for (var col in detailCols) {
      try {
        await db.execute('ALTER TABLE coaching_details ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }
  }

  static Future<void> _ensureP2hTransColumns(Database db) async {
    final cols = [
      'jenis_kendaraan',
      'simper_kimper',
      'foto_speedometer',
      'gol_a_json',
      'gol_b_json',
      'gol_c_json',
      'nik',
      'nama',
    ];
    for (var col in cols) {
      try {
        await db.execute('ALTER TABLE p2h_trans ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS p2h_vehicles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          no_lambung TEXT,
          jenis_kendaraan TEXT,
          merek TEXT,
          last_km REAL DEFAULT 0
        );
      ''');
      try {
        await db.execute('ALTER TABLE p2h_vehicles ADD COLUMN last_km REAL DEFAULT 0;');
      } catch (_) {}
      await db.execute('CREATE INDEX IF NOT EXISTS idx_p2h_veh_nl ON p2h_vehicles (no_lambung);');
    } catch (_) {}
  }

  static Future<void> _ensureInspectionTransColumns(Database db) async {
    final cols = [
      'nik',
      'nama',
      'area',
      'lokasi',
      'jenis_inspeksi',
      'pja',
      'nik_pja',
      'departemen_pja',
      'payload_json',
      'q1_1',
      'q1_2',
      'q1_3',
      'q2_1',
      'q2_2',
      'q2_3',
      'q3_1',
      'q3_2',
      'q3_3',
      'q4_1',
      'q4_2',
      'q4_3',
      'q5_1',
      'q5_2',
      'q5_3',
    ];
    for (var col in cols) {
      try {
        await db
            .execute('ALTER TABLE inspection_trans ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }
  }

  static Future<void> _ensureObservationTransColumns(Database db) async {
    for (final col in [
      'area',
      'lokasi',
      'company_name',
      'dept_name',
      'doc_name',
      'risk_name',
      'risk_level'
    ]) {
      try {
        await db
            .execute('ALTER TABLE observation_trans ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }
  }

  static Future<void> _ensureEmployeeColumns(Database db) async {
    final cols = ['departemen', 'jabatan', 'perusahaan', 'company_id', 'foto'];
    for (var col in cols) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }
    try {
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_emp_nik ON employees (no_nik);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_emp_nama ON employees (nama_lengkap);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_emp_company ON employees (perusahaan);');
    } catch (_) {}
  }

  static Future<void> _ensureBenchmarkTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tbl_m_benchmark (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          perusahaan_id INTEGER,
          area_utama TEXT,
          nama_benchmark TEXT,
          created_by_nik TEXT,
          created_by_name TEXT,
          created_at TEXT
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_bm_area ON tbl_m_benchmark (area_utama);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_bm_name ON tbl_m_benchmark (nama_benchmark);');
      // Bersihkan entri invalid CAMP EKSPLORASI dari area_utama
      await db.execute(
          "DELETE FROM tbl_m_benchmark WHERE area_utama LIKE '%CAMP EKSPLORASI%' OR nama_benchmark = 'CAMP EKSPLORASI BLOCK CENTRAL';");

      // Pastikan kolom nik, departemen, jabatan, perusahaan ada di tabel employees
      for (var col in ['nik', 'departemen', 'jabatan', 'perusahaan']) {
        try {
          await db.execute('ALTER TABLE employees ADD COLUMN `$col` TEXT;');
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<void> _ensureHazardTransColumns(Database db) async {
    final cols = [
      'area',
      'lokasi',
      'kategori_bahaya',
      'jenis_bahaya',
      'jenis_ketidaksesuaian',
      'tingkat_resiko',
      'tindakan_perbaikan',
      'pja',
      'nik_pja',
      'departemen_pja',
      'payload_json',
    ];
    for (var col in cols) {
      try {
        await db.execute('ALTER TABLE hazard_trans ADD COLUMN `$col` TEXT;');
      } catch (_) {}
    }
  }

  Future<void> _createOfflineSyncJobsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS offline_sync_jobs (
      `id` TEXT PRIMARY KEY,
      `feature` TEXT NOT NULL,
      `local_id` TEXT NOT NULL,
      `payload` TEXT NOT NULL,
      `created_at` TEXT NOT NULL
    );
  ''');

  /// Hapus total database SQLite lokal (isafe18.db) untuk persiapan sinkronisasi ulang
  Future<void> clearDatabase() async {
    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
      }
      _database = null;
      var dbPath = await getDatabasesPath();
      var path = join(dbPath, 'isafe18.db');
      await deleteDatabase(path);
      debugPrint(
          '[DatabaseService] Database lokal SQLite isafe18.db berhasil dihapus.');
    } catch (e) {
      debugPrint('[DatabaseService] Error menghapus database lokal: $e');
    }
  }

  _onCreate(Database db, int intVersion) async {
    /* master */
    await db.execute('''
		CREATE TABLE enum_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE enum_bridges (
			`id` INTEGER PRIMARY KEY,
			`flag` TEXT,
			`primary_id` INTEGER,
			`secondary_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE inspection_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`categories` TEXT,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE hazard_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE coaching_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE k3_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE observation_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p2h_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p5m_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE safety_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE vehicle_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`ellipse_code` TEXT,
			`unit` TEXT,
			`brand` TEXT,
			`company` TEXT,
			`chassis_no` TEXT,
			`engine_no` TEXT,
			`cn_type` TEXT,
			`license_plate` TEXT,
			`year` INTEGER,
			`remark` TEXT,
			`employee_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE employees (
			`id` INTEGER PRIMARY KEY,
			`no_nik` TEXT,
			`nama_lengkap` TEXT,
			`nama_alias` TEXT,
			`tmp_lahir` TEXT,
			`tgl_lahir` TEXT,
			`email_pribadi` TEXT,
			`email_kantor` TEXT,
			`hp` TEXT,
			`depart` TEXT,
			`section` TEXT,
			`posisi` TEXT,
			`foto` TEXT,
			`user_id` INTEGER,
			`company_id` INTEGER,
			`departemen` TEXT,
			`jabatan` TEXT,
			`perusahaan` TEXT,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    /* transaction */
    await db.execute('''
		CREATE TABLE inspection_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`inspection_id` INTEGER,
			`shift_id` INTEGER,
			`danger_level` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`category` TEXT,
			`inspektor1_id` INTEGER,
			`inspektor2_id` INTEGER,
			`inspektor3_id` INTEGER,
			`inspektor4_id` INTEGER,
			`inspektor5_id` INTEGER,
			`pja_id` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE hazard_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`hazard_id` INTEGER,
			`hazard_type_id` INTEGER,
			`hazard_subtype_id` INTEGER,
			`hazard_danger_id` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`repair` INTEGER,
			`repair_remark` TEXT,
			`repair_image` TEXT,
			`repair_video` TEXT,
			`repair_date` TEXT,
			`repair_time` TEXT,
			`pja_id` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE coaching_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`trainer_id` INTEGER,
			`tema_id` INTEGER,
			`purpose` TEXT,
			`feedback` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE k3_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`inductor_id` INTEGER,
			`nik` TEXT,
			`birth_place` TEXT,
			`birth_date` TEXT,
			`hire_date` TEXT,
			`depart` TEXT,
			`section` TEXT,
			`jabatan` TEXT,
			`level` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`inductor_sign` TEXT,
			`employee_sign` TEXT,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE observation_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`dept_id` INTEGER,
			`doc_id` INTEGER,
			`risk_id` INTEGER,
			`subject` TEXT,
			`activity` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p2h_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`vehicle_id` INTEGER,
			`hm` REAL,
			`km` REAL,
			`no_lambung` TEXT,
			`merek` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`simper` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p5m_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`topic_id` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE safety_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`topic_id` INTEGER,
			`self_image` TEXT,
			`event_image` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    /* detail */
    await db.execute('''
		CREATE TABLE inspection_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`repair` INTEGER,
			`repair_remark` TEXT,
			`repair_image` TEXT,
			`repair_video` TEXT,
			`location_id` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE coaching_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE k3_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE observation_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`point` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p2h_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p5m_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE safety_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    /* action */
    await db.execute('''
		CREATE TABLE action_plans (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`pja_id` INTEGER,
			`pic_id` INTEGER,
			`plan` TEXT,
			`plan_date` TEXT,
			`overdue` INTEGER,
			`reason` TEXT,
			`action` TEXT,
			`action_date` TEXT,
			`action_image` TEXT,
			`action_video` TEXT,
			`table` TEXT,
			`category` TEXT,
			`tran_id` INTEGER,
			`detail_id` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE files (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`table` TEXT,
			`category` TEXT,
			`point_id` INTEGER,
			`sync_id` INTEGER,
			`tran_id` INTEGER,
			`detail_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await _createOfflineSyncJobsTable(db);
  }

  Future close() async {
    _database = null;

    final db = await database;
    return db.close();
  }

  Future<List<Map>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  Future<List<dynamic>> gets(table, where, order) async {
    final db = await database;
    try {
      if (table == null || where == null || order == null) return [];
      return await db
          .rawQuery("SELECT * FROM $table WHERE $where ORDER BY $order");
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  Future<dynamic> get(table, int id) async {
    final db = await database;
    try {
      if (table == null) return null;
      final result = await db.query(table, where: 'id=?', whereArgs: [id]);
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  Future<int> insert(table, Map<String, dynamic> vals) async {
    final db = await database;
    try {
      return await db.insert(table, vals,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint(e.toString());
      return 0;
    }
  }

  Future<int> update(table, Map<String, dynamic> vals, int id) async {
    final db = await database;
    try {
      return await db.update(table, vals, where: 'id=?', whereArgs: [id]);
    } catch (e) {
      debugPrint(e.toString());
      return 0;
    }
  }

  Future<int> delete(table, int id) async {
    final db = await database;
    try {
      return await db.delete(table, where: 'id=?', whereArgs: [id]);
    } catch (e) {
      debugPrint(e.toString());
      return 0;
    }
  }

  Future<void> execute(String sql) async {
    final db = await database;
    try {
      return await db.execute(sql);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> saveFiles(String type, int point, int tran, int detail) async {
    final db = await database;
    try {
      return await db
          .execute('''update files set tran_id=$tran, detail_id=$detail
          where type='$type' and point_id=$point and tran_id is null and detail_id is null''');
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> dropFiles(String type) async {
    final db = await database;
    try {
      return await db.execute('''delete from files
          where type='$type' and point_id is not null and tran_id is null and detail_id is null''');
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
