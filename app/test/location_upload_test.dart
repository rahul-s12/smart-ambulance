import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ambulance_app/location/location_tracker.dart';
import 'package:smart_ambulance_app/location/location_upload.dart';
import 'package:smart_ambulance_app/trip/trip_controller.dart';

class _FakeLocationApi implements LocationApi {
  var calls = 0;

  @override
  Future<LocationUploadResult> upload({
    required AmbulanceLocation location,
    required ActiveTrip trip,
  }) async {
    calls++;
    return LocationUploadResult(
      route: RouteEstimate(
        distanceMeters: 1200,
        durationSeconds: 300,
        eta: DateTime(2026, 11, 7, 12, 5),
      ),
    );
  }
}

void main() {
  final trip = ActiveTrip(
    configuration: TripConfiguration(
      ambulanceId: 'AMB-001',
      destination: demoHospitalDestinations.first,
    ),
    startedAt: DateTime(2026, 11, 7, 12),
  );
  final location = AmbulanceLocation(
    latitude: 19.076,
    longitude: 72.8777,
    accuracyMeters: 6,
    capturedAt: DateTime(2026, 11, 7, 12),
  );

  test('uploads only while a trip is active and retains the route estimate', () async {
    final api = _FakeLocationApi();
    final controller = LocationUploadController(api);
    controller.submit(location);
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, 0);

    controller.setTrip(trip);
    controller.submit(location);
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, 1);
    expect(controller.route!.durationSeconds, 300);
    expect(controller.status, 'Location uploaded. Route ETA updated.');
  });
}
