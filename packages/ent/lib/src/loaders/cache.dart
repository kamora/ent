part of '../../ent.dart';

/// A simple caching system, used internally by [FileLoader]. To enable caching across all loaders that use
/// [FileLoader], add `Cache.enabled = true` once in your app.
///
/// The reference's Cache is an object literal; here it is a class with static members (E-SINGLETON).
abstract final class Cache {
  /// Whether caching is enabled or not.
  static bool enabled = false;

  /// A dictionary that holds cached files.
  static Map<String, Object?> files = {};

  /// Adds a cache entry with a key to reference the file. If this key already holds a file, it is
  /// overwritten. Blob URLs are never cached.
  static void add(String key, Object? file) {
    if (enabled == false) {
      return;
    }

    if (_cacheIsBlobURL(key)) {
      return;
    }

    files[key] = file;
  }

  /// Gets the cached value for the given key; `null` (`undefined` in the reference) if caching is disabled, the key is
  /// a blob URL, or nothing is cached for it.
  static Object? get(String key) {
    if (enabled == false) {
      return null;
    }

    if (_cacheIsBlobURL(key)) {
      return null;
    }

    return files[key];
  }

  /// Removes the cached file associated with the given key.
  static void remove(String key) {
    files.remove(key);
  }

  /// Removes all entries from the cache.
  static void clear() {
    files = {};
  }
}

/// Whether the cache key (`'file:<url>'`, ...) names a blob URL. The reference parses the URL with `new URL()`, which
/// accepts only absolute URLs; a relative one is not a blob URL.
bool _cacheIsBlobURL(String key) {
  final url = Uri.tryParse(key.substring(key.indexOf(':') + 1)); // remove type identifier
  return url != null && url.hasScheme && url.scheme == 'blob';
}
