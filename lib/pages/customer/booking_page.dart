import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/fleet_vehicle.dart';
import '../../services/auth_service.dart';
import '../../services/distance_service.dart';
import '../../services/pricing_service.dart';
import 'my_requests_page.dart';

/// FR-04 Booking and Service Selection + FR-05 Load Customization and Price
/// Quote + FR-06 Shipment Request Submission, combined into one flow since
/// the quote needs everything the customer enters on this screen.
///
/// Pickup/drop-off are plain city fields rather than a map pin-drop for now
/// (no Google Maps API key configured yet); swap in a map widget here once
/// that's sorted out, the rest of the flow doesn't need to change.
class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    required this.vehicle,
    this.initialPickupCity = '',
    this.initialDestinationCity = '',
    this.initialUrgency = 'standard',
    this.initialWeightKg,
  });

  final FleetVehicle vehicle;
  final String initialPickupCity;
  final String initialDestinationCity;
  final String initialUrgency;
  final double? initialWeightKg;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  late final _pickupController = TextEditingController(text: widget.initialPickupCity);
  late final _destinationController = TextEditingController(text: widget.initialDestinationCity);
  final _distanceController = TextEditingController();
  final _goodsTypeController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  late final _weightController = TextEditingController(
    text: (widget.initialWeightKg != null && widget.initialWeightKg! > 0) ? widget.initialWeightKg!.toStringAsFixed(0) : '',
  );
  late String _urgency = widget.initialUrgency;
  bool _fragileHandling = false;
  bool _insurance = false;
  bool _packing = false;
  bool _labor = false;
  bool _submitting = false;

  List<TextEditingController> get _liveControllers => [
        _pickupController,
        _destinationController,
        _distanceController,
        _weightController,
      ];

  @override
  void initState() {
    super.initState();
    _distanceController.text = DistanceService.estimateKm(widget.initialPickupCity, widget.initialDestinationCity).toStringAsFixed(0);
    for (final controller in _liveControllers) {
      controller.addListener(_onLiveFieldChanged);
    }
  }

  void _onLiveFieldChanged() => setState(() {});

  @override
  void dispose() {
    for (final controller in _liveControllers) {
      controller.removeListener(_onLiveFieldChanged);
    }
    _pickupController.dispose();
    _destinationController.dispose();
    _distanceController.dispose();
    _goodsTypeController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _autoEstimateDistance() {
    final estimate = DistanceService.estimateKm(_pickupController.text, _destinationController.text);
    _distanceController.text = estimate.toStringAsFixed(0);
  }

  PricingBreakdown _breakdown() {
    return PricingService.calculate(
      distanceKm: double.tryParse(_distanceController.text.trim()) ?? 0,
      baseFarePerKm: widget.vehicle.baseFarePerKm,
      estimatedWeightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      isExpress: _urgency == 'express',
      fragileHandling: _fragileHandling,
      insurance: _insurance,
      packing: _packing,
      labor: _labor,
    );
  }

  String _money(double value) => 'Rs ${value.toStringAsFixed(0)}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final breakdown = _breakdown();
    setState(() => _submitting = true);
    try {
      final user = AuthService.auth.currentUser;
      if (user == null) throw StateError('You must be logged in to submit a request.');
      final profile = await AuthService.fetchProfile();
      await AuthService.firestore.collection('shipmentRequests').add({
        'customerId': user.uid,
        'customerName': profile['name'] ?? '',
        'customerEmail': profile['email'] ?? user.email ?? '',
        'vehicleId': widget.vehicle.id,
        'vehicleRegistrationNo': widget.vehicle.registrationNo,
        'categoryId': widget.vehicle.categoryId,
        'categoryName': widget.vehicle.categoryName,
        'pickupCity': _pickupController.text.trim(),
        'destinationCity': _destinationController.text.trim(),
        'distanceKm': breakdown.distanceKm,
        'urgency': _urgency,
        'goodsType': _goodsTypeController.text.trim(),
        'lengthCm': double.tryParse(_lengthController.text.trim()),
        'widthCm': double.tryParse(_widthController.text.trim()),
        'heightCm': double.tryParse(_heightController.text.trim()),
        'estimatedWeightKg': double.tryParse(_weightController.text.trim()) ?? 0,
        'addOns': {
          'fragileHandling': _fragileHandling,
          'insurance': _insurance,
          'packing': _packing,
          'labor': _labor,
        },
        'priceBreakdown': {
          'distanceCharge': breakdown.distanceCharge,
          'weightCharge': breakdown.weightCharge,
          'subtotal': breakdown.subtotal,
          'urgencySurcharge': breakdown.urgencySurcharge,
          'addOnCharges': breakdown.addOnCharges,
        },
        'totalQuote': breakdown.totalQuote,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await _showSubmittedDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit request: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSubmittedDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF0F766E), size: 40),
        title: const Text('Request submitted'),
        content: const Text('Your logistics request is now pending admin approval. We will notify you once it is reviewed.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to dashboard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyRequestsPage()));
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            child: const Text('View my requests'),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {String? suffixText}) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon), suffixText: suffixText);

  String? _required(String? value, String message) => value == null || value.trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    final breakdown = _breakdown();
    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.vehicle.registrationNo}'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: const Color(0xFFECFEFF),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const Icon(Icons.info_outline, color: Color(0xFF0F766E)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pickup and drop-off use city names for now. Map pin selection will replace this once a Google Maps API key is available.',
                              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Pickup & route',
                      children: [
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pickupController,
                              decoration: _decoration('Pickup city', Icons.trip_origin),
                              validator: (v) => _required(v, 'Enter pickup city'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _destinationController,
                              decoration: _decoration('Destination city', Icons.flag_outlined),
                              validator: (v) => _required(v, 'Enter destination city'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: TextFormField(
                              controller: _distanceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                              decoration: _decoration('Estimated distance', Icons.route_outlined, suffixText: 'km'),
                              validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Enter or estimate distance' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: OutlinedButton.icon(
                              onPressed: _autoEstimateDistance,
                              icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                              label: const Text('Auto-estimate'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          'Placeholder estimate from a city lookup table until FR-17 GPS routing is wired in — feel free to adjust.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'standard', label: Text('Standard'), icon: Icon(Icons.schedule_outlined)),
                            ButtonSegment(value: 'express', label: Text('Express'), icon: Icon(Icons.bolt_outlined)),
                          ],
                          selected: {_urgency},
                          onSelectionChanged: (value) => setState(() => _urgency = value.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Cargo details',
                      children: [
                        TextFormField(
                          controller: _goodsTypeController,
                          decoration: _decoration('Type of goods (e.g. Furniture, Electronics)', Icons.inventory_2_outlined),
                          validator: (v) => _required(v, 'Describe the goods being shipped'),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lengthController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _decoration('Length', Icons.straighten_outlined, suffixText: 'cm'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _widthController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _decoration('Width', Icons.straighten_outlined, suffixText: 'cm'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _decoration('Height', Icons.straighten_outlined, suffixText: 'cm'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                          decoration: _decoration('Estimated weight', Icons.scale_outlined, suffixText: 'kg'),
                          validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Enter estimated weight' : null,
                        ),
                        if ((double.tryParse(_weightController.text.trim()) ?? 0) > widget.vehicle.capacityKg) ...[
                          const SizedBox(height: 8),
                          Text(
                            'This exceeds the ${widget.vehicle.registrationNo} capacity of ${widget.vehicle.capacityKg.toStringAsFixed(0)} kg — consider a larger vehicle.',
                            style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Value-added services',
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _fragileHandling,
                          onChanged: (v) => setState(() => _fragileHandling = v ?? false),
                          title: const Text('Fragile Handling'),
                          subtitle: Text('Flat fee: ${_money(PricingService.fragileHandlingFee)}'),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _insurance,
                          onChanged: (v) => setState(() => _insurance = v ?? false),
                          title: const Text('Insurance Coverage'),
                          subtitle: Text('2% of subtotal, minimum ${_money(PricingService.insuranceMinFee)}'),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _packing,
                          onChanged: (v) => setState(() => _packing = v ?? false),
                          title: const Text('Professional Packing'),
                          subtitle: Text('Flat fee: ${_money(PricingService.packingFee)}'),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _labor,
                          onChanged: (v) => setState(() => _labor = v ?? false),
                          title: const Text('Labor for Loading/Unloading'),
                          subtitle: Text('Flat fee: ${_money(PricingService.laborFee)}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFF0F172A),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Price quote', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            _quoteRow('Distance (${breakdown.distanceKm.toStringAsFixed(0)} km × Rs ${widget.vehicle.baseFarePerKm.toStringAsFixed(0)}/km)', breakdown.distanceCharge),
                            _quoteRow('Weight charge', breakdown.weightCharge),
                            const Divider(color: Colors.white24, height: 20),
                            _quoteRow('Subtotal', breakdown.subtotal, emphasize: true),
                            if (breakdown.isExpress) _quoteRow('Express surcharge (25%)', breakdown.urgencySurcharge),
                            for (final entry in breakdown.addOnCharges.entries) _quoteRow(entry.key, entry.value),
                            const Divider(color: Colors.white24, height: 20),
                            _quoteRow('Total quote', breakdown.totalQuote, emphasize: true, big: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: const Icon(Icons.send_rounded),
                        label: _submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit logistics request'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF0F766E)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitting sends this request for admin review (FR-07). No payment is taken yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quoteRow(String label, double amount, {bool emphasize = false, bool big = false}) {
    final style = TextStyle(
      color: Colors.white,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400,
      fontSize: big ? 20 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style.copyWith(color: Colors.white.withValues(alpha: emphasize ? 1 : 0.85)))),
          Text(_money(amount), style: style),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}