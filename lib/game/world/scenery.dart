import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../terrain/noise.dart';

/// The things that stand on the ground, and make one course a *place*.
///
/// A theme swap alone does not make a new location. Recolouring the same
/// bare ground gives you the same course tinted, and the eye is not fooled
/// - what tells you where you are is what is growing, rusting or standing
/// around you. A pine says alpine. A cactus says desert. A floodlight mast
/// says stadium. So a biome here is a palette AND a cast of props.
///
/// Everything is drawn rather than sprited. Each shape is a handful of
/// paths taking their colours from the level's own style, which means a new
/// location costs a palette and a prop mix rather than a folder of PNGs,
/// and every shape stays crisp at any zoom.
///
/// None of them carry a physics body. A tree you can hit is a wall, and a
/// wall in a lane you cannot leave is just an unfair stop.

/// Everything a course can have standing on it.
enum PropKind {
  /// Conifer, three tiers over a short trunk.
  pine,

  /// The same tree under snow: white caps on every tier.
  snowPine,

  /// Bare branching trunk. Winter, or dead.
  deadTree,

  /// Saguaro: a column with two raised arms.
  cactus,

  /// Leaning trunk with a fan of fronds.
  palm,

  /// Low rounded foliage.
  bush,

  /// A few blades of grass.
  tuft,

  /// A lump on the ground.
  rock,

  /// Stacked shipping crates.
  crate,

  /// Oil drum, with hoops.
  barrel,

  /// Steel lattice tower, tapering.
  pylon,

  /// Mast with an angled lamp head and the light it throws.
  floodlight,

  /// Post-and-rail, two bars.
  fence,

  /// Rounded headstone.
  gravestone,

  /// Pole with a pennant.
  banner,

  /// Wind-carved rock needle. What erosion leaves behind when there is
  /// nothing growing to hold the ground together.
  spire,

  /// Tilted solar array on legs.
  solarPanel,

  /// Short post with a lamp on it, and a halo around the lamp.
  beacon,
}

/// What grows - or rusts, or stands - on a given course.
class SceneryStyle {
  const SceneryStyle({
    required this.bodyDark,
    required this.bodyLight,
    required this.stem,
    required this.detail,
    required this.stone,
    required this.mix,
    this.spacing = 4.2,
    this.minHeight = 3.0,
    this.maxHeight = 6.2,
  });

  /// Bare ground: what Mars uses, and the default.
  static const SceneryStyle none = SceneryStyle(
    bodyDark: Color(0x00000000),
    bodyLight: Color(0x00000000),
    stem: Color(0x00000000),
    detail: Color(0x00000000),
    stone: Color(0x00000000),
    mix: {},
    spacing: 0,
  );

  bool get isEmpty => spacing <= 0 || mix.isEmpty;

  /// The main mass of a prop - canopy, cactus flesh, crate face.
  final Color bodyDark;

  /// Its sunlit side. Everything is drawn dark then lit on the right, which
  /// is what stops a flat shape reading as a cut-out.
  final Color bodyLight;

  /// Trunks, poles, masts, steelwork.
  final Color stem;

  /// Grass, snow caps, glass, banding - the small bright bits.
  final Color detail;

  /// Rock, concrete, stone.
  final Color stone;

  /// What stands here and in what proportion. Weights need not sum to one.
  final Map<PropKind, double> mix;

  /// Average metres between props. Smaller is denser.
  final double spacing;

  /// Height range for a full-size prop, in metres. A machine is about
  /// 3.2 m long, so 6 m reads as a proper tree without filling the screen.
  final double minHeight;
  final double maxHeight;
}

/// One thing standing on the ground.
///
/// Positioned at its BASE, so placing it is just `surfaceY(x)` - no need to
/// know how tall it turned out.
class SceneryProp extends PositionComponent {
  SceneryProp({
    required Vector2 base,
    required this.kind,
    required this.style,
    required this.extent,
    required this.lean,
    required this.tint,
  }) : super(position: base, priority: _priority) {
    anchor = Anchor.bottomCenter;
  }

  /// Above the terrain fill (-10) so props stand on the ground, below the
  /// machine (0) so you drive in front of them rather than through them.
  static const int _priority = -5;

  final PropKind kind;
  final SceneryStyle style;

  /// Metres, base to tip. Not `height`: PositionComponent already owns that
  /// name, and there it means the component's box, not the tree.
  final double extent;

  /// Radians of tilt. Nothing in a field is plumb, and a row of perfectly
  /// upright props reads as wallpaper.
  final double lean;

  /// -1..1 shade offset, so neighbours are not identical.
  final double tint;

  Color _shade(Color c) {
    final f = 1 + tint * 0.14;
    return Color.fromARGB(
      c.alpha,
      (c.red * f).clamp(0, 255).round(),
      (c.green * f).clamp(0, 255).round(),
      (c.blue * f).clamp(0, 255).round(),
    );
  }

  Paint get _dark => Paint()..color = _shade(style.bodyDark);
  Paint get _light => Paint()..color = _shade(style.bodyLight);
  Paint get _stemPaint => Paint()..color = _shade(style.stem);
  Paint get _detail => Paint()..color = _shade(style.detail);
  Paint get _stone => Paint()..color = _shade(style.stone);

  @override
  void render(Canvas canvas) {
    canvas
      ..save()
      ..rotate(lean);

    switch (kind) {
      case PropKind.pine:
        _conifer(canvas, snow: false);
      case PropKind.snowPine:
        _conifer(canvas, snow: true);
      case PropKind.deadTree:
        _deadTree(canvas);
      case PropKind.cactus:
        _cactus(canvas);
      case PropKind.palm:
        _palm(canvas);
      case PropKind.bush:
        _bush(canvas);
      case PropKind.tuft:
        _tuft(canvas);
      case PropKind.rock:
        _rock(canvas);
      case PropKind.crate:
        _crate(canvas);
      case PropKind.barrel:
        _barrel(canvas);
      case PropKind.pylon:
        _pylon(canvas);
      case PropKind.floodlight:
        _floodlight(canvas);
      case PropKind.fence:
        _fence(canvas);
      case PropKind.gravestone:
        _gravestone(canvas);
      case PropKind.banner:
        _banner(canvas);
      case PropKind.spire:
        _spire(canvas);
      case PropKind.solarPanel:
        _solarPanel(canvas);
      case PropKind.beacon:
        _beacon(canvas);
    }

    canvas.restore();
  }

  // --- growing things -------------------------------------------------

  /// Three stacked triangles over a short trunk, narrowing to the tip.
  /// With [snow], each tier gets a cap sitting on its shoulders.
  void _conifer(Canvas canvas, {required bool snow}) {
    final trunkH = extent * 0.18;
    final trunkW = extent * 0.055;
    canvas.drawRect(
      Rect.fromLTWH(-trunkW / 2, -trunkH, trunkW, trunkH),
      _stemPaint,
    );

    final canopyH = extent - trunkH;
    const tiers = 3;
    for (var i = 0; i < tiers; i++) {
      final t = i / tiers;
      final base = -trunkH - canopyH * t * 0.72;
      final h = canopyH * (0.52 - i * 0.09);
      final halfW = extent * (0.20 - i * 0.045);

      canvas
        ..drawPath(
          Path()
            ..moveTo(0, base - h)
            ..lineTo(-halfW, base)
            ..lineTo(halfW, base)
            ..close(),
          _dark,
        )
        // Sun side: the same wedge, right half only.
        ..drawPath(
          Path()
            ..moveTo(0, base - h)
            ..lineTo(halfW * 0.86, base)
            ..lineTo(0, base)
            ..close(),
          _light,
        );

      if (snow) {
        // Snow settles on the upper third and sags at the edges, which is
        // what makes it read as weight rather than as paint.
        final snowH = h * 0.44;
        canvas.drawPath(
          Path()
            ..moveTo(0, base - h)
            ..lineTo(-halfW * 0.46, base - h + snowH)
            ..quadraticBezierTo(
              -halfW * 0.2,
              base - h + snowH * 0.55,
              0,
              base - h + snowH * 0.78,
            )
            ..quadraticBezierTo(
              halfW * 0.2,
              base - h + snowH * 0.55,
              halfW * 0.46,
              base - h + snowH,
            )
            ..close(),
          _detail,
        );
      }
    }
  }

  /// A trunk that forks, with bare limbs reaching up and out.
  void _deadTree(Canvas canvas) {
    final paint = Paint()
      ..color = _shade(style.stem)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = extent * 0.09;

    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
            extent * 0.04, -extent * 0.5, -extent * 0.03, -extent * 0.62),
      paint,
    );

    // Limbs off the fork, alternating sides and shortening upwards.
    paint.strokeWidth = extent * 0.045;
    const limbs = [
      (-1.0, 0.62, 0.30, 0.92),
      (1.0, 0.58, 0.26, 0.86),
      (-1.0, 0.80, 0.18, 1.00),
      (1.0, 0.84, 0.15, 1.02),
    ];
    for (final (side, from, reach, to) in limbs) {
      canvas.drawPath(
        Path()
          ..moveTo(-extent * 0.03, -extent * from)
          ..quadraticBezierTo(
            side * extent * reach * 0.6,
            -extent * (from + (to - from) * 0.4),
            side * extent * reach,
            -extent * to,
          ),
        paint,
      );
    }
  }

  /// Saguaro: a fat column with two arms raised to different heights.
  void _cactus(Canvas canvas) {
    final w = extent * 0.22;

    void column(double cx, double bottom, double top, double width) {
      canvas
        ..drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(cx - width / 2, -top, cx + width / 2, -bottom),
            topLeft: Radius.circular(width / 2),
            topRight: Radius.circular(width / 2),
          ),
          _dark,
        )
        // A lit rib down the sunward side.
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx + width * 0.10,
              -top + width * 0.4,
              cx + width * 0.34,
              -bottom,
            ),
            Radius.circular(width * 0.12),
          ),
          _light,
        );
    }

    column(0, 0, extent, w);

    // Arms: elbow out, then up.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-extent * 0.30, -extent * 0.56, 0, -extent * 0.44),
        Radius.circular(w / 2),
      ),
      _dark,
    );
    column(-extent * 0.26, extent * 0.44, extent * 0.78, w * 0.72);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, -extent * 0.42, extent * 0.26, -extent * 0.32),
        Radius.circular(w / 2),
      ),
      _dark,
    );
    column(extent * 0.23, extent * 0.32, extent * 0.60, w * 0.66);
  }

  /// Curved trunk with a fan of fronds at the top.
  void _palm(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(-extent * 0.04, 0)
        ..quadraticBezierTo(
            extent * 0.10, -extent * 0.45, extent * 0.14, -extent * 0.78)
        ..lineTo(extent * 0.22, -extent * 0.78)
        ..quadraticBezierTo(extent * 0.18, -extent * 0.45, extent * 0.06, 0)
        ..close(),
      _stemPaint,
    );

    const fronds = [-1.0, -0.62, -0.2, 0.2, 0.62, 1.0];
    for (final f in fronds) {
      canvas.drawPath(
        Path()
          ..moveTo(extent * 0.18, -extent * 0.78)
          ..quadraticBezierTo(
            extent * (0.18 + f * 0.30),
            -extent * (0.94 - f.abs() * 0.04),
            extent * (0.18 + f * 0.42),
            -extent * (0.78 - f.abs() * 0.10),
          )
          ..quadraticBezierTo(
            extent * (0.18 + f * 0.26),
            -extent * 0.82,
            extent * 0.18,
            -extent * 0.78,
          )
          ..close(),
        f > 0 ? _light : _dark,
      );
    }
  }

  /// Three overlapping circles, the front one lighter.
  void _bush(Canvas canvas) {
    final r = extent * 0.42;
    canvas
      ..drawCircle(Offset(-r * 0.7, -r * 0.85), r * 0.78, _dark)
      ..drawCircle(Offset(r * 0.7, -r * 0.8), r * 0.72, _dark)
      ..drawCircle(Offset(0, -r * 1.15), r * 0.95, _dark)
      ..drawCircle(Offset(r * 0.22, -r * 1.05), r * 0.6, _light);
  }

  /// A few blades fanning out of one point.
  void _tuft(Canvas canvas) {
    final paint = Paint()
      ..color = _shade(style.detail)
      ..style = PaintingStyle.stroke
      ..strokeWidth = extent * 0.1
      ..strokeCap = StrokeCap.round;

    for (var i = -2; i <= 2; i++) {
      final spread = i * 0.28;
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(
            extent * spread * 0.5,
            -extent * 0.6,
            extent * spread,
            -extent * (1 - spread.abs() * 0.5),
          ),
        paint,
      );
    }
  }

  /// A lump, flat on the ground.
  void _rock(Canvas canvas) {
    final w = extent * 1.5;
    canvas
      ..drawPath(
        Path()
          ..moveTo(-w / 2, 0)
          ..quadraticBezierTo(-w * 0.42, -extent, -w * 0.06, -extent * 0.92)
          ..quadraticBezierTo(w * 0.36, -extent * 0.82, w / 2, 0)
          ..close(),
        _stone,
      )
      ..drawPath(
        Path()
          ..moveTo(-w * 0.1, -extent * 0.9)
          ..quadraticBezierTo(w * 0.3, -extent * 0.75, w * 0.46, -extent * 0.06)
          ..lineTo(w * 0.2, -extent * 0.1)
          ..close(),
        Paint()..color = _shade(style.bodyLight).withOpacity(0.16),
      );
  }

  // --- built things ---------------------------------------------------

  /// Two boxes stacked, the top one offset and smaller.
  void _crate(Canvas canvas) {
    final s = extent * 0.62;

    void box(double cx, double bottom, double size) {
      final rect = Rect.fromLTWH(cx - size / 2, -bottom - size, size, size);
      canvas
        ..drawRect(rect, _dark)
        ..drawRect(
          Rect.fromLTWH(rect.left + size * 0.62, rect.top, size * 0.38, size),
          _light,
        )
        // A strap across the middle.
        ..drawRect(
          Rect.fromLTWH(rect.left, rect.top + size * 0.42, size, size * 0.14),
          _detail,
        );
    }

    box(0, 0, s);
    box(s * 0.22, s, s * 0.74);
  }

  /// A drum: rounded body, two hoops.
  void _barrel(Canvas canvas) {
    final w = extent * 0.62;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w / 2, -extent, w, extent),
          Radius.circular(w * 0.16),
        ),
        _dark,
      )
      ..drawRect(Rect.fromLTWH(w * 0.06, -extent, w * 0.30, extent), _light);
    for (final f in [0.26, 0.66]) {
      canvas.drawRect(
        Rect.fromLTWH(-w / 2, -extent * f, w, extent * 0.07),
        _detail,
      );
    }
  }

  /// Steel lattice, tapering, with cross-bracing. The X-bracing is what
  /// makes it read as a tower rather than a post.
  void _pylon(Canvas canvas) {
    final paint = Paint()
      ..color = _shade(style.stem)
      ..style = PaintingStyle.stroke
      ..strokeWidth = extent * 0.035
      ..strokeCap = StrokeCap.round;

    double halfAt(double t) => extent * (0.20 - 0.13 * t);

    canvas
      ..drawLine(Offset(-halfAt(0), 0), Offset(-halfAt(1), -extent), paint)
      ..drawLine(Offset(halfAt(0), 0), Offset(halfAt(1), -extent), paint);

    const rungs = 4;
    for (var i = 0; i < rungs; i++) {
      final t0 = i / rungs;
      final t1 = (i + 1) / rungs;
      final y0 = -extent * t0;
      final y1 = -extent * t1;
      canvas
        ..drawLine(Offset(-halfAt(t1), y1), Offset(halfAt(t1), y1), paint)
        ..drawLine(Offset(-halfAt(t0), y0), Offset(halfAt(t1), y1), paint)
        ..drawLine(Offset(halfAt(t0), y0), Offset(-halfAt(t1), y1), paint);
    }
  }

  /// A mast, a lamp head tipped forward, and the light it throws.
  void _floodlight(Canvas canvas) {
    final mastW = extent * 0.05;
    canvas.drawRect(
      Rect.fromLTWH(-mastW / 2, -extent * 0.9, mastW, extent * 0.9),
      _stemPaint,
    );

    final headW = extent * 0.30;
    final headH = extent * 0.16;
    canvas
      ..drawPath(
        Path()
          ..moveTo(-headW * 0.2, -extent)
          ..lineTo(headW * 0.8, -extent + headH * 0.35)
          ..lineTo(headW * 0.8, -extent + headH * 1.15)
          ..lineTo(-headW * 0.2, -extent + headH * 0.8)
          ..close(),
        _dark,
      )
      // The beam, faint and only a suggestion: a hard cone reads as a
      // solid object sitting in front of the machine.
      ..drawPath(
        Path()
          ..moveTo(headW * 0.7, -extent + headH * 0.5)
          ..lineTo(extent * 1.15, -extent * 0.25)
          ..lineTo(extent * 0.95, -extent * 0.02)
          ..lineTo(headW * 0.7, -extent + headH * 1.1)
          ..close(),
        Paint()..color = _shade(style.detail).withOpacity(0.14),
      )
      ..drawCircle(
        Offset(headW * 0.72, -extent + headH * 0.75),
        headH * 0.28,
        _detail,
      );
  }

  /// Two posts and two rails, running along the ground.
  void _fence(Canvas canvas) {
    final w = extent * 2.1;
    final postW = extent * 0.14;

    for (final f in [-0.5, 0.5]) {
      canvas.drawRect(
        Rect.fromLTWH(w * f - postW / 2, -extent, postW, extent),
        _stemPaint,
      );
    }
    for (final h in [0.38, 0.76]) {
      canvas.drawRect(
        Rect.fromLTWH(-w / 2, -extent * h, w, extent * 0.11),
        _dark,
      );
    }
  }

  /// A slab with a rounded top.
  void _gravestone(Canvas canvas) {
    final w = extent * 0.72;
    canvas
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(-w / 2, -extent, w, extent),
          topLeft: Radius.circular(w / 2),
          topRight: Radius.circular(w / 2),
        ),
        _stone,
      )
      ..drawRect(
        Rect.fromLTWH(w * 0.10, -extent * 0.82, w * 0.22, extent * 0.7),
        Paint()..color = _shade(style.bodyLight).withOpacity(0.18),
      );
  }

  /// Pole with a pennant streaming off it.
  void _banner(Canvas canvas) {
    final poleW = extent * 0.05;
    canvas
      ..drawRect(Rect.fromLTWH(-poleW / 2, -extent, poleW, extent), _stemPaint)
      ..drawPath(
        Path()
          ..moveTo(0, -extent)
          ..lineTo(extent * 0.52, -extent * 0.90)
          ..lineTo(0, -extent * 0.72)
          ..close(),
        _dark,
      )
      ..drawPath(
        Path()
          ..moveTo(0, -extent * 0.90)
          ..lineTo(extent * 0.40, -extent * 0.855)
          ..lineTo(0, -extent * 0.78)
          ..close(),
        _light,
      );
  }

  /// A needle of rock, wider at the foot, with a step partway up where a
  /// harder layer resisted the wind.
  void _spire(Canvas canvas) {
    final w = extent * 0.30;
    canvas
      ..drawPath(
        Path()
          ..moveTo(-w, 0)
          ..lineTo(-w * 0.52, -extent * 0.46)
          ..lineTo(-w * 0.66, -extent * 0.52)
          ..lineTo(-w * 0.20, -extent)
          ..lineTo(w * 0.22, -extent * 0.94)
          ..lineTo(w * 0.50, -extent * 0.50)
          ..lineTo(w * 0.86, 0)
          ..close(),
        _stone,
      )
      // Sunward face, brighter, following the same taper.
      ..drawPath(
        Path()
          ..moveTo(w * 0.06, -extent * 0.98)
          ..lineTo(w * 0.50, -extent * 0.50)
          ..lineTo(w * 0.80, -extent * 0.04)
          ..lineTo(w * 0.30, -extent * 0.06)
          ..lineTo(w * 0.10, -extent * 0.50)
          ..close(),
        Paint()..color = _shade(style.bodyLight).withOpacity(0.30),
      );
  }

  /// Two legs and a panel tipped towards the sun, with cell divisions.
  void _solarPanel(Canvas canvas) {
    final w = extent * 1.5;
    final legW = extent * 0.07;

    for (final f in [-0.28, 0.28]) {
      canvas.drawRect(
        Rect.fromLTWH(w * f - legW / 2, -extent * 0.55, legW, extent * 0.55),
        _stemPaint,
      );
    }

    // The panel: a parallelogram, low edge forward.
    final panel = Path()
      ..moveTo(-w * 0.5, -extent * 0.52)
      ..lineTo(w * 0.5, -extent * 0.98)
      ..lineTo(w * 0.5, -extent * 0.86)
      ..lineTo(-w * 0.5, -extent * 0.40)
      ..close();
    canvas.drawPath(panel, _dark);

    final cell = Paint()
      ..color = _shade(style.detail)
      ..style = PaintingStyle.stroke
      ..strokeWidth = extent * 0.02;
    for (var i = 1; i < 4; i++) {
      final t = i / 4;
      canvas.drawLine(
        Offset(-w * 0.5 + w * t, -extent * (0.52 - 0.46 * t)),
        Offset(-w * 0.5 + w * t, -extent * (0.40 - 0.46 * t)),
        cell,
      );
    }
  }

  /// A stubby post with a lit lamp, and a soft halo so it reads as a
  /// source rather than a painted dot.
  void _beacon(Canvas canvas) {
    final postW = extent * 0.16;
    canvas
      ..drawRect(
        Rect.fromLTWH(-postW / 2, -extent * 0.7, postW, extent * 0.7),
        _stemPaint,
      )
      ..drawCircle(
        Offset(0, -extent * 0.82),
        extent * 0.34,
        Paint()..color = _shade(style.detail).withOpacity(0.20),
      )
      ..drawCircle(Offset(0, -extent * 0.82), extent * 0.17, _detail)
      ..drawRect(
        Rect.fromLTWH(-postW * 0.9, -extent, postW * 1.8, extent * 0.06),
        _dark,
      );
  }
}

// --- placement --------------------------------------------------------

/// Pick a prop from the style's weighted mix.
PropKind kindFor(SceneryStyle style, double roll) {
  final total = style.mix.values.fold(0.0, (a, b) => a + b);
  var t = roll * total;
  for (final entry in style.mix.entries) {
    t -= entry.value;
    if (t <= 0) return entry.key;
  }
  return style.mix.keys.last;
}

/// How tall a prop grows relative to the style's full height. A tree is
/// full size; undergrowth is knee-high; a rock is barely a bump.
double heightScaleFor(PropKind kind) => switch (kind) {
      PropKind.pine || PropKind.snowPine => 1.0,
      PropKind.deadTree => 0.86,
      PropKind.palm => 0.92,
      PropKind.pylon => 1.15,
      PropKind.floodlight => 1.30,
      PropKind.cactus => 0.62,
      PropKind.bush => 0.34,
      PropKind.crate => 0.42,
      PropKind.barrel => 0.34,
      PropKind.banner => 0.55,
      PropKind.gravestone => 0.26,
      PropKind.fence => 0.22,
      PropKind.tuft => 0.16,
      PropKind.rock => 0.20,
      PropKind.spire => 1.05,
      PropKind.solarPanel => 0.32,
      PropKind.beacon => 0.30,
    };

/// Living things lean; built things stand straighter, and a rock not at all.
double leanFor(PropKind kind, double roll) => switch (kind) {
      PropKind.pine || PropKind.snowPine => (roll - 0.5) * 0.12,
      PropKind.deadTree => (roll - 0.5) * 0.24,
      PropKind.palm => (roll - 0.5) * 0.20,
      PropKind.cactus => (roll - 0.5) * 0.08,
      PropKind.bush => (roll - 0.5) * 0.16,
      PropKind.tuft => (roll - 0.5) * 0.5,
      PropKind.gravestone => (roll - 0.5) * 0.28,
      PropKind.crate || PropKind.barrel => (roll - 0.5) * 0.10,
      PropKind.spire => (roll - 0.5) * 0.10,
      PropKind.rock ||
      PropKind.pylon ||
      PropKind.floodlight ||
      PropKind.fence ||
      PropKind.banner ||
      PropKind.solarPanel ||
      PropKind.beacon =>
        0.0,
    };

double propHeight(SceneryStyle style, PropKind kind, double roll) =>
    (style.minHeight + (style.maxHeight - style.minHeight) * roll) *
    heightScaleFor(kind);

/// Every prop standing in one terrain chunk.
///
/// This is THE placement, used by the streaming manager in the game and by
/// the preview render alike. It exists as a shared function rather than a
/// method on the manager for one reason learned the hard way on this
/// project: a preview that lays the world out itself proves nothing about
/// the world the game actually builds.
///
/// Seeded off the chunk index, so a chunk culled and streamed back rebuilds
/// the identical scene rather than a fresh random one - otherwise the
/// scenery visibly reshuffles behind you.
List<SceneryProp> sceneryForChunk({
  required SceneryStyle style,
  required int seed,
  required int index,
  required double chunkWidth,
  required double Function(double x) surfaceY,
}) {
  if (style.isEmpty) return const [];

  final startX = index * chunkWidth;
  final endX = startX + chunkWidth;
  final rng = SeededRandom(seed ^ (index * 40503));
  final props = <SceneryProp>[];

  var x = startX + rng.range(0, style.spacing);
  while (x < endX) {
    final kind = kindFor(style, rng.next());
    props.add(
      SceneryProp(
        base: Vector2(x, surfaceY(x)),
        kind: kind,
        style: style,
        extent: propHeight(style, kind, rng.next()),
        lean: leanFor(kind, rng.next()),
        tint: rng.range(-1, 1),
      ),
    );
    x += rng.range(style.spacing * 0.45, style.spacing * 1.55);
  }

  return props;
}

/// Small helper so callers do not have to import dart:math for a clamp.
double clamp01(double v) => math.min(1, math.max(0, v));

// --- the biomes -------------------------------------------------------

/// Sunlit valley: pines, bushes and long grass.
const SceneryStyle meadowScenery = SceneryStyle(
  bodyDark: Color(0xFF2F6B3A),
  bodyLight: Color(0xFF57A34C),
  stem: Color(0xFF5A3F2B),
  detail: Color(0xFF6FBF54),
  stone: Color(0xFF8C9384),
  mix: {
    PropKind.pine: 0.30,
    PropKind.bush: 0.22,
    PropKind.tuft: 0.40,
    PropKind.rock: 0.08,
  },
);

/// Alpine: snow-laden conifers, bare rock breaking through, drifts.
const SceneryStyle snowScenery = SceneryStyle(
  bodyDark: Color(0xFF1F4A3D),
  bodyLight: Color(0xFF2F6B55),
  stem: Color(0xFF4A3A32),
  detail: Color(0xFFF4FAFF),
  stone: Color(0xFF9AA9BC),
  mix: {
    PropKind.snowPine: 0.44,
    PropKind.rock: 0.20,
    PropKind.deadTree: 0.10,
    PropKind.bush: 0.26,
  },
  spacing: 4.6,
);

/// Refinery yard: lattice towers, crates, drums and wire fence.
const SceneryStyle industrialScenery = SceneryStyle(
  bodyDark: Color(0xFF5A5A4A),
  bodyLight: Color(0xFF8A8570),
  stem: Color(0xFF6E4A2C),
  detail: Color(0xFFD8A63C),
  stone: Color(0xFF6B6B62),
  mix: {
    PropKind.pylon: 0.22,
    PropKind.crate: 0.28,
    PropKind.barrel: 0.28,
    PropKind.fence: 0.14,
    PropKind.rock: 0.08,
  },
  spacing: 3.6,
);

/// Moorland at night: dead trees, headstones, broken fencing.
const SceneryStyle hauntedScenery = SceneryStyle(
  bodyDark: Color(0xFF2A2438),
  bodyLight: Color(0xFF4A4160),
  stem: Color(0xFF3B3348),
  detail: Color(0xFF7FE6D0),
  stone: Color(0xFF6C6880),
  mix: {
    PropKind.deadTree: 0.36,
    PropKind.gravestone: 0.24,
    PropKind.fence: 0.20,
    PropKind.rock: 0.12,
    PropKind.bush: 0.08,
  },
  spacing: 5.4,
);

/// Stadium: floodlight masts, pennants, marker crates.
const SceneryStyle arenaScenery = SceneryStyle(
  bodyDark: Color(0xFF7A2230),
  bodyLight: Color(0xFFC24455),
  stem: Color(0xFF9EA6B4),
  detail: Color(0xFFFFF3C4),
  stone: Color(0xFF8B8F99),
  mix: {
    PropKind.floodlight: 0.26,
    PropKind.banner: 0.34,
    PropKind.crate: 0.22,
    PropKind.fence: 0.18,
  },
  spacing: 6.0,
);

/// Desert: saguaro, sun-bleached posts, boulders and dry scrub.
const SceneryStyle desertScenery = SceneryStyle(
  bodyDark: Color(0xFF4E7A3A),
  bodyLight: Color(0xFF7BA84F),
  stem: Color(0xFF8A6A45),
  detail: Color(0xFFC8B672),
  stone: Color(0xFFA9825C),
  mix: {
    PropKind.cactus: 0.34,
    PropKind.rock: 0.24,
    PropKind.fence: 0.16,
    PropKind.tuft: 0.26,
  },
  spacing: 5.2,
);

/// Chryse: a surveyed basin. Somebody has been here - masts, arrays and
/// supply cases left standing between the boulders.
const SceneryStyle marsSurveyScenery = SceneryStyle(
  bodyDark: Color(0xFF4C3A30),
  bodyLight: Color(0xFF8A6A50),
  stem: Color(0xFF9A9086),
  detail: Color(0xFF63C8E0),
  stone: Color(0xFF8A5636),
  mix: {
    PropKind.rock: 0.34,
    PropKind.solarPanel: 0.20,
    PropKind.pylon: 0.14,
    PropKind.crate: 0.20,
    PropKind.fence: 0.12,
  },
  spacing: 5.0,
);

/// Tharsis: nothing built, nothing living. Wind-carved needles and
/// tattered route markers, which is all that survives out here.
const SceneryStyle marsStormScenery = SceneryStyle(
  bodyDark: Color(0xFF6B4A28),
  bodyLight: Color(0xFFC79A5A),
  stem: Color(0xFF7A6244),
  detail: Color(0xFFD8B25E),
  stone: Color(0xFF8C6238),
  mix: {
    PropKind.spire: 0.40,
    PropKind.rock: 0.30,
    PropKind.banner: 0.16,
    PropKind.fence: 0.14,
  },
  spacing: 5.4,
);

/// Olympus at night: ice needles and the beacons that mark the route up.
const SceneryStyle marsPolarScenery = SceneryStyle(
  bodyDark: Color(0xFF3A2E48),
  bodyLight: Color(0xFF8E7CB0),
  stem: Color(0xFF5A4E70),
  detail: Color(0xFFFFB24B),
  stone: Color(0xFF5C4E70),
  mix: {
    PropKind.spire: 0.34,
    PropKind.beacon: 0.26,
    PropKind.rock: 0.28,
    PropKind.pylon: 0.12,
  },
  spacing: 5.6,
);

/// A tropical shore: palms leaning off the dune, sea grape and dune grass.
const SceneryStyle beachScenery = SceneryStyle(
  bodyDark: Color(0xFF2E7A4E),
  bodyLight: Color(0xFF57B472),
  stem: Color(0xFF8A6742),
  detail: Color(0xFFCFD98A),
  stone: Color(0xFFB9A386),
  mix: {
    PropKind.palm: 0.34,
    PropKind.bush: 0.22,
    PropKind.tuft: 0.32,
    PropKind.rock: 0.12,
  },
  spacing: 4.4,
);
