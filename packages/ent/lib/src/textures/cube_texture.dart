part of '../../ent.dart';

/// Creates a cube texture made up of six images.
///
/// ```dart
/// final loader = CubeTextureLoader();
/// loader.setPath('textures/cube/pisa/');
/// final textureCube = loader.load(['px.png', 'nx.png', 'py.png', 'ny.png', 'pz.png', 'nz.png']);
/// final material = MeshBasicMaterial({'color': 0xffffff, 'envMap': textureCube});
/// ```
class CubeTexture extends Texture {
  /// Constructs a new cube texture from six [images] (default an empty list). [mapping] defaults to
  /// [CubeReflectionMapping]; the other parameters default as in [Texture].
  CubeTexture([
    List<Object?>? images,
    int mapping = CubeReflectionMapping,
    int? wrapS,
    int? wrapT,
    int? magFilter,
    int? minFilter,
    int? format,
    int? type,
    double? anisotropy,
    String? colorSpace,
  ]) : super(
         images ?? <Object?>[],
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
    // If set to `true`, the texture is flipped along the vertical axis when uploaded to the GPU.
    // Overwritten and set to `false` by default.
    flipY = false;
  }

  /// This flag can be used for type testing.
  bool get isCubeTexture => true;

  /// Alias for [image].
  Object? get images {
    return image;
  }

  set images(Object? value) {
    image = value;
  }

  /// Returns a new cube texture with copied values from this instance (E-CLONE).
  @override
  CubeTexture clone() {
    return CubeTexture()..copy(this);
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
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
