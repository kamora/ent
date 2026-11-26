part of '../../ent.dart';

final _cameraPosition = Vector3();
final _cameraQuaternion = Quaternion();
final _cameraScale = Vector3();

/// Abstract base class for cameras. This class should always be inherited when you build a new camera.
///
/// The reference marks the class `@abstract` but it can be instantiated, and so can this port.
class Camera extends Object3D {
  /// Constructs a new camera.
  Camera() {
    type = 'Camera';
  }

  /// This flag can be used for type testing.
  @override
  bool get isCamera => true;

  /// The inverse of the camera's world matrix.
  Matrix4 matrixWorldInverse = Matrix4();

  /// The camera's projection matrix.
  Matrix4 projectionMatrix = Matrix4();

  /// The inverse of the camera's projection matrix.
  Matrix4 projectionMatrixInverse = Matrix4();

  /// The coordinate system in which the camera is used ([WebGLCoordinateSystem] or
  /// [WebGPUCoordinateSystem]).
  int coordinateSystem = WebGLCoordinateSystem;

  // Set by the renderers, which are not ported yet.
  bool _reversedDepth = false;

  /// The flag that indicates whether the camera uses a reversed depth buffer.
  bool get reversedDepth {
    return _reversedDepth;
  }

  /// For tests: sets [reversedDepth], as a renderer with a reversed depth buffer does.
  @visibleForTesting
  set reversedDepth(bool value) => _reversedDepth = value;

  @override
  Camera copy(covariant Camera source, [bool? recursive]) {
    super.copy(source, recursive ?? true);

    matrixWorldInverse.copy(source.matrixWorldInverse);

    projectionMatrix.copy(source.projectionMatrix);
    projectionMatrixInverse.copy(source.projectionMatrixInverse);

    coordinateSystem = source.coordinateSystem;

    return this;
  }

  /// Returns a vector representing the ("look") direction of the 3D object in world space.
  ///
  /// This method is overwritten since cameras have a different forward vector compared to other 3D objects.
  /// A camera looks down its local, negative z-axis by default.
  @override
  Vector3 getWorldDirection(Vector3 target) {
    return super.getWorldDirection(target).negate();
  }

  @override
  void updateMatrixWorld([bool? force]) {
    super.updateMatrixWorld(force ?? false);

    // exclude scale from view matrix to be glTF conform

    matrixWorld.decompose(_cameraPosition, _cameraQuaternion, _cameraScale);

    if (_cameraScale.x == 1 && _cameraScale.y == 1 && _cameraScale.z == 1) {
      matrixWorldInverse.copy(matrixWorld).invert();
    } else {
      matrixWorldInverse.compose(_cameraPosition, _cameraQuaternion, _cameraScale.set(1, 1, 1)).invert();
    }
  }

  @override
  void updateWorldMatrix([bool? updateParents, bool? updateChildren, bool? force]) {
    super.updateWorldMatrix(updateParents ?? false, updateChildren ?? false, force ?? false);

    // exclude scale from view matrix to be glTF conform

    matrixWorld.decompose(_cameraPosition, _cameraQuaternion, _cameraScale);

    if (_cameraScale.x == 1 && _cameraScale.y == 1 && _cameraScale.z == 1) {
      matrixWorldInverse.copy(matrixWorld).invert();
    } else {
      matrixWorldInverse.compose(_cameraPosition, _cameraQuaternion, _cameraScale.set(1, 1, 1)).invert();
    }
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'matrixWorldInverse' => matrixWorldInverse,
      'projectionMatrix' => projectionMatrix,
      'projectionMatrixInverse' => projectionMatrixInverse,
      'coordinateSystem' => coordinateSystem,
      'reversedDepth' => reversedDepth,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'matrixWorldInverse':
        matrixWorldInverse = value as Matrix4;
      case 'projectionMatrix':
        projectionMatrix = value as Matrix4;
      case 'projectionMatrixInverse':
        projectionMatrixInverse = value as Matrix4;
      case 'coordinateSystem':
        coordinateSystem = _jsInt(value);
      default:
        super[key] = value;
    }
  }

  /// Returns a new camera with copied values from this instance. The reference builds `new this.constructor()`; each
  /// Dart subclass overrides this method (E-CLONE).
  @override
  Camera clone([bool? recursive]) {
    return Camera().copy(this);
  }
}
