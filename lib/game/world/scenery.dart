import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../terrain/noise.dart';

/// Things that grow on the ground.
///
/// A course is more than a colour. Mars reads as Mars because the ground is
/// bare - nothing grows there, and the emptiness is the point. Somewhere
/// green has to have things standing on it, or it is just the same terrain
/// tinted, and the eye reads it as the same place.
///
/// These are drawn, not sprited. A pine is a stack of triangles and a
/// trunk; a bush is three overlapping circles. That costs nothing, scales
/// to any zoom without art, and - the reason that actually matters - it
/// takes its colours from the level's own theme, so a new biome is a
/// palette rather than a folder of PNGs.
///
/// They carry no physics body. You drive through them, as you do in every
/// side-scrolling hill climber: a tree you can hit is a wall, and a wall in
/// a lane you cannot leave is just an unfair stop.

/// What grows on a given course, and how thickly.
class SceneryStyle {
  const SceneryStyle({
    required this.canopyDark,
    required this.canopyLight,
    required this.trunk,
    required this.undergrowth,
    required this.rock,
    this.spacing = 4.2,
    this.treeShare = 0.30,
    this.bushShare = 0.22,
    this.tuftShare = 0.40,
    this.minHeight = 3.0,
    this.maxHeight = 6.2,
  });

  /// Bare ground: what Mars uses, and the default.
  static const SceneryStyle none = SceneryStyle(
    canopyDark: Color(0x00000000),
    canopyLight: Color(0x00000000),
    trunk: Color(0x00000000),
    undergrowth: Color(0x00000000),
    rock: Color(0x00000000),
    spacing: 0,
  );

  bool get isEmpty => spacing <= 0;

  final Color canopyDark;
  final Color canopyLight;
  final Color trunk;
  final Color undergrowth;
  final Color rock;

  /// Average metres between props. Smaller is denser.
  final double spacing;

  /// How the population splits. Whatever is left over after these three is
  /// rock, so they should sum to less than one.
  final double treeShare;
  final double bushShare;
  final double tuftShare;

  /// Height range for a full-grown tree, in metres. A machine is about
  /// 3.2 m long, so 5 m reads as a proper tree without filling the screen.
  final double minHeight;
  final double maxHeight;
}

enum PropKind { pine, bush, tuft, rock }

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

  /// Metres, base to tip. Not `height`: PositionComponent already owns
  /// that, and it means the component's box, not the tree.
  final double extent;

  /// Radians of tilt. Everything leans a little; nothing in a field is
  /// plumb, and a row of perfectly upright trees reads as wallpaper.
  final double lean;

  /// -1..1 shade offset, so neighbouring props are not identical.
  final double tint;

  Color _shade(Color c) {
    final f = 1 + tint * 0.16;
    return Color.fromARGB(
      c.alpha,
      (c.red * f).clamp(0, 255).round(),
      (c.green * f).clamp(0, 255).round(),
      (c.blue * f).clamp(0, 255).round(),
    );
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..save()
      ..rotate(lean);

    switch (kind) {
      case PropKind.pine:
        _pine(canvas);
      case PropKind.bush:
        _bush(canvas);
      case PropKind.tuft:
        _tuft(canvas);
      case PropKind.rock:
        _rock(canvas);
    }

    canvas.restore();
  }

  /// A conifer: three stacked triangles narrowing towards the tip, over a
  /// short trunk. Each tier is drawn dark then overlaid with a lighter
  /// wedge on the sun side, which is what stops it reading as a flat
  /// cut-out.
  void _pine(Canvas canvas) {
    final trunkH = extent * 0.18;
    final trunkW = extent * 0.055;
    canvas.drawRect(
      Rect.fromLTWH(-trunkW / 2, -trunkH, trunkW, trunkH),
      Paint()..color = _shade(style.trunk),
    );

    final dark = Paint()..color = _shade(style.canopyDark);
    final light = Paint()..color = _shade(style.canopyLight);

    final canopyH = extent - trunkH;
    const tiers = 3;
    for (var i = 0; i < tiers; i++) {
      // Tier 0 is the widest and lowest; each one above is smaller and
      // overlaps the one below.
      final t = i / tiers;
      final tierBase = -trunkH - canopyH * t * 0.72;
      final tierH = canopyH * (0.52 - i * 0.09);
      final halfW = extent * (0.20 - i * 0.045);

      final tri = Path()
        ..moveTo(0, tierBase - tierH)
        ..lineTo(-halfW, tierBase)
        ..lineTo(halfW, tierBase)
        ..close();
      canvas.drawPath(tri, dark);

      // Sun side: the same wedge, right half only.
      final lit = Path()
        ..moveTo(0, tierBase - tierH)
        ..lineTo(halfW * 0.86, tierBase)
        ..lineTo(0, tierBase)
        ..close();
      canvas.drawPath(lit, light);
    }
  }

  /// Three overlapping circles, the front one lighter.
  void _bush(Canvas canvas) {
    final r = extent * 0.42;
    final dark = Paint()..color = _shade(style.canopyDark);
    final light = Paint()..color = _shade(style.canopyLight);

    canvas
      ..drawCircle(Offset(-r * 0.7, -r * 0.85), r * 0.78, dark)
      ..drawCircle(Offset(r * 0.7, -r * 0.8), r * 0.72, dark)
      ..drawCircle(Offset(0, -r * 1.15), r * 0.95, dark)
      ..drawCircle(Offset(r * 0.22, -r * 1.05), r * 0.6, light);
  }

  /// A few blades fanning out of one point.
  void _tuft(Canvas canvas) {
    final paint = Paint()
      ..color = _shade(style.undergrowth)
      ..style = PaintingStyle.stroke
      ..strokeWidth = extent * 0.1
      ..strokeCap = StrokeCap.round;

    for (var i = -2; i <= 2; i++) {
      final spread = i * 0.28;
      final blade = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
          extent * spread * 0.5,
          -extent * 0.6,
          extent * spread,
          -extent * (1 - spread.abs() * 0.5),
        );
      canvas.drawPath(blade, paint);
    }
  }

  /// A lump, flat on the ground.
  void _rock(Canvas canvas) {
    final w = extent * 1.5;
    final lump = Path()
      ..moveTo(-w / 2, 0)
      ..quadraticBezierTo(-w * 0.42, -extent, -w * 0.06, -extent * 0.92)
      ..quadraticBezierTo(w * 0.36, -extent * 0.82, w / 2, 0)
      ..close();
    canvas
      ..drawPath(lump, Paint()..color = _shade(style.rock))
      ..drawPath(
        Path()
          ..moveTo(-w * 0.1, -extent * 0.9)
          ..quadraticBezierTo(w * 0.3, -extent * 0.75, w * 0.46, -extent * 0.06)
          ..lineTo(w * 0.2, -extent * 0.1)
          ..close(),
        Paint()..color = _shade(style.canopyLight).withOpacity(0.18),
      );
  }
}

/// Pick what grows at a point, given a roll in 0..1.
PropKind kindFor(SceneryStyle style, double roll) {
  if (roll < style.treeShare) return PropKind.pine;
  if (roll < style.treeShare + style.bushShare) return PropKind.bush;
  if (roll < style.treeShare + style.bushShare + style.tuftShare) {
    return PropKind.tuft;
  }
  return PropKind.rock;
}

/// How tall a prop of this kind grows, as a fraction of the style's tree
/// extent. Undergrowth is knee-high; a rock is barely more than a bump.
double heightScaleFor(PropKind kind) => switch (kind) {
      PropKind.pine => 1.0,
      PropKind.bush => 0.34,
      PropKind.tuft => 0.16,
      PropKind.rock => 0.20,
    };

/// Trees lean; a rock does not.
double leanFor(PropKind kind, double roll) => switch (kind) {
      PropKind.pine => (roll - 0.5) * 0.12,
      PropKind.bush => (roll - 0.5) * 0.16,
      PropKind.tuft => (roll - 0.5) * 0.5,
      PropKind.rock => 0.0,
    };

/// Sunlit greens for a temperate meadow.
const SceneryStyle meadowScenery = SceneryStyle(
  canopyDark: Color(0xFF2F6B3A),
  canopyLight: Color(0xFF57A34C),
  trunk: Color(0xFF5A3F2B),
  undergrowth: Color(0xFF6FBF54),
  rock: Color(0xFF8C9384),
  spacing: 4.2,
);

/// Everything a course needs to place its own scenery, kept next to the
/// maths that does it.
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
/// the identical wood rather than a fresh random one - otherwise the
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
