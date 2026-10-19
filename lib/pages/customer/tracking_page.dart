import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/auth_service.dart';

class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key, required this.requestId, required this.routeLabel});

  final String requestId;
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live shipment tracking'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AuthService.firestore.collection('shipmentRequests').doc(requestId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Could not load tracking: ${snapshot.error ?? 'request not found'}'));
          }
          final data = snapshot.data!.data() ?? {};
          final rawLocation = data['liveLocation'] as Map<String, dynamic>?;
          final latitude = (rawLocation?['latitude'] as num?)?.toDouble();
          final longitude = (rawLocation?['longitude'] as num?)?.toDouble();
          final point = latitude == null || longitude == null ? null : LatLng(latitude, longitude);
          final updatedAt = data['locationUpdatedAt'] as Timestamp?;
          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(initialCenter: point ?? const LatLng(30.3753, 69.3451), initialZoom: point == null ? 5.5 : 13),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.sflms'),
                  if (point != null)
                    MarkerLayer(markers: [
                      Marker(point: point, width: 58, height: 64, child: const Icon(Icons.local_shipping, color: Color(0xFF0F766E), size: 42)),
                    ]),
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
                          const Icon(Icons.gps_fixed, color: Color(0xFF0F766E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              point == null ? '$routeLabel\nWaiting for the driver to share a location.' : '$routeLabel\nUpdated ${updatedAt == null ? 'just now' : _formatTime(updatedAt.toDate())}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (point != null) const Icon(Icons.circle, color: Color(0xFF16A34A), size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}