part of '../../ent.dart';

/// The options of [RenderTarget] and their defaults (the reference's `Object.assign( { ... }, options )`).
const Map<String, Object?> _renderTargetDefaults = {
  'generateMipmaps': false,
  'internalFormat': null,
  'minFilter': LinearFilter,
  'depthBuffer': true,
  'stencilBuffer': false,
  'resolveColorBuffer': true,
  'resolveDepthBuffer': true,
  'resolveStencilBuffer': true,
  'storeMultisampledColorBuffer': true,
  'storeMultisampledDepthBuffer': true,
  'storeMultisampledStencilBuffer': true,
  'depthTexture': null,
  'samples': 0,
  'count': 1,
  'depth': 1,
  'multiview': false,
  'useArrayDepthTexture': false,
};

/// A render target is a buffer where the video card draws pixels for a scene that is being rendered in the
/// background. It is used in different effects, such as applying postprocessing to a rendered image before
/// displaying it on the screen.
///
/// The [options] map takes the reference's option keys: `generateMipmaps`, `magFilter`, `minFilter`, `format`, `type`,
/// `internalFormat`, `wrapS`, `wrapT`, `wrapR`, `mapping`, `anisotropy`, `colorSpace`, `flipY`, `mipmapsAutoUpdate`
/// (texture options), and `depthBuffer`, `stencilBuffer`, `resolveColorBuffer`, `resolveDepthBuffer`,
/// `resolveStencilBuffer`, `storeMultisampledColorBuffer`, `storeMultisampledDepthBuffer`,
/// `storeMultisampledStencilBuffer`, `depthTexture`, `samples`, `count`, `depth`, `multiview`, `useArrayDepthTexture`.
class RenderTarget extends EventDispatcher {
  /// Constructs a new render target of the given size (default `1` × `1`) with the given options.
  RenderTarget([this.width = 1, this.height = 1, Map<String, Object?> options = const {}]) {
    options = {..._renderTargetDefaults, ...options};

    depth = options['depth'] as int;

    scissor = Vector4(0, 0, width.toDouble(), height.toDouble());

    viewport = Vector4(0, 0, width.toDouble(), height.toDouble());

    final count = options['count'] as int;

    for (var i = 0; i < count; i++) {
      textures.add(Texture(DataImage(width: width, height: height, depth: depth)));
      textures[i].isRenderTargetTexture = true;
      textures[i].renderTarget = this;
    }

    _setTextureOptions(options);

    depthBuffer = options['depthBuffer'] as bool;

    stencilBuffer = options['stencilBuffer'] as bool;

    resolveColorBuffer = options['resolveColorBuffer'] as bool;

    resolveDepthBuffer = options['resolveDepthBuffer'] as bool;

    resolveStencilBuffer = options['resolveStencilBuffer'] as bool;

    storeMultisampledColorBuffer = options['storeMultisampledColorBuffer'] as bool;

    storeMultisampledDepthBuffer = options['storeMultisampledDepthBuffer'] as bool;

    storeMultisampledStencilBuffer = options['storeMultisampledStencilBuffer'] as bool;

    depthTexture = options['depthTexture'] as Texture?;

    samples = options['samples'] as int;

    multiview = options['multiview'] as bool;

    useArrayDepthTexture = options['useArrayDepthTexture'] as bool;
  }

  /// This flag can be used for type testing.
  bool get isRenderTarget => true;

  /// The width of the render target.
  int width;

  /// The height of the render target.
  int height;

  /// The depth of the render target.
  late int depth;

  /// A rectangular area inside the render target's viewport. Fragments that are outside the area will be
  /// discarded.
  late Vector4 scissor;

  /// Indicates whether the scissor test should be enabled when rendering into this render target or not.
  bool scissorTest = false;

  /// A rectangular area representing the current viewport of the render target.
  late Vector4 viewport;

  /// An array of textures. Each color attachment is represented as a separate texture. Has at least a single
  /// entry for the default color attachment.
  List<Texture> textures = [];

  /// Whether to allocate a depth buffer or not.
  late bool depthBuffer;

  /// Whether to allocate a stencil buffer or not.
  late bool stencilBuffer;

  /// Whether to resolve the color buffer or not.
  late bool resolveColorBuffer;

  /// Whether to resolve the depth buffer or not.
  late bool resolveDepthBuffer;

  /// Whether to resolve the stencil buffer or not.
  late bool resolveStencilBuffer;

  /// Whether to store the multisampled color buffer or not.
  late bool storeMultisampledColorBuffer;

  /// Whether to store the multisampled depth buffer or not.
  late bool storeMultisampledDepthBuffer;

  /// Whether to store the multisampled stencil buffer or not.
  late bool storeMultisampledStencilBuffer;

  Texture? _depthTexture;

  /// The number of MSAA samples. A value of `0` disables MSAA.
  late int samples;

  /// Whether to this target is used in multiview rendering.
  late bool multiview;

  /// Whether to use an array depth texture or not.
  late bool useArrayDepthTexture;

  /// Sets texture options. The reference's default parameter `{}` is the default map.
  void _setTextureOptions([Map<String, Object?> options = const {}]) {
    final values = <String, Object?>{
      'minFilter': LinearFilter,
      'generateMipmaps': false,
      'flipY': false,
      'internalFormat': null,
    };

    for (final key in const [
      'mapping',
      'wrapS',
      'wrapT',
      'wrapR',
      'magFilter',
      'minFilter',
      'format',
      'type',
      'anisotropy',
      'colorSpace',
      'flipY',
      'generateMipmaps',
      'mipmapsAutoUpdate',
      'internalFormat',
    ]) {
      // `options.key !== undefined`: a key given explicitly as null counts as set, as the reference's null.
      if (options.containsKey(key)) {
        values[key] = options[key];
      }
    }

    for (var i = 0; i < textures.length; i++) {
      final texture = textures[i];
      texture.setValues(values);
    }
  }

  /// The texture representing the default color attachment.
  Texture get texture {
    return textures[0];
  }

  set texture(Texture value) {
    textures[0] = value;
  }

  /// Instead of saving the depth in a renderbuffer, a texture can be used instead which is useful for
  /// further processing (e.g. in context of post-processing).
  set depthTexture(Texture? current) {
    final previous = _depthTexture;

    if (previous != null && previous.renderTarget == this) {
      previous.renderTarget = null;
    }

    if (current != null && current.renderTarget == null) {
      current.renderTarget = this;
    }

    _depthTexture = current;
  }

  /// The texture the depth is saved in, instead of a renderbuffer; `null` when the depth stays in a renderbuffer.
  Texture? get depthTexture {
    return _depthTexture;
  }

  /// Sets the size of this render target ([depth] defaults to `1`).
  void setSize(int width, int height, [int depth = 1]) {
    if (this.width != width || this.height != height || this.depth != depth) {
      this.width = width;
      this.height = height;
      this.depth = depth;

      for (var i = 0, il = textures.length; i < il; i++) {
        final image = textures[i].image as DataImage;

        image.width = width;
        image.height = height;
        image.depth = depth;

        if (textures[i] is! Data3DTexture) {
          // Fix for #31693

          // A note kept from the reference: reconsider setting isArrayTexture flag here and in the ctor of Texture.
          // Maybe a method `isArrayTexture()` or just a getter could replace a flag since both are evaluated on each
          // call?

          textures[i].isArrayTexture = depth > 1;
        }
      }

      dispose();
    }

    viewport.set(0, 0, width.toDouble(), height.toDouble());
    scissor.set(0, 0, width.toDouble(), height.toDouble());
  }

  /// Returns a new render target with copied values from this instance.
  RenderTarget clone() {
    return RenderTarget().copy(this);
  }

  /// Copies the settings of the given render target. This is a structural copy so no resources are shared
  /// between render targets after the copy. That includes all MRT textures and the depth texture.
  RenderTarget copy(RenderTarget source) {
    width = source.width;
    height = source.height;
    depth = source.depth;

    scissor.copy(source.scissor);
    scissorTest = source.scissorTest;

    viewport.copy(source.viewport);

    textures.length = 0;

    for (var i = 0, il = source.textures.length; i < il; i++) {
      textures.add(source.textures[i].clone());
      textures[i].isRenderTargetTexture = true;
      textures[i].renderTarget = this;

      // ensure image object is not shared, see #20328

      final image = source.textures[i].image;
      textures[i].source = TextureSource(image is DataImage ? image.copy() : image);
    }

    depthBuffer = source.depthBuffer;
    stencilBuffer = source.stencilBuffer;

    resolveColorBuffer = source.resolveColorBuffer;
    resolveDepthBuffer = source.resolveDepthBuffer;
    resolveStencilBuffer = source.resolveStencilBuffer;

    storeMultisampledColorBuffer = source.storeMultisampledColorBuffer;
    storeMultisampledDepthBuffer = source.storeMultisampledDepthBuffer;
    storeMultisampledStencilBuffer = source.storeMultisampledStencilBuffer;

    final sourceDepth = source.depthTexture;

    if (sourceDepth != null) {
      if (sourceDepth.renderTarget == source) {
        final depthTexture = sourceDepth.clone();
        depthTexture.renderTarget = null;

        this.depthTexture = depthTexture;
      } else {
        depthTexture = sourceDepth;
      }
    } else {
      depthTexture = null;
    }

    samples = source.samples;
    multiview = source.multiview;
    useArrayDepthTexture = source.useArrayDepthTexture;

    return this;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  void dispose() {
    dispatchEvent(Event('dispose'));
  }
}
