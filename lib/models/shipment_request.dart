import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer's submitted logistics request (FR-06). Starts life with
/// status `pending`; FR-07 (admin review) adds `approved`/`rejected`
/// transitions, and later phases add payment and delivery statuses on top.
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
  final String status;
  final String? rejectionReason;
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
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}