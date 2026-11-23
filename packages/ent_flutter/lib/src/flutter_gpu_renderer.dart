// A renderer on Flutter GPU (Impeller) that draws what the reference renderer draws. The frame logic (culling,
// render lists, sorting) lives in render_list.dart and holds no Flutter code; this file runs the items: per draw it
// picks the material kind's program, sets the pipeline state as the reference does per material, writes the
// uniforms the reference would refresh and binds geometry and texture buffers (gpu/).
//
// Clip space: Impeller expects depth in [0, 1], like WebGPU, so the renderer switches cameras to
// WebGPUCoordinateSystem and updates their projection, as the reference's WebGPU renderer does.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:ent/ent.dart';
import 'package:ent_shaders/ent_shaders.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'gpu/check.dart';
import 'gpu/dfg.dart';
import 'gpu/effects.dart';
import 'gpu/environments.dart';
import 'gpu/geometries.dart';
import 'gpu/host_buffers.dart';
import 'gpu/lights.dart';
import 'gpu/passes.dart';
import 'gpu/programs.dart';
import 'gpu/shadows.dart';
import 'gpu/textures.dart';
import 'render_list.dart';

/// Draw statistics of the last frame, named as the reference's `renderer.info.render`.
class RenderInfo {
  RenderInfo._();

  /// Draw calls of the last frame.
  int calls = 0;

  /// Triangles drawn in the last frame.
  int triangles = 0;

  /// Line segments drawn in the last frame.
  int lines = 0;

  /// Points drawn in the last frame.
  int points = 0;

  /// Frames rendered so far.
  int frame = 0;
}

/// GPU memory held for geometries and textures, named as the reference's `renderer.info.memory`.
class MemoryInfo {
  MemoryInfo._(this._geometries, this._textures);

  final GpuGeometries _geometries;

  final GpuTextures _textures;

  /// Geometries with GPU buffers.
  int get geometries => _geometries.count;

  /// Textures uploaded to the GPU.
  int get textures => _textures.count;
}

/// Renderer statistics, as the reference's `renderer.info`.
class RendererInfo {
  RendererInfo._(GpuGeometries geometries, GpuTextures textures) : memory = MemoryInfo._(geometries, textures);

  /// Draw statistics of the last frame.
  final RenderInfo render = RenderInfo._();

  /// GPU memory held for geometries and textures.
  final MemoryInfo memory;
}

/// Renders an ent scene graph into a Flutter GPU texture, with the reference renderer's method names.
class FlutterGpuRenderer implements EffectComposerRenderer {
  FlutterGpuRenderer._(gpu.ShaderLibrary library)
    : _library = library,
      _basic = Program(library, 'MeshBasicMaterial', 'MeshVertex', 'basic', {
        'map',
        'alpha_map',
        'ao_map',
        'light_map',
        'specular_map',
        'env_map',
      }),
      _dashed = Program(library, 'LineDashedMaterial', 'MeshDashedVertex', 'dashed', {
        'map',
        'alpha_map',
        'ao_map',
        'light_map',
        'specular_map',
        'env_map',
      }, dashedSlots),
      _normal = Program(library, 'MeshNormalMaterial', 'MeshVertex', 'normal', {'normal_map', 'bump_map'}),
      _lambert = Program(library, 'MeshLambertMaterial', 'MeshVertex', 'lambert', {..._lit, 'specular_map', 'env_map'}),
      _phong = Program(library, 'MeshPhongMaterial', 'MeshVertex', 'phong', {..._lit, 'specular_map', 'env_map'}),
      _shadow = Program(library, 'ShadowMaterial', 'MeshVertex', 'ShadowFragment', {
        'light_texture_0',
        'light_texture_1',
        'light_texture_2',
        'light_texture_3',
        'light_texture_4',
        'light_texture_5',
      }),
      _toon = Program(library, 'MeshToonMaterial', 'MeshVertex', 'toon', {..._lit, 'gradient_map'}),
      _physical = Program(library, 'MeshStandardMaterial', 'MeshVertex', 'physical', {
        ..._lit,
        'env_map',
        'dfg_lut',
        ..._physicalMaps,
        'transmission_sampler_map',
      }),
      _background = Program(
        library,
        'Background',
        'BackgroundVertex',
        'BackgroundFragment',
        {'map'},
        const [VertexSlot('position', 3), VertexSlot('uv', 2)],
      ),
      _backgroundCube = Program(
        library,
        'BackgroundCube',
        'BackgroundCubeVertex',
        'BackgroundCubeFragment',
        {'env_map'},
        const [VertexSlot('position', 3)],
      ),
      _effects = {
        for (final MapEntry(key: type, value: effect) in effects.entries)
          type: (
            effect,
            Program(library, effect.fragment, 'EffectVertex', effect.fragment, effect.samplers.toSet(), effectSlots),
          ),
      },
      _passes = GpuPasses(library),
      _matcap = Program(library, 'MeshMatcapMaterial', 'MeshVertex', 'matcap', {
        'map',
        'alpha_map',
        'normal_map',
        'bump_map',
        'matcap',
      }),
      _hologram = Program(library, 'HologramMaterial', 'MeshVertex', 'hologram', const {}),
      _depth = Program(library, 'MeshDepthMaterial', 'MeshVertex', 'depth', {'map', 'alpha_map'}),
      _distance = Program(library, 'MeshDistanceMaterial', 'MeshVertex', 'distance', {'map', 'alpha_map'}),
      _points = Program(
        library,
        'PointsMaterial',
        'PointsVertex',
        'points',
        {'map', 'alpha_map'},
        const [VertexSlot('position', 3), VertexSlot('uv', 2), VertexSlot('color', 4)],
      ),
      _sprite = Program(
        library,
        'SpriteMaterial',
        'SpriteVertex',
        'sprite',
        {'map', 'alpha_map'},
        const [VertexSlot('position', 3), VertexSlot('uv', 2)],
      ) {
    _environments = GpuEnvironments(_passes, _textures);
  }

  // The fragment samplers the lit kinds share (Lambert, Phong, Toon and Physical extend it), with the
  // shadow maps and spot light maps of shaders/lights.glsl.
  static const Set<String> _lit = {
    'map',
    'alpha_map',
    'ao_map',
    'light_map',
    'emissive_map',
    'normal_map',
    'bump_map',
    'light_texture_0',
    'light_texture_1',
    'light_texture_2',
    'light_texture_3',
    'light_texture_4',
    'light_texture_5',
  };

  // The sampler names of the maps of MeshStandardMaterial and MeshPhysicalMaterial, in the order of
  // shaders/physical.glsl's UvInfo.
  static const List<String> _physicalMaps = [
    'roughness_map',
    'metalness_map',
    'clearcoat_map',
    'clearcoat_roughness_map',
    'clearcoat_normal_map',
    'sheen_color_map',
    'sheen_roughness_map',
    'iridescence_map',
    'iridescence_thickness_map',
    'anisotropy_map',
    'specular_intensity_map',
    'specular_color_map',
    'diffuse_roughness_map',
    'transmission_map',
    'thickness_map',
  ];

  // VertInfo's members of the maps' uv transforms and channels: the map's transform member, then its channel.
  static const List<(String, String)> _mapMembers = [
    ('map_transform', 'map_channel'),
    ('alpha_map_transform', 'alpha_map_channel'),
    ('ao_map_transform', 'ao_map_channel'),
    ('light_map_transform', 'light_map_channel'),
    ('emissive_map_transform', 'emissive_map_channel'),
    ('specular_map_transform', 'specular_map_channel'),
    ('bump_map_transform', 'bump_map_channel'),
    ('normal_map_transform', 'normal_map_channel'),
    ('displacement_map_transform', 'displacement_map_channel'),
  ];

  // The light textures' sampler names, `light_texture_0` and on.
  static final List<String> _lightTextures = [for (var i = 0; i < maxLightTextures; i++) 'light_texture_$i'];

  // Map [i] of _physicalMaps, with the condition the reference adds (HAS_CLEARCOATMAP needs clearcoat > 0, ...).
  static Texture? _physicalMap(MeshStandardMaterial material, int i) {
    if (material is! MeshPhysicalMaterial) {
      return switch (i) {
        0 => material.roughnessMap,
        1 => material.metalnessMap,
        _ => null,
      };
    }

    final m = material;

    return switch (i) {
      0 => m.roughnessMap,
      1 => m.metalnessMap,
      2 => m.clearcoat > 0 ? m.clearcoatMap : null,
      3 => m.clearcoat > 0 ? m.clearcoatRoughnessMap : null,
      4 => m.clearcoat > 0 ? m.clearcoatNormalMap : null,
      5 => m.sheen > 0 ? m.sheenColorMap : null,
      6 => m.sheen > 0 ? m.sheenRoughnessMap : null,
      7 => m.iridescence > 0 ? m.iridescenceMap : null,
      8 => m.iridescence > 0 ? m.iridescenceThicknessMap : null,
      9 => m.anisotropy > 0 ? m.anisotropyMap : null,
      10 => m.specularIntensityMap,
      11 => m.specularColorMap,
      12 => m.diffuseRoughness > 0 ? m.diffuseRoughnessMap : null,
      13 => m.transmission > 0 ? m.transmissionMap : null,
      _ => m.transmission > 0 ? m.thicknessMap : null,
    };
  }

  /// Loads the shader bundle and creates a renderer. The bundle is `ent_shaders`' asset
  /// `packages/ent_shaders/build/shaderbundles/ent.shaderbundle`, which its build hook writes. Throws a [StateError] when the app has not enabled Flutter GPU, or when
  /// Flutter GPU cannot render on this device (Android's OpenGL ES fallback).
  ///
  /// [antialias] is the reference renderer's constructor parameter: the frame is drawn with 4× MSAA and resolved, where
  /// the GPU supports offscreen MSAA (`gpuContext.doesSupportOffscreenMSAA`); elsewhere it is drawn without, with one
  /// warning (exception E-ANTIALIAS). Render targets are not multisampled by it; their own `samples` is.
  static Future<FlutterGpuRenderer> create({bool antialias = false}) async {
    try {
      gpu.gpuContext.defaultColorFormat;
    } catch (e) {
      throw StateError(
        'ent_flutter: Flutter GPU is not enabled. Run with --enable-flutter-gpu, or set FLTEnableFlutterGPU '
        'to true in Info.plist (iOS, macOS) or io.flutter.embedding.android.EnableFlutterGPU to true in '
        'AndroidManifest.xml (Android). Cause: $e',
      );
    }

    await checkRendering();
    final loads = await checkLoad();

    if (antialias && !gpu.gpuContext.doesSupportOffscreenMSAA) {
      warnOnce('FlutterGpuRenderer: antialias needs offscreen MSAA, which this GPU lacks; rendering without it.');
    }

    final samples = antialias && gpu.gpuContext.doesSupportOffscreenMSAA ? 4 : 1;

    gpu.ShaderLibrary? library;
    Object? error;

    try {
      library = await gpu.ShaderLibrary.fromAsset('packages/ent_shaders/build/shaderbundles/ent.shaderbundle');
    } catch (e) {
      error = e;
    }

    if (library == null) {
      throw StateError(
        'ent_flutter: no shader bundle for this GPU; is the build hook of ent_shaders enabled? A bundle built for '
        'another target keeps only that target\'s backends: rebuild for this one. ${error ?? ''}',
      );
    }

    // Outside the try: a shader missing from the bundle throws its own error, naming the shader.
    final renderer = FlutterGpuRenderer._(library)
      .._samples = samples
      .._loads = loads;
    renderer._textures
      ..filtersFloat = await checkFloatFilter(renderer._passes)
      ..readsDepth = await checkDepthRead(renderer._passes);
    return renderer;
  }

  // One program per material kind (exception E-SHADERS); a new kind adds its shader pair to
  // ent.shaderbundle.json, a Program here, a case in _programOf and one in _materialUniforms.
  final gpu.ShaderLibrary _library;

  final Program _basic;

  // The variants drawn so far, by key.
  final Map<String, Program> _variants = {};

  // LineDashedMaterial: the basic stages with the lineDistance attribute and the dash test (DASHED).
  final Program _dashed;

  final Program _normal;

  final Program _lambert;

  final Program _phong;

  final Program _toon;

  // ShadowMaterial (ShaderLib.shadow): only the light uniforms and shadow maps of shaders/lights.glsl.
  final Program _shadow;

  final Program _matcap;

  final Program _hologram;

  final Program _depth;

  final Program _distance;

  // MeshStandardMaterial and MeshPhysicalMaterial (shaders/physical.glsl).
  final Program _physical;

  final Program _points;

  final Program _sprite;

  // The reference's background plane (texture backgrounds) and box (cube and equirectangular backgrounds).
  final Program _background;

  final Program _backgroundCube;

  final GpuPasses _passes;

  // The registered effect programs, by their material's class (exception E-POSTPROCESSING).
  final Map<Type, (Effect, Program)> _effects;

  late final GpuEnvironments _environments;

  final RenderList _list = RenderList();

  final LightState _lights = LightState();

  final GpuGeometries _geometries = GpuGeometries();

  final GpuTextures _textures = GpuTextures();

  final HostBuffers _buffers = HostBuffers();

  final Color _clearColor = Color(0x000000);

  double _clearAlpha = 1;

  double _width = 1;

  double _height = 1;

  double _pixelRatio = 1;

  gpu.Texture? _depthBuffer;

  // The frame's depth while autoClear is off, stored for the next render into the frame, which loads it unless it
  // clears depth; `null` while autoClear is on (the frame then uses the transient [_depthBuffer]).
  gpu.Texture? _kept;

  // With antialias, the frame's multisampled color, resolved into each frame's own texture; `null` without.
  gpu.Texture? _sampled;

  // The frame's sample count: 4 with antialias where offscreen MSAA is supported, else 1.
  int _samples = 1;

  bool _loads = false;

  /// Whether a render into a target that does not clear keeps the target's color (`LoadAction.load`), as WebGL does:
  /// probed once at [create] by clearing a texture and loading it in a second pass, never by platform. True on Metal;
  /// false in flutter_tester, whose Impeller on Vulkan through SwiftShader clears it (flutter/flutter#196199).
  /// TuningPass takes the reference's additive blend onto its read buffer where it is true (exception
  /// E-POSTPROCESSING).
  @override
  bool get loadKeepsColor => _loads;

  /// Whether this GPU filters 32-bit float textures linearly, as WebGL with OES_texture_float_linear does: probed
  /// once at [create] by sampling a 2 × 1 float texture between its texels, never by platform. False on the iPhone
  /// 11's A13, which reads the nearest texel; FloatType textures with a linear filter are then stored as half floats
  /// (exception E-FLOATFILTER).
  bool get filtersFloat => _textures.filtersFloat;

  /// Whether this GPU samples a depth buffer through a plain sampler: probed once at [create] by clearing a depth
  /// buffer and reading it back, never by platform. True on Metal, where a render target's depth texture is copied
  /// from its depth buffer; false in flutter_tester, whose SwiftShader reads black, where the meshes are drawn again
  /// into it (exception E-DEPTHTEXTURE).
  bool get readsDepth => _textures.readsDepth;

  // The frame's height in pixels, for gl_FragCoord in GL's orientation (shadows/lights.glsl).
  int _frameHeight = 1;

  // The frame's width in pixels, for the line rule in shaders/basic.glsl.
  int _frameWidth = 1;

  // The frame's viewport and scissor in logical pixels and the scissor test (the reference's `_viewport`, `_scissor`,
  // `_scissorTest`), and the viewport and scissor in pixels that renders into the frame use (`_currentViewport`,
  // `_currentScissor`); all from the bottom left, as in GL.
  final Vector4 _viewport = Vector4(0, 0, 1, 1);

  final Vector4 _scissor = Vector4(0, 0, 1, 1);

  bool _scissorTest = false;

  final Vector4 _currentViewport = Vector4(0, 0, 1, 1);

  final Vector4 _currentScissor = Vector4(0, 0, 1, 1);

  // The shadow map of each light shadow, kept across frames (the reference's `shadow.map`), and the depth material the
  // casters are drawn with; while [_shadowing] it writes the depth itself.
  final Expando<ShadowTarget> _shadowTargets = Expando();

  final MeshDepthMaterial _shadowDepth = MeshDepthMaterial();

  // The depth material of a render target's depth texture pass (_depthTexture).
  final MeshDepthMaterial _targetDepth = MeshDepthMaterial();

  bool _shadowing = false;

  gpu.Texture? _texture;

  final Color _rgb = Color();

  final Matrix3 _matrix3 = Matrix3();

  final Matrix4 _matrix4 = Matrix4();

  // The reference's `_m` for materials and backgrounds: a mirror in x.
  static final Matrix3 _mirror = Matrix3().set(-1, 0, 0, 0, 1, 0, 0, 0, 1);

  // The background meshes: a 2 × 2 plane without normals, a unit box without normals and uvs.
  late final Mesh _plane = Mesh(BufferGeometry().copy(PlaneGeometry(2, 2))..deleteAttribute('normal'));

  late final Mesh _box = Mesh(
    BufferGeometry().copy(BoxGeometry(1, 1, 1))
      ..deleteAttribute('normal')
      ..deleteAttribute('uv'),
  );

  // The transmission target (kept across frames), the texture transmissive materials sample (`null` without a
  // transmission pass this frame), and whether a pass renders into a render target: there materials output linear color
  // without tone mapping, as in the reference (outputColorSpace and toneMapping of a render target).
  _TransmissionTarget? _transmission;

  gpu.Texture? _target;

  bool _intoTarget = false;

  // The application render target of setRenderTarget (`null`: the frame), and the face of a cube target.
  RenderTarget? _renderTarget;

  int _face = 0;

  // Whether compile is drawing: render callbacks are not called.
  bool _warming = false;

  // The frame each skeleton was last updated in (the reference's updateMap).
  final Expando<int> _skeletons = Expando();

  /// Debug builds only: the draw states met so far (program variant, target kind and every material property
  /// that sets pipeline state), for tests that check compile prepared what a frame draws.
  @visibleForTesting
  final Set<Record> states = {};

  // WebGL's blend function persists between draws and frames: where setBlending only logs an error
  // (SubtractiveBlending or MultiplyBlending without premultipliedAlpha) the previous one stays, starting from
  // GL's initial (ONE, ZERO, FUNC_ADD).
  gpu.ColorBlendEquation _equation = gpu.ColorBlendEquation(
    destinationColorBlendFactor: gpu.BlendFactor.zero,
    destinationAlphaBlendFactor: gpu.BlendFactor.zero,
  );

  // In a macOS app window the context reports `PixelFormat.unknown` as its default color format (verified on
  // Flutter 3.47.6, docs/flutter-gpu.md); 8-bit RGBA renders everywhere tested.
  static final gpu.PixelFormat _colorFormat = () {
    final preferred = gpu.gpuContext.defaultColorFormat;
    final usable =
        preferred != gpu.PixelFormat.unknown && gpu.gpuContext.supportsTextureFormat(preferred, renderTarget: true);
    return usable ? preferred : gpu.PixelFormat.r8g8b8a8UNormInt;
  }();

  /// Statistics of the last frame and of GPU memory.
  late final RendererInfo info = RendererInfo._(_geometries, _textures);

  /// Whether the renderer clears the color and depth buffers before rendering, as the reference does.
  @override
  bool autoClear = true;

  /// Whether an automatic clear (and [clear] with the composer's arguments) clears the color buffer.
  @override
  bool autoClearColor = true;

  /// Whether an automatic clear clears the depth buffer.
  @override
  bool autoClearDepth = true;

  /// Kept for the reference's API; render targets and the frame have no stencil buffer here.
  @override
  bool autoClearStencil = true;

  // What the next render clears after [clear] or [clearDepth] (exception E-POSTPROCESSING).
  bool _clearColorNext = false;

  bool _clearDepthNext = false;

  /// Whether opaque and transparent objects are sorted.
  bool sortObjects = true;

  /// The tone mapping applied to materials with `toneMapped` (default [NoToneMapping]).
  @override
  int toneMapping = NoToneMapping;

  /// The exposure of the tone mapping.
  @override
  double toneMappingExposure = 1;

  /// The color space of the frame, [SRGBColorSpace] (default) or [LinearSRGBColorSpace].
  @override
  String outputColorSpace = SRGBColorSpace;

  /// The size of the transmission render target relative to the drawing buffer.
  double transmissionResolutionScale = 1;

  /// Recording mode: while set, every shader variant a draw or [compile] needs is added by its key, registered or
  /// not, and an object whose variant the registry lacks is not drawn (with a warning) instead of throwing. Run the
  /// app through its scenes, then save the keys as the registry: `{"variants": [...]}`, docs/usage.md.
  Set<String>? recorded;

  /// The point light whose position, shadow camera near and far a MeshDistanceMaterial measures from. The
  /// reference sets it (`properties.get( material ).light`) only while rendering a point light's shadow map and
  /// throws when the material is drawn otherwise; here such objects are skipped with a warning while it is `null`.
  /// Point light shadow maps do not need it: the reference samples their depth texture (CubeDepthTexture), not the
  /// distance material's color, so they are drawn with the depth material here, and only tests set it.
  @visibleForTesting
  PointLight? distanceLight;

  /// Shadow settings: whether lights cast shadows, their filter and when the maps are rendered.
  final ShadowMap shadowMap = ShadowMap();

  /// The color texture of the last frame, or `null` before the first render.
  gpu.Texture? get texture => _texture;

  /// The device pixel ratio used to size the drawing buffer.
  @override
  double getPixelRatio() => _pixelRatio;

  /// Sets the device pixel ratio and, as the reference does, the viewport to the whole frame (see [setSize]).
  void setPixelRatio(double value) {
    _pixelRatio = value;
    setSize(_width, _height);
  }

  /// Writes the logical size into [target].
  @override
  Vector2 getSize(Vector2 target) => target.set(_width, _height);

  /// Sets the logical size; the drawing buffer is `size * pixelRatio`, floored, as in the reference, and the viewport
  /// covers it (the scissor stays).
  void setSize(double width, double height) {
    _width = width;
    _height = height;
    setViewport(0, 0, width, height);
  }

  /// Writes the viewport in pixels the next render uses into [target]: the frame's (`setViewport` times the pixel
  /// ratio) or the render target's.
  Vector4 getCurrentViewport(Vector4 target) => target.copy(_currentViewport);

  /// Writes the frame's viewport in logical pixels into [target].
  Vector4 getViewport(Vector4 target) => target.copy(_viewport);

  /// Sets the frame's viewport, from ([x], [y]) at its lower left to (`x + width`, `y + height`) in logical
  /// pixels, or from a Vector4 [x]. Render targets use their own viewport.
  void setViewport(Object x, [double y = 0, double width = 0, double height = 0]) {
    if (x is Vector4) {
      _viewport.copy(x);
    } else {
      _viewport.set((x as num).toDouble(), y, width, height);
    }

    _currentViewport.copy(_viewport).multiplyScalar(_ratio).round();
  }

  /// Writes the frame's scissor region in logical pixels into [target].
  Vector4 getScissor(Vector4 target) => target.copy(_scissor);

  /// Sets the frame's scissor region as [setViewport] sets the viewport.
  void setScissor(Object x, [double y = 0, double width = 0, double height = 0]) {
    if (x is Vector4) {
      _scissor.copy(x);
    } else {
      _scissor.set((x as num).toDouble(), y, width, height);
    }

    _currentScissor.copy(_scissor).multiplyScalar(_ratio).round();
  }

  /// Whether the scissor test is on for the frame.
  bool getScissorTest() => _scissorTest;

  /// Turns the frame's scissor test on or off: with it on, renders and their clears change only the pixels inside
  /// the scissor region (exception E-FRAME).
  void setScissorTest(bool value) {
    _scissorTest = value;
  }

  // The pixel ratio for the frame, 1 for a render target (the reference's getTargetPixelRatio).
  double get _ratio => _renderTarget == null ? _pixelRatio : 1;

  /// Writes the drawing-buffer size in physical pixels into [target].
  Vector2 getDrawingBufferSize(Vector2 target) {
    return target.set((_width * _pixelRatio).floorToDouble(), (_height * _pixelRatio).floorToDouble());
  }

  @override
  Color getClearColor(Color target) => target.copy(_clearColor);

  /// Sets the clear color (anything `Color.set` accepts) and alpha.
  @override
  void setClearColor(Object color, [double alpha = 1]) {
    _clearColor.set(color);
    _clearAlpha = alpha;
  }

  @override
  double getClearAlpha() => _clearAlpha;

  @override
  void setClearAlpha(double alpha) {
    _clearAlpha = alpha;
  }

  /// Makes the next [render] clear the [color] and [depth] buffers of its target, even without [autoClear] (the
  /// reference clears at once; exception E-POSTPROCESSING). There is no stencil buffer.
  @override
  void clear([bool color = true, bool depth = true, bool stencil = true]) {
    _clearColorNext = _clearColorNext || color;
    _clearDepthNext = _clearDepthNext || depth;
  }

  /// Makes the next [render] clear the color buffer of its target (see [clear]).
  void clearColor() {
    clear(true, false, false);
  }

  /// Makes the next [render] clear the depth buffer of its target (see [clear]).
  @override
  void clearDepth() {
    clear(false, true, false);
  }

  /// Kept for the reference's API; there is no stencil buffer, so nothing to clear.
  void clearStencil() {}

  /// The coordinate system of the cameras: Flutter GPU's clip space is WebGPU's (depth 0 to 1, row 0 at NDC +y). The
  /// reference renderer reports WebGLCoordinateSystem; this renderer converts every camera it draws with, and
  /// CubeCamera orients its cameras for WebGPU (docs/flutter-gpu.md, CubeCamera).
  @override
  int get coordinateSystem => WebGPUCoordinateSystem;

  /// The render target [render] draws into, or `null` for the frame.
  @override
  RenderTarget? getRenderTarget() => _renderTarget;

  @override
  int getActiveCubeFace() => _face;

  @override
  int getActiveMipmapLevel() => 0;

  /// Makes [render] draw into [target], or into the frame when it is `null`, into face [activeCubeFace] of a
  /// WebGLCubeRenderTarget. 3D and array targets and mip levels other than 0 are drawn as a plain target's level 0,
  /// with one warning.
  @override
  void setRenderTarget(RenderTarget? target, [int activeCubeFace = 0, int activeMipmapLevel = 0]) {
    if ((target?.depth ?? 1) > 1 || activeMipmapLevel != 0) {
      warnOnce('FlutterGpuRenderer: 3D and array render targets and mip levels are not supported yet.');
    }

    _renderTarget = target;
    _face = target is WebGLCubeRenderTarget ? activeCubeFace : 0;

    if (target == null) {
      _currentViewport.copy(_viewport).multiplyScalar(_pixelRatio).floor();
      _currentScissor.copy(_scissor).multiplyScalar(_pixelRatio).floor();
    } else {
      _currentViewport.copy(target.viewport);
      _currentScissor.copy(target.scissor);
    }
  }

  /// Completes when the GPU has finished every frame and pass submitted so far. Read an image [render] returned only
  /// after it: on some Vulkan drivers (the Galaxy S10's Mali-G76) a texture read back right after a submit misses the
  /// GPU's writes (HostBuffers.idle). [readRenderTargetPixels] waits for it itself.
  Future<void> idle() => Future.wait([_buffers.idle(), _passes.idle()]);

  /// Reads the [width] × [height] rectangle at ([x], [y]) of [target]'s color texture into [buffer] as the reference
  /// does (rows from the bottom, as glReadPixels), for 8-bit RGBA targets (with the reference's error otherwise).
  /// Asynchronous: Flutter GPU hands texture contents back through `asImage().toByteData()`.
  Future<void> readRenderTargetPixels(
    RenderTarget target,
    int x,
    int y,
    int width,
    int height,
    Uint8List buffer, [
    int activeCubeFaceIndex = 0,
    int textureIndex = 0,
  ]) async {
    final texture = target.textures[textureIndex];

    if (texture.format != RGBAFormat) {
      error('WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.');
      return;
    }

    if (texture.type != UnsignedByteType) {
      error(
        'WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.',
      );
      return;
    }

    // The rectangle inside the render target, as the reference's bounds check.
    if (x < 0 || x > target.width - width || y < 0 || y > target.height - height) {
      return;
    }

    await idle();
    final data = (await _textures.target(target).color.asImage().toByteData(format: ui.ImageByteFormat.rawRgba))!;

    for (var row = 0; row < height; row++) {
      final from = ((target.height - 1 - (y + row)) * target.width + x) * 4;
      buffer.setRange(row * width * 4, (row + 1) * width * 4, data.buffer.asUint8List(data.offsetInBytes + from));
    }
  }

  /// Renders [scene] as seen by [camera] and returns the frame as an image; with a render target set
  /// ([setRenderTarget]) it draws into the target's texture and returns that texture as an image (for a cube
  /// target, which Flutter GPU cannot show as an image, a 1 × 1 black one). Before reading the image's pixels
  /// (`toByteData`), await [idle].
  @override
  ui.Image render(Object3D scene, Camera camera) {
    _prepareCamera(camera);

    if (scene.matrixWorldAutoUpdate) {
      scene.updateMatrixWorld();
    }

    if (camera.parent == null && camera.matrixWorldAutoUpdate) {
      camera.updateMatrixWorld();
    }

    if (scene is Scene) {
      scene.onBeforeRender(this, scene, camera, null, null, null);
    }

    _list.build(scene, camera, sort: sortObjects);

    // Each render writes into a host buffer of its own, recycled once its command buffers have completed.
    _buffers.next();

    info.render
      ..calls = 0
      ..triangles = 0
      ..lines = 0
      ..points = 0
      ..frame += 1;

    _renderShadows(scene, camera);

    final target = _renderTarget;

    if (target != null) {
      final texture = _frame(scene, camera, target.width, target.height, null, target);

      if (target is! WebGLCubeRenderTarget) {
        return texture.asImage();
      }

      // The mip chain is filled after the last face CubeCamera draws, as the reference does.
      final gpuTarget = _textures.target(target);

      if (gpuTarget.levels > 1 && target.texture.mipmapsAutoUpdate) {
        _environments.mipmaps(texture, target.width, gpuTarget.levels);
      }

      return _textures.fallback.asImage();
    }

    final texture = _frame(
      scene,
      camera,
      (_width * _pixelRatio).floor().clamp(1, 16384),
      (_height * _pixelRatio).floor().clamp(1, 16384),
    );
    _texture = texture;

    return texture.asImage();
  }

  /// Prepares the programs [scene]'s materials need before the first render, as the reference's `compile`, with the
  /// lights and environment of [targetScene] (default [scene]), which must be set up by then. Flutter GPU builds a
  /// pipeline the first time a draw meets a new state (docs/flutter-gpu.md, Pipeline compile cost), so this draws every
  /// mesh and line of [scene] in the camera's layers (visible or not, in the frustum or not) into a 1×1 offscreen
  /// frame, with the background, the shadow casters and the transmission pass a frame would draw. The commands are
  /// submitted without waiting; nothing the next render shows or counts changes. Returns the materials, as the
  /// reference does.
  Set<Material> compile(Object3D scene, Camera camera, [Scene? targetScene]) => _compile(scene, camera, targetScene);

  /// [compile], completing with [scene] once the GPU has run the warm-up frame, so its pipelines are built (the
  /// reference's `compileAsync` waits for KHR_parallel_shader_compile).
  Future<Object3D> compileAsync(Object3D scene, Camera camera, [Scene? targetScene]) async {
    final done = Completer<void>();
    _compile(scene, camera, targetScene, (_) => done.complete());
    await done.future;

    return scene;
  }

  Set<Material> _compile(Object3D scene, Camera camera, Scene? targetScene, [gpu.CompletionCallback? done]) {
    final target = targetScene ?? scene;
    final materials = <Material>{};
    final (calls, triangles, lines, points) = (
      info.render.calls,
      info.render.triangles,
      info.render.lines,
      info.render.points,
    );
    final (depth, sampled, transmission, equation) = (_depthBuffer, _sampled, _transmission, _equation);
    _prepareCamera(camera);

    // The lights of the target scene and of the new objects, as in a frame (visible, in the camera's layers).
    _list.clear();

    for (final root in {target, scene}) {
      root.traverseVisible((object) {
        if (object is Light && object.layers.test(camera.layers)) {
          _list.lights.add(object);

          if (object.castShadow) {
            _list.shadows.add(object);
          }
        }
      });
    }

    scene.traverse((object) {
      final (found, items) = _drawn(object);
      materials.addAll(found);

      for (final item in items) {
        final m = item.material;
        (_transmits(m) ? _list.transmissive : (m.transparent ? _list.transparent : _list.opaque)).add(item);
      }
    });

    // A transmissive object of the target scene makes a frame draw the opaque ones into the transmission target.
    if (_list.transmissive.isEmpty && target != scene) {
      target.traverse((object) {
        if (_list.transmissive.isEmpty) {
          _list.transmissive.addAll(_drawn(object).$2.where((item) => _transmits(item.material)).take(1));
        }
      });
    }

    _warming = true;

    // Restored even when a draw throws (an unregistered variant), so the next frame is drawn as before.
    try {
      _warmShadows(scene, target, camera);
      _frame(target, camera, 1, 1, done);
    } finally {
      _warming = false;
      info.render
        ..calls = calls
        ..triangles = triangles
        ..lines = lines
        ..points = points;
      _depthBuffer = depth;
      _sampled = sampled;
      _transmission = transmission;
      _equation = equation;
    }

    return materials;
  }

  // The materials of a mesh, line, points or sprite and the items a frame draws of it: one per group of a material
  // array, as RenderList.
  static (Iterable<Material>, List<RenderItem>) _drawn(Object3D object) {
    final (geometry, material) = switch (object) {
      Mesh o => (o.geometry, o.material),
      Line o => (o.geometry, o.material),
      Points o => (o.geometry, o.material),
      Sprite o => (o.geometry, o.material),
      _ => (null, null),
    };

    if (geometry == null) {
      return (const [], const []);
    }

    if (material is List) {
      return (
        material.whereType<Material>(),
        [
          for (final group in geometry.groups)
            if (group.materialIndex case final int i when i >= 0 && i < material.length && material[i] is Material)
              RenderItem(object, geometry, material[i] as Material, 0, 0, group),
        ],
      );
    }

    return material is Material
        ? ([material], [RenderItem(object, geometry, material, 0, 0, null)])
        : (const [], const []);
  }

  static bool _transmits(Material material) => material is MeshPhysicalMaterial && material.transmission > 0;

  // The shadow pass of compile: the casters of [scene] drawn once into a 1×1 shadow map, when a light's shadows
  // are drawn, so the depth program meets each caster's side.
  void _warmShadows(Object3D scene, Object3D target, Camera camera) {
    final light = !shadowMap.enabled ? null : _list.shadows.where((l) => _shadowOf(l) != null).firstOrNull;

    if (light == null) {
      return;
    }

    final commands = gpu.gpuContext.createCommandBuffer();
    final pass = commands.createRenderPass(ShadowTarget(1, 1).attachments());
    _shadowing = true;

    try {
      scene.traverse((object) {
        if (object is Mesh && object.castShadow) {
          _castMesh(pass, object, target, camera, _shadowOf(light)!.camera);
        }
      });
    } finally {
      _shadowing = false;
    }

    _buffers.submit(commands);
  }

  // The frame after the shadow maps: lights, background, the transmission pass and the render lists drawn into a
  // new [width] × [height] color texture, or into [into]'s, submitted (with [done] as the completion callback).
  gpu.Texture _frame(
    Object3D scene,
    Camera camera,
    int width,
    int height, [
    gpu.CompletionCallback? done,
    RenderTarget? into,
  ]) {
    _lights
      ..shadowType = switch (shadowMap.type) {
        BasicShadowMap => 0,
        VSMShadowMap => 2,
        _ => 1,
      }
      ..setup(_list.lights, camera, _shadowMapOf);

    final context = gpu.gpuContext;
    final depth = _depthBuffer;

    if (into == null && (depth == null || depth.width != width || depth.height != height)) {
      _depthBuffer = context.createTexture(
        gpu.StorageMode.deviceTransient,
        width,
        height,
        format: context.defaultDepthStencilFormat,
        sampleCount: _samples,
        enableShaderReadUsage: false,
      );
      _sampled = _samples == 1
          ? null
          : context.createTexture(
              gpu.StorageMode.deviceTransient,
              width,
              height,
              format: _colorFormat,
              sampleCount: _samples,
              enableShaderReadUsage: false,
            );
    }

    _frameHeight = height;
    _frameWidth = width;
    final background = _backgroundOf(scene);

    // renderTransmissionPass: the opaque objects into the transmission target first (not with an
    // overrideMaterial).
    _target = null;

    if (_list.transmissive.isNotEmpty && !(scene is Scene && scene.overrideMaterial != null)) {
      _transmissionPass(scene, camera, background, width, height);
    }

    // A fresh color texture per frame: the previous frame may still be on screen as a ui.Image. A render target keeps
    // its textures, so without autoClear it is drawn over (the reference's behaviour), and its materials output linear
    // color without tone mapping, as the transmission pass's.
    final target = into == null ? null : _textures.target(into);
    _intoTarget = target != null;
    final texture =
        target?.color ?? context.createTexture(gpu.StorageMode.devicePrivate, width, height, format: _colorFormat);
    final (clear, force) = _clearValue(scene, background, linear: target != null);
    final (clearColor, clearDepth) = (_clearColorNext, _clearDepthNext);
    _clearColorNext = false;
    _clearDepthNext = false;

    // The frame's viewport and, with the scissor test, its scissor (the reference's state.viewport and state.scissor of
    // `_currentViewport`, `_currentScissor`) in Flutter GPU's top-left origin, the scissor within the frame; `null`
    // where they cover the whole frame, the common case, which sets neither (exception E-FRAME); compile's 1 × 1 frame
    // uses neither. Flutter GPU rejects a viewport that starts outside the frame (GL takes it).
    final view = target == null && !_warming ? _flip(_currentViewport, width, height) : null;
    final cut = target == null && !_warming && _scissorTest ? _flip(_currentScissor, width, height, clamp: true) : null;
    final paint = autoClear || force || clearColor;
    final wipe = autoClear || force || clearDepth;
    final cleared = paint && cut == null;

    // A render into the frame that keeps its color starts from a copy of the previous render's texture, drawn first
    // in the pass (so earlier images stay as they were, and the copy needs no LoadAction.load, which
    // flutter_tester's SwiftShader clears: flutter/flutter#196199); without one of the same size it starts from
    // transparent black, as a fresh WebGL drawing buffer. While autoClear is off, the frame's depth is kept in
    // [_kept] and loaded by the next such render unless it clears depth (exception E-FRAME).
    final previous = _texture;
    final copy =
        target == null &&
        !cleared &&
        !_warming &&
        previous != null &&
        previous.width == width &&
        previous.height == height;
    final kept = target == null && !autoClear && !_warming;
    final stored = _kept;

    if (target == null && !_warming) {
      _kept = autoClear
          ? null
          : stored != null && stored.width == width && stored.height == height
          ? stored
          : context.createTexture(
              gpu.StorageMode.devicePrivate,
              width,
              height,
              format: context.defaultDepthStencilFormat,
              sampleCount: _samples,
              enableShaderReadUsage: false,
            );
    }

    final depthLoad = switch (target) {
      null => kept && identical(stored, _kept) && (cut != null || !wipe),
      _ => !autoClear && !force && !clearDepth,
    };
    final commands = context.createCommandBuffer();

    // With antialias the main frame draws into the multisampled [_sampled] and resolves into [texture] at the end
    // of the pass; the samples are not kept: a render that keeps the frame's color copies the resolved previous
    // texture into them first (above).
    // A target with `samples` keeps its samples (and multisampled depth) for the next render into it, which loads
    // them without autoClear, and resolves into its texture at the end of every render (the reference resolves in
    // updateMultisampleRenderTarget after each render into it).
    final sampled = target == null ? _sampled : target.samples;
    final pass = commands.createRenderPass(
      gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
          texture: sampled ?? texture,
          resolveTexture: sampled == null ? null : texture,
          slice: into is WebGLCubeRenderTarget ? _face : 0,
          loadAction: cleared || (target == null && !copy)
              ? gpu.LoadAction.clear
              : (copy ? gpu.LoadAction.dontCare : gpu.LoadAction.load),
          storeAction: switch ((sampled, target)) {
            (null, _) => gpu.StoreAction.store,
            (_, null) => gpu.StoreAction.multisampleResolve,
            _ => gpu.StoreAction.storeAndMultisampleResolve,
          },
          clearValue: cleared ? clear : vm.Vector4.zero(),
        ),
        depthStencilAttachment: gpu.DepthStencilAttachment(
          texture: target?.depth ?? (kept ? _kept! : _depthBuffer!),
          depthLoadAction: depthLoad ? gpu.LoadAction.load : gpu.LoadAction.clear,
          depthStoreAction: target != null || kept ? gpu.StoreAction.store : gpu.StoreAction.dontCare,
          depthClearValue: 1,
        ),
      ),
    );

    if (into != null) {
      _bounds(pass, into);
    }

    // The copy, and a clear inside the scissor (gl.clear is scissored; the load action clears the whole attachment):
    // the clear value over the copy or transparent black, then the far depth over the loaded depth with the color
    // kept by blending (ZERO, ONE). Both are drawn before the scissor applies.
    final rect = cut == null || !paint ? null : cut;

    if (copy || rect != null) {
      pass
        ..setDepthWriteEnable(false)
        ..setDepthCompareOperation(gpu.CompareFunction.always);
      _passes.draw(
        pass,
        'FrameFragment',
        _buffers,
        blocks: {
          'FrameInfo': (block) => block
            ..floats('size', [width.toDouble(), height.toDouble()])
            ..float('copy', copy ? 1 : 0)
            ..floats('rect', switch (rect) {
              (final x, final y, final w, final h) => [x.toDouble(), y.toDouble(), x + w + 0.0, y + h + 0.0],
              _ => [0, 0, 0, 0],
            })
            ..floats('color', clear.storage),
        },
        textures: {'previous': PassTexture(copy ? previous : _textures.fallback, _nearest)},
      );
    }

    if (cut case (final x, final y, final w, final h)) {
      pass.setScissor(gpu.Scissor(x: x, y: y, width: w, height: h));

      if (wipe && depthLoad) {
        pass
          ..setDepthWriteEnable(true)
          ..setDepthCompareOperation(gpu.CompareFunction.always);
        _passes.draw(
          pass,
          'ClearFragment',
          _buffers,
          textures: {'source': PassTexture(_textures.fallback, _nearest)},
          keep: true,
        );
      }
    }

    if (view case (final x, final y, final w, final h)) {
      pass.setViewport(gpu.Viewport(x: x, y: y, width: w, height: h));
    }

    // renderScene: the background (first of the opaque list), opaque, transmissive, transparent.
    _drawBackground(pass, background, camera);

    for (final items in [_list.opaque, _list.transmissive, _list.transparent]) {
      for (final item in items) {
        _renderObject(pass, item, scene, camera);
      }
    }

    _buffers.submit(commands, target?.depths == null ? done : null);

    if (target?.depths case final depths?) {
      if (target!.replay case final replay?) {
        _depthTexture(into!, replay, depths, autoClear || force || clearDepth, scene, camera, done);
      } else {
        _copyDepth(target.depth, depths, done);
      }
    }

    _intoTarget = false;

    return texture;
  }

  // The depth texture of a target where the GPU samples depth buffers (readsDepth): the depth buffer's red channel,
  // copied texel for texel into [depths] (exception E-DEPTHTEXTURE: Metal reads it as (d, d, d, 1), WebGL's depth
  // texture as (d, 0, 0, 1)).
  void _copyDepth(gpu.Texture depth, gpu.Texture depths, gpu.CompletionCallback? done) {
    final commands = gpu.gpuContext.createCommandBuffer();
    _passes.draw(
      commands.createRenderPass(
        gpu.RenderTarget.singleColor(gpu.ColorAttachment(texture: depths, loadAction: gpu.LoadAction.dontCare)),
      ),
      'MipFragment',
      _buffers,
      blocks: {
        'MipInfo': (block) => block
          ..float('source_lod', 0)
          ..floats('size', [depths.width.toDouble(), depths.height.toDouble()]),
      },
      textures: {'source': PassTexture(depth, _nearest)},
    );
    _buffers.submit(commands, done);
  }

  // The depth texture of a target where the GPU cannot sample the depth buffer (exception E-DEPTHTEXTURE): the meshes
  // that wrote depth in the pass, drawn again in the same order with a MeshDepthMaterial of their depthFunc, writing
  // their depth into [depths] with a [depth] buffer of its own, so the same tests leave the same depth. Both are
  // cleared to 1 when the pass cleared the target's depth buffer. Not counted in info.render.
  void _depthTexture(
    RenderTarget into,
    gpu.Texture depth,
    gpu.Texture depths,
    bool clear,
    Object3D scene,
    Camera camera,
    gpu.CompletionCallback? done,
  ) {
    final commands = gpu.gpuContext.createCommandBuffer();
    final pass = commands.createRenderPass(
      gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
          texture: depths,
          loadAction: clear ? gpu.LoadAction.clear : gpu.LoadAction.load,
          clearValue: vm.Vector4(1, 1, 1, 1),
        ),
        depthStencilAttachment: gpu.DepthStencilAttachment(
          texture: depth,
          depthLoadAction: clear ? gpu.LoadAction.clear : gpu.LoadAction.load,
          depthStoreAction: gpu.StoreAction.store,
          depthClearValue: 1,
        ),
      ),
    );
    final (calls, triangles) = (info.render.calls, info.render.triangles);
    final override = scene is Scene ? scene.overrideMaterial : null;
    _bounds(pass, into);
    _shadowing = true;

    try {
      for (final items in [_list.opaque, _list.transmissive, _list.transparent]) {
        for (final item in items) {
          final object = item.object;
          final material = override != null && item.material.allowOverride ? override : item.material;
          final surface = _Surface.of(material);

          if (object is! Mesh ||
              !object.layers.test(camera.layers) ||
              !material.depthTest ||
              !material.depthWrite ||
              surface.wireframe ||
              _programOf(material) == null) {
            continue;
          }

          final depth = _targetDepth
            ..depthFunc = material.depthFunc
            ..side = material.side
            ..alphaMap = surface.alphaMap
            ..alphaTest = material.alphaToCoverage ? 0.5 : material.alphaTest
            ..map = surface.map
            ..displacementMap = surface.displacementMap
            ..displacementScale = surface.displacementScale
            ..displacementBias = surface.displacementBias
            ..polygonOffset = material.polygonOffset
            ..polygonOffsetFactor = material.polygonOffsetFactor
            ..polygonOffsetUnits = material.polygonOffsetUnits;
          object.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse, object.matrixWorld);
          _draw(
            pass,
            _depth,
            RenderItem(object, item.geometry, depth, 0, 0, item.group),
            object,
            depth,
            depth.side,
            scene,
            camera,
          );
        }
      }
    } finally {
      _shadowing = false;
    }

    _buffers.submit(commands, done);
    info.render
      ..calls = calls
      ..triangles = triangles;
  }

  // The viewport and scissor for a render target, as the reference sets them: its viewport and, with scissorTest, its
  // scissor, given from the bottom left as in GL; Flutter GPU's origin is the top left, where the frame's rows start.
  // The clear (the pass's load action) covers the whole target, unlike gl.clear inside a scissor.
  void _bounds(gpu.RenderPass pass, RenderTarget target) {
    final (v, s, h) = (target.viewport, target.scissor, target.height);
    pass.setViewport(gpu.Viewport(x: v.x.round(), y: (h - v.y - v.w).round(), width: v.z.round(), height: v.w.round()));

    if (target.scissorTest) {
      pass.setScissor(gpu.Scissor(x: s.x.round(), y: (h - s.y - s.w).round(), width: s.z.round(), height: s.w.round()));
    }
  }

  // [r] (x and y from the bottom left, width, height in pixels) with y from the top of a [width] × [height] frame,
  // with [clamp] cut to the frame; `null` when it is the whole frame.
  static (int, int, int, int)? _flip(Vector4 r, int width, int height, {bool clamp = false}) {
    var (x0, y0, x1, y1) = (r.x.toInt(), height - (r.y + r.w).toInt(), (r.x + r.z).toInt(), height - r.y.toInt());

    if (clamp) {
      (x0, y0) = (x0.clamp(0, width), y0.clamp(0, height));
      (x1, y1) = (x1.clamp(x0, width), y1.clamp(y0, height));
    }

    return x0 == 0 && y0 == 0 && x1 == width && y1 == height ? null : (x0, y0, x1 - x0, y1 - y0);
  }

  // The background's clear value, as the reference renders it: in the output color space ([linear]: the working color
  // space of a render target) and premultiplied, and whether a Color background forces the clear.
  (vm.Vector4, bool) _clearValue(
    Object3D scene,
    _Background? background, {
    required bool linear,
    bool transmission = false,
  }) {
    final color = scene is Scene ? scene.background : null;
    var alpha = _clearAlpha;
    _rgb.copy(_clearColor);

    if (color is Color) {
      _rgb.copy(color);
      alpha = 1;
    } else if (color != null && background == null && !(color is Texture && GpuEnvironments.isEnvironment(color))) {
      warnOnce('FlutterGpuRenderer: unsupported background ${color.runtimeType}; using the clear color.');
    }

    if (transmission && color is! Color && _clearAlpha < 1) {
      // renderTransmissionPass clears a translucent canvas's target with white at alpha 0.5.
      _rgb.setRGB(1, 1, 1);
      alpha = 0.5;
    }

    _rgb.getRGB(_rgb, linear ? LinearSRGBColorSpace : outputColorSpace);

    return (vm.Vector4(_rgb.r * alpha, _rgb.g * alpha, _rgb.b * alpha, alpha), color is Color);
  }

  // The reference's transmission pass: the background and the opaque objects, without tone mapping and in linear color,
  // into a 4× multisampled HalfFloatType target, resolved and mipmapped (generateMipmap). Without
  // WEBGL_multisampled_render_to_texture (Chrome on macOS has none) the reference then draws the back faces of
  // double-sided transmissive objects into it too, sampling the first result, and resolves again; here into a second
  // texture, so the pass never samples the texture it resolves into.
  void _transmissionPass(Object3D scene, Camera camera, _Background? background, int width, int height) {
    final w = (width * transmissionResolutionScale).floor().clamp(1, 16384);
    final h = (height * transmissionResolutionScale).floor().clamp(1, 16384);
    final target = _transmission?.width == w && _transmission?.height == h
        ? _transmission!
        : _transmission = _TransmissionTarget(w, h);
    final (clear, _) = _clearValue(scene, background, linear: true, transmission: true);
    final (frameWidth, frameHeight, into) = (_frameWidth, _frameHeight, _intoTarget);
    final doubles = [
      for (final item in _list.transmissive)
        if (item.material.side == DoubleSide && item.object.layers.test(camera.layers)) item,
    ];

    _intoTarget = true;
    _frameWidth = w;
    _frameHeight = h;

    final commands = gpu.gpuContext.createCommandBuffer();
    final pass = commands.createRenderPass(target.attachments(target.texture, clear: clear, keep: doubles.isNotEmpty));
    _drawBackground(pass, background, camera);

    for (final item in _list.opaque) {
      _renderObject(pass, item, scene, camera);
    }

    _buffers.submit(commands);
    _mipmaps(target.texture);
    _target = target.texture;

    if (doubles.isNotEmpty) {
      final again = gpu.gpuContext.createCommandBuffer();
      final backs = again.createRenderPass(target.attachments(target.back, clear: null, keep: false));

      for (final item in doubles) {
        _renderObject(backs, item, scene, camera, BackSide);
      }

      _buffers.submit(again);
      _mipmaps(target.back);
      _target = target.back;
    }

    _frameWidth = frameWidth;
    _frameHeight = frameHeight;
    _intoTarget = into;
  }

  // The shadow pass: each shadow-casting light's casters drawn with a MeshDepthMaterial from the light's shadow camera
  // (orthographic or perspective, six cube faces for a point light) into its map.
  void _renderShadows(Object3D scene, Camera camera) {
    final settings = shadowMap;

    if (!settings.enabled || (!settings.autoUpdate && !settings.needsUpdate) || _list.shadows.isEmpty) {
      return;
    }

    if (settings.type == PCFSoftShadowMap) {
      warn('FlutterGpuRenderer: PCFSoftShadowMap has been removed. Using PCFShadowMap instead.');
      settings.type = PCFShadowMap;
    }

    _shadowing = true;

    try {
      for (final light in _list.shadows) {
        final shadow = _shadowOf(light);

        if (shadow == null) {
          warnOnce('FlutterGpuRenderer: ${light.type} shadows are not supported yet; the light casts none.');
          continue;
        }

        final vsm = settings.type == VSMShadowMap;

        if (light is PointLight && vsm) {
          warnOnce(
            'FlutterGpuRenderer: VSM shadow maps are not supported for PointLights. Use PCF or BasicShadowMap instead.',
          );
          continue;
        }

        if (!shadow.autoUpdate && !shadow.needsUpdate) {
          continue;
        }

        // A point light's six cube faces side by side, each mapSize.x square (in the reference a cube render target).
        final point = light is PointLight;
        final width = point ? shadow.mapSize.x.floor() * 6 : shadow.mapSize.x.floor();
        final height = point ? shadow.mapSize.x.floor() : shadow.mapSize.y.floor();
        var target = _shadowTargets[shadow];

        // A new map updates the shadow camera's projection, in Impeller's depth range.
        if (target == null) {
          prepareShadow(shadow, created: true);
        }

        if (target == null || target.width != width || target.height != height || (target.map != null) != vsm) {
          target = _shadowTargets[shadow] = ShadowTarget(width, height, vsm: vsm);
        }

        final shadowCamera = shadow.camera;
        final layers = (shadowCamera.layers.mask & 0xFFFFFFFE) != 0 ? shadowCamera.layers : camera.layers;
        final commands = gpu.gpuContext.createCommandBuffer();
        final pass = commands.createRenderPass(target.attachments());

        if (light is PointLight) {
          _pointFaces(pass, light, shadow, scene, camera, layers);
        } else {
          shadow.updateMatrices(light);
          _castShadows(pass, scene, scene, camera, shadowCamera, layers, shadow.getFrustum());
        }

        _buffers.submit(commands);

        if (vsm) {
          _blurShadow(shadow, target);
        }

        shadow.needsUpdate = false;
      }
    } finally {
      _shadowing = false;
    }

    settings.needsUpdate = false;
  }

  // VSMPass: the depth in [target] blurred vertically into its pass target, then horizontally into its map, each
  // pass blurSamples samples spread over ± radius texels.
  void _blurShadow(LightShadow shadow, ShadowTarget target) {
    _passes.begin();

    for (final (from, to, horizontal) in [(target.texture, target.pass!, 0.0), (target.pass!, target.map!, 1.0)]) {
      _passes.run(
        to,
        'VsmFragment',
        blocks: {
          'VsmInfo': (block) => block
            ..floats('resolution', [target.width.toDouble(), target.height.toDouble()])
            ..float('radius', shadow.radius)
            ..float('samples', shadow.blurSamples.toDouble())
            ..float('horizontal', horizontal),
        },
        textures: {'shadow_pass': PassTexture(from, horizontal > 0 ? ShadowTarget.linear : ShadowTarget.sampler)},
      );
    }
  }

  // The faces of a point light's shadow map (the reference's shadow pass for a cube render target): the shadow camera
  // at the light, turned to each face's direction and up, its far the light's distance when set, the shadow matrix the
  // translation to the light; face f drawn into columns f × size … (f + 1) × size of the map.
  void _pointFaces(
    gpu.RenderPass pass,
    PointLight light,
    LightShadow shadow,
    Object3D scene,
    Camera camera,
    Layers layers,
  ) {
    final shadowCamera = shadow.camera as PerspectiveCamera;
    final far = light.distance != 0 ? light.distance : shadowCamera.far;

    if (far != shadowCamera.far) {
      shadowCamera.far = far;
      shadowCamera.updateProjectionMatrix();
    }

    final position = Vector3().setFromMatrixPosition(light.matrixWorld);
    final size = shadow.mapSize.x.floor();
    shadow.matrix.makeTranslation(-position.x, -position.y, -position.z);

    for (var face = 0; face < 6; face++) {
      shadowCamera.position.copy(position);
      shadowCamera.up.copy(_cubeUps[face]);
      shadowCamera.lookAt(position.clone().add(_cubeDirections[face]));
      shadowCamera.updateMatrixWorld();
      shadow.getFrustum().setFromProjectionMatrix(
        Matrix4().multiplyMatrices(shadowCamera.projectionMatrix, shadowCamera.matrixWorldInverse),
        shadowCamera.coordinateSystem,
        shadowCamera.reversedDepth,
      );
      pass
        ..setViewport(gpu.Viewport(x: face * size, width: size, height: size))
        ..setScissor(gpu.Scissor(x: face * size, width: size, height: size));
      _castShadows(pass, scene, scene, camera, shadowCamera, layers, shadow.getFrustum());
    }
  }

  // The reference's _cubeDirections and _cubeUps: the view direction and up of each cube face.
  static final List<Vector3> _cubeDirections = [
    Vector3(1, 0, 0),
    Vector3(-1, 0, 0),
    Vector3(0, 1, 0),
    Vector3(0, -1, 0),
    Vector3(0, 0, 1),
    Vector3(0, 0, -1),
  ];

  static final List<Vector3> _cubeUps = [
    Vector3(0, -1, 0),
    Vector3(0, -1, 0),
    Vector3(0, 0, 1),
    Vector3(0, 0, -1),
    Vector3(0, -1, 0),
    Vector3(0, -1, 0),
  ];

  // The shadow pass's objects: shadow-casting meshes in the shadow camera's layers and frustum, per group material.
  // Lines and points are not drawn yet (phase 5). A BatchedMesh's onBeforeShadow culls and sorts its ranges against
  // [shadowCamera] (each cube face's for a point light); _draw then draws them as in the main pass.
  void _castShadows(
    gpu.RenderPass pass,
    Object3D object,
    Object3D scene,
    Camera camera,
    Camera shadowCamera,
    Layers layers,
    Frustum frustum,
  ) {
    if (!object.visible) {
      return;
    }

    if (object is Mesh &&
        object.layers.test(layers) &&
        (object.castShadow || (object.receiveShadow && shadowMap.type == VSMShadowMap)) &&
        (!object.frustumCulled || object.intersectsFrustum(frustum))) {
      _castMesh(pass, object, scene, camera, shadowCamera);
    }

    for (final child in object.children) {
      _castShadows(pass, child, scene, camera, shadowCamera, layers, frustum);
    }
  }

  // One caster drawn from [shadowCamera], per group material.
  void _castMesh(gpu.RenderPass pass, Mesh object, Object3D scene, Camera camera, Camera shadowCamera) {
    object.modelViewMatrix.multiplyMatrices(shadowCamera.matrixWorldInverse, object.matrixWorld);

    final geometry = object.geometry;
    final material = object.material;

    if (material is List) {
      for (final group in geometry.groups) {
        final index = group.materialIndex;
        final m = index is int && index >= 0 && index < material.length ? material[index] as Material? : null;

        if (m != null && m.visible) {
          _castShadow(pass, object, geometry, m, group, scene, camera, shadowCamera);
        }
      }
    } else if (material is Material && material.visible) {
      _castShadow(pass, object, geometry, material, null, scene, camera, shadowCamera);
    }
  }

  // getDepthMaterial and the draw: one shared MeshDepthMaterial takes the caster material's side (shadowSide, or
  // the opposite side), maps, alphaTest and displacement for each draw.
  void _castShadow(
    gpu.RenderPass pass,
    Mesh object,
    BufferGeometry geometry,
    Material material,
    GeometryGroup? group,
    Object3D scene,
    Camera camera,
    Camera shadowCamera,
  ) {
    final surface = _Surface.of(material);

    if (surface.wireframe) {
      warnOnce('FlutterGpuRenderer: wireframe is not supported yet (lines come with phase 5); not drawn.');
      return;
    }

    final depth = _shadowDepth
      ..side = material.shadowSide ?? (shadowMap.type == VSMShadowMap ? material.side : _shadowSides[material.side]!)
      ..alphaMap = surface.alphaMap
      ..alphaTest = material.alphaToCoverage ? 0.5 : material.alphaTest
      ..map = surface.map
      ..displacementMap = surface.displacementMap
      ..displacementScale = surface.displacementScale
      ..displacementBias = surface.displacementBias;

    if (!_warming) {
      object.onBeforeShadow(this, object, camera, shadowCamera, geometry, depth, group);
    }

    _draw(
      pass,
      _depth,
      RenderItem(object, geometry, depth, 0, 0, group),
      object,
      depth,
      depth.side,
      scene,
      shadowCamera,
    );
    if (!_warming) {
      object.onAfterShadow(this, object, camera, shadowCamera, geometry, depth, group);
    }
  }

  // The reference's shadowSide: casters draw the side facing away from the light.
  static const Map<int, int> _shadowSides = {FrontSide: BackSide, BackSide: FrontSide, DoubleSide: DoubleSide};

  // The shadow map of a shadow-casting light, `null` when shadows are not drawn; a light whose map was never rendered
  // reads the default texture.
  gpu.Texture? _shadowMapOf(Light light) {
    if (!shadowMap.enabled) {
      return null;
    }

    final target = _shadowTargets[_shadowOf(light)!];
    return target?.map ?? target?.texture ?? _textures.fallback;
  }

  // The shadow of a light whose shadows are drawn.
  static LightShadow? _shadowOf(Light light) {
    return switch (light) {
      DirectionalLight(:final shadow) => shadow,
      SpotLight(:final shadow) => shadow,
      PointLight(:final shadow) => shadow,
      _ => null,
    };
  }

  // generateMipmap of a 2D render target: each level a box filter of the one above.
  void _mipmaps(gpu.Texture texture) {
    _passes.begin();

    for (var level = 1; level < texture.mipLevelCount; level++) {
      final w = GpuPasses.levelSize(texture.width, level);
      final h = GpuPasses.levelSize(texture.height, level);
      _passes.run(
        texture,
        'MipFragment',
        level: level,
        blocks: {
          'MipInfo': (block) => block
            ..float('source_lod', level - 1.0)
            ..floats('size', [w.toDouble(), h.toDouble()]),
        },
        textures: {
          'source': PassTexture(
            texture,
            gpu.SamplerOptions(minFilter: gpu.MinMagFilter.linear, magFilter: gpu.MinMagFilter.linear),
          ),
        },
      );
    }
  }

  // The background, as the reference adds it to the render list: a texture background on a full-frame plane, a cube or
  // equirectangular one (blurred through a PMREM with backgroundBlurriness) on a box around the camera; `null` for
  // none, a Color, or a map that is not ready.
  _Background? _backgroundOf(Object3D scene) {
    final background = scene is Scene ? scene.background : null;

    if (scene is! Scene || background is! Texture) {
      return null;
    }

    if (!GpuEnvironments.isEnvironment(background)) {
      return background.mapping == UVMapping
          ? _Background(scene, background, null, ColorManagement.getTransfer(background.colorSpace) != SRGBTransfer)
          : null;
    }

    final environment = _environments.get(background, pmrem: scene.backgroundBlurriness > 0);

    if (environment == null) {
      return null;
    }

    // The resolved texture's color space: a PMREM is linear, a converted map keeps the source's.
    final space = environment.pmrem ? LinearSRGBColorSpace : background.colorSpace;
    return _Background(scene, background, environment, ColorManagement.getTransfer(space) != SRGBTransfer);
  }

  void _drawBackground(gpu.RenderPass pass, _Background? background, Camera camera) {
    if (background == null) {
      return;
    }

    final scene = background.scene;
    final environment = background.environment;
    final program = environment == null ? _background : _backgroundCube;
    final variant = program.variant(offset: false);
    final mesh = environment == null ? _plane : _box;

    pass
      ..clearBindings()
      ..bindPipeline(variant.pipeline)
      ..setCullMode(gpu.CullMode.backFace)
      ..setWindingOrder(environment == null ? gpu.WindingOrder.counterClockwise : gpu.WindingOrder.clockwise)
      ..setDepthWriteEnable(false)
      ..setDepthCompareOperation(gpu.CompareFunction.always)
      ..setColorBlendEnable(false)
      ..setColorBlendEquation(gpu.ColorBlendEquation());

    if (environment == null) {
      variant.vertInfo
        ..begin()
        ..mat3('uv_transform', _transform(background.texture));
      variant.fragInfo
        ..begin()
        ..float('intensity', scene.backgroundIntensity);
      variant.bindTexture(pass, 'map', _textures.texture(background.texture), _textures.sampler(background.texture));
    } else {
      // onBeforeRender: the box follows the camera.
      mesh.matrixWorld.copyPosition(camera.matrixWorld);
      mesh.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse, mesh.matrixWorld);
      variant.vertInfo
        ..begin()
        ..floats('projection_matrix', camera.projectionMatrix.elements)
        ..floats('model_view_matrix', mesh.modelViewMatrix.elements)
        ..floats('model_matrix', mesh.matrixWorld.elements);
      variant.fragInfo
        ..begin()
        ..mat3('rotation', _rotation(scene.backgroundRotation, environment).elements)
        ..float('blurriness', scene.backgroundBlurriness)
        ..float('intensity', scene.backgroundIntensity)
        ..flag('pmrem', environment.pmrem)
        ..float('max_lod', environment.maxLod ?? 0);
      variant.bindTexture(pass, 'env_map', environment.texture, environment.sampler);
    }

    variant.outputInfo
      ..begin()
      ..float('tone_mapping', background.toneMapped && !_intoTarget ? _toneMapping().toDouble() : 0)
      ..float('tone_mapping_exposure', toneMappingExposure)
      ..flag('output_srgb', !_intoTarget && ColorManagement.getTransfer(outputColorSpace) == SRGBTransfer);

    for (final block in variant.blocks) {
      block.bind(pass, _buffers);
    }

    _drawGeometry(pass, program, mesh.geometry);
    info.render.calls += 1;
    info.render.triangles += (mesh.geometry.index?.count ?? 0) ~/ 3;
  }

  // The vertex buffers of [program]'s slots and the indexed draw of [geometry], for the renderer's own meshes.
  void _drawGeometry(gpu.RenderPass pass, Program program, BufferGeometry geometry) {
    final index = _geometries.index(geometry)!;
    _geometries.track(geometry);

    for (var slot = 0; slot < program.slots.length; slot++) {
      final stream = _geometries.attribute(geometry, program.slots[slot])!;
      pass.bindVertexBuffer(
        gpu.BufferView(stream.buffer, offsetInBytes: 0, lengthInBytes: stream.lengthInBytes),
        slot: slot,
      );
    }

    pass
      ..bindIndexBuffer(
        gpu.BufferView(index.buffer, offsetInBytes: 0, lengthInBytes: geometry.index!.count * index.bytesPerIndex),
        index.type,
      )
      ..drawIndexed(geometry.index!.count);
  }

  // envMapRotation or backgroundRotation as the reference writes it: the rotation's inverse
  // (transpose), mirrored in x for a cube texture that is not a render target.
  Matrix3 _rotation(Euler rotation, GpuEnvironment environment) {
    final matrix = _matrix3.setFromMatrix4(_matrix4.makeRotationFromEuler(rotation)).transpose();
    return environment.renderTarget ? matrix : matrix.premultiply(_mirror);
  }

  /// Releases every GPU resource the renderer holds.
  void dispose() {
    _geometries.dispose();
    _textures.dispose();
    _environments.dispose();
    _transmission = null;
    _target = null;
    _depthBuffer = null;
    _sampled = null;
    _kept = null;
    _texture = null;
  }

  void _prepareCamera(Camera camera) {
    if (camera.coordinateSystem == WebGPUCoordinateSystem) {
      return;
    }

    camera.coordinateSystem = WebGPUCoordinateSystem;

    if (camera is PerspectiveCamera) {
      camera.updateProjectionMatrix();
    } else if (camera is OrthographicCamera) {
      camera.updateProjectionMatrix();
    }
  }

  /// The program of [material], or `null` (with a one-time warning) for a kind not ported yet.
  Program? _programOf(Material material) {
    return switch (material) {
      MeshBasicMaterial _ => _basic,
      LineDashedMaterial _ => _dashed,
      LineBasicMaterial _ => _basic,
      PointsMaterial _ => _points,
      SpriteMaterial _ => _sprite,
      MeshNormalMaterial _ => _normal,
      MeshLambertMaterial _ => _lambert,
      MeshPhongMaterial _ => _phong,
      MeshToonMaterial _ => _toon,
      MeshMatcapMaterial _ => _matcap,
      HologramMaterial _ => _hologram,
      MeshStandardMaterial _ => _physical,
      MeshDepthMaterial _ => _depth,
      ShadowMaterial _ => _shadow,
      MeshDistanceMaterial _ when distanceLight == null => _unsupported(
        'MeshDistanceMaterial is drawn only into point light shadow maps; objects with it are not drawn.',
      ),
      MeshDistanceMaterial _ => _distance,
      _ => _unsupported('${material.type} is not supported yet; objects with it are not drawn.'),
    };
  }

  // The registered variant of [kind] (a kind of ent_shaders' variants, named by its fragment) that [material]
  // needs on [object]: of its maps, vertex colors (or instance or batch colors) and polygon offset, the flags the
  // kind accepts. A StateError names a variant the shader registry lacks; while [recorded], null instead.
  Program? _variantOf(Program kind, Material material, Object3D object) {
    final surface = _Surface.of(material);
    final accepted = kinds[kind.fragment]!.flags;
    final key = keyOf(
      kind.fragment,
      [
        if (surface.map != null) 'map',
        if (surface.alphaMap != null) 'alpha_map',
        if (surface.aoMap != null) 'ao_map',
        if (surface.lightMap != null) 'light_map',
        if (surface.emissiveMap != null) 'emissive_map',
        if (surface.specularMap != null) 'specular_map',
        if (surface.normalMap != null)
          surface.normalMapType == ObjectSpaceNormalMap ? 'object_normal_map' : 'normal_map',
        // A normal map takes precedence over a bump map (normal_fragment_maps), which the variant then lacks.
        if (surface.bumpMap != null && surface.normalMap == null) 'bump_map',
        if (material is MeshToonMaterial && material.gradientMap != null) 'gradient_map',
        if (material is MeshMatcapMaterial && material.matcap != null) 'matcap',
        if (material is MeshDepthMaterial)
          ?switch (material.depthPacking) {
            RGBADepthPacking => 'rgba_packing',
            RGBDepthPacking => 'rgb_packing',
            RGDepthPacking => 'rg_packing',
            _ => null,
          },
        // The physical maps (named as their samplers) with their layer on, and the layers.
        if (material is MeshStandardMaterial)
          for (var i = 0; i < _physicalMaps.length; i++)
            if (_physicalMap(material, i) != null) _physicalMaps[i],
        if (material is MeshPhysicalMaterial) ...[
          if (material.clearcoat > 0) 'clearcoat',
          if (material.sheen > 0) 'sheen',
          if (material.iridescence > 0) 'iridescence',
          if (material.anisotropy > 0) 'anisotropy',
          if (material.diffuseRoughness > 0) 'diffuse_roughness',
          if (material.transmission > 0) 'transmission',
          if (material.transmission > 0 && material.dispersion > 0) 'dispersion',
        ],
        if (material.polygonOffset) 'polygon_offset',
      ].where(accepted.containsKey),
    );

    recorded?.add(key);

    if (!_variants.containsKey(key) && _library[key] == null) {
      final message =
          'ent_flutter: the shader variant "$key" is not registered; add it to the "variants" of the registry that '
          'pubspec.yaml names in hooks: user_defines: ent_shaders: shaders:, then rebuild.';

      if (recorded == null) {
        throw StateError(message);
      }

      warnOnce('$message Objects with it are not drawn.');
      return null;
    }

    // Its samplers: the kind's, less those its flags add, plus those this variant's flags add.
    return _variants[key] ??= kind.withFragment(key, {
      ...kind.samplers.difference({for (final flag in accepted.values) ?flag.$2}),
      ...samplersOf(key),
    });
  }

  Program? _unsupported(String message) {
    warnOnce('FlutterGpuRenderer: $message');
    return null;
  }

  // Draws one render item, as the reference's renderObject does; [side] in place of the material's (the
  // transmission pass's back faces).
  void _renderObject(gpu.RenderPass pass, RenderItem item, Object3D scene, Camera camera, [int? side]) {
    final object = item.object;
    final override = scene is Scene ? scene.overrideMaterial : null;
    final material = override != null && item.material.allowOverride ? override : item.material;

    if (!object.layers.test(camera.layers)) {
      return;
    }

    if (object is! Mesh && object is! Line && object is! Points && object is! Sprite) {
      warnOnce('FlutterGpuRenderer: ${object.type} is not supported yet; it is not drawn.');
      return;
    }

    if (material case final EffectMaterial effect when _effects.containsKey(effect.runtimeType)) {
      final (registered, program) = _effects[effect.runtimeType]!;

      if (!_warming) {
        object.onBeforeRender(this, scene, camera, item.geometry, material, item.group);
      }

      object.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse, object.matrixWorld);
      _drawEffect(pass, registered, program, item, effect, camera);

      if (!_warming) {
        object.onAfterRender(this, scene, camera, item.geometry, material, item.group);
      }

      return;
    }

    final program = _programOf(material);

    if (program == null) {
      return;
    }

    if (_Surface.of(material).wireframe) {
      warnOnce('FlutterGpuRenderer: wireframe is not supported yet (lines come with phase 5); not drawn.');
      return;
    }

    // compile prepares programs only: the reference calls no render callbacks there.
    if (!_warming) {
      object.onBeforeRender(this, scene, camera, item.geometry, material, item.group);
    }

    object.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse, object.matrixWorld);
    object.normalMatrix.getNormalMatrix(object.modelViewMatrix);

    if (!_warming) {
      material.onBeforeRender(this, scene, camera, item.geometry, object, item.group);
    }

    // A transparent double-sided material is drawn back faces first, then front faces.
    if (side != null) {
      _draw(pass, program, item, object, material, side, scene, camera);
    } else if (material.transparent && material.side == DoubleSide && !material.forceSinglePass) {
      _draw(pass, program, item, object, material, BackSide, scene, camera);
      _draw(pass, program, item, object, material, FrontSide, scene, camera);
    } else {
      _draw(pass, program, item, object, material, material.side, scene, camera);
    }

    if (!_warming) {
      object.onAfterRender(this, scene, camera, item.geometry, material, item.group);
    }
  }

  // An effect material (exception E-POSTPROCESSING): its program over the geometry's position and uv, the material's
  // state and fields, and its textures (with their rows flipped for a render target's texture). Groups and the draw
  // range are not applied: the passes draw one whole triangle.
  void _drawEffect(
    gpu.RenderPass pass,
    Effect effect,
    Program program,
    RenderItem item,
    EffectMaterial material,
    Camera camera,
  ) {
    final geometry = item.geometry;
    final variant = program.variant(offset: false);
    final streams = [for (final slot in effectSlots) _geometries.attribute(geometry, slot)];

    if (streams.contains(null)) {
      warnOnce('FlutterGpuRenderer: ${material.name} needs position and uv attributes; not drawn.');
      return;
    }

    pass
      ..clearBindings()
      ..bindPipeline(variant.pipeline);
    _setMaterial(pass, material, material.side, item.object.matrixWorld.determinant() < 0);

    variant.vertInfo
      ..begin()
      ..floats('projection_matrix', camera.projectionMatrix.elements)
      ..floats('model_view_matrix', item.object.modelViewMatrix.elements);
    final textures = effect.textures(material);
    variant.fragInfo
      ..begin()
      ..flag('flip', switch (textures.first) {
        final Texture texture => topDown(texture),
        null => false,
      });
    variant.outputInfo.begin();
    effect.write(variant, material);

    for (final (i, sampler) in effect.samplers.indexed) {
      if (textures[i] case final Texture map) {
        variant.bindTexture(pass, sampler, _textures.texture(map), _textures.sampler(map));
      } else {
        variant.bindTexture(pass, sampler, _textures.fallback, _nearest);
      }
    }

    for (final block in variant.blocks) {
      block.bind(pass, _buffers);
    }

    for (final (slot, stream) in streams.indexed) {
      pass.bindVertexBuffer(
        gpu.BufferView(stream!.buffer, offsetInBytes: 0, lengthInBytes: stream.lengthInBytes),
        slot: slot,
      );
    }

    final index = _geometries.index(geometry);
    _geometries.track(geometry);

    if (index == null) {
      pass.draw(geometry.getAttribute('position')!.count);
    } else {
      pass
        ..bindIndexBuffer(
          gpu.BufferView(index.buffer, offsetInBytes: 0, lengthInBytes: geometry.index!.count * index.bytesPerIndex),
          index.type,
        )
        ..drawIndexed(geometry.index!.count);
    }

    info.render.calls += 1;
    info.render.triangles += (geometry.index?.count ?? geometry.getAttribute('position')!.count) ~/ 3;
  }

  static Texture? _envMap(Material material) {
    return switch (material) {
      MeshBasicMaterial m => m.envMap,
      MeshLambertMaterial m => m.envMap,
      MeshPhongMaterial m => m.envMap,
      MeshStandardMaterial m => m.envMap,
      _ => null,
    };
  }

  // The kinds that light with scene.environment (the reference's `environment` program parameter).
  static bool _environmental(Material material) {
    return material is MeshStandardMaterial || material is MeshLambertMaterial || material is MeshPhongMaterial;
  }

  // Draws a mesh, line or point object as the reference does, with [side] in place of material.side. Lines are one
  // pixel wide: Flutter GPU has no line width, and WebGL on ANGLE (Metal) draws only width 1 too.
  void _draw(
    gpu.RenderPass pass,
    Program kind,
    RenderItem item,
    Object3D object,
    Material material,
    int side,
    Object3D scene,
    Camera camera,
  ) {
    final geometry = item.geometry;
    final position = geometry.getAttribute('position');
    final index = _geometries.index(geometry);
    _geometries.track(geometry);

    if (position == null || (index == null && position.count == 0)) {
      return;
    }

    // The draw range, narrowed to the group and to the data.
    final range = geometry.drawRange;
    final group = item.group;
    var start = range.start;
    var end = range.start + range.count;

    if (group != null) {
      start = start > group.start ? start : group.start.toDouble();
      end = end < group.start + group.count ? end : (group.start + group.count).toDouble();
    }

    final dataCount = index != null ? geometry.index!.count : position.count;
    start = start > 0 ? start : 0;
    end = end < dataCount ? end : dataCount.toDouble();

    final count = (end - start).floor();

    if (count <= 0) {
      return;
    }

    final morph = _geometries.morph(geometry);
    final base = kinds.containsKey(kind.fragment) ? _variantOf(kind, material, object) : kind;

    if (base == null) {
      return;
    }

    final program = switch (object) {
      SkinnedMesh _ => _skinnedOf(base, object, morph != null),
      InstancedMesh _ => _instancedOf(base, object, morph != null),
      BatchedMesh _ => _batchedOf(base, morph != null),
      _ when morph != null => _morphedOf(base),
      _ => base,
    };
    final variant = program.variant(offset: material.polygonOffset);

    // renderInstances' instance count, and USE_INSTANCING_COLOR (color_fragment multiplies by vColor).
    final instanced = object is InstancedMesh && program.slots.last.instance ? object : null;
    final tint = instanced?.instanceColor != null;

    // Bindings persist across draws: a program with fewer vertex slots would inherit the previous ones.
    pass.clearBindings();
    pass.bindPipeline(variant.pipeline);

    // renderBufferDirect's frontFaceCW: a sprite faces the camera whatever its scale's sign.
    final mirrored = object is! Sprite && object.matrixWorld.determinant() < 0;
    _setMaterial(pass, material, side, mirrored);

    final primitive = switch (object) {
      LineSegments _ => gpu.PrimitiveType.line,
      Line _ => gpu.PrimitiveType.lineStrip,
      Points _ => gpu.PrimitiveType.point,
      _ => gpu.PrimitiveType.triangle,
    };

    pass.setPrimitiveType(primitive);
    assert(() {
      states.add((
        variant,
        _intoTarget,
        _shadowing,
        side,
        mirrored,
        primitive,
        material.depthTest,
        material.depthWrite,
        material.depthFunc,
        material.colorWrite,
        material.transparent,
        material.blending,
        material.premultipliedAlpha,
        (material.blendSrc, material.blendDst, material.blendEquation),
        (material.blendSrcAlpha, material.blendDstAlpha, material.blendEquationAlpha),
      ));
      return true;
    }());

    final surface = _Surface.of(material);
    variant.beginSlots(_lights.textures.length, ltc: _lights.rectArea > 0);

    // The environment of the standard, Lambert and Phong kinds (a PMREM, except for a Lambert or Phong material's own
    // envMap) and its rotation.
    final environment = _environmental(material) && scene is Scene ? scene.environment : null;
    final own = _envMap(material);
    final pmrem = material is MeshStandardMaterial || (_environmental(material) && own == null);
    final env = _environments.get(own ?? environment, pmrem: pmrem);

    _vertexUniforms(pass, variant, object, geometry, material, surface, side, camera, env);

    if (morph != null && variant.morphInfo.size != null) {
      _morphUniforms(pass, variant, object, geometry, material, surface, morph, index == null ? start.floor() : 0);
    }
    _materialUniforms(pass, variant, material, side);

    if (kind == _hologram) {
      variant.fragInfo.flag('is_orthographic', camera is OrthographicCamera);
    }

    if (kind == _basic || kind == _dashed) {
      variant.fragInfo
        ..floats('line_projection', camera.projectionMatrix.elements)
        ..floats('line', [_frameWidth.toDouble(), _frameHeight.toDouble(), object is Line ? 1 : 0]);
    }

    // refreshUniformsDash: the dash test reads the dash and the dash plus the gap.
    if (material is LineDashedMaterial) {
      variant.vertInfo.float('line_scale', material.scale);
      variant.fragInfo
        ..float('dash_size', material.dashSize)
        ..float('total_size', material.dashSize + material.gapSize);
    }

    // refreshUniformsPoints: size × pixel ratio, scale = height / 2, uvTransform from the map; USE_POINTS_UV
    // reads the uv attribute instead of gl_PointCoord (the reference's pointsUvs).
    if (material is PointsMaterial) {
      final map = material.map;
      variant.vertInfo.floats('point', [material.size * _pixelRatio, _height * 0.5, material.sizeAttenuation ? 1 : 0]);
      variant.fragInfo
        ..mat3('uv_transform', _transform(map))
        ..flag('points_uv', geometry.getAttribute('uv') != null && (map != null || material.alphaMap != null))
        ..float('alpha_test', material.alphaTest);
    }

    // refreshUniformsSprites: rotation, the object's center and USE_SIZEATTENUATION; the maps' transforms are
    // written with the vertex uniforms.
    if (material is SpriteMaterial && object is Sprite) {
      final center = object.center;
      variant.vertInfo.floats('sprite', [material.rotation, center.x, center.y, material.sizeAttenuation ? 1 : 0]);
      variant.fragInfo.float('alpha_test', material.alphaTest);
    }

    _mapUniforms(pass, variant, material, surface);

    _normalUniforms(pass, variant, object, geometry, material, surface, side);
    _envUniforms(pass, variant, material, scene, camera, env, own == null && environment != null);
    variant.transmissionInfo
      ..begin()
      ..floats('model_matrix', object.matrixWorld.elements)
      ..floats('projection_matrix', camera.projectionMatrix.elements);
    _outputUniforms(variant.outputInfo, material, surface, scene);
    variant.offsetInfo
      ..begin()
      ..floats('polygon_offset', [material.polygonOffsetFactor, material.polygonOffsetUnits]);

    if (variant.lightInfo.size != null) {
      variant.lightInfo.begin();
      _lights.write(
        variant.lightInfo,
        camera,
        object,
        height: _frameHeight,
        normals: geometry.getAttribute('normal') != null,
      );

      for (var i = 0; i < maxLightTextures; i++) {
        final textures = _lights.textures;

        switch (i < textures.length ? textures[i] : null) {
          case final gpu.Texture map:
            variant.bindTexture(
              pass,
              _lightTextures[i],
              map,
              shadowMap.type == VSMShadowMap ? ShadowTarget.linear : ShadowTarget.sampler,
            );
          case final Texture map:
            _bindTexture(pass, variant, _lightTextures[i], map);
          default:
            _bindTexture(pass, variant, _lightTextures[i], null);
        }
      }
    }

    variant.endSlots(pass, _textures.fallback);

    for (final block in variant.blocks) {
      block.bind(pass, _buffers);
    }

    for (var slot = 0; slot < program.slots.length; slot++) {
      final spec = program.slots[slot];

      // The geometry's colors only for a material with vertexColors: without, the vertex stage reads white, so
      // vertex colors are not a flag of the fragment variant (an object's instance and batch colors multiply it).
      // With vertexColors and no color attribute it reads WebGL's default (0, 0, 0, 1), as the reference does.
      final white = spec.name == 'color' && !material.vertexColors;
      final stream = white ? null : _geometries.attribute(geometry, spec);

      if (instanced != null && (spec.instance || (spec.name == 'color' && tint && !material.vertexColors))) {
        _bindInstanced(pass, slot, spec, instanced, index == null ? count : position.count);
      } else if (stream != null) {
        pass.bindVertexBuffer(
          gpu.BufferView(
            stream.buffer,
            offsetInBytes: index == null ? start.floor() * spec.stride : 0,
            lengthInBytes: index == null ? count * spec.stride : stream.lengthInBytes,
          ),
          slot: slot,
        );
      } else {
        final vertices = index == null ? count : position.count;
        pass.bindVertexBuffer(
          gpu.BufferView(
            _geometries.fallback(spec, vertices, white: white),
            offsetInBytes: 0,
            lengthInBytes: vertices * spec.stride,
          ),
          slot: slot,
        );
      }
    }

    // A kind without the batching variant draws nothing.
    if (object is BatchedMesh) {
      if (variant.batchInfo.size != null) {
        _drawBatched(pass, variant, object, geometry, index, position.count, material.vertexColors);
      }

      return;
    }

    if (object is LineLoop) {
      // GL's LINE_LOOP: a line strip through the range's vertices and back to the first.
      final loop = Uint32List(count + 1);

      for (var i = 0; i < count; i++) {
        loop[i] = index == null ? i : geometry.index!.getX(start.floor() + i).toInt();
      }

      loop[count] = loop[0];
      pass.bindIndexBuffer(_buffers.emplace(ByteData.sublistView(loop)), gpu.IndexType.int32);
      pass.drawIndexed(count + 1);
    } else if (index != null) {
      pass.bindIndexBuffer(
        gpu.BufferView(
          index.buffer,
          offsetInBytes: start.floor() * index.bytesPerIndex,
          lengthInBytes: count * index.bytesPerIndex,
        ),
        index.type,
      );
      pass.drawIndexed(count, instanceCount: instanced?.count ?? 1);
    } else {
      pass.draw(count, instanceCount: instanced?.count ?? 1);
    }

    // As in the reference, an instanced draw of no instances is not counted; triangles count every instance.
    if (instanced?.count == 0) {
      return;
    }

    info.render.calls += 1;

    switch (object) {
      case LineLoop _:
        info.render.lines += count;
      case LineSegments _:
        info.render.lines += count ~/ 2;
      case Line _:
        info.render.lines += count - 1;
      case Points _:
        info.render.points += count;
      default:
        info.render.triangles += (instanced?.count ?? 1) * (count ~/ 3);
    }
  }

  // The instanced attributes, as the reference binds them: the columns of instanceMatrix and instanceColor advance per
  // instance (white without instanceColor), and a white `color` stands for the vertex colors an instanceColor
  // multiplies when the material has none (color_vertex starts vColor at 1).
  void _bindInstanced(gpu.RenderPass pass, int slot, VertexSlot spec, InstancedMesh object, int vertices) {
    final attribute = switch (spec.name) {
      'color' => null,
      'instanceColor' => object.instanceColor,
      _ => object.instanceMatrix,
    };

    if (attribute == null) {
      final count = spec.instance ? object.count : vertices;
      pass.bindVertexBuffer(
        gpu.BufferView(_geometries.ones(spec.size, count), offsetInBytes: 0, lengthInBytes: count * spec.stride),
        slot: slot,
      );
      return;
    }

    // A column of the matrix: the same 64-byte stream from its column's offset.
    final column = attribute == object.instanceMatrix ? int.parse(spec.name.substring(14)) * 16 : 0;
    final stream = _geometries.instance(attribute);
    pass.bindVertexBuffer(
      gpu.BufferView(stream.buffer, offsetInBytes: column, lengthInBytes: stream.lengthInBytes - column),
      slot: slot,
    );
  }

  // The reference's `skinning` program parameter (with `morphTargets`, the combined vertex stage) and object update: a
  // SkinnedMesh draws with the skinning vertex stage, its skeleton updated once per frame (not while compile warms
  // programs, as the reference's compile updates nothing).
  Program _skinnedOf(Program kind, SkinnedMesh object, bool morphed) {
    final skeleton = object.skeleton;

    if (skeleton != null && !_warming && _skeletons[skeleton] != info.render.frame) {
      skeleton.update();
      _skeletons[skeleton] = info.render.frame;
    }

    return (morphed ? kind.skinnedMorphed : kind.skinned) ??
        (_unsupported('${kind.name} has no skinning variant; a SkinnedMesh with it is drawn unskinned.') ?? kind);
  }

  // The reference's `instancing`, `instancingColor` and `instancingMorph` (with `morphTargets`, the combined vertex
  // stage). An InstancedMesh.morphTexture (setMorphAt) gives each instance its own influences. A kind without the
  // variant draws once.
  Program _instancedOf(Program kind, InstancedMesh object, bool morphed) {
    final program = morphed && object.morphTexture != null
        ? kind.instancedMorphTexture
        : (morphed ? kind.instancedMorphed : kind.instanced);
    return program ??
        (_unsupported('${kind.name} has no instancing variant; an InstancedMesh with it is drawn once.') ??
            (morphed ? _morphedOf(kind) : kind));
  }

  // The reference's `batching` and `batchingColor`. A batched geometry's morph attributes are not read (the reference
  // copies only its attributes into the batch), with one warning.
  Program _batchedOf(Program kind, bool morphed) {
    if (morphed) {
      warnOnce('FlutterGpuRenderer: a BatchedMesh geometry has morph attributes; they are not drawn.');
    }

    return kind.batched ??
        (_unsupported('${kind.name} has no batching variant; a BatchedMesh with it is not drawn.') ?? kind);
  }

  // The reference's BatchedMesh path without WEBGL_multi_draw: one draw per range of the last onBeforeRender
  // (BatchedMesh's culled and sorted multiDrawStarts and multiDrawCounts), the range's instance (the indirect texture's
  // entry, getIndirectIndex( gl_DrawID )) matrix and color written into BatchInfo for that draw. A non-indexed batch
  // draws its ranges through a sequential index buffer of its [vertices]. Counted as one call, as multiDrawArraysWEBGL.
  void _drawBatched(
    gpu.RenderPass pass,
    ProgramVariant variant,
    BatchedMesh object,
    BufferGeometry geometry,
    GpuIndex? index,
    int vertices,
    bool vertexColors,
  ) {
    final indirect = (object.indirectTexture.image as DataImage).data as List<int>;
    final matrices = (object.matricesTexture.image as DataImage).data as List<double>;
    final colors = (object.colorsTexture?.image as DataImage?)?.data as List<double>?;
    final bytes = (geometry.index?.array as TypedData?)?.elementSizeInBytes ?? 1;
    final sequence = index == null
        ? _buffers.emplace(ByteData.sublistView(Uint32List.fromList(List.generate(vertices, (i) => i))))
        : null;
    var elements = 0;

    for (var i = 0; i < object.multiDrawCount; i++) {
      final id = indirect[i];
      final start = object.multiDrawStarts[i] ~/ bytes;
      final count = object.multiDrawCounts[i];

      variant.batchInfo
        ..begin()
        ..floats('matrix', matrices.sublist(id * 16, id * 16 + 16))
        ..floats('color', colors?.sublist(id * 4, id * 4 + 4) ?? const [1, 1, 1, 1])
        ..flag('vertex_colors', vertexColors)
        ..bind(pass, _buffers);

      if (sequence != null) {
        pass.bindIndexBuffer(
          gpu.BufferView(sequence.buffer, offsetInBytes: sequence.offsetInBytes + start * 4, lengthInBytes: count * 4),
          gpu.IndexType.int32,
        );
      } else {
        pass.bindIndexBuffer(
          gpu.BufferView(
            index!.buffer,
            offsetInBytes: start * index.bytesPerIndex,
            lengthInBytes: count * index.bytesPerIndex,
          ),
          index.type,
        );
      }

      pass.drawIndexed(count);
      elements += count;
    }

    if (object.multiDrawCount > 0) {
      info.render.calls += 1;
      info.render.triangles += elements ~/ 3;
    }
  }

  // The reference's `morphTargets`: a geometry with morph attributes draws with the morph target vertex stage.
  Program _morphedOf(Program kind) {
    return kind.morphed ??
        (_unsupported('${kind.name} has no morph target variant; objects with morph targets are drawn unmorphed.') ??
            kind);
  }

  // The reference's morph target update and the program's morph parameters: USE_MORPHTARGETS, USE_MORPHNORMALS (not
  // with flat shading), USE_MORPHCOLORS with USE_COLOR or USE_COLOR_ALPHA, MORPHTARGETS_COUNT and the texture stride.
  // Influences past [maxMorphTargets] are dropped (exception E-SHADERS); [first] is the first vertex of a non-indexed
  // range, whose vertex buffers start there.
  void _morphUniforms(
    gpu.RenderPass pass,
    ProgramVariant variant,
    Object3D object,
    BufferGeometry geometry,
    Material material,
    _Surface surface,
    GpuMorph morph,
    int first,
  ) {
    final influences =
        switch (object) {
          Mesh m => m.morphTargetInfluences,
          Line l => l.morphTargetInfluences,
          _ => null,
        } ??
        const <double>[];
    final count = math.min(morph.count, maxMorphTargets);

    if (morph.count > maxMorphTargets) {
      warnOnce('FlutterGpuRenderer: a geometry has more than $maxMorphTargets morph targets; the rest are not drawn.');
    }

    final attributes = geometry.morphAttributes;
    final alpha = geometry.getAttribute('color')?.itemSize == 4;
    final colors = attributes['color'] != null && material.vertexColors ? (alpha ? 2 : 1) : 0;

    variant.morphInfo
      ..begin()
      ..floats('influences', [for (var i = 0; i < count; i++) i < influences.length ? influences[i] : 0])
      ..float('base_influence', geometry.morphTargetsRelative ? 1 : 1 - influences.fold(0.0, (a, b) => a + b))
      ..float('count', count.toDouble())
      ..float('stride', morph.stride.toDouble())
      ..float('width', morph.width.toDouble())
      ..float('rows', morph.rows.toDouble())
      ..float('height', (morph.rows * morph.count).toDouble())
      ..float('first', first.toDouble())
      ..flag('positions', attributes['position'] != null)
      ..flag('normals', attributes['normal'] != null && !surface.flatShading)
      ..float('colors', colors.toDouble());
    variant.bindTexture(pass, 'morph_targets_texture', morph.texture, _nearest, vertex: true);

    // morphinstance_vertex: the per-instance rows of InstancedMesh.morphTexture, in the variant that reads them.
    final rows = object is InstancedMesh ? object.morphTexture : null;

    if (rows != null && variant.morphInfo.has('instance_width')) {
      final image = rows.image as DataImage;
      variant.morphInfo
        ..float('instance_width', image.width!.toDouble())
        ..float('instance_height', image.height!.toDouble());
      _bindTexture(pass, variant, 'morph_texture', rows, vertex: true);
    }
  }

  static final gpu.SamplerOptions _nearest = gpu.SamplerOptions();

  // The pipeline state of a material, as the reference sets it: culling and winding (setFlipSided), blending, depth,
  // color mask.
  void _setMaterial(gpu.RenderPass pass, Material material, int side, bool frontFaceCW) {
    pass.setCullMode(side == DoubleSide ? gpu.CullMode.none : gpu.CullMode.backFace);
    pass.setWindingOrder(
      (side == BackSide) != frontFaceCW ? gpu.WindingOrder.clockwise : gpu.WindingOrder.counterClockwise,
    );

    // With the depth test off, GL neither tests nor writes depth.
    pass.setDepthWriteEnable(material.depthTest && material.depthWrite);
    pass.setDepthCompareOperation(material.depthTest ? _compare(material.depthFunc) : gpu.CompareFunction.always);

    if (!material.colorWrite) {
      // Flutter GPU has no color write mask; blending (ZERO, ONE) keeps the target unchanged.
      pass.setColorBlendEnable(true);
      pass.setColorBlendEquation(
        gpu.ColorBlendEquation(
          sourceColorBlendFactor: gpu.BlendFactor.zero,
          destinationColorBlendFactor: gpu.BlendFactor.one,
          sourceAlphaBlendFactor: gpu.BlendFactor.zero,
          destinationAlphaBlendFactor: gpu.BlendFactor.one,
        ),
      );
      return;
    }

    final blending = material.blending == NormalBlending && !material.transparent ? NoBlending : material.blending;

    if (blending == NoBlending) {
      pass.setColorBlendEnable(false);
      pass.setColorBlendEquation(gpu.ColorBlendEquation());
      return;
    }

    pass.setColorBlendEnable(true);
    _equation = _blendEquation(material, blending) ?? _equation;
    pass.setColorBlendEquation(_equation);
  }

  // The reference's setBlending; `null` where the reference logs an error and keeps the previous blend function.
  static gpu.ColorBlendEquation? _blendEquation(Material material, int blending) {
    const zero = gpu.BlendFactor.zero;
    const one = gpu.BlendFactor.one;
    const oneMinusSrcAlpha = gpu.BlendFactor.oneMinusSourceAlpha;

    gpu.ColorBlendEquation factors(
      gpu.BlendFactor src,
      gpu.BlendFactor dst,
      gpu.BlendFactor srcA,
      gpu.BlendFactor dstA,
    ) {
      return gpu.ColorBlendEquation(
        sourceColorBlendFactor: src,
        destinationColorBlendFactor: dst,
        sourceAlphaBlendFactor: srcA,
        destinationAlphaBlendFactor: dstA,
      );
    }

    if (blending != CustomBlending) {
      if (material.premultipliedAlpha) {
        switch (blending) {
          case NormalBlending:
            return factors(one, oneMinusSrcAlpha, one, oneMinusSrcAlpha);
          case AdditiveBlending:
            return factors(one, one, one, one);
          case SubtractiveBlending:
            return factors(zero, gpu.BlendFactor.oneMinusSourceColor, zero, one);
          case MultiplyBlending:
            return factors(gpu.BlendFactor.destinationColor, oneMinusSrcAlpha, zero, one);
        }

        error('FlutterGpuRenderer: Invalid blending: ', [blending]);
        return null;
      }

      switch (blending) {
        case NormalBlending:
          return factors(gpu.BlendFactor.sourceAlpha, oneMinusSrcAlpha, one, oneMinusSrcAlpha);
        case AdditiveBlending:
          return factors(gpu.BlendFactor.sourceAlpha, one, one, one);
        case SubtractiveBlending:
          error('FlutterGpuRenderer: SubtractiveBlending requires material.premultipliedAlpha = true');
          return null;
        case MultiplyBlending:
          error('FlutterGpuRenderer: MultiplyBlending requires material.premultipliedAlpha = true');
          return null;
      }

      error('FlutterGpuRenderer: Invalid blending: ', [blending]);
      return null;
    }

    final equation = material.blendEquation;
    final equationAlpha = material.blendEquationAlpha ?? equation;

    return gpu.ColorBlendEquation(
      colorBlendOperation: _operation(equation),
      sourceColorBlendFactor: _factor(material.blendSrc),
      destinationColorBlendFactor: _factor(material.blendDst),
      alphaBlendOperation: _operation(equationAlpha),
      sourceAlphaBlendFactor: _factor(material.blendSrcAlpha ?? material.blendSrc),
      destinationAlphaBlendFactor: _factor(material.blendDstAlpha ?? material.blendDst),
    );
  }

  static gpu.BlendOperation _operation(int equation) {
    switch (equation) {
      case SubtractEquation:
        return gpu.BlendOperation.subtract;
      case ReverseSubtractEquation:
        return gpu.BlendOperation.reverseSubtract;
      case MinEquation:
      case MaxEquation:
        warnOnce(
          'FlutterGpuRenderer: MinEquation and MaxEquation are not available on Flutter GPU; using AddEquation.',
        );
    }

    return gpu.BlendOperation.add;
  }

  static gpu.BlendFactor _factor(int factor) {
    switch (factor) {
      case ZeroFactor:
        return gpu.BlendFactor.zero;
      case OneFactor:
        return gpu.BlendFactor.one;
      case SrcColorFactor:
        return gpu.BlendFactor.sourceColor;
      case OneMinusSrcColorFactor:
        return gpu.BlendFactor.oneMinusSourceColor;
      case SrcAlphaFactor:
        return gpu.BlendFactor.sourceAlpha;
      case OneMinusSrcAlphaFactor:
        return gpu.BlendFactor.oneMinusSourceAlpha;
      case DstAlphaFactor:
        return gpu.BlendFactor.destinationAlpha;
      case OneMinusDstAlphaFactor:
        return gpu.BlendFactor.oneMinusDestinationAlpha;
      case DstColorFactor:
        return gpu.BlendFactor.destinationColor;
      case OneMinusDstColorFactor:
        return gpu.BlendFactor.oneMinusDestinationColor;
      case SrcAlphaSaturateFactor:
        return gpu.BlendFactor.sourceAlphaSaturated;
    }

    warnOnce(
      'FlutterGpuRenderer: constant blend factors read Flutter GPU\'s unset blend color, not material.blendColor '
      'and blendAlpha.',
    );

    return switch (factor) {
      ConstantColorFactor => gpu.BlendFactor.blendColor,
      OneMinusConstantColorFactor => gpu.BlendFactor.oneMinusBlendColor,
      ConstantAlphaFactor => gpu.BlendFactor.blendAlpha,
      _ => gpu.BlendFactor.oneMinusBlendAlpha,
    };
  }

  // The vertex uniforms: matrices, uv transforms and channels (refreshTransformUniform), FLIP_SIDED, tangents
  // and the displacement map.
  void _vertexUniforms(
    gpu.RenderPass pass,
    ProgramVariant variant,
    Object3D object,
    BufferGeometry geometry,
    Material material,
    _Surface surface,
    int side,
    Camera camera,
    GpuEnvironment? env,
  ) {
    // envmap_vertex: MeshBasicMaterial's cube map reflects in the vertex stage (no ENV_WORLDPOS).
    final reflect = material is MeshBasicMaterial && env != null && !env.pmrem;

    final displace = surface.displacementMap != null;

    final block = variant.vertInfo
      ..begin()
      ..floats('projection_matrix', camera.projectionMatrix.elements)
      ..floats('model_view_matrix', object.modelViewMatrix.elements)
      ..floats('model_matrix', object.matrixWorld.elements)
      ..mat3('normal_matrix', object.normalMatrix.elements)
      ..float('flip_sided', side == BackSide ? -1 : 1)
      ..flag('use_tangent', _tangents(geometry, material, surface))
      ..float('env_vertex', reflect ? (env.mapping == CubeRefractionMapping ? 2 : 1) : 0)
      ..float('refraction_ratio', material is MeshBasicMaterial ? material.refractionRatio : 0.98)
      ..flag('is_orthographic', camera is OrthographicCamera)
      ..floats('camera_position', _cameraPosition(camera))
      ..floats('view_matrix', camera.matrixWorldInverse.elements)
      ..flag('use_displacement_map', displace)
      ..float('displacement_scale', surface.displacementScale)
      ..float('displacement_bias', surface.displacementBias);

    final maps = [
      surface.map,
      surface.alphaMap,
      surface.aoMap,
      surface.lightMap,
      surface.emissiveMap,
      surface.specularMap,
      surface.bumpMap,
      surface.normalMap,
      surface.displacementMap,
    ];

    for (var i = 0; i < maps.length; i++) {
      block
        ..mat3(_mapMembers[i].$1, _transform(maps[i]))
        ..float(_mapMembers[i].$2, _channel(maps[i]));
    }

    // setProgram's bindMatrix, bindMatrixInverse and boneTexture (computed on first use, as the reference does;
    // re-uploaded when skeleton.update() marks it). Without a skeleton the unbound texture reads (0, 0, 0, 1), as
    // WebGL's.
    if (object is SkinnedMesh) {
      final skeleton = object.skeleton;
      final bones = skeleton == null ? null : (skeleton.boneTexture ?? skeleton.computeBoneTexture().boneTexture);

      variant.skinInfo
        ..begin()
        ..floats('bind_matrix', object.bindMatrix.elements)
        ..floats('bind_matrix_inverse', object.bindMatrixInverse.elements)
        ..float('bone_texture_size', ((bones?.image as DataImage?)?.width ?? 1).toDouble());
      _bindTexture(pass, variant, 'bone_texture', bones, vertex: true);
    }

    // The points and sprite vertex stages (shaders/points.vert, sprite.vert) have no displacement map; the skinned and
    // morphed ones bind it only when there is one.
    if (material is! PointsMaterial &&
        material is! SpriteMaterial &&
        (displace || variant.skinInfo.size == null && variant.morphInfo.size == null)) {
      _bindTexture(pass, variant, 'displacement_map', surface.displacementMap, vertex: true);
    }
  }

  // USE_TANGENT: the reference's vertexTangents (a tangent attribute, and a normal map or anisotropy).
  static bool _tangents(BufferGeometry geometry, Material material, _Surface surface) {
    final anisotropy = material is MeshPhysicalMaterial && material.anisotropy > 0;
    return geometry.getAttribute('tangent') != null && (surface.normalMap != null || anisotropy);
  }

  // cameraPosition: the camera's world position.
  List<double> _cameraPosition(Camera camera) {
    final e = camera.matrixWorld.elements;
    return [e[12], e[13], e[14]];
  }

  static final List<double> _identity = Matrix3().elements;

  static List<double> _transform(Texture? texture) {
    if (texture == null) {
      return _identity;
    }

    if (texture.matrixAutoUpdate) {
      texture.updateMatrix();
    }

    // A render target's rows (and its depth texture's) start at the top here, at the bottom in WebGL: t is flipped
    // (t' = 1 - t).
    return topDown(texture)
        ? (Matrix3()..set(1, 0, 0, 0, -1, 1, 0, 0, 1)).multiply(texture.matrix).elements
        : texture.matrix.elements;
  }

  static double _channel(Texture? texture) {
    final channel = texture?.channel ?? 0;

    if (channel > 1) {
      warnOnce('FlutterGpuRenderer: texture channels above 1 (uv2, uv3) are not supported yet; using uv.');
      return 0;
    }

    return channel.toDouble();
  }

  // The material kind's own uniforms and textures (the reference's refreshMaterialUniforms).
  void _materialUniforms(gpu.RenderPass pass, ProgramVariant variant, Material material, int side) {
    final block = variant.fragInfo..begin();

    switch (material) {
      case MeshStandardMaterial m:
        _physicalUniforms(pass, variant, block, m, side);
      case MeshBasicMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity);
      case LineBasicMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity);
      case PointsMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity);
      case SpriteMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity);
      case MeshNormalMaterial m:
        block.float('opacity', m.opacity);
      case MeshLambertMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity)
          ..floats('emissive', _emissive(m.emissive, m.emissiveIntensity));
      case MeshPhongMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity)
          ..floats('emissive', _emissive(m.emissive, m.emissiveIntensity))
          ..floats('specular', [m.specular.r, m.specular.g, m.specular.b])
          ..float('shininess', m.shininess > 1e-4 ? m.shininess : 1e-4);
      case MeshToonMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity)
          ..floats('emissive', _emissive(m.emissive, m.emissiveIntensity));
        _bindTexture(pass, variant, 'gradient_map', m.gradientMap);
      case MeshMatcapMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity);
        _bindTexture(pass, variant, 'matcap', m.matcap);
      case HologramMaterial m:
        block
          ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity)
          ..float('fill', m.fill)
          ..float('rim', m.rim)
          ..float('rim_power', m.rimPower)
          ..float('scanlines', m.scanlines)
          ..float('scanline_density', m.scanlineDensity)
          ..float('scanline_speed', m.scanlineSpeed)
          ..float('flicker', m.flicker)
          ..float('time', m.time);
      case ShadowMaterial m:
        block
          ..floats('color', [m.color.r, m.color.g, m.color.b])
          ..float('opacity', m.opacity);
      case MeshDepthMaterial m:
        block
          ..float('opacity', m.opacity)
          ..flag('shadow', _shadowing);
      case MeshDistanceMaterial _:
        final light = distanceLight!;
        final camera = light.shadow.camera as PerspectiveCamera;
        final position = Vector3().setFromMatrixPosition(light.matrixWorld);
        block
          ..floats('reference_position', [position.x, position.y, position.z])
          ..float('near_distance', camera.near)
          ..float('far_distance', camera.far);
    }
  }

  // refreshUniformsStandard and refreshUniformsPhysical, the physical maps (uv transforms in UvInfo) and the DFG
  // LUT; each physical layer is on when the reference would define it.
  void _physicalUniforms(
    gpu.RenderPass pass,
    ProgramVariant variant,
    UniformBlock block,
    MeshStandardMaterial m,
    int side,
  ) {
    block
      ..floats('diffuse', [m.color.r, m.color.g, m.color.b])
      ..float('opacity', m.opacity)
      ..floats('emissive', _emissive(m.emissive, m.emissiveIntensity))
      ..float('roughness', m.roughness)
      ..float('metalness', m.metalness)
      ..float('attenuation_distance', double.infinity)
      // MeshStandardMaterial's: the reference's values without PHYSICAL.
      ..float('ior', 1.5)
      ..float('specular_intensity', 1)
      ..floats('specular_color', [1, 1, 1]);

    if (m is MeshPhysicalMaterial) {
      final sheen = m.sheenColor;
      final specular = m.specularColor;
      final attenuation = m.attenuationColor;
      final scale = m.clearcoatNormalScale;
      final sign = side == BackSide ? -1.0 : 1.0;

      block
        ..float('ior', m.ior)
        ..float('specular_intensity', m.specularIntensity)
        ..floats('specular_color', [specular.r, specular.g, specular.b])
        ..float('diffuse_roughness', m.diffuseRoughness > 0 ? m.diffuseRoughness : 0)
        ..float('retroreflectivity', m.retroreflectivity > 0 ? m.retroreflectivity : 0)
        ..float('dispersion', m.dispersion > 0 && m.transmission > 0 ? m.dispersion : 0);

      if (m.clearcoat > 0) {
        block
          ..float('clearcoat', m.clearcoat)
          ..float('clearcoat_roughness', m.clearcoatRoughness)
          ..floats('clearcoat_normal_scale', [scale.x * sign, scale.y * sign]);
      }

      if (m.iridescence > 0) {
        block
          ..float('iridescence', m.iridescence)
          ..float('iridescence_ior', m.iridescenceIOR)
          ..float('iridescence_thickness_minimum', m.iridescenceThicknessMinimum)
          ..float('iridescence_thickness_maximum', m.iridescenceThicknessMaximum);
      }

      if (m.sheen > 0) {
        block
          ..floats('sheen_color', [sheen.r * m.sheen, sheen.g * m.sheen, sheen.b * m.sheen])
          ..float('sheen_roughness', m.sheenRoughness);
      }

      if (m.anisotropy > 0) {
        final rotation = m.anisotropyRotation;
        block.floats('anisotropy_vector', [m.anisotropy * math.cos(rotation), m.anisotropy * math.sin(rotation)]);
      }

      final target = _target;

      if (m.transmission > 0) {
        block
          ..float('transmission', m.transmission)
          ..float('thickness', m.thickness)
          ..float('attenuation_distance', m.attenuationDistance)
          ..floats('attenuation_color', [attenuation.r, attenuation.g, attenuation.b])
          ..floats('transmission_size', [(target?.width ?? 1).toDouble(), (target?.height ?? 1).toDouble()]);
      }

      variant.bindTexture(
        pass,
        'transmission_sampler_map',
        m.transmission > 0 && target != null ? target : _textures.fallback,
        _TransmissionTarget.sampler,
      );
    } else {
      variant.bindTexture(pass, 'transmission_sampler_map', _textures.fallback, gpu.SamplerOptions());
    }

    final uv = variant.uvInfo..begin();
    final channels = List<double>.filled(16, 0);

    for (var i = 0; i < _physicalMaps.length; i++) {
      final map = _physicalMap(m, i);
      channels[i] = _channel(map);
      uv.floats('transform', _mat4(_transform(map)), 16 * i);
      _bindTexture(pass, variant, _physicalMaps[i], map);
    }

    uv.floats('channel', channels);
    _bindTexture(pass, variant, 'dfg_lut', dfgLut());

    // The reference's rectAreaLTC1 and rectAreaLTC2, set while the frame has rect area lights.
    if (_lights.rectArea > 0) {
      _bindTexture(pass, variant, 'ltc_1', ltcTextures[0]);
      _bindTexture(pass, variant, 'ltc_2', ltcTextures[1]);
    }
  }

  static List<double> _mat4(List<double> e) => [
    e[0],
    e[1],
    e[2],
    0,
    e[3],
    e[4],
    e[5],
    0,
    e[6],
    e[7],
    e[8],
    0,
    0,
    0,
    0,
    1,
  ];

  static List<double> _emissive(Color emissive, double intensity) {
    return [emissive.r * intensity, emissive.g * intensity, emissive.b * intensity];
  }

  // The shared maps (shaders/maps.glsl): map, alphaMap, alphaTest, aoMap, lightMap, emissiveMap, specularMap.
  void _mapUniforms(gpu.RenderPass pass, ProgramVariant variant, Material material, _Surface surface) {
    variant.mapInfo
      ..begin()
      ..float('alpha_test', material.alphaTest > 0 && material is! LineDashedMaterial ? material.alphaTest : 0)
      ..float('ao_map_intensity', surface.aoMapIntensity)
      ..float('light_map_intensity', surface.lightMapIntensity);

    for (final (name, texture) in [
      ('map', surface.map),
      ('alpha_map', surface.alphaMap),
      ('ao_map', surface.aoMap),
      ('light_map', surface.lightMap),
      ('emissive_map', surface.emissiveMap),
      ('specular_map', surface.specularMap),
    ]) {
      _bindTexture(pass, variant, name, texture);
    }
  }

  // The shading normal (shaders/normals.glsl): DOUBLE_SIDED, FLAT_SHADED, FLIP_SIDED, normal and bump maps, with
  // normalScale and bumpScale negated for BackSide as refreshUniformsCommon does.
  void _normalUniforms(
    gpu.RenderPass pass,
    ProgramVariant variant,
    Object3D object,
    BufferGeometry geometry,
    Material material,
    _Surface surface,
    int side,
  ) {
    final sign = side == BackSide ? -1.0 : 1.0;
    final scale = surface.normalScale;

    variant.normalInfo
      ..begin()
      ..mat3('normal_matrix', object.normalMatrix.elements)
      ..floats('normal_scale', [scale.x * sign, scale.y * sign])
      ..float('bump_scale', surface.bumpScale * sign)
      ..flag('double_sided', side == DoubleSide)
      ..flag('flat_shaded', surface.flatShading || _flat(material, geometry, surface))
      ..flag('flip_sided', side == BackSide)
      ..flag('use_tangent', _tangents(geometry, material, surface));

    _bindTexture(pass, variant, 'normal_map', surface.normalMap);
    _bindTexture(pass, variant, 'bump_map', surface.bumpMap);
  }

  // The reference's flatShading without a normal attribute (or normal map) for the lit kinds.
  static bool _flat(Material material, BufferGeometry geometry, _Surface surface) {
    final lit = material is MeshLambertMaterial || material is MeshPhongMaterial || material is MeshStandardMaterial;
    return lit && geometry.getAttribute('normal') == null && surface.normalMap == null && !surface.wireframe;
  }

  // envmap_common_pars_fragment and envmap_pars_fragment: the environment of the draw (EnvInfo), with
  // scene.environmentIntensity and environmentRotation when it is the scene's.
  void _envUniforms(
    gpu.RenderPass pass,
    ProgramVariant variant,
    Material material,
    Object3D scene,
    Camera camera,
    GpuEnvironment? env,
    bool fromScene,
  ) {
    final block = variant.envInfo
      ..begin()
      ..floats('view_matrix', camera.matrixWorldInverse.elements)
      ..floats('camera_position', _cameraPosition(camera))
      ..flag('is_orthographic', camera is OrthographicCamera);

    if (env != null && variant.envInfo.size != null) {
      final rotation = fromScene ? (scene as Scene).environmentRotation : _envMapRotation(material);
      final (combine, reflectivity, ratio) = switch (material) {
        MeshBasicMaterial m => (m.combine, m.reflectivity, m.refractionRatio),
        MeshLambertMaterial m => (m.combine, m.reflectivity, m.refractionRatio),
        MeshPhongMaterial m => (m.combine, m.reflectivity, m.refractionRatio),
        MeshPhysicalMaterial m => (MultiplyOperation, m.reflectivity, 0.98),
        _ => (MultiplyOperation, 1.0, 0.98),
      };

      block
        ..mat3('env_rotation', _rotation(rotation, env).elements)
        ..float('env_type', env.pmrem ? 2 : 1)
        ..float('env_intensity', fromScene ? (scene as Scene).environmentIntensity : _envMapIntensity(material))
        ..float('env_max_lod', env.maxLod ?? 0)
        ..float('reflectivity', reflectivity)
        ..float('refraction_ratio', ratio)
        ..flag('env_refraction', env.mapping == CubeRefractionMapping)
        ..float('combine', combine.toDouble())
        ..flag('world_position', material is MeshLambertMaterial || material is MeshPhongMaterial);
    }

    if (variant.reads('env_map')) {
      variant.bindTexture(
        pass,
        'env_map',
        env?.texture ?? _textures.fallbackCube,
        env?.sampler ?? gpu.SamplerOptions(),
      );
    }
  }

  static Euler _envMapRotation(Material material) {
    return switch (material) {
      MeshBasicMaterial m => m.envMapRotation,
      MeshLambertMaterial m => m.envMapRotation,
      MeshPhongMaterial m => m.envMapRotation,
      MeshStandardMaterial m => m.envMapRotation,
      _ => Euler(),
    };
  }

  static double _envMapIntensity(Material material) {
    return switch (material) {
      MeshLambertMaterial m => m.envMapIntensity,
      MeshPhongMaterial m => m.envMapIntensity,
      MeshStandardMaterial m => m.envMapIntensity,
      _ => 1,
    };
  }

  void _bindTexture(gpu.RenderPass pass, ProgramVariant variant, String name, Texture? texture, {bool vertex = false}) {
    // A slotted stage reads a 2D sampler without a texture as the fallback (opaque black) without binding one.
    if (texture == null && !vertex && variant.slotted && name != 'env_map') {
      return;
    }

    // A 2D texture of the physical program found no free slot (maxTextureSlots): the draw cannot show it.
    if (!variant.bindTexture(
      pass,
      name,
      texture == null ? _textures.fallback : _textures.texture(texture),
      texture == null ? gpu.SamplerOptions() : _textures.sampler(texture),
      vertex: vertex,
    )) {
      throw StateError(
        'ent_flutter: a MeshStandardMaterial or MeshPhysicalMaterial draw needs more than $maxTextureSlots 2D '
        'textures (its maps, the shadow and spot light maps in use, the DFG table, the transmission target); its '
        '$name finds no free slot. Give the material fewer textures (maps with the same texture share a slot), or the '
        'scene fewer shadow-casting lights.',
      );
    }
  }

  // The end of the fragment stages that include output.glsl: OPAQUE, PREMULTIPLIED_ALPHA, tone mapping, output
  // color space and fog.
  void _outputUniforms(UniformBlock block, Material material, _Surface surface, Object3D scene) {
    final fog = scene is Scene ? scene.fog : null;

    block
      ..begin()
      ..flag('opaque', !material.transparent && material.blending == NormalBlending && !material.alphaToCoverage)
      ..flag('premultiplied_alpha', material.premultipliedAlpha)
      ..float('tone_mapping', material.toneMapped && !_intoTarget ? _toneMapping().toDouble() : 0)
      ..float('tone_mapping_exposure', toneMappingExposure)
      ..flag('output_srgb', !_intoTarget && ColorManagement.getTransfer(outputColorSpace) == SRGBTransfer);

    if (surface.fog && (fog is Fog || fog is FogExp2)) {
      final space = _intoTarget ? LinearSRGBColorSpace : outputColorSpace;
      final color = (fog is Fog ? fog.color : (fog as FogExp2).color).getRGB(_rgb, space);
      block.floats('fog_color', [color.r, color.g, color.b]);

      if (fog is Fog) {
        block
          ..float('fog_mode', 1)
          ..float('fog_near', fog.near)
          ..float('fog_far', fog.far);
      } else if (fog is FogExp2) {
        block
          ..float('fog_mode', 2)
          ..float('fog_density', fog.density);
      }
    }
  }

  // getToneMappingFunction: an unknown constant warns and uses LinearToneMapping.
  int _toneMapping() {
    if (toneMapping < NoToneMapping || toneMapping > NeutralToneMapping) {
      warn('FlutterGpuRenderer: Unsupported toneMapping:', [toneMapping]);
      return LinearToneMapping;
    }

    return toneMapping;
  }

  static gpu.CompareFunction _compare(int depthFunc) {
    return switch (depthFunc) {
      NeverDepth => gpu.CompareFunction.never,
      AlwaysDepth => gpu.CompareFunction.always,
      LessDepth => gpu.CompareFunction.less,
      EqualDepth => gpu.CompareFunction.equal,
      GreaterEqualDepth => gpu.CompareFunction.greaterEqual,
      GreaterDepth => gpu.CompareFunction.greater,
      NotEqualDepth => gpu.CompareFunction.notEqual,
      _ => gpu.CompareFunction.lessEqual,
    };
  }
}

/// What the reference's programs and refreshUniformsCommon read from a mesh material besides its kind's own
/// uniforms: the shared maps, vertex colors, flat shading, fog and wireframe. A kind without a property keeps the
/// default (its shader in the reference does not include the chunk).
class _Surface {
  _Surface({
    this.map,
    this.alphaMap,
    this.aoMap,
    this.aoMapIntensity = 1,
    this.lightMap,
    this.lightMapIntensity = 1,
    this.emissiveMap,
    this.specularMap,
    this.bumpMap,
    this.bumpScale = 1,
    this.normalMap,
    this.normalMapType = TangentSpaceNormalMap,
    Vector2? normalScale,
    this.displacementMap,
    this.displacementScale = 1,
    this.displacementBias = 0,
    this.flatShading = false,
    this.fog = false,
    this.wireframe = false,
  }) : normalScale = normalScale ?? Vector2(1, 1);

  static _Surface of(Material material) {
    return switch (material) {
      MeshBasicMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        aoMap: m.aoMap,
        aoMapIntensity: m.aoMapIntensity,
        lightMap: m.lightMap,
        lightMapIntensity: m.lightMapIntensity,
        specularMap: m.specularMap,
        fog: m.fog,
        wireframe: m.wireframe,
      ),
      MeshLambertMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        aoMap: m.aoMap,
        aoMapIntensity: m.aoMapIntensity,
        lightMap: m.lightMap,
        lightMapIntensity: m.lightMapIntensity,
        emissiveMap: m.emissiveMap,
        specularMap: m.specularMap,
        bumpMap: m.bumpMap,
        bumpScale: m.bumpScale,
        normalMap: m.normalMap,
        normalMapType: m.normalMapType,
        normalScale: m.normalScale,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
        flatShading: m.flatShading,
        fog: m.fog,
        wireframe: m.wireframe,
      ),
      MeshPhongMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        aoMap: m.aoMap,
        aoMapIntensity: m.aoMapIntensity,
        lightMap: m.lightMap,
        lightMapIntensity: m.lightMapIntensity,
        emissiveMap: m.emissiveMap,
        specularMap: m.specularMap,
        bumpMap: m.bumpMap,
        bumpScale: m.bumpScale,
        normalMap: m.normalMap,
        normalMapType: m.normalMapType,
        normalScale: m.normalScale,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
        flatShading: m.flatShading,
        fog: m.fog,
        wireframe: m.wireframe,
      ),
      MeshToonMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        aoMap: m.aoMap,
        aoMapIntensity: m.aoMapIntensity,
        lightMap: m.lightMap,
        lightMapIntensity: m.lightMapIntensity,
        emissiveMap: m.emissiveMap,
        bumpMap: m.bumpMap,
        bumpScale: m.bumpScale,
        normalMap: m.normalMap,
        normalMapType: m.normalMapType,
        normalScale: m.normalScale,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
        fog: m.fog,
        wireframe: m.wireframe,
      ),
      MeshStandardMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        aoMap: m.aoMap,
        aoMapIntensity: m.aoMapIntensity,
        lightMap: m.lightMap,
        lightMapIntensity: m.lightMapIntensity,
        emissiveMap: m.emissiveMap,
        bumpMap: m.bumpMap,
        bumpScale: m.bumpScale,
        normalMap: m.normalMap,
        normalMapType: m.normalMapType,
        normalScale: m.normalScale,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
        flatShading: m.flatShading,
        fog: m.fog,
        wireframe: m.wireframe,
      ),
      MeshMatcapMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        bumpMap: m.bumpMap,
        bumpScale: m.bumpScale,
        normalMap: m.normalMap,
        normalMapType: m.normalMapType,
        normalScale: m.normalScale,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
        flatShading: m.flatShading,
        fog: m.fog,
        wireframe: m.wireframe,
      ),
      MeshNormalMaterial m => _Surface(
        bumpMap: m.bumpMap,
        bumpScale: m.bumpScale,
        normalMap: m.normalMap,
        normalMapType: m.normalMapType,
        normalScale: m.normalScale,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
        flatShading: m.flatShading,
        wireframe: m.wireframe,
      ),
      HologramMaterial m => _Surface(fog: m.fog),
      LineBasicMaterial m => _Surface(map: m.map, fog: m.fog),
      PointsMaterial m => _Surface(map: m.map, alphaMap: m.alphaMap, fog: m.fog),
      SpriteMaterial m => _Surface(map: m.map, alphaMap: m.alphaMap, fog: m.fog),
      ShadowMaterial m => _Surface(fog: m.fog),
      MeshDepthMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
        wireframe: m.wireframe,
      ),
      MeshDistanceMaterial m => _Surface(
        map: m.map,
        alphaMap: m.alphaMap,
        displacementMap: m.displacementMap,
        displacementScale: m.displacementScale,
        displacementBias: m.displacementBias,
      ),
      _ => _Surface(),
    };
  }

  final Texture? map;

  final Texture? alphaMap;

  final Texture? aoMap;

  final double aoMapIntensity;

  final Texture? lightMap;

  final double lightMapIntensity;

  final Texture? emissiveMap;

  final Texture? specularMap;

  final Texture? bumpMap;

  final double bumpScale;

  final Texture? normalMap;

  final int normalMapType;

  final Vector2 normalScale;

  final Texture? displacementMap;

  final double displacementScale;

  final double displacementBias;

  final bool flatShading;

  final bool fog;

  final bool wireframe;
}

/// A texture or cube background of a frame (the reference's background plane or box).
class _Background {
  _Background(this.scene, this.texture, this.environment, this.toneMapped);

  final Scene scene;

  final Texture texture;

  /// The cube map (or PMREM) of a cube or equirectangular background; `null` for the plane.
  final GpuEnvironment? environment;

  /// Whether the material is tone mapped: the resolved texture's color space is not sRGB.
  final bool toneMapped;
}

/// The transmission render target: 4× multisampled color and depth, resolved into HalfFloatType textures with
/// mip levels (LinearMipmapLinearFilter, generateMipmaps): [texture] for the opaque objects, [back] when the back
/// faces of double-sided transmissive objects are added.
class _TransmissionTarget {
  _TransmissionTarget(this.width, this.height)
    : samples = _create(width, height, gpu.PixelFormat.r16g16b16a16Float, 4),
      depth = _create(width, height, gpu.gpuContext.defaultDepthStencilFormat, 4),
      texture = _resolve(width, height),
      back = _resolve(width, height);

  final int width;

  final int height;

  final gpu.Texture samples;

  final gpu.Texture depth;

  final gpu.Texture texture;

  final gpu.Texture back;

  static final gpu.SamplerOptions sampler = gpu.SamplerOptions(
    minFilter: gpu.MinMagFilter.linear,
    magFilter: gpu.MinMagFilter.linear,
    mipFilter: gpu.MipFilter.linear,
  );

  static gpu.Texture _create(int width, int height, gpu.PixelFormat format, int samples) {
    return gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      format: format,
      sampleCount: samples,
      enableShaderReadUsage: false,
    );
  }

  static gpu.Texture _resolve(int width, int height) {
    return gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      format: gpu.PixelFormat.r16g16b16a16Float,
      mipLevelCount: math.min(math.max(width, height).bitLength, gpu.Texture.fullMipCount(width, height)),
    );
  }

  /// The attachments of a pass resolving into [resolve]: cleared to [clear], or loading the samples of the last
  /// pass when it is `null`; with [keep] the samples and depth are stored for a later pass.
  gpu.RenderTarget attachments(gpu.Texture resolve, {required vm.Vector4? clear, required bool keep}) {
    return gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: samples,
        resolveTexture: resolve,
        loadAction: clear == null ? gpu.LoadAction.load : gpu.LoadAction.clear,
        storeAction: keep ? gpu.StoreAction.storeAndMultisampleResolve : gpu.StoreAction.multisampleResolve,
        clearValue: clear,
      ),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depth,
        depthLoadAction: clear == null ? gpu.LoadAction.load : gpu.LoadAction.clear,
        depthStoreAction: keep ? gpu.StoreAction.store : gpu.StoreAction.dontCare,
        depthClearValue: 1,
      ),
    );
  }
}
