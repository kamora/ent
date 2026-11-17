part of '../../ent.dart';

/// Creates a texture based on data in compressed form.
///
/// These texture are usually loaded with [CompressedTextureLoader].
class CompressedTexture extends Texture {
  /// Constructs a new compressed texture.
  ///
  /// [mipmaps] holds for all mipmaps (including the bases mip) the data and dimensions (default an empty
  /// list); [width] and [height] are those of the biggest mipmap. The other parameters default as in
  /// [Texture].
  CompressedTexture([
    List<Object?>? mipmaps,
    int? width,
    int? height,
    int? format,
    int? type,
    int? mapping,
    int? wrapS,
    int? wrapT,
    int? magFilter,
    int? minFilter,
    double? anisotropy,
    String? colorSpace,
  ]) : super(
         null,
         mapping,
         wrapS ?? ClampToEdgeWrapping,
         wrapT ?? ClampToEdgeWrapping,
         magFilter ?? LinearFilter,
         minFilter ?? LinearMipmapLinearFilter,
         format ?? RGBAFormat,
         type ?? UnsignedByteType,
         anisotropy,
         colorSpace ?? NoColorSpace,
       ) {
    // The image property of a compressed texture just defines its dimensions.
    image = DataImage(width: width, height: height);

    // This array holds for all mipmaps (including the bases mip) the data and dimensions.
    this.mipmaps = mipmaps ?? <Object?>[];

    // If set to `true`, the texture is flipped along the vertical axis when uploaded to the GPU.
    // Overwritten and set to `false` by default since it is not possible to flip compressed textures.
    flipY = false;

    // Whether to generate mipmaps (if possible) for a texture. Overwritten and set to `false` by default
    // since it is not possible to generate mipmaps for compressed data. Mipmaps must be embedded in the
    // compressed texture file.
    generateMipmaps = false;
  }

  /// This flag can be used for type testing.
  bool get isCompressedTexture => true;

  /// Returns a new compressed texture with copied values from this instance (E-CLONE).
  @override
  CompressedTexture clone() {
    return CompressedTexture()..copy(this);
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isCompressedTexture' => isCompressedTexture,
      _ => super._getValue(key),
    };
  }
}
