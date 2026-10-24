import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shipment_request.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Mock payment gateway for the commitment fee and staged payments.
/// `payCommitmentFee` records the fee as paid — swap its
/// body for a real JazzCash/EasyPaisa REST call once merchant access is
/// sorted out; nothing that calls this service needs to change.
class PaymentService {
  static Future<String> payCommitmentFee(String requestId, {required double amount}) async {
    final payment = await AuthService.firestore.collection('payments').add({
      'requestId': requestId,
      'userId': AuthService.auth.currentUser?.uid,
      'amount': amount,
      'method': 'mock_gateway',
      'status': 'pending_verification',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await AuthService.firestore.collection('shipmentRequests').doc(requestId).update({
      'commitmentFeeStatus': 'pending_verification',
      'paymentId': payment.id,
    });
    return payment.id;
  }

  static Future<String> payStage({required ShipmentRequest request, required String stage, required double amount}) async {
    final payment = await AuthService.firestore.collection('payments').add({
      'requestId': request.id,
      'userId': AuthService.auth.currentUser?.uid,
      'amount': amount,
      'stage': stage,
      'method': 'mock_gateway',
      'status': 'pending_verification',
      'createdAt': FieldValue.serverTimestamp(),
    });
    final fieldPrefix = stage == 'pickup' ? 'pickup' : 'delivery';
    await AuthService.firestore.collection('shipmentRequests').doc(request.id).update({
      '${fieldPrefix}PaymentAmount': amount,
      '${fieldPrefix}PaymentStatus': 'pending_verification',
      '${fieldPrefix}PaymentId': payment.id,
    });
    return payment.id;
  }

  static Future<void> verifyPayment({required String requestId, required String paymentId}) async {
    final paymentRef = AuthService.firestore.collection('payments').doc(paymentId);
    final payment = await paymentRef.get();
    final stage = payment.data()?['stage'] as String? ?? 'commitment';
    final batch = AuthService.firestore.batch();
    batch.update(paymentRef, {
      'status': 'verified',
      'verifiedBy': AuthService.auth.currentUser?.uid,
      'verifiedAt': FieldValue.serverTimestamp(),
    });
    final requestRef = AuthService.firestore.collection('shipmentRequests').doc(requestId);
    if (stage == 'pickup') {
      batch.update(requestRef, {'pickupPaymentStatus': 'paid', 'pickupPaymentPaidAt': FieldValue.serverTimestamp()});
    } else if (stage == 'delivery') {
      batch.update(requestRef, {'deliveryPaymentStatus': 'paid', 'deliveryPaymentPaidAt': FieldValue.serverTimestamp()});
    } else {
      batch.update(requestRef, {'commitmentFeeStatus': 'paid', 'commitmentFeePaidAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    final request = await AuthService.firestore.collection('shipmentRequests').doc(requestId).get();
    final data = request.data();
    if (data != null && (data['customerId'] as String?) != null) {
      await NotificationService.create(
        userId: data['customerId'] as String,
        title: stage == 'commitment' ? 'Booking confirmed' : '${stage[0].toUpperCase()}${stage.substring(1)} payment verified',
        body: stage == 'pickup'
          ? 'Your pickup payment was verified. The driver can now continue your shipment.'
          : stage == 'delivery'
            ? 'Your final delivery payment was verified. Thank you.'
            : 'Your commitment fee was verified and your booking is now confirmed.',
        type: '${stage}_payment_verified',
        requestId: requestId,
      );
    }
  }

  /// If an approved request's commitment fee is still unpaid past its
  /// 24-hour due time, cancel it and free the
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

  /// Lightweight client-side reminder for the school/demo deployment. The
  /// scheduled Cloud Function can also perform this in a production setup,
  /// but the app remains functional without billing or server deployment.
  static Future<void> remindIfDueSoon(ShipmentRequest request) async {
    if (request.status != 'approved' || request.commitmentFeeStatus != 'unpaid') return;
    final dueAt = request.commitmentFeeDueAt?.toDate();
    if (dueAt == null) return;
    final remaining = dueAt.difference(DateTime.now());
    if (remaining.isNegative || remaining > const Duration(hours: 6)) return;
    final ref = AuthService.firestore.collection('shipmentRequests').doc(request.id);
    final latest = await ref.get();
    if (latest.data()?['paymentReminderSentAt'] != null) return;
    await ref.update({'paymentReminderSentAt': FieldValue.serverTimestamp()});
    await NotificationService.create(
      userId: request.customerId,
      title: 'Payment reminder',
      body: 'Your commitment fee for ${request.pickupCity} to ${request.destinationCity} is due soon.',
      type: 'payment_reminder',
      requestId: request.id,
    );
  }
}
