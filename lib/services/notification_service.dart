import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles the application's Firestore-backed in-app notifications.
///
/// This provides the notification infrastructure needed for FR-07.
/// It can later be extended to trigger Firebase Cloud Messaging (FCM).
class NotificationService {
  NotificationService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  /// Streams all notifications belonging to [userId].
  ///
  /// Newest notifications are returned first.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamForUser(
    String userId,
  ) {
    if (userId.isEmpty) {
      return const Stream.empty();
    }

    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Creates a notification for a customer.
  static Future<void> create({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? requestId,
  }) async {
    if (userId.isEmpty) return;

    await _notifications.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'requestId': requestId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks one notification as read.
  static Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;

    await _notifications.doc(notificationId).update({
      'read': true,
    });
  }

  /// Marks all notifications belonging to [userId] as read.
  static Future<void> markAllAsRead(String userId) async {
    if (userId.isEmpty) return;

    final snapshot = await _notifications
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }
}