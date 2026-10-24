import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/shipment_request.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/booking_modification_service.dart';
import '../../services/notification_service.dart';
import 'payment_page.dart';
import 'tracking_page.dart';

String _formatDateTime(DateTime dt) {
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

/// Shows the signed-in customer's own logistics requests and their current
/// status, commitment-fee payment, and assigned operational team details.
class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'assigned':
        return const Color(0xFF0F766E);
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

                    // Check for overdue commitment fees when the request list loads.
                    if (request.status == 'approved' && request.commitmentFeeStatus == 'unpaid') {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        await PaymentService.expireIfOverdue(request);
                        await PaymentService.remindIfDueSoon(request);
                      });
                    }

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
                            if (request.scheduledPickupAt != null) ...[
                              const SizedBox(height: 4),
                              Text('Pickup: ${_formatDateTime(request.scheduledPickupAt!.toDate())}', style: TextStyle(color: Colors.grey.shade700)),
                            ],
                            if ({'departed', 'pickup_arrived', 'en_route', 'arrived'}.contains(request.status)) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackingPage(requestId: request.id, routeLabel: '${request.pickupCity} → ${request.destinationCity}'))),
                                  icon: const Icon(Icons.gps_fixed),
                                  label: const Text('Track shipment live'),
                                ),
                              ),
                            ],
                            if (request.status == 'rejected' && (request.rejectionReason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reason: ${request.rejectionReason}',
                                style: const TextStyle(color: Color(0xFFDC2626), fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ],
                            if (request.status == 'cancelled' && (request.cancelReason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Cancelled: ${request.cancelReason}',
                                style: const TextStyle(color: Color(0xFFDC2626), fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ],
                            if (request.status == 'approved' && request.commitmentFeeStatus == 'unpaid') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentPage(request: request))),
                                  icon: const Icon(Icons.payment_outlined),
                                  label: Text(
                                    'Pay commitment fee (Rs ${(request.commitmentFeeAmount ?? request.totalQuote * 0.10).toStringAsFixed(0)})',
                                  ),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                                ),
                              ),
                            ],
                            if (request.commitmentFeeStatus == 'pending_verification') ...[
                              const SizedBox(height: 8),
                              const Row(children: [
                                Icon(Icons.hourglass_top_outlined, color: Color(0xFFCA8A04), size: 16),
                                SizedBox(width: 6),
                                Text('Payment submitted - awaiting admin verification', style: TextStyle(color: Color(0xFFCA8A04), fontWeight: FontWeight.w600)),
                              ]),
                            ],
                            if (request.status == 'pickup_arrived' && (request.pickupPaymentStatus == null || request.pickupPaymentStatus == 'unpaid')) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentPage(request: request, stage: 'pickup', stageAmount: _pickupAmount(request)))),
                                  icon: const Icon(Icons.payment_outlined),
                                  label: Text('Pay pickup installment (Rs ${_pickupAmount(request).toStringAsFixed(0)})'),
                                ),
                              ),
                            ],
                            if (request.pickupPaymentStatus == 'pending_verification')
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Pickup payment submitted - awaiting admin verification', style: TextStyle(color: Color(0xFFCA8A04), fontWeight: FontWeight.w600)),
                              ),
                            if (request.status == 'pod_pending_customer') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _signPod(context, request),
                                  icon: const Icon(Icons.draw_outlined),
                                  label: const Text('Sign proof of delivery'),
                                ),
                              ),
                            ],
                            if (request.status == 'delivered' && (request.deliveryPaymentStatus == null || request.deliveryPaymentStatus == 'unpaid')) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentPage(request: request, stage: 'delivery', stageAmount: _deliveryAmount(request)))),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: Text('Pay final balance (Rs ${_deliveryAmount(request).toStringAsFixed(0)})'),
                                ),
                              ),
                            ],
                            if (request.deliveryPaymentStatus == 'pending_verification')
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Final payment submitted - awaiting admin verification', style: TextStyle(color: Color(0xFFCA8A04), fontWeight: FontWeight.w600)),
                              ),
                            if (request.proofOfDelivery != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Proof of delivery', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                                    const SizedBox(height: 4),
                                    Text('Received by: ${request.proofOfDelivery?['receivedBy'] ?? '—'}'),
                                    if ((request.proofOfDelivery?['customerSignature'] as String? ?? '').isNotEmpty)
                                      Text('Customer signature: ${request.proofOfDelivery?['customerSignature']}'),
                                    if ((request.proofOfDelivery?['notes'] as String? ?? '').isNotEmpty) Text('Notes: ${request.proofOfDelivery?['notes']}'),
                                    if (request.deliveredAt != null) Text('Delivered: ${_formatDateTime(request.deliveredAt!.toDate())}'),
                                  ],
                                ),
                              ),
                            ],
                            if (BookingModificationService.canModify(request)) ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: OutlinedButton.icon(onPressed: () => _rescheduleRequest(context, request), icon: const Icon(Icons.edit_calendar_outlined), label: const Text('Reschedule'))),
                                const SizedBox(width: 10),
                                Expanded(child: OutlinedButton.icon(onPressed: () => _cancelRequest(context, request), icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel'))),
                              ]),
                            ],
                            if (request.commitmentFeeStatus == 'paid' && request.status != 'assigned') ...[
                              const SizedBox(height: 8),
                              const Row(children: [
                                Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                                SizedBox(width: 6),
                                Text('Commitment fee paid \u2014 waiting on team assignment', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                              ]),
                            ],
                            // Assigned operational team details.
                            if (request.status == 'assigned') ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFECFEFF), borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Operational Team', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
                                    const SizedBox(height: 6),
                                    Text('Driver: ${request.driverName ?? '—'}'),
                                    if ((request.loader1Name ?? '').isNotEmpty || (request.loader2Name ?? '').isNotEmpty)
                                      Text(
                                        'Loaders: ${[request.loader1Name, request.loader2Name].where((s) => (s ?? '').isNotEmpty).join(', ')}',
                                      ),
                                    Text('Vehicle: ${request.vehicleRegistrationNo}'),
                                    if (request.expectedArrivalAt != null)
                                      Text('Expected arrival: ${_formatDateTime(request.expectedArrivalAt!.toDate())}'),
                                  ],
                                ),
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

Future<void> _rescheduleRequest(BuildContext context, ShipmentRequest request) async {
  final initial = request.scheduledPickupAt?.toDate() ?? DateTime.now().add(const Duration(days: 1));
  final date = await showDatePicker(
    context: context,
    firstDate: DateTime.now().add(const Duration(hours: 12)),
    lastDate: DateTime.now().add(const Duration(days: 180)),
    initialDate: initial,
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null || !context.mounted) return;
  try {
    await BookingModificationService.reschedule(request, DateTime(date.year, date.month, date.day, time.hour, time.minute));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking rescheduled.')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<void> _cancelRequest(BuildContext context, ShipmentRequest request) async {
  final pickup = request.scheduledPickupAt?.toDate();
  final fee = pickup == null ? 0 : request.totalQuote * BookingModificationService.cancellationFeeRate(pickup);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel booking?'),
      content: Text('The calculated cancellation fee is Rs ${fee.toStringAsFixed(0)}. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep booking')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancel booking')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await BookingModificationService.cancel(request);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

double _commitmentAmount(ShipmentRequest request) => request.commitmentFeeAmount ?? request.totalQuote * .10;
double _pickupAmount(ShipmentRequest request) => (request.totalQuote - _commitmentAmount(request)) * .50;
double _deliveryAmount(ShipmentRequest request) => request.totalQuote - _commitmentAmount(request) - (request.pickupPaymentAmount ?? _pickupAmount(request));

Future<void> _signPod(BuildContext context, ShipmentRequest request) async {
  final signatureController = TextEditingController();
  final signature = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Customer signature'),
      content: TextField(
        controller: signatureController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Type your full name as signature', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (signatureController.text.trim().isNotEmpty) Navigator.pop(dialogContext, signatureController.text.trim());
          },
          child: const Text('Sign and confirm'),
        ),
      ],
    ),
  );
  signatureController.dispose();
  if (signature == null || !context.mounted) return;
  final proof = {...?request.proofOfDelivery, 'customerSignature': signature, 'signedAt': FieldValue.serverTimestamp()};
  try {
    await AuthService.firestore.collection('shipmentRequests').doc(request.id).update({
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
      'proofOfDelivery': proof,
    });
    await NotificationService.create(
      userId: request.customerId,
      title: 'POD signed',
      body: 'The proof of delivery is complete. Your final balance is now due.',
      type: 'pod_signed',
      requestId: request.id,
    );
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not sign proof of delivery: $e')));
  }
}