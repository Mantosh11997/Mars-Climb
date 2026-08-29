import 'package:flutter/foundation.dart';

import '../config.dart';

enum RunStatus { running, outOfOxygen, crashed }

/// All the numbers the HUD cares about, in one listenable place.
///
/// The Flutter overlays listen to this, so the widget layer never has to
/// poke at the game loop.
class GameState extends ChangeNotifier {
  double oxygen = GameConfig.oxygenMax;
  int cells = 0;
  double distance = 0;
  double speed = 0;
  RunStatus status = RunStatus.running;

  bool get isOver => status != RunStatus.running;

  double get oxygenFraction =>
      (oxygen / GameConfig.oxygenMax).clamp(0.0, 1.0);

  String get gameOverTitle => switch (status) {
        RunStatus.outOfOxygen => 'OXYGEN DEPLETED',
        RunStatus.crashed => 'ROVER DOWN',
        RunStatus.running => '',
      };

  String get gameOverBlurb => switch (status) {
        RunStatus.outOfOxygen =>
          'The fuel cell ran dry. Mission control lost telemetry.',
        RunStatus.crashed =>
          'The driver hit the regolith. Helmet integrity compromised.',
        RunStatus.running => '',
      };

  void reset() {
    oxygen = GameConfig.oxygenMax;
    _lastNotifiedOxygen = GameConfig.oxygenMax;
    cells = 0;
    distance = 0;
    speed = 0;
    status = RunStatus.running;
    notifyListeners();
  }

  double _lastNotifiedOxygen = GameConfig.oxygenMax;

  void drain(double amount) {
    if (isOver) return;
    oxygen = (oxygen - amount).clamp(0.0, GameConfig.oxygenMax);
    if (oxygen <= 0) {
      status = RunStatus.outOfOxygen;
      notifyListeners();
      return;
    }
    // Don't rebuild the HUD 60x a second for a sub-pixel bar change.
    if ((_lastNotifiedOxygen - oxygen).abs() >= 0.25) {
      _lastNotifiedOxygen = oxygen;
      notifyListeners();
    }
  }

  void collectCell() {
    if (isOver) return;
    cells += 1;
    oxygen = (oxygen + GameConfig.oxygenPerCell)
        .clamp(0.0, GameConfig.oxygenMax);
    notifyListeners();
  }

  void crash() {
    if (isOver) return;
    status = RunStatus.crashed;
    notifyListeners();
  }

  /// Cheap telemetry update - only notifies when a displayed value would
  /// actually change, so we don't rebuild the HUD 60 times a second for
  /// nothing.
  void updateTelemetry({required double distance, required double speed}) {
    final newDistance = distance;
    final changed = newDistance.floor() != this.distance.floor() ||
        (speed - this.speed).abs() > 0.4;
    this.distance = newDistance;
    this.speed = speed;
    if (changed) notifyListeners();
  }
}
