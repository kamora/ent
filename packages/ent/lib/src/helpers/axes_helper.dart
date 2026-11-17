part of '../../ent.dart';

/// An axis object to visualize the 3 axes in a simple way. The X axis is red. The Y axis is green. The Z axis
/// is blue.
///
/// ```dart
/// final axesHelper = AxesHelper(5);
/// scene.add(axesHelper);
/// ```
class AxesHelper extends LineSegments {
  /// Constructs a new axes helper; `size` is the size of the lines representing the axes.
  AxesHelper([double size = 1])
    : super(_axesHelperGeometry(size), LineBasicMaterial({'vertexColors': true, 'toneMapped': false})) {
    type = 'AxesHelper';
  }

  /// Defines the colors of the axes helper; each is a number, [Color] or string.
  AxesHelper setColors(Object? xAxisColor, Object? yAxisColor, Object? zAxisColor) {
    final color = Color();
    final attribute = geometry.attributes['color']!;
    final array = attribute.array as List<double>;

    color.set(xAxisColor);
    color.toArray(array, 0);
    color.toArray(array, 3);

    color.set(yAxisColor);
    color.toArray(array, 6);
    color.toArray(array, 9);

    color.set(zAxisColor);
    color.toArray(array, 12);
    color.toArray(array, 15);

    attribute.needsUpdate = true;

    return this;
  }

  @override
  AxesHelper clone([bool recursive = true]) {
    return AxesHelper().copy(this, recursive) as AxesHelper;
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

BufferGeometry _axesHelperGeometry(double size) {
  return BufferGeometry()
    ..setAttribute(
      'position',
      Float32BufferAttribute(<double>[
        0, 0, 0, size, 0, 0, //
        0, 0, 0, 0, size, 0, //
        0, 0, 0, 0, 0, size, //
      ], 3),
    )
    ..setAttribute(
      'color',
      Float32BufferAttribute(<double>[
        1, 0, 0, 1, 0.6, 0, //
        0, 1, 0, 0.6, 1, 0, //
        0, 0, 1, 0, 0.6, 1, //
      ], 3),
    );
}
