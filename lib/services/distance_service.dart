/// Estimates road distance between two cities.
///
/// This is a deliberate placeholder: without a Google Maps/Directions API
/// key, we can't compute a real routed distance, so FR-05's price quote
/// uses a small lookup table of known city pairs (with a generic fallback
/// for anything else) and lets the customer see and override the value.
/// Swap this for a Directions API call once billing/API access is sorted
/// out with your supervisor — the call sites (BookingPage) don't need to
/// change, only this class.
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

  static double estimateKm(String pickupCity, String destinationCity) {
    final pickup = pickupCity.trim().toLowerCase();
    final destination = destinationCity.trim().toLowerCase();
    if (pickup.isEmpty || destination.isEmpty) return 0;
    if (pickup == destination) return _sameCityDistanceKm;
    return _distancesKm['$pickup|$destination'] ?? _distancesKm['$destination|$pickup'] ?? _defaultDistanceKm;
  }
}