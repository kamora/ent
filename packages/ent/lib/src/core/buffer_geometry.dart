part of '../../ent.dart';

//
// Members carry the types the reference's JSDoc declares: `index` and `indirect` are BufferAttributes, and
// `attributes`/`morphAttributes` hold a BufferAttribute or an InterleavedBufferAttribute, which share the
// BufferAttributeLike interface (exception E-DUCK). A GLBufferAttribute is not a BufferAttributeLike, so it cannot be
// stored in `attributes` (exception E-GLATTR); the GLBufferAttribute branches of the bounding computations are kept for
// a subclass implementing both.

int _bufferGeometryId = 0;

final _bufferGeometryM1 = Matrix4();
final _bufferGeometryObj = Object3D();
final _bufferGeometryOffset = Vector3();
final _bufferGeometryBox = Box3();
final _bufferGeometryBoxMorphTargets = Box3();
final _bufferGeometryVector = Vector3();

/// A group of a [BufferGeometry], rendered in its own draw call with the material at [materialIndex].
///
/// The reference stores plain objects `{ start, count, materialIndex }` in `geometry.groups` (exception E-OBJECT).
class GeometryGroup {
  /// Constructs a new group of [count] vertices or indices from [start], drawn with the material at [materialIndex].
  GeometryGroup({required this.start, required this.count, this.materialIndex = 0});

  /// The first vertex for non-indexed geometry, otherwise the first triangle index.
  int start;

  /// How many vertices (or indices) are part of this group.
  int count;

  /// The material array index to use; the reference accepts any value here.
  Object? materialIndex;
}

/// The part of a [BufferGeometry] to render: the reference's `{ start, count }`, with `count` defaulting to infinity
/// (exception E-OBJECT).
class DrawRange {
  /// Constructs a new range from [start] (default `0`) of [count] (default: all).
  DrawRange({this.start = 0, this.count = double.infinity});

  /// The first vertex for non-indexed geometry, otherwise the first index.
  double start;

  /// How many vertices or indices to render.
  double count;
}

/// The typed-array class name the reference writes into JSON (`index.array.constructor.name`).
String _bufferGeometryArrayType(Object? array) {
  return switch (array) {
    Float32List() => 'Float32Array',
    Float64List() => 'Float64Array',
    Int8List() => 'Int8Array',
    Uint8ClampedList() => 'Uint8ClampedArray',
    Uint8List() => 'Uint8Array',
    Int16List() => 'Int16Array',
    Uint16List() => 'Uint16Array',
    Int32List() => 'Int32Array',
    Uint32List() => 'Uint32Array',
    _ => 'Array',
  };
}

/// `new array.constructor( length )`: an empty list of the same kind as [array].
List<num> _bufferGeometryNewArray(Object? array, int length) {
  return switch (array) {
    Float32List() => Float32List(length),
    Float64List() => Float64List(length),
    Int8List() => Int8List(length),
    Uint8ClampedList() => Uint8ClampedList(length),
    Uint8List() => Uint8List(length),
    Int16List() => Int16List(length),
    Uint16List() => Uint16List(length),
    Int32List() => Int32List(length),
    Uint32List() => Uint32List(length),
    _ => List<double>.filled(length, 0.0),
  };
}

/// A representation of mesh, line, or point geometry. Includes vertex positions, face indices, normals,
/// colors, UVs, and custom attributes within buffers, reducing the cost of passing all this data to the GPU.
///
/// ```dart
/// final geometry = BufferGeometry();
///
/// // create a simple square shape. We duplicate the top left and bottom right
/// // vertices because each vertex needs to appear once per triangle.
/// final vertices = Float32List.fromList([
/// 	-1.0, -1.0, 1.0, // v0
/// 	1.0, -1.0, 1.0, // v1
/// 	1.0, 1.0, 1.0, // v2
/// 	1.0, 1.0, 1.0, // v3
/// 	-1.0, 1.0, 1.0, // v4
/// 	-1.0, -1.0, 1.0, // v5
/// ]);
///
/// // itemSize = 3 because there are 3 values (components) per vertex
/// geometry.setAttribute('position', BufferAttribute(vertices, 3));
/// ```
class BufferGeometry extends EventDispatcher {
  /// Constructs a new geometry.
  BufferGeometry() : id = _bufferGeometryId++;

  /// This flag can be used for type testing.
  bool get isBufferGeometry => true;

  /// The ID of the geometry.
  final int id;

  /// The UUID of the geometry.
  String uuid = MathUtils.generateUUID();

  /// The name of the geometry.
  String name = '';

  /// The type of the geometry.
  String type = 'BufferGeometry';

  /// Allows for vertices to be re-used across multiple triangles; this is called using "indexed
  /// triangles". Each triangle is associated with the indices of three vertices. This attribute therefore
  /// stores the index of each vertex for each triangular face. If this attribute is not set, the renderer
  /// assumes that each three contiguous positions represent a single triangle.
  BufferAttribute? index;

  /// A (storage) buffer attribute which was generated with a compute shader and now defines indirect draw
  /// calls. Can only be used with `WebGPURenderer` and a WebGPU backend.
  BufferAttribute? indirect;

  /// The offset, in bytes, into the indirect drawing buffer where the value data begins (a number, or a
  /// list of numbers for multiple indirect draw calls). Can only be used with `WebGPURenderer` and a
  /// WebGPU backend.
  Object indirectOffset = 0;

  /// This dictionary has as id the name of the attribute to be set and as value the buffer attribute to set
  /// it to (a `BufferAttribute` or an `InterleavedBufferAttribute`). Rather than accessing this property
  /// directly, use [setAttribute] and [getAttribute] to access attributes of this geometry.
  Map<String, BufferAttributeLike> attributes = {};

  /// This dictionary holds the morph targets of the geometry.
  ///
  /// Note: Once the geometry has been rendered, the morph attribute data cannot be changed. You will have
  /// to call [dispose], and create a new geometry instance.
  Map<String, List<BufferAttributeLike>> morphAttributes = {};

  /// Used to control the morph target behavior; when set to `true`, the morph target data is treated as
  /// relative offsets, rather than as absolute positions/normals.
  bool morphTargetsRelative = false;

  /// Split the geometry into groups, each of which will be rendered in a separate draw call. This allows an
  /// array of materials to be used with the geometry. Use [addGroup] and [clearGroups] to edit groups,
  /// rather than modifying this array directly.
  ///
  /// Every vertex and index must belong to exactly one group — groups must not share vertices or indices,
  /// and must not leave vertices or indices unused.
  List<GeometryGroup> groups = [];

  /// Bounding box for the geometry which can be calculated with [computeBoundingBox].
  Box3? boundingBox;

  /// Bounding sphere for the geometry which can be calculated with [computeBoundingSphere].
  Sphere? boundingSphere;

  /// Determines the part of the geometry to render. This should not be set directly, instead use
  /// [setDrawRange].
  DrawRange drawRange = DrawRange();

  /// An object that can be used to store custom data about the geometry. It should not hold references to
  /// functions as these will not be cloned.
  Map<String, Object?> userData = {};

  /// The construction parameters of geometry generators. The reference declares it only on the subclasses that set it
  /// and tests it against `undefined`; here it is `null` on plain geometries.
  Map<String, Object?>? parameters;

  /// `true` when the geometry has been transformed since construction (e.g. via [applyMatrix4]). Only
  /// relevant for geometry generators (subclasses that populate `parameters`): when set, [toJSON] omits
  /// `parameters` since they no longer describe the geometry.
  bool _transformed = false;

  /// Returns the index of this geometry, or `null` if no index is defined.
  BufferAttribute? getIndex() {
    return index;
  }

  /// Sets the given index to this geometry: a list of integers (stored as a `Uint16BufferAttribute`, or a
  /// `Uint32BufferAttribute` when a value needs 32 bits) or a buffer attribute.
  BufferGeometry setIndex(Object? index) {
    // Array.isArray() is false for typed arrays: those are stored as they are, as the reference does.
    if (index is List && index is! TypedData) {
      final array = index.cast<num>();
      this.index = arrayNeedsUint32(array) ? Uint32BufferAttribute(array, 1) : Uint16BufferAttribute(array, 1);
    } else {
      this.index = index as BufferAttribute?;
    }

    return this;
  }

  /// Sets the given indirect attribute to this geometry.
  BufferGeometry setIndirect(BufferAttribute? indirect, [Object indirectOffset = 0]) {
    this.indirect = indirect;
    this.indirectOffset = indirectOffset;

    return this;
  }

  /// Returns the indirect attribute of this geometry, or `null` if none is defined.
  BufferAttribute? getIndirect() {
    return indirect;
  }

  /// Returns the buffer attribute for the given name, or `null` (`undefined` in the reference) if no attribute has been
  /// found.
  BufferAttributeLike? getAttribute(String name) {
    return attributes[name];
  }

  /// Sets the given attribute for the given name.
  BufferGeometry setAttribute(String name, BufferAttributeLike attribute) {
    attributes[name] = attribute;

    return this;
  }

  /// Deletes the attribute for the given name.
  BufferGeometry deleteAttribute(String name) {
    attributes.remove(name);

    return this;
  }

  /// Returns `true` if this geometry has an attribute for the given name.
  bool hasAttribute(String name) {
    return attributes[name] != null;
  }

  /// Adds a group to this geometry. `start` is the first vertex for non-indexed geometry, otherwise the
  /// first triangle index; `count` specifies how many vertices (or indices) are part of this group.
  void addGroup(int start, int count, [Object? materialIndex = 0]) {
    groups.add(GeometryGroup(start: start, count: count, materialIndex: materialIndex));
  }

  /// Clears all groups.
  void clearGroups() {
    groups = [];
  }

  /// Sets the draw range for this geometry. For non-indexed geometry, `count` is the number of vertices to
  /// render; for indexed geometry, the number of indices.
  void setDrawRange(double start, double count) {
    drawRange.start = start;
    drawRange.count = count;
  }

  /// Applies the given 4x4 transformation matrix to the geometry.
  BufferGeometry applyMatrix4(Matrix4 matrix) {
    final position = attributes['position'];

    if (position != null) {
      position.applyMatrix4(matrix);

      position.needsUpdate = true;
    }

    final normal = attributes['normal'];

    if (normal != null) {
      final normalMatrix = Matrix3().getNormalMatrix(matrix);

      normal.applyNormalMatrix(normalMatrix);

      normal.needsUpdate = true;
    }

    final tangent = attributes['tangent'];

    if (tangent != null) {
      tangent.transformDirection(matrix);

      tangent.needsUpdate = true;
    }

    if (boundingBox != null) {
      computeBoundingBox();
    }

    if (boundingSphere != null) {
      computeBoundingSphere();
    }

    _transformed = true;

    return this;
  }

  /// Applies the rotation represented by the Quaternion to the geometry.
  BufferGeometry applyQuaternion(Quaternion q) {
    _bufferGeometryM1.makeRotationFromQuaternion(q);

    applyMatrix4(_bufferGeometryM1);

    return this;
  }

  /// Rotates the geometry about the X axis. This is typically done as a one time operation, and not during
  /// a loop. Use `Object3D.rotation` for typical real-time mesh rotation.
  BufferGeometry rotateX(double angle) {
    // rotate geometry around world x-axis

    _bufferGeometryM1.makeRotationX(angle);

    applyMatrix4(_bufferGeometryM1);

    return this;
  }

  /// Rotates the geometry about the Y axis. This is typically done as a one time operation, and not during
  /// a loop. Use `Object3D.rotation` for typical real-time mesh rotation.
  BufferGeometry rotateY(double angle) {
    // rotate geometry around world y-axis

    _bufferGeometryM1.makeRotationY(angle);

    applyMatrix4(_bufferGeometryM1);

    return this;
  }

  /// Rotates the geometry about the Z axis. This is typically done as a one time operation, and not during
  /// a loop. Use `Object3D.rotation` for typical real-time mesh rotation.
  BufferGeometry rotateZ(double angle) {
    // rotate geometry around world z-axis

    _bufferGeometryM1.makeRotationZ(angle);

    applyMatrix4(_bufferGeometryM1);

    return this;
  }

  /// Translates the geometry. This is typically done as a one time operation, and not during a loop. Use
  /// `Object3D.position` for typical real-time mesh rotation.
  BufferGeometry translate(double x, double y, double z) {
    // translate geometry

    _bufferGeometryM1.makeTranslation(x, y, z);

    applyMatrix4(_bufferGeometryM1);

    return this;
  }

  /// Scales the geometry. This is typically done as a one time operation, and not during a loop. Use
  /// `Object3D.scale` for typical real-time mesh rotation.
  BufferGeometry scale(double x, double y, double z) {
    // scale geometry

    _bufferGeometryM1.makeScale(x, y, z);

    applyMatrix4(_bufferGeometryM1);

    return this;
  }

  /// Rotates the geometry to face a point in 3D space. This is typically done as a one time operation, and
  /// not during a loop. Use `Object3D.lookAt` for typical real-time mesh rotation.
  BufferGeometry lookAt(Vector3 vector) {
    _bufferGeometryObj.lookAt(vector);

    _bufferGeometryObj.updateMatrix();

    applyMatrix4(_bufferGeometryObj.matrix);

    return this;
  }

  /// Center the geometry based on its bounding box.
  BufferGeometry center() {
    computeBoundingBox();

    boundingBox!.getCenter(_bufferGeometryOffset).negate();

    translate(_bufferGeometryOffset.x, _bufferGeometryOffset.y, _bufferGeometryOffset.z);

    return this;
  }

  /// Defines a geometry by creating a `position` attribute based on the given array of points. The array
  /// can hold 2D or 3D vectors. When using two-dimensional data, the `z` coordinate for all vertices is set
  /// to `0`.
  ///
  /// If the method is used with an existing `position` attribute, the vertex data are overwritten with the
  /// data from the array. The length of the array must match the vertex count.
  BufferGeometry setFromPoints(List<Object> points) {
    final positionAttribute = getAttribute('position');

    if (positionAttribute == null) {
      final position = <double>[];

      for (var i = 0, l = points.length; i < l; i++) {
        final (x, y, z) = _bufferGeometryPoint(points[i]);
        position.addAll([x, y, z]);
      }

      setAttribute('position', Float32BufferAttribute(position, 3));
    } else {
      // make sure data do not exceed buffer size
      final l = math.min(points.length, positionAttribute.count);

      for (var i = 0; i < l; i++) {
        final (x, y, z) = _bufferGeometryPoint(points[i]);
        positionAttribute.setXYZ(i, x, y, z);
      }

      if (points.length > (positionAttribute.count)) {
        warn('BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry.');
      }

      positionAttribute.needsUpdate = true;
    }

    return this;
  }

  /// Computes the bounding box of the geometry, and updates the [boundingBox] member. The bounding box is
  /// not computed by the engine; it must be computed by your app. You may need to recompute the bounding
  /// box if the geometry vertices are modified.
  void computeBoundingBox() {
    final box = boundingBox ??= Box3();

    final position = attributes['position'];
    final morphAttributesPosition = morphAttributes['position'];

    if (position is GLBufferAttribute) {
      error('BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.', [this]);

      box.set(
        Vector3(double.negativeInfinity, double.negativeInfinity, double.negativeInfinity),
        Vector3(double.infinity, double.infinity, double.infinity),
      );

      return;
    }

    if (position != null) {
      box.setFromBufferAttribute(position);

      // process morph attributes if present

      if (morphAttributesPosition != null) {
        for (var i = 0, il = morphAttributesPosition.length; i < il; i++) {
          final morphAttribute = morphAttributesPosition[i];
          _bufferGeometryBox.setFromBufferAttribute(morphAttribute);

          if (morphTargetsRelative) {
            _bufferGeometryVector.addVectors(box.min, _bufferGeometryBox.min);
            box.expandByPoint(_bufferGeometryVector);

            _bufferGeometryVector.addVectors(box.max, _bufferGeometryBox.max);
            box.expandByPoint(_bufferGeometryVector);
          } else {
            box.expandByPoint(_bufferGeometryBox.min);
            box.expandByPoint(_bufferGeometryBox.max);
          }
        }
      }
    } else {
      box.makeEmpty();
    }

    if (box.min.x.isNaN || box.min.y.isNaN || box.min.z.isNaN) {
      error(
        'BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',
        [this],
      );
    }
  }

  /// Computes the bounding sphere of the geometry, and updates the [boundingSphere] member. The engine
  /// automatically computes the bounding sphere when it is needed, e.g., for ray casting or view frustum
  /// culling. You may need to recompute the bounding sphere if the geometry vertices are modified.
  void computeBoundingSphere() {
    final sphere = boundingSphere ??= Sphere();

    final position = attributes['position'];
    final morphAttributesPosition = morphAttributes['position'];

    if (position is GLBufferAttribute) {
      error('BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.', [this]);

      sphere.set(Vector3(), double.infinity);

      return;
    }

    if (position != null) {
      final attribute = position;

      // first, find the center of the bounding sphere

      final center = sphere.center;

      _bufferGeometryBox.setFromBufferAttribute(attribute);

      // process morph attributes if present

      if (morphAttributesPosition != null) {
        for (var i = 0, il = morphAttributesPosition.length; i < il; i++) {
          final morphAttribute = morphAttributesPosition[i];
          _bufferGeometryBoxMorphTargets.setFromBufferAttribute(morphAttribute);

          if (morphTargetsRelative) {
            _bufferGeometryVector.addVectors(_bufferGeometryBox.min, _bufferGeometryBoxMorphTargets.min);
            _bufferGeometryBox.expandByPoint(_bufferGeometryVector);

            _bufferGeometryVector.addVectors(_bufferGeometryBox.max, _bufferGeometryBoxMorphTargets.max);
            _bufferGeometryBox.expandByPoint(_bufferGeometryVector);
          } else {
            _bufferGeometryBox.expandByPoint(_bufferGeometryBoxMorphTargets.min);
            _bufferGeometryBox.expandByPoint(_bufferGeometryBoxMorphTargets.max);
          }
        }
      }

      _bufferGeometryBox.getCenter(center);

      // second, try to find a boundingSphere with a radius smaller than the
      // boundingSphere of the boundingBox: sqrt(3) smaller in the best case

      var maxRadiusSq = 0.0;

      for (var i = 0, il = attribute.count; i < il; i++) {
        _bufferGeometryVector.fromBufferAttribute(attribute, i);

        maxRadiusSq = math.max(maxRadiusSq, center.distanceToSquared(_bufferGeometryVector));
      }

      // process morph attributes if present

      if (morphAttributesPosition != null) {
        for (var i = 0, il = morphAttributesPosition.length; i < il; i++) {
          final morphAttribute = morphAttributesPosition[i];
          final relative = morphTargetsRelative;

          for (var j = 0, jl = morphAttribute.count; j < jl; j++) {
            _bufferGeometryVector.fromBufferAttribute(morphAttribute, j);

            if (relative) {
              _bufferGeometryOffset.fromBufferAttribute(attribute, j);
              _bufferGeometryVector.add(_bufferGeometryOffset);
            }

            maxRadiusSq = math.max(maxRadiusSq, center.distanceToSquared(_bufferGeometryVector));
          }
        }
      }

      sphere.radius = math.sqrt(maxRadiusSq);

      if (sphere.radius.isNaN) {
        error(
          'BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',
          [this],
        );
      }
    }
  }

  /// Calculates and adds a tangent attribute to this geometry.
  ///
  /// The computation is only supported for indexed geometries and if position, normal, and uv attributes are
  /// defined. When using a tangent space normal map, prefer the MikkTSpace algorithm provided by
  /// `BufferGeometryUtils.computeMikkTSpaceTangents` instead.
  void computeTangents() {
    final index = this.index;

    // based on http://www.terathon.com/code/tangent.html
    // (per vertex tangents)

    final positionAttribute = attributes['position'];
    final normalAttribute = attributes['normal'];
    final uvAttribute = attributes['uv'];

    if (index == null || positionAttribute == null || normalAttribute == null || uvAttribute == null) {
      error('BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)');
      return;
    }

    final count = positionAttribute.count;

    var tangentAttribute = getAttribute('tangent');

    if (tangentAttribute == null || tangentAttribute.count != count) {
      tangentAttribute = BufferAttribute(Float32List(4 * count), 4);
      setAttribute('tangent', tangentAttribute);
    }

    final tan1 = <Vector3>[], tan2 = <Vector3>[];
    final used = Uint8List(count);

    for (var i = 0; i < count; i++) {
      tan1.add(Vector3());
      tan2.add(Vector3());
    }

    final vA = Vector3(), vB = Vector3(), vC = Vector3();
    final uvA = Vector2(), uvB = Vector2(), uvC = Vector2();
    final sdir = Vector3(), tdir = Vector3();

    void handleTriangle(int a, int b, int c) {
      used[a] = used[b] = used[c] = 1;

      vA.fromBufferAttribute(positionAttribute, a);
      vB.fromBufferAttribute(positionAttribute, b);
      vC.fromBufferAttribute(positionAttribute, c);

      uvA.fromBufferAttribute(uvAttribute, a);
      uvB.fromBufferAttribute(uvAttribute, b);
      uvC.fromBufferAttribute(uvAttribute, c);

      vB.sub(vA);
      vC.sub(vA);

      uvB.sub(uvA);
      uvC.sub(uvA);

      final r = 1.0 / (uvB.x * uvC.y - uvC.x * uvB.y);

      // silently ignore degenerate uv triangles having coincident or colinear vertices

      if (!r.isFinite) {
        return;
      }

      sdir.copy(vB).multiplyScalar(uvC.y).addScaledVector(vC, -uvB.y).multiplyScalar(r);
      tdir.copy(vC).multiplyScalar(uvB.x).addScaledVector(vB, -uvC.x).multiplyScalar(r);

      tan1[a].add(sdir);
      tan1[b].add(sdir);
      tan1[c].add(sdir);

      tan2[a].add(tdir);
      tan2[b].add(tdir);
      tan2[c].add(tdir);
    }

    var groups = this.groups;

    if (groups.isEmpty) {
      groups = [GeometryGroup(start: 0, count: index.count)];
    }

    for (var i = 0, il = groups.length; i < il; ++i) {
      final group = groups[i];

      final start = group.start;
      final count = group.count;

      for (var j = start, jl = start + count; j < jl; j += 3) {
        handleTriangle(index.getX(j + 0).toInt(), index.getX(j + 1).toInt(), index.getX(j + 2).toInt());
      }
    }

    final tmp = Vector3(), tmp2 = Vector3();
    final n = Vector3(), n2 = Vector3();

    void handleVertex(int v) {
      n.fromBufferAttribute(normalAttribute, v);
      n2.copy(n);

      final t = tan1[v];

      // Gram-Schmidt orthogonalize

      tmp.copy(t);
      tmp.sub(n.multiplyScalar(n.dot(t))).normalize();

      // Calculate handedness

      tmp2.crossVectors(n2, t);
      final test = tmp2.dot(tan2[v]);
      final w = (test < 0.0) ? -1.0 : 1.0;

      tangentAttribute!.setXYZW(v, tmp.x, tmp.y, tmp.z, w);
    }

    for (var i = 0, il = count; i < il; ++i) {
      if (used[i] != 0) {
        handleVertex(i);
      }
    }

    _transformed = true;
  }

  /// Computes vertex normals for the given vertex data. For indexed geometries, the method sets each vertex
  /// normal to be the average of the face normals of the faces that share that vertex. For non-indexed
  /// geometries, vertices are not shared, and the method sets each vertex normal to be the same as the face
  /// normal.
  void computeVertexNormals() {
    final index = this.index;
    final positionAttribute = getAttribute('position');

    if (positionAttribute != null) {
      var normalAttribute = getAttribute('normal');

      if (normalAttribute == null || normalAttribute.count != positionAttribute.count) {
        normalAttribute = BufferAttribute(Float32List(positionAttribute.count * 3), 3);
        setAttribute('normal', normalAttribute);
      } else {
        // reset existing normals to zero

        for (var i = 0, il = normalAttribute.count; i < il; i++) {
          normalAttribute.setXYZ(i, 0.0, 0.0, 0.0);
        }
      }

      final pA = Vector3(), pB = Vector3(), pC = Vector3();
      final nA = Vector3(), nB = Vector3(), nC = Vector3();
      final cb = Vector3(), ab = Vector3();

      // indexed elements

      if (index != null) {
        for (var i = 0, il = index.count; i < il; i += 3) {
          final vA = index.getX(i + 0).toInt();
          final vB = index.getX(i + 1).toInt();
          final vC = index.getX(i + 2).toInt();

          pA.fromBufferAttribute(positionAttribute, vA);
          pB.fromBufferAttribute(positionAttribute, vB);
          pC.fromBufferAttribute(positionAttribute, vC);

          cb.subVectors(pC, pB);
          ab.subVectors(pA, pB);
          cb.cross(ab);

          nA.fromBufferAttribute(normalAttribute, vA);
          nB.fromBufferAttribute(normalAttribute, vB);
          nC.fromBufferAttribute(normalAttribute, vC);

          nA.add(cb);
          nB.add(cb);
          nC.add(cb);

          normalAttribute.setXYZ(vA, nA.x, nA.y, nA.z);
          normalAttribute.setXYZ(vB, nB.x, nB.y, nB.z);
          normalAttribute.setXYZ(vC, nC.x, nC.y, nC.z);
        }
      } else {
        // non-indexed elements (unconnected triangle soup)

        for (var i = 0, il = positionAttribute.count; i < il; i += 3) {
          pA.fromBufferAttribute(positionAttribute, i + 0);
          pB.fromBufferAttribute(positionAttribute, i + 1);
          pC.fromBufferAttribute(positionAttribute, i + 2);

          cb.subVectors(pC, pB);
          ab.subVectors(pA, pB);
          cb.cross(ab);

          normalAttribute.setXYZ(i + 0, cb.x, cb.y, cb.z);
          normalAttribute.setXYZ(i + 1, cb.x, cb.y, cb.z);
          normalAttribute.setXYZ(i + 2, cb.x, cb.y, cb.z);
        }
      }

      normalizeNormals();

      normalAttribute.needsUpdate = true;
    }
  }

  /// Ensures every normal vector in a geometry will have a magnitude of `1`. This will correct lighting on
  /// the geometry surfaces.
  void normalizeNormals() {
    final normals = attributes['normal']!;

    for (var i = 0, il = normals.count; i < il; i++) {
      _bufferGeometryVector.fromBufferAttribute(normals, i);

      _bufferGeometryVector.normalize();

      normals.setXYZ(i, _bufferGeometryVector.x, _bufferGeometryVector.y, _bufferGeometryVector.z);
    }
  }

  /// Return a new non-index version of this indexed geometry. If the geometry is already non-indexed, the
  /// method is a NOOP.
  BufferGeometry toNonIndexed() {
    BufferAttribute convertBufferAttribute(BufferAttributeLike attribute, List<num> indices) {
      final array = attribute.array;
      final itemSize = attribute.itemSize;
      final normalized = attribute.normalized;

      final array2 = _bufferGeometryNewArray(array, indices.length * itemSize);

      var index = 0, index2 = 0;

      for (var i = 0, l = indices.length; i < l; i++) {
        if (attribute is InterleavedBufferAttribute) {
          index = indices[i].toInt() * attribute.data.stride + attribute.offset;
        } else {
          index = indices[i].toInt() * itemSize;
        }

        for (var j = 0; j < itemSize; j++) {
          array2[index2++] = array[index++];
        }
      }

      return BufferAttribute(array2, itemSize, normalized);
    }

    //

    final index = this.index;

    if (index == null) {
      warn('BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed.');
      return this;
    }

    final geometry2 = BufferGeometry();

    final indices = index.array;

    // attributes

    for (final MapEntry(key: name, value: attribute) in attributes.entries) {
      final newAttribute = convertBufferAttribute(attribute, indices);

      geometry2.setAttribute(name, newAttribute);
    }

    // morph attributes

    for (final MapEntry(key: name, value: morphAttribute) in morphAttributes.entries) {
      final morphArray = <BufferAttributeLike>[];

      // morphAttribute: array of Float32BufferAttributes
      for (var i = 0, il = morphAttribute.length; i < il; i++) {
        final attribute = morphAttribute[i];

        final newAttribute = convertBufferAttribute(attribute, indices);

        morphArray.add(newAttribute);
      }

      geometry2.morphAttributes[name] = morphArray;
    }

    geometry2.morphTargetsRelative = morphTargetsRelative;

    // groups

    for (var i = 0, l = groups.length; i < l; i++) {
      final group = groups[i];
      geometry2.addGroup(group.start, group.count, group.materialIndex);
    }

    return geometry2;
  }

  /// Serializes the geometry into JSON (a map, exception E-OBJECT).
  Map<String, Object?> toJSON() {
    final Map<String, Object?> data = {
      'metadata': <String, Object?>{'version': 4.7, 'type': 'BufferGeometry', 'generator': 'BufferGeometry.toJSON'},
    };

    final parameters = this.parameters;

    // standard BufferGeometry serialization

    data['uuid'] = uuid;
    data['type'] = type;

    // A parametric geometry that was transformed is written as plain BufferGeometry data.
    if (parameters != null && _transformed == true) {
      data['type'] = 'BufferGeometry';
    }

    data['name'] = name;

    if (userData.isNotEmpty) {
      data['userData'] = userData;
    }

    if (parameters != null && _transformed != true) {
      for (final MapEntry(:key, :value) in parameters.entries) {
        if (value != null) {
          data[key] = value;
        }
      }

      return data;
    }

    // for simplicity the code assumes attributes are not shared across geometries, see #15811

    final Map<String, Object?> json = {'attributes': <String, Object?>{}};
    data['data'] = json;

    final index = this.index;

    if (index != null) {
      json['index'] = <String, Object?>{
        'type': _bufferGeometryArrayType(index.array),
        'array': List<num>.of(index.array),
      };
    }

    final jsonAttributes = json['attributes'] as Map<String, Object?>;

    for (final MapEntry(:key, value: attribute) in attributes.entries) {
      jsonAttributes[key] = attribute.toJSON(json);
    }

    final Map<String, Object?> jsonMorphAttributes = {};
    var hasMorphAttributes = false;

    for (final MapEntry(:key, value: attributeArray) in morphAttributes.entries) {
      final array = <Object?>[];

      for (var i = 0, il = attributeArray.length; i < il; i++) {
        final attribute = attributeArray[i];

        array.add(attribute.toJSON(json));
      }

      if (array.isNotEmpty) {
        jsonMorphAttributes[key] = array;

        hasMorphAttributes = true;
      }
    }

    if (hasMorphAttributes) {
      json['morphAttributes'] = jsonMorphAttributes;
      json['morphTargetsRelative'] = morphTargetsRelative;
    }

    if (groups.isNotEmpty) {
      // the reference deep-copies through JSON.parse( JSON.stringify( groups ) )
      json['groups'] = [
        for (final group in groups)
          <String, Object?>{'start': group.start, 'count': group.count, 'materialIndex': group.materialIndex},
      ];
    }

    final boundingSphere = this.boundingSphere;

    if (boundingSphere != null) {
      json['boundingSphere'] = boundingSphere.toJSON();
    }

    return data;
  }

  /// Returns a new geometry with copied values from this instance.
  BufferGeometry clone() {
    return BufferGeometry().copy(this);
  }

  /// Copies the values of the given geometry to this instance.
  BufferGeometry copy(BufferGeometry source) {
    // reset

    index = null;
    attributes = {};
    morphAttributes = {};
    groups = [];
    boundingBox = null;
    boundingSphere = null;

    // used for storing cloned, shared data

    final Map<String, Object?> data = {};

    // name

    name = source.name;

    // index

    final sourceIndex = source.index;

    if (sourceIndex != null) {
      setIndex(sourceIndex.clone());
    }

    // attributes

    for (final MapEntry(key: name, value: attribute) in source.attributes.entries) {
      setAttribute(name, attribute.clone(data));
    }

    // morph attributes

    for (final MapEntry(key: name, value: morphAttribute) in source.morphAttributes.entries) {
      final array = <BufferAttributeLike>[];

      // morphAttribute: array of Float32BufferAttributes
      for (var i = 0, l = morphAttribute.length; i < l; i++) {
        array.add(morphAttribute[i].clone(data));
      }

      morphAttributes[name] = array;
    }

    morphTargetsRelative = source.morphTargetsRelative;

    // groups

    for (var i = 0, l = source.groups.length; i < l; i++) {
      final group = source.groups[i];
      addGroup(group.start, group.count, group.materialIndex);
    }

    // bounding box

    if (source.boundingBox != null) {
      boundingBox = source.boundingBox!.clone();
    }

    // bounding sphere

    if (source.boundingSphere != null) {
      boundingSphere = source.boundingSphere!.clone();
    }

    // draw range

    drawRange.start = source.drawRange.start;
    drawRange.count = source.drawRange.count;

    // user data

    userData = source.userData;

    // transformed flag

    _transformed = source._transformed;

    return this;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  void dispose() {
    dispatchEvent(Event('dispose'));
  }
}

/// Reads `point.x, point.y, point.z || 0` from a Vector2, Vector3 or Vector4 (exception E-UNION).
(double, double, double) _bufferGeometryPoint(Object point) {
  // `z || 0`: 0, -0 and NaN all become 0
  double orZero(double z) => _jsOr(z, 0);

  return switch (point) {
    Vector2() => (point.x, point.y, 0.0),
    Vector3() => (point.x, point.y, orZero(point.z)),
    Vector4() => (point.x, point.y, orZero(point.z)),
    _ => throw ArgumentError('BufferGeometry.setFromPoints(): expected Vector2 or Vector3 points, got $point'),
  };
}
