part of '../../ent.dart';

//
// Subclass branches of toJSON() (Scene, Mesh/Line/Points, InstancedMesh, BatchedMesh, SkinnedMesh, materials, morph
// targets) belong to classes outside core. They are added in place, at the marked positions, as
// `if (this is Mesh) { ... }` blocks when those classes are ported: the whole package is one library, so the branches
// can read the subclasses' fields directly, as the reference does with `this.isMesh`.

int _object3DId = 0;

final _object3dV1 = Vector3();
final _object3dQ1 = Quaternion();
final _object3dM1 = Matrix4();
final _object3dTarget = Vector3();

final _object3dPosition = Vector3();
final _object3dScale = Vector3();
final _object3dQuaternion = Quaternion();

final _object3dXAxis = Vector3(1, 0, 0);
final _object3dYAxis = Vector3(0, 1, 0);
final _object3dZAxis = Vector3(0, 0, 1);

/// Fires when the object has been added to its parent object.
final _object3dAddedEvent = Event('added');

/// Fires when the object has been removed from its parent object.
final _object3dRemovedEvent = Event('removed');

/// Fires when a new child object has been added.
final _object3dChildaddedEvent = Event('childadded', {'child': null});

/// Fires when a child object has been removed.
final _object3dChildremovedEvent = Event('childremoved', {'child': null});

/// The signature of [Object3D.onBeforeRender] and [Object3D.onAfterRender]: `(renderer, scene, camera,
/// geometry, material, group)`. Renderers and materials are not ported yet, so the parameters are untyped.
typedef Object3DRenderCallback = void Function(
  Object? renderer,
  Object? scene,
  Object? camera,
  Object? geometry,
  Object? material,
  Object? group,
);

/// The signature of [Object3D.onBeforeShadow] and [Object3D.onAfterShadow]: `(renderer, object, camera,
/// shadowCamera, geometry, depthMaterial, group)`.
typedef Object3DShadowCallback = void Function(
  Object? renderer,
  Object? object,
  Object? camera,
  Object? shadowCamera,
  Object? geometry,
  Object? depthMaterial,
  Object? group,
);

void _object3dRenderNoop(Object? a, Object? b, Object? c, Object? d, Object? e, Object? f) {}

void _object3dShadowNoop(Object? a, Object? b, Object? c, Object? d, Object? e, Object? f, Object? g) {}

/// `===` as the reference's `getObjectByProperty` uses it: value equality for numbers, strings and booleans, identity
/// for everything else.
bool _object3dStrictEquals(Object? a, Object? b) {
  if (a is num || a is String || a is bool) {
    return a == b;
  }

  return identical(a, b);
}

/// `JSON.parse( JSON.stringify( value ) )` for `userData`: maps and lists are copied deeply; NaN and
/// infinities become `null`, functions are dropped from maps and become `null` in lists, as JSON does.
/// Other objects are kept by reference (exception E-OBJECT).
Object? _object3dJsonCopy(Object? value) {
  if (value is double && !value.isFinite) {
    return null;
  }

  if (value is Map) {
    final copy = <String, Object?>{};

    for (final entry in value.entries) {
      if (entry.value is! Function) {
        copy['${entry.key}'] = _object3dJsonCopy(entry.value);
      }
    }

    return copy;
  }

  if (value is List) {
    return [for (final item in value) item is Function ? null : _object3dJsonCopy(item)];
  }

  return value;
}

/// This is the base class for most objects in the engine and provides a set of properties and methods for manipulating
/// objects in 3D space.
class Object3D extends EventDispatcher {
  /// Constructs a new 3D object.
  Object3D()
    : id = _object3DId++,
      up = Object3D.DEFAULT_UP.clone(),
      matrixAutoUpdate = Object3D.DEFAULT_MATRIX_AUTO_UPDATE,
      matrixWorldAutoUpdate = Object3D.DEFAULT_MATRIX_WORLD_AUTO_UPDATE {
    rotation._onChange(() => quaternion.setFromEuler(rotation, false));
    quaternion._onChange(() => rotation.setFromQuaternion(quaternion, null, false));
  }

  /// The default up direction for objects, also used as the default position for `DirectionalLight` and
  /// `HemisphereLight`.
  static final Vector3 DEFAULT_UP = Vector3(0, 1, 0);

  /// The default setting for [matrixAutoUpdate] for newly created 3D objects.
  static bool DEFAULT_MATRIX_AUTO_UPDATE = true;

  /// The default setting for [matrixWorldAutoUpdate] for newly created 3D objects.
  static bool DEFAULT_MATRIX_WORLD_AUTO_UPDATE = true;

  /// This flag can be used for type testing.
  bool get isObject3D => true;

  /// Whether this object is a camera; `lookAt()` orients cameras and lights the opposite way. The reference reads the
  /// subclass flag, which is `undefined` on other objects; here every object answers `false` unless a camera subclass
  /// overrides it (exception E-FLAGS).
  bool get isCamera => false;

  /// Whether this object is a light; see [isCamera].
  bool get isLight => false;

  /// The ID of the 3D object.
  final int id;

  /// The UUID of the 3D object.
  String uuid = MathUtils.generateUUID();

  /// The name of the 3D object.
  String name = '';

  /// The type property is used for detecting the object type in context of serialization/deserialization.
  String type = 'Object3D';

  /// A reference to the parent object.
  Object3D? parent;

  /// An array holding the child 3D objects of this instance.
  List<Object3D> children = [];

  /// Defines the `up` direction of the 3D object which influences the orientation via methods like
  /// [lookAt]. The default values for all 3D objects is defined by [Object3D.DEFAULT_UP].
  Vector3 up;

  /// Represents the object's local position.
  final Vector3 position = Vector3();

  /// Represents the object's local rotation as Euler angles, in radians.
  final Euler rotation = Euler();

  /// Represents the object's local rotation as Quaternions.
  final Quaternion quaternion = Quaternion();

  /// Represents the object's local scale.
  final Vector3 scale = Vector3(1, 1, 1);

  /// Represents the object's model-view matrix.
  final Matrix4 modelViewMatrix = Matrix4();

  /// Represents the object's normal matrix.
  final Matrix3 normalMatrix = Matrix3();

  /// Represents the object's transformation matrix in local space.
  Matrix4 matrix = Matrix4();

  /// Represents the object's transformation matrix in world space. If the 3D object has no parent, then
  /// it's identical to the local transformation matrix.
  Matrix4 matrixWorld = Matrix4();

  /// When set to `true`, the engine automatically computes the local matrix from position, rotation and
  /// scale every frame. If set to `false`, the app is responsible for recomputing the local matrix by
  /// calling `updateMatrix()`. The default values for all 3D objects is defined by
  /// [Object3D.DEFAULT_MATRIX_AUTO_UPDATE].
  bool matrixAutoUpdate;

  /// When set to `true`, the engine automatically computes the world matrix from the current local matrix
  /// and the object's transformation hierarchy. If set to `false`, the app is responsible for recomputing
  /// the world matrix by directly updating the `matrixWorld` property. The default values for all 3D
  /// objects is defined by [Object3D.DEFAULT_MATRIX_WORLD_AUTO_UPDATE].
  bool matrixWorldAutoUpdate; // checked by the renderer

  /// When set to `true`, it calculates the world matrix in that frame and resets this property to `false`.
  bool matrixWorldNeedsUpdate = false;

  /// The layer membership of the 3D object. The 3D object is only visible if it has at least one layer in
  /// common with the camera in use. This property can also be used to filter out unwanted objects in
  /// ray-intersection tests when using [Raycaster].
  Layers layers = Layers();

  /// When set to `true`, the 3D object gets rendered.
  bool visible = true;

  /// When set to `true`, the 3D object gets rendered into shadow maps.
  bool castShadow = false;

  /// When set to `true`, the 3D object is affected by shadows in the scene.
  bool receiveShadow = false;

  /// When set to `true`, the 3D object is honored by view frustum culling.
  bool frustumCulled = true;

  /// This value allows the default rendering order of scene graph objects to be overridden although opaque
  /// and transparent objects remain sorted independently. When this property is set for an instance of
  /// `Group`, all descendants objects will be sorted and rendered together. Sorting is from lowest to
  /// highest render order.
  int renderOrder = 0;

  /// An array holding the animation clips of the 3D object (`AnimationClip`, not ported yet).
  List<Object> animations = [];

  /// Custom depth material to be used when rendering to the depth map. Can only be used in context of meshes. When
  /// shadow-casting with a `DirectionalLight` or `SpotLight`, if you are modifying vertex positions in the vertex
  /// shader you must specify a custom depth material for proper shadows. Only relevant in context of the reference
  /// renderer. (A `Material`, not ported yet; `null` for `undefined`.)
  Object? customDepthMaterial;

  /// Same as [customDepthMaterial], but used with `PointLight`. Only relevant in context of the reference renderer.
  Object? customDistanceMaterial;

  /// Whether the 3D object is supposed to be static or not. If set to `true`, it means the 3D object is not
  /// going to be changed after the first render. This includes geometry and material settings. A static 3D
  /// object can be processed by the renderer slightly faster since certain state checks can be bypassed.
  /// Only relevant in context of `WebGPURenderer`.
  bool static = false;

  /// An object that can be used to store custom data about the 3D object. It should not hold references to
  /// functions as these will not be cloned.
  Map<String, Object?> userData = {};

  /// The pivot point for rotation and scale transformations. When set, rotation and scale are applied
  /// around this point instead of the object's origin.
  Vector3? pivot;

  /// A callback that is executed immediately before a 3D object is rendered to a shadow map.
  Object3DShadowCallback onBeforeShadow = _object3dShadowNoop;

  /// A callback that is executed immediately after a 3D object is rendered to a shadow map.
  Object3DShadowCallback onAfterShadow = _object3dShadowNoop;

  /// A callback that is executed immediately before a 3D object is rendered.
  Object3DRenderCallback onBeforeRender = _object3dRenderNoop;

  /// A callback that is executed immediately after a 3D object is rendered.
  Object3DRenderCallback onAfterRender = _object3dRenderNoop;

  /// Reads a property by its name, like `object[ name ]` in JavaScript; `null` for a name this class does not have
  /// (`undefined` in the reference). Used by [getObjectByProperty]; subclasses add their own properties and fall back
  /// to `super[key]` (exception E-PROPERTY).
  Object? operator [](String key) {
    return switch (key) {
      'isObject3D' => isObject3D,
      'isCamera' => isCamera,
      'isLight' => isLight,
      'id' => id,
      'uuid' => uuid,
      'name' => name,
      'type' => type,
      'parent' => parent,
      'children' => children,
      'up' => up,
      'position' => position,
      'rotation' => rotation,
      'quaternion' => quaternion,
      'scale' => scale,
      'modelViewMatrix' => modelViewMatrix,
      'normalMatrix' => normalMatrix,
      'matrix' => matrix,
      'matrixWorld' => matrixWorld,
      'matrixAutoUpdate' => matrixAutoUpdate,
      'matrixWorldAutoUpdate' => matrixWorldAutoUpdate,
      'matrixWorldNeedsUpdate' => matrixWorldNeedsUpdate,
      'layers' => layers,
      'visible' => visible,
      'castShadow' => castShadow,
      'receiveShadow' => receiveShadow,
      'frustumCulled' => frustumCulled,
      'renderOrder' => renderOrder,
      'animations' => animations,
      'customDepthMaterial' => customDepthMaterial,
      'customDistanceMaterial' => customDistanceMaterial,
      'static' => static,
      'userData' => userData,
      'pivot' => pivot,
      _ => null,
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the writable counterpart of
  /// `operator []`, used by [PropertyBinding] to animate properties such as `visible`. Read-only properties
  /// (`position`, `rotation`, `quaternion`, `scale`, `id`, ...) and unknown names throw an [ArgumentError]; subclasses
  /// add their own properties and fall back to `super[key] = value` (exception E-PROPERTY). Numbers are accepted for
  /// integer properties, as a JS number would be.
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'name':
        name = value as String;
      case 'type':
        type = value as String;
      case 'parent':
        parent = value as Object3D?;
      case 'children':
        children = value is List<Object3D> ? value : (value as List).cast<Object3D>();
      case 'up':
        up = value as Vector3;
      case 'matrix':
        matrix = value as Matrix4;
      case 'matrixWorld':
        matrixWorld = value as Matrix4;
      case 'matrixAutoUpdate':
        matrixAutoUpdate = value as bool;
      case 'matrixWorldAutoUpdate':
        matrixWorldAutoUpdate = value as bool;
      case 'matrixWorldNeedsUpdate':
        matrixWorldNeedsUpdate = value as bool;
      case 'layers':
        layers = value as Layers;
      case 'visible':
        visible = value as bool;
      case 'castShadow':
        castShadow = value as bool;
      case 'receiveShadow':
        receiveShadow = value as bool;
      case 'frustumCulled':
        frustumCulled = value as bool;
      case 'renderOrder':
        renderOrder = (value as num).toInt();
      case 'animations':
        animations = value is List<Object> ? value : (value as List).cast<Object>();
      case 'customDepthMaterial':
        customDepthMaterial = value;
      case 'customDistanceMaterial':
        customDistanceMaterial = value;
      case 'static':
        static = value as bool;
      case 'userData':
        userData = value as Map<String, Object?>;
      case 'pivot':
        pivot = value as Vector3?;
      default:
        throw ArgumentError.value(key, 'key', 'Object3D has no writable property');
    }
  }

  /// Applies the given transformation matrix to the object and updates the object's position, rotation and
  /// scale.
  void applyMatrix4(Matrix4 matrix) {
    if (matrixAutoUpdate) {
      updateMatrix();
    }

    this.matrix.premultiply(matrix);

    this.matrix.decompose(position, quaternion, scale);

    final pivot = this.pivot;

    if (pivot != null) {
      // the matrix maps the pivot to position + pivot, see updateMatrix()
      position.copy(pivot).applyMatrix4(this.matrix).sub(pivot);
    }
  }

  /// Applies a rotation represented by given the quaternion to the 3D object.
  Object3D applyQuaternion(Quaternion q) {
    quaternion.premultiply(q);

    return this;
  }

  /// Sets the given rotation represented as an axis/angle couple to the 3D object.
  void setRotationFromAxisAngle(Vector3 axis, double angle) {
    // assumes axis is normalized

    quaternion.setFromAxisAngle(axis, angle);
  }

  /// Sets the given rotation represented as Euler angles to the 3D object.
  void setRotationFromEuler(Euler euler) {
    quaternion.setFromEuler(euler, true);
  }

  /// Sets the given rotation represented as rotation matrix to the 3D object. The upper 3x3 of `m` must be
  /// a pure rotation matrix (i.e, unscaled).
  void setRotationFromMatrix(Matrix4 m) {
    // assumes the upper 3x3 of m is a pure rotation matrix (i.e, unscaled)

    quaternion.setFromRotationMatrix(m);
  }

  /// Sets the given rotation represented as a Quaternion to the 3D object.
  void setRotationFromQuaternion(Quaternion q) {
    // assumes q is normalized

    quaternion.copy(q);
  }

  /// Rotates the 3D object along an axis in local space.
  Object3D rotateOnAxis(Vector3 axis, double angle) {
    // rotate object on axis in object space
    // axis is assumed to be normalized

    _object3dQ1.setFromAxisAngle(axis, angle);

    quaternion.multiply(_object3dQ1);

    return this;
  }

  /// Rotates the 3D object along an axis in world space.
  Object3D rotateOnWorldAxis(Vector3 axis, double angle) {
    // rotate object on axis in world space
    // axis is assumed to be normalized
    // method assumes no rotated parent

    _object3dQ1.setFromAxisAngle(axis, angle);

    quaternion.premultiply(_object3dQ1);

    return this;
  }

  /// Rotates the 3D object around its X axis in local space.
  Object3D rotateX(double angle) {
    return rotateOnAxis(_object3dXAxis, angle);
  }

  /// Rotates the 3D object around its Y axis in local space.
  Object3D rotateY(double angle) {
    return rotateOnAxis(_object3dYAxis, angle);
  }

  /// Rotates the 3D object around its Z axis in local space.
  Object3D rotateZ(double angle) {
    return rotateOnAxis(_object3dZAxis, angle);
  }

  /// Translate the 3D object by a distance along the given axis in local space.
  Object3D translateOnAxis(Vector3 axis, double distance) {
    // translate object by distance along axis in object space
    // axis is assumed to be normalized

    _object3dV1.copy(axis).applyQuaternion(quaternion);

    position.add(_object3dV1.multiplyScalar(distance));

    return this;
  }

  /// Translate the 3D object by a distance along its X-axis in local space.
  Object3D translateX(double distance) {
    return translateOnAxis(_object3dXAxis, distance);
  }

  /// Translate the 3D object by a distance along its Y-axis in local space.
  Object3D translateY(double distance) {
    return translateOnAxis(_object3dYAxis, distance);
  }

  /// Translate the 3D object by a distance along its Z-axis in local space.
  Object3D translateZ(double distance) {
    return translateOnAxis(_object3dZAxis, distance);
  }

  /// Converts the given vector from this 3D object's local space to world space.
  Vector3 localToWorld(Vector3 vector) {
    updateWorldMatrix(true, false);

    return vector.applyMatrix4(matrixWorld);
  }

  /// Converts the given vector from this 3D object's world space to local space.
  Vector3 worldToLocal(Vector3 vector) {
    updateWorldMatrix(true, false);

    return vector.applyMatrix4(_object3dM1.copy(matrixWorld).invert());
  }

  /// Rotates the object to face a point in world space. This method does not support objects having
  /// non-uniformly-scaled parent(s).
  ///
  /// `x` is the target as a [Vector3], or its x coordinate with `y` and `z` (exception E-UNION).
  void lookAt(Object x, [double? y, double? z]) {
    // This method does not support objects having non-uniformly-scaled parent(s)

    if (x is Vector3) {
      _object3dTarget.copy(x);
    } else if (x is num) {
      // Missing coordinates are `undefined` in the reference, which turns the result into NaN.
      _object3dTarget.set(x.toDouble(), y ?? double.nan, z ?? double.nan);
    } else {
      throw ArgumentError.value(x, 'x', 'a Vector3 or a number');
    }

    final parent = this.parent;

    updateWorldMatrix(true, false);

    _object3dPosition.setFromMatrixPosition(matrixWorld);

    if (isCamera || isLight) {
      _object3dM1.lookAt(_object3dPosition, _object3dTarget, up);
    } else {
      _object3dM1.lookAt(_object3dTarget, _object3dPosition, up);
    }

    quaternion.setFromRotationMatrix(_object3dM1);

    if (parent != null) {
      _object3dM1.extractRotation(parent.matrixWorld);
      _object3dQ1.setFromRotationMatrix(_object3dM1);
      quaternion.premultiply(_object3dQ1.invert());
    }
  }

  /// Adds the given 3D object as a child to this 3D object. Any current parent on an object passed in here
  /// will be removed, since an object can have at most one parent.
  ///
  /// The reference accepts several objects at once (`add( a, b, c )`); Dart takes one per call:
  /// `object..add(a)..add(b)..add(c)` (exception E-VARIADIC).
  Object3D add(Object3D object) {
    if (identical(object, this)) {
      error("Object3D.add: object can't be added as a child of itself.", [object]);
      return this;
    }

    object.removeFromParent();
    object.parent = this;
    children.add(object);

    object.dispatchEvent(_object3dAddedEvent);

    _object3dChildaddedEvent['child'] = object;
    dispatchEvent(_object3dChildaddedEvent);
    _object3dChildaddedEvent['child'] = null;

    return this;
  }

  /// Removes the given 3D object as child from this 3D object. The reference accepts several objects at once; Dart
  /// takes one per call (exception E-VARIADIC).
  Object3D remove(Object3D object) {
    final index = children.indexOf(object);

    if (index != -1) {
      object.parent = null;
      children.removeAt(index);

      object.dispatchEvent(_object3dRemovedEvent);

      _object3dChildremovedEvent['child'] = object;
      dispatchEvent(_object3dChildremovedEvent);
      _object3dChildremovedEvent['child'] = null;
    }

    return this;
  }

  /// Removes this 3D object from its current parent.
  Object3D removeFromParent() {
    final parent = this.parent;

    if (parent != null) {
      parent.remove(this);
    }

    return this;
  }

  /// Removes all child objects.
  Object3D clear() {
    // The reference spreads a snapshot of the children into remove( ... ); removing them one by one from a copy gives
    // the same order of removals and events.
    for (final child in children.toList()) {
      remove(child);
    }

    return this;
  }

  /// Adds the given 3D object as a child of this 3D object, while maintaining the object's world transform.
  /// This method does not support scene graphs having non-uniformly-scaled nodes(s).
  Object3D attach(Object3D object) {
    // adds object as a child of this, while maintaining the object's world transform

    // Note: This method does not support scene graphs having non-uniformly-scaled nodes(s)

    updateWorldMatrix(true, false);

    _object3dM1.copy(matrixWorld).invert();

    final parent = object.parent;

    if (parent != null) {
      parent.updateWorldMatrix(true, false);

      _object3dM1.multiply(parent.matrixWorld);
    }

    object.applyMatrix4(_object3dM1);

    object.removeFromParent();
    object.parent = this;
    children.add(object);

    object.updateWorldMatrix(false, true);

    object.dispatchEvent(_object3dAddedEvent);

    _object3dChildaddedEvent['child'] = object;
    dispatchEvent(_object3dChildaddedEvent);
    _object3dChildaddedEvent['child'] = null;

    return this;
  }

  /// Searches through the 3D object and its children, starting with the 3D object itself, and returns the first with a
  /// matching ID; `null` if none (`undefined` in the reference).
  Object3D? getObjectById(int id) {
    return getObjectByProperty('id', id);
  }

  /// Searches through the 3D object and its children, starting with the 3D object itself, and returns the
  /// first with a matching name; `null` if none.
  Object3D? getObjectByName(String name) {
    return getObjectByProperty('name', name);
  }

  /// Searches through the 3D object and its children, starting with the 3D object itself, and returns the
  /// first with a matching property value; `null` if none. Properties are read with [operator []].
  Object3D? getObjectByProperty(String name, Object? value) {
    if (_object3dStrictEquals(this[name], value)) {
      return this;
    }

    for (var i = 0, l = children.length; i < l; i++) {
      final child = children[i];
      final object = child.getObjectByProperty(name, value);

      if (object != null) {
        return object;
      }
    }

    return null;
  }

  /// Searches through the 3D object and its children, starting with the 3D object itself, and returns all
  /// 3D objects with a matching property value.
  List<Object3D> getObjectsByProperty(String name, Object? value, [List<Object3D>? result]) {
    result ??= [];

    if (_object3dStrictEquals(this[name], value)) {
      result.add(this);
    }

    final children = this.children;

    for (var i = 0, l = children.length; i < l; i++) {
      children[i].getObjectsByProperty(name, value, result);
    }

    return result;
  }

  /// Returns a vector representing the position of the 3D object in world space.
  Vector3 getWorldPosition(Vector3 target) {
    updateWorldMatrix(true, false);

    return target.setFromMatrixPosition(matrixWorld);
  }

  /// Returns a Quaternion representing the position of the 3D object in world space.
  Quaternion getWorldQuaternion(Quaternion target) {
    updateWorldMatrix(true, false);

    matrixWorld.decompose(_object3dPosition, target, _object3dScale);

    return target;
  }

  /// Returns a vector representing the scale of the 3D object in world space.
  Vector3 getWorldScale(Vector3 target) {
    updateWorldMatrix(true, false);

    matrixWorld.decompose(_object3dPosition, _object3dQuaternion, target);

    return target;
  }

  /// Returns a vector representing the ("look") direction of the 3D object in world space.
  Vector3 getWorldDirection(Vector3 target) {
    updateWorldMatrix(true, false);

    final e = matrixWorld.elements;

    return target.set(e[8], e[9], e[10]).normalize();
  }

  /// Abstract method to get intersections between a casted ray and this 3D object. Renderable 3D objects
  /// such as `Mesh`, `Line` or `Points` implement this method in order to use raycasting.
  ///
  /// Returning `false` stops [Raycaster] from descending into the children; the default returns `null` (`undefined` in
  /// the reference).
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    return null;
  }

  /// Returns `true` if this 3D object intersects the given frustum. Renderable 3D objects such as `Mesh`,
  /// `Line` or `Points` override this method in order to use frustum culling. The default implementation
  /// always returns `true`.
  bool intersectsFrustum(Frustum frustum) {
    return true;
  }

  /// Executes the callback on this 3D object and all descendants.
  ///
  /// Note: Modifying the scene graph inside the callback is discouraged.
  void traverse(void Function(Object3D object) callback) {
    callback(this);

    final children = this.children;

    for (var i = 0, l = children.length; i < l; i++) {
      children[i].traverse(callback);
    }
  }

  /// Like [traverse], but the callback will only be executed for visible 3D objects. Descendants of
  /// invisible 3D objects are not traversed.
  ///
  /// Note: Modifying the scene graph inside the callback is discouraged.
  void traverseVisible(void Function(Object3D object) callback) {
    if (visible == false) {
      return;
    }

    callback(this);

    final children = this.children;

    for (var i = 0, l = children.length; i < l; i++) {
      children[i].traverseVisible(callback);
    }
  }

  /// Like [traverse], but the callback will only be executed for all ancestors.
  ///
  /// Note: Modifying the scene graph inside the callback is discouraged.
  void traverseAncestors(void Function(Object3D object) callback) {
    final parent = this.parent;

    if (parent != null) {
      callback(parent);

      parent.traverseAncestors(callback);
    }
  }

  /// Updates the transformation matrix in local space by computing it from the current position, rotation
  /// and scale values.
  void updateMatrix() {
    matrix.compose(position, quaternion, scale);

    final pivot = this.pivot;

    if (pivot != null) {
      final px = pivot.x, py = pivot.y, pz = pivot.z;
      final te = matrix.elements;

      te[12] += px - te[0] * px - te[4] * py - te[8] * pz;
      te[13] += py - te[1] * px - te[5] * py - te[9] * pz;
      te[14] += pz - te[2] * px - te[6] * py - te[10] * pz;
    }

    matrixWorldNeedsUpdate = true;
  }

  /// Updates the transformation matrix in world space of this 3D objects and its descendants.
  ///
  /// To ensure correct results, this method also recomputes the 3D object's transformation matrix in local
  /// space. The computation of the local and world matrix can be controlled with the [matrixAutoUpdate] and
  /// [matrixWorldAutoUpdate] flags which are both `true` by default. Set these flags to `false` if you need
  /// more control over the update matrix process. `force` updates the world matrix even when
  /// [matrixWorldNeedsUpdate] is `false`.
  void updateMatrixWorld([bool? force]) {
    if (matrixAutoUpdate) {
      updateMatrix();
    }

    if (matrixWorldNeedsUpdate || force == true) {
      if (matrixWorldAutoUpdate == true) {
        final parent = this.parent;

        if (parent == null) {
          matrixWorld.copy(matrix);
        } else {
          matrixWorld.multiplyMatrices(parent.matrixWorld, matrix);
        }
      }

      matrixWorldNeedsUpdate = false;

      force = true;
    }

    // make sure descendants are updated if required

    final children = this.children;

    for (var i = 0, l = children.length; i < l; i++) {
      final child = children[i];

      child.updateMatrixWorld(force);
    }
  }

  /// An alternative version of [updateMatrixWorld] with more control over the update of ancestor and
  /// descendant nodes. `force` updates the world matrix even when [matrixWorldNeedsUpdate] is `false`.
  ///
  /// `updateParents` and `updateChildren` are optional as in the reference, where a missing value counts as false.
  void updateWorldMatrix([bool? updateParents, bool? updateChildren, bool force = false]) {
    final parent = this.parent;

    if (updateParents == true && parent != null) {
      parent.updateWorldMatrix(true, false);
    }

    if (matrixAutoUpdate) {
      updateMatrix();
    }

    if (matrixWorldNeedsUpdate || force) {
      if (matrixWorldAutoUpdate == true) {
        if (parent == null) {
          matrixWorld.copy(matrix);
        } else {
          matrixWorld.multiplyMatrices(parent.matrixWorld, matrix);
        }
      }

      matrixWorldNeedsUpdate = false;

      force = true;
    }

    // make sure descendants are updated

    if (updateChildren == true) {
      final children = this.children;

      for (var i = 0, l = children.length; i < l; i++) {
        final child = children[i];

        child.updateWorldMatrix(false, true, force);
      }
    }
  }

  /// Serializes the 3D object into JSON.
  ///
  /// `meta` collects shared geometries, materials, textures, ... while a hierarchy is serialized; leave it out for the
  /// root object (the reference also accepts the key string `JSON.stringify` passes).
  Map<String, Object?> toJSON([Map<String, Object?>? meta]) {
    // meta is a string when called from JSON.stringify
    final isRootObject = meta == null;

    final output = <String, Object?>{};

    // meta is a hash used to collect geometries, materials.
    // not providing it implies that this is the root object
    // being serialized.
    final library =
        meta ??
        <String, Object?>{
          'geometries': <String, Object?>{},
          'materials': <String, Object?>{},
          'textures': <String, Object?>{},
          'images': <String, Object?>{},
          'shapes': <String, Object?>{},
          'skeletons': <String, Object?>{},
          'animations': <String, Object?>{},
          'nodes': <String, Object?>{},
        };

    if (isRootObject) {
      output['metadata'] = <String, Object?>{'version': 4.7, 'type': 'Object', 'generator': 'Object3D.toJSON'};
    }

    // standard Object3D serialization

    final object = <String, Object?>{};

    object['uuid'] = uuid;
    object['type'] = type;

    object['name'] = name;
    object['castShadow'] = castShadow;
    object['receiveShadow'] = receiveShadow;
    object['visible'] = visible;
    object['frustumCulled'] = frustumCulled;
    object['renderOrder'] = renderOrder;
    object['static'] = static;
    object['matrixAutoUpdate'] = matrixAutoUpdate;

    if (userData.isNotEmpty) {
      object['userData'] = userData;
    }

    object['layers'] = layers.mask;
    object['matrix'] = matrix.toArray();
    object['up'] = up.toArray();

    final pivot = this.pivot;

    if (pivot != null) {
      object['pivot'] = pivot.toArray();
    }

    final (morphTargetDictionary, morphTargetInfluences) = switch (this) {
      final Mesh mesh => (mesh.morphTargetDictionary, mesh.morphTargetInfluences),
      final Line line => (line.morphTargetDictionary, line.morphTargetInfluences),
      final Points points => (points.morphTargetDictionary, points.morphTargetInfluences),
      _ => (null, null),
    };

    if (morphTargetDictionary != null) {
      object['morphTargetDictionary'] = Map.of(morphTargetDictionary);
    }

    if (morphTargetInfluences != null) {
      object['morphTargetInfluences'] = List.of(morphTargetInfluences);
    }

    // object specific properties

    final self = this;

    if (self is InstancedMesh) {
      object['type'] = 'InstancedMesh';
      object['count'] = self.count;
      object['instanceMatrix'] = self.instanceMatrix.toJSON();

      if (self.instanceColor != null) {
        object['instanceColor'] = self.instanceColor!.toJSON();
      }
    }

    if (self is BatchedMesh) {
      object['type'] = 'BatchedMesh';
      object['perObjectFrustumCulled'] = self.perObjectFrustumCulled;
      object['sortObjects'] = self.sortObjects;

      // The reference also writes `drawRanges` and `reservedRanges` from `_drawRanges` and `_reservedRanges`, which its
      // BatchedMesh no longer has: both are `undefined`, which JSON drops

      object['geometryInfo'] = self._geometryInfo.map((info) => info.toJSON()).toList();
      object['instanceInfo'] = self._instanceInfo.map((info) => info.toJSON()).toList();

      object['availableInstanceIds'] = self._availableInstanceIds.toList();
      object['availableGeometryIds'] = self._availableGeometryIds.toList();

      object['nextIndexStart'] = self._nextIndexStart;
      object['nextVertexStart'] = self._nextVertexStart;
      object['geometryCount'] = self._geometryCount;

      object['maxInstanceCount'] = self._maxInstanceCount;
      object['maxVertexCount'] = self._maxVertexCount;
      object['maxIndexCount'] = self._maxIndexCount;

      object['geometryInitialized'] = self._geometryInitialized;

      object['matricesTexture'] = self._matricesTexture!.toJSON(library);

      object['indirectTexture'] = self._indirectTexture!.toJSON(library);

      if (self._colorsTexture != null) {
        object['colorsTexture'] = self._colorsTexture!.toJSON(library);
      }

      if (self.boundingSphere != null) {
        object['boundingSphere'] = self.boundingSphere!.toJSON();
      }

      if (self.boundingBox != null) {
        object['boundingBox'] = self.boundingBox!.toJSON();
      }
    }

    //

    String serialize(String name, Object element) {
      final cache = library[name] as Map<String, Object?>;

      // Shared resources are duck-typed in the reference: anything with a `uuid` and a `toJSON( meta )`. JS ignores the
      // argument where `toJSON()` takes none; Dart does not, so those are called without it.
      final dynamic resource = element;
      final uuid = resource.uuid as String;

      if (cache[uuid] == null) {
        final takesMeta = element is! BufferGeometry && element is! Curve && element is! AnimationClip;
        cache[uuid] = takesMeta ? resource.toJSON(library) : resource.toJSON();
      }

      return uuid;
    }

    if (self is Scene) {
      final background = self.background;

      if (background != null) {
        if (background is Color) {
          object['background'] = background.toJSON();
        } else if (background is Texture) {
          object['background'] = background.toJSON(library)['uuid'];
        }
      }

      final environment = self.environment;

      if (environment != null && environment.isRenderTargetTexture != true) {
        object['environment'] = environment.toJSON(library)['uuid'];
      }
    } else if (self is Mesh || self is Line || self is Points) {
      final geometry = switch (self) {
        final Mesh mesh => mesh.geometry,
        final Line line => line.geometry,
        final Points points => points.geometry,
        _ => throw StateError('unreachable'),
      };

      object['geometry'] = serialize('geometries', geometry);

      final parameters = geometry.parameters;

      if (parameters != null && parameters['shapes'] != null) {
        final shapes = parameters['shapes'];

        if (shapes is List) {
          for (var i = 0, l = shapes.length; i < l; i++) {
            final shape = shapes[i] as Object;

            serialize('shapes', shape);
          }
        } else {
          serialize('shapes', shapes!);
        }
      }
    }

    if (self is SkinnedMesh) {
      object['bindMode'] = self.bindMode;
      object['bindMatrix'] = self.bindMatrix.toArray();

      if (self.skeleton != null) {
        serialize('skeletons', self.skeleton!);

        object['skeleton'] = self.skeleton!.uuid;
      }
    }

    final Object? material = switch (self) {
      final Mesh mesh => mesh.material,
      final Line line => line.material,
      final Points points => points.material,
      final Sprite sprite => sprite.material,
      _ => null,
    };

    if (material != null) {
      if (material is List) {
        final uuids = <Object?>[];

        for (var i = 0, l = material.length; i < l; i++) {
          uuids.add(serialize('materials', material[i] as Object));
        }

        object['material'] = uuids;
      } else {
        object['material'] = serialize('materials', material);
      }
    }

    //

    if (children.isNotEmpty) {
      final list = <Object?>[];
      object['children'] = list;

      for (var i = 0; i < children.length; i++) {
        list.add(children[i].toJSON(library)['object']);
      }
    }

    //

    if (animations.isNotEmpty) {
      final list = <Object?>[];
      object['animations'] = list;

      for (var i = 0; i < animations.length; i++) {
        final animation = animations[i];

        list.add(serialize('animations', animation));
      }
    }

    if (isRootObject) {
      final geometries = _object3dExtractFromCache(library['geometries']);
      final materials = _object3dExtractFromCache(library['materials']);
      final textures = _object3dExtractFromCache(library['textures']);
      final images = _object3dExtractFromCache(library['images']);
      final shapes = _object3dExtractFromCache(library['shapes']);
      final skeletons = _object3dExtractFromCache(library['skeletons']);
      final animations = _object3dExtractFromCache(library['animations']);
      final nodes = _object3dExtractFromCache(library['nodes']);

      if (geometries.isNotEmpty) {
        output['geometries'] = geometries;
      }

      if (materials.isNotEmpty) {
        output['materials'] = materials;
      }

      if (textures.isNotEmpty) {
        output['textures'] = textures;
      }

      if (images.isNotEmpty) {
        output['images'] = images;
      }

      if (shapes.isNotEmpty) {
        output['shapes'] = shapes;
      }

      if (skeletons.isNotEmpty) {
        output['skeletons'] = skeletons;
      }

      if (animations.isNotEmpty) {
        output['animations'] = animations;
      }

      if (nodes.isNotEmpty) {
        output['nodes'] = nodes;
      }
    }

    output['object'] = object;

    return output;
  }

  /// Returns a new 3D object with copied values from this instance; `recursive` (default `true`) also
  /// clones the descendants. Subclasses override it to return their own type (exception E-CLONE).
  Object3D clone([bool recursive = true]) {
    return Object3D().copy(this, recursive);
  }

  /// Copies the values of the given 3D object to this instance; `recursive` (default `true`) also copies
  /// the descendants, as clones.
  Object3D copy(covariant Object3D source, [bool recursive = true]) {
    name = source.name;

    up.copy(source.up);

    position.copy(source.position);
    rotation.order = source.rotation.order;
    quaternion.copy(source.quaternion);
    scale.copy(source.scale);

    pivot = source.pivot?.clone();

    matrix.copy(source.matrix);
    matrixWorld.copy(source.matrixWorld);

    matrixAutoUpdate = source.matrixAutoUpdate;

    matrixWorldAutoUpdate = source.matrixWorldAutoUpdate;
    matrixWorldNeedsUpdate = source.matrixWorldNeedsUpdate;

    layers.mask = source.layers.mask;
    visible = source.visible;

    castShadow = source.castShadow;
    receiveShadow = source.receiveShadow;

    frustumCulled = source.frustumCulled;
    renderOrder = source.renderOrder;

    static = source.static;

    animations = source.animations.toList();

    userData = _object3dJsonCopy(source.userData) as Map<String, Object?>;

    if (recursive == true) {
      for (var i = 0; i < source.children.length; i++) {
        final child = source.children[i];
        add(child.clone());
      }
    }

    return this;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  ///
  /// Geometries, materials and textures are potentially shared with other 3D objects and must be disposed
  /// of separately.
  void dispose() {
    // Fires when the 3D object has been disposed of.
    dispatchEvent(Event('dispose'));
  }
}

/// Extracts data from the cache hash, removes the metadata on each item and returns them as a list.
List<Object?> _object3dExtractFromCache(Object? cache) {
  final values = <Object?>[];

  for (final data in (cache as Map<String, Object?>).values) {
    if (data is Map) {
      data.remove('metadata');
    }

    values.add(data);
  }

  return values;
}
