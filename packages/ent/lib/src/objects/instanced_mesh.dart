part of '../../ent.dart';

final _instancedMeshInstanceLocalMatrix = Matrix4();
final _instancedMeshInstanceWorldMatrix = Matrix4();

final List<Intersection> _instancedMeshInstanceIntersects = [];

final _instancedMeshBox3 = Box3();
final _instancedMeshIdentity = Matrix4();
final _instancedMeshMesh = Mesh();
final _instancedMeshSphere = Sphere();

/// A special version of a mesh with instanced rendering support. Use this class if you have to render a
/// large number of objects with the same geometry and material(s) but with different world transformations.
/// The usage of `InstancedMesh` will help you to reduce the number of draw calls and thus improve the
/// overall rendering performance in your application.
class InstancedMesh extends Mesh {
  /// Constructs a new instanced mesh for `count` instances. All instance matrices start as the identity.
  ///
  /// [count] (inherited from [Mesh]) is the number of instances. The value passed into the constructor is
  /// the maximum number of instances of this mesh; it can be changed at runtime to an integer in the range
  /// `[0, count]`. If you need more instances, you have to create a new `InstancedMesh`.
  InstancedMesh(super.geometry, super.material, int count)
    : instanceMatrix = InstancedBufferAttribute(Float32List(count * 16), 16) {
    this.count = count;

    for (var i = 0; i < count; i++) {
      setMatrixAt(i, _instancedMeshIdentity);
    }
  }

  /// This flag can be used for type testing.
  bool get isInstancedMesh => true;

  /// Represents the local transformation of all instances. You have to set its
  /// [BufferAttribute.needsUpdate] flag to true if you modify instanced data via [setMatrixAt].
  InstancedBufferAttribute instanceMatrix;

  /// Represents the color of all instances. You have to set its [BufferAttribute.needsUpdate] flag to true
  /// if you modify instanced data via [setColorAt].
  InstancedBufferAttribute? instanceColor;

  /// Represents the morph target weights of all instances. You have to set its [Texture.needsUpdate] flag
  /// to true if you modify instanced data via [setMorphAt].
  DataTexture? morphTexture;

  /// The bounding box of the instanced mesh. Can be computed via [computeBoundingBox].
  Box3? boundingBox;

  /// The bounding sphere of the instanced mesh. Can be computed via [computeBoundingSphere].
  Sphere? boundingSphere;

  /// Computes the bounding box of the instanced mesh, and updates [boundingBox]. The bounding box is not
  /// automatically computed by the engine; this method must be called by your app. You may need to
  /// recompute the bounding box if an instance is transformed via [setMatrixAt].
  void computeBoundingBox() {
    final geometry = this.geometry;
    final count = this.count;

    boundingBox ??= Box3();

    if (geometry.boundingBox == null) {
      geometry.computeBoundingBox();
    }

    boundingBox!.makeEmpty();

    for (var i = 0; i < count; i++) {
      getMatrixAt(i, _instancedMeshInstanceLocalMatrix);

      _instancedMeshBox3.copy(geometry.boundingBox!).applyMatrix4(_instancedMeshInstanceLocalMatrix);

      boundingBox!.union(_instancedMeshBox3);
    }
  }

  /// Computes the bounding sphere of the instanced mesh, and updates [boundingSphere]. The engine
  /// automatically computes the bounding sphere when it is needed, e.g., for ray casting or view frustum
  /// culling. You may need to recompute the bounding sphere if an instance is transformed via
  /// [setMatrixAt].
  void computeBoundingSphere() {
    final geometry = this.geometry;
    final count = this.count;

    boundingSphere ??= Sphere();

    if (geometry.boundingSphere == null) {
      geometry.computeBoundingSphere();
    }

    boundingSphere!.makeEmpty();

    for (var i = 0; i < count; i++) {
      getMatrixAt(i, _instancedMeshInstanceLocalMatrix);

      _instancedMeshSphere.copy(geometry.boundingSphere!).applyMatrix4(_instancedMeshInstanceLocalMatrix);

      boundingSphere!.union(_instancedMeshSphere);
    }
  }

  @override
  InstancedMesh copy(covariant InstancedMesh source, [bool? recursive]) {
    super.copy(source, recursive ?? true);

    instanceMatrix.copy(source.instanceMatrix);

    morphTexture = source.morphTexture?.clone();
    instanceColor = source.instanceColor?.clone();

    count = source.count;

    boundingBox = source.boundingBox?.clone();
    boundingSphere = source.boundingSphere?.clone();

    return this;
  }

  @override
  InstancedMesh clone([bool? recursive]) {
    return InstancedMesh(null, null, 0).copy(this, recursive ?? true);
  }

  /// Gets the color of the defined instance into `color`.
  Color getColorAt(int index, Color color) {
    final instanceColor = this.instanceColor;

    if (instanceColor == null) {
      return color.setRGB(1, 1, 1);
    } else {
      return color.fromArray(instanceColor.array, index * 3);
    }
  }

  /// Gets the local transformation matrix of the defined instance into `matrix`.
  Matrix4 getMatrixAt(int index, Matrix4 matrix) {
    return matrix.fromArray(instanceMatrix.array, index * 16);
  }

  /// Gets the morph target weights of the defined instance into the `morphTargetInfluences` of `object`.
  void getMorphAt(int index, Mesh object) {
    final objectInfluences = object.morphTargetInfluences!;

    final array = (morphTexture!.source.data as DataImage).data as List<double>;

    final len = objectInfluences.length + 1; // All influences + the baseInfluenceSum

    final dataIndex = index * len + 1; // Skip the baseInfluenceSum at the beginning

    for (var i = 0; i < objectInfluences.length; i++) {
      objectInfluences[i] = array[dataIndex + i];
    }
  }

  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final matrixWorld = this.matrixWorld;
    final raycastTimes = count;

    _instancedMeshMesh.geometry = geometry;
    _instancedMeshMesh.material = material;

    if (_instancedMeshMesh.material == null) {
      return null;
    }

    // test with bounding sphere first

    if (boundingSphere == null) {
      computeBoundingSphere();
    }

    _instancedMeshSphere.copy(boundingSphere!);
    _instancedMeshSphere.applyMatrix4(matrixWorld);

    if (raycaster.ray.intersectsSphere(_instancedMeshSphere) == false) {
      return null;
    }

    // now test each instance

    for (var instanceId = 0; instanceId < raycastTimes; instanceId++) {
      // calculate the world matrix for each instance

      getMatrixAt(instanceId, _instancedMeshInstanceLocalMatrix);

      _instancedMeshInstanceWorldMatrix.multiplyMatrices(matrixWorld, _instancedMeshInstanceLocalMatrix);

      // the mesh represents this single instance

      _instancedMeshMesh.matrixWorld = _instancedMeshInstanceWorldMatrix;

      _instancedMeshMesh.raycast(raycaster, _instancedMeshInstanceIntersects);

      // process the result of raycast

      for (var i = 0, l = _instancedMeshInstanceIntersects.length; i < l; i++) {
        final intersect = _instancedMeshInstanceIntersects[i];
        intersect.instanceId = instanceId;
        intersect.object = this;
        intersects.add(intersect);
      }

      _instancedMeshInstanceIntersects.length = 0;
    }

    return null;
  }

  /// Sets the given color to the defined instance. Make sure you set the `needsUpdate` flag of
  /// [instanceColor] to `true` after updating all the colors.
  InstancedMesh setColorAt(int index, Color color) {
    instanceColor ??= InstancedBufferAttribute(
      Float32List(instanceMatrix.count * 3)..fillRange(0, instanceMatrix.count * 3, 1),
      3,
    );

    color.toArray(instanceColor!.array as List<double>, index * 3);
    return this;
  }

  /// Sets the given local transformation matrix to the defined instance. Make sure you set the
  /// `needsUpdate` flag of [instanceMatrix] to `true` after updating all the matrices.
  InstancedMesh setMatrixAt(int index, Matrix4 matrix) {
    matrix.toArray(instanceMatrix.array as List<double>, index * 16);
    return this;
  }

  /// Sets the morph target weights to the defined instance, read from the `morphTargetInfluences` of
  /// `object`. Make sure you set the `needsUpdate` flag of [morphTexture] to `true` after updating all the
  /// influences.
  InstancedMesh setMorphAt(int index, Mesh object) {
    final objectInfluences = object.morphTargetInfluences!;

    final len = objectInfluences.length + 1; // morphBaseInfluence + all influences

    morphTexture ??= DataTexture(Float32List(len * count), len, count, RedFormat, FloatType);

    final array = (morphTexture!.source.data as DataImage).data as List<double>;

    var morphInfluencesSum = 0.0;

    for (var i = 0; i < objectInfluences.length; i++) {
      morphInfluencesSum += objectInfluences[i];
    }

    final morphBaseInfluence = geometry.morphTargetsRelative ? 1.0 : 1 - morphInfluencesSum;

    final dataIndex = len * index;

    array[dataIndex] = morphBaseInfluence;

    array.setAll(dataIndex + 1, objectInfluences);
    return this;
  }

  @override
  void updateMorphTargets() {}

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    instanceMatrix.dispose();

    instanceColor?.dispose();

    if (morphTexture != null) {
      morphTexture!.dispose();
      morphTexture = null;
    }
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isInstancedMesh' => isInstancedMesh,
      'instanceMatrix' => instanceMatrix,
      'instanceColor' => instanceColor,
      'morphTexture' => morphTexture,
      'boundingBox' => boundingBox,
      'boundingSphere' => boundingSphere,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'instanceMatrix':
        instanceMatrix = value as InstancedBufferAttribute;
      case 'instanceColor':
        instanceColor = value as InstancedBufferAttribute?;
      case 'morphTexture':
        morphTexture = value as DataTexture?;
      case 'boundingBox':
        boundingBox = value as Box3?;
      case 'boundingSphere':
        boundingSphere = value as Sphere?;
      default:
        super[key] = value;
    }
  }
}
