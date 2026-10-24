import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fleet_vehicle.dart';
import '../models/vehicle_category.dart';
import 'auth_service.dart';

/// Reads (and, for now, seeds) the `vehicleCategories` and `fleetVehicles`
/// collections that back the customer dashboard and fleet search. Writes
/// will move behind an admin-only role once fleet management is available;
/// for now, any authenticated user may seed sample data.
class CatalogService {
  static CollectionReference<Map<String, dynamic>> get _categories =>
      AuthService.firestore.collection('vehicleCategories');

  static CollectionReference<Map<String, dynamic>> get _vehicles =>
      AuthService.firestore.collection('fleetVehicles');

  /// Streams active vehicle categories for the dashboard grid.
  static Stream<List<VehicleCategory>> streamActiveCategories() {
    return _categories.where('isActive', isEqualTo: true).snapshots().map((snapshot) {
      final categories = snapshot.docs.map(VehicleCategory.fromDoc).toList();
      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return categories;
    });
  }

  /// Searches available vehicles by pickup/destination city, minimum load
  /// capacity, and urgency. City and capacity filters are applied
  /// client-side after a small server-side availability query, which is fine
  /// at this fleet size and avoids extra Firestore composite indexes.
  static Future<List<FleetVehicle>> searchVehicles({
    String? categoryId,
    String? pickupCity,
    String? destinationCity,
    double? minLoadKg,
    bool expressOnly = false,
  }) async {
    Query<Map<String, dynamic>> query = _vehicles.where('isAvailable', isEqualTo: true);
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    final snapshot = await query.get();
    var vehicles = snapshot.docs.map(FleetVehicle.fromDoc).toList();

    if (minLoadKg != null && minLoadKg > 0) {
      vehicles = vehicles.where((vehicle) => vehicle.capacityKg >= minLoadKg).toList();
    }
    if (expressOnly) {
      vehicles = vehicles.where((vehicle) => vehicle.supportsExpress).toList();
    }
    final pickup = pickupCity?.trim().toLowerCase() ?? '';
    if (pickup.isNotEmpty) {
      vehicles = vehicles
          .where((vehicle) => vehicle.serviceCities.any((city) => city.toLowerCase() == pickup))
          .toList();
    }
    final destination = destinationCity?.trim().toLowerCase() ?? '';
    if (destination.isNotEmpty) {
      vehicles = vehicles
          .where((vehicle) => vehicle.serviceCities.any((city) => city.toLowerCase() == destination))
          .toList();
    }

    vehicles.sort((a, b) => a.capacityKg.compareTo(b.capacityKg));
    return vehicles;
  }

  static Future<bool> catalogIsEmpty() async {
    final snapshot = await _categories.limit(1).get();
    return snapshot.docs.isEmpty;
  }

  /// One-time helper to populate demo categories and vehicles so the
  /// dashboard and search screens have Firestore data before an admin panel
  /// is available to manage the fleet.
  static Future<void> seedSampleCatalog() async {
    final batch = AuthService.firestore.batch();

    const categories = [
      {
        'name': 'Small Van',
        'description': 'Ideal for small parcels and light household items.',
        'minCapacityKg': 0,
        'maxCapacityKg': 1000,
        'baseFarePerKm': 80,
        'iconKey': 'van',
        'sortOrder': 1,
      },
      {
        'name': 'Medium Truck',
        'description': 'Suited for furniture, retail stock and mid-size cargo.',
        'minCapacityKg': 1000,
        'maxCapacityKg': 5000,
        'baseFarePerKm': 150,
        'iconKey': 'truck',
        'sortOrder': 2,
      },
      {
        'name': 'Refrigerated Truck',
        'description': 'Temperature-controlled transport for perishables and pharma.',
        'minCapacityKg': 2000,
        'maxCapacityKg': 8000,
        'baseFarePerKm': 220,
        'iconKey': 'refrigerated',
        'sortOrder': 3,
      },
      {
        'name': 'Heavy-Duty Truck',
        'description': 'For construction material, machinery and bulk freight.',
        'minCapacityKg': 8000,
        'maxCapacityKg': 20000,
        'baseFarePerKm': 300,
        'iconKey': 'heavy',
        'sortOrder': 4,
      },
    ];

    final categoryRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    final ratesByCategoryName = <String, int>{};
    for (final category in categories) {
      final ref = _categories.doc();
      batch.set(ref, {
        ...category,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      categoryRefs[category['name'] as String] = ref;
      ratesByCategoryName[category['name'] as String] = category['baseFarePerKm'] as int;
    }

    const vehicles = [
      {'category': 'Small Van', 'registrationNo': 'PSW-1201', 'capacityKg': 800.0, 'serviceCities': ['Peshawar', 'Islamabad'], 'supportsExpress': true},
      {'category': 'Small Van', 'registrationNo': 'PSW-1340', 'capacityKg': 950.0, 'serviceCities': ['Peshawar', 'Mardan'], 'supportsExpress': false},
      {'category': 'Medium Truck', 'registrationNo': 'ISB-3021', 'capacityKg': 3500.0, 'serviceCities': ['Islamabad', 'Lahore'], 'supportsExpress': true},
      {'category': 'Medium Truck', 'registrationNo': 'LHR-4410', 'capacityKg': 4800.0, 'serviceCities': ['Lahore', 'Karachi'], 'supportsExpress': false},
      {'category': 'Refrigerated Truck', 'registrationNo': 'KHI-5502', 'capacityKg': 6000.0, 'serviceCities': ['Karachi', 'Lahore'], 'supportsExpress': true},
      {'category': 'Refrigerated Truck', 'registrationNo': 'PSW-5590', 'capacityKg': 3000.0, 'serviceCities': ['Peshawar', 'Islamabad'], 'supportsExpress': false},
      {'category': 'Heavy-Duty Truck', 'registrationNo': 'LHR-7710', 'capacityKg': 15000.0, 'serviceCities': ['Lahore', 'Islamabad', 'Peshawar'], 'supportsExpress': false},
      {'category': 'Heavy-Duty Truck', 'registrationNo': 'KHI-7890', 'capacityKg': 18000.0, 'serviceCities': ['Karachi', 'Lahore'], 'supportsExpress': true},
    ];

    for (final vehicle in vehicles) {
      final categoryRef = categoryRefs[vehicle['category'] as String]!;
      final ref = _vehicles.doc();
      batch.set(ref, {
        'categoryId': categoryRef.id,
        'categoryName': vehicle['category'],
        'baseFarePerKm': ratesByCategoryName[vehicle['category']] ?? 0,
        'registrationNo': vehicle['registrationNo'],
        'capacityKg': vehicle['capacityKg'],
        'serviceCities': vehicle['serviceCities'],
        'supportsExpress': vehicle['supportsExpress'],
        'isAvailable': true,
        'driverId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
