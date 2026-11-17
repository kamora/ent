part of '../../ent.dart';

final _lineVStart = Vector3();
final _lineVEnd = Vector3();

final _lineInverseMatrix = Matrix4();
final _lineRay = Ray();
final _lineSphere = Sphere();

final _lineIntersectPointOnRay = Vector3();
final _lineIntersectPointOnSegment = Vector3();

/// A continuous line. The line are rendered by connecting consecutive vertices with straight lines.
///
/// ```dart
/// final material = LineBasicMaterial();
/// final geometry = BufferGeometry().setFromPoints([Vector3(-10, 0, 0), Vector3(0, 10, 0), Vector3(10, 0, 0)]);
/// final line = Line(geometry, material);
/// scene.add(line);
/// ```
class Line extends Object3D {
  /// Constructs a new line. `geometry` defaults to a new [BufferGeometry], `material` to a new
  /// [LineBasicMaterial].
  ///
  /// `material` is a [Material] or a `List<Material>` (exception E-UNION).
  Line([BufferGeometry? geometry, Object? material])
    : geometry = geometry ?? BufferGeometry(),
      material = material ?? LineBasicMaterial() {
    type = 'Line';

    updateMorphTargets();
  }

  /// This flag can be used for type testing.
  bool get isLine => true;

  /// The line geometry.
  BufferGeometry geometry;

  /// The line material: a [Material] or a `List<Material>`.
  Object? material;

  /// A dictionary representing the morph targets in the geometry. The key is the morph target name, the
  /// value its attribute index. This member is `null` by default and only set when [updateMorphTargets]
  /// is called.
  Map<String, int>? morphTargetDictionary;

  /// An array of weights typically in the range `[0,1]` that specify how much of the morph is applied.
  /// This member is `null` by default and only set when [updateMorphTargets] is called.
  List<double>? morphTargetInfluences;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isLine' => isLine,
      'geometry' => geometry,
      'material' => material,
      'morphTargetDictionary' => morphTargetDictionary,
      'morphTargetInfluences' => morphTargetInfluences,
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
      default:
        super[key] = value;
    }
  }

  @override
  Line copy(covariant Line source, [bool recursive = true]) {
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
  Line clone([bool recursive = true]) {
    return Line().copy(this, recursive);
  }

  /// Computes an array of distance values which are necessary for rendering dashed lines. For each vertex
  /// in the geometry, the method calculates the cumulative length from the current point to the very
  /// beginning of the line.
  Line computeLineDistances() {
    final geometry = this.geometry;

    // we assume non-indexed geometry

    if (geometry.index == null) {
      final positionAttribute = geometry.attributes['position']!;
      final lineDistances = <double>[0];

      for (var i = 1, l = positionAttribute.count; i < l; i++) {
        _lineVStart.fromBufferAttribute(positionAttribute, i - 1);
        _lineVEnd.fromBufferAttribute(positionAttribute, i);

        lineDistances.add(lineDistances[i - 1]);
        lineDistances[i] += _lineVStart.distanceTo(_lineVEnd);
      }

      geometry.setAttribute('lineDistance', Float32BufferAttribute(lineDistances, 1));
    } else {
      warn('Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.');
    }

    return this;
  }

  @override
  bool intersectsFrustum(Frustum frustum) {
    return frustum.intersectsObject(this);
  }

  /// Computes intersection points between a casted ray and this line.
  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final geometry = this.geometry;
    final matrixWorld = this.matrixWorld;
    final threshold = (raycaster.params['Line']!['threshold'] as num).toDouble();
    final drawRange = geometry.drawRange;

    // Checking boundingSphere distance to ray

    if (geometry.boundingSphere == null) {
      geometry.computeBoundingSphere();
    }

    _lineSphere.copy(geometry.boundingSphere!);
    _lineSphere.applyMatrix4(matrixWorld);
    _lineSphere.radius += threshold;

    if (raycaster.ray.intersectsSphere(_lineSphere) == false) {
      return null;
    }

    //

    _lineInverseMatrix.copy(matrixWorld).invert();
    _lineRay.copy(raycaster.ray).applyMatrix4(_lineInverseMatrix);

    final localThreshold = threshold / ((scale.x + scale.y + scale.z) / 3);
    final localThresholdSq = localThreshold * localThreshold;

    final step = this is LineSegments ? 2 : 1;

    final index = geometry.index;

    if (index != null) {
      final start = math.max(0.0, drawRange.start);
      final end = math.min(index.count.toDouble(), drawRange.start + drawRange.count);

      for (var i = start.toInt(), l = end - 1; i < l; i += step) {
        final a = index.getX(i).toInt();
        final b = index.getX(i + 1).toInt();

        final intersect = _lineCheckIntersection(this, raycaster, _lineRay, localThresholdSq, a, b, i);

        if (intersect != null) {
          intersects.add(intersect);
        }
      }

      if (this is LineLoop) {
        final a = index.getX((end - 1).toInt()).toInt();
        final b = index.getX(start.toInt()).toInt();

        final intersect = _lineCheckIntersection(this, raycaster, _lineRay, localThresholdSq, a, b, (end - 1).toInt());

        if (intersect != null) {
          intersects.add(intersect);
        }
      }
    } else {
      final positionAttribute = geometry.attributes['position']!;
      final start = math.max(0.0, drawRange.start);
      final end = math.min(positionAttribute.count.toDouble(), drawRange.start + drawRange.count);

      for (var i = start.toInt(), l = end - 1; i < l; i += step) {
        final intersect = _lineCheckIntersection(this, raycaster, _lineRay, localThresholdSq, i, i + 1, i);

        if (intersect != null) {
          intersects.add(intersect);
        }
      }

      if (this is LineLoop) {
        final last = (end - 1).toInt();
        final intersect = _lineCheckIntersection(
          this,
          raycaster,
          _lineRay,
          localThresholdSq,
          last,
          start.toInt(),
          last,
        );

        if (intersect != null) {
          intersects.add(intersect);
        }
      }
    }

    return null;
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
}

Intersection? _lineCheckIntersection(
  Line object,
  Raycaster raycaster,
  Ray ray,
  double thresholdSq,
  int a,
  int b,
  int i,
) {
  final positionAttribute = object.geometry.attributes['position']!;

  _lineVStart.fromBufferAttribute(positionAttribute, a);
  _lineVEnd.fromBufferAttribute(positionAttribute, b);

  final distSq = ray.distanceSqToSegment(
    _lineVStart,
    _lineVEnd,
    _lineIntersectPointOnRay,
    _lineIntersectPointOnSegment,
  );

  if (distSq > thresholdSq) {
    return null;
  }

  _lineIntersectPointOnRay.applyMatrix4(object.matrixWorld); // Move back to world space for distance calculation

  final distance = raycaster.ray.origin.distanceTo(_lineIntersectPointOnRay);

  if (distance < raycaster.near || distance > raycaster.far) {
    return null;
  }

  return Intersection(
    distance: distance,

    // What do we want? intersection point on the ray or on the segment??
    // point: raycaster.ray.at( distance ),
    point: _lineIntersectPointOnSegment.clone().applyMatrix4(object.matrixWorld),
    index: i,
    object: object,
  );
}
