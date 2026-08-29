import 'package:flame/components.dart';

import '../collectibles/energy_cell.dart';
import '../config.dart';
import 'noise.dart';
import 'terrain_chunk.dart';
import 'terrain_generator.dart';

/// Streams terrain chunks (and their collectibles) in and out around the
/// rover, so the world feels endless without paying for it.
///
/// Chunks and collectibles are children of this component, so tearing the
/// manager down tears the whole world down with it.
class TerrainManager extends Component {
  TerrainManager({required this.generator, required this.onCellCollected});

  final TerrainGenerator generator;

  /// Wired into every cell at spawn time, so the manager owns the plumbing
  /// and the game loop never has to scan for new pickups.
  final void Function(EnergyCell cell) onCellCollected;

  final Map<int, TerrainChunk> _chunks = {};
  final Map<int, List<EnergyCell>> _cells = {};

  /// Ids of cells the player has already banked. Chunk generation is
  /// deterministic, so without this a culled-and-restreamed chunk would
  /// hand out the same cells again.
  final Set<String> _collected = {};

  /// Call every tick with the rover's world x.
  void updateAround(double focusX) {
    final centreIndex = (focusX / GameConfig.terrainChunkWidth).floor();
    final first = centreIndex - GameConfig.terrainChunksBehind;
    final last = centreIndex + GameConfig.terrainChunksAhead;

    for (var i = first; i <= last; i++) {
      _ensureChunk(i);
    }

    // Cull anything that has fallen out of the live window.
    final stale = _chunks.keys.where((i) => i < first || i > last).toList();
    for (final i in stale) {
      _removeChunk(i);
    }
  }

  void _ensureChunk(int index) {
    if (_chunks.containsKey(index)) return;

    final chunk = TerrainChunk(index: index, generator: generator);
    _chunks[index] = chunk;

    final cells = _spawnCellsFor(index);
    _cells[index] = cells;

    // Chunks and cells are children of the manager, not of the world.
    // Adding to `this` queues correctly even before the manager itself has
    // mounted, so the very first updateAround() during game setup works.
    // BodyComponent finds the physics world through the game reference,
    // not through its parent, so the extra nesting costs nothing.
    add(chunk);
    addAll(cells);
  }

  void _removeChunk(int index) {
    _chunks.remove(index)?.removeFromParent();
    for (final cell in _cells.remove(index) ?? const <EnergyCell>[]) {
      // A cell already collected has removed itself; removing twice is a
      // no-op in Flame, so this stays safe.
      cell.removeFromParent();
    }
  }

  /// Deterministic per-chunk placement, derived from the chunk index, so a
  /// culled-and-restreamed chunk rebuilds the identical layout. Cells
  /// already banked are filtered out via [_collected].
  List<EnergyCell> _spawnCellsFor(int index) {
    final startX = index * GameConfig.terrainChunkWidth;
    final endX = startX + GameConfig.terrainChunkWidth;

    // Nothing to collect on the spawn runway.
    if (endX <= GameConfig.terrainFlatRunway) return const [];

    final rng = SeededRandom(GameConfig.terrainSeed ^ (index * 92821));
    final cells = <EnergyCell>[];

    var ordinal = 0;
    var x = startX + rng.range(2, GameConfig.cellSpacing);
    while (x < endX) {
      final id = '$index:$ordinal';
      if (x > GameConfig.terrainFlatRunway * 0.75 && !_collected.contains(id)) {
        final y = generator.surfaceY(x) - GameConfig.cellHoverHeight;
        cells.add(
          EnergyCell(spawn: Vector2(x, y), id: id)
            ..onCollected = _handleCollected,
        );
      }
      ordinal++;
      x += rng.range(
        GameConfig.cellSpacing * 0.6,
        GameConfig.cellSpacing * 1.4,
      );
    }

    return cells;
  }

  void _handleCollected(EnergyCell cell) {
    _collected.add(cell.id);
    onCellCollected(cell);
  }

  void clear() {
    for (final index in _chunks.keys.toList()) {
      _removeChunk(index);
    }
    _collected.clear();
  }
}
