import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import 'terrain_generator.dart';

/// One slice of Martian ground: a Forge2D chain shape plus the reddish
/// fill rendered beneath it.
///
/// The body sits at the world origin and stores absolute vertices, so
/// body-local space == world space. That keeps the render path trivial.
class TerrainChunk extends BodyComponent {
  TerrainChunk({
    required this.index,
    required TerrainGenerator generator,
  })  : _generator = generator,
        startX = index * GameConfig.terrainChunkWidth,
        endX = (index + 1) * GameConfig.terrainChunkWidth {
    renderBody = false;
    priority = -10;
  }

  final int index;
  final TerrainGenerator _generator;
  final double startX;
  final double endX;

  /// Physics vertices: exactly this chunk's span, so neighbouring chains
  /// share an endpoint and the collision surface has no gap.
  late final List<Vector2> _points = _generator.sample(startX, endX);

  /// Render vertices: deliberately overlap the neighbours by a little.
  ///
  /// Two antialiased polygons that share an edge blend against each other
  /// along it and leave a visible hairline seam at every chunk join.
  /// Overlapping the *fill* (never the physics) hides that completely.
  late final List<Vector2> _renderPoints = _generator.sample(
    startX - _fillOverlap,
    endX + _fillOverlap,
  );

  /// Metres of fill overlap into each neighbour.
  static const double _fillOverlap = 1.0;

  Path? _fillPath;
  Path? _crustPath;

  /// How far above sea level the ground gradient starts. Constant across
  /// every chunk so the fill is continuous along the whole course.
  static const double _gradientTopMetres = 8.0;

  @override
  Body createBody() {
    final shape = ChainShape()..createChain(_points);

    // Ghost vertices: tell the chain what the neighbouring chunks look
    // like so wheels don't snag on the seam between two chunks.
    const spacing = GameConfig.terrainPointSpacing;
    // Assigning these also flips the shape's internal hasPrev/hasNext flags.
    shape
      ..prevVertex = Vector2(
        startX - spacing,
        _generator.surfaceY(startX - spacing),
      )
      ..nextVertex = Vector2(
        endX + spacing,
        _generator.surfaceY(endX + spacing),
      );

    final fixtureDef = FixtureDef(shape)
      ..friction = GameConfig.terrainFriction
      ..restitution = GameConfig.terrainRestitution
      ..filter.categoryBits = GameConfig.categoryTerrain
      ..filter.maskBits = GameConfig.categoryVehicle |
          GameConfig.categoryDriver |
          GameConfig.categoryPickup;

    final bodyDef = BodyDef(
      type: BodyType.static,
      position: Vector2.zero(),
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  void _buildPaths() {
    // Built from the OVERLAPPING sample, not the physics one.
    final pts = _renderPoints;
    final fill = Path()..moveTo(pts.first.x, pts.first.y);
    final crust = Path()..moveTo(pts.first.x, pts.first.y);

    for (var i = 1; i < pts.length; i++) {
      fill.lineTo(pts[i].x, pts[i].y);
      crust.lineTo(pts[i].x, pts[i].y);
    }

    const bottom = GameConfig.terrainBaseY + GameConfig.terrainFillDepth;
    fill
      ..lineTo(pts.last.x, bottom)
      ..lineTo(pts.first.x, bottom)
      ..close();

    _fillPath = fill;
    _crustPath = crust;
  }

  @override
  void render(Canvas canvas) {
    if (_fillPath == null) _buildPaths();

    // Anchor the gradient to fixed WORLD heights, not to this chunk's own
    // first vertex. Deriving it per chunk gave every chunk a slightly
    // different gradient and left a visible vertical seam at each join.
    const top = GameConfig.terrainBaseY - _gradientTopMetres;
    const bottom = GameConfig.terrainBaseY + GameConfig.terrainFillDepth;

    final bodyPaint = Paint()
      ..shader = Gradient.linear(
        Offset(startX, top),
        Offset(startX, bottom),
        const [GameConfig.groundFill, GameConfig.groundFillDeep],
      );

    canvas.drawPath(_fillPath!, bodyPaint);

    // A brighter dusty crust line along the surface itself.
    canvas.drawPath(
      _crustPath!,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.22
        ..color = GameConfig.groundCrust
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }
}
