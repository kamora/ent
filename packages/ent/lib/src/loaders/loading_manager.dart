part of '../../ent.dart';

/// Called with the URL and item counts by [LoadingManager.onStart] and [LoadingManager.onProgress].
typedef LoadingManagerCallback = void Function(String url, int itemsLoaded, int itemsTotal);

/// Handles and keeps track of loaded and pending data. A default global instance of this class is created
/// and used by loaders if not supplied manually.
///
/// In general that should be sufficient, however there are times when it can be useful to have separate
/// loaders - for example if you want to show separate loading bars for objects and textures.
class LoadingManager {
  /// Constructs a new loading manager with the functions called when all items are loaded, when an item
  /// finishes, and when an item fails.
  LoadingManager([this.onLoad, this.onProgress, this.onError]);

  bool _isLoading = false;

  int _itemsLoaded = 0;

  int _itemsTotal = 0;

  String Function(String url)? _urlModifier;

  final List<Object> _handlers = [];

  /// Executes when an item starts loading. Not set in the constructor.
  LoadingManagerCallback? onStart;

  /// Executes when all items have been loaded.
  void Function()? onLoad;

  /// Executes when a single item has been loaded.
  LoadingManagerCallback? onProgress;

  /// Executes when an item produces an error.
  void Function(String url)? onError;

  AbortController? _abortController;

  /// Used for aborting ongoing requests in loaders using this manager; created on first access.
  AbortController get abortController {
    return _abortController ??= AbortController();
  }

  /// This should be called by any loader using the manager when the loader starts loading an item.
  void itemStart(String url) {
    _itemsTotal++;

    if (_isLoading == false) {
      onStart?.call(url, _itemsLoaded, _itemsTotal);
    }

    _isLoading = true;
  }

  /// This should be called by any loader using the manager when the loader ended loading an item.
  void itemEnd(String url) {
    _itemsLoaded++;

    onProgress?.call(url, _itemsLoaded, _itemsTotal);

    if (_itemsLoaded == _itemsTotal) {
      _isLoading = false;

      onLoad?.call();
    }
  }

  /// This should be called by any loader using the manager when the loader encounters an error when
  /// loading an item.
  void itemError(String url) {
    onError?.call(url);
  }

  /// Given a URL, uses the URL modifier callback (if any) and returns a resolved URL. If no URL modifier is
  /// set, returns the original URL.
  String resolveURL(String url) {
    // Normalize to NFC so that Unicode URIs (e.g. from glTF) are percent-encoded correctly per RFC 3987.
    // Dart has no NFC normalization: the platform provides it (E-PLATFORM).
    url = Loader.platform?.normalizeNFC(url) ?? url;

    final modifier = _urlModifier;

    if (modifier != null) {
      return modifier(url);
    }

    return url;
  }

  /// If provided, the callback will be passed each resource URL before a request is sent. The callback may
  /// return the original URL, or a new URL to override loading behavior.
  LoadingManager setURLModifier(String Function(String url)? transform) {
    _urlModifier = transform;

    return this;
  }

  /// Registers a loader with the given regular expression. Can be used to define what loader should be
  /// used in order to load specific files.
  LoadingManager addHandler(RegExp regex, Loader<Object?> loader) {
    _handlers
      ..add(regex)
      ..add(loader);

    return this;
  }

  /// Removes the loader for the given regular expression.
  LoadingManager removeHandler(RegExp regex) {
    final index = _handlers.indexOf(regex);

    if (index != -1) {
      _handlers.removeRange(index, index + 2);
    }

    return this;
  }

  /// Can be used to retrieve the registered loader for the given file path; `null` if there is none. A Dart RegExp
  /// keeps no `lastIndex` state, so the reference's reset for global regexes is not needed.
  Loader<Object?>? getHandler(String file) {
    for (var i = 0, l = _handlers.length; i < l; i += 2) {
      final regex = _handlers[i] as RegExp;
      final loader = _handlers[i + 1] as Loader<Object?>;

      if (regex.hasMatch(file)) {
        return loader;
      }
    }

    return null;
  }

  /// Can be used to abort ongoing loading requests in loaders using this manager. The abort only works if
  /// the loaders implement [Loader.abort] and the platform honours the signal.
  LoadingManager abort() {
    abortController.abort();
    _abortController = null;

    return this;
  }
}

/// The global default loading manager.
final LoadingManager DefaultLoadingManager = LoadingManager();
