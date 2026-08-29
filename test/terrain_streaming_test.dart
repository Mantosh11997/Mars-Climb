import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/mars_climb_game.dart';
import 'package:mars_climb/game/terrain/terrain_chunk.dart';
import 'package:mars_climb/ui/controls.dart';
import 'package:mars_climb/ui/hud.dart';
import 'package:mars_climb/ui/outcome_overlay.dart';

/// Does the ground the rover drives on actually exist?
///
/// A continuous generator is not enough - the chunks have to reach the
/// component tree with a live body. A screenshot showed the world simply
/// stopping at x=42 m, the first chunk boundary, with nothing but backdrop
/// beyond it: `ChainShape.createChain` was throwing inside
/// `BodyComponent.onLoad`, so those chunks silently never mounted.
void main() {
  // FlameTester drives the Flame game lifecycle correctly; it just needs
  // the overlay builders, since the game registers 'hud' and 'controls'
  // in onLoad and an unknown overlay is an assertion failure.
  final harness = FlameTester<MarsClimbGame>(
    MarsClimbGame.new,
    createGameWidget: (game) => GameWidget<MarsClimbGame>(
      game: game,
      overlayBuilderMap: {
        Overlays.hud: (_, g) => Hud(game: g),
        Overlays.controls: (_, g) => Controls(game: g),
        Overlays.gameOver: (_, g) =>
            OutcomeOverlay(game: g, onNextLevel: (_) {}, onQuit: () {}),
        Overlays.levelComplete: (_, g) =>
            OutcomeOverlay(game: g, onNextLevel: (_) {}, onQuit: () {}),
      },
    ),
  );

  /// Get the game fully loaded and its mount queue drained.
  ///
  /// `onLoad` decodes real sprite images; the fake-async test zone will
  /// not drive those futures, so this has to happen inside runAsync or the
  /// world comes back empty.
  Future<void> settle(MarsClimbGame game, WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    for (var i = 0; i < 20; i++) {
      game.update(1 / 60);
      await tester.pump();
    }
  }

  List<TerrainChunk> chunksIn(MarsClimbGame game) =>
      game.world.descendants().whereType<TerrainChunk>().toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  harness.testGameWidget(
    'the streaming window around the spawn is mounted',
    verify: (game, tester) async {
    await settle(game, tester);
    final chunks = chunksIn(game);
    final indices = chunks.map((c) => c.index).toList();

    // ignore: avoid_print
    print('mounted chunk indices at spawn: $indices');

    expect(
      indices,
      containsAll(<int>[
        for (var i = 0; i <= GameConfig.terrainChunksAhead; i++) i,
      ]),
      reason: 'if a chunk fails to mount the world just ends there',
    );
  },
  );

  harness.testGameWidget(
    'mounted terrain is continuous and has live bodies',
    verify: (game, tester) async {
    await settle(game, tester);
    final chunks = chunksIn(game);
    expect(chunks, isNotEmpty);

    for (final chunk in chunks) {
      expect(chunk.isMounted, isTrue,
          reason: 'chunk ${chunk.index} is in the tree but never mounted');
      expect(() => chunk.body, returnsNormally,
          reason: 'chunk ${chunk.index} has no body - nothing to drive on');
    }

    for (var i = 1; i < chunks.length; i++) {
      expect(chunks[i].startX, closeTo(chunks[i - 1].endX, 1e-6),
          reason: 'chunk ${chunks[i].index} must begin exactly where chunk '
              '${chunks[i - 1].index} ends - a gap is a hole in the world');
    }

    final covered = chunks.last.endX - chunks.first.startX;
    // ignore: avoid_print
    print('terrain covers ${chunks.first.startX}..${chunks.last.endX} m '
        'from ${chunks.length} chunks');
    expect(covered, greaterThan(GameConfig.terrainChunkWidth * 2));
  },
  );

  harness.testGameWidget(
    'terrain keeps up as the rover advances',
    verify: (game, tester) async {
    await settle(game, tester);

    game.rover.body.setTransform(
      Vector2(GameConfig.terrainChunkWidth * 5 + 10, -6),
      0,
    );
    for (var i = 0; i < 20; i++) {
      game.update(1 / 60);
      await tester.pump();
    }

    final roverX = game.rover.body.position.x;
    final chunks = chunksIn(game);
    // ignore: avoid_print
    print('at ${roverX.toStringAsFixed(1)} m, chunks '
        '${chunks.map((c) => c.index).toList()}');

    expect(
      chunks.any((c) => c.startX <= roverX && c.endX >= roverX),
      isTrue,
      reason: 'there must be ground under the rover at $roverX m',
    );
  },
  );
}
