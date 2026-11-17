part of '../../ent.dart';

/// This helper is an object to define polar grids. Grids are two-dimensional arrays of lines.
///
/// ```dart
/// final helper = PolarGridHelper(10, 16, 8, 64);
/// scene.add(helper);
/// ```
class PolarGridHelper extends LineSegments {
  /// Constructs a new polar grid helper: `radius` is the radius of the polar grid, `sectors` the number of
  /// sectors the grid will be divided into, `rings` the number of rings, `divisions` the number of line
  /// segments used for each circle, `color1` and `color2` the alternating colors of the grid elements (each a
  /// number, [Color] or string).
  PolarGridHelper([
    double radius = 10,
    int sectors = 16,
    int rings = 8,
    int divisions = 64,
    Object? color1 = 0x444444,
    Object? color2 = 0x888888,
  ]) : super(
         _polarGridHelperGeometry(radius, sectors, rings, divisions, Color(color1), Color(color2)),
         LineBasicMaterial({'vertexColors': true, 'toneMapped': false}),
       ) {
    type = 'PolarGridHelper';
  }

  @override
  PolarGridHelper clone([bool recursive = true]) {
    return PolarGridHelper().copy(this, recursive) as PolarGridHelper;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    geometry.dispose();
    (material! as Material).dispose();
  }
}

BufferGeometry _polarGridHelperGeometry(
  double radius,
  int sectors,
  int rings,
  int divisions,
  Color color1,
  Color color2,
) {
  final vertices = <double>[];
  final colors = <double>[];

  // create the sectors

  if (sectors > 1) {
    for (var i = 0; i < sectors; i++) {
      final v = (i / sectors) * (math.pi * 2);

      final x = math.sin(v) * radius;
      final z = math.cos(v) * radius;

      vertices.addAll([0, 0, 0]);
      vertices.addAll([x, 0, z]);

      final color = (i & 1) != 0 ? color1 : color2;

      colors.addAll([color.r, color.g, color.b]);
      colors.addAll([color.r, color.g, color.b]);
    }
  }

  // create the rings

  for (var i = 0; i < rings; i++) {
    final color = (i & 1) != 0 ? color1 : color2;

    final r = radius - (radius / rings * i);

    for (var j = 0; j < divisions; j++) {
      // first vertex

      var v = (j / divisions) * (math.pi * 2);

      var x = math.sin(v) * r;
      var z = math.cos(v) * r;

      vertices.addAll([x, 0, z]);
      colors.addAll([color.r, color.g, color.b]);

      // second vertex

      v = ((j + 1) / divisions) * (math.pi * 2);

      x = math.sin(v) * r;
      z = math.cos(v) * r;

      vertices.addAll([x, 0, z]);
      colors.addAll([color.r, color.g, color.b]);
    }
  }

  return BufferGeometry()
    ..setAttribute('position', Float32BufferAttribute(vertices, 3))
    ..setAttribute('color', Float32BufferAttribute(colors, 3));
}
