part of '../../ent.dart';

class _FileLoaderCallbacks {
  _FileLoaderCallbacks(this.onLoad, this.onProgress, this.onError);

  final void Function(Object? data)? onLoad;

  final LoaderProgressCallback? onProgress;

  final LoaderErrorCallback? onError;
}

/// Requests in flight per URL; later requests for the same URL wait for the first one.
final Map<String, List<_FileLoaderCallbacks>> _fileLoaderLoading = {};

final RegExp _fileLoaderCharset = RegExp(r'charset="?([^;"\s]*)"?', caseSensitive: false);

final RegExp _fileLoaderInt = RegExp(r'^\s*([+-]?\d+)');

/// The error a request with an HTTP status other than 200 or 0 fails with.
class HttpError extends EntError {
  /// Constructs a new error with the given message and the response that failed.
  HttpError(super.message, this.response);

  /// The response that failed.
  final LoaderResponse response;
}

/// A low level class for loading resources with the Fetch API, used internally for most loaders. It can
/// also be used directly to load any file type that does not have a loader.
///
/// This loader supports caching. If you want to use it, add `Cache.enabled = true` once in your app.
///
/// Requests go through [Loader.platform] (exception E-PLATFORM). The loaded data is a `String` (default
/// response type), a `ByteBuffer` (`'arraybuffer'`), the decoded JSON (`'json'`), a platform blob
/// (`'blob'`) or a platform document (`'document'`).
class FileLoader extends Loader<Object?> {
  /// Constructs a new file loader.
  FileLoader([super.manager]);

  /// The expected mime type. Valid values can be found
  /// [here](https://developer.mozilla.org/en-US/docs/Web/API/DOMParser/parseFromString#mimetype).
  String mimeType = '';

  /// The expected response type: `'arraybuffer'`, `'blob'`, `'document'`, `'json'` or `''` (text).
  String responseType = '';

  AbortController _abortController = AbortController();

  /// Starts loading from the given URL and passes the loaded response to the [onLoad] callback.
  @override
  void load(
    covariant String? url, [
    void Function(Object? data)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    var resolved = url ?? '';

    resolved = path + resolved;

    resolved = manager.resolveURL(resolved);

    final cached = Cache.get('file:$resolved');

    if (cached != null) {
      manager.itemStart(resolved);

      Future<void>(() {
        onLoad?.call(cached);

        manager.itemEnd(resolved);
      });

      return;
    }

    // Check if request is duplicate

    final pending = _fileLoaderLoading[resolved];

    if (pending != null) {
      pending.add(_FileLoaderCallbacks(onLoad, onProgress, onError));

      return;
    }

    // Initialise array for duplicate requests
    _fileLoaderLoading[resolved] = [_FileLoaderCallbacks(onLoad, onProgress, onError)];

    // create request
    final request = LoaderRequest(
      url: resolved,
      headers: Map.of(requestHeader),
      credentials: withCredentials ? 'include' : 'same-origin',
      priority: priority,
      cache: cache,
      signal: AbortSignal.any([_abortController.signal, manager.abortController.signal]),
    );

    // start the fetch; the state is recorded to avoid a data race
    final platform = _loaderPlatform('fetch()');
    _fetch(platform, request, mimeType, responseType);

    manager.itemStart(resolved);
  }

  Future<void> _fetch(LoaderPlatform platform, LoaderRequest request, String mimeType, String responseType) async {
    final url = request.url;

    try {
      final response = await _fileLoaderAbortable(platform.fetch(request), request.signal);
      Uint8List bytes;

      if (response.status == 200 || response.status == 0) {
        // Some browsers return HTTP Status 0 when using non-http protocol
        // e.g. 'file://' or 'data://'. Handle as success.

        if (response.status == 0) {
          warn('FileLoader: HTTP Status 0 received.');
        }

        final body = response.body;

        if (body == null) {
          bytes = await _fileLoaderAbortable(response.bytes(), request.signal);
        } else {
          bytes = await _readWithProgress(body, response, url, request.signal);
        }
      } else {
        throw HttpError(
          'fetch for "${response.url}" responded with ${response.status}: ${response.statusText}',
          response,
        );
      }

      final data = _convert(platform, bytes, response, responseType, mimeType);

      // Add to cache only on HTTP success, so that we do not cache
      // error response bodies as proper responses to requests.
      Cache.add('file:$url', data);

      final callbacks = _fileLoaderLoading.remove(url)!;

      for (var i = 0, il = callbacks.length; i < il; i++) {
        callbacks[i].onLoad?.call(data);
      }
    } catch (err, stack) {
      // Abort errors and other errors are handled the same

      final callbacks = _fileLoaderLoading[url];

      if (callbacks == null) {
        // When onLoad was called and url was deleted in `loading`: the reference rethrows, an unhandled rejection
        // reported after `finally` has ended the item.
        manager.itemError(url);
        manager.itemEnd(url);
        Zone.current.handleUncaughtError(err, stack);
        return;
      }

      _fileLoaderLoading.remove(url);

      for (var i = 0, il = callbacks.length; i < il; i++) {
        callbacks[i].onError?.call(err);
      }

      manager.itemError(url);
    }

    manager.itemEnd(url);
  }

  /// Reads a streamed body, reporting progress to every request waiting for [url].
  Future<Uint8List> _readWithProgress(
    Stream<List<int>> body,
    LoaderResponse response,
    String url,
    AbortSignal signal,
  ) async {
    final callbacks = _fileLoaderLoading[url]!;

    // Nginx needs X-File-Size check
    // https://serverfault.com/questions/482875/why-does-nginx-remove-content-length-header-for-chunked-content
    final fileSize = response.header('X-File-Size');
    var contentLength = response.header('Content-Length');

    if (fileSize != null && fileSize != '') {
      contentLength = fileSize;
    }

    // parseInt: leading digits; a value with none is NaN, which still counts as computable but reports 0
    int? parsed = 0;

    if (contentLength != null && contentLength != '') {
      parsed = _fileLoaderParseInt(contentLength);
    }

    final total = parsed ?? 0;
    final lengthComputable = parsed != 0;
    var loaded = 0;
    final builder = BytesBuilder(copy: false);

    await for (final chunk in body) {
      if (signal.aborted) {
        throw signal.reason!;
      }

      loaded += chunk.length;

      final event = ProgressEvent('progress', lengthComputable: lengthComputable, loaded: loaded, total: total);

      for (var i = 0, il = callbacks.length; i < il; i++) {
        callbacks[i].onProgress?.call(event);
      }

      builder.add(chunk);
    }

    return builder.takeBytes();
  }

  Object? _convert(
    LoaderPlatform platform,
    Uint8List bytes,
    LoaderResponse response,
    String responseType,
    String mimeType,
  ) {
    switch (responseType) {
      case 'arraybuffer':
        if (bytes.offsetInBytes == 0 && bytes.buffer.lengthInBytes == bytes.length) {
          return bytes.buffer;
        }

        return Uint8List.fromList(bytes).buffer;

      case 'blob':
        return platform.createBlob(bytes, response.header('Content-Type') ?? '');

      case 'document':
        return platform.parseDocument(_fileLoaderUtf8(bytes), mimeType);

      case 'json':
        return jsonDecode(_fileLoaderUtf8(bytes));

      default:
        if (mimeType == '') {
          return _fileLoaderUtf8(bytes);
        } else {
          // sniff encoding
          final exec = _fileLoaderCharset.firstMatch(mimeType);
          String? label;

          if (exec != null && exec[1] != null && exec[1] != '') {
            label = exec[1]!.toLowerCase();
          }

          if (label == null || label == 'utf-8' || label == 'utf8' || label == 'unicode-1-1-utf-8') {
            return _fileLoaderUtf8(bytes);
          }

          final encoding = Encoding.getByName(label);

          if (encoding == null) {
            throw ArgumentError('The encoding label provided (\'$label\') is invalid.');
          }

          return encoding.decode(bytes);
        }
    }
  }

  /// Sets the expected response type.
  FileLoader setResponseType(String value) {
    responseType = value;
    return this;
  }

  /// Sets the expected mime type of the loaded file.
  FileLoader setMimeType(String value) {
    mimeType = value;
    return this;
  }

  /// Aborts ongoing fetch requests.
  @override
  FileLoader abort() {
    _abortController.abort();
    _abortController = AbortController();

    return this;
  }
}

/// `TextDecoder( 'utf-8' ).decode()`: replaces malformed sequences and drops a leading byte order mark.
String _fileLoaderUtf8(Uint8List bytes) {
  var start = 0;

  // A byte order mark is skipped.
  if (bytes.length >= 3 && bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf) {
    start = 3;
  }

  return utf8.decode(Uint8List.sublistView(bytes, start), allowMalformed: true);
}

/// `parseInt( value )`: the leading integer, or `null` for NaN.
int? _fileLoaderParseInt(String value) {
  final match = _fileLoaderInt.firstMatch(value);
  return match == null ? null : int.parse(match[1]!);
}

/// Completes like [future], or fails with the signal's reason as soon as [signal] aborts.
Future<T> _fileLoaderAbortable<T>(Future<T> future, AbortSignal signal) {
  if (signal.aborted) {
    future.ignore();
    return Future<T>.error(signal.reason!);
  }

  final completer = Completer<T>();

  void onAbort() {
    if (!completer.isCompleted) {
      completer.completeError(signal.reason!);
    }
  }

  signal.addListener(onAbort);

  future.then(
    (value) {
      signal.removeListener(onAbort);

      if (!completer.isCompleted) {
        completer.complete(value);
      }
    },
    onError: (Object e, StackTrace s) {
      signal.removeListener(onAbort);

      if (!completer.isCompleted) {
        completer.completeError(e, s);
      }
    },
  );

  return completer.future;
}
