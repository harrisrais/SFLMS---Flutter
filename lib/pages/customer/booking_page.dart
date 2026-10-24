import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/fleet_vehicle.dart';
import '../../services/auth_service.dart';
import '../../services/distance_service.dart';
import '../../services/pricing_service.dart';
import 'my_requests_page.dart';
import 'map_picker_page.dart';

/// Combines booking details, cargo customization, price quote, and request
/// submission into one flow.
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
  bool _routing = false;
  late DateTime _scheduledPickup = DateTime.now().add(const Duration(days: 1));

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

  Future<void> _autoEstimateDistance() async {
    setState(() => _routing = true);
    final estimate = await DistanceService.routeDistanceKm(_pickupController.text, _destinationController.text);
    if (mounted) {
      _distanceController.text = estimate.toStringAsFixed(1);
      setState(() => _routing = false);
    }
  }

  Future<void> _pickLocation({required bool pickup}) async {
    final result = await Navigator.of(context).push<MapSelection>(
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          title: pickup ? 'Choose pickup location' : 'Choose destination',
          initialCity: pickup ? _pickupController.text : _destinationController.text,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final controller = pickup ? _pickupController : _destinationController;
    controller.text = result.city;
    await _autoEstimateDistance();
  }

  Future<void> _choosePickupTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(hours: 12)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      initialDate: _scheduledPickup,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledPickup));
    if (time == null) return;
    setState(() => _scheduledPickup = DateTime(date.year, date.month, date.day, time.hour, time.minute));
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
        'scheduledPickupAt': Timestamp.fromDate(_scheduledPickup),
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
                              'Choose a city by searching or tapping the OpenStreetMap map. Routing uses OSRM with an offline fallback.',
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
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickLocation(pickup: true),
                                icon: const Icon(Icons.location_searching_outlined),
                                label: const Text('Pick on map'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickLocation(pickup: false),
                                icon: const Icon(Icons.pin_drop_outlined),
                                label: const Text('Drop-off on map'),
                              ),
                            ),
                          ],
                        ),
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
                              onPressed: _routing ? null : _autoEstimateDistance,
                              icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                              label: Text(_routing ? 'Routing...' : 'Route with OSM'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          'Distance is calculated with open-source routing and falls back to the local city table when offline.',
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
                    _SectionCard(
                      title: 'Pickup schedule',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_available_outlined, color: Color(0xFF0F766E)),
                          title: Text('${_scheduledPickup.day}/${_scheduledPickup.month}/${_scheduledPickup.year} at ${TimeOfDay.fromDateTime(_scheduledPickup).format(context)}'),
                          subtitle: const Text('Changes and cancellations close 12 hours before pickup.'),
                          trailing: IconButton(icon: const Icon(Icons.edit_calendar_outlined), tooltip: 'Change pickup time', onPressed: _choosePickupTime),
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
                      'Your request will be sent for admin review. No payment is taken yet.',
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