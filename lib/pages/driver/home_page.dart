import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/shipment_request.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/tracking_service.dart';
import '../login_page.dart';
import '../profile_page.dart';
import 'route_map_page.dart';

String _formatDateTime(DateTime dt) {
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

Future<void> _advanceTask(BuildContext context, ShipmentRequest task, String status, String title, String body) async {
  try {
    await AuthService.firestore.collection('shipmentRequests').doc(task.id).update({
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    });
    await NotificationService.create(userId: task.customerId, title: title, body: body, type: status, requestId: task.id);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title sent.')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update shipment: $e')));
  }
}

  Future<void> _completeDelivery(BuildContext context, ShipmentRequest task) async {
    final recipientController = TextEditingController();
    final notesController = TextEditingController();
    final proof = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Proof of delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: recipientController, decoration: const InputDecoration(labelText: 'Received by', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Delivery notes', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (recipientController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, {'recipient': recipientController.text.trim(), 'notes': notesController.text.trim()});
            },
            child: const Text('Complete delivery'),
          ),
        ],
      ),
    );
    recipientController.dispose();
    notesController.dispose();
    if (proof == null || !context.mounted) return;
    try {
      await TrackingService.stop(task.id);
      await AuthService.firestore.collection('shipmentRequests').doc(task.id).update({
        'status': 'pod_pending_customer',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'proofOfDelivery': {'receivedBy': proof['recipient'], 'notes': proof['notes']},
      });
      await NotificationService.create(userId: task.customerId, title: 'Proof of delivery ready', body: 'The recipient signed for your shipment. Please countersign the digital proof of delivery.', type: 'pod_ready', requestId: task.id);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not complete delivery: $e')));
    }
  }
/// FR-10 Task Assignment: shows the tasks an admin has assigned to this
/// driver (route, cargo, loaders, expected arrival). Pickup/drop-off map
/// navigation will be added once a Google Maps API key is available
/// (FR-17); for now the route is shown as city names only.
class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Logout', onPressed: () => _logout(context)),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AuthService.firestore.collection('shipmentRequests').where('driverId', isEqualTo: uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load tasks: ${snapshot.error}')),
                  );
                }
                final tasks = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(ShipmentRequest.fromDoc)
                      .where((r) => {'assigned', 'departed', 'pickup_arrived', 'en_route', 'arrived'}.contains(r.status))
                    .toList()
                  ..sort((a, b) {
                    final aTime = a.expectedArrivalAt?.millisecondsSinceEpoch ?? 0;
                    final bTime = b.expectedArrivalAt?.millisecondsSinceEpoch ?? 0;
                    return aTime.compareTo(bTime);
                  });

                if (tasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No assigned tasks yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text(
                            'Task assignments will appear here once an admin dispatches you on a shipment.',
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
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${task.pickupCity} \u2192 ${task.destinationCity}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text('${task.categoryName} \u00b7 ${task.vehicleRegistrationNo}', style: TextStyle(color: Colors.grey.shade700)),
                            Text(
                              '${task.goodsType.isEmpty ? 'Goods' : task.goodsType} \u00b7 '
                              '${task.estimatedWeightKg.toStringAsFixed(0)} kg \u00b7 '
                              '${task.urgency == 'express' ? 'Express' : 'Standard'}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            Text(
                              'Customer: ${task.customerName.isEmpty ? task.customerId : task.customerName}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            if ((task.loader1Name ?? '').isNotEmpty || (task.loader2Name ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Loaders: ${[task.loader1Name, task.loader2Name].where((s) => (s ?? '').isNotEmpty).join(', ')}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                            if (task.expectedArrivalAt != null) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.schedule_outlined, size: 16, color: Color(0xFF0F766E)),
                                const SizedBox(width: 6),
                                Text(
                                  'Expected arrival: ${_formatDateTime(task.expectedArrivalAt!.toDate())}',
                                  style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                                ),
                              ]),
                            ],
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RouteMapPage(pickupCity: task.pickupCity, destinationCity: task.destinationCity))),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Open route map'),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFFECFEFF), borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.map_outlined, size: 14, color: Color(0xFF0F766E)),
                                const SizedBox(width: 6),
                                Text(
                                  'Map navigation to ${task.pickupCity} \u2192 ${task.destinationCity} coming with FR-17',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E)),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if ({'assigned', 'departed', 'pickup_arrived', 'en_route', 'arrived'}.contains(task.status))
                                  OutlinedButton.icon(
                                    onPressed: () => _startTracking(context, task),
                                    icon: const Icon(Icons.gps_fixed),
                                    label: const Text('Share live location'),
                                  ),
                                if (task.status == 'assigned')
                                  FilledButton.icon(
                                    onPressed: () => _advanceTask(context, task, 'departed', 'Shipment departed', 'Your driver has departed for pickup.'),
                                    icon: const Icon(Icons.play_arrow_outlined),
                                    label: const Text('Departed'),
                                  ),
                                if (task.status == 'departed')
                                  FilledButton.icon(
                                    onPressed: () => _advanceTask(context, task, 'pickup_arrived', 'Arrived at pickup', 'Your driver has arrived at the pickup location. Please complete the pickup payment.'),
                                    icon: const Icon(Icons.storefront_outlined),
                                    label: const Text('Arrived at pickup'),
                                  ),
                                if (task.status == 'pickup_arrived' && task.pickupPaymentStatus == 'paid')
                                  FilledButton.icon(
                                    onPressed: () => _advanceTask(context, task, 'en_route', 'Shipment en route', 'Your shipment is now en route to its destination.'),
                                    icon: const Icon(Icons.local_shipping_outlined),
                                    label: const Text('Start delivery'),
                                  ),
                                if (task.status == 'en_route')
                                  FilledButton.icon(
                                    onPressed: () => _advanceTask(context, task, 'arrived', 'Shipment arrived', 'Your shipment has arrived at the destination.'),
                                    icon: const Icon(Icons.location_on_outlined),
                                    label: const Text('Arrived'),
                                  ),
                                if (task.status == 'arrived')
                                  FilledButton.icon(
                                    onPressed: () => _completeDelivery(context, task),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Delivered'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

Future<void> _startTracking(BuildContext context, ShipmentRequest task) async {
  try {
    await TrackingService.start(task.id);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live location sharing started.')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start tracking: $e')));
  }
}