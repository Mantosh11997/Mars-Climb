import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../terrain/noise.dart';

/// A single parallax band of Martian terrain silhouette.
class _ParallaxBand {
  _ParallaxBand({
    required this.factor,
    required this.color,
    required this.baselineFraction,
    required this.amplitude,
    required this.wavelength,
    required int seed,
  }) : noise = ValueNoise1D(seed);

  /// 0 == pinned to the camera (infinitely far), 1 == moves with the world.
  final double factor;
  final Color color;

  /// Where the band's baseline sits, as a fraction of viewport height.
  final double baselineFraction;

  /// Silhouette height in pixels.
  final double amplitude;

  /// Silhouette wavelength in pixels.
  final double wavelength;

  final ValueNoise1D noise;
}

/// The whole Martian sky + distant scenery, rendered in VIEWPORT space.
///
/// This lives on `camera.backdrop`, which is not affected by the camera
/// transform - so we read the camera position ourselves and offset each
/// band by its own parallax factor. That is what buys the depth.
class MarsBackdrop extends Component {
  MarsBackdrop({required this.cameraPosition, required this.viewportSize});

  /// Live reference to `camera.viewfinder.position` (metres).
  final Vector2 Function() cameraPosition;

  /// Live reference to `camera.viewport.size` (pixels).
  final Vector2 Function() viewportSize;

  late final List<_ParallaxBand> _bands = [
    // Far crater rim - barely moves.
    _ParallaxBand(
      factor: 0.08,
      color: GameConfig.mountainFar,
      baselineFraction: 0.72,
      amplitude: 110,
      wavelength: 640,
      seed: GameConfig.terrainSeed + 11,
    ),
    // Mid ridge.
    _ParallaxBand(
      factor: 0.20,
      color: GameConfig.mountainMid,
      baselineFraction: 0.82,
      amplitude: 90,
      wavelength: 420,
      seed: GameConfig.terrainSeed + 29,
    ),
    // Near dunes - noticeably faster.
    _ParallaxBand(
      factor: 0.42,
      color: GameConfig.mountainNear,
      baselineFraction: 0.93,
      amplitude: 70,
      wavelength: 300,
      seed: GameConfig.terrainSeed + 53,
    ),
  ];

  late final List<Offset> _stars = _generateStars();

  List<Offset> _generateStars() {
    final rng = SeededRandom(GameConfig.terrainSeed + 7);
    // Normalised (0..1) positions, scaled to the viewport at render time.
    return List.generate(
      70,
      (_) => Offset(rng.next(), rng.next() * 0.45),
    );
  }

  @override
  void render(Canvas canvas) {
    final size = viewportSize();
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    final cam = cameraPosition();

    _renderSky(canvas, w, h);
    _renderStars(canvas, w, h, cam);
    _renderSun(canvas, w, h, cam);

    for (final band in _bands) {
      _renderBand(canvas, w, h, cam, band);
    }

    _renderDustHaze(canvas, w, h);
  }

  void _renderSky(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, 0),
          Offset(0, h),
          const [
            GameConfig.skyTop,
            GameConfig.skyMid,
            GameConfig.skyLow,
            GameConfig.skyHorizon,
          ],
          const [0.0, 0.42, 0.72, 1.0],
        ),
    );
  }

  void _renderStars(Canvas canvas, double w, double h, Vector2 cam) {
    // Stars drift the least of anything - almost, but not quite, fixed.
    final drift = -cam.x * 0.6;
    final paint = Paint()..color = const Color(0x99FFE9D6);

    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      var x = (s.dx * w + drift) % w;
      if (x < 0) x += w;
      final y = s.dy * h;
      // Fade stars out toward the bright horizon.
      paint.color = const Color(0x99FFE9D6).withOpacity(
        0.6 * (1.0 - (y / (h * 0.5))).clamp(0.0, 1.0),
      );
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.1 : 1.7, paint);
    }
  }

  void _renderSun(Canvas canvas, double w, double h, Vector2 cam) {
    // A small, pale sun - Mars is 1.5 AU out.
    final cx = (w * 0.78) - cam.x * 0.9;
    final cy = h * 0.20 + cam.y * 0.35;

    canvas
      ..drawCircle(
        Offset(cx, cy),
        70,
        Paint()
          ..color = GameConfig.sun.withOpacity(0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      )
      ..drawCircle(Offset(cx, cy), 22, Paint()..color = GameConfig.sun);
  }

  void _renderBand(
    Canvas canvas,
    double w,
    double h,
    Vector2 cam,
    _ParallaxBand band,
  ) {
    // Camera x is in metres; convert to pixels before applying parallax.
    final offsetPx = cam.x * GameConfig.cameraZoom * band.factor;
    // Vertical parallax is much weaker, or the horizon feels rubbery.
    final baseline = h * band.baselineFraction + cam.y * band.factor * 12;

    final path = Path()..moveTo(0, h);

    const step = 12.0;
    for (var x = 0.0; x <= w + step; x += step) {
      final sampleX = (x + offsetPx) / band.wavelength;
      final n = band.noise.fbm(
        sampleX,
        octaves: 3,
        persistence: 0.5,
        lacunarity: 2.0,
      );
      // abs() gives peaky, ridge-like silhouettes rather than soft waves.
      final y = baseline - n.abs() * band.amplitude;
      path.lineTo(x, y);
    }

    path
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(path, Paint()..color = band.color);
  }

  void _renderDustHaze(Canvas canvas, double w, double h) {
    // Warm dust sitting in the bottom third, tying the sky to the ground.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.6, w, h * 0.4),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h * 0.6),
          Offset(0, h),
          [
            const Color(0x00E9A063),
            GameConfig.skyHorizon.withOpacity(0.35),
          ],
        ),
    );
  }
}
