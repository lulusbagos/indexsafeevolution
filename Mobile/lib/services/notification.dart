import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../pages/approval/approval_center_page.dart';
import '../pages/hazard/hazard_page.dart';
import '../pages/inspeksi/inspeksi_page.dart';
import '../pages/notif_page.dart';
import '../pages/p2h/p2h_page.dart';
import '../pages/performance/performance_hub_pages.dart';
import '../pages/profile_page.dart';
import '../pages/roster_settings_page.dart';
import '../pages/special_permit/special_permit_followup_page.dart';
import '../pages/special_permit/special_permit_list_page.dart';
import '../utils/enums.dart';
import 'api.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Callback background top-level yang dibutuhkan plugin flutter_local_notifications
}

class NotificationService {
  NotificationService();

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static String? _pendingPayload;

  static void consumePendingPayload() {
    if (_pendingPayload != null && _pendingPayload!.isNotEmpty) {
      final p = _pendingPayload!;
      _pendingPayload = null;
      Future.delayed(const Duration(milliseconds: 300), () {
        navigateToUrl(p);
      });
    }
  }

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          navigateToUrl(payload);
        } else {
          navigateToNotifPage();
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Deteksi jika aplikasi dibuka dari kondisi mati (terminated) via tap notifikasi
    try {
      final details = await _localNotifications.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp && details.notificationResponse != null) {
        final p = details.notificationResponse?.payload;
        if (p != null && p.isNotEmpty) {
          _pendingPayload = p;
        }
      }
    } catch (_) {}

    // Create Android Notification Channels: Normal & Urgent Long Vibration for Findings
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();

      // Channel 1: Notifikasi Biasa
      final regularChannel = AndroidNotificationChannel(
        'indexsafe_notification_channel',
        'MBS SAP Notifications',
        description: 'Notifikasi Real-time Keselamatan Kerja MBS SAP',
        importance: Importance.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(regularChannel);

      // Channel 2: Temuan K3 Yang Diarahkan ke User (Getaran Jauh Lebih Panjang & Intensif)
      final urgentTemuanChannel = AndroidNotificationChannel(
        'indexsafe_temuan_urgent_channel',
        'Temuan K3 Ditugaskan ke Anda (Urgent)',
        description: 'Peringatan Temuan Bahaya & Action Plan K3 Yang Diarahkan ke Anda (Getar Panjang)',
        importance: Importance.max,
        enableVibration: true,
        // Pola getar panjang: jeda 0ms, getar 1000ms, jeda 250ms, getar 1200ms, jeda 250ms, getar 1500ms
        vibrationPattern: Int64List.fromList([0, 1000, 250, 1200, 250, 1500]),
        playSound: true,
      );
      await androidImplementation.createNotificationChannel(urgentTemuanChannel);
    }
  }

  /// Getaran fisik berulang & intensif khusus ketika login / deteksi user ditugaskan sebagai PIC/PJA Hazard, Inspeksi, Action Plan, dll.
  static Future<void> vibrateForPicAssignment({String? reason}) async {
    try {
      for (int i = 0; i < 4; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 180));
        await HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 220));
      }
    } catch (_) {}
  }

  // Display notification, pop up heads-up banner, and VIBRATE phone!
  static Future<void> display({
    required String title,
    required String body,
    String? payload,
    String? notifType,
    String? logo,
    String? priority,
  }) async {
    final t = (notifType ?? '').toLowerCase();
    final p = (priority ?? '').toLowerCase();
    final combined = '$title $body'.toLowerCase();
    final bool isTemuanK3 = p == 'urgent' ||
        t.startsWith('hazard_') ||
        t.startsWith('inspection_') ||
        t.startsWith('actionplan_') ||
        t.startsWith('special_permit') ||
        combined.contains('temuan') ||
        combined.contains('penugasan') ||
        combined.contains('pic') ||
        combined.contains('pja') ||
        combined.contains('special permit') ||
        combined.contains('high risk') ||
        combined.contains('kegiatan high risk') ||
        combined.contains('perlu mitigasi') ||
        combined.contains('tindakan perbaikan') ||
        combined.contains('action plan') ||
        combined.contains('assigned') ||
        combined.contains('reassign');

    // 1. Trigger physical vibration on phone
    // Temuan K3 yang diarahkan ke login bersangkutan: Getaran dibuat LEBIH PANJANG & berulang!
    if (isTemuanK3) {
      () async {
        try {
          for (int i = 0; i < 4; i++) {
            await HapticFeedback.heavyImpact();
            await Future.delayed(const Duration(milliseconds: 220));
            await HapticFeedback.vibrate();
            await Future.delayed(const Duration(milliseconds: 280));
          }
        } catch (_) {}
      }();
    } else {
      try {
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.vibrate();
      } catch (_) {}
    }

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Vibration pattern for system notification banner
    final vibrationPattern = isTemuanK3
        ? Int64List.fromList([0, 1000, 250, 1200, 250, 1500])
        : Int64List.fromList([0, 400, 200, 400]);

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        isTemuanK3 ? 'indexsafe_temuan_urgent_channel' : 'indexsafe_notification_channel',
        isTemuanK3 ? 'Temuan K3 Ditugaskan ke Anda (Urgent)' : 'MBS SAP Notifications',
        channelDescription: isTemuanK3
            ? 'Peringatan Temuan Bahaya & Action Plan K3 Yang Diarahkan ke Anda (Getar Panjang)'
            : 'Notifikasi Real-time Keselamatan Kerja MBS SAP',
        importance: Importance.max,
        priority: isTemuanK3 ? Priority.max : Priority.high,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        playSound: true,
        autoCancel: true,
        channelAction: AndroidNotificationChannelAction.createIfNotExists,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          htmlFormatContentTitle: false,
          htmlFormatBigText: false,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Direct navigation from notification payload / url ("langsung mengarah ke menunya")
  static void navigateToUrl(String url) {
    if (url.trim().isEmpty) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('[NotificationService] Navigator belum siap untuk url: $url. Mengantrekan retry...');
      _pendingPayload = url;
      for (final delay in [200, 500, 1000, 1800]) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (_pendingPayload != null && rootNavigatorKey.currentState != null) {
            final p = _pendingPayload!;
            _pendingPayload = null;
            navigateToUrl(p);
          }
        });
      }
      return;
    }
    _pendingPayload = null;

    final lower = url.toLowerCase();

    // PRIORITAS UTAMA: Special Permit / Observasi High Risk
    // HARUS dicek paling pertama sebelum 'hazard', karena payload special_permit_obs sering memuat kata 'hazard' di dalam atribut permit!
    if (lower.startsWith('special_permit_obs:') ||
        lower.contains('special_permit_id:') ||
        lower.contains('special_permit') ||
        lower.contains('specialpermit') ||
        lower.contains('high_risk') ||
        lower.contains('observasi')) {
      _openSpecialPermitObservation(url, nav);
      return;
    }

    if (lower.contains('roster')) {
      nav.push(MaterialPageRoute(builder: (_) => const RosterSettingsPage()));
    } else if (lower.contains('incident') || lower.contains('insiden') || lower.contains('safety')) {
      nav.push(MaterialPageRoute(builder: (_) => const SafetyUpdatesPage()));
    } else if (lower.contains('hazard')) {
      nav.push(MaterialPageRoute(builder: (_) => const HazardPage()));
    } else if (lower.contains('inspect') || lower.contains('inspeksi')) {
      nav.push(MaterialPageRoute(builder: (_) => const InspeksiPage(Module.inspection)));
    } else if (lower.contains('performance') || lower.contains('achievement') || lower.contains('pencapaian')) {
      nav.push(MaterialPageRoute(builder: (_) => const AchievementSapPage()));
    } else if (lower.contains('league') || lower.contains('liga')) {
      nav.push(MaterialPageRoute(builder: (_) => const SapLeaguePage()));
    } else if (lower.contains('p2h')) {
      nav.push(MaterialPageRoute(builder: (_) => const P2HPage()));
    } else if (lower.contains('profile')) {
      nav.push(MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else if (lower.contains('action') || lower.contains('actionplan')) {
      nav.push(MaterialPageRoute(builder: (_) => const ActionTrackerPage()));
    } else if (lower.contains('approval') || lower.contains('approval_center')) {
      nav.push(MaterialPageRoute(builder: (_) => const ApprovalCenterPage()));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const NotifPage()));
    }
  }

  static Future<void> _openSpecialPermitObservation(String payload, NavigatorState nav) async {
    // 1. Jika payload berisi JSON lengkap permit ("special_permit_obs:{...}")
    if (payload.startsWith('special_permit_obs:')) {
      try {
        final rawJson = payload.substring('special_permit_obs:'.length);
        final map = jsonDecode(rawJson);
        if (map is Map<String, dynamic>) {
          nav.push(MaterialPageRoute(
            builder: (_) => SpecialPermitFollowupPage(permit: map),
          ));
          return;
        }
      } catch (e) {
        debugPrint('[NotificationService] Gagal parse JSON permit dari payload: $e');
      }
    }

    // 2. Jika payload berisi ID permit: "special_permit_id:<guid>"
    if (payload.contains('special_permit_id:')) {
      final id = payload.split('special_permit_id:').last.trim();
      if (id.isNotEmpty) {
        try {
          final res = await ApiService().getSpecialPermitDetail(id);
          bool handled = false;
          res.fold((_) {}, (data) {
            final p = data['data'];
            if (p is Map<String, dynamic>) {
              nav.push(MaterialPageRoute(
                builder: (_) => SpecialPermitFollowupPage(permit: p),
              ));
              handled = true;
            }
          });
          if (handled) return;
        } catch (_) {}
      }
    }

    // 3. Fallback cerdas: Ambil permit high risk aktif milik NIK login dari endpoint alerts
    try {
      final res = await ApiService().getSpecialPermitAlerts();
      bool handled = false;
      res.fold((_) {}, (data) {
        final list = (data['data'] as List<dynamic>?) ?? [];
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          nav.push(MaterialPageRoute(
            builder: (_) => SpecialPermitFollowupPage(permit: first),
          ));
          handled = true;
        }
      });
      if (handled) return;
    } catch (_) {}

    // 4. Jika tidak ada alert high risk aktif, buka list page
    nav.push(MaterialPageRoute(builder: (_) => const SpecialPermitListPage()));
  }

  static void navigateToNotifPage() {
    final nav = rootNavigatorKey.currentState;
    if (nav != null) {
      nav.push(MaterialPageRoute(builder: (_) => const NotifPage()));
    }
  }

  static void cancelAll() => _localNotifications.cancelAll();
}
