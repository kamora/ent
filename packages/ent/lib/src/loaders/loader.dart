part of '../../ent.dart';

// The base class of the loaders, plus the platform layer that stands in for the browser APIs the loaders use (fetch,
// Request/Response, AbortController, ProgressEvent, HTMLImageElement, createImageBitmap, DOMParser,
// String.prototype.normalize). Core code never touches a browser or file system directly; a web or Flutter package
// installs a [LoaderPlatform] in [Loader.platform] (exception E-PLATFORM).

/// Called with download progress, as the reference's `onProgress( event )`.
typedef LoaderProgressCallback = void Function(ProgressEvent event);

/// Called with the error of a failed load, as the reference's `onError( error )`.
typedef LoaderErrorCallback = void Function(Object error);

/// The progress of a download, the reference's DOM `ProgressEvent`.
class ProgressEvent {
  /// Constructs a new event of the given type and progress (default: nothing loaded, length not computable).
  ProgressEvent(this.type, {this.lengthComputable = false, this.loaded = 0, this.total = 0});

  /// The event type, `'progress'`.
  final String type;

  /// Whether [total] is known.
  final bool lengthComputable;

  /// The bytes received so far.
  final int loaded;

  /// The expected bytes, or `0` if unknown.
  final int total;
}

/// The error an aborted request fails with, the DOM `AbortError`.
class AbortError extends EntError {
  /// Constructs a new abort error with the given message (default: the DOM's message for an abort without a reason).
  AbortError([super.message = 'signal is aborted without reason']);

  /// The DOM exception name, `'AbortError'`.
  String get name => 'AbortError';

  @override
  String toString() => 'AbortError: $message';
}

/// A signal that tells a request to stop, the DOM `AbortSignal`.
class AbortSignal {
  bool _aborted = false;

  Object? _reason;

  final List<void Function()> _listeners = [];

  /// Whether the signal has been aborted.
  bool get aborted => _aborted;

  /// Why the signal was aborted (an [AbortError] unless a reason was given).
  Object? get reason => _reason;

  /// Calls [listener] once, when the signal is aborted.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Removes a listener added with [addListener].
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _abort(Object reason) {
    if (_aborted) {
      return;
    }

    _aborted = true;
    _reason = reason;

    for (final listener in _listeners.toList()) {
      listener();
    }

    _listeners.clear();
  }

  /// A signal that aborts as soon as any of [signals] does, `AbortSignal.any( signals )`.
  static AbortSignal any(List<AbortSignal> signals) {
    final result = AbortSignal();

    for (final signal in signals) {
      if (signal.aborted) {
        result._abort(signal.reason!);
        return result;
      }
    }

    for (final signal in signals) {
      signal.addListener(() => result._abort(signal.reason!));
    }

    return result;
  }
}

/// Aborts requests through its [signal], the DOM `AbortController`.
class AbortController {
  /// The signal handed to requests.
  final AbortSignal signal = AbortSignal();

  /// Aborts the signal; does nothing if it is already aborted.
  void abort([Object? reason]) {
    signal._abort(reason ?? AbortError());
  }
}

/// What [LoaderPlatform.fetch] is asked to load: the reference's `Request`.
class LoaderRequest {
  /// Constructs a new request for [url] with the given options.
  LoaderRequest({
    required this.url,
    Map<String, String>? headers,
    this.credentials = 'same-origin',
    this.priority = 'auto',
    this.cache = 'default',
    AbortSignal? signal,
  }) : headers = headers ?? {},
       signal = signal ?? AbortSignal();

  /// The resolved URL.
  final String url;

  /// The request headers.
  final Map<String, String> headers;

  /// `'include'` or `'same-origin'`.
  final String credentials;

  /// The fetch priority: `'auto'`, `'high'` or `'low'`.
  final String priority;

  /// The cache mode: `'default'`, `'no-store'`, `'reload'`, ...
  final String cache;

  /// Aborts the request; a platform should stop and fail with [AbortSignal.reason].
  final AbortSignal signal;
}

/// The answer to a [LoaderRequest]: the reference's `Response`.
class LoaderResponse {
  /// Constructs a new response with the given status and body.
  LoaderResponse({
    required this.status,
    this.statusText = '',
    this.url = '',
    Map<String, String>? headers,
    this.data,
    this.body,
  }) : headers = {for (final MapEntry(:key, :value) in (headers ?? {}).entries) key.toLowerCase(): value};

  /// The HTTP status; `0` for non-HTTP protocols in some browsers.
  final int status;

  /// The HTTP status text.
  final String statusText;

  /// The final URL of the response.
  final String url;

  /// The response headers, with lower-case names.
  final Map<String, String> headers;

  /// The body as a stream of chunks, when the platform can stream it (download progress is reported per
  /// chunk); `null` otherwise, and [bytes] holds it.
  final Stream<List<int>>? body;

  /// The whole body, when the platform does not stream it ([body] is `null`).
  final Uint8List? data;

  /// A header by name, case-insensitive; `null` if it is missing (the reference's `headers.get( name )`).
  String? header(String name) => headers[name.toLowerCase()];

  /// The whole body.
  Future<Uint8List> bytes() async {
    final body = this.body;

    if (body == null) {
      return data ?? Uint8List(0);
    }

    final builder = BytesBuilder(copy: false);

    await for (final chunk in body) {
      builder.add(chunk);
    }

    return builder.takeBytes();
  }
}

/// An image element the [ImageLoader] fills: the reference's `HTMLImageElement`, created by the platform.
abstract class LoaderImage {
  /// Whether the image has finished loading.
  bool get complete;

  /// The CORS setting.
  set crossOrigin(String? value);

  /// The fetch priority hint.
  String get fetchPriority;

  set fetchPriority(String value);

  /// The source URL; setting it starts the load.
  String get src;

  set src(String value);

  /// Adds a `'load'` or `'error'` listener.
  void addEventListener(String type, void Function(Object? event) listener);

  /// Removes a listener added with [addEventListener].
  void removeEventListener(String type, void Function(Object? event) listener);
}

/// The browser services the loaders use in the reference, provided by a platform package (exception E-PLATFORM).
abstract class LoaderPlatform {
  /// Performs a request, the reference's `fetch( request )`. The future fails with [LoaderRequest.signal]'s reason when
  /// the request is aborted.
  Future<LoaderResponse> fetch(LoaderRequest request);

  /// Creates an image element, the reference's `document.createElementNS( ..., 'img' )`.
  LoaderImage createImage();

  /// Whether [createImageBitmap] is available (the reference checks `typeof createImageBitmap`).
  bool get hasCreateImageBitmap => false;

  /// Decodes a blob into an image bitmap, the reference's `createImageBitmap( blob, options )`.
  Future<Object> createImageBitmap(Object blob, Map<String, Object?> options) {
    throw UnsupportedError('createImageBitmap() not supported.');
  }

  /// Wraps response bytes as a blob, the reference's `response.blob()`; the bytes themselves by default.
  Object createBlob(Uint8List bytes, String type) => bytes;

  /// Parses a document, the reference's `new DOMParser().parseFromString( text, mimeType )`.
  Object parseDocument(String text, String mimeType) {
    throw UnsupportedError('DOMParser not supported.');
  }

  /// Unicode NFC normalization, the reference's `url.normalize( 'NFC' )`; the identity by default.
  String normalizeNFC(String value) => value;
}

/// Abstract base class for loaders.
///
/// [T] is the type a successful load passes to `onLoad`.
class Loader<T> {
  /// Creates a new loader. Without a [manager], it uses [DefaultLoadingManager].
  Loader([LoadingManager? manager]) : manager = manager ?? DefaultLoadingManager;

  /// The platform services (network, images, ...) all loaders use; `null` until a platform package installs one. Loads
  /// that need it throw a [StateError] without it (in the reference: a `ReferenceError`).
  static LoaderPlatform? platform;

  /// The default material name used by loaders.
  static const String DEFAULT_MATERIAL_NAME = '__DEFAULT';

  /// The loading manager.
  LoadingManager manager;

  /// The crossOrigin string to implement CORS for loading the url from a different domain that allows CORS.
  String crossOrigin = 'anonymous';

  /// Whether the XMLHttpRequest uses credentials.
  bool withCredentials = false;

  /// The base path from which the asset will be loaded.
  String path = '';

  /// The base path from which additional resources like textures will be loaded.
  String resourcePath = '';

  /// The request header used in HTTP request.
  Map<String, String> requestHeader = {};

  /// The fetch priority, `'auto'`, `'high'` or `'low'`.
  String priority = 'auto';

  /// The fetch cache mode.
  String cache = 'default';

  /// Starts loading from the given URL and passes the loaded asset to [onLoad]. The reference's base class does
  /// nothing; subclasses implement it.
  Object? load(
    covariant Object? url, [
    covariant void Function(T data)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    return null;
  }

  /// A version of [load] that returns a future instead of calling back.
  Future<T> loadAsync(Object? url, [LoaderProgressCallback? onProgress]) {
    final completer = Completer<T>();

    load(url, completer.complete, onProgress, completer.completeError);

    return completer.future;
  }

  /// Parses the given asset data. The reference's base class does nothing and returns `undefined` (`null`).
  Object? parse(covariant Object? data) {
    return null;
  }

  /// Sets the crossOrigin String to implement CORS for loading the URL from a different domain.
  Loader<T> setCrossOrigin(String crossOrigin) {
    this.crossOrigin = crossOrigin;
    return this;
  }

  /// Whether the XMLHttpRequest uses credentials such as cookies, authorization headers or TLS client
  /// certificates.
  Loader<T> setWithCredentials(bool value) {
    withCredentials = value;
    return this;
  }

  /// Sets the base path for the asset.
  Loader<T> setPath(String path) {
    this.path = path;
    return this;
  }

  /// Sets the base path for dependent resources like textures.
  Loader<T> setResourcePath(String resourcePath) {
    this.resourcePath = resourcePath;
    return this;
  }

  /// Sets the given request header.
  Loader<T> setRequestHeader(Map<String, String> requestHeader) {
    this.requestHeader = requestHeader;
    return this;
  }

  /// Sets the fetch priority.
  Loader<T> setPriority(String value) {
    priority = value;
    return this;
  }

  /// Sets the fetch cache mode.
  Loader<T> setCache(String value) {
    cache = value;
    return this;
  }

  /// Aborts ongoing fetch requests. The reference's base class does nothing.
  Loader<T> abort() {
    return this;
  }
}

/// The installed platform, or a [StateError] naming the browser API of the reference that is missing.
LoaderPlatform _loaderPlatform(String api) {
  final platform = Loader.platform;

  if (platform == null) {
    throw StateError('ENT.Loader: $api needs a platform (Loader.platform).');
  }

  return platform;
}
