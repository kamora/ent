part of '../../ent.dart';

/// A geometry class for representing a plane.
///
/// ```dart
/// final geometry = PlaneGeometry(1, 1);
/// ```
class PlaneGeometry extends BufferGeometry {
  /// Constructs a new plane geometry.
  ///
  /// [width] is the width along the X axis and [height] the height along the Y axis (default `1`);
  /// [widthSegments] and [heightSegments] are the numbers of segments along the X and Y axes (default `1`).
  PlaneGeometry([double width = 1, double height = 1, int widthSegments = 1, int heightSegments = 1]) {
    type = 'PlaneGeometry';

    parameters = {'width': width, 'height': height, 'widthSegments': widthSegments, 'heightSegments': heightSegments};

    final widthHalf = width / 2;
    final heightHalf = height / 2;

    final gridX = widthSegments;
    final gridY = heightSegments;

    final gridX1 = gridX + 1;
    final gridY1 = gridY + 1;

    final segmentWidth = width / gridX;
    final segmentHeight = height / gridY;

    //

    final indices = <int>[];
    final vertices = <double>[];
    final normals = <double>[];
    final uvs = <double>[];

    for (var iy = 0; iy < gridY1; iy++) {
      final y = iy * segmentHeight - heightHalf;

      for (var ix = 0; ix < gridX1; ix++) {
        final x = ix * segmentWidth - widthHalf;

        vertices.addAll([x, -y, 0]);

        normals.addAll([0, 0, 1]);

        uvs.add(ix / gridX);
        uvs.add(1 - (iy / gridY));
      }
    }

    for (var iy = 0; iy < gridY; iy++) {
      for (var ix = 0; ix < gridX; ix++) {
        final a = ix + gridX1 * iy;
        final b = ix + gridX1 * (iy + 1);
        final c = (ix + 1) + gridX1 * (iy + 1);
        final d = (ix + 1) + gridX1 * iy;

        indices.addAll([a, b, d]);
        indices.addAll([b, c, d]);
      }
    }

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(vertices, 3));
    setAttribute('normal', Float32BufferAttribute(normals, 3));
    setAttribute('uv', Float32BufferAttribute(uvs, 2));
  }

  @override
  PlaneGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new plane geometry with copied values from this instance.
  @override
  PlaneGeometry clone() {
    return PlaneGeometry().copy(this);
  }

  /// Factory method for creating an instance of this class from the given JSON object.
  static PlaneGeometry fromJSON(Map<String, Object?> data) {
    return PlaneGeometry(
      _geometryDouble(data, 'width', 1),
      _geometryDouble(data, 'height', 1),
      _geometryInt(data, 'widthSegments', 1),
      _geometryInt(data, 'heightSegments', 1),
    );
  }
}
