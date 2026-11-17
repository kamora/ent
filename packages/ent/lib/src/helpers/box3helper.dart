part of '../../ent.dart';

/// A helper object to visualize an instance of [Box3].
///
/// ```dart
/// final box = Box3()..setFromCenterAndSize(Vector3(1, 1, 1), Vector3(2, 1, 3));
/// final helper = Box3Helper(box, 0xffff00);
/// scene.add(helper);
/// ```
class Box3Helper extends LineSegments {
  /// Constructs a new box3 helper for `box`; `color` is a number, [Color] or string.
  Box3Helper(this.box, [Object? color = 0xffff00])
    : super(
        BufferGeometry()
          ..setIndex(
            BufferAttribute(
              Uint16List.fromList([0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]),
              1,
            ),
          )
          ..setAttribute(
            'position',
            Float32BufferAttribute(<double>[
              1,
              1,
              1,
              -1,
              1,
              1,
              -1,
              -1,
              1,
              1,
              -1,
              1,
              1,
              1,
              -1,
              -1,
              1,
              -1,
              -1,
              -1,
              -1,
              1,
              -1,
              -1,
            ], 3),
          ),
        LineBasicMaterial({'color': color, 'toneMapped': false}),
      ) {
    type = 'Box3Helper';

    geometry.computeBoundingSphere();
  }

  /// The box being visualized.
  Box3 box;

  @override
  Object? operator [](String key) {
    return key == 'box' ? box : super[key];
  }

  @override
  void updateMatrixWorld([bool? force]) {
    final box = this.box;

    if (box.isEmpty()) {
      return;
    }

    box.getCenter(position);

    box.getSize(scale);

    scale.multiplyScalar(0.5);

    super.updateMatrixWorld(force);
  }

  /// The reference's `clone()` builds the copy without a box (exception E-CLONE); this one keeps the source's box.
  @override
  Box3Helper clone([bool recursive = true]) {
    return Box3Helper(box).copy(this, recursive) as Box3Helper;
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
