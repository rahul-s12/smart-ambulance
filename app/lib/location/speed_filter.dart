/// Stabilises raw GPS speed for the operator-facing display.
///
/// A stationary phone can still report a small speed because satellite fixes
/// drift. The filter suppresses values below 3 km/h, then uses an exponential
/// moving average for actual movement so individual GPS fixes do not make the
/// displayed value jump around.
class SpeedFilter {
  static const double stationaryThresholdMetersPerSecond = 3 / 3.6;
  static const double _smoothingFactor = 0.35;

  double? _smoothedSpeed;
  bool _isMoving = false;

  double filter(double rawSpeedMetersPerSecond) {
    if (!rawSpeedMetersPerSecond.isFinite || rawSpeedMetersPerSecond <= 0) {
      _isMoving = false;
      _smoothedSpeed = 0;
      return 0;
    }

    if (!_isMoving &&
        rawSpeedMetersPerSecond < stationaryThresholdMetersPerSecond) {
      return 0;
    }

    _isMoving = rawSpeedMetersPerSecond >= stationaryThresholdMetersPerSecond;
    if (!_isMoving) {
      _smoothedSpeed = 0;
      return 0;
    }

    final previous = _smoothedSpeed;
    _smoothedSpeed = previous == null
        ? rawSpeedMetersPerSecond
        : (_smoothingFactor * rawSpeedMetersPerSecond) +
              ((1 - _smoothingFactor) * previous);
    return _smoothedSpeed!;
  }

  void reset() {
    _smoothedSpeed = null;
    _isMoving = false;
  }
}
