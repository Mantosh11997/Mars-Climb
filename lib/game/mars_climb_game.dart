import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

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
  MarsClimbGame({this.level = level1, v.Vehicle? vehicle})
      : vehicle = vehicle ?? v.rover,
        super(gravity: Vector2(0, GameConfig.gravity));

  Level level;
  v.Vehicle vehicle;

  late final GameState state = GameState(level);

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
      (level.oxygenIdleDrain +
              (throttling ? level.oxygenThrottleDrain : 0.0)) *
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

  void _onCellCollected(FuelCan cell) => state.collectCell();
}
