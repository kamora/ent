// Replays fixtures/values/effect_composer.json (the reference's EffectComposer, RenderPass, ShaderPass and OutputPass
// in Node with a recording renderer, `node tool/reference/js/effect_composer.mjs`): each scenario runs here with the
// Dart composer and the same recording renderer, and the logs must be equal line for line (render targets named by
// first use, the passes' render calls, swaps, sizes, clears and defines).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// A number as JavaScript prints it in a template string (1, not 1.0).
String _js(Object? value) {
  if (value is double && value == value.truncateToDouble()) {
    return '${value.toInt()}';
  }

  return '$value';
}

// Whether the recorders made from now on keep a target's color between renders, as the reference renderer does (its log
// unchanged).
var _loads = false;

/// The recording renderer of effect_composer.mjs: draws nothing, logs every call the passes make.
class _Recorder implements EffectComposerRenderer {
  _Recorder(this._width, this._height, this._ratio);

  final double _width;

  final double _height;

  final double _ratio;

  final List<String> log = [];

  final Map<RenderTarget, String> _ids = {};

  final Color _clearColor = Color(0x000000);

  double _clearAlpha = 1;

  RenderTarget? _current;

  @override
  bool autoClear = true;

  @override
  bool autoClearColor = true;

  @override
  bool autoClearDepth = true;

  @override
  bool autoClearStencil = true;

  @override
  int toneMapping = NoToneMapping;

  @override
  double toneMappingExposure = 1;

  @override
  String outputColorSpace = SRGBColorSpace;

  @override
  bool loadKeepsColor = _loads;

  // TuningPass's copy of its input (exception E-POSTPROCESSING) is named apart, so the reference's targets keep
  // their ids.
  String id(RenderTarget? target) => switch (target) {
    null => 'screen',
    RenderTarget(texture: Texture(name: 'TuningPass.base')) => 'base',
    _ => _ids.putIfAbsent(target, () => 'T${_ids.length}'),
  };

  @override
  int get coordinateSystem => WebGLCoordinateSystem;

  @override
  int getActiveCubeFace() => 0;

  @override
  int getActiveMipmapLevel() => 0;

  @override
  double getPixelRatio() => _ratio;

  @override
  Vector2 getSize(Vector2 target) => target.set(_width, _height);

  @override
  RenderTarget? getRenderTarget() => _current;

  @override
  void setRenderTarget(RenderTarget? target, [int activeCubeFace = 0, int activeMipmapLevel = 0]) {
    _current = target;
    log.add('setRenderTarget ${id(target)}');
  }

  @override
  Color getClearColor(Color target) => target.copy(_clearColor);

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

  @override
  void clear([bool color = true, bool depth = true, bool stencil = true]) {
    log.add('clear $color $depth $stencil');
  }

  @override
  void clearDepth() {
    log.add('clearDepth');
  }

  // A uniform's value as effect_composer.mjs `format` writes it.
  String _format(Object? value) => switch (value) {
    final List<Object?> list => '[${list.map(_format).join(';')}]',
    final Texture t => id(t.renderTarget),
    final Vector2 v => '${_js(v.x)},${_js(v.y)}',
    final Vector3 v => '${_js(v.x)},${_js(v.y)},${_js(v.z)}',
    final Color c => c.getHexString(),
    _ => _js(value),
  };

  @override
  Object? render(Object3D scene, Camera camera) {
    final state = 'autoClear=$autoClear clear=${_clearColor.getHexString()}/${_js(_clearAlpha)} into=${id(_current)}';

    if (scene is Scene) {
      log.add('render scene ${scene.name} ${camera.type} override=${scene.overrideMaterial?.name ?? '-'} $state');
    } else {
      final material = (scene as Mesh).material as EffectMaterial;
      final (defines, uniforms) = _reference(material);
      log.add(
        'render quad ${material.type} ${camera.type} defines=${(defines.keys.toList()..sort()).join(',')} '
        'blending=${material.blending} '
        '${[for (final key in uniforms.keys.toList()..sort()) '$key=${_format(uniforms[key])}'].join(' ')} $state',
      );
    }

    return null;
  }
}

/// A pass that logs its setSize and render calls (effect_composer.mjs `Probe`).
class _Probe extends Pass {
  _Probe(this.name, this.log, [bool swap = true]) {
    needsSwap = swap;
  }

  final String name;

  final List<String> log;

  @override
  void setSize(int width, int height) {
    log.add('setSize $name $width $height');
  }

  @override
  void render(
    EffectComposerRenderer renderer,
    WebGLRenderTarget writeBuffer,
    WebGLRenderTarget readBuffer, [
    double? deltaTime,
    bool? maskActive,
  ]) {
    final r = renderer as _Recorder;
    log.add(
      'probe $name write=${r.id(writeBuffer)} read=${r.id(readBuffer)} dt=${_js(deltaTime)} mask=$maskActive '
      'screen=$renderToScreen',
    );
  }
}

void _targets(EffectComposer composer, _Recorder renderer) {
  for (final (key, target) in [
    ('rt1', composer.renderTarget1),
    ('rt2', composer.renderTarget2),
    ('write', composer.writeBuffer),
    ('read', composer.readBuffer),
  ]) {
    renderer.log.add(
      '$key ${renderer.id(target)} ${target.width}x${target.height} type=${target.texture.type} '
      'name=${target.texture.name}',
    );
  }
}

// The reference's tone mapping defines (OutputPass).
const Map<int, String> _toneMappings = {
  LinearToneMapping: 'LINEAR_TONE_MAPPING',
  ReinhardToneMapping: 'REINHARD_TONE_MAPPING',
  CineonToneMapping: 'CINEON_TONE_MAPPING',
  ACESFilmicToneMapping: 'ACES_FILMIC_TONE_MAPPING',
  AgXToneMapping: 'AGX_TONE_MAPPING',
  NeutralToneMapping: 'NEUTRAL_TONE_MAPPING',
  CustomToneMapping: 'CUSTOM_TONE_MAPPING',
};

/// An effect material as the reference's shader material: its defines and its uniforms by their names.
(Map<String, Object?>, Map<String, Object?>) _reference(EffectMaterial material) => switch (material) {
  CopyMaterial m => (const {}, {'opacity': m.opacity, 'tDiffuse': m.map}),
  OutputMaterial m => (
    {
      if (ColorManagement.getTransfer(m.outputColorSpace) == SRGBTransfer) 'SRGB_TRANSFER': '',
      if (_toneMappings[m.toneMapping] case final String define) define: '',
    },
    {'tDiffuse': m.map, 'toneMappingExposure': m.toneMappingExposure},
  ),
  VignetteMaterial m => (const {}, {'darkness': m.darkness, 'offset': m.offset, 'tDiffuse': m.map}),
  FXAAMaterial m => (const {}, {'resolution': m.resolution, 'tDiffuse': m.map}),
  HighPassMaterial m => (
    const {},
    {
      'defaultColor': m.defaultColor,
      'defaultOpacity': m.defaultOpacity,
      'luminosityThreshold': m.threshold,
      'smoothWidth': m.smoothWidth,
      'tDiffuse': m.map,
    },
  ),
  BlurMaterial m => (
    {'KERNEL_PAIRS': m.offsets.length},
    {
      'centerWeight': m.centerWeight,
      'colorTexture': m.map,
      'direction': m.direction,
      'gaussianOffsets': m.offsets,
      'gaussianWeights': m.weights,
      'invSize': m.invSize,
    },
  ),
  BloomMaterial m => (
    {'NUM_MIPS': m.maps.length},
    {
      'bloomFactors': m.factors,
      'bloomRadius': m.radius,
      'bloomStrength': m.strength,
      'bloomTintColors': m.tints,
      for (final (i, map) in m.maps.indexed) 'blurTexture${i + 1}': map,
    },
  ),
  _ => throw StateError('no reference for ${material.type}'),
};

// The reference's name for a full-screen quad's material, from its line: ShaderPass's materials are named after their
// shader, TuningPass's are not.
String _type(String line) => switch (line) {
  _ when line.contains('render quad CopyShader ') => 'CopyMaterial',
  _ when line.contains('render quad VignetteShader ') => 'VignetteMaterial',
  _ when line.contains('render quad FXAAShader ') => 'FXAAMaterial',
  _ when line.contains('render quad OutputShader ') => 'OutputMaterial',
  _ when line.contains('luminosityThreshold=') => 'HighPassMaterial',
  _ when line.contains('defines=KERNEL_PAIRS ') => 'BlurMaterial',
  _ when line.contains('defines=NUM_MIPS ') => 'BloomMaterial',
  _ => 'CopyMaterial',
};

final Map<String, List<String> Function()> _scenarios = {
  'chain': () {
    final renderer = _Recorder(64, 32, 2)
      ..toneMapping = ACESFilmicToneMapping
      ..toneMappingExposure = 1.5;
    final composer = EffectComposer(renderer);
    _targets(composer, renderer);
    final copy = CopyPass()..material.opacity = 0.5;
    composer
      ..addPass(RenderPass(Scene()..name = 'main', PerspectiveCamera()))
      ..addPass(copy)
      ..addPass(VignettePass()..enabled = false)
      ..addPass(OutputPass());
    renderer.log.add('last ${[0, 1, 2, 3].map(composer.isLastEnabledPass).join(',')}');
    composer
      ..render(0.25)
      ..render(0.25);
    _targets(composer, renderer);
    return renderer.log;
  },
  'offscreen': () {
    final renderer = _Recorder(10, 10, 1);
    final composer = EffectComposer(renderer)..renderToScreen = false;
    composer
      ..addPass(RenderPass(Scene(), OrthographicCamera()))
      ..addPass(VignettePass()..clear = true)
      ..addPass(OutputPass())
      ..render(0);
    _targets(composer, renderer);
    return renderer.log;
  },
  'sizes': () {
    final renderer = _Recorder(40, 20, 1);
    final composer = EffectComposer(renderer);
    final a = _Probe('a', renderer.log);
    final c = _Probe('c', renderer.log);
    composer
      ..addPass(a)
      ..addPass(c)
      ..insertPass(_Probe('b', renderer.log, false), 1)
      ..setPixelRatio(2)
      ..setSize(30, 12);
    _targets(composer, renderer);
    composer.render(1);
    c.enabled = false;
    composer
      ..render(1)
      ..removePass(a)
      ..removePass(a)
      ..render(1);
    renderer.log.add('passes ${composer.passes.map((p) => (p as _Probe).name).join(',')}');
    composer.swapBuffers();
    _targets(composer, renderer);
    return renderer.log;
  },
  'reset': () {
    final renderer = _Recorder(16, 8, 1);
    final composer = EffectComposer(renderer);
    _targets(composer, renderer);
    composer.reset();
    _targets(composer, renderer);
    composer.reset(WebGLRenderTarget(5, 7));
    _targets(composer, renderer);
    _targets(EffectComposer(renderer, WebGLRenderTarget(9, 3)), renderer);
    return renderer.log;
  },
  'fxaa': () {
    final renderer = _Recorder(64, 32, 2);
    final composer = EffectComposer(renderer);
    final fxaa = FXAAPass();
    void resolution() {
      final value = fxaa.material.resolution;
      renderer.log.add('resolution ${_js(value.x)} ${_js(value.y)}');
    }

    resolution();
    composer
      ..addPass(RenderPass(Scene(), PerspectiveCamera()))
      ..addPass(fxaa)
      ..addPass(OutputPass());
    resolution();
    composer
      ..render(0)
      ..setPixelRatio(1);
    resolution();
    composer.setSize(30, 12);
    resolution();
    composer.render(0);
    return renderer.log;
  },
  'render_pass': () {
    final renderer = _Recorder(8, 8, 1)..setClearColor(0x112233, 0.75);
    final composer = EffectComposer(renderer);
    final scene = Scene()..name = 'main';
    composer
      ..addPass(
        RenderPass(scene, PerspectiveCamera(), MeshBasicMaterial()..name = 'override', 0xff8800, 0.5)
          ..clearDepth = true,
      )
      ..addPass(RenderPass(scene, PerspectiveCamera())..clear = false);
    renderer.autoClear = true;
    composer.render(0);
    renderer.log.add(
      'after autoClear=${renderer.autoClear} clear=${renderer.getClearColor(Color()).getHexString()}/'
      '${_js(renderer.getClearAlpha())} override=${scene.overrideMaterial}',
    );
    return renderer.log;
  },
  'bloom': () {
    final renderer = _Recorder(101, 61, 1);
    final composer = EffectComposer(renderer);
    final bloom = TuningPass(Vector2(101, 61), 1.5, 0.4, 0.85);
    void state() {
      for (final target in [
        bloom.renderTargetBright,
        ...bloom.renderTargetsHorizontal,
        ...bloom.renderTargetsVertical,
      ]) {
        renderer.log.add(
          'target ${target.texture.name} ${target.width}x${target.height} type=${target.texture.type} '
          'depth=${target.depthBuffer} mipmaps=${target.texture.generateMipmaps}',
        );
      }

      for (final material in [
        bloom.materialHighPassFilter,
        ...bloom.separableBlurMaterials,
        bloom.compositeMaterial,
        bloom.blendMaterial,
      ]) {
        renderer.log.add(
          'material defines=${jsonEncode(_reference(material).$1)} blending=${material.blending} '
          'premultiplied=${material.premultipliedAlpha} transparent=${material.transparent} '
          'depth=${material.depthTest},${material.depthWrite}',
        );
      }
    }

    renderer.log.add(
      'swap=${bloom.needsSwap} mips=${bloom.nMips} resolution=${_js(bloom.resolution.x)},${_js(bloom.resolution.y)}',
    );
    state();
    composer
      ..addPass(RenderPass(Scene(), PerspectiveCamera()))
      ..addPass(bloom)
      ..addPass(OutputPass());
    state();
    composer
      ..render(0)
      ..setSize(37, 22);
    bloom
      ..strength = 0.8
      ..radius = 1
      ..threshold = 0.2
      ..bloomTintColors[2] = Vector3(1, 0.5, 0.25);
    state();
    composer.render(0);
    return renderer.log;
  },
  'output': () {
    final renderer = _Recorder(4, 4, 1);
    final output = OutputPass();
    final composer = EffectComposer(renderer)..addPass(output);

    for (final (toneMapping, space) in [
      (NoToneMapping, SRGBColorSpace),
      (LinearToneMapping, SRGBColorSpace),
      (ReinhardToneMapping, LinearSRGBColorSpace),
      (CineonToneMapping, SRGBColorSpace),
      (ACESFilmicToneMapping, SRGBColorSpace),
      (AgXToneMapping, SRGBColorSpace),
      (NeutralToneMapping, LinearSRGBColorSpace),
      (CustomToneMapping, SRGBColorSpace),
      (CustomToneMapping, SRGBColorSpace),
    ]) {
      renderer
        ..toneMapping = toneMapping
        ..outputColorSpace = space;
      composer.render(0);
    }

    return renderer.log;
  },
};

void main() {
  final fixtures =
      jsonDecode(File('../../fixtures/values/effect_composer.json').readAsStringSync()) as Map<String, Object?>;

  test('the fixtures cover every scenario', () {
    expect(fixtures.keys.where((k) => k != 'pin').toSet(), _scenarios.keys.toSet());
  });

  // The reference log in ent's terms (E-POSTPROCESSING): a quad's material named by its class, a material's state
  // without its shader source, and no `version` lines (the reference's OutputPass recompiles its shader when the
  // tone mapping or color space changes; an effect material has no shader to recompile).
  List<String> reference(String name) => [
    for (final line in (fixtures[name]! as List).cast<String>())
      if (line.startsWith('render quad '))
        'render quad ${_type(line)}${line.substring(12).substring(line.substring(12).indexOf(' '))}'
      else if (line.startsWith('material '))
        line.replaceFirst(RegExp(r' vertex=\S+ fragment=\S+'), '')
      else if (!line.startsWith('version '))
        line,
  ];

  // The reference log, with TuningPass's final blend (one additive quad into the read buffer) as ent draws it: the
  // read buffer copied into its own target, then the copy and the bloom in one render (E-POSTPROCESSING).
  List<String> expected(String name) {
    final log = <String>[];

    for (final line in reference(name)) {
      if (line.startsWith('render quad ') && line.contains(' blending=2 ')) {
        final into = line.split(' into=').last;
        log
          ..last = 'setRenderTarget base'
          ..addAll([
            'clear true true true',
            'render quad CopyMaterial OrthographicCamera defines= blending=0 opacity=1 tDiffuse=$into autoClear=false '
                'clear=000000/0 into=base',
            'setRenderTarget $into',
            'clear true true true',
            'render scene  OrthographicCamera override=- autoClear=false clear=000000/0 into=$into',
          ]);
      } else {
        log.add(line);
      }
    }

    return log;
  }

  // Numbers within 1e-12 (relative): the gaussian coefficients go through Math.exp in V8 and dart:math's exp, which
  // differ in the last bit; every other character equal.
  final number = RegExp(r'-?\d+(\.\d+)?(e-?\d+)?');
  String text(String line) => line.replaceAll(number, '#');
  List<double> numbers(String line) => [for (final m in number.allMatches(line)) double.parse(m[0]!)];

  void equal(List<String> log, List<String> reference) {
    expect(log.map(text), reference.map(text));

    for (final (i, line) in log.indexed) {
      final want = numbers(reference[i]);

      for (final (k, value) in numbers(line).indexed) {
        expect(value, closeTo(want[k], 1e-12 * math.max(1, want[k].abs())), reason: line);
      }
    }
  }

  for (final MapEntry(key: name, value: run) in _scenarios.entries) {
    test('$name matches the reference', () {
      equal(run(), expected(name));
    });
  }

  // Where the renderer keeps a target's color (Metal), TuningPass blends onto its read buffer as the reference
  // does.
  test('bloom matches the reference line for line where load keeps the color', () {
    _loads = true;
    addTearDown(() => _loads = false);
    equal(_scenarios['bloom']!(), reference('bloom'));
  });

  // The reference draws the input to the screen first (MeshBasicMaterial, after a clear) and the bloom additively at
  // the end; ent draws both in its last render (E-POSTPROCESSING). Not in the reference log: its recorder logs
  // ShaderMaterials.
  test('TuningPass on screen draws its input and the bloom in one render', () {
    final renderer = _Recorder(16, 8, 1);
    final bloom = TuningPass(Vector2(16, 8), 1, 0.5, 0.5);
    EffectComposer(renderer)
      ..addPass(RenderPass(Scene(), PerspectiveCamera()))
      ..addPass(bloom)
      ..render(0);
    expect(renderer.log.where((line) => line.contains('into=screen')), [
      'render scene  OrthographicCamera override=- autoClear=false clear=000000/0 into=screen',
    ]);

    // The composer restores the render target after the last pass.
    expect(renderer.log.sublist(renderer.log.length - 4), [
      'setRenderTarget screen',
      'clear true true true',
      'render scene  OrthographicCamera override=- autoClear=false clear=000000/0 into=screen',
      'setRenderTarget screen',
    ]);
  });
}
