import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'notification.dart';
import 'preference.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final title = message.notification?.title ??
      message.data['title'] ??
      'MBS Notification';
  final body = message.notification?.body ?? message.data['body'] ?? '';
  final payload = message.data['payload'] ?? message.data['url'] ?? '';

  if (title.isNotEmpty || body.isNotEmpty) {
    await NotificationService.display(
      title: title,
      body: body,
      payload: payload,
      notifType: message.data['type'],
      priority: message.data['priority'],
    );
  }
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      debugPrint('[FCM] Firebase initialized successfully');

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Do not show a permission prompt on app startup. Android permission is
      // requested only after the user explicitly enables notifications.
      await updateToken();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        PreferenceService.setFcmToken(newToken);
        if (PreferenceService.getAuth() != null) {
          ApiService().updateFcmToken(newToken);
        }
      });

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ??
            message.data['title'] ??
            'MBS Notification';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        final payload = message.data['payload'] ?? message.data['url'] ?? '';

        NotificationService.display(
          title: title,
          body: body,
          payload: payload,
          notifType: message.data['type'],
          priority: message.data['priority'],
        );
      });

      // User tapped notification from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = message.data['payload'] ?? message.data['url'] ?? '';
        if (payload.isNotEmpty) {
          NotificationService.navigateToUrl(payload);
        } else {
          NotificationService.navigateToNotifPage();
        }
      });

      // Check if app was opened from terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        final payload =
            initialMessage.data['payload'] ?? initialMessage.data['url'] ?? '';
        if (payload.isNotEmpty) {
          NotificationService.navigateToUrl(payload);
        }
      }
    } catch (e, stack) {
      debugPrint('[FCM] Initialization error: $e\n$stack');
    }
  }

  static Future<String?> updateToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await PreferenceService.setFcmToken(token);
        if (PreferenceService.getAuth() != null) {
          ApiService().updateFcmToken(token);
        }
      }
      return token;
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
      return null;
    }
  }

  static String? get savedToken => PreferenceService.getFcmToken();

  /// Call only from a clear user action, for example the notification setting.
  static Future<bool> requestPermissionFromUser() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) await updateToken();
    return granted;
  }
}
