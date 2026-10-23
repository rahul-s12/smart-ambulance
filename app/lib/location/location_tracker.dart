import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A phone position captured for ambulance-trip tracking.
///
/// It deliberately keeps the location timestamp separate from BLE observation
/// time. Uploading and route calculation will be added in a later milestone.
class AmbulanceLocation {
  const AmbulanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    this.speedMetersPerSecond,
  });

  factory AmbulanceLocation.fromPosition(Position position) =>
      AmbulanceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
        speedMetersPerSecond: position.speed >= 0 ? position.speed : null,
      );

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final double? speedMetersPerSecond;
}

/// Owns foreground location tracking for the gateway screen.
///
/// Background tracking and uploads are intentionally deferred until trips and
/// the cloud endpoint are implemented.
class LocationTracker extends ChangeNotifier {
  StreamSubscription<Position>? _positionSubscription;

  AmbulanceLocation? latest;
  String status = 'Location tracking is off.';

  bool get isTracking => _positionSubscription != null;

  Future<void> start() async {
    if (isTracking) return;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status = 'Turn on Location in phone settings to start tracking.';
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        status = 'Location permission was not granted.';
        notifyListeners();
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        status = 'Location permission is blocked. Enable it in App info.';
        notifyListeners();
        return;
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      status = 'Finding your location…';
      notifyListeners();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(_setPosition, onError: _setError);
    } catch (_) {
      status = 'Could not get location. Check Location and app permission.';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    status = 'Location tracking is off.';
    notifyListeners();
  }

  void _setPosition(Position position) {
    latest = AmbulanceLocation.fromPosition(position);
    status = 'Location tracking';
    notifyListeners();
  }

  void _setError(Object _) {
    status = 'Location updates stopped. Check Location and app permission.';
    _positionSubscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
