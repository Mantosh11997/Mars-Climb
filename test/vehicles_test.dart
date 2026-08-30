import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';

/// Sanity checks on the garage.
///
/// A vehicle is pure data plus two PNGs, so the things that can go wrong
/// are a missing asset, a typo'd filename, or geometry that puts the
/// wheels somewhere the art has no arch.
void main() {
  test('every vehicle has both of its sprites on disk', () {
    for (final v in vehicles) {
      for (final asset in [v.bodyAsset, v.wheelAsset]) {
        expect(
          File('assets/images/$asset').existsSync(),
          isTrue,
          reason: '${v.id} references assets/images/$asset, which is missing',
        );
      }
    }
  });

  test('wheel anchors sit inside the chassis art and the right way round', () {
    for (final v in vehicles) {
      expect(v.frontAnchor.x, greaterThan(v.rearAnchor.x),
          reason: '${v.id}: the front wheel must be ahead of the rear one');

      final halfWidth = v.spriteSize.x / 2;
      expect(v.rearAnchor.x.abs(), lessThan(halfWidth),
          reason: '${v.id}: rear wheel is outside the body art');
      expect(v.frontAnchor.x.abs(), lessThan(halfWidth),
          reason: '${v.id}: front wheel is outside the body art');

      // Wheels hang below the chassis centre, never above it.
      expect(v.rearAnchor.y, greaterThan(0), reason: '${v.id} rear wheel');
      expect(v.frontAnchor.y, greaterThan(0), reason: '${v.id} front wheel');
    }
  });

  test('the driver sits on the machine, and the helmet above the driver', () {
    for (final v in vehicles) {
      expect(v.headOffset.y, lessThan(v.driverOffset.y),
          reason: '${v.id}: the helmet body should be above the driver art');
      expect(v.driverOffset.y, lessThan(0),
          reason: '${v.id}: the driver should sit above the chassis centre');
    }
  });

  test('the chassis hitbox fits inside its own art', () {
    for (final v in vehicles) {
      expect(v.chassisSize.x, lessThan(v.spriteSize.x));
      expect(v.chassisSize.y, lessThan(v.spriteSize.y));
    }
  });

  test('ids are unique', () {
    expect(vehicles.map((v) => v.id).toSet().length, vehicles.length);
  });

  test('the roster spreads out - no machine wins everywhere', () {
    // If one vehicle were top of every stat there would be no reason to
    // drive the others.
    double best(double Function(Vehicle) f) =>
        vehicles.map(f).reduce((a, b) => a > b ? a : b);

    final winners = <String>{};
    for (final metric in <double Function(Vehicle)>[
      (v) => v.topSpeed,
      (v) => v.engineMaxTorque,
      (v) => v.wheelFriction,
      (v) => -v.headDensity,
    ]) {
      final top = best(metric);
      winners.add(vehicles.firstWhere((v) => metric(v) == top).id);
    }

    // ignore: avoid_print
    print('stat leaders: $winners');
    expect(winners.length, greaterThan(2),
        reason: 'the machines should trade blows, not rank linearly');
  });
}
