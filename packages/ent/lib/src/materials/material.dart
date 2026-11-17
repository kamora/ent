part of '../../ent.dart';

// The reference's Material reads and writes subclass properties by name (`this[ key ]` in setValues, `this.roughness`
// in toJSON and fromJSON). Dart has no dynamic properties, so every material class lists its properties in
// `_getValue`/`_setValue`, overriding and falling back to `super` (exception E-PROPERTY), as Texture does.

int _materialId = 0;

/// What `this[ key ]` reads for a key that is not a property of the material: the reference's `undefined`.
const Object _materialUndefined = Object();

/// The signature of [Material.onBeforeRender]: `(renderer, scene, camera, geometry, object, group)`.
/// Renderers are not ported yet, so the parameters are untyped.
typedef MaterialRenderCallback = void Function(
  Object? renderer,
  Object? scene,
  Object? camera,
  Object? geometry,
  Object? object,
  Object? group,
);

void _materialRenderNoop(Object? a, Object? b, Object? c, Object? d, Object? e, Object? f) {}

double _materialDouble(Object? value) => (value as num).toDouble();

int _materialInt(Object? value) => (value as num).toInt();

int? _materialIntOrNull(Object? value) => value == null ? null : (value as num).toInt();

/// Abstract base class for materials.
///
/// Materials define the appearance of renderable 3D objects.
class Material extends EventDispatcher {
  /// Constructs a new material.
  Material();

  /// This flag can be used for type testing.
  bool get isMaterial => true;

  /// The ID of the material.
  final int id = _materialId++;

  /// The UUID of the material.
  String uuid = MathUtils.generateUUID();

  /// The name of the material.
  String name = '';

  /// The type property is used for detecting the object type in context of serialization/deserialization.
  String type = 'Material';

  /// Defines the blending type of the material.
  ///
  /// It must be set to `CustomBlending` if custom blending properties like [blendSrc], [blendDst] or
  /// [blendEquation] should have any effect.
  int blending = NormalBlending;

  /// Defines which side of faces will be rendered - front, back or both.
  int side = FrontSide;

  /// If set to `true`, vertex colors should be used.
  ///
  /// The engine supports RGB and RGBA vertex colors depending on whether a three (RGB) or four (RGBA)
  /// component color buffer attribute is used.
  bool vertexColors = false;

  /// Defines how transparent the material is. A value of `0.0` indicates fully transparent, `1.0` is fully
  /// opaque.
  ///
  /// If the [transparent] is not set to `true`, the material will remain fully opaque and this value will
  /// only affect its color.
  double opacity = 1;

  /// Defines whether this material is transparent. This has an effect on rendering as transparent objects
  /// need special treatment and are rendered after non-transparent objects.
  ///
  /// When set to true, the extent to which the material is transparent is controlled by [opacity].
  bool transparent = false;

  /// Enables alpha hashed transparency, an alternative to [transparent] or [alphaTest]. The material will
  /// not be rendered if opacity is lower than a random threshold. Randomization introduces some grain or
  /// noise, but approximates alpha blending without the associated problems of sorting. Using TAA can
  /// reduce the resulting noise.
  bool alphaHash = false;

  /// Defines the blending source factor.
  int blendSrc = SrcAlphaFactor;

  /// Defines the blending destination factor.
  int blendDst = OneMinusSrcAlphaFactor;

  /// Defines the blending equation.
  int blendEquation = AddEquation;

  /// Defines the blending source alpha factor.
  int? blendSrcAlpha;

  /// Defines the blending destination alpha factor.
  int? blendDstAlpha;

  /// Defines the blending equation of the alpha channel.
  int? blendEquationAlpha;

  /// Represents the RGB values of the constant blend color.
  ///
  /// This property has only an effect when using custom blending with `ConstantColor` or
  /// `OneMinusConstantColor`.
  Color blendColor = Color(0, 0, 0);

  /// Represents the alpha value of the constant blend color.
  ///
  /// This property has only an effect when using custom blending with `ConstantAlpha` or
  /// `OneMinusConstantAlpha`.
  double blendAlpha = 0;

  /// Defines the depth function.
  int depthFunc = LessEqualDepth;

  /// Whether to have depth test enabled when rendering this material. When the depth test is disabled, the
  /// depth write will also be implicitly disabled.
  bool depthTest = true;

  /// Whether rendering this material has any effect on the depth buffer.
  ///
  /// When drawing 2D overlays it can be useful to disable the depth writing in order to layer several
  /// things together without creating z-index artifacts.
  bool depthWrite = true;

  /// The bit mask to use when writing to the stencil buffer.
  int stencilWriteMask = 0xff;

  /// The stencil comparison function to use.
  int stencilFunc = AlwaysStencilFunc;

  /// The value to use when performing stencil comparisons or stencil operations.
  int stencilRef = 0;

  /// The bit mask to use when comparing against the stencil buffer.
  int stencilFuncMask = 0xff;

  /// Which stencil operation to perform when the comparison function returns `false`.
  int stencilFail = KeepStencilOp;

  /// Which stencil operation to perform when the comparison function returns `true` but the depth test
  /// fails.
  int stencilZFail = KeepStencilOp;

  /// Which stencil operation to perform when the comparison function returns `true` and the depth test
  /// passes.
  int stencilZPass = KeepStencilOp;

  /// Whether stencil operations are performed against the stencil buffer. In order to perform writes or
  /// comparisons against the stencil buffer this value must be `true`.
  bool stencilWrite = false;

  /// User-defined clipping planes specified as [Plane] objects in world space. These planes apply to the objects this
  /// material is attached to. Points in space whose signed distance to the plane is negative are clipped (not
  /// rendered). The reference renderer requires its `localClippingEnabled` to be `true` for this.
  List<Plane>? clippingPlanes;

  /// Changes the behavior of clipping planes so that only their intersection is clipped, rather than their
  /// union.
  bool clipIntersection = false;

  /// Defines whether to clip shadows according to the clipping planes specified on this material.
  bool clipShadows = false;

  /// Defines which side of faces cast shadows. If `null`, the side casting shadows is determined as
  /// follows:
  ///
  /// - When [side] is set to `FrontSide`, the back side cast shadows.
  /// - When [side] is set to `BackSide`, the front side cast shadows.
  /// - When [side] is set to `DoubleSide`, both sides cast shadows.
  int? shadowSide;

  /// Whether to render the material's color.
  ///
  /// This can be used in conjunction with [Object3D.renderOrder] to create invisible objects that occlude
  /// other objects.
  bool colorWrite = true;

  /// Whether to use polygon offset or not. When enabled, each fragment's depth value will be offset after it
  /// is interpolated from the depth values of the appropriate vertices. The offset is added before the depth
  /// test is performed and before the value is written into the depth buffer.
  ///
  /// Can be useful for rendering hidden-line images, for applying decals to surfaces, and for rendering
  /// solids with highlighted edges.
  bool polygonOffset = false;

  /// Specifies a scale factor that is used to create a variable depth offset for each polygon.
  double polygonOffsetFactor = 0;

  /// Is multiplied by an implementation-specific value to create a constant depth offset.
  double polygonOffsetUnits = 0;

  /// Whether to apply dithering to the color to remove the appearance of banding.
  bool dithering = false;

  /// Whether alpha to coverage should be enabled or not. Can only be used with MSAA-enabled contexts
  /// (meaning when the renderer was created with *antialias* parameter set to `true`). Enabling this will
  /// smooth aliasing on clip plane edges and alphaTest-clipped edges.
  bool alphaToCoverage = false;

  /// Whether to premultiply the alpha (transparency) value.
  bool premultipliedAlpha = false;

  /// Whether double-sided, transparent objects should be rendered with a single pass or not.
  ///
  /// The engine renders double-sided, transparent objects with two draw calls (back faces first, then front
  /// faces) to mitigate transparency artifacts. There are scenarios however where this approach produces no
  /// quality gains but still doubles draw calls e.g. when rendering flat vegetation like grass sprites. In
  /// these cases, set the `forceSinglePass` flag to `true` to disable the two pass rendering to avoid
  /// performance issues.
  bool forceSinglePass = false;

  /// Whether it's possible to override the material with `Scene.overrideMaterial` or not.
  bool allowOverride = true;

  /// Defines whether 3D objects using this material are visible.
  bool visible = true;

  /// Defines whether this material is tone mapped according to the renderer's tone mapping setting.
  ///
  /// It is ignored when rendering to a render target or using post processing or when using
  /// `WebGPURenderer`. In all these cases, all materials are honored by tone mapping.
  bool toneMapped = true;

  /// An object that can be used to store custom data about the Material. It should not hold references to
  /// functions as these will not be cloned.
  Map<String, Object?> userData = {};

  /// This starts at `0` and counts how many times [needsUpdate] is set to `true`.
  int version = 0;

  double _alphaTest = 0;

  /// Sets the alpha value to be used when running an alpha test. The material will not be rendered if the
  /// opacity is lower than this value.
  double get alphaTest => _alphaTest;

  set alphaTest(double value) {
    if (_alphaTest > 0 != value > 0) {
      version++;
    }

    _alphaTest = value;
  }

  /// An optional callback that is executed immediately before the material is used to render a 3D object.
  ///
  /// This method can only be used when rendering with the reference renderer.
  MaterialRenderCallback onBeforeRender = _materialRenderNoop;

  /// Reads a property by its name, like `material[ key ]` in JavaScript; `null` for a name this class does not have
  /// (`undefined` in the reference). Subclasses add their properties (exception E-PROPERTY).
  Object? operator [](String key) {
    final value = _getValue(key);
    return identical(value, _materialUndefined) ? null : value;
  }

  /// `this[ key ]`: the property value, or [_materialUndefined] when there is no such property.
  Object? _getValue(String key) {
    return switch (key) {
      'isMaterial' => isMaterial,
      'id' => id,
      'uuid' => uuid,
      'name' => name,
      'type' => type,
      'blending' => blending,
      'side' => side,
      'vertexColors' => vertexColors,
      'opacity' => opacity,
      'transparent' => transparent,
      'alphaHash' => alphaHash,
      'blendSrc' => blendSrc,
      'blendDst' => blendDst,
      'blendEquation' => blendEquation,
      'blendSrcAlpha' => blendSrcAlpha,
      'blendDstAlpha' => blendDstAlpha,
      'blendEquationAlpha' => blendEquationAlpha,
      'blendColor' => blendColor,
      'blendAlpha' => blendAlpha,
      'depthFunc' => depthFunc,
      'depthTest' => depthTest,
      'depthWrite' => depthWrite,
      'stencilWriteMask' => stencilWriteMask,
      'stencilFunc' => stencilFunc,
      'stencilRef' => stencilRef,
      'stencilFuncMask' => stencilFuncMask,
      'stencilFail' => stencilFail,
      'stencilZFail' => stencilZFail,
      'stencilZPass' => stencilZPass,
      'stencilWrite' => stencilWrite,
      'clippingPlanes' => clippingPlanes,
      'clipIntersection' => clipIntersection,
      'clipShadows' => clipShadows,
      'shadowSide' => shadowSide,
      'colorWrite' => colorWrite,
      'polygonOffset' => polygonOffset,
      'polygonOffsetFactor' => polygonOffsetFactor,
      'polygonOffsetUnits' => polygonOffsetUnits,
      'dithering' => dithering,
      'alphaToCoverage' => alphaToCoverage,
      'premultipliedAlpha' => premultipliedAlpha,
      'forceSinglePass' => forceSinglePass,
      'allowOverride' => allowOverride,
      'visible' => visible,
      'toneMapped' => toneMapped,
      'userData' => userData,
      'version' => version,
      'alphaTest' => alphaTest,
      'onBeforeRender' => onBeforeRender,
      _ => _materialUndefined,
    };
  }

  /// `this[ key ] = value`. Read-only properties (`id`, the `is…` flags) throw an [ArgumentError], where the
  /// reference's strict-mode assignment to a non-writable property throws a `TypeError`.
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'uuid':
        uuid = value as String;
      case 'name':
        name = value as String;
      case 'type':
        type = value as String;
      case 'blending':
        blending = _materialInt(value);
      case 'side':
        side = _materialInt(value);
      case 'vertexColors':
        vertexColors = value as bool;
      case 'opacity':
        opacity = _materialDouble(value);
      case 'transparent':
        transparent = value as bool;
      case 'alphaHash':
        alphaHash = value as bool;
      case 'blendSrc':
        blendSrc = _materialInt(value);
      case 'blendDst':
        blendDst = _materialInt(value);
      case 'blendEquation':
        blendEquation = _materialInt(value);
      case 'blendSrcAlpha':
        blendSrcAlpha = _materialIntOrNull(value);
      case 'blendDstAlpha':
        blendDstAlpha = _materialIntOrNull(value);
      case 'blendEquationAlpha':
        blendEquationAlpha = _materialIntOrNull(value);
      case 'blendColor':
        blendColor = value as Color;
      case 'blendAlpha':
        blendAlpha = _materialDouble(value);
      case 'depthFunc':
        depthFunc = _materialInt(value);
      case 'depthTest':
        depthTest = value as bool;
      case 'depthWrite':
        depthWrite = value as bool;
      case 'stencilWriteMask':
        stencilWriteMask = _materialInt(value);
      case 'stencilFunc':
        stencilFunc = _materialInt(value);
      case 'stencilRef':
        stencilRef = _materialInt(value);
      case 'stencilFuncMask':
        stencilFuncMask = _materialInt(value);
      case 'stencilFail':
        stencilFail = _materialInt(value);
      case 'stencilZFail':
        stencilZFail = _materialInt(value);
      case 'stencilZPass':
        stencilZPass = _materialInt(value);
      case 'stencilWrite':
        stencilWrite = value as bool;
      case 'clippingPlanes':
        clippingPlanes = (value as List?)?.cast<Plane>();
      case 'clipIntersection':
        clipIntersection = value as bool;
      case 'clipShadows':
        clipShadows = value as bool;
      case 'shadowSide':
        shadowSide = _materialIntOrNull(value);
      case 'colorWrite':
        colorWrite = value as bool;
      case 'polygonOffset':
        polygonOffset = value as bool;
      case 'polygonOffsetFactor':
        polygonOffsetFactor = _materialDouble(value);
      case 'polygonOffsetUnits':
        polygonOffsetUnits = _materialDouble(value);
      case 'dithering':
        dithering = value as bool;
      case 'alphaToCoverage':
        alphaToCoverage = value as bool;
      case 'premultipliedAlpha':
        premultipliedAlpha = value as bool;
      case 'forceSinglePass':
        forceSinglePass = value as bool;
      case 'allowOverride':
        allowOverride = value as bool;
      case 'visible':
        visible = value as bool;
      case 'toneMapped':
        toneMapped = value as bool;
      case 'userData':
        userData = value as Map<String, Object?>;
      case 'version':
        version = _materialInt(value);
      case 'alphaTest':
        alphaTest = _materialDouble(value);
      case 'onBeforeRender':
        onBeforeRender = value as MaterialRenderCallback;
      default:
        throw ArgumentError.value(key, 'key', 'read-only property of $runtimeType');
    }
  }

  bool _has(String key) => !identical(_getValue(key), _materialUndefined);

  /// This method can be used to set default values from parameter objects. It is a generic implementation
  /// so it can be used with different types of materials.
  ///
  /// [values] maps property names to values. A `null` value is assigned like JavaScript's `null`; JavaScript's
  /// `undefined` value cannot be expressed in a Dart map (exception E-UNDEFINED). An unknown key logs the reference's
  /// warning and is skipped. A [Color] property is set with [Color.set] (so a hex number or a CSS string works too); a
  /// Vector2, Vector3 or Euler property is copied into from a value of its type.
  void setValues([Map<String, Object?>? values]) {
    if (values == null) {
      return;
    }

    for (final MapEntry(:key, value: newValue) in values.entries) {
      final currentValue = _getValue(key);

      if (identical(currentValue, _materialUndefined)) {
        warn("Material: '$key' is not a property of ENT.$type.");
        continue;
      }

      if (currentValue is Color) {
        currentValue.set(newValue);
      } else if (currentValue is Vector2 && newValue is Vector2) {
        currentValue.copy(newValue);
      } else if (currentValue is Euler && newValue is Euler) {
        currentValue.copy(newValue);
      } else if (currentValue is Vector3 && newValue is Vector3) {
        currentValue.copy(newValue);
      } else {
        _setValue(key, newValue);
      }
    }
  }

  /// Serializes the material into JSON.
  ///
  /// [meta] is `null` or a string for a root object, or a map holding the collected serialization data
  /// (`meta['textures']` and `meta['images']` keyed by UUID), as the reference's meta object.
  Map<String, Object?> toJSON([Object? meta]) {
    final isRootObject = meta == null || meta is String;

    if (isRootObject) {
      meta = <String, Object?>{'textures': <String, Object?>{}, 'images': <String, Object?>{}};
    }

    final data = <String, Object?>{
      'metadata': <String, Object?>{'version': 4.7, 'type': 'Material', 'generator': 'Material.toJSON'},
    };

    // standard Material serialization
    data['uuid'] = uuid;
    data['type'] = type;

    data['blending'] = blending;
    data['side'] = side;
    data['shadowSide'] = shadowSide;
    data['vertexColors'] = vertexColors;
    data['opacity'] = opacity;
    data['transparent'] = transparent;
    data['blendSrc'] = blendSrc;
    data['blendDst'] = blendDst;
    data['blendEquation'] = blendEquation;
    data['blendSrcAlpha'] = blendSrcAlpha;
    data['blendDstAlpha'] = blendDstAlpha;
    data['blendEquationAlpha'] = blendEquationAlpha;
    data['blendColor'] = blendColor.getHex();
    data['blendAlpha'] = blendAlpha;
    data['depthFunc'] = depthFunc;
    data['depthTest'] = depthTest;
    data['depthWrite'] = depthWrite;
    data['colorWrite'] = colorWrite;
    data['clipIntersection'] = clipIntersection;
    data['clipShadows'] = clipShadows;
    data['stencilWriteMask'] = stencilWriteMask;
    data['stencilFunc'] = stencilFunc;
    data['stencilRef'] = stencilRef;
    data['stencilFuncMask'] = stencilFuncMask;
    data['stencilFail'] = stencilFail;
    data['stencilZFail'] = stencilZFail;
    data['stencilZPass'] = stencilZPass;
    data['stencilWrite'] = stencilWrite;
    data['polygonOffset'] = polygonOffset;
    data['polygonOffsetFactor'] = polygonOffsetFactor;
    data['polygonOffsetUnits'] = polygonOffsetUnits;
    data['dithering'] = dithering;
    data['alphaTest'] = alphaTest;
    data['alphaHash'] = alphaHash;
    data['alphaToCoverage'] = alphaToCoverage;
    data['premultipliedAlpha'] = premultipliedAlpha;
    data['forceSinglePass'] = forceSinglePass;
    data['allowOverride'] = allowOverride;
    data['visible'] = visible;
    data['toneMapped'] = toneMapped;
    data['name'] = name;

    // The rest is duck-typed in the reference: `this.roughness !== undefined`, `this.map && this.map.isTexture`.
    final v = _getValue;
    String? texture(String key) => (v(key) as Texture).toJSON(meta)['uuid'] as String?;

    if (v('color') is Color) {
      data['color'] = (v('color') as Color).getHex();
    }

    for (final key in ['roughness', 'metalness', 'sheen']) {
      if (_has(key)) {
        data[key] = v(key);
      }
    }

    if (v('sheenColor') is Color) {
      data['sheenColor'] = (v('sheenColor') as Color).getHex();
    }

    if (_has('sheenRoughness')) {
      data['sheenRoughness'] = v('sheenRoughness');
    }

    if (v('emissive') is Color) {
      data['emissive'] = (v('emissive') as Color).getHex();
    }

    if (_has('emissiveIntensity')) {
      data['emissiveIntensity'] = v('emissiveIntensity');
    }

    if (v('specular') is Color) {
      data['specular'] = (v('specular') as Color).getHex();
    }

    if (_has('specularIntensity')) {
      data['specularIntensity'] = v('specularIntensity');
    }

    if (v('specularColor') is Color) {
      data['specularColor'] = (v('specularColor') as Color).getHex();
    }

    for (final key in ['shininess', 'clearcoat', 'clearcoatRoughness', 'diffuseRoughness']) {
      if (_has(key)) {
        data[key] = v(key);
      }
    }

    for (final key in ['diffuseRoughnessMap', 'clearcoatMap', 'clearcoatRoughnessMap']) {
      if (v(key) is Texture) {
        data[key] = texture(key);
      }
    }

    if (v('clearcoatNormalMap') is Texture) {
      data['clearcoatNormalMap'] = texture('clearcoatNormalMap');
      data['clearcoatNormalScale'] = (v('clearcoatNormalScale') as Vector2).toArray();
    }

    for (final key in ['sheenColorMap', 'sheenRoughnessMap']) {
      if (v(key) is Texture) {
        data[key] = texture(key);
      }
    }

    for (final key in [
      'dispersion',
      'retroreflectivity',
      'iridescence',
      'iridescenceIOR',
      'iridescenceThicknessMinimum',
      'iridescenceThicknessMaximum',
    ]) {
      if (_has(key)) {
        data[key] = v(key);
      }
    }

    for (final key in ['iridescenceMap', 'iridescenceThicknessMap']) {
      if (v(key) is Texture) {
        data[key] = texture(key);
      }
    }

    for (final key in ['anisotropy', 'anisotropyRotation']) {
      if (_has(key)) {
        data[key] = v(key);
      }
    }

    for (final key in ['anisotropyMap', 'map', 'matcap', 'alphaMap']) {
      if (v(key) is Texture) {
        data[key] = texture(key);
      }
    }

    if (v('lightMap') is Texture) {
      data['lightMap'] = texture('lightMap');
      data['lightMapIntensity'] = v('lightMapIntensity');
    }

    if (v('aoMap') is Texture) {
      data['aoMap'] = texture('aoMap');
      data['aoMapIntensity'] = v('aoMapIntensity');
    }

    if (v('bumpMap') is Texture) {
      data['bumpMap'] = texture('bumpMap');
      data['bumpScale'] = v('bumpScale');
    }

    if (v('normalMap') is Texture) {
      data['normalMap'] = texture('normalMap');
      data['normalMapType'] = v('normalMapType');
      data['normalScale'] = (v('normalScale') as Vector2).toArray();
    }

    if (v('displacementMap') is Texture) {
      data['displacementMap'] = texture('displacementMap');
      data['displacementScale'] = v('displacementScale');
      data['displacementBias'] = v('displacementBias');
    }

    for (final key in [
      'roughnessMap',
      'metalnessMap',
      'emissiveMap',
      'specularMap',
      'specularIntensityMap',
      'specularColorMap',
    ]) {
      if (v(key) is Texture) {
        data[key] = texture(key);
      }
    }

    if (v('envMap') is Texture) {
      data['envMap'] = texture('envMap');

      if (_has('combine')) {
        data['combine'] = v('combine');
      }
    }

    if (_has('envMapRotation')) {
      data['envMapRotation'] = (v('envMapRotation') as Euler).toArray();
    }

    for (final key in ['envMapIntensity', 'reflectivity', 'refractionRatio']) {
      if (_has(key)) {
        data[key] = v(key);
      }
    }

    if (v('gradientMap') is Texture) {
      data['gradientMap'] = texture('gradientMap');
    }

    if (_has('transmission')) {
      data['transmission'] = v('transmission');
    }

    if (v('transmissionMap') is Texture) {
      data['transmissionMap'] = texture('transmissionMap');
    }

    if (_has('thickness')) {
      data['thickness'] = v('thickness');
    }

    if (v('thicknessMap') is Texture) {
      data['thicknessMap'] = texture('thicknessMap');
    }

    if (_has('attenuationDistance')) {
      data['attenuationDistance'] = v('attenuationDistance');
    }

    if (_has('attenuationColor')) {
      data['attenuationColor'] = (v('attenuationColor') as Color).getHex();
    }

    for (final key in ['size', 'sizeAttenuation']) {
      if (_has(key)) {
        data[key] = v(key);
      }
    }

    final planes = clippingPlanes;

    if (planes != null && planes.isNotEmpty) {
      data['clippingPlanes'] = planes.map((plane) => plane.toJSON()).toList();
    }

    // rotation (SpriteMaterial), depthPacking (MeshDepthMaterial), then line, dash, wireframe and shading.
    for (final key in [
      'rotation',
      'depthPacking',
      'linewidth',
      'linecap',
      'linejoin',
      'dashSize',
      'gapSize',
      'scale',
      'wireframe',
      'wireframeLinewidth',
      'wireframeLinecap',
      'wireframeLinejoin',
      'flatShading',
      'fog',
    ]) {
      if (_has(key)) {
        data[key] = v(key);
      }
    }

    if (userData.isNotEmpty) {
      data['userData'] = userData;
    }

    // The reference notes this helper is copied from Object3D.toJSON.

    List<Object?> extractFromCache(Map<String, Object?> cache) {
      final values = <Object?>[];

      for (final key in cache.keys) {
        final data = cache[key] as Map<String, Object?>;
        data.remove('metadata');
        values.add(data);
      }

      return values;
    }

    if (isRootObject) {
      final collected = meta as Map<String, Object?>;
      final textures = extractFromCache(collected['textures'] as Map<String, Object?>);
      final images = extractFromCache(collected['images'] as Map<String, Object?>);

      if (textures.isNotEmpty) {
        data['textures'] = textures;
      }

      if (images.isNotEmpty) {
        data['images'] = images;
      }
    }

    return data;
  }

  /// The reference assigns `this[ key ] = json[ key ]` even for a property this material lacks (JavaScript then adds
  /// it). Dart objects cannot grow properties, so such keys are dropped (exception E-PROPERTY).
  void _jsonSet(String key, Object? value) {
    if (_has(key)) {
      _setValue(key, value);
    }
  }

  /// Deserializes the material from the given JSON. [textures] maps texture UUIDs to textures, for the maps
  /// the JSON references.
  Material fromJSON(Map<String, Object?> json, [Map<String, Texture>? textures]) {
    // `json.key !== undefined`: a key present with a null value counts, as a JSON null does in the reference.
    bool defined(String key) => json.containsKey(key);

    // `textures[ json.map ] || null`: like in the reference, a JSON naming a map with no `textures` given throws.
    Texture? texture(String key) => textures![json[key]];

    if (defined('uuid')) {
      uuid = json['uuid'] as String;
    }

    if (defined('name')) {
      name = json['name'] as String;
    }

    if (defined('color') && _has('color')) {
      (_getValue('color') as Color).setHex(json['color'] as num);
    }

    for (final key in ['roughness', 'metalness', 'sheen']) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    if (defined('sheenColor')) {
      _jsonSet('sheenColor', Color().setHex(json['sheenColor'] as num));
    }

    if (defined('sheenRoughness')) {
      _jsonSet('sheenRoughness', json['sheenRoughness']);
    }

    if (defined('emissive') && _has('emissive')) {
      (_getValue('emissive') as Color).setHex(json['emissive'] as num);
    }

    if (defined('specular') && _has('specular')) {
      (_getValue('specular') as Color).setHex(json['specular'] as num);
    }

    if (defined('specularIntensity')) {
      _jsonSet('specularIntensity', json['specularIntensity']);
    }

    if (defined('specularColor') && _has('specularColor')) {
      (_getValue('specularColor') as Color).setHex(json['specularColor'] as num);
    }

    for (final key in [
      'shininess',
      'clearcoat',
      'clearcoatRoughness',
      'diffuseRoughness',
      'dispersion',
      'retroreflectivity',
      'iridescence',
      'iridescenceIOR',
      'iridescenceThicknessMinimum',
      'iridescenceThicknessMaximum',
    ]) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    if (defined('iridescenceThicknessRange')) {
      // @deprecated
      final range = json['iridescenceThicknessRange'] as List;
      _jsonSet('iridescenceThicknessMinimum', range[0]);
      _jsonSet('iridescenceThicknessMaximum', range[1]);
    }

    for (final key in ['transmission', 'thickness', 'attenuationDistance']) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    if (defined('attenuationColor') && _has('attenuationColor')) {
      (_getValue('attenuationColor') as Color).setHex(json['attenuationColor'] as num);
    }

    for (final key in [
      'anisotropy',
      'anisotropyRotation',
      'fog',
      'flatShading',
      'blending',
      'combine',
      'side',
      'shadowSide',
      'opacity',
      'transparent',
      'alphaTest',
      'alphaHash',
      'depthFunc',
      'depthTest',
      'depthWrite',
      'colorWrite',
    ]) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    if (defined('clippingPlanes')) {
      clippingPlanes = [
        for (final plane in json['clippingPlanes'] as List) Plane().fromJSON(plane as Map<String, Object?>),
      ];
    }

    for (final key in [
      'clipIntersection',
      'clipShadows',
      'depthPacking',
      'blendSrc',
      'blendDst',
      'blendEquation',
      'blendSrcAlpha',
      'blendDstAlpha',
      'blendEquationAlpha',
    ]) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    if (defined('blendColor')) {
      blendColor.setHex(json['blendColor'] as num);
    }

    for (final key in [
      'blendAlpha',
      'stencilWriteMask',
      'stencilFunc',
      'stencilRef',
      'stencilFuncMask',
      'stencilFail',
      'stencilZFail',
      'stencilZPass',
      'stencilWrite',
      'wireframe',
      'wireframeLinewidth',
      'wireframeLinecap',
      'wireframeLinejoin',
      'rotation',
      'linewidth',
      'linecap',
      'linejoin',
      'dashSize',
      'gapSize',
      'scale',
      'polygonOffset',
      'polygonOffsetFactor',
      'polygonOffsetUnits',
      'dithering',
      'alphaToCoverage',
      'premultipliedAlpha',
      'forceSinglePass',
      'allowOverride',
      'visible',
      'toneMapped',
    ]) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    if (defined('userData')) {
      userData = json['userData'] as Map<String, Object?>;
    }

    if (defined('vertexColors')) {
      final value = json['vertexColors'];

      if (value is num) {
        vertexColors = value > 0;
      } else {
        vertexColors = value as bool;
      }
    }

    // for PointsMaterial

    for (final key in ['size', 'sizeAttenuation']) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    // maps

    for (final key in ['map', 'matcap', 'alphaMap', 'bumpMap']) {
      if (defined(key)) {
        _jsonSet(key, texture(key));
      }
    }

    if (defined('bumpScale')) {
      _jsonSet('bumpScale', json['bumpScale']);
    }

    if (defined('normalMap')) {
      _jsonSet('normalMap', texture('normalMap'));
    }

    if (defined('normalMapType')) {
      _jsonSet('normalMapType', json['normalMapType']);
    }

    if (defined('normalScale')) {
      var normalScale = json['normalScale'];

      if (normalScale is! List) {
        // Blender exporter used to export a scalar. See #7459

        normalScale = [normalScale, normalScale];
      }

      _jsonSet('normalScale', Vector2().fromArray(normalScale.cast<num>()));
    }

    if (defined('displacementMap')) {
      _jsonSet('displacementMap', texture('displacementMap'));
    }

    for (final key in ['displacementScale', 'displacementBias']) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    for (final key in ['roughnessMap', 'metalnessMap', 'emissiveMap']) {
      if (defined(key)) {
        _jsonSet(key, texture(key));
      }
    }

    if (defined('emissiveIntensity')) {
      _jsonSet('emissiveIntensity', json['emissiveIntensity']);
    }

    for (final key in ['specularMap', 'specularIntensityMap', 'specularColorMap', 'envMap']) {
      if (defined(key)) {
        _jsonSet(key, texture(key));
      }
    }

    if (defined('envMapRotation')) {
      // The reference calls `this.envMapRotation.fromArray()`, which throws for a material without one.
      (_getValue('envMapRotation') as Euler).fromArray(json['envMapRotation'] as List<Object?>);
    }

    for (final key in ['envMapIntensity', 'reflectivity', 'refractionRatio']) {
      if (defined(key)) {
        _jsonSet(key, json[key]);
      }
    }

    if (defined('lightMap')) {
      _jsonSet('lightMap', texture('lightMap'));
    }

    if (defined('lightMapIntensity')) {
      _jsonSet('lightMapIntensity', json['lightMapIntensity']);
    }

    if (defined('aoMap')) {
      _jsonSet('aoMap', texture('aoMap'));
    }

    if (defined('aoMapIntensity')) {
      _jsonSet('aoMapIntensity', json['aoMapIntensity']);
    }

    for (final key in ['gradientMap', 'clearcoatMap', 'clearcoatRoughnessMap', 'clearcoatNormalMap']) {
      if (defined(key)) {
        _jsonSet(key, texture(key));
      }
    }

    if (defined('clearcoatNormalScale')) {
      _jsonSet('clearcoatNormalScale', Vector2().fromArray((json['clearcoatNormalScale'] as List).cast<num>()));
    }

    for (final key in [
      'diffuseRoughnessMap',
      'iridescenceMap',
      'iridescenceThicknessMap',
      'transmissionMap',
      'thicknessMap',
      'anisotropyMap',
      'sheenColorMap',
      'sheenRoughnessMap',
    ]) {
      if (defined(key)) {
        _jsonSet(key, texture(key));
      }
    }

    return this;
  }

  /// Returns a new material with copied values from this instance. Subclasses override it to return their
  /// own type (exception E-CLONE).
  Material clone() {
    return Material().copy(this);
  }

  /// Copies the values of the given material to this instance.
  Material copy(covariant Material source) {
    name = source.name;

    blending = source.blending;
    side = source.side;
    vertexColors = source.vertexColors;

    opacity = source.opacity;
    transparent = source.transparent;

    blendSrc = source.blendSrc;
    blendDst = source.blendDst;
    blendEquation = source.blendEquation;
    blendSrcAlpha = source.blendSrcAlpha;
    blendDstAlpha = source.blendDstAlpha;
    blendEquationAlpha = source.blendEquationAlpha;
    blendColor.copy(source.blendColor);
    blendAlpha = source.blendAlpha;

    depthFunc = source.depthFunc;
    depthTest = source.depthTest;
    depthWrite = source.depthWrite;

    stencilWriteMask = source.stencilWriteMask;
    stencilFunc = source.stencilFunc;
    stencilRef = source.stencilRef;
    stencilFuncMask = source.stencilFuncMask;
    stencilFail = source.stencilFail;
    stencilZFail = source.stencilZFail;
    stencilZPass = source.stencilZPass;
    stencilWrite = source.stencilWrite;

    final srcPlanes = source.clippingPlanes;
    List<Plane>? dstPlanes;

    if (srcPlanes != null) {
      dstPlanes = [for (final plane in srcPlanes) plane.clone()];
    }

    clippingPlanes = dstPlanes;
    clipIntersection = source.clipIntersection;
    clipShadows = source.clipShadows;

    shadowSide = source.shadowSide;

    colorWrite = source.colorWrite;

    polygonOffset = source.polygonOffset;
    polygonOffsetFactor = source.polygonOffsetFactor;
    polygonOffsetUnits = source.polygonOffsetUnits;

    dithering = source.dithering;

    alphaTest = source.alphaTest;
    alphaHash = source.alphaHash;
    alphaToCoverage = source.alphaToCoverage;
    premultipliedAlpha = source.premultipliedAlpha;
    forceSinglePass = source.forceSinglePass;
    allowOverride = source.allowOverride;

    visible = source.visible;

    toneMapped = source.toneMapped;

    userData = _object3dJsonCopy(source.userData) as Map<String, Object?>;

    return this;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  void dispose() {
    dispatchEvent(Event('dispose'));
  }

  /// Setting this property to `true` indicates the engine the material needs to be recompiled.
  set needsUpdate(bool value) {
    if (value == true) {
      version++;
    }
  }
}
