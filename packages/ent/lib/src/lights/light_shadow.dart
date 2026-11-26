part of '../../ent.dart';

final _lightShadowProjScreenMatrix = Matrix4();
final _lightShadowLightPositionWorld = Vector3();
final _lightShadowLookTarget = Vector3();

/// Abstract base class for light shadow classes. These classes represent the shadow configuration for
/// different light types.
class LightShadow {
  /// Constructs a new light shadow with the light's view of the world, [camera].
  ///
  /// The reference allows a missing camera until [copy] sets one; the Dart constructor requires it (E-ARGS).
  LightShadow(this.camera);

  /// The light's view of the world.
  Camera camera;

  /// The intensity of the shadow. The default is `1`. Valid values are in the range `[0, 1]`.
  double intensity = 1;

  /// Shadow map bias, how much to add or subtract from the normalized depth when deciding whether a surface
  /// is in shadow. The default is `0`. Very tiny adjustments here (in the order of `0.0001`) may help reduce
  /// artifacts in shadows.
  double bias = 0;

  /// A node version of [bias]. Only supported with `WebGPURenderer`. If a bias node is defined, [bias] has
  /// no effect. The node system is not ported yet; the value is kept as an opaque object.
  Object? biasNode;

  /// Defines how much the position used to query the shadow map is offset along the object normal. The
  /// default is `0`. Increasing this value can be used to reduce shadow acne especially in large scenes
  /// where light shines onto geometry at a shallow angle. The cost is that shadows may appear distorted.
  double normalBias = 0;

  /// Setting this to values greater than 1 will blur the edges of the shadow. High values will cause
  /// unwanted banding effects in the shadows - a greater map size will allow for a higher value to be used
  /// here before these effects become visible. The property has no effect when the shadow map type is
  /// `BasicShadowMap`.
  double radius = 1;

  /// The amount of samples to use when blurring a VSM shadow map.
  int blurSamples = 8;

  /// Defines the width and height of the shadow map. Higher values give better quality shadows at the cost
  /// of computation time. Values must be powers of two.
  Vector2 mapSize = Vector2(512, 512);

  /// The type of shadow texture. The default is `UnsignedByteType`.
  int mapType = UnsignedByteType;

  /// The depth map generated using the internal camera; a location beyond a pixel's depth is in shadow.
  /// Computed internally during rendering.
  RenderTarget? map;

  /// The distribution map generated using the internal camera; an occlusion is calculated based on the
  /// distribution of depths. Computed internally during rendering.
  RenderTarget? mapPass;

  /// Model to shadow camera space, to compute location and depth in shadow map. This is computed internally
  /// during rendering.
  Matrix4 matrix = Matrix4();

  /// Enables automatic updates of the light's shadow. If you do not require dynamic lighting / shadows, you
  /// may set this to `false`.
  bool autoUpdate = true;

  /// When set to `true`, shadow maps will be updated in the next `render` call. If you have set
  /// [autoUpdate] to `false`, you will need to set this property to `true` and then make a render call to
  /// update the light's shadow.
  bool needsUpdate = false;

  final Frustum _frustum = Frustum();

  final Vector2 _frameExtents = Vector2(1, 1);

  final int _viewportCount = 1;

  final List<Vector4> _viewports = [Vector4(0, 0, 1, 1)];

  /// Used internally by the renderer to get the number of viewports that need to be rendered for this
  /// shadow.
  int getViewportCount() {
    return _viewportCount;
  }

  /// Used internally by the renderer to get the camera that renders the given viewport.
  Camera getCamera([int? viewportIndex]) {
    return camera;
  }

  /// Gets the shadow cameras frustum. Used internally by the renderer to cull objects.
  Frustum getFrustum() {
    return _frustum;
  }

  /// Update the matrices for the camera and shadow, used internally by the renderer. The [light] must have a `target`
  /// (a [DirectionalLight] or a [SpotLight]), as the reference reads `light.target`.
  void updateMatrices(Light light) {
    final shadowCamera = camera;
    _lightShadowLightPositionWorld.setFromMatrixPosition(light.matrixWorld);
    shadowCamera.position.copy(_lightShadowLightPositionWorld);

    _lightShadowLookTarget.setFromMatrixPosition(_lightShadowTarget(light).matrixWorld);
    shadowCamera.lookAt(_lightShadowLookTarget);
    shadowCamera.updateMatrixWorld();
    _updateMatrix(shadowCamera, matrix, _frustum);
  }

  /// For tests: [_updateMatrix], whose [viewport] path the renderers take (PointLightShadow's faces).
  @visibleForTesting
  void updateMatrix(Camera shadowCamera, Matrix4 shadowMatrix, Frustum frustum, [Vector4? viewport]) {
    _updateMatrix(shadowCamera, shadowMatrix, frustum, viewport);
  }

  /// Updates a shadow projection matrix and its corresponding frustum.
  void _updateMatrix(Camera shadowCamera, Matrix4 shadowMatrix, Frustum frustum, [Vector4? viewport]) {
    _lightShadowProjScreenMatrix.multiplyMatrices(shadowCamera.projectionMatrix, shadowCamera.matrixWorldInverse);
    frustum.setFromProjectionMatrix(
      _lightShadowProjScreenMatrix,
      shadowCamera.coordinateSystem,
      shadowCamera.reversedDepth,
    );

    final frameExtents = _frameExtents;
    final scaleX = viewport != null ? viewport.z / frameExtents.x : 1.0;
    final scaleY = viewport != null ? viewport.w / frameExtents.y : 1.0;
    final offsetX = viewport != null ? viewport.x / frameExtents.x : 0.0;
    final offsetY = viewport != null ? viewport.y / frameExtents.y : 0.0;

    if (shadowCamera.coordinateSystem == WebGPUCoordinateSystem || shadowCamera.reversedDepth) {
      shadowMatrix.set(
        0.5 * scaleX,
        0.0,
        0.0,
        0.5 * scaleX + offsetX,
        0.0,
        0.5 * scaleY,
        0.0,
        0.5 * scaleY + offsetY,
        0.0,
        0.0,
        1.0,
        0.0, // Identity Z (preserving the correct [0, 1] range from the projection matrix)
        0.0,
        0.0,
        0.0,
        1.0,
      );
    } else {
      shadowMatrix.set(
        0.5 * scaleX,
        0.0,
        0.0,
        0.5 * scaleX + offsetX,
        0.0,
        0.5 * scaleY,
        0.0,
        0.5 * scaleY + offsetY,
        0.0,
        0.0,
        0.5,
        0.5,
        0.0,
        0.0,
        0.0,
        1.0,
      );
    }

    shadowMatrix.multiply(_lightShadowProjScreenMatrix);
  }

  /// Returns a viewport definition for the given viewport index.
  Vector4 getViewport(int viewportIndex) {
    return _viewports[viewportIndex];
  }

  /// Returns the frame extends.
  Vector2 getFrameExtents() {
    return _frameExtents;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  void dispose() {
    map?.dispose();
    mapPass?.dispose();
  }

  /// Copies the values of the given light shadow instance to this instance.
  LightShadow copy(LightShadow source) {
    camera = source.camera.clone();

    intensity = source.intensity;

    bias = source.bias;
    radius = source.radius;

    autoUpdate = source.autoUpdate;
    needsUpdate = source.needsUpdate;
    normalBias = source.normalBias;
    blurSamples = source.blurSamples;

    mapSize.copy(source.mapSize);
    mapType = source.mapType;

    biasNode = source.biasNode;

    return this;
  }

  /// Returns a new light shadow instance with copied values from this instance. The reference builds
  /// `new this.constructor()`; each Dart subclass overrides this method (E-CLONE).
  LightShadow clone() {
    return LightShadow(camera.clone()).copy(this);
  }

  /// Serializes the light shadow into JSON (a map, E-OBJECT).
  Map<String, Object?> toJSON() {
    final object = <String, Object?>{};

    object['intensity'] = intensity;
    object['bias'] = bias;
    object['normalBias'] = normalBias;
    object['radius'] = radius;
    object['blurSamples'] = blurSamples;
    object['mapSize'] = mapSize.toArray();
    object['mapType'] = mapType;

    // The reference calls `camera.toJSON( false )`: serialized as a non-root object, without metadata.
    final cameraJson = camera.toJSON(_lightShadowJsonLibrary())['object'] as Map<String, Object?>;
    cameraJson.remove('matrix');
    object['camera'] = cameraJson;

    return object;
  }

  /// Reads a property by its name, like `object[ name ]` in JavaScript; `null` for a name this class does not have
  /// (`undefined` in the reference). Used by [PropertyBinding] (exception E-PROPERTY).
  Object? operator [](String key) {
    return switch (key) {
      'camera' => camera,
      'intensity' => intensity,
      'bias' => bias,
      'biasNode' => biasNode,
      'normalBias' => normalBias,
      'radius' => radius,
      'blurSamples' => blurSamples,
      'mapSize' => mapSize,
      'mapType' => mapType,
      'map' => map,
      'mapPass' => mapPass,
      'matrix' => matrix,
      'autoUpdate' => autoUpdate,
      'needsUpdate' => needsUpdate,
      _ => null,
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'camera':
        camera = value as Camera;
      case 'intensity':
        intensity = _jsDouble(value);
      case 'bias':
        bias = _jsDouble(value);
      case 'biasNode':
        biasNode = value;
      case 'normalBias':
        normalBias = _jsDouble(value);
      case 'radius':
        radius = _jsDouble(value);
      case 'blurSamples':
        blurSamples = _jsInt(value);
      case 'mapSize':
        mapSize = value as Vector2;
      case 'mapType':
        mapType = _jsInt(value);
      case 'map':
        map = value as RenderTarget?;
      case 'mapPass':
        mapPass = value as RenderTarget?;
      case 'matrix':
        matrix = value as Matrix4;
      case 'autoUpdate':
        autoUpdate = value as bool;
      case 'needsUpdate':
        needsUpdate = value as bool;
      default:
        throw ArgumentError.value(key, 'key', 'LightShadow has no writable property');
    }
  }
}

/// The `target` that the reference reads duck-typed from a light in [LightShadow.updateMatrices].
Object3D _lightShadowTarget(Light light) {
  return switch (light) {
    DirectionalLight l => l.target,
    SpotLight l => l.target,
    _ => throw ArgumentError.value(light, 'light', 'has no target'),
  };
}

/// An empty serialization library, so that `toJSON` treats the camera as a non-root object.
Map<String, Object?> _lightShadowJsonLibrary() {
  return {
    'geometries': <String, Object?>{},
    'materials': <String, Object?>{},
    'textures': <String, Object?>{},
    'images': <String, Object?>{},
    'shapes': <String, Object?>{},
    'skeletons': <String, Object?>{},
    'animations': <String, Object?>{},
    'nodes': <String, Object?>{},
  };
}
