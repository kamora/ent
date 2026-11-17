part of '../../ent.dart';

class _ImageLoaderCallbacks {
  _ImageLoaderCallbacks(this.onLoad, this.onError);

  final void Function(LoaderImage image)? onLoad;

  final LoaderErrorCallback? onError;
}

/// Callbacks of loads that found the image in the cache before it completed (in the reference: a `WeakMap`).
final Expando<List<_ImageLoaderCallbacks>> _imageLoaderLoading = Expando();

/// A loader for loading images. The class loads images with the HTML `Image` API, created by
/// [LoaderPlatform.createImage] (exception E-PLATFORM).
///
/// Please note that `ImageLoader` has dropped support for progress events in `r84`.
class ImageLoader extends Loader<LoaderImage> {
  /// Constructs a new image loader.
  ImageLoader([super.manager]);

  /// Starts loading from the given URL and passes the loaded image to the [onLoad] callback. The method
  /// also returns a new image object which can directly be used for texture creation. If you do it this
  /// way, the texture may pop up in your scene once the respective loading process is finished.
  @override
  LoaderImage load(
    covariant String url, [
    void Function(LoaderImage image)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    url = path + url;

    url = manager.resolveURL(url);

    final cached = Cache.get('image:$url') as LoaderImage?;

    if (cached != null) {
      if (cached.complete == true) {
        manager.itemStart(url);

        Future<void>(() {
          onLoad?.call(cached);

          manager.itemEnd(url);
        });
      } else {
        var arr = _imageLoaderLoading[cached];

        if (arr == null) {
          arr = [];
          _imageLoaderLoading[cached] = arr;
        }

        arr.add(_ImageLoaderCallbacks(onLoad, onError));
      }

      return cached;
    }

    final image = _loaderPlatform('document.createElementNS()').createImage();
    late void Function(Object? event) onImageLoad;
    late void Function(Object? event) onImageError;

    void removeEventListeners() {
      image.removeEventListener('load', onImageLoad);
      image.removeEventListener('error', onImageError);
    }

    onImageLoad = (event) {
      removeEventListeners();

      onLoad?.call(image);

      //

      final callbacks = _imageLoaderLoading[image] ?? [];

      for (var i = 0; i < callbacks.length; i++) {
        callbacks[i].onLoad?.call(image);
      }

      _imageLoaderLoading[image] = null;

      manager.itemEnd(url);
    };

    onImageError = (event) {
      removeEventListeners();

      onError?.call(event ?? 'error');

      Cache.remove('image:$url');

      //

      final callbacks = _imageLoaderLoading[image] ?? [];

      for (var i = 0; i < callbacks.length; i++) {
        callbacks[i].onError?.call(event ?? 'error');
      }

      _imageLoaderLoading[image] = null;

      manager.itemError(url);
      manager.itemEnd(url);
    };

    image.addEventListener('load', onImageLoad);
    image.addEventListener('error', onImageError);

    if (!url.startsWith('data:')) {
      image.crossOrigin = crossOrigin;
    }

    Cache.add('image:$url', image);
    manager.itemStart(url);

    image.fetchPriority = priority;
    image.src = url;

    return image;
  }
}
