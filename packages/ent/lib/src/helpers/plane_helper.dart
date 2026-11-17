part of '../../ent.dart';

/// A helper object to visualize an instance of [Plane].
///
/// ```dart
/// final plane = Plane(Vector3(1, 1, 0.2), 3);
/// final helper = PlaneHelper(plane, 1, 0xffff00);
/// scene.add(helper);
/// ```
class PlaneHelper extends Line {
  /// Constructs a new plane helper for `plane`; `size` is the side length of the plane helper, `hex` the
  /// helper's color (a number, [Color] or string).
  PlaneHelper(this.plane, [this.size = 1, Object? hex = 0xffff00])
    : super(
        BufferGeometry()
          ..setAttribute(
            'position',
            Float32BufferAttribute(<double>[
              1,
              -1,
              0,
              -1,
              1,
              0,
              -1,
              -1,
              0,
              1,
              1,
              0,
              -1,
              1,
              0,
              -1,
              -1,
              0,
              1,
              -1,
              0,
              1,
              1,
              0,
            ], 3),
          )
          ..computeBoundingSphere(),
        LineBasicMaterial({'color': hex, 'toneMapped': false}),
      ) {
    type = 'PlaneHelper';

    add(
      Mesh(
        BufferGeometry()
          ..setAttribute(
            'position',
            Float32BufferAttribute(<double>[1, 1, 0, -1, 1, 0, -1, -1, 0, 1, 1, 0, -1, -1, 0, 1, -1, 0], 3),
          )
          ..computeBoundingSphere(),
        MeshBasicMaterial({
          'color': hex,
          'opacity': 0.2,
          'transparent': true,
          'depthWrite': false,
          'toneMapped': false,
        }),
      ),
    );
  }

  /// The plane being visualized.
  Plane plane;

  /// The side length of plane helper.
  double size;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'plane' => plane,
      'size' => size,
      _ => super[key],
    };
  }

  @override
  void operator []=(String key, Object? value) {
    if (key == 'size') {
      size = (value! as num).toDouble();
    } else {
      super[key] = value;
    }
  }

  @override
  void updateMatrixWorld([bool? force]) {
    position.set(0, 0, 0);

    scale.set(0.5 * size, 0.5 * size, 1);

    lookAt(plane.normal);

    translateZ(-plane.constant);

    super.updateMatrixWorld(force);
  }

  /// The reference's `clone()` builds the copy without a plane (exception E-CLONE); this one keeps the source's plane.
  @override
  PlaneHelper clone([bool recursive = true]) {
    return PlaneHelper(plane).copy(this, recursive) as PlaneHelper;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    geometry.dispose();
    (material! as Material).dispose();

    final mesh = children[0] as Mesh;

    mesh.geometry.dispose();
    (mesh.material! as Material).dispose();
  }
}
