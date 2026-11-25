// Programs: one precompiled shader pair per material kind (exception E-SHADERS), with the shared mesh vertex
// stage, the fixed vertex layout and the uniform blocks written at the offsets impellerc reflected.

import 'dart:typed_data';

import 'package:ent_renderer/gpu.dart' as gpu;

import 'host_buffers.dart';
import 'lights.dart';

/// One vertex buffer slot: an attribute name, its component count and the value WebGL reads for a disabled
/// attribute (`(0, 0, 0, 1)` cut to the component count). An [instance] slot advances once per instance; its
/// [stride] may span more than the attribute (a column of an instance matrix).
class VertexSlot {
  const VertexSlot(this.name, this.size, {this.instance = false, int? stride}) : stride = stride ?? size * 4;

  final String name;

  /// Components per vertex (float32 each).
  final int size;

  final bool instance;

  /// Bytes from one element to the next.
  final int stride;
}

/// The vertex layout of every mesh program, in slot order. A geometry without one of them is drawn with a
/// default buffer; a vec3 color is uploaded as vec4 with alpha 1.
const List<VertexSlot> meshSlots = [
  VertexSlot('position', 3),
  VertexSlot('normal', 3),
  VertexSlot('uv', 2),
  VertexSlot('uv1', 2),
  VertexSlot('color', 4),
  VertexSlot('tangent', 4),
];

/// The vertex layout of the skinned mesh programs (`MeshSkinVertex`): [meshSlots], then the skin indices and
/// weights.
const List<VertexSlot> skinSlots = [...meshSlots, VertexSlot('skinIndex', 4), VertexSlot('skinWeight', 4)];

/// The vertex layout of the dashed line program (`MeshDashedVertex`): [meshSlots], then `lineDistance`
/// (`Line.computeLineDistances`; without it, WebGL's disabled attribute reads 0).
const List<VertexSlot> dashedSlots = [...meshSlots, VertexSlot('lineDistance', 1)];

/// The vertex layout of the instanced mesh programs (`MeshInstanceVertex`): [meshSlots], then per instance the
/// four columns of `instanceMatrix` (views of one 64-byte stream) and `instanceColor`.
const List<VertexSlot> instanceSlots = [
  ...meshSlots,
  VertexSlot('instanceMatrix0', 4, instance: true, stride: 64),
  VertexSlot('instanceMatrix1', 4, instance: true, stride: 64),
  VertexSlot('instanceMatrix2', 4, instance: true, stride: 64),
  VertexSlot('instanceMatrix3', 4, instance: true, stride: 64),
  VertexSlot('instanceColor', 3, instance: true),
];

/// The most morph targets a mesh's influences reach the shaders for (`MAX_MORPH_TARGETS` in shaders/mesh.glsl).
const int maxMorphTargets = 64;

/// The generic 2D texture slots of the physical program's fragment stages (shaders/slots.glsl): with `env_map`,
/// 16 sampler states, the most a Metal stage binds on every Apple GPU (the iPhone 11's A13 skips a pipeline
/// that declares 17).
const int maxTextureSlots = 15;

/// The slot of the DFG table in the physical program's fragment stages, read there directly (shaders/slots.glsl).
const int dfgSlot = 13;

/// The slots of the LTC tables `ltc_1` and `ltc_2` in the physical program's fragment stages while the frame has
/// rect area lights, read there directly (shaders/slots.glsl); without such lights they take maps.
const List<int> ltcSlots = [11, 12];

/// A uniform block of one shader. [begin] starts a fresh copy for a draw; members are written by name and silently
/// skipped when the shader does not have them (as WebGL skips inactive uniforms). [bind] uploads the copy, or binds the
/// view uploaded before when the bytes equal it and its frame is still open (as the reference caches uniforms).
class UniformBlock {
  UniformBlock(gpu.Shader shader, String name) : slot = shader.getUniformSlot(name) {
    size = slot.sizeInBytes;
  }

  /// Whether [bind] checks every reuse byte by byte and that the view's block is in the open frame, throwing on
  /// a difference (tests; `--dart-define=UNIFORM_CHECK=true`).
  static bool check = const bool.fromEnvironment('UNIFORM_CHECK');

  final gpu.UniformSlot slot;

  /// The block's size in bytes, or `null` when the shader has no such block.
  late final int? size;

  // The float index of each member written so far, -1 for one the shader does not have.
  final Map<String, int> _indices = {};

  ByteData _data = ByteData(0);

  // A float view of [_data]: members are float-aligned, and both supported hosts (arm64, x64) are little-endian,
  // as the GPU reads the block.
  Float32List _floats = Float32List(0);

  // [_data] as words, compared bit for bit with [_last].
  Int32List _words = Int32List(0);

  // The words last uploaded, their view, and the host buffers and frame it belongs to.
  Int32List _last = Int32List(0);

  gpu.BufferView? _view;

  HostBuffers? _owner;

  int _frame = -1;

  void begin() {
    if (_data.lengthInBytes != (size ?? 0)) {
      _data = ByteData(size ?? 0);
      _floats = _data.buffer.asFloat32List(0, (size ?? 0) ~/ 4);
      _words = _data.buffer.asInt32List(0, (size ?? 0) ~/ 4);
      _last = Int32List(_words.length);
      _view = null;
    } else {
      _words.fillRange(0, _words.length, 0);
    }
  }

  int _index(String member) => _indices[member] ?? _resolve(member);

  int _resolve(String member) {
    final offset = size == null ? null : slot.getMemberOffsetInBytes(member);
    return _indices[member] = offset == null ? -1 : offset ~/ 4;
  }

  /// Whether the shader has the block and its [member].
  bool has(String member) => _index(member) >= 0;

  /// Writes [values] as consecutive floats from the start of [member], or from its float [at] (an element
  /// of an array member).
  void floats(String member, List<double> values, [int at = 0]) {
    final i = _index(member);

    // An indexed loop: setRange copies element by element through a slow path when the source is not a Float32List.
    if (i >= 0) {
      for (var k = 0; k < values.length; k++) {
        _floats[i + at + k] = values[k];
      }
    }
  }

  void float(String member, double value) {
    final i = _index(member);

    if (i >= 0) {
      _floats[i] = value;
    }
  }

  void flag(String member, bool value) => float(member, value ? 1 : 0);

  /// Writes a Matrix3 (column-major elements) as the upper-left 3×3 of a mat4 member.
  void mat3(String member, List<double> e) {
    final i = _index(member);

    if (i < 0) {
      return;
    }

    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        if (c < 3 && r < 3) {
          _floats[i + c * 4 + r] = e[c * 3 + r];
        } else {
          _floats[i + c * 4 + r] = c == r ? 1 : 0;
        }
      }
    }
  }

  /// Binds the written copy for the next draw, when the shader has the block.
  void bind(gpu.RenderPass pass, HostBuffers buffers) {
    if (size == null) {
      return;
    }

    if (_view != null && identical(_owner, buffers) && _frame == buffers.frame && _same()) {
      if (check) {
        _verify(buffers);
      }

      pass.bindUniform(slot, _view!);
      return;
    }

    _view = buffers.emplace(_data);
    _owner = buffers;
    _frame = buffers.frame;
    _last.setRange(0, _words.length, _words);
    pass.bindUniform(slot, _view!);
  }

  bool _same() {
    for (var i = 0; i < _words.length; i++) {
      if (_words[i] != _last[i]) {
        return false;
      }
    }

    return true;
  }

  // The reuse check: the bytes, read one at a time, equal the uploaded copy, and its block is in the open frame.
  void _verify(HostBuffers buffers) {
    final last = _last.buffer.asByteData();

    for (var i = 0; i < _data.lengthInBytes; i++) {
      if (_data.getUint8(i) != last.getUint8(i)) {
        throw StateError('UniformBlock: reused a ${slot.uniformName} copy that differs at byte $i.');
      }
    }

    if (!buffers.holds(_view!)) {
      throw StateError('UniformBlock: reused a ${slot.uniformName} view outside its frame.');
    }
  }
}

/// The vertex stage, fragment stage and pipeline of one program variant, with its uniform blocks: `VertInfo`,
/// `SkinInfo`, `MorphInfo` and `BatchInfo` (vertex, the second in the skinned stages only, the third in the morphed
/// ones, the fourth in the batching one), the material kind's `FragInfo`, and the shared `MapInfo` (shaders/maps.glsl),
/// `NormalInfo` (shaders/normals.glsl), `LightInfo` (shaders/lights.glsl), `EnvInfo` (shaders/envmaps.glsl),
/// `OutputInfo` (shaders/output.glsl), `OffsetInfo` (shaders/offset.glsl, polygon-offset variants only) and the
/// physical material's `UvInfo`, `TransmissionInfo` and `SlotInfo` where the stage declares them. A block the shader
/// declares but never reads breaks the binding of the others (shaders/offset.glsl), so the shaders read every block
/// they declare.
class ProgramVariant {
  ProgramVariant(gpu.GpuContext context, this.vertex, this.fragment, gpu.VertexLayout layout, this._samplers)
    : pipeline = context.createRenderPipeline(vertex, fragment, vertexLayout: layout),
      vertInfo = UniformBlock(vertex, 'VertInfo'),
      fragInfo = UniformBlock(fragment, 'FragInfo'),
      mapInfo = UniformBlock(fragment, 'MapInfo'),
      normalInfo = UniformBlock(fragment, 'NormalInfo'),
      lightInfo = UniformBlock(fragment, 'LightInfo'),
      envInfo = UniformBlock(fragment, 'EnvInfo'),
      outputInfo = UniformBlock(fragment, 'OutputInfo'),
      skinInfo = UniformBlock(vertex, 'SkinInfo'),
      morphInfo = UniformBlock(vertex, 'MorphInfo'),
      batchInfo = UniformBlock(vertex, 'BatchInfo'),
      offsetInfo = UniformBlock(fragment, 'OffsetInfo'),
      uvInfo = UniformBlock(fragment, 'UvInfo'),
      transmissionInfo = UniformBlock(fragment, 'TransmissionInfo'),
      slotInfo = UniformBlock(fragment, 'SlotInfo');

  final gpu.Shader vertex;

  final gpu.Shader fragment;

  final gpu.RenderPipeline pipeline;

  final UniformBlock vertInfo;

  final UniformBlock fragInfo;

  final UniformBlock mapInfo;

  final UniformBlock normalInfo;

  final UniformBlock lightInfo;

  final UniformBlock envInfo;

  final UniformBlock outputInfo;

  final UniformBlock skinInfo;

  final UniformBlock morphInfo;

  /// The batched instance of the next draw (shaders/mesh_batch.vert), written and bound once per range.
  final UniformBlock batchInfo;

  final UniformBlock offsetInfo;

  final UniformBlock uvInfo;

  final UniformBlock transmissionInfo;

  /// The slot of each 2D texture of the draw (shaders/slots.glsl), in the stages that bind through slots.
  final UniformBlock slotInfo;

  // The next slot a map of this draw may take (the DFG table's is skipped, and the LTC tables' with [_ltc]).
  int _filled = 0;

  // Whether this draw keeps [ltcSlots] for the LTC tables.
  bool _ltc = false;

  // The textures this draw bound to slots, with their samplers and slots: a map with the same texture and sampler
  // reads the same slot.
  final _bound = <(gpu.Texture, gpu.SamplerOptions, int)>[];

  bool _kept(int slot) => slot == dfgSlot || (_ltc && ltcSlots.contains(slot));

  // Whether the stage reads maps through slots: a physical variant without maps declares only the light, LTC and
  // DFG slots, and with transmission the target's (SLOT_MAPS, shaders/slots.glsl).
  late final bool _maps = _samplers.any(
    (name) =>
        !name.startsWith('light_texture_') &&
        !const {'env_map', 'dfg_lut', 'ltc_1', 'ltc_2', 'transmission_sampler_map'}.contains(name),
  );

  // The slots the draw's textures may fill: the transmission variant keeps the last for its target.
  late final int _capacity = maxTextureSlots - (_samplers.contains('transmission_sampler_map') ? 1 : 0);

  List<UniformBlock> get blocks => [
    vertInfo,
    fragInfo,
    mapInfo,
    normalInfo,
    lightInfo,
    envInfo,
    outputInfo,
    skinInfo,
    morphInfo,
    batchInfo,
    offsetInfo,
    uvInfo,
    transmissionInfo,
    slotInfo,
  ];

  final Set<String> _samplers;

  // The fragment stage's generic slots `slot_0` and on, resolved on the first slotted draw.
  late final List<gpu.UniformSlot> _slots = [
    for (var i = 0; i < maxTextureSlots; i++) fragment.getUniformSlot('slot_$i'),
  ];

  // The samplers bound by name, per stage, resolved on first use.
  final Map<String, gpu.UniformSlot> _vertexSamplers = {};

  final Map<String, gpu.UniformSlot> fragmentSamplers = {};

  /// Whether the fragment stage reads the sampler [name].
  bool reads(String name) => _samplers.contains(name);

  /// Whether the fragment stage binds its 2D textures through slots (shaders/slots.glsl): the physical stages, the
  /// ones that read the DFG table. Not from SlotInfo, which a variant without maps does not declare.
  bool get slotted => _samplers.contains('dfg_lut');

  /// Starts a draw's texture bindings: in a slotted stage the first [lights] slots hold the light textures in use
  /// (light texture k in slot k) and no other 2D texture has a slot yet (each reads as opaque black, the
  /// renderer's fallback texture). With [ltc] the slots [ltcSlots] are kept for the LTC tables.
  void beginSlots(int lights, {bool ltc = false}) {
    _filled = lights;
    _ltc = ltc;
    _bound.clear();

    if (slotted) {
      slotInfo.begin();

      for (final name in _samplers) {
        slotInfo.float(name, -1);
      }
    }
  }

  /// Binds [fallback] to the slots this draw left empty, which the shader never reads.
  void endSlots(gpu.RenderPass pass, gpu.Texture fallback) {
    if (!slotted) {
      return;
    }

    for (var i = _filled; i < _capacity; i++) {
      if (!_kept(i) && (_maps || i < maxLightTextures || ltcSlots.contains(i))) {
        pass.bindTexture(_slots[i], fallback, sampler: gpu.SamplerOptions());
      }
    }
  }

  /// Binds [texture] to the sampler [name] of the fragment stage, or of the vertex stage with [vertex] (which
  /// always reads `displacement_map`); does nothing for a fragment sampler the kind does not read. In a slotted
  /// stage a light texture takes its own slot, the DFG table [dfgSlot], the LTC tables [ltcSlots], the
  /// transmission target the last one, and another 2D texture the slot of the same texture and sampler bound
  /// earlier in the draw, or else the next free one; returns false, binding nothing, when no slot is left.
  bool bindTexture(
    gpu.RenderPass pass,
    String name,
    gpu.Texture texture,
    gpu.SamplerOptions sampler, {
    bool vertex = false,
  }) {
    if (!vertex && slotted && name.startsWith('light_texture_')) {
      // Its one digit is its slot (at most 6 light textures), read without building a substring.
      pass.bindTexture(_slots[name.codeUnitAt(14) - 0x30], texture, sampler: sampler);
    } else if (!vertex && slotted && name == 'transmission_sampler_map') {
      // Slot 14: a physical variant without maps or transmission does not declare it (SLOT_MAPS).
      if (_maps || _samplers.contains(name)) {
        pass.bindTexture(_slots[maxTextureSlots - 1], texture, sampler: sampler);
      }
    } else if (!vertex && slotted && name == 'dfg_lut') {
      pass.bindTexture(_slots[dfgSlot], texture, sampler: sampler);
    } else if (!vertex && slotted && (name == 'ltc_1' || name == 'ltc_2')) {
      pass.bindTexture(_slots[ltcSlots[name == 'ltc_1' ? 0 : 1]], texture, sampler: sampler);
    } else if (!vertex && slotted && name != 'env_map' && _samplers.contains(name)) {
      for (final (bound, options, slot) in _bound) {
        if (identical(bound, texture) && _same(options, sampler)) {
          slotInfo.float(name, slot.toDouble());
          return true;
        }
      }

      while (_kept(_filled)) {
        _filled++;
      }

      if (_filled >= _capacity) {
        return false;
      }

      slotInfo.float(name, _filled.toDouble());
      pass.bindTexture(_slots[_filled], texture, sampler: sampler);
      _bound.add((texture, sampler, _filled));
      _filled++;
    } else if (vertex || _samplers.contains(name)) {
      pass.bindTexture(
        vertex
            ? _vertexSamplers[name] ??= this.vertex.getUniformSlot(name)
            : fragmentSamplers[name] ??= fragment.getUniformSlot(name),
        texture,
        sampler: sampler,
      );
    }

    return true;
  }

  static bool _same(gpu.SamplerOptions a, gpu.SamplerOptions b) =>
      a.minFilter == b.minFilter &&
      a.magFilter == b.magFilter &&
      a.mipFilter == b.mipFilter &&
      a.widthAddressMode == b.widthAddressMode &&
      a.heightAddressMode == b.heightAddressMode &&
      a.maxAnisotropy == b.maxAnisotropy;
}

/// The shader [name] from [library]; a [StateError] naming it when the bundle lacks it (a stale build).
gpu.Shader shaderOf(gpu.ShaderLibrary library, String name) =>
    library[name] ??
    (throw StateError('${library.package}: the shader bundle has no $name; rebuild it (flutter clean, then build).'));

/// A material kind's program: its plain variant and, built on first use, the variant that applies
/// `polygonOffset` (for example `ShadowFragment` and `ShadowOffsetFragment` in the shader bundle, compiled from
/// the same source, the second with POLYGON_OFFSET defined). Writing the fragment depth disables early depth
/// testing, so only materials with polygonOffset pay for it.
///
/// [samplers] names the fragment samplers the kind's shader reads. The compiler removes a declared sampler that
/// is never read, and binding a texture to a removed sampler is accepted by Flutter GPU but crashes the process
/// when the pass is encoded (Flutter 3.47.6), so only these are bound; the list must match the shader.
class Program {
  Program(
    this._context,
    this._library,
    this.name,
    this._vertexName,
    this.fragment,
    this.samplers, [
    this.slots = meshSlots,
  ]) : _vertex = shaderOf(_library, _vertexName);

  final gpu.GpuContext _context;

  final gpu.ShaderLibrary _library;

  /// The material kind, for messages.
  final String name;

  final String _vertexName;

  final gpu.Shader _vertex;

  /// The fragment stage's entry point; a kind drawn through variants names its kind (ent_shaders' kinds)
  /// instead, and only its variants draw.
  final String fragment;

  Program? _skinned;

  Program? _morphed;

  Program? _skinnedMorphed;

  Program? _instanced;

  Program? _instancedMorphed;

  Program? _instancedMorphTexture;

  Program? _batched;

  /// This program's vertex stage with the fragment stage [fragment] reading [samplers]: a variant of this kind.
  Program withFragment(String fragment, Set<String> samplers) =>
      Program(_context, _library, name, _vertexName, fragment, samplers, slots);

  /// The program of a BatchedMesh: the same fragment stage over the batching vertex stage (`MeshBatchVertex`),
  /// or `null` where [skinned] is.
  Program? get batched {
    if (_vertexName != 'MeshVertex') {
      return null;
    }

    return _batched ??= Program(_context, _library, name, 'MeshBatchVertex', fragment, samplers);
  }

  /// The program of an InstancedMesh: the same fragment stage over the instancing vertex stage and
  /// [instanceSlots], or `null` where [skinned] is.
  Program? get instanced {
    if (_vertexName != 'MeshVertex') {
      return null;
    }

    return _instanced ??= Program(_context, _library, name, 'MeshInstanceVertex', fragment, samplers, instanceSlots);
  }

  /// The program of an InstancedMesh whose geometry has morph attributes (`MeshInstanceMorphVertex`), or `null`
  /// where [skinned] is.
  Program? get instancedMorphed {
    if (_vertexName != 'MeshVertex') {
      return null;
    }

    return _instancedMorphed ??= Program(
      _context,
      _library,
      name,
      'MeshInstanceMorphVertex',
      fragment,
      samplers,
      instanceSlots,
    );
  }

  /// The program of an InstancedMesh with morph attributes and a `morphTexture` (setMorphAt's per-instance
  /// influences, USE_INSTANCING_MORPH: `MeshInstanceMorphTextureVertex`), or `null` where [skinned] is.
  Program? get instancedMorphTexture {
    if (_vertexName != 'MeshVertex') {
      return null;
    }

    return _instancedMorphTexture ??= Program(
      _context,
      _library,
      name,
      'MeshInstanceMorphTextureVertex',
      fragment,
      samplers,
      instanceSlots,
    );
  }

  /// The program of a geometry with morph attributes: the same fragment stage over the morph target vertex
  /// stage, or `null` for a program whose vertex stage is not the mesh one.
  Program? get morphed {
    if (_vertexName != 'MeshVertex') {
      return null;
    }

    return _morphed ??= Program(_context, _library, name, 'MeshMorphVertex', fragment, samplers);
  }

  /// The program of a SkinnedMesh: the same fragment stage over the skinning vertex stage and [skinSlots], or
  /// `null` for a program whose vertex stage is not the mesh one (points, sprites, backgrounds).
  Program? get skinned {
    if (_vertexName != 'MeshVertex') {
      return null;
    }

    return _skinned ??= Program(_context, _library, name, 'MeshSkinVertex', fragment, samplers, skinSlots);
  }

  /// The program of a SkinnedMesh whose geometry has morph attributes: both vertex stages' features in one
  /// (`MeshSkinMorphVertex`), or `null` where [skinned] is.
  Program? get skinnedMorphed {
    if (_vertexName != 'MeshVertex') {
      return null;
    }

    return _skinnedMorphed ??= Program(_context, _library, name, 'MeshSkinMorphVertex', fragment, samplers, skinSlots);
  }

  final List<VertexSlot> slots;

  final Set<String> samplers;

  ProgramVariant? _plain;

  ProgramVariant? _offset;

  late final gpu.VertexLayout _layout = gpu.VertexLayout(
    buffers: [
      for (final slot in slots)
        gpu.VertexBuffer(
          strideInBytes: slot.stride,
          stepMode: slot.instance ? gpu.VertexStepMode.instance : gpu.VertexStepMode.vertex,
          attributes: [gpu.VertexAttribute(name: slot.name, format: _format(slot.size))],
        ),
    ],
  );

  /// The plain fragment stage, or with [offset] its polygon offset twin; a variant program (named by its key, not
  /// `…Fragment`) carries polygon offset as a flag of its key instead, so [offset] does not apply to it.
  ProgramVariant variant({required bool offset}) {
    if (offset && fragment.endsWith('Fragment')) {
      return _offset ??= ProgramVariant(
        _context,
        _vertex,
        shaderOf(_library, fragment.replaceFirst('Fragment', 'OffsetFragment')),
        _layout,
        samplers,
      );
    }

    return _plain ??= ProgramVariant(_context, _vertex, shaderOf(_library, fragment), _layout, samplers);
  }

  static gpu.VertexFormat _format(int size) {
    return switch (size) {
      1 => gpu.VertexFormat.float32,
      2 => gpu.VertexFormat.float32x2,
      3 => gpu.VertexFormat.float32x3,
      _ => gpu.VertexFormat.float32x4,
    };
  }
}
