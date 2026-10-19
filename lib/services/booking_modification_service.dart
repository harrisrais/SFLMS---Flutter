import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shipment_request.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class BookingModificationService {
  static const modificationCutoff = Duration(hours: 12);

  static double cancellationFeeRate(DateTime pickupAt, {DateTime? now}) {
    final hours = pickupAt.difference(now ?? DateTime.now()).inMinutes / 60;
    if (hours >= 48) return 0;
    if (hours >= 24) return .10;
    if (hours >= 12) return .25;
    return 1;
  }

  static bool canModify(ShipmentRequest request, {DateTime? now}) {
    final pickup = request.scheduledPickupAt?.toDate();
    return pickup != null && pickup.difference(now ?? DateTime.now()) > modificationCutoff &&
        {'pending', 'approved', 'assigned'}.contains(request.status);
  }

  static Future<void> reschedule(ShipmentRequest request, DateTime pickupAt) async {
    if (!canModify(request)) throw StateError('Bookings can only be changed more than 12 hours before pickup.');
    if (pickupAt.difference(DateTime.now()) <= modificationCutoff) {
      throw StateError('Choose a pickup time more than 12 hours from now.');
    }
    await AuthService.firestore.collection('shipmentRequests').doc(request.id).update({
      'scheduledPickupAt': Timestamp.fromDate(pickupAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await NotificationService.create(
      userId: request.customerId,
      title: 'Booking rescheduled',
      body: 'Your ${request.pickupCity} to ${request.destinationCity} pickup was rescheduled to ${pickupAt.toLocal()}.',
      type: 'rescheduled',
      requestId: request.id,
    );
  }

  static Future<void> cancel(ShipmentRequest request) async {
    if (!canModify(request)) throw StateError('Bookings can only be cancelled more than 12 hours before pickup.');
    final rate = cancellationFeeRate(request.scheduledPickupAt!.toDate());
    await AuthService.firestore.collection('shipmentRequests').doc(request.id).update({
      'status': 'cancelled',
      'cancellationFeeAmount': request.totalQuote * rate,
      'cancelReason': 'Cancelled by customer (${(rate * 100).toStringAsFixed(0)}% cancellation fee).',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    await NotificationService.create(
      userId: request.customerId,
      title: 'Booking cancelled',
      body: 'Your booking was cancelled. Cancellation fee: Rs ${(request.totalQuote * rate).toStringAsFixed(0)}.',
      type: 'cancelled',
      requestId: request.id,
    );
  }
}