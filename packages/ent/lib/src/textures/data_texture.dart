part of '../../ent.dart';

/// Creates a texture directly from raw buffer data.
///
/// The interpretation of the data depends on type and format: If the type is `UnsignedByteType`, a
/// `Uint8List` will be useful for addressing the texel data. If the format is `RGBAFormat`, data needs four
/// values for one texel; Red, Green, Blue and Alpha (typically the opacity).
class DataTexture extends Texture {
  /// Constructs a new data texture from [data] (a typed list or `null`) and its [width] and [height] (both
  /// default `1`). [magFilter] and [minFilter] default to [NearestFilter]; the other parameters default as
  /// in [Texture].
  DataTexture([
    Object? data,
    int width = 1,
    int height = 1,
    int? format,
    int? type,
    int? mapping,
    int? wrapS,
    int? wrapT,
    int magFilter = NearestFilter,
    int minFilter = NearestFilter,
    double? anisotropy,
    String? colorSpace,
  ]) : super(
         null,
         mapping,
         wrapS ?? ClampToEdgeWrapping,
         wrapT ?? ClampToEdgeWrapping,
         magFilter,
         minFilter,
         format ?? RGBAFormat,
         type ?? UnsignedByteType,
         anisotropy,
         colorSpace ?? NoColorSpace,
       ) {
    // The image definition of a data texture.
    image = DataImage(data: data, width: width, height: height);

    // Whether to generate mipmaps (if possible) for a texture. Overwritten and set to `false` by default.
    generateMipmaps = false;

    // If set to `true`, the texture is flipped along the vertical axis when uploaded to the GPU.
    // Overwritten and set to `false` by default.
    flipY = false;

    // Specifies the alignment requirements for the start of each pixel row in memory. Overwritten and set to
    // `1` by default.
    unpackAlignment = 1;
  }

  /// This flag can be used for type testing.
  bool get isDataTexture => true;

  /// Returns a new data texture with copied values from this instance. The reference builds `new this.constructor()`;
  /// Dart subclasses override this method (E-CLONE).
  @override
  DataTexture clone() {
    return DataTexture()..copy(this);
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isDataTexture' => isDataTexture,
      _ => super._getValue(key),
    };
  }
}
