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

  late final List<Vector2> _points = _generator.sample(startX, endX);

  Path? _fillPath;
  Path? _crustPath;

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
    final fill = Path()..moveTo(_points.first.x, _points.first.y);
    final crust = Path()..moveTo(_points.first.x, _points.first.y);

    for (var i = 1; i < _points.length; i++) {
      fill.lineTo(_points[i].x, _points[i].y);
      crust.lineTo(_points[i].x, _points[i].y);
    }

    const bottom = GameConfig.terrainBaseY + GameConfig.terrainFillDepth;
    fill
      ..lineTo(_points.last.x, bottom)
      ..lineTo(_points.first.x, bottom)
      ..close();

    _fillPath = fill;
    _crustPath = crust;
  }

  @override
  void render(Canvas canvas) {
    if (_fillPath == null) _buildPaths();

    final top = _points.first.y - 2;
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
