part of '../../ent.dart';

//
// The reference reads `object.geometry`, `object.boundingBox` and `object.boundingSphere` from any 3D object and lets
// `undefined` decide (Box3.expandByObject, Frustum.intersectsObject). The helpers at the end of this file answer those
// reads for the classes that have the properties.

final _meshInverseMatrix = Matrix4();
final _meshRay = Ray();
final _meshSphere = Sphere();
final _meshSphereHitAt = Vector3();

final _meshVA = Vector3();
final _meshVB = Vector3();
final _meshVC = Vector3();

final _meshTempA = Vector3();
final _meshMorphA = Vector3();

final _meshIntersectionPoint = Vector3();
final _meshIntersectionPointWorld = Vector3();

/// Class representing triangular polygon mesh based objects.
///
/// ```dart
/// final mesh = Mesh(BoxGeometry(1, 1, 1), MeshBasicMaterial());
/// scene.add(mesh);
/// ```
class Mesh extends Object3D {
  /// Constructs a new mesh. `geometry` defaults to a new [BufferGeometry], `material` to a new
  /// [MeshBasicMaterial].
  ///
  /// `material` is a [Material] or a `List<Material>` (the reference's `Material|Array<Material>`, exception E-UNION).
  Mesh([BufferGeometry? geometry, Object? material])
    : geometry = geometry ?? BufferGeometry(),
      material = material ?? MeshBasicMaterial() {
    type = 'Mesh';

    updateMorphTargets();
  }

  /// This flag can be used for type testing.
  bool get isMesh => true;

  /// The mesh geometry.
  BufferGeometry geometry;

  /// The mesh material: a [Material] or a `List<Material>` (one per geometry group). `null` stands for the reference's
  /// `undefined` and makes the mesh ignored by raycasting.
  Object? material;

  /// A dictionary representing the morph targets in the geometry. The key is the morph target name, the
  /// value its attribute index. This member is `null` by default and only set when [updateMorphTargets]
  /// is called.
  Map<String, int>? morphTargetDictionary;

  /// An array of weights typically in the range `[0,1]` that specify how much of the morph is applied.
  /// This member is `null` by default and only set when [updateMorphTargets] is called.
  List<double>? morphTargetInfluences;

  /// The number of instances of this mesh. Can only be used with `WebGPURenderer`.
  int count = 1;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isMesh' => isMesh,
      'geometry' => geometry,
      'material' => material,
      'morphTargetDictionary' => morphTargetDictionary,
      'morphTargetInfluences' => morphTargetInfluences,
      'count' => count,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'geometry':
        geometry = value as BufferGeometry;
      case 'material':
        material = value;
      case 'morphTargetDictionary':
        morphTargetDictionary = value as Map<String, int>?;
      case 'morphTargetInfluences':
        morphTargetInfluences = value as List<double>?;
      case 'count':
        count = _jsInt(value);
      default:
        super[key] = value;
    }
  }

  @override
  Mesh copy(covariant Mesh source, [bool recursive = true]) {
    super.copy(source, recursive);

    final influences = source.morphTargetInfluences;
    morphTargetInfluences = influences != null ? List.of(influences) : null;

    final dictionary = source.morphTargetDictionary;
    morphTargetDictionary = dictionary != null ? Map.of(dictionary) : null;

    material = _objectsCopyMaterial(source.material);
    geometry = source.geometry;

    return this;
  }

  @override
  Mesh clone([bool recursive = true]) {
    return Mesh().copy(this, recursive);
  }

  /// Sets the values of [morphTargetDictionary] and [morphTargetInfluences] to make sure existing morph
  /// targets can influence this 3D object.
  void updateMorphTargets() {
    final morph = _objectsMorphTargets(geometry);

    if (morph != null) {
      morphTargetInfluences = morph.$1;
      morphTargetDictionary = morph.$2;
    }
  }

  /// Returns the local-space position of the vertex at the given index, taking into account the current
  /// animation state of both morph targets and skinning.
  Vector3 getVertexPosition(int index, Vector3 target) {
    final position = geometry.attributes['position']!;
    final morphPosition = geometry.morphAttributes['position'];
    final morphTargetsRelative = geometry.morphTargetsRelative;

    target.fromBufferAttribute(position, index);

    final morphInfluences = morphTargetInfluences;

    if (morphPosition != null && morphInfluences != null) {
      _meshMorphA.set(0, 0, 0);

      for (var i = 0, il = morphPosition.length; i < il; i++) {
        final influence = morphInfluences[i];
        final morphAttribute = morphPosition[i];

        if (influence == 0) {
          continue;
        }

        _meshTempA.fromBufferAttribute(morphAttribute, index);

        if (morphTargetsRelative) {
          _meshMorphA.addScaledVector(_meshTempA, influence);
        } else {
          _meshMorphA.addScaledVector(_meshTempA.sub(target), influence);
        }
      }

      target.add(_meshMorphA);
    }

    return target;
  }

  @override
  bool intersectsFrustum(Frustum frustum) {
    return frustum.intersectsObject(this);
  }

  /// Computes intersection points between a casted ray and this mesh.
  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final geometry = this.geometry;
    final matrixWorld = this.matrixWorld;

    if (material == null) {
      return null;
    }

    // test with bounding sphere in world space

    if (geometry.boundingSphere == null) {
      geometry.computeBoundingSphere();
    }

    _meshSphere.copy(geometry.boundingSphere!);
    _meshSphere.applyMatrix4(matrixWorld);

    // check distance from ray origin to bounding sphere

    _meshRay.copy(raycaster.ray).recast(raycaster.near);

    if (_meshSphere.containsPoint(_meshRay.origin) == false) {
      if (_meshRay.intersectSphere(_meshSphere, _meshSphereHitAt) == null) {
        return null;
      }

      final range = raycaster.far - raycaster.near;

      if (_meshRay.origin.distanceToSquared(_meshSphereHitAt) > range * range) {
        return null;
      }
    }

    // convert ray to local space of mesh

    _meshInverseMatrix.copy(matrixWorld).invert();
    _meshRay.copy(raycaster.ray).applyMatrix4(_meshInverseMatrix);

    // test with bounding box in local space

    final boundingBox = geometry.boundingBox;

    if (boundingBox != null) {
      if (_meshRay.intersectsBox(boundingBox) == false) {
        return null;
      }
    }

    // test for intersections with geometry

    _computeIntersections(raycaster, intersects, _meshRay);

    return null;
  }

  void _computeIntersections(Raycaster raycaster, List<Intersection> intersects, Ray rayLocalSpace) {
    Intersection? intersection;

    final geometry = this.geometry;
    final material = this.material;

    final index = geometry.index;
    final position = geometry.attributes['position'];
    final uv = geometry.attributes['uv'];
    final uv1 = geometry.attributes['uv1'];
    final normal = geometry.attributes['normal'];
    final groups = geometry.groups;
    final drawRange = geometry.drawRange;

    if (index != null) {
      // indexed buffer geometry

      if (material is List<Material>) {
        for (var i = 0, il = groups.length; i < il; i++) {
          final group = groups[i];
          final groupMaterial = material[group.materialIndex as int];

          final start = math.max(group.start.toDouble(), drawRange.start);
          final end = math.min(
            index.count.toDouble(),
            math.min((group.start + group.count).toDouble(), drawRange.start + drawRange.count),
          );

          for (var j = start.toInt(); j < end; j += 3) {
            final a = index.getX(j).toInt();
            final b = index.getX(j + 1).toInt();
            final c = index.getX(j + 2).toInt();

            intersection = _meshCheckGeometryIntersection(
              this,
              groupMaterial,
              raycaster,
              rayLocalSpace,
              uv,
              uv1,
              normal,
              a,
              b,
              c,
            );

            if (intersection != null) {
              intersection.faceIndex = j ~/ 3; // triangle number in indexed buffer semantics
              intersection.face!.materialIndex = group.materialIndex;
              intersects.add(intersection);
            }
          }
        }
      } else {
        final start = math.max(0.0, drawRange.start);
        final end = math.min(index.count.toDouble(), drawRange.start + drawRange.count);

        for (var i = start.toInt(); i < end; i += 3) {
          final a = index.getX(i).toInt();
          final b = index.getX(i + 1).toInt();
          final c = index.getX(i + 2).toInt();

          intersection = _meshCheckGeometryIntersection(
            this,
            material as Material,
            raycaster,
            rayLocalSpace,
            uv,
            uv1,
            normal,
            a,
            b,
            c,
          );

          if (intersection != null) {
            intersection.faceIndex = i ~/ 3; // triangle number in indexed buffer semantics
            intersects.add(intersection);
          }
        }
      }
    } else if (position != null) {
      // non-indexed buffer geometry

      if (material is List<Material>) {
        for (var i = 0, il = groups.length; i < il; i++) {
          final group = groups[i];
          final groupMaterial = material[group.materialIndex as int];

          final start = math.max(group.start.toDouble(), drawRange.start);
          final end = math.min(
            position.count.toDouble(),
            math.min((group.start + group.count).toDouble(), drawRange.start + drawRange.count),
          );

          for (var j = start.toInt(); j < end; j += 3) {
            final a = j;
            final b = j + 1;
            final c = j + 2;

            intersection = _meshCheckGeometryIntersection(
              this,
              groupMaterial,
              raycaster,
              rayLocalSpace,
              uv,
              uv1,
              normal,
              a,
              b,
              c,
            );

            if (intersection != null) {
              intersection.faceIndex = j ~/ 3; // triangle number in non-indexed buffer semantics
              intersection.face!.materialIndex = group.materialIndex;
              intersects.add(intersection);
            }
          }
        }
      } else {
        final start = math.max(0.0, drawRange.start);
        final end = math.min(position.count.toDouble(), drawRange.start + drawRange.count);

        for (var i = start.toInt(); i < end; i += 3) {
          final a = i;
          final b = i + 1;
          final c = i + 2;

          intersection = _meshCheckGeometryIntersection(
            this,
            material as Material,
            raycaster,
            rayLocalSpace,
            uv,
            uv1,
            normal,
            a,
            b,
            c,
          );

          if (intersection != null) {
            intersection.faceIndex = i ~/ 3; // triangle number in non-indexed buffer semantics
            intersects.add(intersection);
          }
        }
      }
    }
  }
}

Intersection? _meshCheckIntersection(
  Object3D object,
  Material material,
  Raycaster raycaster,
  Ray ray,
  Vector3 pA,
  Vector3 pB,
  Vector3 pC,
  Vector3 point,
) {
  Vector3? intersect;

  if (material.side == BackSide) {
    intersect = ray.intersectTriangle(pC, pB, pA, true, point);
  } else {
    intersect = ray.intersectTriangle(pA, pB, pC, (material.side == FrontSide), point);
  }

  if (intersect == null) {
    return null;
  }

  _meshIntersectionPointWorld.copy(point);
  _meshIntersectionPointWorld.applyMatrix4(object.matrixWorld);

  final distance = raycaster.ray.origin.distanceTo(_meshIntersectionPointWorld);

  if (distance < raycaster.near || distance > raycaster.far) {
    return null;
  }

  return Intersection(distance: distance, point: _meshIntersectionPointWorld.clone(), object: object);
}

Intersection? _meshCheckGeometryIntersection(
  Mesh object,
  Material material,
  Raycaster raycaster,
  Ray ray,
  BufferAttributeLike? uv,
  BufferAttributeLike? uv1,
  BufferAttributeLike? normal,
  int a,
  int b,
  int c,
) {
  object.getVertexPosition(a, _meshVA);
  object.getVertexPosition(b, _meshVB);
  object.getVertexPosition(c, _meshVC);

  final intersection = _meshCheckIntersection(
    object,
    material,
    raycaster,
    ray,
    _meshVA,
    _meshVB,
    _meshVC,
    _meshIntersectionPoint,
  );

  if (intersection != null) {
    final barycoord = Vector3();
    Triangle.getBarycoordStatic(_meshIntersectionPoint, _meshVA, _meshVB, _meshVC, barycoord);

    if (uv != null) {
      intersection.uv = Triangle.getInterpolatedAttribute(uv, a, b, c, barycoord, Vector2());
    }

    if (uv1 != null) {
      intersection.uv1 = Triangle.getInterpolatedAttribute(uv1, a, b, c, barycoord, Vector2());
    }

    if (normal != null) {
      final interpolated = Triangle.getInterpolatedAttribute(normal, a, b, c, barycoord, Vector3());
      intersection.normal = interpolated;

      if (interpolated.dot(ray.direction) > 0) {
        interpolated.multiplyScalar(-1);
      }
    }

    final face = Face(a: a, b: b, c: c, normal: Vector3(), materialIndex: 0);

    Triangle.getNormalStatic(_meshVA, _meshVB, _meshVC, face.normal);

    intersection.face = face;
    intersection.barycoord = barycoord;
  }

  return intersection;
}

/// `updateMorphTargets()` of Mesh, Line and Points: the influences and dictionary for the first morph attribute of
/// [geometry], or `null` when it has none (the reference then leaves both properties unchanged).
(List<double>, Map<String, int>)? _objectsMorphTargets(BufferGeometry geometry) {
  final morphAttributes = geometry.morphAttributes;

  if (morphAttributes.isEmpty) {
    return null;
  }

  final morphAttribute = morphAttributes[morphAttributes.keys.first]!;
  final influences = <double>[];
  final dictionary = <String, int>{};

  for (var m = 0, ml = morphAttribute.length; m < ml; m++) {
    final name = morphAttribute[m].name.isNotEmpty ? morphAttribute[m].name : '$m';

    influences.add(0);
    dictionary[name] = m;
  }

  return (influences, dictionary);
}

/// `Array.isArray( material ) ? material.slice() : material` from the objects' `copy()`.
Object? _objectsCopyMaterial(Object? material) {
  return material is List<Material> ? List<Material>.of(material) : material;
}

/// The reference's `object.geometry`: the geometry of the 3D objects that have one, else `null` (`undefined`).
BufferGeometry? _objectsGeometry(Object3D object) {
  return switch (object) {
    Mesh o => o.geometry,
    Line o => o.geometry,
    Points o => o.geometry,
    Sprite o => o.geometry,
    _ => null,
  };
}

/// The reference's object-level `object.boundingBox` (InstancedMesh, BatchedMesh, SkinnedMesh), computed when it is
/// still `null`, as `Box3.expandByObject` does; `null` (`undefined`) for other objects.
Box3? _objectsBoundingBox(Object3D object) {
  switch (object) {
    case InstancedMesh o:
      if (o.boundingBox == null) {
        o.computeBoundingBox();
      }

      return o.boundingBox;
    case BatchedMesh o:
      if (o.boundingBox == null) {
        o.computeBoundingBox();
      }

      return o.boundingBox;
    case SkinnedMesh o:
      if (o.boundingBox == null) {
        o.computeBoundingBox();
      }

      return o.boundingBox;
  }

  return null;
}

/// The reference's object-level `object.boundingSphere` (InstancedMesh, BatchedMesh, SkinnedMesh), computed when it is
/// still `null`, as `Frustum.intersectsObject` does; `null` (`undefined`) for other objects.
Sphere? _objectsBoundingSphere(Object3D object) {
  switch (object) {
    case InstancedMesh o:
      if (o.boundingSphere == null) {
        o.computeBoundingSphere();
      }

      return o.boundingSphere;
    case BatchedMesh o:
      if (o.boundingSphere == null) {
        o.computeBoundingSphere();
      }

      return o.boundingSphere;
    case SkinnedMesh o:
      if (o.boundingSphere == null) {
        o.computeBoundingSphere();
      }

      return o.boundingSphere;
  }

  return null;
}
