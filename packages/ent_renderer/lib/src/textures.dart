// Textures on Flutter GPU, uploaded and sampled as the reference renderer does: data and image textures are
// converted to RGBA texels on the CPU (flipY, premultiplyAlpha, unpackAlignment, the formats WebGL 2 samples as
// RGBA), stored in an sRGB pixel format where the reference picks SRGB8_ALPHA8, and given a mip chain when the
// minification filter uses one. Flutter GPU has no generateMipmap, so levels are box filtered here (in linear light
// for sRGB textures). A CubeTexture's six images become the slices of a cube texture, in WebGL's face order (+X, -X,
// +Y, -Y, +Z, -Z).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ent_renderer/gpu.dart' as gpu;
import 'package:ent/ent.dart';

import 'flutter_platform.dart';

/// RGBA texels of one level: [bytes] (8-bit) or [floats], rows in upload order (row 0 is t = 0). Floats of
/// HalfFloatType data are uploaded as half floats ([half]), as WebGL keeps them (RGBA16F), and so are those of a
/// linearly filtered FloatType texture where 32-bit floats are not filtered (clamped to ±65504; E-FLOATFILTER).
class _Texels {
  _Texels(this.width, this.height, {this.bytes, this.floats, this.half = false});

  final int width;

  final int height;

  final Uint8List? bytes;

  final Float32List? floats;

  final bool half;

  ByteData get data {
    if (bytes != null) {
      return bytes!.buffer.asByteData();
    }

    if (half) {
      return Uint16List.fromList([
        for (final v in floats!) DataUtils.toHalfFloat(MathUtils.clamp(v, -65504, 65504).toDouble()),
      ]).buffer.asByteData();
    }

    return floats!.buffer.asByteData();
  }
}

class _Entry {
  _Entry(this.version, this.mipmapped, this.texture, this.listener);

  final int version;

  final bool mipmapped;

  final gpu.Texture texture;

  final EventListener listener;
}

/// The GPU textures of an application render target (as the reference renderer sets up a plain 2D target): [color] and
/// a [depth] buffer, kept until the target's dispose event (which RenderTarget.setSize also fires). Rows are stored as
/// the frame's: row 0 is the top of the image (NDC +y), the opposite of WebGL's.
class GpuTarget {
  GpuTarget(this.color, this.depth, this.listener, {this.levels = 1, this.samples, this.depths, this.replay});

  /// A cube texture (six slices) for a WebGLCubeRenderTarget.
  final gpu.Texture color;

  /// For a target with `samples`, its 4× multisampled color, stored between renders and resolved into [color] at
  /// the end of each ([depth] is then multisampled too); `null` without.
  final gpu.Texture? samples;

  /// The mip levels of [color]: more than 1 for a cube target whose texture generates mipmaps.
  final int levels;

  final gpu.Texture depth;

  /// For a target with a depthTexture, what its depth texture reads: the depth of each texel in a 32-bit float color
  /// texture (exception E-DEPTHTEXTURE), written after each render into the target: copied from [depth] where the GPU
  /// samples depth buffers ([GpuTextures.readsDepth]), else drawn again with [replay].
  final gpu.Texture? depths;

  /// The depth buffer [depths] is drawn with, which replays the depth tests of [depth]; `null` where [depth] is
  /// copied.
  final gpu.Texture? replay;

  final EventListener listener;
}

/// Whether [texture]'s rows start at the top (see [GpuTarget]): a render target's texture or depth texture.
bool topDown(Texture texture, gpu.GpuContext context) {
  if (context.rowsUp) {
    return false;
  }

  return texture.isRenderTargetTexture || (texture is DepthTexture && texture.renderTarget != null);
}

/// The textures a renderer holds; [count] is reported as `renderer.info.memory.textures`.
class GpuTextures {
  GpuTextures(this._context);

  final gpu.GpuContext _context;

  final Map<Texture, _Entry> _entries = {};

  final Map<RenderTarget, GpuTarget> _targets = {};

  /// What WebGL samples from a texture that was never uploaded (no texture bound): opaque black.
  late final gpu.Texture fallback = _create(_Texels(1, 1, bytes: Uint8List.fromList([0, 0, 0, 255])), false, 1);

  /// [fallback] for a samplerCube.
  late final gpu.Texture fallbackCube = () {
    final texture = _create(_Texels(1, 1), false, 1, cube: true);

    for (var face = 0; face < 6; face++) {
      texture.overwrite(Uint8List.fromList([0, 0, 0, 255]).buffer.asByteData(), slice: face);
    }

    return texture;
  }();

  /// Whether the GPU filters 32-bit float textures linearly (checkFloatFilter); where it does not, a FloatType
  /// texture sampled with a linear filter is stored as half floats, which are filtered (exception E-FLOATFILTER).
  bool filtersFloat = true;

  /// Whether the GPU samples a depth buffer (checkDepthRead); where it does, a target's depth texture is copied from
  /// its depth buffer instead of drawn again (exception E-DEPTHTEXTURE).
  bool readsDepth = false;

  /// Whether [texture] is FloatType data that this GPU would not filter as WebGL with OES_texture_float_linear does:
  /// a magnification or minification filter other than NEAREST and NEAREST_MIPMAP_NEAREST.
  bool halves(Texture texture) {
    return !filtersFloat &&
        texture.type == FloatType &&
        (texture.magFilter != NearestFilter ||
            (texture.minFilter != NearestFilter && texture.minFilter != NearestMipmapNearestFilter));
  }

  /// A target's depth texture counts as one more (the reference uploads it as a texture of its own).
  int get count => _entries.length + _targets.length + _targets.values.where((t) => t.depths != null).length;

  /// The GPU textures of [target], created on first use: one 8-bit RGBA (SRGB8_ALPHA8 for an sRGB texture),
  /// RGBA16F (HalfFloatType) or RGBA32F (FloatType) color texture and a depth buffer, both 4× multisampled
  /// behind a resolved color texture when `samples` is above 0 (any count: Flutter GPU offers 4, exception
  /// E-ANTIALIAS), and for a 2D target with a DepthTexture the 32-bit float texture it reads (E-DEPTHTEXTURE).
  /// Unsupported options (samples of cube, 3D and array targets, without offscreen MSAA or with a depthTexture,
  /// count, the depthTexture of other targets, depth, stencil, generateMipmaps) are ignored with one warning each.
  GpuTarget target(RenderTarget target) {
    final cached = _targets[target];

    // A depthTexture set or removed after the first render rebuilds the textures (setupDepthRenderbuffer).
    if (cached != null && (cached.depths != null) == (target.depthTexture is DepthTexture)) {
      return cached;
    }

    if (cached != null) {
      target.removeEventListener('dispose', cached.listener);
    }

    final texture = target.texture;
    final cube = target is WebGLCubeRenderTarget;
    final depth = target.depthTexture is DepthTexture && !cube && target.depth == 1;
    final samples = target.samples > 0 && !cube && !depth && target.depth == 1 && _context.doesSupportOffscreenMSAA
        ? 4
        : 1;

    for (final (unsupported, option) in [
      (target.samples > 0 && samples == 1, 'samples (MSAA) of a cube, 3D or array target or without offscreen MSAA'),
      (target.textures.length > 1, 'count (MRT)'),
      (target.samples > 0 && depth, 'samples (MSAA) with a depthTexture'),
      (target.depthTexture != null && !depth, 'depthTexture of a cube, 3D or array target'),
      (target.depth > 1, 'depth (3D and array targets)'),
      (target.stencilBuffer, 'stencilBuffer'),
      (!target.depthBuffer, 'depthBuffer: false (a depth buffer is attached)'),
      (_mipmapped(texture) && !cube, 'generateMipmaps'),
    ]) {
      if (unsupported) {
        warnOnce('FlutterGpuRenderer: render target $option is not supported; ignored.');
      }
    }

    final format = switch (texture.type) {
      HalfFloatType => gpu.PixelFormat.r16g16b16a16Float,
      FloatType => gpu.PixelFormat.r32g32b32a32Float,
      UnsignedByteType when ColorManagement.getTransfer(texture.colorSpace) == SRGBTransfer =>
        gpu.PixelFormat.r8g8b8a8UNormIntSRGB,
      UnsignedByteType => gpu.PixelFormat.r8g8b8a8UNormInt,
      _ => () {
        warnOnce('FlutterGpuRenderer: render target texture type ${texture.type} is not supported; using 8-bit RGBA.');
        return gpu.PixelFormat.r8g8b8a8UNormInt;
      }(),
    };

    void listener(Event _) {
      _targets.remove(target);
      target.removeEventListener('dispose', listener);
    }

    target.addEventListener('dispose', listener);

    // A cube target's mip chain is filled after its last face, as the reference renderer does.
    var levels = 1;

    if (cube && _mipmapped(texture)) {
      levels = _context.maxMipLevelCount(target.width, target.height);
    }

    return _targets[target] = GpuTarget(
      _context.createTexture(
        gpu.StorageMode.devicePrivate,
        target.width,
        target.height,
        format: format,
        textureType: cube ? gpu.TextureType.textureCube : gpu.TextureType.texture2D,
        mipLevelCount: levels,
      ),
      _context.createTexture(
        gpu.StorageMode.devicePrivate,
        target.width,
        target.height,
        format: _context.defaultDepthStencilFormat,
        sampleCount: samples,
        enableShaderReadUsage: depth && readsDepth,
      ),
      listener,
      levels: levels,
      depths: depth
          ? _context.createTexture(
              gpu.StorageMode.devicePrivate,
              target.width,
              target.height,
              format: gpu.PixelFormat.r32Float,
            )
          : null,
      replay: depth && !readsDepth
          ? _context.createTexture(
              gpu.StorageMode.devicePrivate,
              target.width,
              target.height,
              format: _context.defaultDepthStencilFormat,
              enableShaderReadUsage: false,
            )
          : null,
      samples: samples == 1
          ? null
          : _context.createTexture(
              gpu.StorageMode.devicePrivate,
              target.width,
              target.height,
              format: format,
              sampleCount: samples,
              enableShaderReadUsage: false,
            ),
    );
  }

  /// The GPU textures of the cube render target whose texture is [texture] (a cube target's texture has no
  /// `renderTarget` set), `null` before the target is first drawn.
  GpuTarget? cube(Texture texture) {
    for (final MapEntry(key: target, value: entry) in _targets.entries) {
      if (target is WebGLCubeRenderTarget && target.texture == texture) {
        return entry;
      }
    }

    return null;
  }

  /// The GPU texture for [texture], uploaded or re-uploaded when its version changed. A texture that was never marked
  /// for update, or whose image is missing or incomplete, reads as [fallback] (with the reference's warning for the
  /// last two).
  gpu.Texture texture(Texture texture) {
    final target = texture.renderTarget;

    // A render target's texture is what the last render into it drew ([fallback] before that), its depth
    // texture the depth buffer of that render.
    if (texture is DepthTexture && target != null) {
      return _targets[target]?.depths ?? fallback;
    }

    if (texture.isRenderTargetTexture && target != null) {
      return _targets[target]?.color ?? fallback;
    }

    final cached = _entries[texture];
    final mipmapped = _mipmapped(texture);

    if (cached != null && cached.version == texture.version && cached.mipmapped == mipmapped) {
      return cached.texture;
    }

    if (texture.version == 0) {
      return cached?.texture ?? (texture is CubeTexture ? fallbackCube : fallback);
    }

    final image = texture.image;

    if (texture is CubeTexture) {
      return _cube(texture, cached, mipmapped) ?? cached?.texture ?? fallbackCube;
    }

    if (image == null) {
      warn('FlutterGpuRenderer: Texture marked for update but no image data found.');
      return cached?.texture ?? fallback;
    }

    if (image is FlutterImage && !image.complete) {
      warn('FlutterGpuRenderer: Texture marked for update but image is incomplete');
      return cached?.texture ?? fallback;
    }

    final levels = _levels(texture, image);

    if (levels == null) {
      return cached?.texture ?? fallback;
    }

    final (given, count) = levels;
    final uploaded = _create(given.first, _srgb(texture), count);

    for (var i = 0; i < given.length; i++) {
      uploaded.overwrite(given[i].data, mipLevel: i);
    }

    _fill(uploaded, [given], count, _srgb(texture));
    return _keep(texture, cached, mipmapped, uploaded);
  }

  gpu.Texture _keep(Texture texture, _Entry? cached, bool mipmapped, gpu.Texture uploaded) {
    final listener = cached?.listener ?? (_) => _forget(texture);

    if (cached == null) {
      texture.addEventListener('dispose', listener);
    }

    _entries[texture] = _Entry(texture.version, mipmapped, uploaded, listener);

    return uploaded;
  }

  /// Uploads a CubeTexture's six images (FlutterImage, DataTexture or DataImage faces of one size), as the reference
  /// renderer uploads them; `null` while a face is missing or not decoded.
  gpu.Texture? _cube(CubeTexture texture, _Entry? cached, bool mipmapped) {
    final images = texture.image;

    if (images is! List || images.length != 6) {
      return null;
    }

    final faces = <List<_Texels>>[];
    final counts = <int>[];

    for (final face in images) {
      final Object? image = face is DataTexture ? face.image : face;

      if (image == null || (image is FlutterImage && !image.complete)) {
        return null;
      }

      final levels = _levels(texture, image);

      if (levels == null) {
        return null;
      }

      faces.add(levels.$1);
      counts.add(levels.$2);
    }

    final count = counts.reduce(math.min);
    final uploaded = _create(faces.first.first, _srgb(texture), count, cube: true);

    for (var face = 0; face < 6; face++) {
      for (var i = 0; i < math.min(count, faces[face].length); i++) {
        uploaded.overwrite(faces[face][i].data, mipLevel: i, slice: face);
      }
    }

    _fill(uploaded, faces, count, _srgb(texture));
    return _keep(texture, cached, mipmapped, uploaded);
  }

  /// The sampler the reference renderer would use for [texture] (wrapS/wrapT, magFilter, minFilter, anisotropy).
  gpu.SamplerOptions sampler(Texture texture) {
    final mag = texture.magFilter == NearestFilter ? gpu.MinMagFilter.nearest : gpu.MinMagFilter.linear;
    final min = switch (texture.minFilter) {
      NearestFilter || NearestMipmapNearestFilter || NearestMipmapLinearFilter => gpu.MinMagFilter.nearest,
      _ => gpu.MinMagFilter.linear,
    };
    final mip = switch (texture.minFilter) {
      NearestMipmapLinearFilter || LinearMipmapLinearFilter => gpu.MipFilter.linear,
      _ => gpu.MipFilter.nearest,
    };

    // The reference applies anisotropy only to linear-mipmap minification with a linear magnification filter;
    // Flutter GPU further needs all three filters linear.
    final anisotropy =
        texture.anisotropy > 1 &&
            mag == gpu.MinMagFilter.linear &&
            min == gpu.MinMagFilter.linear &&
            mip == gpu.MipFilter.linear
        ? math.min(texture.anisotropy.floor(), _context.maxSamplerAnisotropy)
        : 1;

    return gpu.SamplerOptions(
      magFilter: mag,
      minFilter: min,
      mipFilter: mip,
      widthAddressMode: _wrap(texture.wrapS),
      heightAddressMode: _wrap(texture.wrapT),
      maxAnisotropy: anisotropy < 1 ? 1 : anisotropy,
    );
  }

  void dispose() {
    for (final MapEntry(key: texture, value: entry) in _entries.entries) {
      texture.removeEventListener('dispose', entry.listener);
    }

    _entries.clear();

    for (final MapEntry(key: target, value: entry) in _targets.entries) {
      target.removeEventListener('dispose', entry.listener);
    }

    _targets.clear();
  }

  void _forget(Texture texture) {
    final entry = _entries.remove(texture);

    if (entry != null) {
      texture.removeEventListener('dispose', entry.listener);
    }
  }

  static gpu.SamplerAddressMode _wrap(int wrap) {
    return switch (wrap) {
      RepeatWrapping => gpu.SamplerAddressMode.repeat,
      MirroredRepeatWrapping => gpu.SamplerAddressMode.mirror,
      _ => gpu.SamplerAddressMode.clampToEdge,
    };
  }

  /// Whether sampling uses mip levels. WebGL allocates log2(max(w, h)) + 1 levels when generateMipmaps is
  /// set (or the user's mipmaps), but a non-mipmap minification filter reads only the base level; Flutter
  /// GPU's samplers always pick a level, so such a texture is uploaded with the base level only.
  static bool _mipmapped(Texture texture) {
    final filter = texture.minFilter;
    return filter != NearestFilter && filter != LinearFilter && (texture.generateMipmaps || texture.mipmaps.isNotEmpty);
  }

  /// Whether the reference would store [texture] as SRGB8_ALPHA8 (decoded to linear when sampled): 8-bit RGBA data in
  /// a color space with the sRGB transfer function.
  static bool _srgb(Texture texture) {
    return texture.format == RGBAFormat &&
        texture.type == UnsignedByteType &&
        ColorManagement.getTransfer(texture.colorSpace) == SRGBTransfer;
  }

  gpu.Texture _create(_Texels base, bool srgb, int levels, {bool cube = false}) {
    return _context.createTexture(
      gpu.StorageMode.devicePrivate,
      base.width,
      base.height,
      format: base.floats != null
          ? (base.half ? gpu.PixelFormat.r16g16b16a16Float : gpu.PixelFormat.r32g32b32a32Float)
          : srgb
          ? gpu.PixelFormat.r8g8b8a8UNormIntSRGB
          : gpu.PixelFormat.r8g8b8a8UNormInt,
      textureType: cube ? gpu.TextureType.textureCube : gpu.TextureType.texture2D,
      enableRenderTargetUsage: false,
      mipLevelCount: levels,
    );
  }

  /// The levels to upload and how many the texture has, or `null` (with a warning) for an image this renderer cannot
  /// read: every level of [Texture.mipmaps] when set; else the base, and for a mipmapped texture the count WebGL's
  /// getMipLevels gives, whose levels below the base [_fill] writes.
  (List<_Texels>, int)? _levels(Texture texture, Object image) {
    final user = texture.mipmaps;

    if (user.isNotEmpty) {
      final levels = <_Texels>[];

      for (final level in user) {
        final texels = level == null ? null : _texels(texture, level);

        if (texels == null) {
          return null;
        }

        levels.add(texels);
      }

      // texture.mipmaps sets the level count; without a mipmap filter only the base level is read.
      final count = _mipmapped(texture)
          ? math.min(levels.length, _context.maxMipLevelCount(levels.first.width, levels.first.height))
          : 1;

      return (levels.sublist(0, count), count);
    }

    final base = _texels(texture, image);

    if (base == null) {
      return null;
    }

    if (!_mipmapped(texture)) {
      return ([base], 1);
    }

    // getMipLevels: log2(max(width, height)) + 1, capped by what the GPU interface allocates (Flutter GPU stops one
    // level short of 1×1 and counts from the smaller side; flutter/flutter#186176).
    return (
      [base],
      math.min(math.max(base.width, base.height).bitLength, _context.maxMipLevelCount(base.width, base.height)),
    );
  }

  /// Writes the levels of [texture] below those of [faces] (one list of levels per slice) up to [count]: on the GPU
  /// as the reference's generateMipmap does where the GPU interface can, else here, each texel the average of a 2 × 2
  /// block of the level above (in linear light for an sRGB texture, [srgb]; exception E-MIPFILTER).
  void _fill(gpu.Texture texture, List<List<_Texels>> faces, int count, bool srgb) {
    if (faces.every((levels) => levels.length >= count) || texture.generateMipmaps()) {
      return;
    }

    for (final (slice, levels) in faces.indexed) {
      for (var level = levels.last, i = levels.length; i < count; i++) {
        level = _halve(level, srgb);
        texture.overwrite(level.data, mipLevel: i, slice: slice);
      }
    }
  }

  /// The RGBA texels of [image] as WebGL uploads it: [DataImage] data of the texture's format and type, or a
  /// decoded [FlutterImage]; then UNPACK_FLIP_Y_WEBGL and UNPACK_PREMULTIPLY_ALPHA_WEBGL.
  _Texels? _texels(Texture texture, Object image) {
    final _Texels texels;

    if (image is FlutterImage) {
      texels = _Texels(image.width, image.height, bytes: Uint8List.fromList(image.pixels!));
    } else if (image is DataImage && image.data != null) {
      final read = _read(texture, image);

      if (read == null) {
        return null;
      }

      texels = read;
    } else {
      warn('FlutterGpuRenderer: unsupported texture image ${image.runtimeType}; the texture reads as black.');
      return null;
    }

    if (texture.flipY) {
      _flip(texels);
    }

    if (texture.premultiplyAlpha) {
      _premultiply(texels);
    }

    return texels;
  }

  /// Expands data of [RGBAFormat], [RGBFormat], [RGFormat], [RedFormat] or [AlphaFormat] with
  /// [UnsignedByteType], [FloatType] or [HalfFloatType] to RGBA as WebGL 2 samples it (missing color
  /// components 0, missing alpha 1; ALPHA reads (0, 0, 0, a)), honouring the row alignment.
  _Texels? _read(Texture texture, DataImage image) {
    final width = image.width ?? 0;
    final height = image.height ?? 0;
    final channels = switch (texture.format) {
      RGBAFormat => 4,
      RGBFormat => 3,
      RGFormat => 2,
      RedFormat => 1,
      AlphaFormat => 1,
      _ => 0,
    };
    final type = texture.type;
    final size = switch (type) {
      UnsignedByteType => 1,
      HalfFloatType => 2,
      FloatType => 4,
      _ => 0,
    };

    if (channels == 0 || size == 0 || width < 1 || height < 1) {
      warn(
        'FlutterGpuRenderer: unsupported texture format ${texture.format} / type ${texture.type}; the texture '
        'reads as black.',
      );
      return null;
    }

    final data = image.data! as List<num>;
    final alignment = texture.unpackAlignment;
    final stride = ((width * channels * size + alignment - 1) ~/ alignment) * alignment ~/ size;
    final alpha = texture.format == AlphaFormat;
    final bytes = type == UnsignedByteType;
    final List<num> out = bytes ? Uint8List(width * height * 4) : Float32List(width * height * 4);

    double value(int i) {
      final v = i < data.length ? data[i] : 0;
      return type == HalfFloatType ? DataUtils.fromHalfFloat(v.toInt()) : v.toDouble();
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final s = y * stride + x * channels;
        final d = (y * width + x) * 4;

        for (var c = 0; c < 4; c++) {
          final v = alpha
              ? (c == 3 ? value(s) : 0.0)
              : c < channels
              ? value(s + c)
              : (c == 3 ? (bytes ? 255.0 : 1.0) : 0.0);
          out[d + c] = bytes ? v.toInt() : v;
        }
      }
    }

    return bytes
        ? _Texels(width, height, bytes: out as Uint8List)
        : _Texels(width, height, floats: out as Float32List, half: type == HalfFloatType || halves(texture));
  }

  static void _flip(_Texels texels) {
    final row = texels.width * 4;
    final List<num> data = texels.bytes ?? texels.floats!;

    for (var y = 0; y < texels.height ~/ 2; y++) {
      final a = y * row;
      final b = (texels.height - 1 - y) * row;

      for (var i = 0; i < row; i++) {
        final t = data[a + i];
        data[a + i] = data[b + i];
        data[b + i] = t;
      }
    }
  }

  static void _premultiply(_Texels texels) {
    final bytes = texels.bytes;

    if (bytes != null) {
      for (var i = 0; i < bytes.length; i += 4) {
        final a = bytes[i + 3];

        for (var c = 0; c < 3; c++) {
          bytes[i + c] = (bytes[i + c] * a / 255).round();
        }
      }
    } else {
      final floats = texels.floats!;

      for (var i = 0; i < floats.length; i += 4) {
        for (var c = 0; c < 3; c++) {
          floats[i + c] *= floats[i + 3];
        }
      }
    }
  }

  static final List<double> _decode = [for (var i = 0; i < 256; i++) SRGBToLinear(i / 255)];

  /// The next mip level: a 2×2 box filter (edge texels repeated for odd sizes), averaged in linear light
  /// for an sRGB texture, as the GPU's own mipmap generation does.
  static _Texels _halve(_Texels source, bool srgb) {
    final width = math.max(1, source.width ~/ 2);
    final height = math.max(1, source.height ~/ 2);
    final sw = source.width;

    int at(int x, int y) => (math.min<int>(y, source.height - 1) * sw + math.min<int>(x, sw - 1)) * 4;

    final bytes = source.bytes;

    if (bytes != null) {
      final out = Uint8List(width * height * 4);

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final p = [at(2 * x, 2 * y), at(2 * x + 1, 2 * y), at(2 * x, 2 * y + 1), at(2 * x + 1, 2 * y + 1)];
          final d = (y * width + x) * 4;

          for (var c = 0; c < 4; c++) {
            if (srgb && c < 3) {
              out[d + c] = (LinearToSRGB(p.fold(0.0, (sum, i) => sum + _decode[bytes[i + c]]) / 4) * 255).round();
            } else {
              out[d + c] = (p.fold(0, (sum, i) => sum + bytes[i + c]) / 4).round();
            }
          }
        }
      }

      return _Texels(width, height, bytes: out);
    }

    final floats = source.floats!;
    final out = Float32List(width * height * 4);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = [at(2 * x, 2 * y), at(2 * x + 1, 2 * y), at(2 * x, 2 * y + 1), at(2 * x + 1, 2 * y + 1)];
        final d = (y * width + x) * 4;

        for (var c = 0; c < 4; c++) {
          out[d + c] = p.fold(0.0, (sum, i) => sum + floats[i + c]) / 4;
        }
      }
    }

    return _Texels(width, height, floats: out, half: source.half);
  }
}
