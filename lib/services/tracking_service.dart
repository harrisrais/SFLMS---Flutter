import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';

class TrackingService {
  static final Map<String, StreamSubscription<Position>> _subscriptions = {};

  static Future<void> start(String requestId) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are disabled on this device.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required to share live tracking.');
    }
    await stop(requestId);
    final settings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    final subscription = Geolocator.getPositionStream(locationSettings: settings).listen((position) {
      AuthService.firestore.collection('shipmentRequests').doc(requestId).update({
        'liveLocation': {'latitude': position.latitude, 'longitude': position.longitude},
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
    _subscriptions[requestId] = subscription;
  }

  static Future<void> stop(String requestId) async {
    await _subscriptions.remove(requestId)?.cancel();
  }
}