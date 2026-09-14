import 'package:cloud_firestore/cloud_firestore.dart';

/// An in-app notification, currently the stand-in for FR-16's Firebase
/// Cloud Messaging push notifications. Written by NotificationService
/// whenever an admin changes a shipment request's status (FR-07/FR-08)
/// or the system auto-cancels a booking (FR-11).
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
