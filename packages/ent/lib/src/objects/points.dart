part of '../../ent.dart';

final _pointsInverseMatrix = Matrix4();
final _pointsRay = Ray();
final _pointsSphere = Sphere();
final _pointsPosition = Vector3();

/// A class for displaying points or point clouds.
class Points extends Object3D {
  /// Constructs a new point cloud. `geometry` defaults to a new [BufferGeometry], `material` to a new
  /// [PointsMaterial].
  ///
  /// `material` is a [Material] or a `List<Material>` (exception E-UNION).
  Points([BufferGeometry? geometry, Object? material])
    : geometry = geometry ?? BufferGeometry(),
      material = material ?? PointsMaterial() {
    type = 'Points';

    updateMorphTargets();
  }

  /// This flag can be used for type testing.
  bool get isPoints => true;

  /// The points geometry.
  BufferGeometry geometry;

  /// The points material: a [Material] or a `List<Material>`.
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
      'isPoints' => isPoints,
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
  Points copy(covariant Points source, [bool recursive = true]) {
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
  Points clone([bool recursive = true]) {
    return Points().copy(this, recursive);
  }

  @override
  bool intersectsFrustum(Frustum frustum) {
    return frustum.intersectsObject(this);
  }

  /// Computes intersection points between a casted ray and this point cloud.
  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final geometry = this.geometry;
    final matrixWorld = this.matrixWorld;
    final threshold = (raycaster.params['Points']!['threshold'] as num).toDouble();
    final drawRange = geometry.drawRange;

    // Checking boundingSphere distance to ray

    if (geometry.boundingSphere == null) {
      geometry.computeBoundingSphere();
    }

    _pointsSphere.copy(geometry.boundingSphere!);
    _pointsSphere.applyMatrix4(matrixWorld);
    _pointsSphere.radius += threshold;

    if (raycaster.ray.intersectsSphere(_pointsSphere) == false) {
      return null;
    }

    //

    _pointsInverseMatrix.copy(matrixWorld).invert();
    _pointsRay.copy(raycaster.ray).applyMatrix4(_pointsInverseMatrix);

    final localThreshold = threshold / ((scale.x + scale.y + scale.z) / 3);
    final localThresholdSq = localThreshold * localThreshold;

    final index = geometry.index;
    final positionAttribute = geometry.attributes['position'];

    if (index != null) {
      final start = math.max(0.0, drawRange.start);
      final end = math.min(index.count.toDouble(), drawRange.start + drawRange.count);

      for (var i = start.toInt(); i < end; i++) {
        final a = index.getX(i).toInt();

        _pointsPosition.fromBufferAttribute(positionAttribute!, a);

        _pointsTestPoint(_pointsPosition, a, localThresholdSq, matrixWorld, raycaster, intersects, this);
      }
    } else {
      final start = math.max(0.0, drawRange.start);
      final end = math.min(positionAttribute!.count.toDouble(), drawRange.start + drawRange.count);

      for (var i = start.toInt(); i < end; i++) {
        _pointsPosition.fromBufferAttribute(positionAttribute, i);

        _pointsTestPoint(_pointsPosition, i, localThresholdSq, matrixWorld, raycaster, intersects, this);
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

void _pointsTestPoint(
  Vector3 point,
  int index,
  double localThresholdSq,
  Matrix4 matrixWorld,
  Raycaster raycaster,
  List<Intersection> intersects,
  Points object,
) {
  final rayPointDistanceSq = _pointsRay.distanceSqToPoint(point);

  if (rayPointDistanceSq < localThresholdSq) {
    final intersectPoint = Vector3();

    _pointsRay.closestPointToPoint(point, intersectPoint);
    intersectPoint.applyMatrix4(matrixWorld);

    final distance = raycaster.ray.origin.distanceTo(intersectPoint);

    if (distance < raycaster.near || distance > raycaster.far) {
      return;
    }

    intersects.add(
      Intersection(
        distance: distance,
        distanceToRay: math.sqrt(rayPointDistanceSq),
        point: intersectPoint,
        index: index,
        object: object,
      ),
    );
  }
}
