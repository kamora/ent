part of '../../ent.dart';

/// The errors of failed cached loads, keyed by their future (in the reference: a `WeakMap` keyed by the promise).
final Expando<Object> _imageBitmapLoaderErrors = Expando();

/// A loader for loading images as an [ImageBitmap](https://developer.mozilla.org/en-US/docs/Web/API/ImageBitmap).
/// An `ImageBitmap` provides an asynchronous and resource efficient pathway to prepare textures for rendering.
///
/// Note that `Texture.flipY` and `Texture.premultiplyAlpha` are ignored with image bitmaps. They need these
/// configuration on bitmap creation unlike regular images need them on uploading to GPU.
///
/// Fetching and decoding go through [Loader.platform] (exception E-PLATFORM); the bitmap is a platform
/// object.
class ImageBitmapLoader extends Loader<Object> {
  /// Constructs a new image bitmap loader.
  ImageBitmapLoader([super.manager]) {
    final platform = Loader.platform;

    if (platform == null || !platform.hasCreateImageBitmap) {
      warn('ImageBitmapLoader: createImageBitmap() not supported.');
    }

    if (platform == null) {
      warn('ImageBitmapLoader: fetch() not supported.');
    }
  }

  /// This flag can be used for type testing.
  final bool isImageBitmapLoader = true;

  /// Represents the loader options; the keys of
  /// [createImageBitmap](https://developer.mozilla.org/en-US/docs/Web/API/createImageBitmap)'s options.
  Map<String, Object?> options = {'premultiplyAlpha': 'none'};

  AbortController _abortController = AbortController();

  /// Sets the given loader options. The structure of the object must match the `options` parameter of
  /// `createImageBitmap`.
  ImageBitmapLoader setOptions(Map<String, Object?> options) {
    this.options = options;

    return this;
  }

  /// Starts loading from the given URL and pass the loaded image bitmap to the [onLoad] callback.
  @override
  void load(
    covariant String? url, [
    void Function(Object imageBitmap)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    var resolved = url ?? '';

    resolved = path + resolved;

    resolved = manager.resolveURL(resolved);

    final cached = Cache.get('image-bitmap:$resolved');

    if (cached != null) {
      manager.itemStart(resolved);

      // If cached is a promise, wait for it to resolve
      if (cached is Future<Object?>) {
        cached.then((imageBitmap) {
          // check if there is an error for the cached promise

          final error = _imageBitmapLoaderErrors[cached];

          if (error != null) {
            onError?.call(error);

            manager.itemError(resolved);
            manager.itemEnd(resolved);
          } else {
            onLoad?.call(imageBitmap!);

            manager.itemEnd(resolved);
          }
        });

        return;
      }

      // If cached is not a promise (i.e., it's already an imageBitmap)
      Future<void>(() {
        onLoad?.call(cached);

        manager.itemEnd(resolved);
      });

      return;
    }

    final platform = _loaderPlatform('fetch()');
    final request = LoaderRequest(
      url: resolved,
      headers: requestHeader,
      credentials: withCredentials || crossOrigin != 'anonymous' ? 'include' : 'same-origin',
      priority: priority,
      cache: cache,
      signal: AbortSignal.any([_abortController.signal, manager.abortController.signal]),
    );

    late final Future<Object?> promise;

    promise = () async {
      try {
        final response = await _fileLoaderAbortable(platform.fetch(request), request.signal);
        final blob = platform.createBlob(await response.bytes(), response.header('Content-Type') ?? '');
        final imageBitmap = await platform.createImageBitmap(blob, {...options, 'colorSpaceConversion': 'none'});

        Cache.add('image-bitmap:$resolved', imageBitmap);

        onLoad?.call(imageBitmap);

        manager.itemEnd(resolved);

        return imageBitmap; // see #34150
      } catch (e) {
        // A rejection is handled a turn later, as the reference's `.catch`; by then `promise` is assigned even if the
        // platform threw synchronously.
        await Future<void>.value();

        onError?.call(e);

        _imageBitmapLoaderErrors[promise] = e;

        Cache.remove('image-bitmap:$resolved');

        manager.itemError(resolved);
        manager.itemEnd(resolved);

        return null;
      }
    }();

    Cache.add('image-bitmap:$resolved', promise);
    manager.itemStart(resolved);
  }

  /// Aborts ongoing fetch requests.
  @override
  ImageBitmapLoader abort() {
    _abortController.abort();
    _abortController = AbortController();

    return this;
  }
}
