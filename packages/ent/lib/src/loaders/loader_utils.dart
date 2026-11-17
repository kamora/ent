part of '../../ent.dart';

final RegExp _loaderUtilsHttp = RegExp(r'^https?:\/\/', caseSensitive: false);
final RegExp _loaderUtilsHost = RegExp(r'(^https?:\/\/[^\/]+).*', caseSensitive: false);
final RegExp _loaderUtilsAbsolute = RegExp(r'^(https?:)?\/\/', caseSensitive: false);
final RegExp _loaderUtilsData = RegExp(r'^data:.*,.*$', caseSensitive: false);
final RegExp _loaderUtilsBlob = RegExp(r'^blob:.*$', caseSensitive: false);

/// A class with loader utility functions.
abstract final class LoaderUtils {
  /// Extracts the base URL from the given URL.
  static String extractUrlBase(String url) {
    final index = url.lastIndexOf('/');

    if (index == -1) {
      return './';
    }

    return url.substring(0, index + 1);
  }

  /// Resolves relative URLs against the given path. Absolute paths, data URLs, and blob URLs will be
  /// returned as is. Invalid URLs will return an empty string.
  static String resolveURL(Object? url, String path) {
    // Invalid URL
    if (url is! String || url == '') {
      return '';
    }

    // Host Relative URL
    if (_loaderUtilsHttp.hasMatch(path) && url.startsWith('/')) {
      path = path.replaceFirstMapped(_loaderUtilsHost, (m) => m[1]!);
    }

    // Absolute URL http://,https://,//
    if (_loaderUtilsAbsolute.hasMatch(url)) {
      return url;
    }

    // Data URI
    if (_loaderUtilsData.hasMatch(url)) {
      return url;
    }

    // Blob URL
    if (_loaderUtilsBlob.hasMatch(url)) {
      return url;
    }

    // Relative URL
    return path + url;
  }
}
