import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ambulance_app/location/speed_filter.dart';

void main() {
  test('suppresses stationary GPS drift below 3 km/h', () {
    final filter = SpeedFilter();

    expect(filter.filter(0), 0);
    expect(filter.filter(0.03), 0);
    expect(filter.filter(2 / 3.6), 0);
  });

  test('smooths movement after the stationary threshold', () {
    final filter = SpeedFilter();

    expect(filter.filter(30 / 3.6), closeTo(30 / 3.6, 0.001));
    expect(filter.filter(60 / 3.6), closeTo(40.5 / 3.6, 0.001));
  });

  test('returns to zero when the ambulance stops', () {
    final filter = SpeedFilter();

    filter.filter(35 / 3.6);
    expect(filter.filter(2 / 3.6), 0);
  });
}
