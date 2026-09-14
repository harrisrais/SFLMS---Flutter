import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// In-app stand-in for FR-16's Firebase Cloud Messaging push notifications.
/// Writing a document here shows up immediately in the customer's
/// NotificationsPage via a live stream. Swapping this for a real FCM push
/// later (e.g. a Cloud Function triggered on write to this collection)
/// won't require changing any of the call sites below.
class NotificationService {
  static CollectionReference<Map<String, dynamic>> get _notifications =>
      AuthService.firestore.collection('notifications');

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
