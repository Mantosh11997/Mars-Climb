import 'dart:math' as math;

/// Deterministic 1D value-noise with fractal Brownian motion on top.
///
/// Hand-rolled so the project has no extra dependency, and so the terrain
/// is *reproducible*: the same seed always gives the same Martian valley,
/// no matter how far the rover drives or which chunks are alive.
class ValueNoise1D {
  ValueNoise1D(this.seed);

  final int seed;

  /// Hash an integer lattice point to a stable value in [-1, 1].
  double _hash(int x) {
    var h = x * 374761393 + seed * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    // Keep it inside a safe positive range, then map to [-1, 1].
    return ((h & 0x7fffffff) / 0x3fffffff) - 1.0;
  }

  /// Smoothstep (3t^2 - 2t^3) keeps the surface C1-continuous, which
  /// matters a lot: sharp kinks in a chain shape catch wheels.
  double _fade(double t) => t * t * (3.0 - 2.0 * t);

  double valueAt(double x) {
    final i = x.floor();
    final f = x - i;
    final a = _hash(i);
    final b = _hash(i + 1);
    return a + (b - a) * _fade(f);
  }

  /// Layered noise. Each octave halves in amplitude and roughly doubles
  /// in frequency, giving big hills with small bumps riding on them.
  double fbm(
    double x, {
    required int octaves,
    required double persistence,
    required double lacunarity,
  }) {
    var amplitude = 1.0;
    var frequency = 1.0;
    var total = 0.0;
    var normaliser = 0.0;

    for (var o = 0; o < octaves; o++) {
      // Offset each octave so they don't share lattice alignment.
      total += valueAt(x * frequency + o * 137.13) * amplitude;
      normaliser += amplitude;
      amplitude *= persistence;
      frequency *= lacunarity;
    }

    return normaliser == 0 ? 0 : total / normaliser;
  }
}

/// Convenience: clamp helper used by the terrain ramp-in.
double smoothClamp01(double t) =>
    t <= 0 ? 0 : (t >= 1 ? 1 : t * t * (3.0 - 2.0 * t));

/// A tiny seeded RNG for gameplay sprinkles (collectible jitter etc).
class SeededRandom {
  SeededRandom(int seed) : _random = math.Random(seed);
  final math.Random _random;
  double next() => _random.nextDouble();
  double range(double min, double max) =>
      min + _random.nextDouble() * (max - min);
}
