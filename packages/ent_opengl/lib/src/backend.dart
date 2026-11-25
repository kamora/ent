/// The renderer core's GPU interface on OpenGL ES 3. Command buffers record their passes and run them on submit, as
/// Flutter GPU's do; a render pass binds a framebuffer of its attachments and clears what its load actions ask.
/// Textures keep GL's memory order: row 0 is the first row [ent.Texture.overwrite] writes and [ent.Texture.read]
/// returns. Shaders are the GLSL ES 3.00 of a shader bundle's `opengl_es` backend ([GlLibrary]).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:math' as math;
import 'dart:io';

import 'package:ent_renderer/gpu.dart' as ent;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:ent_impeller/ent_impeller.dart';
import 'package:ffi/ffi.dart';

import 'gl.dart';

part 'surface.dart';

/// The internal format, format, type and bytes per texel of [format]; null where OpenGL ES 3 has none.
(int, int, int, int)? _layout(ent.PixelFormat format) => switch (format) {
  ent.PixelFormat.r8g8b8a8UNormInt || ent.PixelFormat.b8g8r8a8UNormInt => (glRgba8, glRgba, glUnsignedByte, 4),
  ent.PixelFormat.r8g8b8a8UNormIntSRGB ||
  ent.PixelFormat.b8g8r8a8UNormIntSRGB => (glSrgb8Alpha8, glRgba, glUnsignedByte, 4),
  ent.PixelFormat.r16g16b16a16Float => (glRgba16f, glRgba, glHalfFloat, 8),
  ent.PixelFormat.r32g32b32a32Float => (glRgba32f, glRgba, glFloat, 16),
  ent.PixelFormat.r32Float => (glR32f, glRed, glFloat, 4),
  ent.PixelFormat.r8UNormInt => (glR8, glRed, glUnsignedByte, 1),
  ent.PixelFormat.r8g8UNormInt => (glRg8, glRg, glUnsignedByte, 2),
  ent.PixelFormat.d24UnormS8Uint => (glDepth24Stencil8, glDepthStencil, glUnsignedInt248, 4),
  ent.PixelFormat.d32FloatS8UInt => (glDepth32fStencil8, glDepthStencil, glFloat32UnsignedInt248Rev, 8),
  ent.PixelFormat.s8UInt => (glStencilIndex8, glStencilIndex, glUnsignedByte, 1),
  ent.PixelFormat.unknown || ent.PixelFormat.a8UNormInt => null,
};

/// Throws a [StateError] naming [what] when GL reports an error.
void _check(String what) {
  final error = glGetError();

  if (error != glNoError) {
    throw StateError('ent_opengl: $what failed with GL error 0x${error.toRadixString(16)}.');
  }
}

/// An OpenGL ES 3 context of its own (EGL, a 1 × 1 pbuffer), made current on the thread that calls it.
final class GlContext implements ent.GpuContext {
  GlContext._(this._display, this._config, this._surface, this._context);

  /// Creates the context: EGL's default display (ANGLE on Metal on macOS, the system's on Android) with an OpenGL ES 3
  /// config, which on Android also takes window surfaces. Throws a
  /// [StateError] naming the EGL call that failed.
  factory GlContext() {
    return using((arena) {
      final display = eglGetDisplay(nullptr);

      if (display == nullptr || eglInitialize(display, nullptr, nullptr) == 0) {
        throw StateError('ent_opengl: no EGL display (EGL error 0x${eglGetError().toRadixString(16)}).');
      }

      final attributes = arena<Int32>(5)
        ..[0] = eglRenderableType
        ..[1] = eglOpenglEs3Bit
        ..[2] = eglSurfaceType
        ..[3] = Platform.isAndroid ? eglPbufferBit | eglWindowBit : eglPbufferBit
        ..[4] = eglNone;
      final config = arena<Pointer<Void>>();
      final count = arena<Int32>();

      if (eglChooseConfig(display, attributes, config, 1, count) == 0 || count.value < 1) {
        throw StateError('ent_opengl: no OpenGL ES 3 config (EGL error 0x${eglGetError().toRadixString(16)}).');
      }

      final version = arena<Int32>(3)
        ..[0] = eglContextClientVersion
        ..[1] = 3
        ..[2] = eglNone;
      final context = eglCreateContext(display, config.value, nullptr, version);
      final size = arena<Int32>(5)
        ..[0] = eglWidth
        ..[1] = 1
        ..[2] = eglHeight
        ..[3] = 1
        ..[4] = eglNone;
      final surface = eglCreatePbufferSurface(display, config.value, size);

      if (context == nullptr || surface == nullptr) {
        throw StateError('ent_opengl: no OpenGL ES 3 context (EGL error 0x${eglGetError().toRadixString(16)}).');
      }

      return GlContext._(display, config.value, surface, context).._current();
    });
  }

  /// One context for the process, shared by every renderer, so the checks of ent_renderer run once.
  static final GlContext shared = GlContext();

  final Pointer<Void> _display;

  final Pointer<Void> _config;

  final Pointer<Void> _surface;

  final Pointer<Void> _context;

  // The GL names of textures, renderbuffers and buffers whose handles were collected, deleted at the next submit.
  final List<int> _textures = [];

  final List<int> _renderbuffers = [];

  final List<int> _buffers = [];

  late final Finalizer<int> _dropTexture = Finalizer(_textures.add);

  late final Finalizer<int> _dropRenderbuffer = Finalizer(_renderbuffers.add);

  late final Finalizer<int> _dropBuffer = Finalizer(_buffers.add);

  void _current() {
    if (eglMakeCurrent(_display, _surface, _surface, _context) == 0) {
      throw StateError(
        'ent_opengl: the context cannot be made current (EGL error 0x${eglGetError().toRadixString(16)}).',
      );
    }
  }

  // Deletes the GL objects of collected handles.
  void _collect() {
    for (final (names, delete) in [
      (_textures, glDeleteTextures),
      (_renderbuffers, glDeleteRenderbuffers),
      (_buffers, glDeleteBuffers),
    ]) {
      for (final name in names) {
        using((arena) => delete(1, arena<Uint32>()..value = name));
      }

      names.clear();
    }
  }

  // Blits [frame] into [surface], a GlSurface's EGL surface. An IOSurface's pbuffer keeps the frame's rows (row 0 the
  // top) and is finished before Flutter reads it; a [window] surface's row 0 is its bottom, and swapping the buffers
  // hands it to Flutter. The frame is turned over where its rows run the other way.
  void _present(Pointer<Void> surface, GlTexture frame, int width, int height, {required bool window}) {
    if (eglMakeCurrent(_display, surface, surface, _context) == 0) {
      throw StateError(
        'ent_opengl: the surface cannot be made current (EGL error 0x${eglGetError().toRadixString(16)}).',
      );
    }

    using((arena) {
      final framebuffer = arena<Uint32>();
      glGenFramebuffers(1, framebuffer);
      glBindFramebuffer(glReadFramebuffer, framebuffer.value);
      glFramebufferTexture2D(glReadFramebuffer, glColorAttachment0, glTexture2D, frame.name, 0);
      glBindFramebuffer(glDrawFramebuffer, 0);
      final turn = frame._up != window;
      glBlitFramebuffer(
        0,
        0,
        width,
        height,
        0,
        turn ? height : 0,
        width,
        turn ? 0 : height,
        glColorBufferBit,
        glNearest,
      );
      glBindFramebuffer(glFramebuffer, 0);
      glDeleteFramebuffers(1, framebuffer);
    });
    _check('GlSurface.present');

    if (window) {
      eglSwapBuffers(_display, surface);
    } else {
      glFinish();
    }

    _current();
  }

  /// GL's name for the renderer, such as `ANGLE (Apple, ANGLE Metal Renderer: Apple M1, ...)`.
  String get renderer {
    _current();
    return glGetString(glRendererName).toDartString();
  }

  @override
  ent.PixelFormat get defaultColorFormat => ent.PixelFormat.r8g8b8a8UNormInt;

  @override
  ent.PixelFormat get defaultDepthStencilFormat => ent.PixelFormat.d24UnormS8Uint;

  // Multisampled textures are renderbuffers (OpenGL ES 3.0 has no multisampled textures), resolved by a blit.
  @override
  bool get doesSupportOffscreenMSAA => true;

  // EXT_texture_filter_anisotropic's limit, as the reference reads it (WebGLCapabilities.getMaxAnisotropy); 1
  // without the extension.
  @override
  late final int maxSamplerAnisotropy = () {
    _current();

    if (!glGetString(glExtensions).toDartString().split(' ').contains('GL_EXT_texture_filter_anisotropic')) {
      return 1;
    }

    return using((arena) {
      final value = arena<Float>();
      glGetFloatv(glMaxTextureMaxAnisotropy, value);
      return value.value.floor();
    });
  }();

  @override
  int get minimumUniformByteAlignment {
    _current();
    return using((arena) {
      final value = arena<Int32>();
      glGetIntegerv(glUniformBufferOffsetAlignment, value);
      return value.value;
    });
  }

  // 2D targets and the frame are drawn as WebGL draws them, their first row at the bottom; cube faces with theirs at
  // the top, as the renderer's cube cameras expect (the shaders' _impeller_y_flip turns those over).
  @override
  bool get rowsUp => true;

  // Down to 1 × 1, from the larger side, as WebGL's getMipLevels.
  @override
  int maxMipLevelCount(int width, int height) => math.max(width, height).bitLength;

  @override
  bool supportsTextureFormat(ent.PixelFormat format, {bool renderTarget = false, bool shaderRead = true}) {
    return _layout(format) != null;
  }

  @override
  ent.CommandBuffer createCommandBuffer() => _Commands(this);

  @override
  ent.DeviceBuffer createDeviceBuffer(ent.StorageMode storageMode, int sizeInBytes) => _Buffer(this, sizeInBytes);

  @override
  ent.DeviceBuffer createDeviceBufferWithCopy(ByteData data) {
    return _Buffer(this, data.lengthInBytes)..overwrite(data);
  }

  @override
  ent.RenderPipeline createRenderPipeline(
    ent.Shader vertexShader,
    ent.Shader fragmentShader, {
    ent.VertexLayout? vertexLayout,
  }) {
    _current();
    return _Pipeline(vertexShader as GlShader, fragmentShader as GlShader, vertexLayout);
  }

  // GL sampler objects, one per distinct set of options.
  final Map<
    (ent.MinMagFilter, ent.MinMagFilter, ent.MipFilter, ent.SamplerAddressMode, ent.SamplerAddressMode, int),
    int
  >
  _samplers = {};

  int _sampler(ent.SamplerOptions options) {
    final key = (
      options.minFilter,
      options.magFilter,
      options.mipFilter,
      options.widthAddressMode,
      options.heightAddressMode,
      options.maxAnisotropy,
    );
    return _samplers[key] ??= using((arena) {
      final value = arena<Uint32>();
      glGenSamplers(1, value);
      final linear = options.mipFilter == ent.MipFilter.linear;
      glSamplerParameteri(value.value, glTextureMinFilter, switch (options.minFilter) {
        ent.MinMagFilter.nearest => linear ? glNearestMipmapLinear : glNearestMipmapNearest,
        ent.MinMagFilter.linear => linear ? glLinearMipmapLinear : glLinearMipmapNearest,
      });
      glSamplerParameteri(
        value.value,
        glTextureMagFilter,
        options.magFilter == ent.MinMagFilter.linear ? glLinear : glNearest,
      );
      glSamplerParameteri(value.value, glTextureWrapS, _wrap(options.widthAddressMode));
      glSamplerParameteri(value.value, glTextureWrapT, _wrap(options.heightAddressMode));

      if (options.maxAnisotropy > 1) {
        glSamplerParameterf(value.value, glTextureMaxAnisotropy, options.maxAnisotropy.toDouble());
      }

      return value.value;
    });
  }

  // The attribute locations enabled by the last draw.
  final Set<int> _attributes = {};

  @override
  ent.Texture createTexture(
    ent.StorageMode storageMode,
    int width,
    int height, {
    ent.PixelFormat format = ent.PixelFormat.r8g8b8a8UNormInt,
    int sampleCount = 1,
    ent.TextureType? textureType,
    bool enableRenderTargetUsage = true,
    bool enableShaderReadUsage = true,
    int mipLevelCount = 1,
  }) {
    final layout = _layout(format);

    if (layout == null) {
      throw UnsupportedError('ent_opengl: OpenGL ES 3 has no $format texture.');
    }

    _current();

    // A multisampled texture is a renderbuffer: it is drawn into and resolved, never sampled or read.
    if (sampleCount > 1) {
      final name = using((arena) {
        final value = arena<Uint32>();
        glGenRenderbuffers(1, value);
        return value.value;
      });
      glBindRenderbuffer(glRenderbuffer, name);
      glRenderbufferStorageMultisample(glRenderbuffer, sampleCount, layout.$1, width, height);
      glBindRenderbuffer(glRenderbuffer, 0);
      _check('createTexture($format, $width × $height, $sampleCount samples)');
      return GlTexture._(this, name, width, height, 1, format, false, multisampled: true);
    }

    final cube = textureType == ent.TextureType.textureCube;
    final target = cube ? glTextureCubeMap : glTexture2D;
    final name = using((arena) {
      final value = arena<Uint32>();
      glGenTextures(1, value);
      return value.value;
    });
    glBindTexture(target, name);
    glTexStorage2D(target, mipLevelCount, layout.$1, width, height);
    glTexParameteri(target, glTextureMinFilter, glNearest);
    glTexParameteri(target, glTextureMagFilter, glNearest);
    glBindTexture(target, 0);
    _check('createTexture($format, $width × $height)');
    return GlTexture._(this, name, width, height, mipLevelCount, format, cube);
  }
}

int _wrap(ent.SamplerAddressMode mode) => switch (mode) {
  ent.SamplerAddressMode.clampToEdge => glClampToEdge,
  ent.SamplerAddressMode.repeat => glRepeat,
  ent.SamplerAddressMode.mirror => glMirroredRepeat,
};

/// A texture of a [GlContext]: its GL [name] and size.
final class GlTexture implements ent.Texture {
  GlTexture._(
    this._context,
    this.name,
    this.width,
    this.height,
    this.mipLevelCount,
    this.format,
    this._cube, {
    this.multisampled = false,
  }) {
    (multisampled ? _context._dropRenderbuffer : _context._dropTexture).attach(this, name);
  }

  /// Whether [name] is a multisampled renderbuffer.
  final bool multisampled;

  // Whether the texture was last drawn with its first row at the bottom (GpuContext.rowsUp), so [read] turns it over.
  bool _up = false;

  final GlContext _context;

  /// The texture's GL name.
  final int name;

  @override
  final int width;

  @override
  final int height;

  @override
  final int mipLevelCount;

  final ent.PixelFormat format;

  final bool _cube;

  @override
  void overwrite(ByteData sourceBytes, {int mipLevel = 0, int slice = 0}) {
    if (multisampled) {
      throw StateError('ent_opengl: a multisampled texture cannot be written; draw into it.');
    }

    final (_, format, type, bytes) = _layout(this.format)!;
    final w = (width >> mipLevel).clamp(1, width);
    final h = (height >> mipLevel).clamp(1, height);

    if (sourceBytes.lengthInBytes != w * h * bytes) {
      throw ArgumentError.value(
        sourceBytes.lengthInBytes,
        'sourceBytes',
        'level $mipLevel of a $width × $height ${this.format} texture takes ${w * h * bytes} bytes',
      );
    }

    _context._current();
    using((arena) {
      final data = arena<Uint8>(sourceBytes.lengthInBytes);
      data
          .asTypedList(sourceBytes.lengthInBytes)
          .setAll(0, sourceBytes.buffer.asUint8List(sourceBytes.offsetInBytes, sourceBytes.lengthInBytes));
      glBindTexture(_cube ? glTextureCubeMap : glTexture2D, name);
      glPixelStorei(glUnpackAlignment, 1);
      glTexSubImage2D(
        _cube ? glTextureCubeMapPositiveX + slice : glTexture2D,
        mipLevel,
        0,
        0,
        w,
        h,
        format,
        type,
        data.cast(),
      );
      glBindTexture(_cube ? glTextureCubeMap : glTexture2D, 0);
    });
    _check('Texture.overwrite');
  }

  /// Builds the levels below the base with glGenerateMipmap, as WebGL's generateMipmap does, for 8-bit formats;
  /// OpenGL ES 3 filters others (32-bit floats) only with extensions, so the renderer writes theirs.
  @override
  bool generateMipmaps() {
    final (internal, _, type, _) = _layout(format)!;

    if (multisampled || type != glUnsignedByte || internal == glStencilIndex8) {
      return false;
    }

    _context._current();
    glBindTexture(_cube ? glTextureCubeMap : glTexture2D, name);
    glGenerateMipmap(_cube ? glTextureCubeMap : glTexture2D);
    glBindTexture(_cube ? glTextureCubeMap : glTexture2D, 0);
    _check('Texture.generateMipmaps');
    return true;
  }

  /// The first level as RGBA bytes, rows from the top (a texture drawn with its first row at the bottom is turned
  /// over); 8-bit RGBA formats only so far.
  @override
  Future<ByteData> read() async {
    if (multisampled) {
      throw StateError('ent_opengl: a multisampled texture cannot be read; read its resolve texture.');
    }

    final (_, format, type, bytes) = _layout(this.format)!;

    if (format != glRgba || type != glUnsignedByte) {
      throw UnimplementedError('ent_opengl: reading a ${this.format} texture is not implemented yet.');
    }

    _context._current();
    return using((arena) {
      final framebuffer = arena<Uint32>();
      final data = arena<Uint8>(width * height * bytes);
      glGenFramebuffers(1, framebuffer);
      glBindFramebuffer(glReadFramebuffer, framebuffer.value);
      glFramebufferTexture2D(
        glReadFramebuffer,
        glColorAttachment0,
        _cube ? glTextureCubeMapPositiveX : glTexture2D,
        name,
        0,
      );
      glPixelStorei(glPackAlignment, 1);
      glReadPixels(0, 0, width, height, format, type, data.cast());
      glBindFramebuffer(glReadFramebuffer, 0);
      glDeleteFramebuffers(1, framebuffer);
      _check('Texture.read');
      final rows = data.asTypedList(width * height * bytes);

      if (!_up) {
        return ByteData.sublistView(Uint8List.fromList(rows));
      }

      final stride = width * bytes;
      final turned = Uint8List(rows.length);

      for (var y = 0; y < height; y++) {
        turned.setRange(y * stride, (y + 1) * stride, rows, (height - 1 - y) * stride);
      }

      return ByteData.sublistView(turned);
    });
  }
}

final class _Buffer implements ent.DeviceBuffer {
  _Buffer(this._context, this.sizeInBytes) {
    _context._current();
    _name = using((arena) {
      final value = arena<Uint32>();
      glGenBuffers(1, value);
      return value.value;
    });
    glBindBuffer(glArrayBuffer, _name);
    glBufferData(glArrayBuffer, sizeInBytes, nullptr, glDynamicDraw);
    glBindBuffer(glArrayBuffer, 0);
    _check('createDeviceBuffer($sizeInBytes)');
    _context._dropBuffer.attach(this, _name);
  }

  final GlContext _context;

  late final int _name;

  @override
  final int sizeInBytes;

  @override
  bool overwrite(ByteData sourceBytes, {int destinationOffsetInBytes = 0}) {
    if (destinationOffsetInBytes < 0 || destinationOffsetInBytes + sourceBytes.lengthInBytes > sizeInBytes) {
      return false;
    }

    _context._current();
    using((arena) {
      final data = arena<Uint8>(sourceBytes.lengthInBytes);
      data
          .asTypedList(sourceBytes.lengthInBytes)
          .setAll(0, sourceBytes.buffer.asUint8List(sourceBytes.offsetInBytes, sourceBytes.lengthInBytes));
      glBindBuffer(glArrayBuffer, _name);
      glBufferSubData(glArrayBuffer, destinationOffsetInBytes, sourceBytes.lengthInBytes, data.cast());
      glBindBuffer(glArrayBuffer, 0);
    });
    _check('DeviceBuffer.overwrite');
    return true;
  }
}

final class _Commands implements ent.CommandBuffer {
  _Commands(this._context);

  final GlContext _context;

  // What submit runs, in order: each pass's begin, its draws and its end.
  final List<void Function()> _steps = [];

  _Pass? _open;

  bool _submitted = false;

  void _close() {
    final open = _open;

    if (open != null) {
      _steps.add(open._end);
      _open = null;
    }
  }

  @override
  ent.RenderPass createRenderPass(ent.RenderTarget renderTarget) {
    _close();
    final pass = _Pass(_context, renderTarget, _steps);
    _steps.add(pass._begin);
    return _open = pass;
  }

  @override
  void submit({ent.CompletionCallback? completionCallback}) {
    if (_submitted) {
      throw StateError('CommandBuffer has already been submitted.');
    }

    _submitted = true;
    _close();
    _context._current();

    for (final step in _steps) {
      step();
    }

    _context._collect();
    _check('CommandBuffer.submit');

    if (completionCallback == null) {
      glFlush();
      return;
    }

    // Completion is reported once the GPU has finished, asynchronously as Flutter GPU reports it.
    glFinish();
    Timer.run(() => completionCallback(true));
  }
}

/// The shaders of a bundle's OpenGL ES backend (GLSL ES 3.00), read by `readBundle` of ent_impeller.
final class GlLibrary implements ent.ShaderLibrary {
  /// The shaders of [bundle], an `ent.shaderbundle` that keeps the `opengl_es` backend.
  GlLibrary(Uint8List bundle) : _shaders = readBundle(bundle, 'opengl_es');

  final Map<String, BundledShader> _shaders;

  final Map<String, GlShader> _handles = {};

  @override
  String get package => 'ent_opengl';

  @override
  GlShader? operator [](String shaderName) {
    final shader = _shaders[shaderName];
    return shader == null ? null : _handles[shaderName] ??= GlShader._(shaderName, shader);
  }
}

/// A shader of a [GlLibrary], compiled when a pipeline first uses it.
final class GlShader implements ent.Shader {
  GlShader._(this.name, this._source);

  final String name;

  final BundledShader _source;

  int _compiled = 0;

  int get _name {
    if (_compiled != 0) {
      return _compiled;
    }

    final shader = glCreateShader(_source.stage == 'vertex' ? glVertexShader : glFragmentShader);
    using((arena) {
      // gl_PointCoord counts from the window's top; in a target drawn turned over (_impeller_y_flip -1, rows -1) that
      // is the image's bottom, so it is turned over too.
      final code = utf8.decode(_source.code);
      final text = arena<Pointer<Utf8>>()
        ..value =
            (_source.stage == 'vertex'
                    ? code
                    : code.replaceAll(
                        'gl_PointCoord',
                        'vec2(gl_PointCoord.x, output_info.rows < 0.0 ? 1.0 - gl_PointCoord.y : gl_PointCoord.y)',
                      ))
                .toNativeUtf8(allocator: arena);
      glShaderSource(shader, 1, text, nullptr);
      glCompileShader(shader);
      final status = arena<Int32>();
      glGetShaderiv(shader, glCompileStatus, status);

      if (status.value == 0) {
        throw StateError(
          'ent_opengl: shader $name does not compile: ${_log(shader, glGetShaderiv, glGetShaderInfoLog)}',
        );
      }
    });
    return _compiled = shader;
  }

  @override
  ent.UniformSlot getUniformSlot(String uniformName) => _Slot(this, uniformName);
}

final class _Slot implements ent.UniformSlot {
  _Slot(this._shader, this.uniformName);

  final GlShader _shader;

  @override
  final String uniformName;

  // The key of the slot's binding point or texture unit in a pipeline.
  (GlShader, String) get _key => (_shader, uniformName);

  @override
  int? get sizeInBytes => _shader._source.blocks[uniformName]?.size;

  @override
  int? getMemberOffsetInBytes(String memberName) => _shader._source.blocks[uniformName]?.members[memberName];
}

// A shader's or program's info log.
String _log(
  int name,
  void Function(int, int, Pointer<Int32>) get,
  void Function(int, int, Pointer<Int32>, Pointer<Utf8>) read,
) {
  return using((arena) {
    final length = arena<Int32>();
    get(name, glInfoLogLength, length);
    final text = arena<Uint8>(length.value + 1).cast<Utf8>();
    read(name, length.value + 1, nullptr, text);
    return text.toDartString();
  });
}

/// A linked program, with the binding points of its uniform blocks and the units of its textures, numbered from 0
/// (the bundle's bindings run past GL's limits).
final class _Pipeline implements ent.RenderPipeline {
  _Pipeline(this.vertex, this.fragment, this.layout) : program = glCreateProgram() {
    glAttachShader(program, vertex._name);
    glAttachShader(program, fragment._name);
    glLinkProgram(program);

    using((arena) {
      final status = arena<Int32>();
      glGetProgramiv(program, glLinkStatus, status);

      if (status.value == 0) {
        throw StateError(
          'ent_opengl: ${vertex.name} and ${fragment.name} do not link: '
          '${_log(program, glGetProgramiv, glGetProgramInfoLog)}',
        );
      }

      glUseProgram(program);
      final blocks = <String, int>{};
      final textures = <String, int>{};

      for (final shader in [vertex, fragment]) {
        for (final name in shader._source.blocks.keys) {
          final index = glGetUniformBlockIndex(program, name.toNativeUtf8(allocator: arena));

          if (index == glInvalidIndex) {
            continue;
          }

          final point = blocks[name] ??= blocks.length;
          glUniformBlockBinding(program, index, point);
          points[(shader, name)] = point;
        }

        for (final name in shader._source.textures.keys) {
          final location = glGetUniformLocation(program, name.toNativeUtf8(allocator: arena));

          if (location < 0) {
            continue;
          }

          final unit = textures[name] ??= textures.length;
          glUniform1i(location, unit);
          units[(shader, name)] = unit;
        }
      }

      flip = glGetUniformLocation(program, '_impeller_y_flip'.toNativeUtf8(allocator: arena));
      baseInstance = glGetUniformLocation(program, 'SPIRV_Cross_BaseInstance'.toNativeUtf8(allocator: arena));
    });
    _check('createRenderPipeline(${vertex.name}, ${fragment.name})');
  }

  final GlShader vertex;

  final GlShader fragment;

  final ent.VertexLayout? layout;

  final int program;

  final Map<(GlShader, String), int> points = {};

  final Map<(GlShader, String), int> units = {};

  int flip = -1;

  int baseInstance = -1;
}

int _blendFactor(ent.BlendFactor factor) => switch (factor) {
  ent.BlendFactor.zero => 0,
  ent.BlendFactor.one => 1,
  ent.BlendFactor.sourceColor => 0x0300,
  ent.BlendFactor.oneMinusSourceColor => 0x0301,
  ent.BlendFactor.sourceAlpha => 0x0302,
  ent.BlendFactor.oneMinusSourceAlpha => 0x0303,
  ent.BlendFactor.destinationAlpha => 0x0304,
  ent.BlendFactor.oneMinusDestinationAlpha => 0x0305,
  ent.BlendFactor.destinationColor => 0x0306,
  ent.BlendFactor.oneMinusDestinationColor => 0x0307,
  ent.BlendFactor.sourceAlphaSaturated => 0x0308,
  ent.BlendFactor.blendColor => 0x8001,
  ent.BlendFactor.oneMinusBlendColor => 0x8002,
  ent.BlendFactor.blendAlpha => 0x8003,
  ent.BlendFactor.oneMinusBlendAlpha => 0x8004,
};

int _blendOperation(ent.BlendOperation operation) => switch (operation) {
  ent.BlendOperation.add => 0x8006,
  ent.BlendOperation.subtract => 0x800A,
  ent.BlendOperation.reverseSubtract => 0x800B,
};

int _compare(ent.CompareFunction function) => switch (function) {
  ent.CompareFunction.never => 0x0200,
  ent.CompareFunction.less => 0x0201,
  ent.CompareFunction.equal => 0x0202,
  ent.CompareFunction.lessEqual => 0x0203,
  ent.CompareFunction.greater => 0x0204,
  ent.CompareFunction.notEqual => 0x0205,
  ent.CompareFunction.greaterEqual => 0x0206,
  ent.CompareFunction.always => 0x0207,
};

/// A render pass: its calls are recorded and replayed in order on submit; the bindings and state they set live on the
/// pass while it replays, and each draw applies them to GL. Drawn frames keep Flutter GPU's orientation: the shaders'
/// `_impeller_y_flip` turns them over, so row 0 of a target is its top, and viewports and scissors count from the top.
final class _Pass implements ent.RenderPass {
  _Pass(this._context, this._target, this._steps);

  final GlContext _context;

  final ent.RenderTarget _target;

  final List<void Function()> _steps;

  int _framebuffer = 0;

  (int, int) _size = (1, 1);

  // Whether the pass draws its first row at the bottom, as WebGL: every target but a cube map's face, whose first row
  // is at the top on every GPU (the shaders' _impeller_y_flip turns those over).
  bool _up = true;

  // What the replay has set so far.
  _Pipeline? _pipeline;

  final Map<int, ent.BufferView> _vertices = {};

  (ent.BufferView, ent.IndexType)? _index;

  final Map<(GlShader, String), ent.BufferView> _uniforms = {};

  final Map<(GlShader, String), (GlTexture, ent.SamplerOptions?)> _textures = {};

  bool _blend = false;

  ent.ColorBlendEquation _equation = ent.ColorBlendEquation();

  bool _depthWrite = false;

  ent.CompareFunction _depthCompare = ent.CompareFunction.always;

  ent.CullMode _cull = ent.CullMode.none;

  ent.WindingOrder _winding = ent.WindingOrder.clockwise;

  ent.PrimitiveType _primitive = ent.PrimitiveType.triangle;

  ent.Viewport? _viewport;

  ent.Scissor? _scissor;

  void _record(void Function() step) => _steps.add(step);

  void _begin() {
    _framebuffer = using((arena) {
      final value = arena<Uint32>();
      glGenFramebuffers(1, value);
      return value.value;
    });
    glBindFramebuffer(glFramebuffer, _framebuffer);
    var mask = 0;
    _up = !_target.colorAttachments.any((color) => (color.texture as GlTexture)._cube);

    for (final color in _target.colorAttachments) {
      (color.texture as GlTexture)._up = _up;
      (color.resolveTexture as GlTexture?)?._up = _up;
    }

    for (final (index, color) in _target.colorAttachments.indexed) {
      final texture = color.texture as GlTexture;
      _attach(glFramebuffer, glColorAttachment0 + index, texture, color.slice, color.mipLevel);
      _size = (
        (texture.width >> color.mipLevel).clamp(1, texture.width),
        (texture.height >> color.mipLevel).clamp(1, texture.height),
      );

      if (color.loadAction == ent.LoadAction.clear) {
        final c = color.clearValue;
        glClearColor(c.r, c.g, c.b, c.a);
        mask |= glColorBufferBit;
      }
    }

    final depth = _target.depthStencilAttachment;

    if (depth != null) {
      _attach(glFramebuffer, glDepthStencilAttachment, depth.texture as GlTexture, depth.slice, depth.mipLevel);

      if (depth.depthLoadAction == ent.LoadAction.clear) {
        glClearDepthf(depth.depthClearValue);
        mask |= glDepthBufferBit;
      }

      if (depth.stencilLoadAction == ent.LoadAction.clear) {
        glClearStencil(depth.stencilClearValue);
        mask |= glStencilBufferBit;
      }
    }

    final status = glCheckFramebufferStatus(glFramebuffer);

    if (status != glFramebufferComplete) {
      throw StateError('ent_opengl: the render target is incomplete (status 0x${status.toRadixString(16)}).');
    }

    glViewport(0, 0, _size.$1, _size.$2);

    if (mask != 0) {
      glDisable(glScissorTest);
      glColorMask(1, 1, 1, 1);
      glDepthMask(1);
      glStencilMask(0xFF);
      glClear(mask);
    }
  }

  // Attaches [texture] (a renderbuffer when multisampled) at [point] of the framebuffer bound to [target].
  static void _attach(int target, int point, GlTexture texture, int slice, int level) {
    if (texture.multisampled) {
      glFramebufferRenderbuffer(target, point, glRenderbuffer, texture.name);
      return;
    }

    glFramebufferTexture2D(
      target,
      point,
      texture._cube ? glTextureCubeMapPositiveX + slice : glTexture2D,
      texture.name,
      level,
    );
  }

  // Resolves the multisampled color attachments whose store action asks for it into their resolve textures, then
  // drops the framebuffer.
  void _end() {
    for (final (index, color) in _target.colorAttachments.indexed) {
      final resolve = color.resolveTexture as GlTexture?;

      if (resolve == null) {
        continue;
      }

      if (color.storeAction != ent.StoreAction.multisampleResolve &&
          color.storeAction != ent.StoreAction.storeAndMultisampleResolve) {
        continue;
      }

      using((arena) {
        final framebuffer = arena<Uint32>();
        glGenFramebuffers(1, framebuffer);
        glBindFramebuffer(glDrawFramebuffer, framebuffer.value);
        _attach(glDrawFramebuffer, glColorAttachment0, resolve, color.slice, color.mipLevel);
        glBindFramebuffer(glReadFramebuffer, _framebuffer);
        glReadBuffer(glColorAttachment0 + index);
        glBlitFramebuffer(0, 0, _size.$1, _size.$2, 0, 0, _size.$1, _size.$2, glColorBufferBit, glNearest);
        glBindFramebuffer(glDrawFramebuffer, 0);
        glDeleteFramebuffers(1, framebuffer);
      });
    }

    glBindFramebuffer(glFramebuffer, 0);
    using((arena) => glDeleteFramebuffers(1, arena<Uint32>()..value = _framebuffer));
  }

  @override
  void bindPipeline(ent.RenderPipeline pipeline) => _record(() => _pipeline = pipeline as _Pipeline);

  @override
  void bindVertexBuffer(ent.BufferView bufferView, {int slot = 0}) => _record(() => _vertices[slot] = bufferView);

  @override
  void bindIndexBuffer(ent.BufferView bufferView, ent.IndexType indexType) {
    _record(() => _index = (bufferView, indexType));
  }

  @override
  void bindUniform(ent.UniformSlot slot, ent.BufferView bufferView) {
    _record(() => _uniforms[(slot as _Slot)._key] = bufferView);
  }

  @override
  void bindTexture(ent.UniformSlot slot, ent.Texture texture, {ent.SamplerOptions? sampler}) {
    _record(() => _textures[(slot as _Slot)._key] = (texture as GlTexture, sampler));
  }

  @override
  void clearBindings() {
    _record(() {
      _vertices.clear();
      _index = null;
      _uniforms.clear();
      _textures.clear();
    });
  }

  @override
  void setColorBlendEnable(bool enable, {int colorAttachmentIndex = 0}) => _record(() => _blend = enable);

  @override
  void setColorBlendEquation(ent.ColorBlendEquation equation, {int colorAttachmentIndex = 0}) {
    _record(() => _equation = equation);
  }

  @override
  void setDepthWriteEnable(bool enable) => _record(() => _depthWrite = enable);

  @override
  void setDepthCompareOperation(ent.CompareFunction compareFunction) => _record(() => _depthCompare = compareFunction);

  @override
  void setCullMode(ent.CullMode cullMode) => _record(() => _cull = cullMode);

  @override
  void setWindingOrder(ent.WindingOrder windingOrder) => _record(() => _winding = windingOrder);

  @override
  void setPrimitiveType(ent.PrimitiveType primitiveType) => _record(() => _primitive = primitiveType);

  @override
  void setViewport(ent.Viewport viewport) => _record(() => _viewport = viewport);

  @override
  void setScissor(ent.Scissor scissor) => _record(() => _scissor = scissor);

  @override
  void draw(int vertexCount, {int instanceCount = 1}) {
    _record(() {
      _apply();
      glDrawArraysInstanced(_mode, 0, vertexCount, instanceCount);
    });
  }

  @override
  void drawIndexed(int indexCount, {int instanceCount = 1}) {
    _record(() {
      final (view, type) = _index ?? (throw StateError('ent_opengl: drawIndexed without an index buffer.'));
      _apply();
      glBindBuffer(glElementArrayBuffer, (view.buffer as _Buffer)._name);
      glDrawElementsInstanced(
        _mode,
        indexCount,
        type == ent.IndexType.int16 ? glUnsignedShort : glUnsignedInt,
        Pointer<Void>.fromAddress(view.offsetInBytes),
        instanceCount,
      );
    });
  }

  int get _mode => switch (_primitive) {
    ent.PrimitiveType.triangle => glTriangles,
    ent.PrimitiveType.triangleStrip => glTriangleStrip,
    ent.PrimitiveType.line => glLines,
    ent.PrimitiveType.lineStrip => glLineStrip,
    ent.PrimitiveType.point => glPoints,
  };

  // Applies the bindings and state the replay has set to GL, before a draw.
  void _apply() {
    final pipeline = _pipeline ?? (throw StateError('ent_opengl: a draw without a pipeline.'));
    glUseProgram(pipeline.program);
    glUniform1f(pipeline.flip, _up ? 1 : -1);
    glUniform1i(pipeline.baseInstance, 0);

    for (final location in _context._attributes) {
      glDisableVertexAttribArray(location);
    }

    _context._attributes.clear();

    for (final (slot, buffer) in (pipeline.layout?.buffers ?? const <ent.VertexBuffer>[]).indexed) {
      final view = _vertices[slot];

      if (view == null) {
        continue;
      }

      glBindBuffer(glArrayBuffer, (view.buffer as _Buffer)._name);

      for (final attribute in buffer.attributes) {
        final location = pipeline.vertex._source.inputs[attribute.name];

        if (location == null) {
          continue;
        }

        final format = attribute.format;
        final pointer = Pointer<Void>.fromAddress(view.offsetInBytes + attribute.offsetInBytes);
        glEnableVertexAttribArray(location);
        _context._attributes.add(location);

        if (format.index <= ent.VertexFormat.float32x4.index) {
          glVertexAttribPointer(location, format.componentCount, glFloat, 0, buffer.strideInBytes, pointer);
        } else {
          final signed = format.index >= ent.VertexFormat.sint32.index;
          glVertexAttribIPointer(
            location,
            format.componentCount,
            signed ? glInt : glUnsignedInt,
            buffer.strideInBytes,
            pointer,
          );
        }

        glVertexAttribDivisor(location, buffer.stepMode == ent.VertexStepMode.instance ? 1 : 0);
      }
    }

    for (final MapEntry(key: key, value: view) in _uniforms.entries) {
      final point = pipeline.points[key];

      if (point != null) {
        glBindBufferRange(
          glUniformBuffer,
          point,
          (view.buffer as _Buffer)._name,
          view.offsetInBytes,
          view.lengthInBytes,
        );
      }
    }

    for (final MapEntry(key: key, value: (texture, sampler)) in _textures.entries) {
      final unit = pipeline.units[key];

      if (unit == null) {
        continue;
      }

      glActiveTexture(glTexture0 + unit);
      glBindTexture(texture._cube ? glTextureCubeMap : glTexture2D, texture.name);
      glBindSampler(unit, _context._sampler(sampler ?? ent.SamplerOptions()));
    }

    if (_blend) {
      glEnable(glBlend);
      glBlendEquationSeparate(
        _blendOperation(_equation.colorBlendOperation),
        _blendOperation(_equation.alphaBlendOperation),
      );
      glBlendFuncSeparate(
        _blendFactor(_equation.sourceColorBlendFactor),
        _blendFactor(_equation.destinationColorBlendFactor),
        _blendFactor(_equation.sourceAlphaBlendFactor),
        _blendFactor(_equation.destinationAlphaBlendFactor),
      );
    } else {
      glDisable(glBlend);
    }

    if (_target.depthStencilAttachment == null) {
      glDisable(glDepthTest);
    } else {
      glEnable(glDepthTest);
      glDepthFunc(_compare(_depthCompare));
    }

    glDepthMask(_depthWrite ? 1 : 0);

    if (_cull == ent.CullMode.none) {
      glDisable(glCullFace);
    } else {
      glEnable(glCullFace);
      glCullFaceMode(_cull == ent.CullMode.frontFace ? glFront : glBack);
    }

    // Turned over (_impeller_y_flip -1), the target is mirrored, so the winding GL sees is the other one.
    var front = _winding == ent.WindingOrder.clockwise ? glCw : glCcw;

    if (!_up) {
      front = front == glCw ? glCcw : glCw;
    }

    glFrontFace(front);
    final viewport = _viewport;

    if (viewport == null) {
      glViewport(0, 0, _size.$1, _size.$2);
    } else {
      glViewport(viewport.x, _row(viewport.y, viewport.height), viewport.width, viewport.height);
    }

    final scissor = _scissor;

    if (scissor == null) {
      glDisable(glScissorTest);
    } else {
      glEnable(glScissorTest);
      glScissor(scissor.x, _row(scissor.y, scissor.height), scissor.width, scissor.height);
    }
  }

  // The renderer counts viewports and scissors from the target's top, as Flutter GPU does: GL's first row from the
  // bottom where the pass draws its first row there.
  int _row(int y, int height) {
    if (!_up) {
      return y;
    }

    return _size.$2 - y - height;
  }
}

/// GL's offsets of [members] of [block] in [pipeline]'s program (std140, as GL lays it out); null for one GL lacks.
@visibleForTesting
List<int?> memberOffsets(ent.RenderPipeline pipeline, String block, List<String> members) {
  return using((arena) {
    final names = arena<Pointer<Utf8>>(members.length);
    final indices = arena<Uint32>(members.length);
    final offsets = arena<Int32>(members.length);

    for (final (i, member) in members.indexed) {
      names[i] = '$block.$member'.toNativeUtf8(allocator: arena);
    }

    final program = (pipeline as _Pipeline).program;
    glGetUniformIndices(program, members.length, names, indices);
    glGetActiveUniformsiv(program, members.length, indices, glUniformOffset, offsets);
    return [for (var i = 0; i < members.length; i++) indices[i] == glInvalidIndex ? null : offsets[i]];
  });
}
