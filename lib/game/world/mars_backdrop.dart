import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../terrain/noise.dart';

/// A single parallax band of Martian terrain silhouette.
class _ParallaxBand {
  _ParallaxBand({
    required this.factor,
    required this.verticalFactor,
    required this.color,
    required this.amplitude,
    required this.wavelength,
    required int seed,
  }) : noise = ValueNoise1D(seed);

  /// Horizontal parallax. 0 == pinned to the camera (infinitely far),
  /// 1 == moves exactly with the world.
  final double factor;

  /// Vertical parallax, deliberately much weaker than horizontal. This is
  /// what keeps the band sitting above the horizon as the rover climbs and
  /// drops, instead of being swallowed by the foreground terrain.
  final double verticalFactor;

  final Color color;

  /// Silhouette height in pixels.
  final double amplitude;

  /// Silhouette wavelength in pixels.
  final double wavelength;

  final ValueNoise1D noise;
}

/// The whole Martian sky + distant scenery, rendered in VIEWPORT space.
///
/// This lives on `camera.backdrop`. With the default full-screen viewport
/// that space is exactly screen pixels, untouched by the camera transform,
/// so we read the camera ourselves and offset each band by its own factor.
/// That is what buys the depth.
class MarsBackdrop extends Component {
  MarsBackdrop({
    required this.cameraPosition,
    required this.viewportSize,
    required this.cameraZoom,
  });

  /// Live reference to `camera.viewfinder.position` (metres).
  final Vector2 Function() cameraPosition;

  /// Live reference to `camera.viewport.size` (pixels).
  final Vector2 Function() viewportSize;

  /// Live reference to `camera.viewfinder.zoom` (pixels per metre). The
  /// zoom is derived from screen height at runtime, so everything that
  /// tracks the world has to read it rather than assume a constant.
  final double Function() cameraZoom;

  late final List<_ParallaxBand> _bands = [
    // Far crater rim - barely moves, sits highest.
    _ParallaxBand(
      factor: 0.08,
      verticalFactor: 0.16,
      color: GameConfig.mountainFar,
      amplitude: 120,
      wavelength: 620,
      seed: GameConfig.terrainSeed + 11,
    ),
    // Mid ridge.
    _ParallaxBand(
      factor: 0.20,
      verticalFactor: 0.24,
      color: GameConfig.mountainMid,
      amplitude: 95,
      wavelength: 430,
      seed: GameConfig.terrainSeed + 29,
    ),
    // Near dunes - noticeably faster, sits lowest.
    _ParallaxBand(
      factor: 0.42,
      verticalFactor: 0.32,
      color: GameConfig.mountainNear,
      amplitude: 74,
      wavelength: 310,
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

  /// Screen y of a given world y. The camera is centre-anchored, so world
  /// sea level lands at the middle of the screen plus the camera's own
  /// offset from it.
  double _screenY(double worldY, double h, Vector2 cam, double zoom) =>
      h / 2 + (worldY - cam.y) * zoom;

  @override
  void render(Canvas canvas) {
    final size = viewportSize();
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    final cam = cameraPosition();
    final zoom = cameraZoom();

    _renderSky(canvas, w, h);
    _renderStars(canvas, w, h, cam, zoom);
    _renderSun(canvas, w, h, cam, zoom);

    for (final band in _bands) {
      _renderBand(canvas, w, h, cam, zoom, band);
    }

    _renderDustHaze(canvas, w, h, cam, zoom);
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

  void _renderStars(
    Canvas canvas,
    double w,
    double h,
    Vector2 cam,
    double zoom,
  ) {
    // Stars drift the least of anything - almost, but not quite, fixed.
    final drift = -cam.x * zoom * 0.02;
    final lift = (GameConfig.terrainBaseY - cam.y) * zoom * 0.05;
    final paint = Paint();

    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      var x = (s.dx * w + drift) % w;
      if (x < 0) x += w;
      final y = s.dy * h + lift;
      if (y < 0 || y > h) continue;
      // Fade stars out toward the bright horizon.
      paint.color = const Color(0xFFFFE9D6).withOpacity(
        0.6 * (1.0 - (y / (h * 0.55))).clamp(0.0, 1.0),
      );
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.1 : 1.7, paint);
    }
  }

  void _renderSun(Canvas canvas, double w, double h, Vector2 cam, double zoom) {
    // A small, pale sun - Mars is 1.5 AU out.
    final cx = (w * 0.78) - cam.x * zoom * 0.03;
    final cy = h * 0.18 + (GameConfig.terrainBaseY - cam.y) * zoom * 0.06;

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
    double zoom,
    _ParallaxBand band,
  ) {
    // Anchor the band to the WORLD horizon (sea level), damped by the
    // band's vertical factor. Anchoring to a fixed fraction of screen
    // height instead would let the foreground terrain rise over the top of
    // the mountains as soon as the rover climbed anything.
    final baseline =
        h / 2 + (GameConfig.terrainBaseY - cam.y) * zoom * band.verticalFactor;

    // Nothing to draw if the band has scrolled entirely off-screen.
    if (baseline < -band.amplitude) return;

    // Camera x is in metres; convert to pixels before applying parallax.
    final offsetPx = cam.x * zoom * band.factor;

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
      // Map noise from [-1,1] to [0,1] rather than taking abs(). abs()
      // creases to a dead-flat line everywhere the noise crosses zero,
      // which drew a hard horizontal edge across the sky.
      final t = (n + 1) / 2;
      path.lineTo(x, baseline - t * band.amplitude);
    }

    path
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(path, Paint()..color = band.color);
  }

  void _renderDustHaze(
    Canvas canvas,
    double w,
    double h,
    Vector2 cam,
    double zoom,
  ) {
    // Warm dust sitting on the horizon, tying the sky to the ground.
    //
    // It fades in AND out: ending the band abruptly at the horizon left a
    // visible horizontal edge straight across the scene.
    final horizon = _screenY(GameConfig.terrainBaseY, h, cam, zoom);
    final top = horizon - h * 0.30;
    final bottom = horizon + h * 0.14;
    if (bottom <= 0 || top >= h) return;

    canvas.drawRect(
      Rect.fromLTWH(0, top, w, bottom - top),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            const Color(0x00E9A063),
            GameConfig.skyHorizon.withOpacity(0.30),
            const Color(0x00E9A063),
          ],
          const [0.0, 0.68, 1.0],
        ),
    );
  }
}
