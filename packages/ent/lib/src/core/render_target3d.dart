part of '../../ent.dart';

/// Represents 3D render target.
class RenderTarget3D extends RenderTarget {
  /// Constructs a new 3D render target of the given size (default `1` × `1` × `1`) with the given options
  /// (see [RenderTarget]).
  RenderTarget3D([int width = 1, int height = 1, int depth = 1, Map<String, Object?> options = const {}])
    : super(width, height, options) {
    this.depth = depth;

    // overwrite attachments with 3D textures

    for (var i = 0; i < textures.length; i++) {
      final texture = Data3DTexture(null, width, height, depth);
      texture.isRenderTargetTexture = true;
      texture.renderTarget = this;

      textures[i] = texture;
    }

    _setTextureOptions(options);
  }

  /// This flag can be used for type testing.
  bool get isRenderTarget3D => true;
}
