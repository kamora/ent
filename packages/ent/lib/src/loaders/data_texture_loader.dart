part of '../../ent.dart';

/// Abstract base class for loading binary texture formats RGBE, EXR or TGA. Textures are internally loaded
/// via [FileLoader].
///
/// Derived classes have to implement [parse], returning the texture data as a map with the reference's keys (`image` or
/// `data`/`width`/`height`, `wrapS`, `wrapT`, `magFilter`, `minFilter`, `anisotropy`, `colorSpace`, `flipY`, `format`,
/// `type`, `mipmaps`, `mipmapCount`, `generateMipmaps`) (exception E-OBJECT).
class DataTextureLoader extends Loader<DataTexture> {
  /// Constructs a new data texture loader.
  DataTextureLoader([super.manager]);

  /// Starts loading from the given URL and passes the loaded data texture to the [onLoad] callback, with
  /// the parsed texture data as its second argument. The method also returns a new texture object which
  /// can directly be used for material creation.
  @override
  DataTexture load(
    covariant String url, [
    covariant void Function(DataTexture texture, [Map<String, Object?>? texData])? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final texture = DataTexture();

    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setResponseType('arraybuffer')
      ..setRequestHeader(requestHeader)
      ..setPath(path)
      ..setWithCredentials(withCredentials);

    loader.load(
      url,
      (buffer) {
        Map<String, Object?>? texData;

        try {
          texData = parse(buffer! as ByteBuffer);
        } catch (e) {
          if (onError != null) {
            onError(e);
          } else {
            error(e);
          }

          return;
        }

        _applyTexData(texture, texData);

        onLoad?.call(texture, texData);
      },
      onProgress,
      onError,
    );

    return texture;
  }

  /// Resolves with the loaded texture, as the reference's `loadAsync` (which keeps `onLoad`'s first argument).
  @override
  Future<DataTexture> loadAsync(Object? url, [LoaderProgressCallback? onProgress]) {
    final completer = Completer<DataTexture>();

    load(url! as String, (texture, [texData]) => completer.complete(texture), onProgress, completer.completeError);

    return completer.future;
  }

  /// Parses the given binary texture data; returns `null` here (the reference's base returns `undefined`), so derived
  /// loaders must override it.
  @override
  Map<String, Object?>? parse(covariant ByteBuffer buffer) {
    return null;
  }

  /// Creates a data texture from the given buffer (with [parse]).
  DataTexture createDataTexture(ByteBuffer buffer) {
    final texture = DataTexture();

    _applyTexData(texture, parse(buffer));

    return texture;
  }

  void _applyTexData(DataTexture texture, Map<String, Object?>? texData) {
    final data = texData!;

    if (data['image'] != null) {
      texture.image = data['image'];
    } else if (data['data'] != null) {
      final image = texture.image! as DataImage;
      image.width = (data['width'] as num?)?.toInt();
      image.height = (data['height'] as num?)?.toInt();
      image.data = data['data'];
    }

    texture.wrapS = data['wrapS'] != null ? (data['wrapS']! as num).toInt() : ClampToEdgeWrapping;
    texture.wrapT = data['wrapT'] != null ? (data['wrapT']! as num).toInt() : ClampToEdgeWrapping;

    texture.magFilter = data['magFilter'] != null ? (data['magFilter']! as num).toInt() : LinearFilter;
    texture.minFilter = data['minFilter'] != null ? (data['minFilter']! as num).toInt() : LinearFilter;

    texture.anisotropy = data['anisotropy'] != null ? (data['anisotropy']! as num).toDouble() : 1.0;

    if (data['colorSpace'] != null) {
      texture.colorSpace = data['colorSpace']! as String;
    }

    if (data['flipY'] != null) {
      texture.flipY = data['flipY']! as bool;
    }

    if (data['format'] != null) {
      texture.format = (data['format']! as num).toInt();
    }

    if (data['type'] != null) {
      texture.type = (data['type']! as num).toInt();
    }

    if (data['mipmaps'] != null) {
      texture.mipmaps = (data['mipmaps']! as List).cast<Object?>();
      texture.minFilter = LinearMipmapLinearFilter; // presumably...
    }

    if (data['mipmapCount'] == 1) {
      texture.minFilter = LinearFilter;
    }

    if (data['generateMipmaps'] != null) {
      texture.generateMipmaps = data['generateMipmaps']! as bool;
    }

    texture.needsUpdate = true;
  }
}
