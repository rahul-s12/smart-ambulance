import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ambulance_app/trip/trip_controller.dart';

void main() {
  final validConfiguration = TripConfiguration(
    ambulanceId: 'AMB-001',
    destination: demoHospitalDestinations.first,
  );

  test('does not start a trip without a selected hospital destination', () {
    final controller = TripController();
    const invalid = TripConfiguration(
      ambulanceId: 'AMB-001',
      destination: null,
    );

    expect(controller.start(invalid), isFalse);
    expect(controller.isActive, isFalse);
    expect(controller.status, 'Select the assigned hospital.');
  });

  test('starts and ends a valid trip', () {
    final controller = TripController();

    expect(controller.start(validConfiguration), isTrue);
    expect(controller.isActive, isTrue);
    expect(
      controller.activeTrip!.configuration.hospitalName,
      'City General Hospital',
    );

    controller.end();
    expect(controller.isActive, isFalse);
    expect(controller.status, 'Trip ended.');
  });
}
