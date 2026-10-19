import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/distance_service.dart';

class MapSelection {
  const MapSelection({required this.city, required this.latitude, required this.longitude});

  final String city;
  final double latitude;
  final double longitude;
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key, required this.title, this.initialCity = ''});

  final String title;
  final String initialCity;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  static const _pakistanCenter = LatLng(30.3753, 69.3451);
  final _searchController = TextEditingController();
  final _mapController = MapController();
  LatLng? _selectedPoint;
  String? _selectedCity;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialCity;
    if (widget.initialCity.trim().isNotEmpty) _searchCity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchCity() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await DistanceService.geocodeCity(query);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = 'City not found. Try a nearby city name.';
      });
      return;
    }
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      _selectedPoint = point;
      _selectedCity = query;
      _loading = false;
    });
    _mapController.move(point, 11);
  }

  Future<void> _selectPoint(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _selectedCity = null;
      _loading = true;
      _error = null;
    });
    final city = await DistanceService.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _selectedCity = city;
      _loading = false;
      _error = city == null ? 'Could not identify this location. Tap closer to a city.' : null;
    });
  }

  void _confirm() {
    final point = _selectedPoint;
    final city = _selectedCity;
    if (point == null || city == null || city.trim().isEmpty) return;
    Navigator.of(context).pop(MapSelection(city: city, latitude: point.latitude, longitude: point.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final point = _selectedPoint;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: point ?? _pakistanCenter,
              initialZoom: point == null ? 5.5 : 11,
              onTap: (_, tappedPoint) => _selectPoint(tappedPoint),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sflms',
              ),
              if (point != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 52,
                      height: 62,
                      child: const Icon(Icons.location_pin, color: Color(0xFFDC2626), size: 48),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchCity(),
                        decoration: InputDecoration(
                          hintText: 'Search a city',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), tooltip: 'Find city', onPressed: _loading ? null : _searchCity),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (_loading) const LinearProgressIndicator(minHeight: 2),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                        ),
                      if (_selectedCity != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, color: Color(0xFF0F766E)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_selectedCity!, style: const TextStyle(fontWeight: FontWeight.w700))),
                            FilledButton(onPressed: _confirm, child: const Text('Use location')),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Text('Tap the map to choose a city', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
