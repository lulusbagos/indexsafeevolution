import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'database.dart';
import 'notification.dart';
import 'preference.dart';
import 'sync.dart';

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

  final DatabaseService _db = DatabaseService();
  final ApiService _api = ApiService();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isAutoSyncing = false;
  bool _isListenerStarted = false;

  /// Notifier untuk memberi tahu UI secara instan ketika ada data baru atau sinkronisasi selesai
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  /// Inisialisasi listener deteksi koneksi jaringan untuk auto-sync
  void initAutoSyncListener() {
    if (_isListenerStarted) return;
    _isListenerStarted = true;

    // Load hitungan pending saat aplikasi dimulai
    refreshPendingCount();

    // Dengarkan perubahan konektivitas jaringan (Online / Offline)
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final isOnline = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn);

      if (isOnline) {
        debugPrint('[OfflineSyncService] Jaringan online terdeteksi ($results). Memeriksa data pending...');
        // Beri jeda 2.5 detik agar koneksi benar-benar terhubung stabil
        await Future.delayed(const Duration(milliseconds: 2500));

        final count = await getPendingCount();
        if (count > 0 && !_isAutoSyncing) {
          debugPrint('[OfflineSyncService] Terdapat $count data lokal offline. Memulai Auto-Sync ke server...');
          await autoSyncPending();
        }
      }
    });

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
  Future<({int success, int failed})> autoSyncPending() async {
    if (_isAutoSyncing) return (success: 0, failed: 0);
    _isAutoSyncing = true;
    isSyncingNotifier.value = true;

    try {
      // Pastikan token login tersedia
      if (_api.getToken.isEmpty) {
        final auth = PreferenceService.getAuth();
        if (auth != null && auth.token != null && auth.token!.isNotEmpty) {
          _api.setToken = auth.token!;
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
    final count = await getPendingCount();
    pendingCountNotifier.value = count;
    return count;
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
          moduleTitle: 'Inspection',
          title: (row['category'] != null && row['category'].toString().isNotEmpty)
              ? 'Inspeksi ${row['category']}'
              : (row['remark']?.toString() ?? 'Laporan Inspeksi'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.fact_check_rounded,
          color: const Color(0xFF059669),
          detailText: row['remark']?.toString(),
          imagePath: row['image']?.toString(),
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
          moduleTitle: 'Observation',
          title: (row['title'] != null && row['title'].toString().isNotEmpty)
              ? row['title'].toString()
              : (row['activity']?.toString() ?? 'Observasi K3'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.visibility_rounded,
          color: const Color(0xFF0D9488),
          detailText: row['remark']?.toString(),
          imagePath: row['image']?.toString(),
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
              : (row['remark']?.toString() ?? 'Safety Talk (5M)'),
          date: row['date']?.toString() ?? '',
          time: row['time']?.toString() ?? '',
          location: row['location_detail']?.toString() ?? '',
          icon: Icons.record_voice_over_rounded,
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
    } catch (e) {
      debugPrint('[OfflineSyncService] Error getPendingCount: $e');
    }
    return total;
  }

  /// Sinkronkan satu item ke server
  Future<bool> syncItem(PendingSyncItem item) async {
    try {
      if (_api.getToken.isEmpty) {
        final auth = PreferenceService.getAuth();
        if (auth != null && auth.token != null && auth.token!.isNotEmpty) {
          _api.setToken = auth.token!;
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

    if (_api.getToken.isEmpty) {
      final auth = PreferenceService.getAuth();
      if (auth != null && auth.token != null && auth.token!.isNotEmpty) {
        _api.setToken = auth.token!;
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

    await refreshPendingCount();
    return (success: success, failed: failed);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
