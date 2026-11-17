part of '../../ent.dart';

/// The text of `${ value }` as far as equality goes: JavaScript prints -0 as "0", so both zeros share one key;
/// every other value keeps a key of its own.
String _wireframeKey(double value) {
  return value == 0 ? '0' : value.toString();
}

bool _wireframeIsUniqueEdge(Vector3 start, Vector3 end, Set<String> edges) {
  final from = '${_wireframeKey(start.x)},${_wireframeKey(start.y)},${_wireframeKey(start.z)}';
  final to = '${_wireframeKey(end.x)},${_wireframeKey(end.y)},${_wireframeKey(end.z)}';
  final hash1 = '$from-$to';
  final hash2 = '$to-$from'; // coincident edge

  if (edges.contains(hash1) == true || edges.contains(hash2) == true) {
    return false;
  } else {
    edges.add(hash1);
    edges.add(hash2);
    return true;
  }
}

/// Can be used as a helper object to visualize a geometry as a wireframe.
///
/// Note: It is not yet possible to serialize/deserialize instances of this class.
///
/// ```dart
/// final geometry = SphereGeometry();
/// final wireframe = WireframeGeometry(geometry);
/// ```
class WireframeGeometry extends BufferGeometry {
  /// Constructs a new wireframe geometry of [geometry] (default `null`).
  WireframeGeometry([BufferGeometry? geometry]) {
    type = 'WireframeGeometry';

    parameters = {'geometry': geometry};

    if (geometry != null) {
      // buffer

      final vertices = <double>[];
      final edges = <String>{};

      // helper variables

      final start = Vector3();
      final end = Vector3();

      final indices = geometry.index;

      if (indices != null) {
        // indexed BufferGeometry

        final position = geometry.attributes['position']!;
        var groups = geometry.groups;

        if (groups.isEmpty) {
          groups = [GeometryGroup(start: 0, count: indices.count, materialIndex: 0)];
        }

        // create a data structure that contains all edges without duplicates

        for (var o = 0, ol = groups.length; o < ol; ++o) {
          final group = groups[o];

          final groupStart = group.start;
          final groupCount = group.count;

          for (var i = groupStart, l = (groupStart + groupCount); i < l; i += 3) {
            for (var j = 0; j < 3; j++) {
              final index1 = indices.getX(i + j).toInt();
              final index2 = indices.getX(i + (j + 1) % 3).toInt();

              start.fromBufferAttribute(position, index1);
              end.fromBufferAttribute(position, index2);

              if (_wireframeIsUniqueEdge(start, end, edges) == true) {
                vertices.addAll([start.x, start.y, start.z]);
                vertices.addAll([end.x, end.y, end.z]);
              }
            }
          }
        }
      } else {
        // non-indexed BufferGeometry

        final position = geometry.attributes['position']!;

        for (var i = 0, l = (position.count / 3); i < l; i++) {
          for (var j = 0; j < 3; j++) {
            // three edges per triangle, an edge is represented as (index1, index2)
            // e.g. the first triangle has the following edges: (0,1),(1,2),(2,0)

            final index1 = 3 * i + j;
            final index2 = 3 * i + ((j + 1) % 3);

            start.fromBufferAttribute(position, index1);
            end.fromBufferAttribute(position, index2);

            if (_wireframeIsUniqueEdge(start, end, edges) == true) {
              vertices.addAll([start.x, start.y, start.z]);
              vertices.addAll([end.x, end.y, end.z]);
            }
          }
        }
      }

      // build geometry

      setAttribute('position', Float32BufferAttribute(vertices, 3));
    }
  }

  @override
  WireframeGeometry copy(BufferGeometry source) {
    super.copy(source);

    parameters = {...?source.parameters};

    return this;
  }

  /// Returns a new wireframe geometry with copied values from this instance.
  @override
  WireframeGeometry clone() {
    return WireframeGeometry().copy(this);
  }
}
