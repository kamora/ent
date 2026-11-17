part of '../../ent.dart';

/// Abstract base class for loading compressed texture formats S3TC, ASTC or ETC. Textures are internally
/// loaded via [FileLoader].
///
/// Derived classes have to implement [parse], returning the texture data as a map with the reference's keys (`width`,
/// `height`, `format`, `mipmaps`, `mipmapCount`, `isCubemap`) (exception E-OBJECT).
class CompressedTextureLoader extends Loader<CompressedTexture> {
  /// Constructs a new compressed texture loader.
  CompressedTextureLoader([super.manager]);

  /// Starts loading from the given URL (a `String`) or URLs (a `List<String>` of six cube faces) and passes
  /// the loaded compressed texture to the [onLoad] callback. The method also returns a new texture object
  /// which can directly be used for material creation (E-UNION).
  @override
  CompressedTexture load(
    covariant Object url, [
    void Function(CompressedTexture texture)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final images = <Object?>[];

    final texture = CompressedTexture();

    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setPath(path)
      ..setResponseType('arraybuffer')
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    var loaded = 0;

    void loadTexture(int i) {
      loader.load(
        (url as List<String>)[i],
        (buffer) {
          final texDatas = parse(buffer! as ByteBuffer, true)!;

          _loaderListSet(images, i, {
            'width': texDatas['width'],
            'height': texDatas['height'],
            'format': texDatas['format'],
            'mipmaps': texDatas['mipmaps'],
          });

          loaded += 1;

          if (loaded == 6) {
            if (texDatas['mipmapCount'] == 1) {
              texture.minFilter = LinearFilter;
            }

            texture.image = images;
            texture.format = (texDatas['format']! as num).toInt();
            texture.needsUpdate = true;

            onLoad?.call(texture);
          }
        },
        onProgress,
        onError,
      );
    }

    if (url is List) {
      for (var i = 0, il = url.length; i < il; ++i) {
        loadTexture(i);
      }
    } else {
      // compressed cubemap texture stored in a single DDS file

      loader.load(
        url as String,
        (buffer) {
          final texDatas = parse(buffer! as ByteBuffer, true)!;
          final mipmaps = (texDatas['mipmaps'] as List?)?.cast<Object?>() ?? [];
          final mipmapCount = (texDatas['mipmapCount'] as num?)?.toInt();

          if (texDatas['isCubemap'] == true) {
            final faces = mipmaps.length / mipmapCount!;

            for (var f = 0; f < faces; f++) {
              final face = <String, Object?>{'mipmaps': <Object?>[]};
              _loaderListSet(images, f, face);

              for (var i = 0; i < mipmapCount; i++) {
                (face['mipmaps']! as List<Object?>).add(mipmaps[f * mipmapCount + i]);
                face['format'] = texDatas['format'];
                face['width'] = texDatas['width'];
                face['height'] = texDatas['height'];
              }
            }

            texture.image = images;
          } else {
            final image = texture.image! as DataImage;
            image.width = (texDatas['width'] as num?)?.toInt();
            image.height = (texDatas['height'] as num?)?.toInt();
            texture.mipmaps = mipmaps;
          }

          if (mipmapCount == 1) {
            texture.minFilter = LinearFilter;
          }

          texture.format = (texDatas['format']! as num).toInt();
          texture.needsUpdate = true;

          onLoad?.call(texture);
        },
        onProgress,
        onError,
      );
    }

    return texture;
  }

  /// Parses the given compressed texture data; returns `null` here (the reference's base returns `undefined`), so
  /// derived loaders must override it.
  @override
  Map<String, Object?>? parse(covariant ByteBuffer buffer, [bool loadMipmaps = false]) {
    return null;
  }
}
