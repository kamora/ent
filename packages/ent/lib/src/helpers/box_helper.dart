part of '../../ent.dart';

// Shared by all box helpers, as the reference's module-level `_box`: a helper without an object reuses the box the
// previous update left here.
final _boxHelperBox = Box3();

/// Helper object to graphically show the world-axis-aligned bounding box around an object. The actual
/// bounding box is handled with [Box3], this is just a visual helper for debugging. It can be automatically
/// resized with [update] when the object it's created from is transformed. Note that the object must have a
/// geometry for this to work, so it won't work with sprites.
///
/// ```dart
/// final sphere = SphereGeometry();
/// final object = Mesh(sphere, MeshBasicMaterial({'color': 0xff0000}));
/// final box = BoxHelper(object, 0xffff00);
/// scene.add(box);
/// ```
class BoxHelper extends LineSegments {
  /// Constructs a new box helper for `object` (optional); `color` is a number, [Color] or string.
  BoxHelper([this.object, Object? color = 0xffff00])
    : super(
        BufferGeometry()
          ..setIndex(
            BufferAttribute(
              Uint16List.fromList([0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]),
              1,
            ),
          )
          ..setAttribute('position', BufferAttribute(Float32List(8 * 3), 3)),
        LineBasicMaterial({'color': color, 'toneMapped': false}),
      ) {
    type = 'BoxHelper';

    matrixAutoUpdate = false;

    update();
  }

  /// The 3D object being visualized.
  Object3D? object;

  @override
  Object? operator [](String key) {
    return key == 'object' ? object : super[key];
  }

  /// Updates the helper's geometry to match the dimensions of the object, including any children.
  void update() {
    final object = this.object;

    if (object != null) {
      _boxHelperBox.setFromObject(object);
    }

    if (_boxHelperBox.isEmpty()) {
      return;
    }

    final min = _boxHelperBox.min;
    final max = _boxHelperBox.max;

    /*
			5____4
		1/___0/|
		| 6__|_7
		2/___3/

		0: max.x, max.y, max.z
		1: min.x, max.y, max.z
		2: min.x, min.y, max.z
		3: max.x, min.y, max.z
		4: max.x, max.y, min.z
		5: min.x, max.y, min.z
		6: min.x, min.y, min.z
		7: max.x, min.y, min.z
		*/

    final position = geometry.attributes['position']!;
    final array = position.array as List<double>;

    array[0] = max.x;
    array[1] = max.y;
    array[2] = max.z;
    array[3] = min.x;
    array[4] = max.y;
    array[5] = max.z;
    array[6] = min.x;
    array[7] = min.y;
    array[8] = max.z;
    array[9] = max.x;
    array[10] = min.y;
    array[11] = max.z;
    array[12] = max.x;
    array[13] = max.y;
    array[14] = min.z;
    array[15] = min.x;
    array[16] = max.y;
    array[17] = min.z;
    array[18] = min.x;
    array[19] = min.y;
    array[20] = min.z;
    array[21] = max.x;
    array[22] = min.y;
    array[23] = min.z;

    position.needsUpdate = true;

    geometry.computeBoundingSphere();
  }

  /// Updates the wireframe box for the passed object.
  BoxHelper setFromObject(Object3D object) {
    this.object = object;
    update();

    return this;
  }

  @override
  BoxHelper copy(covariant BoxHelper source, [bool recursive = true]) {
    super.copy(source, recursive);

    object = source.object;

    return this;
  }

  @override
  BoxHelper clone([bool recursive = true]) {
    return BoxHelper().copy(this, recursive);
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
