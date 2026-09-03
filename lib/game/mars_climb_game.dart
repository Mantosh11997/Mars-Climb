import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import 'audio/game_audio.dart';
import 'collectibles/fuel_can.dart';
import 'config.dart';
import 'level/finish_line.dart';
import 'level/level.dart';
import 'level/start_wall.dart';
import 'state/game_state.dart';
import 'terrain/terrain_generator.dart';
import 'terrain/terrain_manager.dart';
import 'vehicle/rover.dart';
import 'vehicle/vehicle.dart' as v;
import 'world/mars_backdrop.dart';

/// Overlay ids, kept in one place so the game and the widget layer can't
/// drift apart.
class Overlays {
  Overlays._();
  static const hud = 'hud';
  static const controls = 'controls';
  static const gameOver = 'gameOver';
  static const levelComplete = 'levelComplete';
}

class MarsClimbGame extends Forge2DGame {
  MarsClimbGame({
    this.level = level1,
    v.Vehicle? vehicle,
    this.fuelMultiplier = 1.0,
  })  : vehicle = vehicle ?? v.rover,
        super(gravity: Vector2(0, GameConfig.gravity));

  Level level;
  v.Vehicle vehicle;

  /// Capacity multiplier from the machine's fitted tank. Comes in from the
  /// screen so the game never has to reach into saved progress.
  final double fuelMultiplier;

  late final GameState state = GameState(
    level,
    maxOxygen: GameConfig.oxygenMax * fuelMultiplier,
  );

  late TerrainGenerator generator;
  late TerrainManager terrain;
  late Rover rover;

  /// The camera chases this, not the rover directly, so we can smooth the
  /// motion and add look-ahead without fighting the physics.
  late final PositionComponent _cameraTarget;

  late final Sprite _chassisSprite;
  late final Sprite _wheelSprite;
  late final Sprite _driverSprite;
  late final Sprite _canSprite;

  bool _built = false;
  bool _rebuildPending = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _chassisSprite = await loadSprite(vehicle.bodyAsset);
    _wheelSprite = await loadSprite(vehicle.wheelAsset);
    _driverSprite = await loadSprite(vehicle.driverAsset);
    _canSprite = await loadSprite('fuel_can.png');

    camera.viewfinder.anchor = Anchor.center;
    _applyZoom();

    // Sky + parallax scenery live behind the world, in viewport space.
    // With the default full-screen viewport those coordinates are exactly
    // screen pixels, so the backdrop covers the display edge to edge on
    // any aspect ratio.
    camera.backdrop.add(
      MarsBackdrop(
        cameraPosition: () => camera.viewfinder.position,
        viewportSize: () => camera.viewport.size,
        cameraZoom: () => camera.viewfinder.zoom,
        theme: level.theme,
        seed: level.seed,
      ),
    );

    _cameraTarget = PositionComponent();
    world.add(_cameraTarget);
    camera.follow(_cameraTarget);

    _buildRun();

    overlays
      ..add(Overlays.hud)
      ..add(Overlays.controls);

    GameAudio.instance.startEngine();
  }

  /// Zoom is derived from the real screen height so the same slice of world
  /// is visible on every device, and the scene always fills the screen.
  void _applyZoom() {
    final height = camera.viewport.size.y;
    if (height <= 0) return;
    camera.viewfinder.zoom = (height / GameConfig.visibleWorldHeight)
        .clamp(GameConfig.minCameraZoom, GameConfig.maxCameraZoom);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _applyZoom();
  }

  // ---------------------------------------------------------------------
  // RUN LIFECYCLE
  // ---------------------------------------------------------------------

  void _buildRun() {
    generator = TerrainGenerator(level);

    const spawnX = Level.startX;
    final spawnY =
        generator.surfaceY(spawnX) - (vehicle.lowestWheelExtent + 0.6);
    final spawn = Vector2(spawnX, spawnY);

    terrain = TerrainManager(
      generator: generator,
      onCellCollected: _onCellCollected,
      canSprite: _canSprite,
    );
    world.add(terrain);
    // Generate the ground before the rover drops onto it.
    terrain.updateAround(spawnX);

    world
      ..add(StartWall(generator: generator))
      ..add(FinishLine(generator: generator));

    rover = Rover(
      spawn: spawn,
      vehicle: vehicle,
      chassisSprite: _chassisSprite,
      wheelSprite: _wheelSprite,
      driverSprite: _driverSprite,
      onHeadImpact: () => _endRun(RunStatus.headImpact),
    );
    world.add(rover);

    _cameraTarget.position = spawn.clone();
    camera.viewfinder.position = spawn.clone();

    _built = true;
  }

  void restart({Level? level}) {
    _built = false;
    if (level != null) this.level = level;

    rover.teardown();
    terrain.clear();
    terrain.removeFromParent();
    world.children.whereType<StartWall>().forEach((c) => c.removeFromParent());
    world.children.whereType<FinishLine>().forEach((c) => c.removeFromParent());

    state.reset(level: this.level);
    _warned = false;
    GameAudio.instance.startEngine();
    overlays
      ..remove(Overlays.gameOver)
      ..remove(Overlays.levelComplete)
      ..add(Overlays.controls);

    // Rebuild on the next tick, after Flame has flushed the removals -
    // otherwise the old bodies are still in the physics world for one
    // more step and the new rover can spawn inside them.
    _rebuildPending = true;
  }

  // ---------------------------------------------------------------------
  // INPUT (called from the Flutter control overlay)
  // ---------------------------------------------------------------------

  void setThrottle(Throttle throttle) {
    if (!_built || state.isOver) {
      if (_built) rover.throttle = Throttle.none;
      return;
    }
    rover.throttle = throttle;
  }

  // ---------------------------------------------------------------------
  // RUN OUTCOMES
  // ---------------------------------------------------------------------

  void _endRun(RunStatus outcome) {
    if (state.isOver) return;
    state.end(outcome);
    rover.throttle = Throttle.none;

    // The motor stops before the jingle starts, or the two overlap and the
    // engine is still running under the game-over panel.
    GameAudio.instance.stopEngine();
    if (outcome != RunStatus.finished) {
      // A crash gets the impact as well as the verdict: the impact is what
      // happened, the jingle is what it cost.
      if (outcome != RunStatus.outOfOxygen) GameAudio.instance.play(Sfx.crash);
      GameAudio.instance.play(Sfx.fail);
    } else {
      GameAudio.instance.play(Sfx.finish);
    }

    overlays.remove(Overlays.controls);
    overlays.add(
      outcome == RunStatus.finished
          ? Overlays.levelComplete
          : Overlays.gameOver,
    );
  }

  /// Everything that can end a run, checked in priority order.
  void _checkOutcomes(Vector2 roverPos, double dt) {
    // Crossed the finish line.
    if (roverPos.x >= level.finishX) {
      _endRun(RunStatus.finished);
      return;
    }

    // Fell off the end of the world (or through it).
    if (roverPos.y > generator.lowestGroundY + GameConfig.fallOutMargin) {
      _endRun(RunStatus.fellOutOfWorld);
      return;
    }

    // Turned a full 360, or landed on the roof and stayed there.
    if (rover.hasRolledOver || rover.hasSettledInverted) {
      _endRun(RunStatus.rolledOver);
      return;
    }

    // Oxygen burn. Head impact is reported by the head body itself.
    final throttling = rover.throttle != Throttle.none;
    state.drain(
      (level.oxygenIdleDrain + (throttling ? level.oxygenThrottleDrain : 0.0)) *
          dt,
    );
    if (state.status == RunStatus.outOfOxygen) {
      _endRun(RunStatus.outOfOxygen);
    }
  }

  // ---------------------------------------------------------------------
  // TICK
  // ---------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);

    if (_rebuildPending) {
      _rebuildPending = false;
      _buildRun();
      return;
    }

    // rover.body only exists once the component has mounted.
    if (!_built || !rover.isMounted) return;

    final roverPos = rover.body.position;

    terrain.updateAround(roverPos.x);
    _updateCamera(dt, roverPos);

    if (state.isOver) return;

    _checkOutcomes(roverPos, dt);

    state.updateTelemetry(
      distance: roverPos.x.clamp(0.0, level.finishX),
      speed: rover.forwardSpeed,
    );

    _updateEngineSound();
  }

  /// Whether the low-oxygen alarm has already sounded this run.
  ///
  /// Latched rather than compared each frame: the fraction hovers either
  /// side of the threshold while you idle, and an alarm that retriggers on
  /// every crossing is a stutter, not a warning.
  bool _warned = false;

  /// Oxygen fraction at which the alarm sounds. Low enough to mean it,
  /// high enough to still be able to do something about it.
  static const double _warnAt = 0.18;

  void _updateEngineSound() {
    final audio = GameAudio.instance;

    // Volume follows the throttle and pitch follows the wheels, so a
    // machine grinding up a slope is loud and low rather than merely slow.
    final topSpeed = vehicle.topSpeedKmh / 3.6;
    audio.setEngine(
      load: rover.throttle == Throttle.none ? 0.0 : 1.0,
      speed: topSpeed <= 0 ? 0 : rover.forwardSpeed.abs() / topSpeed,
    );

    if (!_warned && state.oxygenFraction <= _warnAt) {
      _warned = true;
      audio.play(Sfx.warning);
    }
  }

  void _updateCamera(double dt, Vector2 roverPos) {
    final desired = Vector2(
      roverPos.x + GameConfig.cameraLookAhead,
      roverPos.y - GameConfig.cameraHeightOffset,
    );

    // Exponential smoothing - frame-rate independent.
    final t = 1 - math.exp(-GameConfig.cameraFollowLerp * dt);
    _cameraTarget.position += (desired - _cameraTarget.position) * t;
  }

  void _onCellCollected(FuelCan cell) {
    state.collectCell();
    GameAudio.instance.play(Sfx.coin);
    // Topping up puts the tank back above the threshold, so the alarm is
    // allowed to sound again if it runs down a second time.
    if (state.oxygenFraction > _warnAt) _warned = false;
  }

  @override
  void onRemove() {
    // Leaving the screen must not leave a motor idling behind it.
    GameAudio.instance.stopEngine();
    super.onRemove();
  }
}
