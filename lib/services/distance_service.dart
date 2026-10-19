import 'dart:convert';

import 'package:http/http.dart' as http;

/// Gets a routed distance from OpenStreetMap's Nominatim + OSRM services.
/// The local table remains a fast offline fallback when a provider is
/// unavailable or a city cannot be geocoded.
class DistanceService {
  static const Map<String, double> _distancesKm = {
    'peshawar|islamabad': 170,
    'peshawar|lahore': 480,
    'peshawar|karachi': 1650,
    'peshawar|mardan': 65,
    'islamabad|lahore': 375,
    'islamabad|karachi': 1400,
    'islamabad|mardan': 210,
    'lahore|karachi': 1235,
    'lahore|mardan': 550,
    'karachi|mardan': 1700,
  };

  static const double _sameCityDistanceKm = 15;
  static const double _defaultDistanceKm = 300;

  static double fallbackKm(String pickupCity, String destinationCity) {
    final pickup = pickupCity.trim().toLowerCase();
    final destination = destinationCity.trim().toLowerCase();
    if (pickup.isEmpty || destination.isEmpty) return 0;
    if (pickup == destination) return _sameCityDistanceKm;
    return _distancesKm['$pickup|$destination'] ?? _distancesKm['$destination|$pickup'] ?? _defaultDistanceKm;
  }

  static double estimateKm(String pickupCity, String destinationCity) {
    return fallbackKm(pickupCity, destinationCity);
  }

  static Future<({double latitude, double longitude})?> geocodeCity(String city) {
    return _geocode(city);
  }

  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'jsonv2',
        'zoom': '10',
      });
      final response = await http.get(uri, headers: {'User-Agent': 'SFLMS/1.0 logistics app'}).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final address = (jsonDecode(response.body) as Map<String, dynamic>)['address'] as Map<String, dynamic>?;
      return address?['city'] as String? ?? address?['town'] as String? ?? address?['municipality'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<double> routeDistanceKm(String pickupCity, String destinationCity) async {
    final fallback = fallbackKm(pickupCity, destinationCity);
    if (pickupCity.trim().isEmpty || destinationCity.trim().isEmpty) return fallback;
    try {
      final pickup = await _geocode(pickupCity);
      final destination = await _geocode(destinationCity);
      if (pickup == null || destination == null) return fallback;
      final routeUri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickup.longitude},${pickup.latitude};${destination.longitude},${destination.latitude}?overview=false',
      );
      final response = await http.get(routeUri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return fallback;
      final routes = (jsonDecode(response.body) as Map<String, dynamic>)['routes'] as List<dynamic>?;
      final meters = routes?.isNotEmpty == true ? (routes!.first as Map<String, dynamic>)['distance'] as num? : null;
      return meters == null ? fallback : meters / 1000;
    } catch (_) {
      return fallback;
    }
  }

  static Future<({double latitude, double longitude})?> _geocode(String city) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$city, Pakistan',
      'format': 'jsonv2',
      'limit': '1',
    });
    final response = await http.get(uri, headers: {'User-Agent': 'SFLMS/1.0 logistics app'}).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final places = jsonDecode(response.body) as List<dynamic>;
    if (places.isEmpty) return null;
    final place = places.first as Map<String, dynamic>;
    final latitude = double.tryParse(place['lat'] as String? ?? '');
    final longitude = double.tryParse(place['lon'] as String? ?? '');
    return latitude == null || longitude == null ? null : (latitude: latitude, longitude: longitude);
  }
}