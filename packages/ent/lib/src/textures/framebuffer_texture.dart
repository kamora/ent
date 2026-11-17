part of '../../ent.dart';

/// This class can only be used in combination with `copyFramebufferToTexture()` methods of renderers. It
/// extracts the contents of the current bound framebuffer and provides it as a texture for further usage.
///
/// ```dart
/// final textureSize = 128 * pixelRatio;
/// final frameTexture = FramebufferTexture(textureSize, textureSize);
///
/// // calculate start position for copying part of the frame data
/// final vector = Vector2(width * pixelRatio / 2 - textureSize / 2, height * pixelRatio / 2 - textureSize / 2);
///
/// renderer.render(scene, camera);
///
/// // copy part of the rendered frame into the framebuffer texture
/// renderer.copyFramebufferToTexture(frameTexture, vector);
/// ```
class FramebufferTexture extends Texture {
  /// Constructs a new framebuffer texture of the given [width] and [height].
  FramebufferTexture([int? width, int? height]) : super(DataImage(width: width, height: height)) {
    // How the texture is sampled when a texel covers more than one pixel. Overwritten and set to
    // `NearestFilter` by default to disable filtering.
    magFilter = NearestFilter;

    // How the texture is sampled when a texel covers less than one pixel. Overwritten and set to
    // `NearestFilter` by default to disable filtering.
    minFilter = NearestFilter;

    // Whether to generate mipmaps (if possible) for a texture. Overwritten and set to `false` by default.
    generateMipmaps = false;

    needsUpdate = true;
  }

  /// This flag can be used for type testing.
  bool get isFramebufferTexture => true;

  /// Returns a new framebuffer texture with copied values from this instance (E-CLONE).
  @override
  FramebufferTexture clone() {
    return FramebufferTexture()..copy(this);
  }

  /// Copies the values of the given texture to this instance. The copy gets its own source holding a
  /// shallow copy of the image.
  @override
  FramebufferTexture copy(Texture source) {
    super.copy(source);

    this.source = TextureSource(_textureAssign(source.image));

    return this;
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isFramebufferTexture' => isFramebufferTexture,
      _ => super._getValue(key),
    };
  }
}
