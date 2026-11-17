// Fakes for the loader platform (E-PLATFORM) and a JSON comparison for the reference round trips.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ent/ent.dart';

/// A response the fake platform serves for a URL.
class FakeResource {
  FakeResource(this.bytes, {this.status = 200, this.statusText = 'OK', this.headers = const {}, this.chunks});

  FakeResource.text(String text, {int status = 200, String statusText = 'OK', Map<String, String> headers = const {}})
    : this(Uint8List.fromList(utf8.encode(text)), status: status, statusText: statusText, headers: headers);

  final Uint8List bytes;

  final int status;

  final String statusText;

  final Map<String, String> headers;

  /// When set, the body is streamed in chunks of these sizes.
  final List<int>? chunks;
}

/// An image element that loads when the test calls [finish].
class FakeImage implements LoaderImage {
  @override
  bool complete = false;

  String? crossOriginValue;

  @override
  set crossOrigin(String? value) => crossOriginValue = value;

  @override
  String fetchPriority = 'auto';

  String _src = '';

  @override
  String get src => _src;

  @override
  set src(String value) {
    _src = value;
    platform?.images.add(this);
  }

  FakeLoaderPlatform? platform;

  final Map<String, List<void Function(Object? event)>> listeners = {};

  @override
  void addEventListener(String type, void Function(Object? event) listener) {
    listeners.putIfAbsent(type, () => []).add(listener);
  }

  @override
  void removeEventListener(String type, void Function(Object? event) listener) {
    listeners[type]?.remove(listener);
  }

  /// Completes the load (or fails it), firing the listeners as the browser would.
  void finish({bool error = false}) {
    complete = !error;

    for (final listener in [...?listeners[error ? 'error' : 'load']]) {
      listener(error ? 'error event' : 'load event');
    }
  }
}

/// A loader platform serving fixed resources, recording requests.
class FakeLoaderPlatform extends LoaderPlatform {
  final Map<String, FakeResource> resources = {};

  final List<LoaderRequest> requests = [];

  final List<FakeImage> images = [];

  /// When false, fetches stay pending until [release] is called.
  bool autoRespond = true;

  final List<void Function()> _pending = [];

  @override
  bool hasCreateImageBitmap = true;

  @override
  Future<LoaderResponse> fetch(LoaderRequest request) {
    requests.add(request);
    final completer = Completer<LoaderResponse>();

    void respond() {
      final resource = resources[request.url];

      if (resource == null) {
        completer.complete(LoaderResponse(status: 404, statusText: 'Not Found', url: request.url));
        return;
      }

      final chunks = resource.chunks;
      Stream<List<int>>? body;

      if (chunks != null) {
        body = Stream.fromIterable(() sync* {
          var offset = 0;

          for (final size in chunks) {
            yield resource.bytes.sublist(offset, offset + size);
            offset += size;
          }
        }());
      }

      completer.complete(
        LoaderResponse(
          status: resource.status,
          statusText: resource.statusText,
          url: request.url,
          headers: resource.headers,
          data: chunks == null ? resource.bytes : null,
          body: body,
        ),
      );
    }

    if (autoRespond) {
      Future<void>(respond);
    } else {
      _pending.add(respond);
    }

    return completer.future;
  }

  /// Answers the fetches held back while [autoRespond] was false.
  void release() {
    final pending = [..._pending];
    _pending.clear();

    for (final respond in pending) {
      respond();
    }
  }

  @override
  FakeImage createImage() => FakeImage()..platform = this;

  @override
  Future<Object> createImageBitmap(Object blob, Map<String, Object?> options) async {
    final bytes = blob as Uint8List;

    if (bytes.isEmpty) {
      throw StateError('empty image');
    }

    return {'bitmap': bytes.length, 'options': options};
  }

  @override
  Object createBlob(Uint8List bytes, String type) => bytes;

  @override
  Object parseDocument(String text, String mimeType) => {'document': text, 'mimeType': mimeType};
}

/// Lets queued timers, microtasks and fake responses run.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

/// Converts [json] to plain JSON (as JSON.stringify/parse would, non-finite numbers becoming `null`) and replaces each uuid with its order of
/// first appearance, so two serializations of the same scene compare equal.
Object? canonical(Object? json) {
  final names = <String, String>{};

  Object? walk(Object? value) {
    if (value is String && _uuid.hasMatch(value)) {
      return names.putIfAbsent(value, () => 'uuid-${names.length}');
    }

    if (value is Map) {
      // uuids are also keys (`arrayBuffers`, `interleavedBuffers`)
      return {for (final MapEntry(:key, :value) in value.entries) walk(key)! as String: walk(value)};
    }

    if (value is List) {
      return [for (final v in value) walk(v)];
    }

    return value;
  }

  return walk(jsonDecode(jsonEncode(_finite(json))));
}

/// `JSON.stringify` writes NaN and ±Infinity as `null`; `jsonEncode` refuses them.
Object? _finite(Object? value) {
  if (value is double && !value.isFinite) {
    return null;
  }

  if (value is Map) {
    return {for (final MapEntry(:key, :value) in value.entries) key: _finite(value)};
  }

  if (value is List) {
    return [for (final v in value) _finite(v)];
  }

  return value;
}

/// Differences between [actual] and [expected] (numbers within 1e-9 relative, map keys in order).
List<String> jsonDifferences(Object? actual, Object? expected, [String path = r'$']) {
  final errors = <String>[];

  void compare(Object? a, Object? e, String at) {
    if (errors.length > 20) {
      return;
    }

    if (a is num && e is num) {
      final scale = [1.0, a.abs().toDouble(), e.abs().toDouble()].reduce((x, y) => x > y ? x : y);

      if (a != e && (a - e).abs() > 1e-9 * scale) {
        errors.add('$at: $a != $e');
      }

      return;
    }

    if (a is Map && e is Map) {
      final ak = a.keys.toList();
      final ek = e.keys.toList();

      if (ak.join(',') != ek.join(',')) {
        errors.add('$at: keys ${ak.join(',')} != ${ek.join(',')}');
      }

      for (final key in ek) {
        if (a.containsKey(key)) {
          compare(a[key], e[key], '$at.$key');
        }
      }

      return;
    }

    if (a is List && e is List) {
      if (a.length != e.length) {
        errors.add('$at: length ${a.length} != ${e.length}');
        return;
      }

      for (var i = 0; i < a.length; i++) {
        compare(a[i], e[i], '$at[$i]');
      }

      return;
    }

    if (a != e) {
      errors.add('$at: $a != $e');
    }
  }

  compare(actual, expected, path);
  return errors;
}
