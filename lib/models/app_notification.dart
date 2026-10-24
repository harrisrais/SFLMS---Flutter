import 'package:cloud_firestore/cloud_firestore.dart';

/// An in-app notification written when a shipment's status changes or a
/// booking is automatically cancelled.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.requestId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // e.g. 'approved' | 'rejected' | 'cancelled'
  final bool read;
  final String? requestId;
  final Timestamp? createdAt;

  factory AppNotification.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'info',
      read: data['read'] as bool? ?? false,
      requestId: data['requestId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
