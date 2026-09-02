import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/level/level.dart';
import 'package:mars_climb/game/progress/economy.dart';
import 'package:mars_climb/game/progress/player_profile.dart';
import 'package:mars_climb/game/progress/upgrades.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';

/// The rules of the economy, checked as rules rather than as numbers.
///
/// Balance is a judgement call and will move. What must not move is the
/// shape: you can always earn, prices always rise, an upgrade always helps,
/// and a save always survives a round trip. Those are the things that break
/// the game rather than just make it easier or harder.
void main() {
  group('profile', () {
    test('survives a save and load unchanged', () {
      const before = PlayerProfile(
        coins: 4321,
        ownedVehicles: {'rover', 'gecko'},
        completedLevels: {1, 2, 5},
        bestDistance: {1: 520.0, 3: 217.5},
        upgrades: {
          'gecko': Upgrades(engine: 3, grip: 5, suspension: 1, tank: 2),
        },
      );

      // Through actual JSON, not just the maps: a value that cannot be
      // encoded is the failure this is guarding against.
      final after = PlayerProfile.fromJson(
        jsonDecode(jsonEncode(before.toJson())) as Map<String, dynamic>,
      );

      expect(after.coins, before.coins);
      expect(after.ownedVehicles, before.ownedVehicles);
      expect(after.completedLevels, before.completedLevels);
      expect(after.bestDistance, before.bestDistance);
      expect(after.upgradesFor('gecko'), before.upgradesFor('gecko'));
    });

    test('a garbled save still leaves you something to drive', () {
      final wrecked = PlayerProfile.fromJson(const {'coins': 'not a number'})
          .normalised(starterVehicleId: rover.id);
      expect(wrecked.owns(rover.id), isTrue,
          reason: 'a profile with no machine cannot earn its way out');
      expect(wrecked.coins, 0);
    });

    test('best distance only ever moves up', () {
      var p = PlayerProfile.fresh
          .withRun(levelNumber: 1, distance: 300, finished: false);
      p = p.withRun(levelNumber: 1, distance: 120, finished: false);
      expect(p.bestOn(1), 300);
    });

    test('the campaign opens one course at a time', () {
      const fresh = PlayerProfile.fresh;
      expect(fresh.canPlay(1), isTrue, reason: 'the first is always open');
      expect(fresh.canPlay(2), isFalse);

      final cleared = fresh.withRun(
        levelNumber: 1,
        distance: 520,
        finished: true,
      );
      expect(cleared.canPlay(2), isTrue);
      expect(cleared.canPlay(3), isFalse);
    });

    test('failing a run opens nothing', () {
      final failed = PlayerProfile.fresh
          .withRun(levelNumber: 1, distance: 519, finished: false);
      expect(failed.canPlay(2), isFalse);
    });
  });

  group('economy', () {
    test('a failed run still pays, and a cleared one pays much better', () {
      final failed = payoutFor(
        level: level1,
        distance: 260,
        cans: 3,
        finished: false,
        alreadyCleared: false,
      );
      final cleared = payoutFor(
        level: level1,
        distance: level1.finishX,
        cans: 6,
        finished: true,
        alreadyCleared: false,
      );

      expect(failed.total, greaterThan(0),
          reason: 'a run that pays nothing makes failure feel like a punish');
      expect(cleared.total, greaterThan(failed.total * 2),
          reason: 'clearing has to be worth chasing over grinding halfway');
    });

    test('the first clear of a course is worth more than the next', () {
      final first = payoutFor(
        level: level1,
        distance: level1.finishX,
        cans: 4,
        finished: true,
        alreadyCleared: false,
      );
      final repeat = payoutFor(
        level: level1,
        distance: level1.finishX,
        cans: 4,
        finished: true,
        alreadyCleared: true,
      );
      expect(first.total, greaterThan(repeat.total));
      expect(repeat.total, greaterThan(0), reason: 'replaying still pays');
    });

    test('later courses pay better than earlier ones', () {
      var previous = 0;
      for (final level in levels) {
        final pay = payoutFor(
          level: level,
          distance: level.finishX,
          cans: 5,
          finished: true,
          alreadyCleared: true,
        );
        expect(pay.total, greaterThan(previous),
            reason: '${level.name} should out-pay the course before it');
        previous = pay.total;
      }
    });
  });

  group('prices', () {
    test('the starter is free and nothing else is', () {
      expect(rover.price, 0);
      for (final v in vehicles.where((v) => v.id != rover.id)) {
        expect(v.price, greaterThan(0), reason: '${v.id} is free by accident');
      }
    });

    test('each level of a part costs more than the last', () {
      for (final part in UpgradePart.values) {
        var previous = 0;
        for (var lvl = 0; lvl < maxUpgradeLevel; lvl++) {
          final cost = upgradeCost(part, lvl)!;
          expect(cost, greaterThan(previous),
              reason: '${part.label} level ${lvl + 1} is not dearer');
          previous = cost;
        }
        expect(upgradeCost(part, maxUpgradeLevel), isNull,
            reason: '${part.label} should have a ceiling');
      }
    });

    test('a first course clear covers a meaningful slice of a cheap machine',
        () {
      final pay = payoutFor(
        level: level1,
        distance: level1.finishX,
        cans: 6,
        finished: true,
        alreadyCleared: false,
      );
      final cheapest = vehicles
          .where((v) => v.price > 0)
          .map((v) => v.price)
          .reduce((a, b) => a < b ? a : b);

      // Not affordable in one run - that would make the garage meaningless -
      // but within a handful, or the grind is the game.
      expect(cheapest / pay.total, lessThan(4),
          reason: 'the second machine is more than a few runs away');
      expect(cheapest, greaterThan(pay.total),
          reason: 'one run should not buy a machine outright');
    });
  });

  group('upgrades', () {
    test('fitting parts is bounded and cumulative', () {
      var u = Upgrades.none;
      for (var i = 0; i < maxUpgradeLevel + 3; i++) {
        u = u.bumped(UpgradePart.engine);
      }
      expect(u.engine, maxUpgradeLevel);
      expect(u.isMaxed(UpgradePart.engine), isTrue);
      expect(u.grip, 0, reason: 'one part should not fit another');
    });

    test('a fully built machine is better at everything it should be', () {
      const full = Upgrades(
        engine: maxUpgradeLevel,
        grip: maxUpgradeLevel,
        suspension: maxUpgradeLevel,
        tank: maxUpgradeLevel,
      );

      for (final base in vehicles) {
        final built = base.tuned(full);
        expect(built.engineMaxTorque, greaterThan(base.engineMaxTorque));
        expect(built.wheelFriction, greaterThan(base.wheelFriction));
        expect(
            built.suspensionFrequencyHz, lessThan(base.suspensionFrequencyHz),
            reason: 'a better spring is softer, not stiffer');
        expect(built.suspensionDampingRatio, lessThanOrEqualTo(1.0),
            reason: 'over-damping past 1.0 is not a thing Forge2D wants');
        expect(Vehicle.tankMultiplier(full), greaterThan(1.0));

        // Identity, geometry and art must survive tuning, or the upgraded
        // machine is a different machine.
        expect(built.id, base.id);
        expect(built.wheels.length, base.wheels.length);
        expect(built.bodyAsset, base.bodyAsset);
        expect(built.price, base.price);
      }
    });

    test('nothing fitted changes nothing at all', () {
      for (final base in vehicles) {
        expect(identical(base.tuned(Upgrades.none), base), isTrue);
      }
    });

    test('upgrades do not collapse the roster into one machine', () {
      const full = Upgrades(
        engine: maxUpgradeLevel,
        grip: maxUpgradeLevel,
        suspension: maxUpgradeLevel,
        tank: maxUpgradeLevel,
      );
      // Every part is a multiplier, so the spread between machines has to
      // survive being built. A fully-upgraded Skimmer must still out-grip
      // nothing it did not already out-grip.
      final baseOrder = [...vehicles]
        ..sort((a, b) => a.wheelFriction.compareTo(b.wheelFriction));
      final builtOrder = [...vehicles.map((v) => v.tuned(full))]
        ..sort((a, b) => a.wheelFriction.compareTo(b.wheelFriction));

      expect(
        builtOrder.map((v) => v.id).toList(),
        baseOrder.map((v) => v.id).toList(),
        reason: 'upgrading reordered which machine grips best',
      );
    });
  });
}
