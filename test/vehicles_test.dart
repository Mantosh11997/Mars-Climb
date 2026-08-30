import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';

/// Sanity checks on the garage.
///
/// A vehicle is pure data plus two PNGs, so the things that can go wrong
/// are a missing asset, a typo'd filename, or geometry that puts the
/// wheels somewhere the art has no arch.
void main() {
  test('every vehicle has all of its sprites on disk', () {
    for (final v in vehicles) {
      for (final asset in [v.bodyAsset, v.wheelAsset, v.driverAsset]) {
        expect(
          File('assets/images/$asset').existsSync(),
          isTrue,
          reason: '${v.id} references assets/images/$asset, which is missing',
        );
      }
    }
  });

  test('every wheel sits inside the chassis art and below its centre', () {
    for (final v in vehicles) {
      expect(v.wheels.length, greaterThanOrEqualTo(2),
          reason: '${v.id}: a machine needs at least two wheels to stand up');

      final halfWidth = v.spriteSize.x / 2;
      for (var i = 0; i < v.wheels.length; i++) {
        final w = v.wheels[i];
        expect(w.anchor.x.abs(), lessThan(halfWidth),
            reason: '${v.id} wheel $i is outside the body art');
        expect(w.anchor.y, greaterThan(0),
            reason: '${v.id} wheel $i should hang below the chassis centre');
        expect(w.radius, greaterThan(0.1), reason: '${v.id} wheel $i radius');
      }

      expect(v.wheelbase, greaterThan(0.5),
          reason: '${v.id}: wheels are all bunched at one point');
      expect(v.wheels.any((w) => w.driven), isTrue,
          reason: '${v.id}: nothing drives this machine');
    }
  });

  test('no two wheels overlap each other', () {
    for (final v in vehicles) {
      for (var i = 0; i < v.wheels.length; i++) {
        for (var j = i + 1; j < v.wheels.length; j++) {
          final a = v.wheels[i];
          final b = v.wheels[j];
          final gap = (a.anchor - b.anchor).length;
          expect(gap, greaterThan((a.radius + b.radius) * 0.75),
              reason: '${v.id}: wheels $i and $j are on top of each other');
        }
      }
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
