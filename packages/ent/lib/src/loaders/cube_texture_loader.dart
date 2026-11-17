part of '../../ent.dart';

/// Class for loading cube textures. Images are internally loaded via [ImageLoader].
///
/// The loader returns an instance of [CubeTexture] and expects the cube map to be defined as six separate
/// images representing the sides of a cube. Other cube map definitions like vertical and horizontal cross,
/// column and row layouts are not supported.
///
/// Note that, by convention, cube maps are specified in a coordinate system in which positive-x is to the right when
/// looking up the positive-z axis -- in other words, using a left-handed coordinate system. Since the engine uses a
/// right-handed coordinate system, environment maps used in the engine will have pos-x and neg-x swapped.
///
/// The loaded cube texture is in sRGB color space. Meaning [Texture.colorSpace] is set to
/// [SRGBColorSpace] by default.
class CubeTextureLoader extends Loader<CubeTexture> {
  /// Constructs a new cube texture loader.
  CubeTextureLoader([super.manager]);

  /// Starts loading from the given URLs (one per side) and pass the fully loaded texture to the [onLoad]
  /// callback. The method also returns a new cube texture object which can directly be used for material
  /// creation.
  @override
  CubeTexture load(
    covariant List<String> urls, [
    void Function(CubeTexture texture)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final texture = CubeTexture();
    texture.colorSpace = SRGBColorSpace;

    final loader = ImageLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setCrossOrigin(crossOrigin)
      ..setPath(path);

    var loaded = 0;

    void loadTexture(int i) {
      loader.load(
        urls[i],
        (image) {
          _loaderListSet(texture.images! as List<Object?>, i, image);

          loaded++;

          if (loaded == 6) {
            texture.needsUpdate = true;

            onLoad?.call(texture);
          }
        },
        null,
        onError,
      );
    }

    for (var i = 0; i < urls.length; ++i) {
      loadTexture(i);
    }

    return texture;
  }
}

/// `array[ index ] = value` on a JS array: grows the list, filling holes with `null` (`undefined` in the reference).
void _loaderListSet(List<Object?> list, int index, Object? value) {
  while (list.length <= index) {
    list.add(null);
  }

  list[index] = value;
}
