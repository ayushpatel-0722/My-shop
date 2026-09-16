import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'service_locator.dart';

/// Firebase Cloud Messaging handler that runs when the app is terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // In production this also writes to the /notifications collection via a
  // Cloud Function; the client handler just keeps the token alive.
}

/// Push-notification registration (Section 16).
class NotificationService {
  final _fcm = FirebaseMessaging.instance;

  Future<void> init({required String userId}) async {
    try {
      await _fcm.requestPermission();
      final token = await _fcm.getToken();
      if (token != null && userId.isNotEmpty) {
        await repo.registerFcmToken(userId, token);
      }
      _fcm.onTokenRefresh.listen((newToken) async {
        if (userId.isNotEmpty) await repo.registerFcmToken(userId, newToken);
      });
    } catch (e) {
      debugPrint('NotificationService init warning: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('NotificationService getToken warning: $e');
      return null;
    }
  }

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
