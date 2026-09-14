import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/shipment_request.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../login_page.dart';
import '../profile_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _processing = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream(
    String status,
  ) {
    return _firestore
        .collection('shipmentRequests')
        .where('status', isEqualTo: status)
        .snapshots();
  }

  Future<void> _approveRequest(
    ShipmentRequest request,
  ) async {
    if (_processing) return;

    setState(() {
      _processing = true;
    });

    try {
      await _firestore
          .collection('shipmentRequests')
          .doc(request.id)
          .update({
        'status': 'approved',
        'rejectionReason': FieldValue.delete(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': AuthService.auth.currentUser?.uid,
      });

      await NotificationService.create(
        userId: request.customerId,
        title: 'Request Approved',
        body:
            'Your shipment request from ${request.pickupCity} to ${request.destinationCity} has been approved.',
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

  Future<void> _rejectRequest(
    ShipmentRequest request,
  ) async {
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
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
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

    reasonController.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    if (_processing) return;

    setState(() {
      _processing = true;
    });

    try {
      await _firestore
          .collection('shipmentRequests')
          .doc(request.id)
          .update({
        'status': 'rejected',
        'rejectionReason': reason.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': AuthService.auth.currentUser?.uid,
      });

      await NotificationService.create(
        userId: request.customerId,
        title: 'Request Rejected',
        body:
            'Your shipment request from ${request.pickupCity} to ${request.destinationCity} was rejected. Reason: ${reason.trim()}',
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

  ShipmentRequest _requestFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ShipmentRequest.fromDoc(doc);
  }

  Widget _buildRequestList(String status) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestsStream(status),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load requests.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState(status);
        }

        final requests = docs
            .map(_requestFromDoc)
            .toList()
          ..sort((a, b) {
            final aDate = a.createdAt?.toDate();
            final bDate = b.createdAt?.toDate();

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return bDate.compareTo(aDate);
          });

        return RefreshIndicator(
          onRefresh: () async {
            // Firestore snapshots update automatically.
            await Future<void>.delayed(
              const Duration(milliseconds: 300),
            );
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildRequestCard(requests[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String status) {
    String message;

    switch (status) {
      case 'pending':
        message = 'No pending requests.';
        break;
      case 'approved':
        message = 'No approved requests yet.';
        break;
      case 'rejected':
        message = 'No rejected requests.';
        break;
      default:
        message = 'No requests found.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == 'pending'
                  ? Icons.inbox_outlined
                  : status == 'approved'
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(ShipmentRequest request) {
    final isPending = request.status == 'pending';

    final statusColor = request.status == 'approved'
        ? const Color(0xFF16A34A)
        : request.status == 'rejected'
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${request.pickupCity} → ${request.destinationCity}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow(
              Icons.person_outline,
              'Customer',
              request.customerName,
            ),
            _infoRow(
              Icons.local_shipping_outlined,
              'Vehicle',
              request.vehicleRegistrationNo,
            ),
            _infoRow(
              Icons.category_outlined,
              'Category',
              request.categoryName,
            ),
            _infoRow(
              Icons.inventory_2_outlined,
              'Goods',
              request.goodsType,
            ),
            _infoRow(
              Icons.scale_outlined,
              'Weight',
              '${request.estimatedWeightKg.toStringAsFixed(1)} kg',
            ),
            _infoRow(
              Icons.route_outlined,
              'Distance',
              '${request.distanceKm.toStringAsFixed(1)} km',
            ),
            _infoRow(
              Icons.payments_outlined,
              'Quote',
              'Rs ${request.totalQuote.toStringAsFixed(0)}',
            ),
            if (request.rejectionReason != null &&
                request.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  'Rejection reason: ${request.rejectionReason}',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (request.createdAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Submitted: ${_formatTimestamp(request.createdAt!)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _rejectRequest(request),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _approveRequest(request),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();

    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfilePage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Pending',
            ),
            Tab(
              icon: Icon(Icons.check_circle_outline),
              text: 'Approved',
            ),
            Tab(
              icon: Icon(Icons.cancel_outlined),
              text: 'Rejected',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('pending'),
          _buildRequestList('approved'),
          _buildRequestList('rejected'),
        ],
      ),
    );
  }
}
