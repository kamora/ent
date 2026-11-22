// The browser services the loaders and image utilities use, for Flutter (exception E-PLATFORM): images are decoded into
// straight RGBA bytes the renderer uploads (PNGs in Dart, others with dart:ui), requests are served from data URLs,
// http(s) and the app's asset bundle. FlutterPlatform.install() puts them in ImageUtils.platform and Loader.platform.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:ent/ent.dart';

import 'png.dart';

/// A decoded image, the reference's `HTMLImageElement` / `ImageBitmap`: [width], [height] and straight
/// (non-premultiplied) RGBA [pixels], top row first. Setting [src] decodes a data URL or loads a URL through
/// [Loader.platform], as `img.src = url` does, and fires 'load' or 'error'.
class FlutterImage implements LoaderImage {
  /// An empty image, as the [ImageLoader] creates it; set [src] to load it.
  FlutterImage();

  /// An image of [width] × [height] straight RGBA [pixels], top row first. It is [complete], as an `ImageBitmap` is:
  /// the reference renderer reads `image.complete === false` only of an `HTMLImageElement`.
  FlutterImage.fromPixels(this.width, this.height, Uint8List this.pixels) {
    _done = true;
  }

  /// Reads the pixels of a dart:ui [image].
  static Future<FlutterImage> fromImage(ui.Image image) async {
    return FlutterImage.fromPixels(
      image.width,
      image.height,
      (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List(),
    );
  }

  /// Decodes encoded image [bytes]: a PNG with [decodePng] on another isolate, to its straight colors as stored;
  /// anything else (JPEG, WebP, ...) with dart:ui, which goes through premultiplied alpha (exception E-DECODE).
  static Future<FlutterImage> decode(Uint8List bytes) async {
    if (isPng(bytes)) {
      final png = (await Isolate.run(() => decodePng(bytes)))!;
      return FlutterImage.fromPixels(png.width, png.height, png.pixels);
    }

    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;

    try {
      return await fromImage(image);
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  /// The width in pixels, 0 until the image has loaded.
  int width = 0;

  /// The height in pixels, 0 until the image has loaded.
  int height = 0;

  /// Straight RGBA bytes, `width * height * 4`, or `null` until the image has loaded.
  Uint8List? pixels;

  String _src = '';

  bool _done = false;

  final Map<String, List<void Function(Object? event)>> _listeners = {};

  @override
  bool get complete => _done;

  /// The CORS setting the loader set; unused, as CORS applies only in browsers.
  @override
  String? crossOrigin;

  @override
  String fetchPriority = 'auto';

  @override
  String get src => _src;

  @override
  set src(String value) {
    _src = value;
    _done = false;
    unawaited(_load(value));
  }

  Future<void> _load(String url) async {
    Object? error;

    try {
      final response = await _fetch(LoaderRequest(url: url));

      if (response.status < 200 || response.status > 299) {
        throw StateError('HTTP ${response.status}');
      }

      final decoded = await decode(await response.bytes());

      if (_src != url) {
        return;
      }

      width = decoded.width;
      height = decoded.height;
      pixels = decoded.pixels;
    } catch (e) {
      error = e;
    }

    _done = true;

    for (final listener in [...?_listeners[error == null ? 'load' : 'error']]) {
      listener(error);
    }
  }

  @override
  void addEventListener(String type, void Function(Object? event) listener) {
    (_listeners[type] ??= []).add(listener);
  }

  @override
  void removeEventListener(String type, void Function(Object? event) listener) {
    _listeners[type]?.remove(listener);
  }
}

/// The image operations of [ImageUtils] for [FlutterImage]s.
class FlutterImagePlatform implements ImagePlatform {
  @override
  bool isImage(Object image) => image is FlutterImage;

  /// A data URL: the image's own [FlutterImage.src] when it is one (as the reference returns `image.src`), else the
  /// pixels encoded as PNG (for any [type]; a browser falls back to PNG too, for types it lacks).
  @override
  String getDataURL(Object image, String type) {
    final i = image as FlutterImage;

    if (i.src.toLowerCase().startsWith('data:')) {
      return i.src;
    }

    return 'data:image/png;base64,${base64.encode(_png(i.width, i.height, i.pixels ?? Uint8List(0)))}';
  }

  /// The reference draws the image to a canvas and converts every byte, alpha included, with
  /// `SRGBToLinear( v / 255 ) * 255` into a Uint8ClampedArray (which rounds half to even).
  @override
  Object sRGBToLinear(Object image) {
    final i = image as FlutterImage;
    final source = i.pixels ?? Uint8List(i.width * i.height * 4);
    final pixels = Uint8List(source.length);

    for (var k = 0; k < source.length; k++) {
      pixels[k] = _roundHalfEven(SRGBToLinear(source[k] / 255) * 255);
    }

    return FlutterImage.fromPixels(i.width, i.height, pixels);
  }

  @override
  ImageSize? getSize(Object image) {
    return image is FlutterImage ? (width: image.width, height: image.height, depth: 0) : null;
  }

  static int _roundHalfEven(double v) {
    final floor = v.floorToDouble();
    final diff = v - floor;
    return (diff > 0.5 || (diff == 0.5 && floor % 2 == 1) ? floor + 1 : floor).clamp(0, 255).toInt();
  }

  // An uncompressed-filter PNG (color type 6, 8 bits) with a zlib stream from dart:io.
  static Uint8List _png(int width, int height, Uint8List pixels) {
    final raw = BytesBuilder();

    for (var y = 0; y < height; y++) {
      raw.addByte(0);
      raw.add(Uint8List.sublistView(pixels, y * width * 4, (y + 1) * width * 4));
    }

    final out = BytesBuilder()..add([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

    void chunk(String type, List<int> data) {
      final body = [...ascii.encode(type), ...data];
      out
        ..add(_uint32(data.length))
        ..add(body)
        ..add(_uint32(_crc(body)));
    }

    chunk('IHDR', [..._uint32(width), ..._uint32(height), 8, 6, 0, 0, 0]);
    chunk('IDAT', ZLibCodec().encode(raw.takeBytes()));
    chunk('IEND', []);

    return out.takeBytes();
  }

  static List<int> _uint32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

  static int _crc(List<int> bytes) {
    var c = 0xffffffff;

    for (final b in bytes) {
      c ^= b;

      for (var k = 0; k < 8; k++) {
        c = c & 1 != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
      }
    }

    return c ^ 0xffffffff;
  }
}

/// The loader services for Flutter: `fetch` of data URLs, http(s) URLs (dart:io) and anything else as a key
/// of the app's asset bundle; images are [FlutterImage]s, also from [createImageBitmap].
class FlutterLoaderPlatform extends LoaderPlatform {
  @override
  Future<LoaderResponse> fetch(LoaderRequest request) => _fetch(request);

  @override
  LoaderImage createImage() => FlutterImage();

  @override
  bool get hasCreateImageBitmap => true;

  /// Decodes [blob] (the bytes of [createBlob]); `imageOrientation: 'flipY'` flips the rows and
  /// `premultiplyAlpha: 'premultiply'` premultiplies the color channels, as the browser does.
  @override
  Future<Object> createImageBitmap(Object blob, Map<String, Object?> options) async {
    final image = await FlutterImage.decode(blob as Uint8List);
    final pixels = image.pixels!;
    final row = image.width * 4;

    if (options['imageOrientation'] == 'flipY') {
      final source = Uint8List.fromList(pixels);

      for (var y = 0; y < image.height; y++) {
        pixels.setRange(y * row, (y + 1) * row, source, (image.height - 1 - y) * row);
      }
    }

    if (options['premultiplyAlpha'] == 'premultiply') {
      for (var i = 0; i < pixels.length; i += 4) {
        for (var c = 0; c < 3; c++) {
          pixels[i + c] = (pixels[i + c] * pixels[i + 3] / 255).round();
        }
      }
    }

    return image;
  }
}

/// Installs the Flutter adapters for ent's platform services.
abstract final class FlutterPlatform {
  /// Sets [ImageUtils.platform] and [Loader.platform] unless something is already installed (pass
  /// [replace] to overwrite).
  static void install({bool replace = false}) {
    if (replace || ImageUtils.platform == null) {
      ImageUtils.platform = FlutterImagePlatform();
    }

    if (replace || Loader.platform == null) {
      Loader.platform = FlutterLoaderPlatform();
    }
  }
}

Future<LoaderResponse> _fetch(LoaderRequest request) async {
  final url = request.url;

  if (request.signal.aborted) {
    throw request.signal.reason!;
  }

  if (url.toLowerCase().startsWith('data:')) {
    final data = UriData.parse(url);
    return LoaderResponse(status: 200, url: url, headers: {'content-type': data.mimeType}, data: data.contentAsBytes());
  }

  final uri = Uri.tryParse(url);

  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    final client = HttpClient();

    try {
      final http = await client.getUrl(uri);
      request.headers.forEach(http.headers.set);
      final response = await http.close();
      final bytes = BytesBuilder(copy: false);

      await for (final chunk in response) {
        if (request.signal.aborted) {
          throw request.signal.reason!;
        }

        bytes.add(chunk);
      }

      final headers = <String, String>{};
      response.headers.forEach((name, values) => headers[name] = values.join(', '));

      return LoaderResponse(
        status: response.statusCode,
        statusText: response.reasonPhrase,
        url: url,
        headers: headers,
        data: bytes.takeBytes(),
      );
    } finally {
      client.close();
    }
  }

  try {
    final data = await rootBundle.load(url);
    return LoaderResponse(status: 200, url: url, data: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  } catch (_) {
    return LoaderResponse(status: 404, statusText: 'Not Found', url: url);
  }
}
