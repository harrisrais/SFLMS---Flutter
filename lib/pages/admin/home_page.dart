import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/shipment_request.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/payment_service.dart';
import '../login_page.dart';
import '../profile_page.dart';

String _formatDateTime(DateTime dt) {
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

/// FR-07 Admin Review and Confirmation: logistics managers review pending
/// requests, validate route/load details, and approve or reject them.
/// FR-08 Initial Security Deposit: approving a request also sets up the
/// 10% commitment fee (amount, unpaid status, 24h due time).
/// FR-10 Task Assignment: once the fee is paid, the admin assigns a driver,
/// two loaders, and an expected pickup arrival time, moving the request to
/// an `assigned` status that both the driver's dashboard and the
/// customer's My Requests (FR-09) read from.
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
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
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
        'commitmentFeeDueAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });

      await NotificationService.create(
        userId: request.customerId,
        title: 'Request Approved',
        body: 'Your shipment request from ${request.pickupCity} to ${request.destinationCity} has been approved. '
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
        body: 'Your shipment request from ${request.pickupCity} to ${request.destinationCity} was rejected. '
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

  /// FR-10: opens the Assign Team dialog and, if the admin confirms it,
  /// writes the driver/loaders/expected arrival and flips status to
  /// 'assigned'.
  Future<void> _assignTeam(ShipmentRequest request) async {
    final result = await showDialog<_TeamAssignment>(
      context: context,
      builder: (_) => _AssignTeamDialog(request: request),
    );
    if (result == null) return;
    if (_processing) return;

    setState(() => _processing = true);
    try {
      await _firestore.collection('shipmentRequests').doc(request.id).update({
        'status': 'assigned',
        'driverId': result.driverId,
        'driverName': result.driverName,
        'loader1Name': result.loader1Name,
        'loader2Name': result.loader2Name,
        'expectedArrivalAt': Timestamp.fromDate(result.expectedArrival),
        'assignedAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.create(
        userId: request.customerId,
        title: 'Team assigned',
        body: 'Driver ${result.driverName} has been assigned to your ${request.pickupCity} \u2192 '
            '${request.destinationCity} shipment. Expected arrival: ${_formatDateTime(result.expectedArrival)}.',
        type: 'assigned',
        requestId: request.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team assigned.'), backgroundColor: Color(0xFF0F766E)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to assign team: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _verifyPayment(ShipmentRequest request) async {
    final paymentId = request.commitmentFeeStatus == 'pending_verification'
        ? request.paymentId
        : request.pickupPaymentStatus == 'pending_verification'
            ? request.pickupPaymentId
            : request.deliveryPaymentId;
    if (_processing || paymentId == null) return;
    setState(() => _processing = true);
    try {
      await PaymentService.verifyPayment(requestId: request.id, paymentId: paymentId);
      await NotificationService.create(
        userId: request.customerId,
        title: 'Payment verified',
        body: 'Your payment was verified. The shipment can continue to its next stage.',
        type: 'payment_verified',
        requestId: request.id,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verified.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to verify payment: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _closeTrip(ShipmentRequest request) async {
    final hasCustomerSignature = (request.proofOfDelivery?['customerSignature'] as String? ?? '').isNotEmpty;
    if (_processing || request.status != 'delivered' || request.deliveryPaymentStatus != 'paid' || !hasCustomerSignature) return;
    setState(() => _processing = true);
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('shipmentRequests').doc(request.id), {
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': AuthService.auth.currentUser?.uid,
        'driverId': FieldValue.delete(),
        'driverName': FieldValue.delete(),
      });
      batch.update(_firestore.collection('fleetVehicles').doc(request.vehicleId), {
        'isAvailable': true,
        'driverId': FieldValue.delete(),
        'releasedAt': FieldValue.serverTimestamp(),
      });
      if (request.driverId != null) {
        batch.update(_firestore.collection('users').doc(request.driverId), {
          'isAvailable': true,
          'assignedRequestId': FieldValue.delete(),
        });
      }
      await batch.commit();
      await NotificationService.create(
        userId: request.customerId,
        title: 'Trip closed',
        body: 'Your delivery was formally closed by the administrator. Thank you for using SFLMS.',
        type: 'trip_closed',
        requestId: request.id,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip closed and resources released.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to close trip: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Review'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
            ),
            IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Logout', onPressed: _logout),
          ],
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Assigned'),
            Tab(text: 'Rejected'),
            Tab(text: 'Pickup payments'),
            Tab(text: 'Delivery payments'),
          ]),
        ),
        body: TabBarView(children: [
          _RequestsList(status: 'pending', processing: _processing, onApprove: _approveRequest, onReject: _rejectRequest),
          _RequestsList(
            status: 'approved',
            processing: _processing,
            onApprove: _approveRequest,
            onReject: _rejectRequest,
            onAssign: _assignTeam,
            onVerifyPayment: _verifyPayment,
          ),
          _RequestsList(status: 'assigned', processing: _processing, onApprove: _approveRequest, onReject: _rejectRequest),
          _RequestsList(status: 'rejected', processing: _processing, onApprove: _approveRequest, onReject: _rejectRequest),
          _RequestsList(status: 'pickup_arrived', processing: _processing, onApprove: _approveRequest, onReject: _rejectRequest, onVerifyPayment: _verifyPayment),
          _RequestsList(status: 'delivered', processing: _processing, onApprove: _approveRequest, onReject: _rejectRequest, onVerifyPayment: _verifyPayment, onCloseTrip: _closeTrip),
        ]),
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
    this.onAssign,
    this.onVerifyPayment,
    this.onCloseTrip,
  });

  final String status;
  final bool processing;
  final ValueChanged<ShipmentRequest> onApprove;
  final ValueChanged<ShipmentRequest> onReject;
  final ValueChanged<ShipmentRequest>? onAssign;
  final ValueChanged<ShipmentRequest>? onVerifyPayment;
  final ValueChanged<ShipmentRequest>? onCloseTrip;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AuthService.firestore.collection('shipmentRequests').where('status', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load requests: ${snapshot.error}')),
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
                  Text('No $status requests', style: const TextStyle(fontWeight: FontWeight.w700)),
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                          if (request.addOns['fragileHandling'] == true) const Chip(label: Text('Fragile Handling')),
                          if (request.addOns['insurance'] == true) const Chip(label: Text('Insurance')),
                          if (request.addOns['packing'] == true) const Chip(label: Text('Packing')),
                          if (request.addOns['labor'] == true) const Chip(label: Text('Labor')),
                        ],
                      ),
                    ],
                    if (request.status == 'rejected' && (request.rejectionReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reason: ${request.rejectionReason}',
                        style: const TextStyle(color: Color(0xFFDC2626), fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Quote: Rs ${request.totalQuote.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F766E)),
                    ),
                    if (request.commitmentFeeStatus != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Deposit: Rs ${(request.commitmentFeeAmount ?? 0).toStringAsFixed(0)} \u2014 ${request.commitmentFeeStatus}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                    if (request.driverId != null) ...[
                      const SizedBox(height: 8),
                      Text('Driver: ${request.driverName ?? request.driverId}', style: TextStyle(color: Colors.grey.shade700)),
                      if ((request.loader1Name ?? '').isNotEmpty || (request.loader2Name ?? '').isNotEmpty)
                        Text(
                          'Loaders: ${[request.loader1Name, request.loader2Name].where((s) => (s ?? '').isNotEmpty).join(', ')}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      if (request.expectedArrivalAt != null)
                        Text(
                          'Expected arrival: ${_formatDateTime(request.expectedArrivalAt!.toDate())}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                    ],
                    if (status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: processing ? null : () => onReject(request),
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: processing ? null : () => onApprove(request),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                            child: const Text('Approve'),
                          ),
                        ),
                      ]),
                    ],
                    if (status == 'approved' && request.commitmentFeeStatus == 'paid' && request.driverId == null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: processing ? null : () => onAssign?.call(request),
                          icon: const Icon(Icons.groups_outlined),
                          label: const Text('Assign Operational Team'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                        ),
                      ),
                    ],
                    if ((status == 'approved' && request.commitmentFeeStatus == 'pending_verification') ||
                      (status == 'pickup_arrived' && request.pickupPaymentStatus == 'pending_verification') ||
                      (status == 'delivered' && request.deliveryPaymentStatus == 'pending_verification')) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: processing ? null : () => onVerifyPayment?.call(request),
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Verify mock payment'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                        ),
                      ),
                    ],
                    if (status == 'delivered' && request.deliveryPaymentStatus == 'paid' &&
                        (request.proofOfDelivery?['customerSignature'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: processing ? null : () => onCloseTrip?.call(request),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Close trip and release resources'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                        ),
                      ),
                    ],
                    if (status == 'approved' && request.commitmentFeeStatus != 'paid') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Waiting on customer to pay the commitment fee before a team can be assigned.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
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

class _TeamAssignment {
  const _TeamAssignment({
    required this.driverId,
    required this.driverName,
    required this.loader1Name,
    required this.loader2Name,
    required this.expectedArrival,
  });

  final String driverId;
  final String driverName;
  final String loader1Name;
  final String loader2Name;
  final DateTime expectedArrival;
}

/// FR-10: form for picking a driver (from registered driver accounts), two
/// loader names, and an expected arrival time.
class _AssignTeamDialog extends StatefulWidget {
  const _AssignTeamDialog({required this.request});
  final ShipmentRequest request;

  @override
  State<_AssignTeamDialog> createState() => _AssignTeamDialogState();
}

class _AssignTeamDialogState extends State<_AssignTeamDialog> {
  final _loader1Controller = TextEditingController();
  final _loader2Controller = TextEditingController();
  String? _driverId;
  String? _driverName;
  DateTime? _expectedArrival;
  bool _loadingDrivers = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await AuthService.firestore.collection('users').where('role', isEqualTo: 'driver').get();
      if (!mounted) return;
      setState(() {
        _drivers = snapshot.docs;
        _loadingDrivers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  @override
  void dispose() {
    _loader1Controller.dispose();
    _loader2Controller.dispose();
    super.dispose();
  }

  Future<void> _pickExpectedArrival() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    setState(() {
      _expectedArrival = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (_driverId == null || _driverName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a driver.')));
      return;
    }
    if (_loader1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least Loader 1.')));
      return;
    }
    if (_expectedArrival == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an expected arrival time.')));
      return;
    }
    Navigator.of(context).pop(_TeamAssignment(
      driverId: _driverId!,
      driverName: _driverName!,
      loader1Name: _loader1Controller.text.trim(),
      loader2Name: _loader2Controller.text.trim(),
      expectedArrival: _expectedArrival!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Operational Team'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.request.pickupCity} \u2192 ${widget.request.destinationCity} \u00b7 ${widget.request.vehicleRegistrationNo}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              _loadingDrivers
                  ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  : _drivers.isEmpty
                      ? const Text(
                          'No driver accounts found. Register a driver account first.',
                          style: TextStyle(color: Color(0xFFDC2626)),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _driverId,
                          decoration: const InputDecoration(labelText: 'Driver', border: OutlineInputBorder()),
                          items: _drivers.map((doc) {
                            final data = doc.data();
                            final name = data['name'] as String? ?? doc.id;
                            return DropdownMenuItem(value: doc.id, child: Text(name));
                          }).toList(),
                          onChanged: (value) {
                            final match = _drivers.firstWhere((doc) => doc.id == value);
                            setState(() {
                              _driverId = value;
                              _driverName = (match.data()['name'] as String?) ?? value;
                            });
                          },
                        ),
              const SizedBox(height: 12),
              TextField(
                controller: _loader1Controller,
                decoration: const InputDecoration(labelText: 'Loader 1 name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _loader2Controller,
                decoration: const InputDecoration(labelText: 'Loader 2 name (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickExpectedArrival,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_expectedArrival == null ? 'Pick expected arrival time' : _formatDateTime(_expectedArrival!)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}