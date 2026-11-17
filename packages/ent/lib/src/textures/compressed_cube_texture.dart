part of '../../ent.dart';

/// Creates a cube texture based on data in compressed form.
///
/// These texture are usually loaded with [CompressedTextureLoader].
class CompressedCubeTexture extends CompressedTexture {
  /// Constructs a new compressed cube texture from the six face [images] (each a [DataImage], a map with
  /// `width`/`height` keys as a loader builds it, or a [Texture]), their [format] and [type].
  CompressedCubeTexture(List<Object?> images, [int? format, int? type])
    : super(
        null,
        _compressedCubeTextureSize(images[0], 'width'),
        _compressedCubeTextureSize(images[0], 'height'),
        format,
        type,
        CubeReflectionMapping,
      ) {
    image = images;
  }

  /// This flag can be used for type testing.
  bool get isCompressedCubeTexture => true;

  /// This flag can be used for type testing.
  bool get isCubeTexture => true;

  /// Returns a new compressed cube texture with copied values from this instance (E-CLONE).
  ///
  /// The reference's inherited `new this.constructor().copy( this )` throws here, because the constructor reads
  /// `images[ 0 ]` of `undefined`; the port builds the clone from this texture's images instead.
  @override
  CompressedCubeTexture clone() {
    return CompressedCubeTexture(image as List<Object?>)..copy(this);
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isCompressedCubeTexture' => isCompressedCubeTexture,
      'isCubeTexture' => isCubeTexture,
      _ => super._getValue(key),
    };
  }
}

/// `images[ 0 ].width` / `.height` of a face as the loaders build it; `null` (`undefined` in the reference) when the
/// face has no such dimension.
int? _compressedCubeTextureSize(Object? face, String key) {
  return switch (face) {
    DataImage d => key == 'width' ? d.width : d.height,
    Map<String, Object?> m => (m[key] as num?)?.toInt(),
    Texture t => (key == 'width' ? t.width : t.height).toInt(),
    _ => null,
  };
}
