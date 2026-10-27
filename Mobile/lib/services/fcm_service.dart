import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'notification.dart';
import 'preference.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Message ID: ${message.messageId}');
  debugPrint('[FCM Background] Data: ${message.data}');
  debugPrint('[FCM Background] Notification: ${message.notification?.title} - ${message.notification?.body}');

  final title = message.notification?.title ?? message.data['title'] ?? 'MBS Notification';
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

      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] Authorization status: ${settings.authorizationStatus}');

      // Get FCM Token
      await updateToken();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        PreferenceService.setFcmToken(newToken);
        if (PreferenceService.getAuth() != null) {
          ApiService().updateFcmToken(newToken);
        }
      });

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Received: ${message.notification?.title} - ${message.notification?.body}');
        final title = message.notification?.title ?? message.data['title'] ?? 'MBS Notification';
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
        debugPrint('[FCM OpenedApp] User tapped notification');
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
        debugPrint('[FCM InitialMessage] App launched from notification');
        final payload = initialMessage.data['payload'] ?? initialMessage.data['url'] ?? '';
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
        debugPrint('[FCM] Current Token: $token');
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
}
