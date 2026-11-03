import 'package:flutter/foundation.dart';

/// A hospital's preconfigured ambulance entrance.
///
/// These records deliberately hold the routing coordinates outside the driver
/// form. The cloud assignment service will replace the local list later.
class HospitalDestination {
  const HospitalDestination({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
}

/// Temporary destinations for the on-device demonstration.
///
/// Production destinations must come from the hospital/dispatcher assignment,
/// rather than this catalog.
const demoHospitalDestinations = <HospitalDestination>[
  HospitalDestination(
    id: 'city-general',
    name: 'City General Hospital',
    latitude: 19.0760,
    longitude: 72.8777,
  ),
  HospitalDestination(
    id: 'central-medical',
    name: 'Central Medical Centre',
    latitude: 19.0896,
    longitude: 72.8656,
  ),
  HospitalDestination(
    id: 'riverside-trauma',
    name: 'Riverside Trauma Centre',
    latitude: 19.0618,
    longitude: 72.8493,
  ),
];

/// The fixed destination assigned to an ambulance for one journey.
class TripConfiguration {
  const TripConfiguration({
    required this.ambulanceId,
    required this.destination,
  });

  final String ambulanceId;
  final HospitalDestination? destination;

  String get hospitalName => destination?.name ?? '';
  double? get latitude => destination?.latitude;
  double? get longitude => destination?.longitude;

  String? get validationError {
    if (ambulanceId.trim().isEmpty) return 'Enter an ambulance ID.';
    if (destination == null) return 'Select the assigned hospital.';
    return null;
  }
}

/// A locally active ambulance trip. Cloud persistence comes in the next stage.
class ActiveTrip {
  const ActiveTrip({required this.configuration, required this.startedAt});

  final TripConfiguration configuration;
  final DateTime startedAt;
}

class TripController extends ChangeNotifier {
  ActiveTrip? activeTrip;
  String status = 'No active trip. Configure the assigned hospital to begin.';

  bool get isActive => activeTrip != null;

  bool start(TripConfiguration configuration) {
    final error = configuration.validationError;
    if (error != null) {
      status = error;
      notifyListeners();
      return false;
    }

    activeTrip = ActiveTrip(
      configuration: configuration,
      startedAt: DateTime.now(),
    );
    status = 'Trip active. Destination: ${configuration.hospitalName.trim()}.';
    notifyListeners();
    return true;
  }

  void end() {
    activeTrip = null;
    status = 'Trip ended.';
    notifyListeners();
  }
}
