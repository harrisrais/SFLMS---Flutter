import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A category of fleet vehicle shown on the customer dashboard and used to
/// scope search results.
class VehicleCategory {
  static const Map<String, double> defaultRatesPerKm = {
    'small van': 80,
    'medium truck': 150,
    'refrigerated truck': 220,
    'heavy-duty truck': 300,
  };

  static double defaultRatePerKmFor(String categoryName) =>
      defaultRatesPerKm[categoryName.trim().toLowerCase()] ?? 0;

  const VehicleCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.minCapacityKg,
    required this.maxCapacityKg,
    required this.baseFarePerKm,
    required this.iconKey,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String description;
  final double minCapacityKg;
  final double maxCapacityKg;
  final double baseFarePerKm;
  final String iconKey;
  final bool isActive;
  final int sortOrder;

  factory VehicleCategory.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return VehicleCategory(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed category',
      description: data['description'] as String? ?? '',
      minCapacityKg: (data['minCapacityKg'] as num?)?.toDouble() ?? 0,
      maxCapacityKg: (data['maxCapacityKg'] as num?)?.toDouble() ?? 0,
      baseFarePerKm: (data['baseFarePerKm'] as num?)?.toDouble() ?? 0,
      iconKey: data['iconKey'] as String? ?? 'truck',
      isActive: data['isActive'] as bool? ?? true,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  String get capacityRangeLabel {
    if (maxCapacityKg >= 1000) {
      final minTons = minCapacityKg / 1000;
      final maxTons = maxCapacityKg / 1000;
      String fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      return '${fmt(minTons)}–${fmt(maxTons)} tons';
    }
    return '${minCapacityKg.toInt()}–${maxCapacityKg.toInt()} kg';
  }

  IconData get icon {
    switch (iconKey) {
      case 'van':
        return Icons.airport_shuttle_outlined;
      case 'refrigerated':
        return Icons.ac_unit_outlined;
      case 'heavy':
        return Icons.fire_truck_outlined;
      case 'truck':
      default:
        return Icons.local_shipping_outlined;
    }
  }
}
