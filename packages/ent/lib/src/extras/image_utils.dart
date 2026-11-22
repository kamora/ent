part of '../../ent.dart';

// The reference draws browser images (HTMLImageElement, HTMLCanvasElement, ImageBitmap) through a 2D canvas; those
// paths depend on the platform and go through [ImagePlatform], which a platform package (web, Flutter) installs in
// [ImageUtils.platform]. The plain image objects of data textures (`{ data, width, height, depth }`, here [DataImage])
// are handled here, as the reference does.

/// The plain image object of data textures and render targets: the reference's `{ data, width, height, depth }`.
///
/// A field left `null` is a missing or `undefined` key in the reference; readers treat it as `0` (`width || 0`).
class DataImage {
  /// Constructs a new image of the given data and size; a field left out stays `null`.
  DataImage({this.data, this.width, this.height, this.depth});

  /// The pixel data: a typed list (`Uint8List`, `Float32List`, ...) or `null`.
  Object? data;

  /// The width in pixels.
  int? width;

  /// The height in pixels.
  int? height;

  /// The depth in layers, for 3D and array textures.
  int? depth;

  /// A shallow copy, as the reference's `Object.assign( {}, image )`.
  DataImage copy() {
    return DataImage(data: data, width: width, height: height, depth: depth);
  }
}

/// The size of a platform image, as read by [ImagePlatform.getSize].
typedef ImageSize = ({int width, int height, int depth});

/// The browser-dependent image operations of the reference, supplied by a platform package.
///
/// The reference performs them with DOM classes (`HTMLImageElement`, `HTMLCanvasElement`, `ImageBitmap`,
/// `HTMLVideoElement`, `VideoFrame`) and a 2D canvas; the core package has neither.
abstract class ImagePlatform {
  /// Whether [image] is a platform image that the reference draws through a canvas (`HTMLImageElement`,
  /// `HTMLCanvasElement`, `ImageBitmap`).
  bool isImage(Object image);

  /// The reference's [ImageUtils.getDataURL] for a platform image: a data URI of the image in [type] format.
  String getDataURL(Object image, String type);

  /// The reference's canvas branch of [ImageUtils.sRGBToLinear]: returns a converted copy of [image].
  Object sRGBToLinear(Object image);

  /// The dimensions of a platform image or video (the reference reads `videoWidth`/`videoHeight` of an
  /// `HTMLVideoElement` and `displayWidth`/`displayHeight` of a `VideoFrame`), or `null` when [image] is not one.
  ImageSize? getSize(Object image);
}

/// A class containing utility functions for images.
abstract final class ImageUtils {
  /// The platform operations; `null` until a platform package installs them.
  static ImagePlatform? platform;

  /// Returns a data URI containing a representation of the given image (`type` defaults to
  /// `'image/png'`).
  ///
  /// Needs an [ImagePlatform]: without one there is no canvas, and this throws a [StateError] (the reference returns
  /// `image.src`, which a non-DOM image does not have).
  static String getDataURL(Object image, [String type = 'image/png']) {
    final p = platform;

    if (p == null) {
      throw StateError('ENT.ImageUtils: getDataURL() needs an ImagePlatform (ImageUtils.platform).');
    }

    return p.getDataURL(image, type);
  }

  /// Converts the given sRGB image data to linear color space.
  ///
  /// Platform images go through [platform]; a [DataImage] with data is converted here into a new
  /// [DataImage]; anything else is returned unchanged with a warning.
  static Object sRGBToLinear(Object image) {
    final p = platform;

    if (p != null && p.isImage(image)) {
      return p.sRGBToLinear(image);
    } else if (image is DataImage && image.data != null) {
      final data = _imageUtilsCopy(image.data!);

      for (var i = 0; i < data.length; i++) {
        if (data is Uint8List || data is Uint8ClampedList) {
          data[i] = (SRGBToLinear(data[i] / 255) * 255).floor();
        } else if (data is TypedData && data is! List<double>) {
          // Other integer typed arrays: the reference stores the float, which the typed array truncates.

          data[i] = SRGBToLinear(data[i].toDouble()).truncate();
        } else {
          // assuming float

          data[i] = SRGBToLinear(data[i].toDouble());
        }
      }

      return DataImage(data: data, width: image.width, height: image.height);
    } else {
      warn('ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied.');
      return image;
    }
  }
}

/// `data.slice( 0 )`: a copy of the same list type.
List<num> _imageUtilsCopy(Object data) {
  return switch (data) {
    Uint8ClampedList d => Uint8ClampedList.fromList(d),
    Uint8List d => Uint8List.fromList(d),
    Int8List d => Int8List.fromList(d),
    Uint16List d => Uint16List.fromList(d),
    Int16List d => Int16List.fromList(d),
    Uint32List d => Uint32List.fromList(d),
    Int32List d => Int32List.fromList(d),
    Float32List d => Float32List.fromList(d),
    Float64List d => Float64List.fromList(d),
    List<double> d => List<double>.of(d),
    List<num> d => List<num>.of(d),
    _ => throw ArgumentError.value(data, 'data', 'not a list of numbers'),
  };
}

/// `array.constructor.name` for the lists that stand in for JS arrays.
String _imageUtilsArrayName(Object data) {
  return switch (data) {
    Uint8ClampedList _ => 'Uint8ClampedArray',
    Uint8List _ => 'Uint8Array',
    Int8List _ => 'Int8Array',
    Uint16List _ => 'Uint16Array',
    Int16List _ => 'Int16Array',
    Uint32List _ => 'Uint32Array',
    Int32List _ => 'Int32Array',
    Float32List _ => 'Float32Array',
    Float64List _ => 'Float64Array',
    _ => 'Array',
  };
}
