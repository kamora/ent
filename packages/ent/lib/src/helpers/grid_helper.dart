part of '../../ent.dart';

/// The helper is an object to define grids. Grids are two-dimensional arrays of lines.
///
/// ```dart
/// const size = 10.0;
/// const divisions = 10;
///
/// final gridHelper = GridHelper(size, divisions);
/// scene.add(gridHelper);
/// ```
class GridHelper extends LineSegments {
  /// Constructs a new grid helper: `size` is the size of the grid, `divisions` the number of divisions across
  /// the grid, `color1` the color of the center line and `color2` the color of the lines of the grid (each a
  /// number, [Color] or string).
  GridHelper([double size = 10, int divisions = 10, Object? color1 = 0x444444, Object? color2 = 0x888888])
    : super(
        _gridHelperGeometry(size, divisions, Color(color1), Color(color2)),
        LineBasicMaterial({'vertexColors': true, 'toneMapped': false}),
      ) {
    type = 'GridHelper';
  }

  @override
  GridHelper clone([bool recursive = true]) {
    return GridHelper().copy(this, recursive) as GridHelper;
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

BufferGeometry _gridHelperGeometry(double size, int divisions, Color color1, Color color2) {
  final center = divisions / 2;
  final step = size / divisions;
  final halfSize = size / 2;

  final vertices = <double>[], colors = <double>[];

  for (var i = 0, j = 0, k = -halfSize; i <= divisions; i++, k += step) {
    vertices.addAll([-halfSize, 0, k, halfSize, 0, k]);
    vertices.addAll([k, 0, -halfSize, k, 0, halfSize]);

    final color = i == center ? color1 : color2;

    color.toArray(colors, j);
    j += 3;
    color.toArray(colors, j);
    j += 3;
    color.toArray(colors, j);
    j += 3;
    color.toArray(colors, j);
    j += 3;
  }

  return BufferGeometry()
    ..setAttribute('position', Float32BufferAttribute(vertices, 3))
    ..setAttribute('color', Float32BufferAttribute(colors, 3));
}
