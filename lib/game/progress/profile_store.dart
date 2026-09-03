import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_profile.dart';
import 'upgrades.dart';

/// Holds the saved profile and writes it back whenever it changes.
///
/// A ChangeNotifier rather than a plain store, because every screen shows
/// the coin balance and the lock state: buying a machine on the garage
/// screen has to be visible on the course screen without either of them
/// knowing about the other.
///
/// Writes are fire-and-forget. Losing the last write to a kill is worth far
/// less than blocking the button that caused it, and every mutation writes
/// the whole profile, so the next one repairs any gap.
class ProfileStore extends ChangeNotifier {
  ProfileStore({required this.starterVehicleId});

  /// The machine a player can never be without.
  final String starterVehicleId;

  static const String _key = 'mars_climb_profile_v1';

  PlayerProfile _profile = PlayerProfile.fresh;
  PlayerProfile get profile => _profile;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Read the save. Safe to call more than once; safe to fail.
  ///
  /// A profile that will not parse is replaced with a fresh one rather than
  /// crashing the app on launch - losing progress is bad, but a game that
  /// will not start is worse, and there is nothing here worth a recovery
  /// flow.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _profile = PlayerProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      _profile = PlayerProfile.fresh;
    }
    _profile = _profile.normalised(starterVehicleId: starterVehicleId);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_profile.toJson()));
    } catch (_) {
      // Storage is unavailable on this device or full. The session keeps
      // working on the in-memory profile.
    }
  }

  void _set(PlayerProfile next) {
    _profile = next;
    notifyListeners();
    _persist();
  }

  void award(int coins) {
    if (coins <= 0) return;
    _set(_profile.withCoins(coins));
  }

  /// Record a finished or failed run.
  void recordRun({
    required int levelNumber,
    required double distance,
    required bool finished,
  }) =>
      _set(_profile.withRun(
        levelNumber: levelNumber,
        distance: distance,
        finished: finished,
      ));

  /// Buy a machine. Returns false and changes nothing if it is unaffordable
  /// or already owned, so the caller cannot spend twice by double-tapping.
  bool buyVehicle(String id, int price) {
    if (_profile.owns(id) || _profile.coins < price) return false;
    _set(_profile.withCoins(-price).withVehicle(id));
    return true;
  }

  /// Fit the next level of [part] on a machine. Same contract as
  /// [buyVehicle]: it refuses rather than half-applying, so a double tap
  /// cannot charge twice or skip a level.
  bool buyUpgrade(String vehicleId, UpgradePart part) {
    final fitted = _profile.upgradesFor(vehicleId);
    final price = upgradeCost(part, fitted.levelOf(part));
    if (price == null || _profile.coins < price) return false;
    _set(_profile
        .withCoins(-price)
        .withUpgrades(vehicleId, fitted.bumped(part)));
    return true;
  }

  /// Remember which machine was taken out, so PLAY can offer it again.
  void setLastVehicle(String id) {
    if (_profile.lastVehicleId == id) return;
    _set(_profile.withLastVehicle(id));
  }

  /// Wipe everything. Used by the reset control, and by tests.
  void reset() => _set(
        PlayerProfile.fresh.normalised(starterVehicleId: starterVehicleId),
      );
}
