import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer's submitted logistics request (FR-06). Starts life with
/// status `pending`; FR-07 (admin review) adds `approved`/`rejected`
/// transitions plus `reviewedAt`/`reviewedBy`; FR-08/FR-11 add
/// commitment-fee tracking and auto-cancellation; FR-10 adds the assigned
/// operational team (driver + loaders + expected arrival), at which point
/// status becomes `assigned` and FR-09 shows this breakdown to the customer.
class ShipmentRequest {
  const ShipmentRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.vehicleId,
    required this.vehicleRegistrationNo,
    required this.categoryId,
    required this.categoryName,
    required this.pickupCity,
    required this.destinationCity,
    required this.distanceKm,
    required this.urgency,
    required this.goodsType,
    required this.estimatedWeightKg,
    required this.addOns,
    required this.totalQuote,
    required this.status,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    this.commitmentFeeAmount,
    this.commitmentFeeStatus,
    this.commitmentFeeDueAt,
    this.commitmentFeePaidAt,
    this.paymentId,
    this.pickupPaymentAmount,
    this.pickupPaymentStatus,
    this.pickupPaymentId,
    this.deliveryPaymentAmount,
    this.deliveryPaymentStatus,
    this.deliveryPaymentId,
    this.proofOfDelivery,
    this.deliveredAt,
    this.cancelReason,
    this.driverId,
    this.driverName,
    this.loader1Name,
    this.loader2Name,
    this.expectedArrivalAt,
    this.assignedAt,
    this.scheduledPickupAt,
    this.cancellationFeeAmount,
    this.createdAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String vehicleId;
  final String vehicleRegistrationNo;
  final String categoryId;
  final String categoryName;
  final String pickupCity;
  final String destinationCity;
  final double distanceKm;
  final String urgency;
  final String goodsType;
  final double estimatedWeightKg;
  final Map<String, bool> addOns;
  final double totalQuote;
  final String status; // pending | approved | rejected | cancelled | assigned
  final String? rejectionReason;
  final Timestamp? reviewedAt;
  final String? reviewedBy;
  // FR-08 / FR-11: commitment (deposit) fee tracking.
  final double? commitmentFeeAmount;
  final String? commitmentFeeStatus; // null | 'unpaid' | 'paid' | 'expired'
  final Timestamp? commitmentFeeDueAt;
  final Timestamp? commitmentFeePaidAt;
  final String? paymentId;
  final double? pickupPaymentAmount;
  final String? pickupPaymentStatus;
  final String? pickupPaymentId;
  final double? deliveryPaymentAmount;
  final String? deliveryPaymentStatus;
  final String? deliveryPaymentId;
  final Map<String, dynamic>? proofOfDelivery;
  final Timestamp? deliveredAt;
  final String? cancelReason;
  // FR-09 / FR-10: assigned operational team.
  final String? driverId;
  final String? driverName;
  final String? loader1Name;
  final String? loader2Name;
  final Timestamp? expectedArrivalAt;
  final Timestamp? assignedAt;
  final Timestamp? scheduledPickupAt;
  final double? cancellationFeeAmount;
  final Timestamp? createdAt;

  factory ShipmentRequest.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawAddOns = data['addOns'] as Map<String, dynamic>? ?? const {};
    return ShipmentRequest(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      vehicleRegistrationNo: data['vehicleRegistrationNo'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      pickupCity: data['pickupCity'] as String? ?? '',
      destinationCity: data['destinationCity'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      urgency: data['urgency'] as String? ?? 'standard',
      goodsType: data['goodsType'] as String? ?? '',
      estimatedWeightKg: (data['estimatedWeightKg'] as num?)?.toDouble() ?? 0,
      addOns: rawAddOns.map((key, value) => MapEntry(key, value as bool? ?? false)),
      totalQuote: (data['totalQuote'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'pending',
      rejectionReason: data['rejectionReason'] as String?,
      reviewedAt: data['reviewedAt'] as Timestamp?,
      reviewedBy: data['reviewedBy'] as String?,
      commitmentFeeAmount: (data['commitmentFeeAmount'] as num?)?.toDouble(),
      commitmentFeeStatus: data['commitmentFeeStatus'] as String?,
      commitmentFeeDueAt: data['commitmentFeeDueAt'] as Timestamp?,
      commitmentFeePaidAt: data['commitmentFeePaidAt'] as Timestamp?,
      paymentId: data['paymentId'] as String?,
      pickupPaymentAmount: (data['pickupPaymentAmount'] as num?)?.toDouble(),
      pickupPaymentStatus: data['pickupPaymentStatus'] as String?,
      pickupPaymentId: data['pickupPaymentId'] as String?,
      deliveryPaymentAmount: (data['deliveryPaymentAmount'] as num?)?.toDouble(),
      deliveryPaymentStatus: data['deliveryPaymentStatus'] as String?,
      deliveryPaymentId: data['deliveryPaymentId'] as String?,
      proofOfDelivery: data['proofOfDelivery'] as Map<String, dynamic>?,
      deliveredAt: data['deliveredAt'] as Timestamp?,
      cancelReason: data['cancelReason'] as String?,
      driverId: data['driverId'] as String?,
      driverName: data['driverName'] as String?,
      loader1Name: data['loader1Name'] as String?,
      loader2Name: data['loader2Name'] as String?,
      expectedArrivalAt: data['expectedArrivalAt'] as Timestamp?,
      assignedAt: data['assignedAt'] as Timestamp?,
      scheduledPickupAt: data['scheduledPickupAt'] as Timestamp?,
      cancellationFeeAmount: (data['cancellationFeeAmount'] as num?)?.toDouble(),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}