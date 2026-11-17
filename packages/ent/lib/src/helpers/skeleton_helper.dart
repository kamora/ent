part of '../../ent.dart';

final _skeletonHelperVector = Vector3();
final _skeletonHelperBoneMatrix = Matrix4();
final _skeletonHelperMatrixWorldInv = Matrix4();

/// A helper object to assist with visualizing a [Skeleton].
///
/// ```dart
/// final helper = SkeletonHelper(skinnedMesh);
/// scene.add(helper);
/// ```
class SkeletonHelper extends LineSegments {
  /// Constructs a new skeleton helper. `object` is usually an instance of [SkinnedMesh]; however, any 3D
  /// object can be used if it represents a hierarchy of bones (see [Bone]).
  SkeletonHelper(Object3D object) : this._(object, _skeletonHelperGetBoneList(object));

  SkeletonHelper._(this.root, this.bones)
    : super(
        _skeletonHelperGeometry(bones),
        LineBasicMaterial({
          'vertexColors': true,
          'depthTest': false,
          'depthWrite': false,
          'toneMapped': false,
          'transparent': true,
        }),
      ) {
    type = 'SkeletonHelper';

    matrix = root.matrixWorld;
    matrixAutoUpdate = false;

    // colors

    setColors(Color(0x0000ff), Color(0x00ff00));
  }

  /// This flag can be used for type testing.
  bool get isSkeletonHelper => true;

  /// The object being visualized.
  Object3D root;

  /// The list of bones that the helper visualizes.
  List<Bone> bones;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isSkeletonHelper' => isSkeletonHelper,
      'root' => root,
      'bones' => bones,
      _ => super[key],
    };
  }

  @override
  void updateMatrixWorld([bool? force]) {
    final position = geometry.getAttribute('position')!;

    _skeletonHelperMatrixWorldInv.copy(root.matrixWorld).invert();

    for (var i = 0, j = 0; i < bones.length; i++) {
      final bone = bones[i];
      final parent = bone.parent;

      if (parent is Bone) {
        _skeletonHelperBoneMatrix.multiplyMatrices(_skeletonHelperMatrixWorldInv, bone.matrixWorld);
        _skeletonHelperVector.setFromMatrixPosition(_skeletonHelperBoneMatrix);
        position.setXYZ(j, _skeletonHelperVector.x, _skeletonHelperVector.y, _skeletonHelperVector.z);

        _skeletonHelperBoneMatrix.multiplyMatrices(_skeletonHelperMatrixWorldInv, parent.matrixWorld);
        _skeletonHelperVector.setFromMatrixPosition(_skeletonHelperBoneMatrix);
        position.setXYZ(j + 1, _skeletonHelperVector.x, _skeletonHelperVector.y, _skeletonHelperVector.z);

        j += 2;
      }
    }

    geometry.getAttribute('position')!.needsUpdate = true;

    super.updateMatrixWorld(force);
  }

  /// Defines the colors of the helper: `color1` is the first line color for each bone, `color2` the second.
  SkeletonHelper setColors(Color color1, Color color2) {
    final colorAttribute = geometry.getAttribute('color')!;

    for (var i = 0; i < colorAttribute.count; i += 2) {
      colorAttribute.setXYZ(i, color1.r, color1.g, color1.b);
      colorAttribute.setXYZ(i + 1, color2.r, color2.g, color2.b);
    }

    colorAttribute.needsUpdate = true;

    return this;
  }

  /// The reference's `clone()` builds the copy without an object and throws (exception E-CLONE); this one visualizes
  /// the source's root.
  @override
  SkeletonHelper clone([bool recursive = true]) {
    return SkeletonHelper(root).copy(this, recursive) as SkeletonHelper;
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

BufferGeometry _skeletonHelperGeometry(List<Bone> bones) {
  final vertices = <double>[];
  final colors = <double>[];

  for (var i = 0; i < bones.length; i++) {
    final bone = bones[i];

    if (bone.parent is Bone) {
      vertices.addAll([0, 0, 0]);
      vertices.addAll([0, 0, 0]);
      colors.addAll([0, 0, 0]);
      colors.addAll([0, 0, 0]);
    }
  }

  return BufferGeometry()
    ..setAttribute('position', Float32BufferAttribute(vertices, 3))
    ..setAttribute('color', Float32BufferAttribute(colors, 3));
}

List<Bone> _skeletonHelperGetBoneList(Object3D object) {
  final boneList = <Bone>[];

  if (object is Bone) {
    boneList.add(object);
  }

  for (var i = 0; i < object.children.length; i++) {
    boneList.addAll(_skeletonHelperGetBoneList(object.children[i]));
  }

  return boneList;
}
