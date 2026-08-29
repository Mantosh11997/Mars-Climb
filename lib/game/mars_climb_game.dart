import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import 'collectibles/energy_cell.dart';
import 'config.dart';
import 'state/game_state.dart';
import 'terrain/terrain_generator.dart';
import 'terrain/terrain_manager.dart';
import 'vehicle/rover.dart';
import 'world/mars_backdrop.dart';

/// Overlay ids, kept in one place so the game and the widget layer can't
/// drift apart.
class Overlays {
  Overlays._();
  static const hud = 'hud';
  static const controls = 'controls';
  static const gameOver = 'gameOver';
}

class MarsClimbGame extends Forge2DGame {
  MarsClimbGame()
      : super(
          gravity: Vector2(0, GameConfig.gravity),
          camera: CameraComponent.withFixedResolution(
            width: GameConfig.resolution.x,
            height: GameConfig.resolution.y,
          ),
        );

  final GameState state = GameState();

  late final TerrainGenerator generator;
  late TerrainManager terrain;
  late Rover rover;

  /// The camera chases this, not the rover directly, so we can smooth the
  /// motion and add look-ahead without fighting the physics.
  late final PositionComponent _cameraTarget;

  late final Sprite _chassisSprite;
  late final Sprite _wheelSprite;
  late final Sprite _driverSprite;

  bool _built = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _chassisSprite = await loadSprite('car_body.png');
    _wheelSprite = await loadSprite('wheel.png');
    _driverSprite = await loadSprite('character.png');

    camera.viewfinder
      ..zoom = GameConfig.cameraZoom
      ..anchor = Anchor.center;

    // Sky + parallax scenery live behind the world, in viewport space.
    camera.backdrop.add(
      MarsBackdrop(
        cameraPosition: () => camera.viewfinder.position,
        viewportSize: () => camera.viewport.size,
      ),
    );

    _cameraTarget = PositionComponent();
    world.add(_cameraTarget);
    camera.follow(_cameraTarget);

    generator = TerrainGenerator();

    _buildRun();

    overlays
      ..add(Overlays.hud)
      ..add(Overlays.controls);
  }

  // ---------------------------------------------------------------------
  // RUN LIFECYCLE
  // ---------------------------------------------------------------------

  void _buildRun() {
    final spawnX = GameConfig.terrainFlatRunway * 0.4;
    final spawnY = generator.surfaceY(spawnX) -
        (GameConfig.wheelRadius + GameConfig.chassisSize.y / 2 + 0.6);
    final spawn = Vector2(spawnX, spawnY);

    terrain = TerrainManager(
      generator: generator,
      onCellCollected: _onCellCollected,
    );
    world.add(terrain);
    // Generate the ground before the rover drops onto it.
    terrain.updateAround(spawnX);

    rover = Rover(
      spawn: spawn,
      chassisSprite: _chassisSprite,
      wheelSprite: _wheelSprite,
      driverSprite: _driverSprite,
      onHeadImpact: _onHeadImpact,
    );
    world.add(rover);

    _cameraTarget.position = spawn.clone();
    camera.viewfinder.position = spawn.clone();

    _built = true;
  }

  void restart() {
    _built = false;

    rover.teardown();
    terrain.clear();
    terrain.removeFromParent();

    state.reset();
    overlays
      ..remove(Overlays.gameOver)
      ..add(Overlays.controls);

    // Rebuild on the next tick, after Flame has flushed the removals -
    // otherwise the old bodies are still in the physics world for one
    // more step and the new rover can spawn inside them.
    _rebuildPending = true;
  }

  bool _rebuildPending = false;

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
  // LOSE CONDITIONS
  // ---------------------------------------------------------------------

  void _onHeadImpact() {
    if (state.isOver) return;
    state.crash();
    _endRun();
  }

  void _endRun() {
    rover.throttle = Throttle.none;
    overlays
      ..remove(Overlays.controls)
      ..add(Overlays.gameOver);
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

    // Stream terrain around the rover.
    terrain.updateAround(roverPos.x);

    _updateCamera(dt, roverPos);

    if (state.isOver) return;

    // Oxygen burn.
    final throttling = rover.throttle != Throttle.none;
    state.drain(
      (GameConfig.oxygenIdleDrain +
              (throttling ? GameConfig.oxygenThrottleDrain : 0.0)) *
          dt,
    );

    state.updateTelemetry(
      distance: rover.distanceTravelled,
      speed: rover.forwardSpeed,
    );

    if (state.status == RunStatus.outOfOxygen) {
      _endRun();
    }
  }

  void _updateCamera(double dt, Vector2 roverPos) {
    final desired = Vector2(
      roverPos.x + GameConfig.cameraLookAhead,
      roverPos.y - 1.0,
    );

    // Exponential smoothing - frame-rate independent.
    final t = 1 - math.exp(-GameConfig.cameraFollowLerp * dt);
    _cameraTarget.position += (desired - _cameraTarget.position) * t;
  }

  void _onCellCollected(EnergyCell cell) {
    state.collectCell();
  }
}
