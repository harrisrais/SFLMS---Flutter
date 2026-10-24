import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'auth_service.dart';
import '../firebase_env.dart';

/// In-app notifications are stored in Firestore and appear immediately in the customer's
/// NotificationsPage via a live stream. Swapping this for a real FCM push
/// later (e.g. a Cloud Function triggered on write to this collection)
/// won't require changing any of the call sites below.
class NotificationService {
  static CollectionReference<Map<String, dynamic>> get _notifications =>
      AuthService.firestore.collection('notifications');

  static Future<void> registerDevice() async {
    final user = AuthService.auth.currentUser;
    if (user == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final vapidKey = FirebaseEnv.get('FIREBASE_WEB_VAPID_KEY');
      final token = await messaging.getToken(vapidKey: vapidKey.isEmpty ? null : vapidKey);
      if (token == null || token.isEmpty) return;
      await AuthService.firestore.collection('fcmTokens').doc(token).set({
        'userId': user.uid,
        'platform': 'web',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      messaging.onTokenRefresh.listen((refreshedToken) {
        AuthService.firestore.collection('fcmTokens').doc(refreshedToken).set({
          'userId': user.uid,
          'platform': 'web',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      // In-app Firestore notifications remain available when push is not configured.
    }
  }

  static Future<void> create({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? requestId,
  }) {
    return _notifications.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'requestId': requestId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForUser(
    String userId,
  ) {
    return _notifications.where('userId', isEqualTo: userId).snapshots();
  }

  static Future<void> markRead(String notificationId) {
    return _notifications.doc(notificationId).update({'read': true});
  }
}
