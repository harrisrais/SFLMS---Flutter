import 'package:cloud_firestore/cloud_firestore.dart';

import 'vehicle_category.dart';

/// A fleet vehicle searchable by route, load capacity, and urgency.
/// Assignment fields are populated by the admin task-assignment workflow.
class FleetVehicle {
  const FleetVehicle({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.registrationNo,
    required this.capacityKg,
    required this.baseFarePerKm,
    required this.serviceCities,
    required this.supportsExpress,
    required this.isAvailable,
    this.driverId,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String registrationNo;
  final double capacityKg;
  final double baseFarePerKm;
  final List<String> serviceCities;
  final bool supportsExpress;
  final bool isAvailable;
  final String? driverId;

  static double resolveBaseFarePerKm({required String categoryName, num? storedRate}) {
    final rate = storedRate?.toDouble() ?? 0;
    return rate > 0 ? rate : VehicleCategory.defaultRatePerKmFor(categoryName);
  }

  factory FleetVehicle.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final categoryName = data['categoryName'] as String? ?? 'Vehicle';
    return FleetVehicle(
      id: doc.id,
      categoryId: data['categoryId'] as String? ?? '',
      categoryName: categoryName,
      registrationNo: data['registrationNo'] as String? ?? '—',
      capacityKg: (data['capacityKg'] as num?)?.toDouble() ?? 0,
      baseFarePerKm: resolveBaseFarePerKm(
        categoryName: categoryName,
        storedRate: data['baseFarePerKm'] as num?,
      ),
      serviceCities: (data['serviceCities'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      supportsExpress: data['supportsExpress'] as bool? ?? false,
      isAvailable: data['isAvailable'] as bool? ?? false,
      driverId: data['driverId'] as String?,
    );
  }
}