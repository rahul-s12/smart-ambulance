import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../trip/trip_controller.dart';
import 'location_tracker.dart';

class RouteEstimate {
  const RouteEstimate({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.eta,
  });

  final int distanceMeters;
  final int durationSeconds;
  final DateTime eta;
}

class LocationUploadResult {
  const LocationUploadResult({this.route});

  final RouteEstimate? route;
}

abstract interface class LocationApi {
  Future<LocationUploadResult> upload({
    required AmbulanceLocation location,
    required ActiveTrip trip,
  });
}

/// Sends live phone locations to the cloud endpoint implemented in `cloud/`.
class CloudLocationApi implements LocationApi {
  CloudLocationApi({required this.baseUrl, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  @override
  Future<LocationUploadResult> upload({
    required AmbulanceLocation location,
    required ActiveTrip trip,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Cloud upload is not configured. Set CLOUD_API_BASE_URL when running the app.',
      );
    }
    final destination = trip.configuration.destination;
    if (destination == null) throw StateError('The active trip has no destination.');
    final root = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$root/api/ambulances/${Uri.encodeComponent(trip.configuration.ambulanceId.trim())}/location',
    );
    final request = await _httpClient.postUrl(uri).timeout(const Duration(seconds: 10));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracyMeters': location.accuracyMeters,
      if (location.speedMetersPerSecond != null)
        'speedMetersPerSecond': location.speedMetersPerSecond,
      'capturedAt': location.capturedAt.toUtc().toIso8601String(),
      'destination': {
        'hospitalName': destination.name,
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      },
    }));
    final response = await request.close().timeout(const Duration(seconds: 10));
    final body = await utf8.decoder.bind(response).join();
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = decoded is Map ? decoded['errors'] : null;
      final message = errors is List ? errors.join(' ') : 'HTTP ${response.statusCode}';
      throw HttpException('Location upload was rejected: $message', uri: uri);
    }
    final locationBody = (decoded as Map)['location'];
    final route = locationBody is Map ? locationBody['route'] : null;
    if (route is! Map) return const LocationUploadResult();
    final distance = route['distanceMeters'];
    final duration = route['durationSeconds'];
    final eta = route['eta'];
    if (distance is! num || duration is! num || eta is! String) {
      return const LocationUploadResult();
    }
    return LocationUploadResult(
      route: RouteEstimate(
        distanceMeters: distance.round(),
        durationSeconds: duration.round(),
        eta: DateTime.parse(eta).toLocal(),
      ),
    );
  }
}

/// Keeps one in-flight request and sends the newest GPS fix afterwards.
class LocationUploadController extends ChangeNotifier {
  LocationUploadController(this._api);

  final LocationApi _api;
  ActiveTrip? _trip;
  AmbulanceLocation? _queuedLocation;
  bool _uploading = false;
  String status = 'Start a trip to upload GPS location.';
  DateTime? lastUploadedAt;
  RouteEstimate? route;

  bool get isUploading => _uploading;

  void setTrip(ActiveTrip? trip) {
    _trip = trip;
    _queuedLocation = null;
    route = null;
    status = trip == null
        ? 'Start a trip to upload GPS location.'
        : 'Waiting for a GPS fix to upload.';
    notifyListeners();
  }

  void submit(AmbulanceLocation location) {
    if (_trip == null) return;
    _queuedLocation = location;
    if (!_uploading) unawaited(_drain());
  }

  Future<void> _drain() async {
    _uploading = true;
    notifyListeners();
    while (_queuedLocation != null && _trip != null) {
      final location = _queuedLocation!;
      final trip = _trip!;
      _queuedLocation = null;
      status = 'Uploading location…';
      notifyListeners();
      try {
        final result = await _api.upload(location: location, trip: trip);
        if (_trip != trip) continue;
        route = result.route;
        lastUploadedAt = DateTime.now();
        status = result.route == null
            ? 'Location uploaded. Route ETA is unavailable.'
            : 'Location uploaded. Route ETA updated.';
      } catch (_) {
        if (_trip == trip) {
          status = 'Could not upload location. It will retry with the next GPS fix.';
        }
      }
      notifyListeners();
    }
    _uploading = false;
    notifyListeners();
  }
}
