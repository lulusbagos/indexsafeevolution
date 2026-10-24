import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'database.dart';
import 'notification.dart';
import 'preference.dart';
import 'sync.dart';
import '../pages/bbs/bbs_model.dart';

/// Persistent outbox used by features whose server endpoint is not connected yet.
class OfflineSyncJob {
  const OfflineSyncJob({
    required this.id,
    required this.feature,
    required this.localId,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String feature;
  final String localId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'feature': feature,
        'localId': localId,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineSyncJob.fromJson(Map<String, dynamic> json) => OfflineSyncJob(
        id: '${json['id']}',
        feature: '${json['feature']}',
        localId: '${json['localId']}',
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse('${json['createdAt']}'),
      );
}

class OfflineSyncState {
  const OfflineSyncState({required this.isOnline, required this.pendingCount});
  final bool isOnline;
  final int pendingCount;
}

class PendingSyncItem {
  final int id;
  final String tableKey; // 'hazard', 'inspection', 'observation', 'safety', 'coaching', 'p5m', 'p2h'
  final String moduleTitle;
  final String title;
  final String date;
  final String time;
  final String location;
  final IconData icon;
  final Color color;
  final String? detailText;
  final String? imagePath;
  final Map<String, dynamic> rawData;

  PendingSyncItem({
    required this.id,
    required this.tableKey,
    required this.moduleTitle,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.icon,
    required this.color,
    this.detailText,
    this.imagePath,
    this.rawData = const {},
  });
}

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  factory OfflineSyncService() => instance;
  OfflineSyncService._internal();

  static const _legacyOutboxKey = 'offline_sync_outbox_v1';

  final DatabaseService _db = DatabaseService();
  final ApiService _api = ApiService();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isAutoSyncing = false;
  bool _isListenerStarted = false;
  bool _syncing = false;

  /// ValueNotifier state kompatibel dengan UI Client (TopBar, ActivityHubHeader, BBS, CI)
  final ValueNotifier<OfflineSyncState> state =
      ValueNotifier(const OfflineSyncState(isOnline: true, pendingCount: 0));

  /// Notifier untuk memberi tahu UI secara instan ketika ada data baru atau sinkronisasi selesai
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    await _migrateLegacyOutbox();
    final connectivity = await Connectivity().checkConnectivity();
    await _setConnection(connectivity);
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen(
          (results) => _setConnection(results),
        );
    initAutoSyncListener();
    await refresh();
  }

  Future<void> _setConnection(List<ConnectivityResult> results) async {
    final online = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);
    state.value = OfflineSyncState(
      isOnline: online,
      pendingCount: state.value.pendingCount,
    );
    await refresh();
    if (online) unawaited(syncNow());
  }

  Future<List<OfflineSyncJob>> _jobs() async {
    try {
      final rows = await _db.rawQuery(
          'select id, feature, local_id, payload, created_at from offline_sync_jobs order by created_at asc');
      return rows
          .map((row) => OfflineSyncJob(
                id: '${row['id']}',
                feature: '${row['feature']}',
                localId: '${row['local_id']}',
                payload: Map<String, dynamic>.from(
                    jsonDecode('${row['payload']}') as Map),
                createdAt: DateTime.parse('${row['created_at']}'),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> enqueue({
    required String feature,
    required String localId,
    required Map<String, dynamic> payload,
  }) async {
    final job = OfflineSyncJob(
      id: '$feature-$localId',
      feature: feature,
      localId: localId,
      payload: payload,
      createdAt: DateTime.now(),
    );
    try {
      final db = await _db.database;
      await db.insert('offline_sync_jobs', {
        'id': job.id,
        'feature': job.feature,
        'local_id': job.localId,
        'payload': jsonEncode(job.payload),
        'created_at': job.createdAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[OfflineSyncService] Error enqueue job: $e');
    }
    await refresh();
    if (state.value.isOnline) {
      unawaited(syncNow());
    }
  }

  Future<void> _migrateLegacyOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyOutboxKey);
    if (raw == null) return;
    try {
      final db = await _db.database;
      for (final data in jsonDecode(raw) as List) {
        final job =
            OfflineSyncJob.fromJson(Map<String, dynamic>.from(data as Map));
        await db.insert('offline_sync_jobs', {
          'id': job.id,
          'feature': job.feature,
          'local_id': job.localId,
          'payload': jsonEncode(job.payload),
          'created_at': job.createdAt.toIso8601String(),
        });
      }
      await prefs.remove(_legacyOutboxKey);
    } catch (_) {
      // Leave old data untouched if it cannot be read.
    }
  }

  Future<bool> isPending(String feature, String localId) async =>
      (await _jobs())
          .any((job) => job.feature == feature && job.localId == localId);

  Future<void> discard({required String feature, required String localId}) async {
    try {
      final db = await _db.database;
      await db.delete(
        'offline_sync_jobs',
        where: 'feature = ? and local_id = ?',
        whereArgs: [feature, localId],
      );
    } catch (e) {
      debugPrint('[OfflineSyncService] Error discard job: $e');
    }
    await refresh();
  }

  Future<({int success, int failed})> syncBbsPending() async {
    if (!state.value.isOnline) return (success: 0, failed: 0);
    var success = 0;
    var failed = 0;
    for (final job in await _jobs()) {
      if (job.feature != 'bbs') continue;
      final form = Map<String, dynamic>.from(job.payload['form'] as Map);
      final photoPath = job.payload['photoPath']?.toString();
      final sent = await _api.submitBbs(form, photoPath: photoPath);
      if (sent) {
        await discard(feature: job.feature, localId: job.localId);
        await BbsStorage.markSynced(job.localId);
        success++;
      } else {
        failed++;
      }
    }
    await refresh();
    return (success: success, failed: failed);
  }

  Future<({int success, int failed})> syncFciPending() async {
    if (!state.value.isOnline) return (success: 0, failed: 0);
    var success = 0;
    var failed = 0;
    for (final job in await _jobs()) {
      if (job.feature != 'fci') continue;
      try {
        final map = Map<String, dynamic>.from(job.payload['map'] as Map);
        final photoPath = job.payload['photoPath']?.toString();
        if (photoPath != null && await File(photoPath).exists()) {
          map['foto'] = await MultipartFile.fromFile(photoPath);
        }
        final formData = FormData.fromMap(map);
        final res = await _api.saveFciReport(formData);
        bool ok = false;
        res.fold((err) => ok = false, (succ) => ok = true);
        if (ok) {
          await discard(feature: job.feature, localId: job.localId);
          success++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }
    await refresh();
    return (success: success, failed: failed);
  }

  Future<({int success, int failed})> syncRciPending() async {
    if (!state.value.isOnline) return (success: 0, failed: 0);
    var success = 0;
    var failed = 0;
    for (final job in await _jobs()) {
      if (job.feature != 'rci') continue;
      try {
        final map = Map<String, dynamic>.from(job.payload['map'] as Map);
        final photoPath = job.payload['photoPath']?.toString();
        if (photoPath != null && await File(photoPath).exists()) {
          map['foto'] = await MultipartFile.fromFile(photoPath);
        }
        final formData = FormData.fromMap(map);
        final res = await _api.saveRciReport(formData);
        bool ok = false;
        res.fold((err) => ok = false, (succ) => ok = true);
        if (ok) {
          await discard(feature: job.feature, localId: job.localId);
          success++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }
    await refresh();
    return (success: success, failed: failed);
  }

  Future<void> refresh() async {
    int pending = (await _jobs()).length;
    for (final name in const [
      'inspection',
      'hazard',
      'coaching',
      'k3',
      'observation',
      'p2h',
      'p5m',
      'safety'
    ]) {
      try {
        final rows = await _db
            .rawQuery('select id from ${name}_trans where deleted_at is null and sync_id is null');
        pending += rows.length;
      } catch (_) {}
    }
    // Action plan yang masuk dari server lama dapat memiliki `updated_at`
    // kosong. Itu bukan berarti laporan baru dari perangkat ini, sehingga
    // jangan pernah memasukkannya ke badge sinkronisasi laporan.
    state.value =
        OfflineSyncState(isOnline: state.value.isOnline, pendingCount: pending);
    pendingCountNotifier.value = pending;
  }

  Future<void> syncNow() async {
    if (_syncing || !state.value.isOnline) {
      return;
    }
    _syncing = true;
    isSyncingNotifier.value = true;
    try {
      if (_api.getToken.isEmpty) {
        final auth = PreferenceService.getAuth();
        if (auth != null && auth.token != null && auth.token!.isNotEmpty) {
          _api.setToken = auth.token!;
        }
      }

      for (final name in const [
        'inspection',
        'hazard',
        'coaching',
        'k3',
        'observation',
        'p2h',
        'p5m',
        'safety'
      ]) {
        try {
          final rows = await _db
              .rawQuery('select id from ${name}_trans where deleted_at is null and sync_id is null');
          for (final row in rows) {
            await syncTran(_db, _api, name, row['id'] as int);
          }
        } catch (_) {}
      }

      await syncBbsPending();
      await syncFciPending();
      await syncRciPending();

    } finally {
      _syncing = false;
      isSyncingNotifier.value = false;
      await refresh();
    }
  }

  /// Inisialisasi listener deteksi koneksi jaringan untuk auto-sync
  void initAutoSyncListener() {
    if (_isListenerStarted) return;
    _isListenerStarted = true;

    // Load hitungan pending saat aplikasi dimulai
    refreshPendingCount();

    // Pengecekan otomatis saat startup (jika HP sudah online dan ada data tertinggal)
    Future.delayed(const Duration(seconds: 4), () async {
      try {
        final con = await Connectivity().checkConnectivity();
        final isOnline = con.any((r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn);
        if (isOnline) {
          final count = await getPendingCount();
          if (count > 0 && !_isAutoSyncing) {
            debugPrint('[OfflineSyncService] Startup online: $count data tertinggal. Menjalankan sinkron otomatis...');
            await autoSyncPending();
          }
        }
      } catch (e) {
        debugPrint('[OfflineSyncService] Startup check error: $e');
      }
    });
  }

  /// Sinkronisasi otomatis ke server di background ketika mendeteksi koneksi jaringan
  Future<({int success, int failed})> autoSyncPending({bool force = false}) async {
    if (_isAutoSyncing && !force) return (success: 0, failed: 0);
    _isAutoSyncing = true;
    isSyncingNotifier.value = true;

    try {
      if (_api.getToken.isEmpty || _api.getToken.startsWith('offline_token_')) {
        final auth = PreferenceService.getAuth();
        if (auth != null && auth.token != null && auth.token!.isNotEmpty && !auth.token!.startsWith('offline_token_')) {
          _api.setToken = auth.token!;
        } else {
          final bg = PreferenceService.getBgToken();
          if (bg != null && bg.isNotEmpty) {
            _api.setToken = bg;
          }
        }
      }

      final result = await syncAll();
      debugPrint('[OfflineSyncService] Auto-sync selesai: ${result.success} sukses, ${result.failed} gagal');

      if (result.success > 0) {
        try {
          NotificationService.display(
            title: 'Sinkronisasi Otomatis Berhasil',
            body: '${result.success} data laporan lokal berhasil terkirim ke server pusat saat online.',
            payload: '/pending_sync',
          );
        } catch (e) {
          debugPrint('[OfflineSyncService] Notification error: $e');
        }
      }

      await refreshPendingCount();
      return result;
    } finally {
      _isAutoSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  /// Memperbarui nilai pending count dan memberitahu UI listener
  Future<int> refreshPendingCount() async {
    await refresh();
    return pendingCountNotifier.value;
  }

  /// Mendapatkan daftar semua transaksi lokal yang belum disinkronkan ke server (sync_id is null)
  Future<List<PendingSyncItem>> getPendingItems() async {
    final List<PendingSyncItem> items = [];

    try {
      // 1. Hazard Report
      final hazards = await _db.rawQuery(
        'select * from hazard_trans where deleted_at is null and sync_id is null order by id desc',
      );
      for (var row in hazards) {
        items.add(PendingSyncItem(
          id: row['id'] as int,
          tableKey: 'hazard',
          moduleTitle: 'Hazard Report',
          title: (row['title'] != null && row['title'].toString().isNotEmpty)
              ? row['title'].toString()
              : (row['remark']?.toString() ?? 'Laporan Bahaya'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD97706),
          detailText: row['remark']?.toString(),
          imagePath: row['image']?.toString(),
          rawData: Map<String, dynamic>.from(row),
        ));
      }

      // 2. Inspection
      final inspections = await _db.rawQuery(
        'select * from inspection_trans where deleted_at is null and sync_id is null order by id desc',
      );
      for (var row in inspections) {
        items.add(PendingSyncItem(
          id: row['id'] as int,
          tableKey: 'inspection',
          moduleTitle: 'Inspeksi K3',
          title: (row['title'] != null && row['title'].toString().isNotEmpty)
              ? row['title'].toString()
              : (row['remark']?.toString() ?? 'Inspeksi Area'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.search_rounded,
          color: const Color(0xFF2563EB),
          detailText: row['remark']?.toString(),
          rawData: Map<String, dynamic>.from(row),
        ));
      }

      // 3. Observation
      final observations = await _db.rawQuery(
        'select * from observation_trans where deleted_at is null and sync_id is null order by id desc',
      );
      for (var row in observations) {
        items.add(PendingSyncItem(
          id: row['id'] as int,
          tableKey: 'observation',
          moduleTitle: 'Observasi Tugas',
          title: (row['title'] != null && row['title'].toString().isNotEmpty)
              ? row['title'].toString()
              : (row['remark']?.toString() ?? 'Observasi Karyawan'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.visibility_rounded,
          color: const Color(0xFF059669),
          detailText: row['remark']?.toString(),
          rawData: Map<String, dynamic>.from(row),
        ));
      }

      // 4. Safety Talk
      final safeties = await _db.rawQuery(
        'select * from safety_trans where deleted_at is null and sync_id is null order by id desc',
      );
      for (var row in safeties) {
        items.add(PendingSyncItem(
          id: row['id'] as int,
          tableKey: 'safety',
          moduleTitle: 'Safety Talk',
          title: (row['title'] != null && row['title'].toString().isNotEmpty)
              ? row['title'].toString()
              : (row['remark']?.toString() ?? 'Safety Talk'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.campaign_rounded,
          color: const Color(0xFF4F46E5),
          detailText: row['remark']?.toString(),
          rawData: Map<String, dynamic>.from(row),
        ));
      }

      // 5. Coaching
      final coachings = await _db.rawQuery(
        'select * from coaching_trans where deleted_at is null and sync_id is null order by id desc',
      );
      for (var row in coachings) {
        items.add(PendingSyncItem(
          id: row['id'] as int,
          tableKey: 'coaching',
          moduleTitle: 'Coaching',
          title: (row['title'] != null && row['title'].toString().isNotEmpty)
              ? row['title'].toString()
              : (row['purpose']?.toString() ?? 'Coaching K3'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.psychology_rounded,
          color: const Color(0xFFE11D48),
          detailText: row['remark']?.toString(),
          rawData: Map<String, dynamic>.from(row),
        ));
      }

      // 6. P5M
      final p5ms = await _db.rawQuery(
        'select * from p5m_trans where deleted_at is null and sync_id is null order by id desc',
      );
      for (var row in p5ms) {
        items.add(PendingSyncItem(
          id: row['id'] as int,
          tableKey: 'p5m',
          moduleTitle: 'Fit to Work (P5M)',
          title: (row['title'] != null && row['title'].toString().isNotEmpty)
              ? row['title'].toString()
              : (row['remark']?.toString() ?? 'P5M Harian'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.health_and_safety_rounded,
          color: const Color(0xFF0284C7),
          detailText: row['remark']?.toString(),
          rawData: Map<String, dynamic>.from(row),
        ));
      }

      // 7. P2H
      final p2hs = await _db.rawQuery(
        'select * from p2h_trans where deleted_at is null and sync_id is null order by id desc',
      );
      for (var row in p2hs) {
        items.add(PendingSyncItem(
          id: row['id'] as int,
          tableKey: 'p2h',
          moduleTitle: 'P2H Kendaraan',
          title: (row['no_lambung'] != null && row['no_lambung'].toString().isNotEmpty)
              ? 'P2H Unit ${row['no_lambung']}'
              : 'P2H Kendaraan',
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.car_repair_rounded,
          color: const Color(0xFF7C3AED),
          detailText: row['remark']?.toString(),
          rawData: Map<String, dynamic>.from(row),
        ));
      }
      // 8. Offline Queue Jobs (BBS, FCI, RCI)
      final jobs = await _jobs();
      for (final job in jobs) {
        if (job.feature == 'bbs') {
          final form = Map<String, dynamic>.from(job.payload['form'] as Map? ?? {});
          items.add(PendingSyncItem(
            id: job.id.hashCode,
            tableKey: 'bbs',
            moduleTitle: 'BBS (Behavior Based Safety)',
            title: form['category']?.toString() ?? 'Observasi BBS',
            date: form['observedAt']?.toString().split('T')[0] ?? '',
            time: '',
            location: '${form['area'] ?? ''} ${form['benchmark'] ?? ''}',
            icon: Icons.groups_2_rounded,
            color: const Color(0xFF075985),
            detailText: 'Target: ${form['observedPerson'] ?? ''}',
            rawData: job.payload,
          ));
        } else if (job.feature == 'fci') {
          final map = Map<String, dynamic>.from(job.payload['map'] as Map? ?? {});
          items.add(PendingSyncItem(
            id: job.id.hashCode,
            tableKey: 'fci',
            moduleTitle: 'Front Condition Index (FCI)',
            title: 'FCI - ${map['nama_front'] ?? map['pit'] ?? 'Front Tambang'}',
            date: map['tanggal']?.toString() ?? '',
            time: map['waktu']?.toString() ?? '',
            location: '${map['area'] ?? ''} ${map['pit'] ?? ''}',
            icon: Icons.terrain_rounded,
            color: const Color(0xFF0F766E),
            detailText: 'PIC: ${map['pic'] ?? ''}',
            imagePath: job.payload['photoPath']?.toString(),
            rawData: map,
          ));
        } else if (job.feature == 'rci') {
          final map = Map<String, dynamic>.from(job.payload['map'] as Map? ?? {});
          items.add(PendingSyncItem(
            id: job.id.hashCode,
            tableKey: 'rci',
            moduleTitle: 'Road Condition Index (RCI)',
            title: 'RCI - ${map['segmen_jalan'] ?? map['area'] ?? 'Jalur Tambang'}',
            date: map['tanggal']?.toString() ?? '',
            time: map['waktu']?.toString() ?? '',
            location: '${map['area'] ?? ''} ${map['segmen_jalan'] ?? ''}',
            icon: Icons.add_road_rounded,
            color: const Color(0xFFD97706),
            detailText: 'PIC: ${map['pic'] ?? ''}',
            imagePath: job.payload['photoPath']?.toString(),
            rawData: map,
          ));
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Error getPendingItems: $e');
    }

    return items;
  }

  /// Menghitung total data yang belum disinkronkan ke server
  Future<int> getPendingCount() async {
    int total = 0;
    try {
      final tables = [
        'hazard_trans',
        'inspection_trans',
        'observation_trans',
        'safety_trans',
        'coaching_trans',
        'p5m_trans',
        'p2h_trans',
      ];

      for (var t in tables) {
        final res = await _db.rawQuery(
          'select count(1) as jml from $t where deleted_at is null and sync_id is null',
        );
        if (res.isNotEmpty && res[0]['jml'] != null) {
          total += (res[0]['jml'] as int);
        }
      }

      total += (await _jobs()).length;
    } catch (e) {
      debugPrint('[OfflineSyncService] Error getPendingCount: $e');
    }
    return total;
  }

  /// Sinkronkan satu item ke server
  Future<bool> syncItem(PendingSyncItem item) async {
    try {
      if (item.tableKey == 'bbs') {
        final res = await syncBbsPending();
        return res.success > 0;
      } else if (item.tableKey == 'fci') {
        final res = await syncFciPending();
        return res.success > 0;
      } else if (item.tableKey == 'rci') {
        final res = await syncRciPending();
        return res.success > 0;
      }

      if (_api.getToken.isEmpty || _api.getToken.startsWith('offline_token_')) {
        final auth = PreferenceService.getAuth();
        if (auth != null && auth.token != null && auth.token!.isNotEmpty && !auth.token!.startsWith('offline_token_')) {
          _api.setToken = auth.token!;
        } else {
          final bg = PreferenceService.getBgToken();
          if (bg != null && bg.isNotEmpty) {
            _api.setToken = bg;
          }
        }
      }
      final ok = await syncTran(_db, _api, item.tableKey, item.id);
      if (ok) {
        await refreshPendingCount();
      }
      return ok;
    } catch (e) {
      debugPrint('[OfflineSyncService] Error syncItem ${item.tableKey}:${item.id} -> $e');
      return false;
    }
  }

  /// Sinkronkan semua item secara berurutan
  Future<({int success, int failed})> syncAll() async {
    final items = await getPendingItems();
    int success = 0;
    int failed = 0;

    if (_api.getToken.isEmpty || _api.getToken.startsWith('offline_token_')) {
      final auth = PreferenceService.getAuth();
      if (auth != null && auth.token != null && auth.token!.isNotEmpty && !auth.token!.startsWith('offline_token_')) {
        _api.setToken = auth.token!;
      } else {
        final bg = PreferenceService.getBgToken();
        if (bg != null && bg.isNotEmpty) {
          _api.setToken = bg;
        }
      }
    }

    for (var item in items) {
      final ok = await syncItem(item);
      if (ok) {
        success++;
      } else {
        failed++;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final bbsResult = await syncBbsPending();
    success += bbsResult.success;
    failed += bbsResult.failed;

    final fciResult = await syncFciPending();
    success += fciResult.success;
    failed += fciResult.failed;

    final rciResult = await syncRciPending();
    success += rciResult.success;
    failed += rciResult.failed;

    await refreshPendingCount();
    return (success: success, failed: failed);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
