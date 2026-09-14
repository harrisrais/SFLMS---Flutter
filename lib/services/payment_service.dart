import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shipment_request.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Mock payment gateway for FR-08 (Commitment Fee) and, later, FR-13/FR-14's
/// staged payments. `payCommitmentFee` just marks the fee paid — swap its
/// body for a real JazzCash/EasyPaisa REST call once merchant access is
/// sorted out; nothing that calls this service needs to change.
class PaymentService {
  static Future<void> payCommitmentFee(String requestId) {
    return AuthService.firestore
        .collection('shipmentRequests')
        .doc(requestId)
        .update({
          'commitmentFeeStatus': 'paid',
          'commitmentFeePaidAt': FieldValue.serverTimestamp(),
        });
  }

  /// FR-11 Auto-Cancellation Logic: if an approved request's commitment fee
  /// is still unpaid past its 24-hour due time, cancel it and free the
  /// vehicle slot. There's no real scheduled backend job here — a proper
  /// cron needs a Cloud Function on the paid Blaze plan — so this runs
  /// opportunistically whenever a customer screen loads the request.
  static Future<void> expireIfOverdue(ShipmentRequest request) async {
    if (request.status != 'approved') return;
    if (request.commitmentFeeStatus != 'unpaid') return;
    final dueAt = request.commitmentFeeDueAt?.toDate();
    if (dueAt == null || DateTime.now().isBefore(dueAt)) return;

    await AuthService.firestore
        .collection('shipmentRequests')
        .doc(request.id)
        .update({
          'status': 'cancelled',
          'commitmentFeeStatus': 'expired',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelReason': 'Commitment fee not paid within 24 hours.',
        });
    await NotificationService.create(
      userId: request.customerId,
      title: 'Booking auto-cancelled',
      body:
          'Your ${request.pickupCity} \u2192 ${request.destinationCity} booking was cancelled because '
          'the commitment fee was not paid within 24 hours.',
      type: 'cancelled',
      requestId: request.id,
    );
  }
}
