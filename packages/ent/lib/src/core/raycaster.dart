part of '../../ent.dart';

final _raycasterMatrix = Matrix4();

/// The triangle a [Mesh] raycast hit: the reference's `{ a, b, c, normal, materialIndex }` object (exception E-OBJECT).
/// `a`, `b`, `c` are vertex indices.
class Face {
  /// Creates a face record.
  Face({required this.a, required this.b, required this.c, Vector3? normal, this.materialIndex = 0})
    : normal = normal ?? Vector3();

  /// The index of the first vertex.
  int a;

  /// The index of the second vertex.
  int b;

  /// The index of the third vertex.
  int c;

  /// The face normal, in the object's local space.
  Vector3 normal;

  /// The material index of the face; the reference copies a group's `materialIndex`, which accepts any value.
  Object? materialIndex;
}

/// The intersection point of a raycaster intersection test (in the reference: the `Raycaster~Intersection` object
/// shape). Objects that implement [Object3D.raycast] fill the fields they know and leave the others `null` (`undefined`
/// in the reference); fields are mutable because the reference sets several after creating the result.
class Intersection {
  /// Creates an intersection result.
  Intersection({
    required this.distance,
    required this.point,
    required this.object,
    this.distanceToRay,
    this.face,
    this.faceIndex,
    this.uv,
    this.uv1,
    this.normal,
    this.barycoord,
    this.index,
    this.instanceId,
    this.batchId,
  });

  /// The distance from the ray's origin to the intersection point.
  double distance;

  /// Some 3D objects e.g. `Points` provide the distance of the intersection to the nearest point on the ray.
  /// For other objects it will be `null`.
  double? distanceToRay;

  /// The intersection point, in world coordinates.
  Vector3 point;

  /// The face that has been intersected (set by [Mesh]).
  Face? face;

  /// The face index.
  int? faceIndex;

  /// The 3D object that has been intersected.
  Object3D object;

  /// U,V coordinates at point of intersection.
  Vector2? uv;

  /// Second set of U,V coordinates at point of intersection.
  Vector2? uv1;

  /// Interpolated normal vector at point of intersection.
  Vector3? normal;

  /// Barycentric coordinates of the intersection point within the intersected triangle (set by `Mesh`).
  Vector3? barycoord;

  /// The index of the intersected point or segment (set by `Points` and `Line`).
  int? index;

  /// The index number of the instance where the ray intersects the `InstancedMesh`.
  int? instanceId;

  /// The index number of the instance where the ray intersects the `BatchedMesh`.
  int? batchId;
}

/// This class is designed to assist with raycasting. Raycasting is used for mouse picking (working out what
/// objects in the 3d space the mouse is over) amongst other things.
class Raycaster {
  /// Constructs a new raycaster: the ray's `origin` and (normalized) `direction`, and the `near` (default
  /// `0`) and `far` (default `Infinity`) distance limits.
  Raycaster([Vector3? origin, Vector3? direction, this.near = 0, this.far = double.infinity])
    : ray = Ray(origin, direction);

  /// The ray used for raycasting.
  Ray ray;

  /// All results returned are further away than near. Near can't be negative.
  double near;

  /// All results returned are closer than far. Far can't be lower than near.
  double far;

  /// The camera to use when raycasting against view-dependent objects such as billboarded objects like
  /// sprites. This field can be set manually or is set when calling `setFromCamera()`.
  Camera? camera;

  /// Allows to selectively ignore 3D objects when performing intersection tests. The following code
  /// example ensures that only 3D objects on layer `1` will be honored by raycaster.
  ///
  /// ```dart
  /// raycaster.layers.set(1);
  /// object.layers.enable(1);
  /// ```
  Layers layers = Layers();

  /// A parameter object that configures the raycasting. It has the structure:
  ///
  /// ```
  /// {
  /// 	'Mesh': {},
  /// 	'Line': {'threshold': 1},
  /// 	'LOD': {},
  /// 	'Points': {'threshold': 1},
  /// 	'Sprite': {}
  /// }
  /// ```
  ///
  /// Where `threshold` is the precision of the raycaster when intersecting objects, in world units. Maps keep the
  /// reference's keys and accept the extra ones objects may read (exception E-OBJECT):
  /// `raycaster.params['Line']!['threshold'] = 0.1`.
  Map<String, Map<String, Object?>> params = {
    'Mesh': {},
    'Line': {'threshold': 1.0},
    'LOD': {},
    'Points': {'threshold': 1.0},
    'Sprite': {},
  };

  /// Updates the ray with a new origin and direction by copying the values from the arguments.
  void set(Vector3 origin, Vector3 direction) {
    // direction is assumed to be normalized (for accurate distance calculations)

    ray.set(origin, direction);
  }

  /// Uses the given coordinates and camera to compute a new origin and direction for the internal ray.
  /// X and Y components should be between `-1` and `1`.
  void setFromCamera(Vector2 coords, Camera camera) {
    if (camera is PerspectiveCamera) {
      ray.origin.setFromMatrixPosition(camera.matrixWorld);
      ray.direction.set(coords.x, coords.y, 0.5).unproject(camera).sub(ray.origin).normalize();
      this.camera = camera;
    } else if (camera is OrthographicCamera) {
      // set origin in plane of camera
      ray.origin.set(coords.x, coords.y, camera.projectionMatrix.elements[14]).unproject(camera);
      ray.direction.set(0, 0, -1).transformDirection(camera.matrixWorld);
      this.camera = camera;
    } else {
      error('Raycaster: Unsupported camera type: ${camera.type}');
    }
  }

  /// Uses the given WebXR controller to compute a new origin and direction for the internal ray. Only the
  /// controller's world matrix is read, so any [Object3D] standing for a controller works.
  Raycaster setFromXRController(Object3D controller) {
    _raycasterMatrix.identity().extractRotation(controller.matrixWorld);

    ray.origin.setFromMatrixPosition(controller.matrixWorld);
    ray.direction.set(0, 0, -1).applyMatrix4(_raycasterMatrix);

    return this;
  }

  /// Checks all intersection between the ray and the object with or without the descendants
  /// (`recursive`, default `true`). Intersections are returned sorted by distance, closest first.
  ///
  /// `Raycaster` delegates to the `raycast()` method of the passed 3D object, when evaluating whether the
  /// ray intersects the object or not. This allows meshes to respond differently to ray casting than lines
  /// or points.
  ///
  /// Note that for meshes, faces must be pointed towards the origin of the ray in order to be detected;
  /// intersections of the ray passing through the back of a face will not be detected. To raycast against
  /// both faces of an object, you'll want to set `Material.side` to `DoubleSide`.
  ///
  /// Note that a ray hitting a triangle mesh exactly along an edge shared by two faces may be reported by
  /// both faces, resulting in two coincident intersections (identical point and distance) in the returned
  /// array.
  List<Intersection> intersectObject(Object3D object, [bool recursive = true, List<Intersection>? intersects]) {
    intersects ??= [];

    _raycasterIntersect(object, this, intersects, recursive);

    _raycasterSort(intersects);

    return intersects;
  }

  /// Checks all intersection between the ray and the objects with or without the descendants
  /// (`recursive`, default `true`). Intersections are returned sorted by distance, closest first.
  List<Intersection> intersectObjects(List<Object3D> objects, [bool recursive = true, List<Intersection>? intersects]) {
    intersects ??= [];

    for (var i = 0, l = objects.length; i < l; i++) {
      _raycasterIntersect(objects[i], this, intersects, recursive);
    }

    _raycasterSort(intersects);

    return intersects;
  }
}

/// `intersects.sort( ascSort )` with `ascSort` comparing `a.distance - b.distance`. JavaScript's sort is
/// stable and treats a NaN difference as equal; Dart's `List.sort` is not stable, so ties fall back to the
/// original position.
void _raycasterSort(List<Intersection> intersects) {
  final order = [for (var i = 0; i < intersects.length; i++) i];

  order.sort((a, b) {
    final d = intersects[a].distance - intersects[b].distance;

    if (d < 0) {
      return -1;
    }

    if (d > 0) {
      return 1;
    }

    return a - b;
  });

  final sorted = [for (final i in order) intersects[i]];
  intersects.setAll(0, sorted);
}

void _raycasterIntersect(Object3D object, Raycaster raycaster, List<Intersection> intersects, bool recursive) {
  var propagate = true;

  if (object.layers.test(raycaster.layers)) {
    final result = object.raycast(raycaster, intersects);

    if (result == false) {
      propagate = false;
    }
  }

  if (propagate == true && recursive == true) {
    final children = object.children;

    for (var i = 0, l = children.length; i < l; i++) {
      _raycasterIntersect(children[i], raycaster, intersects, true);
    }
  }
}
