import 'dart:math' as math;

import '../game/vehicle/vehicle.dart';

/// Normalised 0..1 bars for the garage, scaled across the whole roster so
/// the bars compare machines against each other rather than against
/// arbitrary absolutes.
class VehicleBars {
  const VehicleBars({
    required this.speed,
    required this.power,
    required this.grip,
    required this.stability,
  });

  final double speed;
  final double power;
  final double grip;

  /// How hard it is to put on its roof: a long wheelbase and a light
  /// helmet keep the centre of gravity low and forward-aft stable.
  final double stability;

  static double _norm(double v, double lo, double hi) =>
      hi <= lo ? 0.5 : ((v - lo) / (hi - lo)).clamp(0.0, 1.0);

  static double _stabilityScore(Vehicle v) {
    // Long wheelbase good, heavy helmet bad - and more wheels on the
    // ground is steadier still.
    return v.wheelbase + (v.wheelCount - 2) * 0.35 - v.headDensity * 3.0;
  }

  static VehicleBars of(Vehicle v) {
    double lo(double Function(Vehicle) f) => vehicles.map(f).reduce(math.min);
    double hi(double Function(Vehicle) f) => vehicles.map(f).reduce(math.max);

    return VehicleBars(
      speed: _norm(v.topSpeed, lo((x) => x.topSpeed), hi((x) => x.topSpeed)),
      power: _norm(
        v.engineMaxTorque,
        lo((x) => x.engineMaxTorque),
        hi((x) => x.engineMaxTorque),
      ),
      grip: _norm(
        v.wheelFriction,
        lo((x) => x.wheelFriction),
        hi((x) => x.wheelFriction),
      ),
      stability: _norm(
        _stabilityScore(v),
        lo(_stabilityScore),
        hi(_stabilityScore),
      ),
    );
  }

  List<(String, double)> get rows => [
        ('SPEED', speed),
        ('POWER', power),
        ('GRIP', grip),
        ('STABILITY', stability),
      ];
}
