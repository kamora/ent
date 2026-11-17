part of '../../ent.dart';

// Only the functions the engine uses so far are here (toTrianglesDrawMode, for GLTFLoader); the rest are not ported.

/// Utility functions for [BufferGeometry].
abstract final class BufferGeometryUtils {
  /// Returns a new indexed geometry based on `TrianglesDrawMode` draw mode. This mode corresponds to the
  /// `gl.TRIANGLES` primitive in WebGL.
  ///
  /// [drawMode] is the draw mode of the given geometry, `TriangleFanDrawMode` or `TriangleStripDrawMode`. The
  /// geometry is changed in place and returned.
  static BufferGeometry toTrianglesDrawMode(BufferGeometry geometry, int drawMode) {
    if (drawMode == TrianglesDrawMode) {
      warn('BufferGeometryUtils.toTrianglesDrawMode(): Geometry already defined as triangles.');
      return geometry;
    }

    if (drawMode == TriangleFanDrawMode || drawMode == TriangleStripDrawMode) {
      var index = geometry.getIndex();

      // generate index if not present

      if (index == null) {
        final indices = <int>[];

        final position = geometry.getAttribute('position');

        if (position != null) {
          for (var i = 0; i < position.count; i++) {
            indices.add(i);
          }

          geometry.setIndex(indices);
          index = geometry.getIndex()!;
        } else {
          error('BufferGeometryUtils.toTrianglesDrawMode(): Undefined position attribute. Processing not possible.');
          return geometry;
        }
      }

      //

      final numberOfTriangles = index.count - 2;
      final newIndices = <int>[];

      if (drawMode == TriangleFanDrawMode) {
        // gl.TRIANGLE_FAN

        for (var i = 1; i <= numberOfTriangles; i++) {
          newIndices.add(index.getX(0).toInt());
          newIndices.add(index.getX(i).toInt());
          newIndices.add(index.getX(i + 1).toInt());
        }
      } else {
        // gl.TRIANGLE_STRIP

        for (var i = 0; i < numberOfTriangles; i++) {
          if (i % 2 == 0) {
            newIndices.add(index.getX(i).toInt());
            newIndices.add(index.getX(i + 1).toInt());
            newIndices.add(index.getX(i + 2).toInt());
          } else {
            newIndices.add(index.getX(i + 2).toInt());
            newIndices.add(index.getX(i + 1).toInt());
            newIndices.add(index.getX(i).toInt());
          }
        }
      }

      if ((newIndices.length / 3) != numberOfTriangles) {
        error('BufferGeometryUtils.toTrianglesDrawMode(): Unable to generate correct amount of triangles.');
      }

      // updated indices

      geometry.setIndex(newIndices);
      geometry.clearGroups();

      return geometry;
    } else {
      error('BufferGeometryUtils.toTrianglesDrawMode(): Unknown draw mode:', [drawMode]);
      return geometry;
    }
  }
}
