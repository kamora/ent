part of '../../ent.dart';

final _lineSegmentsStart = Vector3();
final _lineSegmentsEnd = Vector3();

/// A series of lines drawn between pairs of vertices.
class LineSegments extends Line {
  /// Constructs a new line segments.
  LineSegments([super.geometry, super.material]) {
    type = 'LineSegments';
  }

  /// This flag can be used for type testing.
  bool get isLineSegments => true;

  @override
  Object? operator [](String key) {
    return key == 'isLineSegments' ? isLineSegments : super[key];
  }

  @override
  LineSegments clone([bool recursive = true]) {
    return LineSegments().copy(this, recursive) as LineSegments;
  }

  @override
  LineSegments computeLineDistances() {
    final geometry = this.geometry;

    // we assume non-indexed geometry

    if (geometry.index == null) {
      final positionAttribute = geometry.attributes['position']!;
      final lineDistances = <double>[];

      for (var i = 0, l = positionAttribute.count; i < l; i += 2) {
        _lineSegmentsStart.fromBufferAttribute(positionAttribute, i);
        _lineSegmentsEnd.fromBufferAttribute(positionAttribute, i + 1);

        _jsArraySet(lineDistances, i, (i == 0) ? 0 : lineDistances[i - 1]);
        _jsArraySet(lineDistances, i + 1, lineDistances[i] + _lineSegmentsStart.distanceTo(_lineSegmentsEnd));
      }

      geometry.setAttribute('lineDistance', Float32BufferAttribute(lineDistances, 1));
    } else {
      warn('LineSegments.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.');
    }

    return this;
  }
}
