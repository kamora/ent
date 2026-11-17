part of '../../ent.dart';

final _skinnedMeshBaseVector = Vector4();

final _skinnedMeshSkinIndex = Vector4();
final _skinnedMeshSkinWeight = Vector4();

final _skinnedMeshVector4 = Vector4();
final _skinnedMeshMatrix4 = Matrix4();
final _skinnedMeshVertex = Vector3();

final _skinnedMeshSphere = Sphere();
final _skinnedMeshInverseMatrix = Matrix4();
final _skinnedMeshRay = Ray();

/// A mesh that has a [Skeleton] that can then be used to animate the vertices of the geometry with skinning
/// animation.
///
/// Next to a valid skeleton, the skinned mesh requires skin indices and weights as buffer attributes in its
/// geometry. These attributes define which bones affect a single vertex to a certain extend.
///
/// Typically skinned meshes are not created manually but loaders like `GLTFLoader` or `FBXLoader` import
/// respective models.
class SkinnedMesh extends Mesh {
  /// Constructs a new skinned mesh.
  SkinnedMesh([super.geometry, super.material]) {
    type = 'SkinnedMesh';
  }

  /// This flag can be used for type testing.
  bool get isSkinnedMesh => true;

  /// `AttachedBindMode` means the skinned mesh shares the same world space as the skeleton. This is not
  /// true when using `DetachedBindMode` which is useful when sharing a skeleton across multiple skinned
  /// meshes.
  String bindMode = AttachedBindMode;

  /// The base matrix that is used for the bound bone transforms.
  Matrix4 bindMatrix = Matrix4();

  /// The base matrix that is used for resetting the bound bone transforms.
  Matrix4 bindMatrixInverse = Matrix4();

  /// The bounding box of the skinned mesh. Can be computed via [computeBoundingBox].
  Box3? boundingBox;

  /// The bounding sphere of the skinned mesh. Can be computed via [computeBoundingSphere].
  Sphere? boundingSphere;

  /// The skeleton holding the bones of this skinned mesh; `null` (`undefined` in the reference) until [bind].
  Skeleton? skeleton;

  /// Computes the bounding box of the skinned mesh, and updates [boundingBox]. The bounding box is not
  /// automatically computed by the engine; this method must be called by your app. If the skinned mesh is
  /// animated, the bounding box should be recomputed per frame in order to reflect the current animation
  /// state.
  void computeBoundingBox() {
    final geometry = this.geometry;

    boundingBox ??= Box3();

    boundingBox!.makeEmpty();

    final positionAttribute = geometry.getAttribute('position')!;

    for (var i = 0; i < positionAttribute.count; i++) {
      getVertexPosition(i, _skinnedMeshVertex);
      boundingBox!.expandByPoint(_skinnedMeshVertex);
    }
  }

  /// Computes the bounding sphere of the skinned mesh, and updates [boundingSphere]. The bounding sphere is
  /// automatically computed by the engine once when it is needed, e.g., for ray casting and view frustum
  /// culling. If the skinned mesh is animated, the bounding sphere should be recomputed per frame in order to
  /// reflect the current animation state.
  void computeBoundingSphere() {
    final geometry = this.geometry;

    boundingSphere ??= Sphere();

    boundingSphere!.makeEmpty();

    final positionAttribute = geometry.getAttribute('position')!;

    for (var i = 0; i < positionAttribute.count; i++) {
      getVertexPosition(i, _skinnedMeshVertex);
      boundingSphere!.expandByPoint(_skinnedMeshVertex);
    }
  }

  @override
  SkinnedMesh copy(covariant SkinnedMesh source, [bool? recursive]) {
    super.copy(source, recursive ?? true);

    bindMode = source.bindMode;
    bindMatrix.copy(source.bindMatrix);
    bindMatrixInverse.copy(source.bindMatrixInverse);

    skeleton = source.skeleton;

    boundingBox = source.boundingBox?.clone();
    boundingSphere = source.boundingSphere?.clone();

    return this;
  }

  @override
  SkinnedMesh clone([bool? recursive]) {
    return SkinnedMesh().copy(this, recursive ?? true);
  }

  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final material = this.material;
    final matrixWorld = this.matrixWorld;

    if (material == null) {
      return null;
    }

    // test with bounding sphere in world space

    if (boundingSphere == null) {
      computeBoundingSphere();
    }

    _skinnedMeshSphere.copy(boundingSphere!);
    _skinnedMeshSphere.applyMatrix4(matrixWorld);

    if (raycaster.ray.intersectsSphere(_skinnedMeshSphere) == false) {
      return null;
    }

    // convert ray to local space of skinned mesh

    _skinnedMeshInverseMatrix.copy(matrixWorld).invert();
    _skinnedMeshRay.copy(raycaster.ray).applyMatrix4(_skinnedMeshInverseMatrix);

    // test with bounding box in local space

    if (boundingBox != null) {
      if (_skinnedMeshRay.intersectsBox(boundingBox!) == false) {
        return null;
      }
    }

    // test for intersections with geometry

    _computeIntersections(raycaster, intersects, _skinnedMeshRay);

    return null;
  }

  /// Returns the local-space position of the vertex at the given index, taking into account the current
  /// animation state of both morph targets and skinning.
  @override
  Vector3 getVertexPosition(int index, Vector3 target) {
    super.getVertexPosition(index, target);

    applyBoneTransform(index, target);

    return target;
  }

  /// Binds the given skeleton to the skinned mesh. If no `bindMatrix` is given, the world matrix of the
  /// skinned mesh is used (after updating it) and the skeleton's bone inverses are recomputed.
  void bind(Skeleton skeleton, [Matrix4? bindMatrix]) {
    this.skeleton = skeleton;

    if (bindMatrix == null) {
      updateMatrixWorld(true);

      this.skeleton!.calculateInverses();

      bindMatrix = matrixWorld;
    }

    this.bindMatrix.copy(bindMatrix);
    bindMatrixInverse.copy(bindMatrix).invert();
  }

  /// This method sets the skinned mesh in the rest pose.
  void pose() {
    skeleton!.pose();
  }

  /// Normalizes the skin weights which are defined via the `skinWeight` buffer attribute in the geometry.
  void normalizeSkinWeights() {
    final vector = Vector4();

    final skinWeight = geometry.attributes['skinWeight']!;

    for (var i = 0, l = skinWeight.count; i < l; i++) {
      vector.fromBufferAttribute(skinWeight, i);

      final scale = 1.0 / vector.manhattanLength();

      if (scale != double.infinity) {
        vector.multiplyScalar(scale);
      } else {
        vector.set(1, 0, 0, 0); // do something reasonable
      }

      skinWeight.setXYZW(i, vector.x, vector.y, vector.z, vector.w);
    }
  }

  @override
  void updateMatrixWorld([bool? force]) {
    super.updateMatrixWorld(force);

    if (bindMode == AttachedBindMode) {
      bindMatrixInverse.copy(matrixWorld).invert();
    } else if (bindMode == DetachedBindMode) {
      bindMatrixInverse.copy(bindMatrix).invert();
    } else {
      warn('SkinnedMesh: Unrecognized bindMode: $bindMode');
    }
  }

  /// Applies the bone transform associated with the given index to the given vertex position, a [Vector3]
  /// or a [Vector4] (exception E-UNION). Returns the updated vector.
  T applyBoneTransform<T extends Object>(int index, T target) {
    final skeleton = this.skeleton!;
    final geometry = this.geometry;

    _skinnedMeshSkinIndex.fromBufferAttribute(geometry.attributes['skinIndex']!, index);
    _skinnedMeshSkinWeight.fromBufferAttribute(geometry.attributes['skinWeight']!, index);

    if (target is Vector4) {
      _skinnedMeshBaseVector.copy(target);
      target.set(0, 0, 0, 0);
    } else if (target is Vector3) {
      _skinnedMeshBaseVector.set(target.x, target.y, target.z, 1);
      target.set(0, 0, 0);
    } else {
      throw ArgumentError.value(target, 'target', 'must be a Vector3 or a Vector4');
    }

    _skinnedMeshBaseVector.applyMatrix4(bindMatrix);

    for (var i = 0; i < 4; i++) {
      final weight = _skinnedMeshSkinWeight.getComponent(i);

      if (weight != 0) {
        final boneIndex = _skinnedMeshSkinIndex.getComponent(i).toInt();

        _skinnedMeshMatrix4.multiplyMatrices(skeleton.bones[boneIndex].matrixWorld, skeleton.boneInverses[boneIndex]);

        final weighted = _skinnedMeshVector4.copy(_skinnedMeshBaseVector).applyMatrix4(_skinnedMeshMatrix4);

        if (target is Vector4) {
          target.addScaledVector(weighted, weight);
        } else if (target is Vector3) {
          target.addScaledVector(weighted, weight);
        }
      }
    }

    if (target is Vector4) {
      // ensure the homogenous coordinate remains unchanged after vector operations
      target.w = _skinnedMeshBaseVector.w;

      target.applyMatrix4(bindMatrixInverse);
    } else if (target is Vector3) {
      target.applyMatrix4(bindMatrixInverse);
    }

    return target;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isSkinnedMesh' => isSkinnedMesh,
      'bindMode' => bindMode,
      'bindMatrix' => bindMatrix,
      'bindMatrixInverse' => bindMatrixInverse,
      'boundingBox' => boundingBox,
      'boundingSphere' => boundingSphere,
      'skeleton' => skeleton,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'bindMode':
        bindMode = value as String;
      case 'bindMatrix':
        bindMatrix = value as Matrix4;
      case 'bindMatrixInverse':
        bindMatrixInverse = value as Matrix4;
      case 'boundingBox':
        boundingBox = value as Box3?;
      case 'boundingSphere':
        boundingSphere = value as Sphere?;
      case 'skeleton':
        skeleton = value as Skeleton?;
      default:
        super[key] = value;
    }
  }
}
