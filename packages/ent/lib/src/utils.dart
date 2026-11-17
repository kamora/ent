part of '../ent.dart';

// The logging utilities. The other utilities of the reference (typed-array helpers, canvas creation, GPU probes) live
// with the modules that use them.

/// Receives every engine log message instead of the console: `type` is `'log'`, `'warn'` or `'error'`, `message`
/// already carries the `ENT.` prefix, `params` are the extra arguments.
typedef ConsoleFunction = void Function(String type, String message, List<Object?> params);

ConsoleFunction? _setConsoleFunction;

final Map<String, bool> _utilsCache = {};

/// Sets a function that receives all log messages in place of the console. `null` restores the console.
void setConsoleFunction(ConsoleFunction? fn) {
  _setConsoleFunction = fn;
}

/// Returns the function set with [setConsoleFunction], or `null`.
ConsoleFunction? getConsoleFunction() {
  return _setConsoleFunction;
}

void _utilsPrint(String type, String message, List<Object?> params) {
  final fn = _setConsoleFunction;

  if (fn != null) {
    fn(type, message, params);
  } else {
    print([message, ...params].join(' '));
  }
}

/// Logs a message with the `ENT.` prefix.
void log(Object? message, [List<Object?> params = const []]) {
  _utilsPrint('log', 'ENT.$message', params);
}

/// Logs a warning with the `ENT.` prefix.
void warn(Object? message, [List<Object?> params = const []]) {
  _utilsPrint('warn', 'ENT.$message', params);
}

/// Logs an error with the `ENT.` prefix.
void error(Object? message, [List<Object?> params = const []]) {
  _utilsPrint('error', 'ENT.$message', params);
}

/// Logs a warning only the first time this exact message (with its params) is seen.
void warnOnce(Object? message, [List<Object?> params = const []]) {
  final key = [message, ...params].join(' ');

  if (_utilsCache.containsKey(key)) {
    return;
  }

  _utilsCache[key] = true;

  warn(message, params);
}

// Typed-array helpers. The reference exports them from the module (BufferGeometry, loaders and addons import them) but
// not from the `ent` entry point; they keep their names here.

/// Returns the minimum value in the given array, or `Infinity` for an empty array.
num arrayMin(List<num> array) {
  if (array.isEmpty) {
    return double.infinity;
  }

  var min = array[0];

  for (var i = 1, l = array.length; i < l; ++i) {
    if (array[i] < min) {
      min = array[i];
    }
  }

  return min;
}

/// Returns the maximum value in the given array, or `-Infinity` for an empty array.
num arrayMax(List<num> array) {
  if (array.isEmpty) {
    return double.negativeInfinity;
  }

  var max = array[0];

  for (var i = 1, l = array.length; i < l; ++i) {
    if (array[i] > max) {
      max = array[i];
    }
  }

  return max;
}

/// Returns `true` if the given array contains a value that needs 32-bit indices.
bool arrayNeedsUint32(List<num> array) {
  // assumes larger values usually on last

  for (var i = array.length - 1; i >= 0; --i) {
    if (array[i] >= 65535) {
      return true; // account for PRIMITIVE_RESTART_FIXED_INDEX, #24565
    }
  }

  return false;
}

/// Returns a new typed array of the given type name (`'Float32Array'`, ...) from [buffer]: a `ByteBuffer`
/// (a view of it), a list of values (a copy), or a length.
List<num> getTypedArray(String type, Object buffer) {
  final List<num> kind = switch (type) {
    'Int8Array' => Int8List(0),
    'Uint8Array' => Uint8List(0),
    'Uint8ClampedArray' => Uint8ClampedList(0),
    'Int16Array' => Int16List(0),
    'Uint16Array' => Uint16List(0),
    'Int32Array' => Int32List(0),
    'Uint32Array' => Uint32List(0),
    'Float32Array' => Float32List(0),
    'Float64Array' => Float64List(0),
    _ => throw EntError('ENT.getTypedArray: unsupported type $type'),
  };

  if (buffer is ByteBuffer) {
    return _typedArrayView(kind, buffer);
  }

  return _typedArrayFrom(kind, buffer);
}

/// Returns `true` if the given object is a typed array (a `dart:typed_data` list, not `ByteData`).
bool isTypedArray(Object? array) {
  return array is TypedData && array is List && array is! ByteData;
}
