import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/distance_service.dart';

class RouteMapPage extends StatefulWidget {
  const RouteMapPage({super.key, required this.pickupCity, required this.destinationCity});

  final String pickupCity;
  final String destinationCity;

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  LatLng? _pickup;
  LatLng? _destination;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final results = await Future.wait([
      DistanceService.geocodeCity(widget.pickupCity),
      DistanceService.geocodeCity(widget.destinationCity),
    ]);
    if (!mounted) return;
    final pickup = results[0];
    final destination = results[1];
    if (pickup == null || destination == null) {
      setState(() => _error = 'Could not locate both cities on the map.');
      return;
    }
    setState(() {
      _pickup = LatLng(pickup.latitude, pickup.longitude);
      _destination = LatLng(destination.latitude, destination.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _pickup;
    final destination = _destination;
    final center = pickup != null && destination != null
        ? LatLng((pickup.latitude + destination.latitude) / 2, (pickup.longitude + destination.longitude) / 2)
        : const LatLng(30.3753, 69.3451);
    return Scaffold(
      appBar: AppBar(title: const Text('Shipment route'), centerTitle: true),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: pickup == null ? 5.5 : 6.5),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.sflms'),
              if (pickup != null && destination != null)
                PolylineLayer(
                  polylines: [
                    Polyline(points: [pickup, destination], strokeWidth: 4, color: const Color(0xFF0F766E)),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (pickup != null)
                    Marker(point: pickup, width: 50, height: 58, child: const Icon(Icons.trip_origin, color: Color(0xFF0F766E), size: 34)),
                  if (destination != null)
                    Marker(point: destination, width: 50, height: 58, child: const Icon(Icons.location_pin, color: Color(0xFFDC2626), size: 42)),
                ],
              ),
              RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.route_outlined, color: Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${widget.pickupCity} -> ${widget.destinationCity}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) Center(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))),
        ],
      ),
    );
  }
}
