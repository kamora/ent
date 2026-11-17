part of '../../ent.dart';

/// This class can be used to automatically save the depth information of a cube rendering into a cube texture
/// with depth format. Used for PointLight shadows.
class CubeDepthTexture extends DepthTexture {
  /// Constructs a new cube depth texture whose six faces are [size] × [size].
  ///
  /// [type] defaults to [UnsignedIntType], [mapping] to [CubeReflectionMapping], [magFilter] and [minFilter]
  /// to [NearestFilter], and [format] to [DepthFormat].
  CubeDepthTexture([
    int? size,
    int type = UnsignedIntType,
    int mapping = CubeReflectionMapping,
    int? wrapS,
    int? wrapT,
    int magFilter = NearestFilter,
    int minFilter = NearestFilter,
    double? anisotropy,
    int format = DepthFormat,
  ]) : super(size, size, type, mapping, wrapS, wrapT, magFilter, minFilter, anisotropy, format) {
    // Create 6 identical image descriptors for the cube faces
    final image = DataImage(width: size, height: size, depth: 1);

    // Replace the single image with the array of 6 images
    this.image = <Object?>[image, image, image, image, image, image];
  }

  /// This flag can be used for type testing.
  bool get isCubeDepthTexture => true;

  /// Set to true for cube texture handling in WebGLTextures.
  bool get isCubeTexture => true;

  /// Alias for [image].
  Object? get images {
    return image;
  }

  set images(Object? value) {
    image = value;
  }

  /// Returns a new cube depth texture with copied values from this instance (E-CLONE).
  @override
  CubeDepthTexture clone() {
    return CubeDepthTexture()..copy(this);
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isCubeDepthTexture' => isCubeDepthTexture,
      'isCubeTexture' => isCubeTexture,
      'images' => images,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    if (key == 'images') {
      images = value;
    } else {
      super._setValue(key, value);
    }
  }
}
