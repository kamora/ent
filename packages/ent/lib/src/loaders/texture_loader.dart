part of '../../ent.dart';

/// Class for loading textures. Images are internally loaded via [ImageLoader].
///
/// Please note that `TextureLoader` has dropped support for progress events in `r84`.
class TextureLoader extends Loader<Texture> {
  /// Constructs a new texture loader.
  TextureLoader([super.manager]);

  /// Starts loading from the given URL and pass the fully loaded texture to the [onLoad] callback. The
  /// method also returns a new texture object which can directly be used for material creation. If you do
  /// it this way, the texture may pop up in your scene once the respective loading process is finished.
  @override
  Texture load(
    covariant String url, [
    void Function(Texture texture)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final texture = Texture();

    final loader = ImageLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setCrossOrigin(crossOrigin)
      ..setPath(path);

    loader.load(
      url,
      (image) {
        texture.image = image;
        texture.needsUpdate = true;

        if (onLoad != null) {
          onLoad(texture);
        }
      },
      onProgress,
      onError,
    );

    return texture;
  }
}
