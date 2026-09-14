import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/shipment_request.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../login_page.dart';
import '../profile_page.dart';

/// FR-07 Admin Review and Confirmation: logistics managers review pending
/// requests, validate route/load details, and approve or reject them.
/// FR-08 Initial Security Deposit: approving a request also sets up the
/// 10% commitment fee (amount, unpaid status, 24h due time) that the
/// customer pays from My Requests. Every status change writes a
/// notification for the customer via NotificationService (an in-app
/// stand-in for FR-16's FCM push).
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseFirestore _firestore = AuthService.firestore;
  bool _processing = false;

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _approveRequest(ShipmentRequest request) async {
    if (_processing) return;

    setState(() {
      _processing = true;
    });

    try {
      await _firestore.collection('shipmentRequests').doc(request.id).update({
        'status': 'approved',
        'rejectionReason': FieldValue.delete(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': AuthService.auth.currentUser?.uid,
        // FR-08: set up the commitment fee the customer must pay within 24h.
        'commitmentFeeAmount': request.totalQuote * 0.10,
        'commitmentFeeStatus': 'unpaid',
        'commitmentFeeDueAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
      });

      await NotificationService.create(
        userId: request.customerId,
        title: 'Request Approved',
        body:
            'Your shipment request from ${request.pickupCity} to ${request.destinationCity} has been approved. '
            'Please pay the commitment fee within 24 hours to confirm your booking.',
        type: 'approved',
        requestId: request.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request approved successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to approve request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _rejectRequest(ShipmentRequest request) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provide a reason for rejecting this request.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Rejection reason',
                  hintText: 'Enter the reason...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () {
                final value = reasonController.text.trim();

                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a rejection reason.'),
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop(value);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;
    if (_processing) return;

    setState(() {
      _processing = true;
    });

    try {
      await _firestore.collection('shipmentRequests').doc(request.id).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': AuthService.auth.currentUser?.uid,
      });

      await NotificationService.create(
        userId: request.customerId,
        title: 'Request Rejected',
        body:
            'Your shipment request from ${request.pickupCity} to ${request.destinationCity} was rejected. '
            'Reason: $reason',
        type: 'rejected',
        requestId: request.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to reject request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Review'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RequestsList(
              status: 'pending',
              processing: _processing,
              onApprove: _approveRequest,
              onReject: _rejectRequest,
            ),
            _RequestsList(
              status: 'approved',
              processing: _processing,
              onApprove: _approveRequest,
              onReject: _rejectRequest,
            ),
            _RequestsList(
              status: 'rejected',
              processing: _processing,
              onApprove: _approveRequest,
              onReject: _rejectRequest,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.status,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final String status;
  final bool processing;
  final ValueChanged<ShipmentRequest> onApprove;
  final ValueChanged<ShipmentRequest> onReject;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AuthService.firestore
          .collection('shipmentRequests')
          .where('status', isEqualTo: status)
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
        final requests =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
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
                  const Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $status requests',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = requests[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.pickupCity} \u2192 ${request.destinationCity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${request.categoryName} \u00b7 ${request.vehicleRegistrationNo} \u00b7 ${request.distanceKm.toStringAsFixed(0)} km',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      '${request.goodsType.isEmpty ? 'Goods' : request.goodsType} \u00b7 '
                      '${request.estimatedWeightKg.toStringAsFixed(0)} kg \u00b7 '
                      '${request.urgency == 'express' ? 'Express' : 'Standard'}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      'Customer: ${request.customerName.isEmpty ? request.customerId : request.customerName}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (request.addOns.values.any((v) => v)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (request.addOns['fragileHandling'] == true)
                            const Chip(label: Text('Fragile Handling')),
                          if (request.addOns['insurance'] == true)
                            const Chip(label: Text('Insurance')),
                          if (request.addOns['packing'] == true)
                            const Chip(label: Text('Packing')),
                          if (request.addOns['labor'] == true)
                            const Chip(label: Text('Labor')),
                        ],
                      ),
                    ],
                    if (request.status == 'rejected' &&
                        (request.rejectionReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reason: ${request.rejectionReason}',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Quote: Rs ${request.totalQuote.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    if (request.commitmentFeeStatus != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Deposit: Rs ${(request.commitmentFeeAmount ?? 0).toStringAsFixed(0)} \u2014 ${request.commitmentFeeStatus}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: processing
                                  ? null
                                  : () => onReject(request),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: processing
                                  ? null
                                  : () => onApprove(request),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
