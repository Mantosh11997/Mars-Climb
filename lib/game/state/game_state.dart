import 'package:flutter/foundation.dart';

import '../config.dart';
import '../level/level.dart';

enum RunStatus {
  running,
  finished,
  outOfOxygen,
  headImpact,
  rolledOver,
  fellOutOfWorld,
}

/// All the numbers the HUD cares about, in one listenable place.
///
/// The Flutter overlays listen to this, so the widget layer never has to
/// poke at the game loop.
class GameState extends ChangeNotifier {
  GameState(this.level, {this.maxOxygen = GameConfig.oxygenMax})
      : oxygen = maxOxygen,
        _lastNotifiedOxygen = maxOxygen;

  Level level;

  /// Capacity for this run. Not a constant any more: the tank upgrade buys
  /// a bigger cell, and the bar has to be full at the start either way.
  final double maxOxygen;

  double oxygen;
  int cells = 0;

  /// Metres travelled from the start line, clamped to the course length.
  double distance = 0;
  double speed = 0;
  RunStatus status = RunStatus.running;

  bool get isOver => status != RunStatus.running;
  bool get hasWon => status == RunStatus.finished;

  double get oxygenFraction => (oxygen / maxOxygen).clamp(0.0, 1.0);

  /// 0 at the start line, 1 at the finish.
  double get progress => (distance / level.finishX).clamp(0.0, 1.0);

  String get outcomeTitle => switch (status) {
        RunStatus.finished => 'LEVEL ${level.number} COMPLETE',
        RunStatus.outOfOxygen => 'OXYGEN DEPLETED',
        RunStatus.headImpact => 'HELMET BREACH',
        RunStatus.rolledOver => 'ROVER FLIPPED',
        RunStatus.fellOutOfWorld => 'LOST OFF-MAP',
        RunStatus.running => '',
      };

  String get outcomeBlurb => switch (status) {
        RunStatus.finished =>
          'Rover recovered at the far marker. ${level.name} is yours.',
        RunStatus.outOfOxygen =>
          'The fuel cell ran dry. Mission control lost telemetry.',
        RunStatus.headImpact =>
          'The driver hit the regolith. Helmet integrity compromised.',
        RunStatus.rolledOver =>
          'A full roll, and all that weight up in the helmet went with it.',
        RunStatus.fellOutOfWorld =>
          'The rover went over the edge and kept going. No ground, no signal.',
        RunStatus.running => '',
      };

  void reset({Level? level}) {
    if (level != null) this.level = level;
    oxygen = maxOxygen;
    _lastNotifiedOxygen = maxOxygen;
    cells = 0;
    distance = 0;
    speed = 0;
    status = RunStatus.running;
    notifyListeners();
  }

  double _lastNotifiedOxygen;

  void drain(double amount) {
    if (isOver) return;
    oxygen = (oxygen - amount).clamp(0.0, maxOxygen);
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
    oxygen = (oxygen + GameConfig.oxygenPerCell).clamp(0.0, maxOxygen);
    notifyListeners();
  }

  /// Ends the run. The first outcome wins - a rover that flips *and* runs
  /// dry on the same tick reports the flip, not the oxygen.
  void end(RunStatus outcome) {
    if (isOver) return;
    status = outcome;
    notifyListeners();
  }

  /// Cheap telemetry update - only notifies when a displayed value would
  /// actually change, so we don't rebuild the HUD 60 times a second for
  /// nothing.
  void updateTelemetry({required double distance, required double speed}) {
    final changed = distance.floor() != this.distance.floor() ||
        (speed - this.speed).abs() > 0.4;
    this.distance = distance;
    this.speed = speed;
    if (changed) notifyListeners();
  }
}
