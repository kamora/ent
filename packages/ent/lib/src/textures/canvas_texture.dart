part of '../../ent.dart';

/// Creates a texture from a canvas element.
///
/// This is almost the same as the base texture class, except that it sets [needsUpdate] to `true`
/// immediately since a canvas can directly be used for rendering.
class CanvasTexture extends Texture {
  /// Constructs a new texture from a platform [canvas] (see [ImagePlatform]); when it is left out, the
  /// texture uses [Texture.DEFAULT_IMAGE]. The other parameters default as in [Texture].
  CanvasTexture([
    Object? canvas = _textureUndefined,
    int? mapping,
    int? wrapS,
    int? wrapT,
    int? magFilter,
    int? minFilter,
    int? format,
    int? type,
    double? anisotropy,
  ]) : super(
         canvas,
         mapping,
         wrapS ?? ClampToEdgeWrapping,
         wrapT ?? ClampToEdgeWrapping,
         magFilter ?? LinearFilter,
         minFilter ?? LinearMipmapLinearFilter,
         format ?? RGBAFormat,
         type ?? UnsignedByteType,
         anisotropy,
       ) {
    needsUpdate = true;
  }

  /// This flag can be used for type testing.
  bool get isCanvasTexture => true;

  /// Returns a new canvas texture with copied values from this instance (E-CLONE).
  @override
  CanvasTexture clone() {
    return CanvasTexture()..copy(this);
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isCanvasTexture' => isCanvasTexture,
      _ => super._getValue(key),
    };
  }
}
