part of '../../ent.dart';

final _lodV1 = Vector3();
final _lodV2 = Vector3();

/// One level of a [LOD]: the reference's `{ distance, hysteresis, object }` object (exception E-OBJECT).
class LODLevel {
  /// Creates a level record.
  LODLevel({required this.distance, required this.hysteresis, required this.object});

  /// The distance at which to display this level of detail.
  double distance;

  /// Threshold used to avoid flickering at LOD boundaries, as a fraction of distance.
  double hysteresis;

  /// The 3D object displayed at this level.
  Object3D object;
}

/// A component for providing a basic Level of Detail (LOD) mechanism.
///
/// Every LOD level is associated with an object, and rendering can be switched between them at the
/// distances specified. Typically you would create, say, three meshes, one for far away (low detail), one
/// for mid range (medium detail) and one for close up (high detail).
///
/// ```dart
/// final lod = LOD();
/// final material = MeshBasicMaterial();
///
/// // Create spheres with 3 levels of detail and create new LOD levels for them
/// for (var i = 0; i < 3; i++) {
/// 	final geometry = IcosahedronGeometry(10, 3 - i);
/// 	final mesh = Mesh(geometry, material);
/// 	lod.addLevel(mesh, i * 75.0);
/// }
///
/// scene.add(lod);
/// ```
class LOD extends Object3D {
  /// Constructs a new LOD.
  LOD() {
    type = 'LOD';
  }

  /// This flag can be used for type testing.
  bool get isLOD => true;

  /// The current LOD index.
  int _currentLevel = 0;

  /// This array holds the LOD levels. The reference defines it as a non-writable property; here it is `final`.
  final List<LODLevel> levels = [];

  /// Whether the LOD object is updated automatically by the renderer per frame or not. If set to `false`,
  /// you have to call [update] in the render loop by yourself.
  bool autoUpdate = true;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isLOD' => isLOD,
      'levels' => levels,
      'autoUpdate' => autoUpdate,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'autoUpdate':
        autoUpdate = value as bool;
      default:
        super[key] = value;
    }
  }

  /// Copies the values of the given LOD. The reference ignores `recursive` and copies the levels as clones of their
  /// objects.
  @override
  LOD copy(covariant LOD source, [bool recursive = true]) {
    super.copy(source, false);

    final levels = source.levels;

    for (var i = 0, l = levels.length; i < l; i++) {
      final level = levels[i];

      addLevel(level.object.clone(), level.distance, level.hysteresis);
    }

    autoUpdate = source.autoUpdate;

    return this;
  }

  @override
  LOD clone([bool recursive = true]) {
    return LOD().copy(this, recursive);
  }

  /// Adds a mesh that will display at a certain distance and greater. Typically the further away the
  /// distance, the lower the detail on the mesh. `distance` (default `0`) is the distance at which to
  /// display this level of detail; `hysteresis` (default `0`) a threshold used to avoid flickering at LOD
  /// boundaries, as a fraction of distance.
  LOD addLevel(Object3D object, [double distance = 0, double hysteresis = 0]) {
    distance = distance.abs();

    final levels = this.levels;

    int l;

    for (l = 0; l < levels.length; l++) {
      if (distance < levels[l].distance) {
        break;
      }
    }

    levels.insert(l, LODLevel(distance: distance, hysteresis: hysteresis, object: object));

    add(object);

    return this;
  }

  /// Removes an existing level, based on the distance from the camera. Returns `true` when the level has
  /// been removed. Otherwise `false`.
  bool removeLevel(double distance) {
    final levels = this.levels;

    for (var i = 0; i < levels.length; i++) {
      if (levels[i].distance == distance) {
        final removed = levels.removeAt(i);
        remove(removed.object);

        return true;
      }
    }

    return false;
  }

  /// Returns the currently active LOD level index.
  int getCurrentLevel() {
    return _currentLevel;
  }

  /// Returns a reference to the first 3D object that is greater than the given distance, or `null` when
  /// there are no levels.
  Object3D? getObjectForDistance(double distance) {
    final levels = this.levels;

    if (levels.isNotEmpty) {
      final l = levels.length;
      var i = 1;

      for (; i < l; i++) {
        var levelDistance = levels[i].distance;

        if (levels[i].object.visible) {
          levelDistance -= levelDistance * levels[i].hysteresis;
        }

        if (distance < levelDistance) {
          break;
        }
      }

      return levels[i - 1].object;
    }

    return null;
  }

  /// Computes intersection points between a casted ray and this LOD.
  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final levels = this.levels;

    if (levels.isNotEmpty) {
      _lodV1.setFromMatrixPosition(matrixWorld);

      final distance = raycaster.ray.origin.distanceTo(_lodV1);

      getObjectForDistance(distance)!.raycast(raycaster, intersects);
    }

    return null;
  }

  /// Updates the LOD by computing which LOD level should be visible according to the current distance of the given
  /// camera. The reference divides by `camera.zoom`, which only perspective and orthographic cameras have; for other
  /// cameras it reads `undefined` and the distance is NaN, as here.
  void update(Camera camera) {
    final levels = this.levels;

    if (levels.length > 1) {
      _lodV1.setFromMatrixPosition(camera.matrixWorld);
      _lodV2.setFromMatrixPosition(matrixWorld);

      final zoom = switch (camera) {
        PerspectiveCamera c => c.zoom,
        OrthographicCamera c => c.zoom,
        _ => double.nan,
      };

      final distance = _lodV1.distanceTo(_lodV2) / zoom;

      levels[0].object.visible = true;

      final l = levels.length;
      var i = 1;

      for (; i < l; i++) {
        var levelDistance = levels[i].distance;

        if (levels[i].object.visible) {
          levelDistance -= levelDistance * levels[i].hysteresis;
        }

        if (distance >= levelDistance) {
          levels[i - 1].object.visible = false;
          levels[i].object.visible = true;
        } else {
          break;
        }
      }

      _currentLevel = i - 1;

      for (; i < l; i++) {
        levels[i].object.visible = false;
      }
    }
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    final data = super.toJSON(meta);
    final object = data['object'] as Map<String, Object?>;

    object['autoUpdate'] = autoUpdate;

    object['levels'] = [
      for (final level in levels)
        {'object': level.object.uuid, 'distance': level.distance, 'hysteresis': level.hysteresis},
    ];

    return data;
  }
}
