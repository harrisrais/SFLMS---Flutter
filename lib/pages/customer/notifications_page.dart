import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

/// Shows booking-status notifications (approved/rejected/cancelled, and
/// later payment/dispatch/delivery updates) written by admin actions or the
/// FR-11 auto-cancel job. Tapping a notification marks it read. This is the
/// in-app view of what FR-16 will eventually also push via FCM.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: uid == null
          ? const Center(child: Text('Not logged in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: NotificationService.streamForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load notifications: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                final notifications =
                    (snapshot.data?.docs ??
                            const <
                              QueryDocumentSnapshot<Map<String, dynamic>>
                            >[])
                        .map(AppNotification.fromDoc)
                        .toList()
                      ..sort((a, b) {
                        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
                        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
                        return bTime.compareTo(aTime);
                      });

                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.notifications_none_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You will see booking updates here once an admin reviews your requests.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Card(
                      color: notification.read ? null : const Color(0xFFECFEFF),
                      child: ListTile(
                        onTap: () {
                          if (!notification.read)
                            NotificationService.markRead(notification.id);
                        },
                        leading: Icon(
                          notification.read
                              ? Icons.notifications_none_outlined
                              : Icons.notifications_active_outlined,
                          color: notification.read
                              ? Colors.grey
                              : const Color(0xFF0F766E),
                        ),
                        title: Text(
                          notification.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(notification.body),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
