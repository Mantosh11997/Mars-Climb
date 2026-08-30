@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/level/level.dart';
import 'package:mars_climb/game/terrain/terrain_chunk.dart';
import 'package:mars_climb/game/terrain/terrain_generator.dart';
import 'package:mars_climb/game/world/mars_backdrop.dart';

/// Renders the real backdrop + terrain code to PNGs, with no device.
///
/// The game's look could otherwise only be checked by building an APK and
/// installing it. This drives the actual render() methods through the same
/// camera maths the game uses, so what lands on disk is what the game
/// draws — which is how the "cliff" at the chunk boundary was tracked down
/// to the parallax palette rather than to the terrain.
///
/// Tagged `preview` and excluded from normal runs, since it writes files
/// rather than asserting anything. To look at the scene:
///
///     flutter test test/render_preview_test.dart --tags preview
///     # PNGs land in build/previews/, override with:
///     #   --dart-define=PREVIEW_DIR=/somewhere
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot({
    required String name,
    required Level level,
    required double roverX,
    double width = 2000,
    double height = 890,
  }) async {
    final gen = TerrainGenerator(level);

    // Match MarsClimbGame: camera centred on the rover, plus look-ahead,
    // sitting cameraHeightOffset above it.
    final roverY = gen.surfaceY(roverX) -
        (GameConfig.wheelRadius + GameConfig.chassisSize.y / 2 + 0.6);
    final cam = Vector2(
      roverX + GameConfig.cameraLookAhead,
      roverY - GameConfig.cameraHeightOffset,
    );
    final zoom = (height / GameConfig.visibleWorldHeight)
        .clamp(GameConfig.minCameraZoom, GameConfig.maxCameraZoom);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // --- backdrop: viewport space (== screen pixels) -------------------
    MarsBackdrop(
      cameraPosition: () => cam,
      viewportSize: () => Vector2(width, height),
      cameraZoom: () => zoom,
      theme: level.theme,
      seed: level.seed,
    ).render(canvas);

    // --- world: exactly the transform Flame's viewfinder applies -------
    canvas
      ..save()
      ..translate(width / 2, height / 2)
      ..scale(zoom)
      ..translate(-cam.x, -cam.y);

    // Every chunk the streaming window would have alive.
    final centre = (roverX / GameConfig.terrainChunkWidth).floor();
    final maxIndex =
        (level.worldEndX / GameConfig.terrainChunkWidth).ceil() - 1;
    final first =
        (centre - GameConfig.terrainChunksBehind).clamp(0, maxIndex);
    final last = (centre + GameConfig.terrainChunksAhead).clamp(0, maxIndex);
    for (var i = first; i <= last; i++) {
      TerrainChunk(index: i, generator: gen).render(canvas);
    }

    // Marker where the rover would be, so framing is readable.
    canvas
      ..drawRect(
        ui.Rect.fromCenter(
          center: ui.Offset(roverX, roverY),
          width: GameConfig.chassisSpriteSize.x,
          height: GameConfig.chassisSpriteSize.y,
        ),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 0.06
          ..color = const ui.Color(0xFF00E5FF),
      )
      ..restore();

    final image = await recorder
        .endRecording()
        .toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(name).writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote $name  (chunks $first..$last, zoom ${zoom.toStringAsFixed(1)})');
  }

  test('render previews', () async {
    const dir =
        String.fromEnvironment('PREVIEW_DIR', defaultValue: 'build/previews');
    Directory(dir).createSync(recursive: true);

    // One frame per course, so the per-level themes can be compared.
    for (final level in levels) {
      await shoot(
        name: '$dir/theme_${level.number}_${level.theme.name.replaceAll(' ', '_')}.png',
        level: level,
        roverX: 150,
      );
    }
  });
}
