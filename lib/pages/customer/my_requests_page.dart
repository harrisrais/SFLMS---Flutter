import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/shipment_request.dart';
import '../../services/auth_service.dart';

/// Shows the signed-in customer's own logistics requests and their current
/// status (pending/approved/rejected/…), so FR-06's "pending state" is
/// actually visible somewhere. FR-07 will add admin-side approve/reject
/// actions that update the `status` field read here.
class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFCA8A04);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My Requests'), centerTitle: true),
      body: uid == null
          ? const Center(child: Text('Not logged in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AuthService.firestore
                  .collection('shipmentRequests')
                  .where('customerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load requests: ${snapshot.error}'),
                    ),
                  );
                }
                final requests = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(ShipmentRequest.fromDoc)
                    .toList()
                  ..sort((a, b) {
                    final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
                    final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
                    return bTime.compareTo(aTime);
                  });

                if (requests.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No logistics requests yet', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            'Search the fleet and submit a booking to see it here.',
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
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final statusColor = _statusColor(request.status);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  '${request.pickupCity} → ${request.destinationCity}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  request.status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text('${request.categoryName} · ${request.vehicleRegistrationNo}', style: TextStyle(color: Colors.grey.shade700)),
                            Text(
                              '${request.goodsType.isEmpty ? 'Goods' : request.goodsType} · '
                              '${request.estimatedWeightKg.toStringAsFixed(0)} kg · '
                              '${request.urgency == 'express' ? 'Express' : 'Standard'}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                                                        const SizedBox(height: 8),
                            Text(
                              'Quote: Rs ${request.totalQuote.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F766E)),
                            ),
                            if (request.status == 'rejected' && (request.rejectionReason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reason: ${request.rejectionReason}',
                                style: const TextStyle(color: Color(0xFFDC2626), fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ],
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