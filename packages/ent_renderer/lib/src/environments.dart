// Environment maps as the reference renderer resolves them: a CubeTexture as uploaded, an equirectangular texture
// converted to a cube render target (WebGLCubeRenderTarget.fromEquirectangularTexture), and either of them
// prefiltered into a PMREM (PMREMGenerator): a cube render target whose mip levels hold the GGX-filtered radiance
// from a mirror at level 0 to roughness 1. Both run as render-to-texture passes (passes.dart) on Flutter GPU.

import 'dart:math' as math;

import 'package:ent_renderer/gpu.dart' as gpu;
import 'package:ent/ent.dart';

import 'flutter_platform.dart';
import 'passes.dart';
import 'programs.dart';
import 'textures.dart';

/// A cube map a material or background samples.
class GpuEnvironment {
  GpuEnvironment(
    this.texture,
    this.sampler, {
    this.maxLod,
    this.renderTarget = true,
    this.mapping = CubeReflectionMapping,
  });

  final gpu.Texture texture;

  final gpu.SamplerOptions sampler;

  /// ENVMAP_MAX_LOD for a PMREM (its last mip level), `null` for a plain cube map (ENVMAP_TYPE_CUBE).
  final double? maxLod;

  /// The reference's `isRenderTargetTexture`: `false` for a CubeTexture, whose images are mirrored in x (flipEnvMap,
  /// the envMapRotation premultiply).
  final bool renderTarget;

  /// CubeReflectionMapping or CubeRefractionMapping (mapTextureMapping of a converted equirectangular map).
  final int mapping;

  bool get pmrem => maxLod != null;
}

class _Cached {
  _Cached(this.version, this.environment);

  final int version;

  final GpuEnvironment environment;
}

/// The cube maps and PMREMs a renderer holds, keyed by their source texture and rebuilt when its version
/// changes.
class GpuEnvironments {
  GpuEnvironments(this._context, this._passes, this._textures);

  final gpu.GpuContext _context;

  final GpuPasses _passes;

  final GpuTextures _textures;

  final Map<Texture, _Cached> _cubes = {};

  final Map<Texture, _Cached> _pmrems = {};

  gpu.Texture? _source;

  // PMREMGenerator: smaller inputs are upsampled to MIN_SIZE; LOD_MIN is log2 of the roughest level's face size;
  // the rough levels integrate a source level of INTEGRATION_SIZE.
  static const int _minSize = 256;

  static const int _lodMin = 3;

  static const int _ggxSamples = 256;

  static const int _integrationSize = 16;

  static const int _integrationLevels = 3;

  static final gpu.SamplerOptions _trilinear = gpu.SamplerOptions(
    minFilter: gpu.MinMagFilter.linear,
    magFilter: gpu.MinMagFilter.linear,
    mipFilter: gpu.MipFilter.linear,
  );

  /// The cube map of [texture] (a PMREM when [pmrem]), [texture]'s own cube map when it needs no conversion, or
  /// `null` for a texture that is not a cube or equirectangular map, or not ready.
  GpuEnvironment? get(Texture? texture, {required bool pmrem}) {
    if (texture == null) {
      return null;
    }

    return pmrem ? _pmrem(texture) : _cube(texture);
  }

  /// Whether [texture] is a cube or equirectangular map, which [get] resolves.
  static bool isEnvironment(Texture texture) {
    return switch (texture.mapping) {
      CubeReflectionMapping ||
      CubeRefractionMapping ||
      EquirectangularReflectionMapping ||
      EquirectangularRefractionMapping => true,
      _ => false,
    };
  }

  static bool _equirect(Texture texture) {
    return texture.mapping == EquirectangularReflectionMapping || texture.mapping == EquirectangularRefractionMapping;
  }

  void dispose() {
    _cubes.clear();
    _pmrems.clear();
    _source = null;
  }

  // getCube: an equirectangular map becomes a cube render target of the image's height; a CubeTexture is used as
  // it is.
  GpuEnvironment? _cube(Texture texture) {
    if (texture is CubeTexture) {
      return GpuEnvironment(
        _texture(texture),
        _textures.sampler(texture),
        renderTarget: false,
        mapping: texture.mapping,
      );
    }

    if (!_equirect(texture)) {
      return null;
    }

    final cached = _cubes[texture];

    if (cached != null && cached.version == texture.version) {
      return cached.environment;
    }

    final height = _height(texture);

    if (height == null) {
      return null;
    }

    final source = _textures.texture(texture);
    final mipmapped =
        texture.generateMipmaps && texture.minFilter != NearestFilter && texture.minFilter != LinearFilter;
    final levels = mipmapped ? math.min(height.bitLength, _context.maxMipLevelCount(height, height)) : 1;

    // Half floats where 32-bit floats are not filtered, as the source is (E-FLOATFILTER).
    final target = _context.createTexture(
      gpu.StorageMode.devicePrivate,
      height,
      height,
      format: _textures.halves(texture) ? gpu.PixelFormat.r16g16b16a16Float : _format(texture),
      textureType: gpu.TextureType.textureCube,
      mipLevelCount: levels,
    );

    // The texture's minFilter is switched to LinearFilter for the conversion ("avoid blurred poles"); its
    // magFilter and wrapping stay.
    final sampler = _textures.sampler(texture)
      ..minFilter = gpu.MinMagFilter.linear
      ..mipFilter = gpu.MipFilter.nearest
      ..maxAnisotropy = 1;

    _passes.begin();

    for (var face = 0; face < 6; face++) {
      _passes.run(
        target,
        'CubeFromEquirectFragment',
        slice: face,
        blocks: {'FaceInfo': (block) => _face(block, face, height)},
        textures: {'source': PassTexture(source, sampler)},
      );
    }

    _mipmaps(target, height, levels);

    // The render target's texture takes the source's filters (fromEquirectangularTexture).
    final environment = GpuEnvironment(
      target,
      gpu.SamplerOptions(
        minFilter: switch (texture.minFilter) {
          NearestFilter || NearestMipmapNearestFilter || NearestMipmapLinearFilter => gpu.MinMagFilter.nearest,
          _ => gpu.MinMagFilter.linear,
        },
        magFilter: texture.magFilter == NearestFilter ? gpu.MinMagFilter.nearest : gpu.MinMagFilter.linear,
        mipFilter: switch (texture.minFilter) {
          NearestMipmapLinearFilter || LinearMipmapLinearFilter => gpu.MipFilter.linear,
          _ => gpu.MipFilter.nearest,
        },
      ),
      mapping: texture.mapping == EquirectangularRefractionMapping ? CubeRefractionMapping : CubeReflectionMapping,
    );

    _cubes[texture] = _Cached(texture.version, environment);
    return environment;
  }

  // getPMREM for an equirectangular or cube map; any other texture is not an environment here.
  GpuEnvironment? _pmrem(Texture texture) {
    if (!isEnvironment(texture)) {
      return null;
    }

    final cached = _pmrems[texture];

    // A render target texture is filtered again when its pmremVersion changes (CubeCamera.update).
    final version = texture.isRenderTargetTexture ? texture.pmremVersion : texture.version;

    if (cached != null && cached.version == version) {
      return cached.environment;
    }

    final int requested;

    if (texture is CubeTexture) {
      final images = texture.image;

      if (images is! List || images.length != 6 || images.any((image) => _size(image) == null)) {
        return null;
      }

      requested = _size(images.first)!.$1;
    } else {
      final width = _size(texture.image)?.$1;

      if (width == null || _height(texture) == null) {
        return null;
      }

      requested = width ~/ 4;
    }

    // _setSize: at least MIN_SIZE, rounded down to a power of two.
    final size = math.max(_minSize, requested < 1 ? 1 : 1 << (requested.bitLength - 1));
    final maxLod = size.bitLength - 1 - _lodMin;
    final pmrem = _target(size, maxLod + 1);

    _passes.begin();
    _toCubemap(texture, size);
    _apply(pmrem, size, maxLod);

    final environment = GpuEnvironment(pmrem, _trilinear, maxLod: maxLod.toDouble());
    _pmrems[texture] = _Cached(version, environment);
    return environment;
  }

  // _textureToCubemap: the source map at level 0 of the source target, then its mip levels (the source target
  // generates mipmaps).
  void _toCubemap(Texture texture, int size) {
    final levels = math.min(size.bitLength, _context.maxMipLevelCount(size, size));

    if (_source == null || _source!.width != size) {
      _source = _target(size, levels);
    }

    final target = _source!;
    final cube = texture is CubeTexture;
    final source = PassTexture(cube ? _texture(texture) : _textures.texture(texture), _textures.sampler(texture));

    for (var face = 0; face < 6; face++) {
      _passes.run(
        target,
        cube ? 'PmremCubeFragment' : 'PmremEquirectFragment',
        slice: face,
        blocks: {
          'FaceInfo': (block) => _face(block, face, size),
          if (cube) 'CubeInfo': (block) => block.float('flip', -1),
        },
        textures: {'source': source},
      );
    }

    _mipmaps(target, size, levels);
  }

  // A CubeTexture's GPU texture, or the faces a CubeCamera drew into a cube render target (opaque black before that).
  // Those are drawn with the WebGPU coordinate system's cameras, which store them as a CubeTexture's images: both are
  // mirrored in x when sampled (as the reference's WebGPU renderer does), the same texels the reference renderer's
  // isRenderTargetTexture layout gives without the flip.
  gpu.Texture _texture(CubeTexture texture) {
    if (texture.isRenderTargetTexture) {
      return _textures.cube(texture)?.color ?? _textures.fallbackCube;
    }

    return _textures.texture(texture);
  }

  // _applyPMREM: the sharp levels by GGX importance sampling, the INTEGRATION_LEVELS roughest by integrating a
  // small source level.
  void _apply(gpu.Texture pmrem, int size, int maxLod) {
    final source = PassTexture(_source!, _trilinear);

    for (var lod = 0; lod <= maxLod; lod++) {
      final roughness = lodToRoughness(lod.toDouble(), maxLod.toDouble());
      final faceSize = GpuPasses.levelSize(size, lod);

      for (var face = 0; face < 6; face++) {
        if (lod > maxLod - _integrationLevels) {
          _passes.run(
            pmrem,
            'PmremIntegrationFragment',
            slice: face,
            level: lod,
            blocks: {
              'FaceInfo': (block) => _face(block, face, faceSize),
              'IntegrationInfo': (block) => block
                ..float('roughness', roughness)
                ..float('source_lod', _log2(size / _integrationSize))
                ..float('source_size', _integrationSize.toDouble()),
            },
            textures: {'source': source},
          );
        } else {
          // For V = N, pdf(L) = D(H) / 4: the source texel solid angle matches 1 / (GGX_SAMPLES × pdf), with a
          // half-mip bias against sampling noise.
          final bias = roughness > 0
              ? _log2(size.toDouble()) + 0.5 * _log2(6 / (_ggxSamples * math.pow(roughness, 4))) + 0.5
              : 0.0;

          _passes.run(
            pmrem,
            'PmremGgxFragment',
            slice: face,
            level: lod,
            blocks: {
              'FaceInfo': (block) => _face(block, face, faceSize),
              'GgxInfo': (block) => block
                ..float('roughness', roughness)
                ..float('lod_bias', bias),
            },
            textures: {'source': source},
          );
        }
      }
    }
  }

  /// PMREMGenerator.lodToRoughness.
  static double lodToRoughness(double lod, double maxLod) {
    return maxLod > 0 ? 1 - math.sqrt(1 - lod / maxLod) : 0;
  }

  static double _log2(double x) => math.log(x) / math.ln2;

  // A HalfFloatType cube render target in LinearSRGBColorSpace (_createRenderTarget).
  gpu.Texture _target(int size, int levels) {
    return _context.createTexture(
      gpu.StorageMode.devicePrivate,
      size,
      size,
      format: gpu.PixelFormat.r16g16b16a16Float,
      textureType: gpu.TextureType.textureCube,
      mipLevelCount: levels,
    );
  }

  /// Levels 1 to [levels] - 1 of a cube target, each a box filter of the one above (generateMipmap).
  void mipmaps(gpu.Texture target, int size, int levels) {
    _passes.begin();
    _mipmaps(target, size, levels);
  }

  void _mipmaps(gpu.Texture target, int size, int levels) {
    for (var level = 1; level < levels; level++) {
      for (var face = 0; face < 6; face++) {
        _passes.run(
          target,
          'CubeMipFragment',
          slice: face,
          level: level,
          blocks: {
            'FaceInfo': (block) => _face(block, face, GpuPasses.levelSize(size, level)),
            'MipInfo': (block) => block.float('source_lod', level - 1.0),
          },
          textures: {
            'source': PassTexture(
              target,
              gpu.SamplerOptions(minFilter: gpu.MinMagFilter.linear, magFilter: gpu.MinMagFilter.linear),
            ),
          },
        );
      }
    }
  }

  static void _face(UniformBlock block, int face, int size) {
    block
      ..float('face', face.toDouble())
      ..float('size', size.toDouble());
  }

  // The render target format the reference picks for the converted map: the source's type and color space.
  static gpu.PixelFormat _format(Texture texture) {
    return switch (texture.type) {
      HalfFloatType => gpu.PixelFormat.r16g16b16a16Float,
      FloatType => gpu.PixelFormat.r32g32b32a32Float,
      _ when ColorManagement.getTransfer(texture.colorSpace) == SRGBTransfer => gpu.PixelFormat.r8g8b8a8UNormIntSRGB,
      _ => gpu.PixelFormat.r8g8b8a8UNormInt,
    };
  }

  static int? _height(Texture texture) {
    final height = _size(texture.image)?.$2;

    if (height == null) {
      return null;
    }

    if (height <= 0) {
      return null;
    }

    return height;
  }

  // The width and height of a ready image (a decoded FlutterImage, a DataImage, a DataTexture's image).
  static (int, int)? _size(Object? image) {
    return switch (image) {
      FlutterImage i when i.complete => (i.width, i.height),
      DataImage(:final width?, :final height?) => (width, height),
      DataTexture t => _size(t.image),
      _ => null,
    };
  }
}
