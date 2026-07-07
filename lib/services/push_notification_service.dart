import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Web Push certificate key pair from Firebase Console →
/// Project settings → Cloud Messaging → Web configuration → Web Push
/// certificates. Required for FCM to work on web; ignored on mobile.
const String kFcmVapidKey = '';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Runs in a background isolate (mobile) when the app is closed/backgrounded.
  // The OS/browser shows the notification automatically from the FCM payload;
  // nothing to do here unless custom data handling is needed later.
}

/// Requests notification permission, fetches the device's FCM token, and
/// keeps it saved on a Firestore document so a server can push to this
/// device later regardless of whether the app is open.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _foregroundListenerAttached = false;

  /// Requests permission, obtains the FCM token, and stores it under
  /// `collection/docId` as an array field `fcmTokens` (supports multiple
  /// devices per user). Also attaches a listener to persist token refreshes.
  Future<void> registerToken({
    required String collection,
    required String docId,
  }) async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: kFcmVapidKey.isEmpty ? null : kFcmVapidKey)
          : await _messaging.getToken();

      if (token != null) {
        await _saveToken(collection, docId, token);
      }

      _messaging.onTokenRefresh.listen((newToken) {
        _saveToken(collection, docId, newToken);
      });

      _attachForegroundListener();
    } catch (e) {
      debugPrint('PushNotificationService.registerToken error: $e');
    }
  }

  Future<void> _saveToken(String collection, String docId, String token) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// Removes this device's token, e.g. on logout, so it stops receiving push.
  Future<void> unregisterToken({
    required String collection,
    required String docId,
  }) async {
    try {
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: kFcmVapidKey.isEmpty ? null : kFcmVapidKey)
          : await _messaging.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection(collection).doc(docId).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PushNotificationService.unregisterToken error: $e');
    }
  }

  void _attachForegroundListener() {
    if (_foregroundListenerAttached) return;
    _foregroundListenerAttached = true;
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground push received: ${message.notification?.title}');
    });
  }
}
