import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an in-app notification stored in Firestore.
///
/// This is the database-backed notification stand-in for FR-16.
/// Later, Firebase Cloud Messaging can be added without changing
/// the customer-facing notification model significantly.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.read,
    this.type,
    this.requestId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final bool read;
  final String? type;
  final String? requestId;
  final Timestamp? createdAt;

  factory AppNotification.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      read: data['read'] == true,
      type: data['type'] as String?,
      requestId: data['requestId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}