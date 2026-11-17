part of '../../ent.dart';

/// The quad shared by all sprites, created with the first one (the reference's module-level `_geometry`).
BufferGeometry? _spriteGeometry;

final _spriteIntersectPoint = Vector3();
final _spriteWorldScale = Vector3();
final _spriteMvPosition = Vector3();

final _spriteAlignedPosition = Vector2();
final _spriteRotatedPosition = Vector2();
final _spriteViewWorldMatrix = Matrix4();

final _spriteVA = Vector3();
final _spriteVB = Vector3();
final _spriteVC = Vector3();

final _spriteUvA = Vector2();
final _spriteUvB = Vector2();
final _spriteUvC = Vector2();

/// A sprite is a plane that always faces towards the camera, generally with a partially transparent texture
/// applied.
///
/// Sprites do not cast shadows, setting [castShadow] to `true` will have no effect.
///
/// ```dart
/// final material = SpriteMaterial();
/// final sprite = Sprite(material);
/// scene.add(sprite);
/// ```
class Sprite extends Object3D {
  /// Constructs a new sprite. `material` defaults to a new [SpriteMaterial].
  Sprite([Material? material]) : material = material ?? SpriteMaterial() {
    type = 'Sprite';

    if (_spriteGeometry == null) {
      final geometry = BufferGeometry();

      final float32Array = Float32List.fromList([
        -0.5, -0.5, 0, 0, 0, //
        0.5, -0.5, 0, 1, 0, //
        0.5, 0.5, 0, 1, 1, //
        -0.5, 0.5, 0, 0, 1, //
      ]);

      final interleavedBuffer = InterleavedBuffer(float32Array, 5);

      geometry.setIndex(<int>[0, 1, 2, 0, 2, 3]);
      geometry.setAttribute('position', InterleavedBufferAttribute(interleavedBuffer, 3, 0, false));
      geometry.setAttribute('uv', InterleavedBufferAttribute(interleavedBuffer, 2, 3, false));

      _spriteGeometry = geometry;
    }

    geometry = _spriteGeometry!;
  }

  /// This flag can be used for type testing.
  bool get isSprite => true;

  /// The sprite geometry, shared by all sprites.
  late BufferGeometry geometry;

  /// The sprite material. Raycasting reads `rotation` and `sizeAttenuation` from it, so it must be a
  /// [SpriteMaterial] (or a subclass) when the sprite is raycast.
  Material material;

  /// The sprite's anchor point, and the point around which the sprite rotates. A value of `(0.5, 0.5)`
  /// corresponds to the midpoint of the sprite. A value of `(0, 0)` corresponds to the lower left corner
  /// of the sprite.
  Vector2 center = Vector2(0.5, 0.5);

  /// The number of instances of this sprite. Can only be used with `WebGPURenderer`.
  int count = 1;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isSprite' => isSprite,
      'geometry' => geometry,
      'material' => material,
      'center' => center,
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
        material = value as Material;
      case 'center':
        center = value as Vector2;
      case 'count':
        count = _jsInt(value);
      default:
        super[key] = value;
    }
  }

  @override
  bool intersectsFrustum(Frustum frustum) {
    return frustum.intersectsSprite(this);
  }

  /// Computes intersection points between a casted ray and this sprite. [Raycaster.camera] must be set.
  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    if (raycaster.camera == null) {
      error('Sprite: "Raycaster.camera" needs to be set in order to raycast against sprites.');
    }

    final camera = raycaster.camera!;
    final material = this.material as SpriteMaterial;

    _spriteWorldScale.setFromMatrixScale(matrixWorld);

    _spriteViewWorldMatrix.copy(camera.matrixWorld);
    modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse, matrixWorld);

    _spriteMvPosition.setFromMatrixPosition(modelViewMatrix);

    if (camera is PerspectiveCamera && material.sizeAttenuation == false) {
      _spriteWorldScale.multiplyScalar(-_spriteMvPosition.z);
    }

    final rotation = material.rotation;
    double? sin, cos;

    if (rotation != 0) {
      cos = math.cos(rotation);
      sin = math.sin(rotation);
    }

    final center = this.center;

    _spriteTransformVertex(_spriteVA.set(-0.5, -0.5, 0), _spriteMvPosition, center, _spriteWorldScale, sin, cos);
    _spriteTransformVertex(_spriteVB.set(0.5, -0.5, 0), _spriteMvPosition, center, _spriteWorldScale, sin, cos);
    _spriteTransformVertex(_spriteVC.set(0.5, 0.5, 0), _spriteMvPosition, center, _spriteWorldScale, sin, cos);

    _spriteUvA.set(0, 0);
    _spriteUvB.set(1, 0);
    _spriteUvC.set(1, 1);

    // check first triangle
    var intersect = raycaster.ray.intersectTriangle(_spriteVA, _spriteVB, _spriteVC, false, _spriteIntersectPoint);

    if (intersect == null) {
      // check second triangle
      _spriteTransformVertex(_spriteVB.set(-0.5, 0.5, 0), _spriteMvPosition, center, _spriteWorldScale, sin, cos);
      _spriteUvB.set(0, 1);

      intersect = raycaster.ray.intersectTriangle(_spriteVA, _spriteVC, _spriteVB, false, _spriteIntersectPoint);

      if (intersect == null) {
        return null;
      }
    }

    final distance = raycaster.ray.origin.distanceTo(_spriteIntersectPoint);

    if (distance < raycaster.near || distance > raycaster.far) {
      return null;
    }

    intersects.add(
      Intersection(
        distance: distance,
        point: _spriteIntersectPoint.clone(),
        uv: Triangle.getInterpolationStatic(
          _spriteIntersectPoint,
          _spriteVA,
          _spriteVB,
          _spriteVC,
          _spriteUvA,
          _spriteUvB,
          _spriteUvC,
          Vector2(),
        ),
        object: this,
      ),
    );

    return null;
  }

  @override
  Sprite copy(covariant Sprite source, [bool recursive = true]) {
    super.copy(source, recursive);

    center.copy(source.center);

    material = source.material;

    return this;
  }

  @override
  Sprite clone([bool recursive = true]) {
    return Sprite().copy(this, recursive);
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);

    (data['object'] as Map<String, Object?>)['center'] = center.toArray();

    return data;
  }
}

void _spriteTransformVertex(
  Vector3 vertexPosition,
  Vector3 mvPosition,
  Vector2 center,
  Vector3 scale,
  double? sin,
  double? cos,
) {
  // compute position in camera space (the reference passes the Vector3s to Vector2 methods, which read x and y)
  _spriteAlignedPosition.x = (vertexPosition.x - center.x + 0.5) * scale.x;
  _spriteAlignedPosition.y = (vertexPosition.y - center.y + 0.5) * scale.y;

  // to check if rotation is not zero
  if (sin != null) {
    _spriteRotatedPosition.x = (cos! * _spriteAlignedPosition.x) - (sin * _spriteAlignedPosition.y);
    _spriteRotatedPosition.y = (sin * _spriteAlignedPosition.x) + (cos * _spriteAlignedPosition.y);
  } else {
    _spriteRotatedPosition.copy(_spriteAlignedPosition);
  }

  vertexPosition.copy(mvPosition);
  vertexPosition.x += _spriteRotatedPosition.x;
  vertexPosition.y += _spriteRotatedPosition.y;

  // transform to world space
  vertexPosition.applyMatrix4(_spriteViewWorldMatrix);
}
