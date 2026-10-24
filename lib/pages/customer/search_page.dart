import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/fleet_vehicle.dart';
import '../../models/vehicle_category.dart';
import '../../services/catalog_service.dart';
import 'booking_page.dart';
/// Lets customers search available vehicles by route, load capacity, and
/// urgency. Results can be scoped to a dashboard category.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialCategory});
  final VehicleCategory? initialCategory;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _loadController = TextEditingController();
  String _urgency = 'standard';
  bool _searching = false;
  bool _searched = false;
  List<FleetVehicle> _results = const [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final results = await CatalogService.searchVehicles(
        categoryId: widget.initialCategory?.id,
        pickupCity: _pickupController.text,
        destinationCity: _destinationController.text,
        minLoadKg: double.tryParse(_loadController.text.trim()),
        expressOnly: _urgency == 'express',
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectVehicle(FleetVehicle vehicle) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingPage(
        vehicle: vehicle,
        initialPickupCity: _pickupController.text.trim(),
        initialDestinationCity: _destinationController.text.trim(),
        initialUrgency: _urgency,
        initialWeightKg: double.tryParse(_loadController.text.trim()),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initialCategory?.name ?? 'Search fleet'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pickupController,
                            decoration: const InputDecoration(
                              labelText: 'Pickup city',
                              prefixIcon: Icon(Icons.trip_origin),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _destinationController,
                            decoration: const InputDecoration(
                              labelText: 'Destination city',
                              prefixIcon: Icon(Icons.flag_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _loadController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Load capacity (kg)',
                              prefixIcon: Icon(Icons.scale_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'standard', label: Text('Standard'), icon: Icon(Icons.schedule_outlined)),
                              ButtonSegment(value: 'express', label: Text('Express'), icon: Icon(Icons.bolt_outlined)),
                            ],
                            selected: {_urgency},
                            onSelectionChanged: (value) => setState(() => _urgency = value.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _searching ? null : _search,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(_searching ? 'Searching…' : 'Search available vehicles'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _searched ? 'No vehicles match those filters yet.' : '',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final vehicle = _results[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFECFEFF),
                                child: Icon(Icons.local_shipping_outlined, color: Color(0xFF0F766E)),
                              ),
                              title: Text('${vehicle.categoryName} · ${vehicle.registrationNo}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Capacity: ${vehicle.capacityKg.toStringAsFixed(0)} kg'),
                                  Text('Serves: ${vehicle.serviceCities.join(', ')}'),
                                  if (vehicle.supportsExpress)
                                    const Text('Express delivery available', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w600)),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: FilledButton(
                                onPressed: () => _selectVehicle(vehicle),
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                                child: const Text('Select'),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
