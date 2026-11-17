part of '../../ent.dart';

/// Represents a texture created externally with the same renderer context.
///
/// This may be a texture from a protected media stream, device camera feed, or other data feeds like a depth
/// sensor.
class ExternalTexture extends Texture {
  /// Creates a new raw texture wrapping [sourceTexture] (default `null`).
  ExternalTexture([this.sourceTexture]) : super();

  /// The external source texture: a platform texture handle (in the reference: a `WebGLTexture` or a `GPUTexture`), or
  /// `null` (E-PLATFORM).
  Object? sourceTexture;

  /// This flag can be used for type testing.
  bool get isExternalTexture => true;

  /// Returns a new external texture with copied values from this instance (E-CLONE).
  @override
  ExternalTexture clone() {
    return ExternalTexture()..copy(this);
  }

  /// Copies the values of the given texture to this instance.
  @override
  ExternalTexture copy(Texture source) {
    super.copy(source);

    sourceTexture = (source as ExternalTexture).sourceTexture;

    return this;
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isExternalTexture' => isExternalTexture,
      'sourceTexture' => sourceTexture,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    if (key == 'sourceTexture') {
      sourceTexture = value;
    } else {
      super._setValue(key, value);
    }
  }
}
