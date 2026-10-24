import 'dart:math' as math;

/// Line-item breakdown of an automated price quote.
class PricingBreakdown {
  const PricingBreakdown({
    required this.distanceKm,
    required this.distanceCharge,
    required this.weightCharge,
    required this.subtotal,
    required this.isExpress,
    required this.urgencySurcharge,
    required this.addOnCharges,
    required this.addOnsTotal,
    required this.totalQuote,
  });

  final double distanceKm;
  final double distanceCharge;
  final double weightCharge;
  final double subtotal;
  final bool isExpress;
  final double urgencySurcharge;
  final Map<String, double> addOnCharges;
  final double addOnsTotal;
  final double totalQuote;
}

/// Computes an automated price quote: distance ×
/// vehicle rate, plus a weight-based charge, an express-delivery surcharge,
/// and any selected value-added services. Rates are centralized
/// here as named constants so they're easy to tune for the FYP write-up
/// without touching the UI.
class PricingService {
  static const double weightRatePerKg = 0.5; // PKR per kg of estimated cargo
  static const double expressSurchargeRate = 0.25; // 25% of subtotal

  static const double fragileHandlingFee = 500;
  static const double insuranceRate = 0.02; // 2% of subtotal
  static const double insuranceMinFee = 300;
  static const double packingFee = 800;
  static const double laborFee = 600;

  static PricingBreakdown calculate({
    required double distanceKm,
    required double baseFarePerKm,
    required double estimatedWeightKg,
    required bool isExpress,
    required bool fragileHandling,
    required bool insurance,
    required bool packing,
    required bool labor,
  }) {
    final safeDistance = distanceKm < 0 ? 0.0 : distanceKm;
    final safeWeight = estimatedWeightKg < 0 ? 0.0 : estimatedWeightKg;

    final distanceCharge = safeDistance * baseFarePerKm;
    final weightCharge = safeWeight * weightRatePerKg;
    final subtotal = distanceCharge + weightCharge;
    final urgencySurcharge = isExpress ? subtotal * expressSurchargeRate : 0.0;

    final addOnCharges = <String, double>{};
    if (fragileHandling) addOnCharges['Fragile Handling'] = fragileHandlingFee;
    if (insurance) addOnCharges['Insurance Coverage'] = math.max(subtotal * insuranceRate, insuranceMinFee);
    if (packing) addOnCharges['Professional Packing'] = packingFee;
    if (labor) addOnCharges['Labor for Loading/Unloading'] = laborFee;
    final addOnsTotal = addOnCharges.values.fold<double>(0, (a, b) => a + b);

    final total = subtotal + urgencySurcharge + addOnsTotal;

    return PricingBreakdown(
      distanceKm: safeDistance,
      distanceCharge: distanceCharge,
      weightCharge: weightCharge,
      subtotal: subtotal,
      isExpress: isExpress,
      urgencySurcharge: urgencySurcharge,
      addOnCharges: addOnCharges,
      addOnsTotal: addOnsTotal,
      totalQuote: total,
    );
  }
}