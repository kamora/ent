part of '../../ent.dart';

// The reference passes array constructors (`Float32Array`, `Array`) as "types"; the port names them by their
// constructor name (`'Float32Array'`, `'Array'`), as `getTypedArray` does (exception E-ARRAYTYPE).

/// The constructor name of [array] as the reference's `array.constructor` would name it: a typed-array name for a
/// `dart:typed_data` list, `'Array'` for any other list.
String _animationArrayType(List<Object?> array) {
  if (array is List<num> && isTypedArray(array)) {
    return _typedArrayName(array);
  }

  return 'Array';
}

/// The utils `isTypedArray`, reachable inside [AnimationUtils], whose static of the same name shadows it.
bool _animationIsTypedArray(Object? object) => isTypedArray(object);

/// JS `ToNumber` for values copied into a typed array: numbers stay, `true`/`false` become 1/0, anything
/// else NaN.
double _animationToNumber(Object? value) {
  return switch (value) {
    num n => n.toDouble(),
    bool b => b ? 1.0 : 0.0,
    _ => double.nan,
  };
}

/// `array[ index ] = value` on a property mixer or keyframe buffer: a typed list stores `ToNumber( value )`,
/// a plain list stores the value as it is. Writes past the end of a typed list are dropped, like JS.
void _animationStore(List<Object?> array, int index, Object? value) {
  if (array is List<double>) {
    if (index < array.length) {
      array[index] = _animationToNumber(value);
    }

    return;
  }

  if (index < array.length) {
    array[index] = value;
  } else {
    _jsArraySetObject(array, index, value);
  }
}

/// `array[ index ] = value` on a plain growable list: grows it (padding with `null` where JS leaves holes).
void _jsArraySetObject(List<Object?> array, int index, Object? value) {
  while (array.length < index) {
    array.add(null);
  }

  array.add(value);
}

/// `value.toArray()` for any object that has one (math types), or `null` when it has none.
List<Object?>? _animationToArray(Object? value) {
  if (value == null || value is List || value is Map || value is String || value is num || value is bool) {
    return null;
  }

  try {
    return ((value as dynamic).toArray() as List).cast<Object?>();
  } on NoSuchMethodError {
    return null;
  }
}

/// A class with various methods to assist with animations.
abstract final class AnimationUtils {
  /// Converts an array to a specific type, named by its constructor (`'Float32Array'`, `'Array'`, ...).
  /// Returns the given array when it already has that type.
  static List<Object?>? convertArray(List<Object?>? array, String type) {
    if (array == null || _animationArrayType(array) == type) {
      return array;
    }

    if (type != 'Array') {
      // create typed array
      final source = array is List<num> ? array : [for (final v in array) _animationToNumber(v)];
      return getTypedArray(type, source);
    }

    return List<Object?>.of(array); // create Array
  }

  /// Returns `true` if the given object is a typed array.
  static bool isTypedArray(Object? object) {
    return _animationIsTypedArray(object);
  }

  /// Returns `true` if the given keyframe track settings hold Bezier tangent data.
  static bool hasTangents(Map<String, Object?>? settings) {
    return settings != null && settings.containsKey('inTangents') && settings.containsKey('outTangents');
  }

  /// Returns an array by which times and values can be sorted.
  static List<int> getKeyframeOrder(List<num> times) {
    final n = times.length;
    final result = List<int>.generate(n, (i) => i);

    // Array.prototype.sort is stable; Dart's sort is not, so ties keep their original order explicitly.
    result.sort((i, j) {
      final d = times[i] - times[j];

      if (d == 0 || d.isNaN) {
        return i - j;
      }

      return d.sign.toInt();
    });

    return result;
  }

  /// Sorts the given array by the previously computed order via [getKeyframeOrder].
  static List<Object?> sortedArray(List<Object?> values, int stride, List<int> order) {
    final nValues = values.length;
    final List<Object?> result;

    if (values is List<num> && _animationIsTypedArray(values)) {
      result = _typedArrayOfLength(values, nValues);
    } else {
      result = List<Object?>.filled(nValues, null, growable: true);
    }

    for (var i = 0, dstOffset = 0; dstOffset != nValues; ++i) {
      final srcOffset = order[i] * stride;

      for (var j = 0; j != stride; ++j) {
        _animationStore(result, dstOffset++, values[srcOffset + j]);
      }
    }

    return result;
  }

  /// Used for parsing AOS keyframe formats: appends each key's `time` to [times] and its
  /// [valuePropertyName] value (flattened) to [values].
  static void flattenJSON(List<Object?> jsonKeys, List<Object?> times, List<Object?> values, String valuePropertyName) {
    Object? keyAt(int index) => index < jsonKeys.length ? jsonKeys[index] : null;
    Object? valueOf(Object? key) => key is Map ? key[valuePropertyName] : null;
    Object? timeOf(Object? key) => key is Map ? key['time'] : null;

    var i = 1;
    var key = keyAt(0);

    while (key != null && valueOf(key) == null) {
      key = keyAt(i++);
    }

    if (key == null) {
      return; // no data
    }

    var value = valueOf(key);

    if (value == null) {
      return; // no data
    }

    if (value is List) {
      do {
        value = valueOf(key);

        if (value != null) {
          times.add(timeOf(key));
          values.addAll(value as List); // push all elements
        }

        key = keyAt(i++);
      } while (key != null);
    } else if (_animationToArray(value) != null) {
      // ...assume a math type (one with toArray)
      do {
        value = valueOf(key);

        if (value != null) {
          times.add(timeOf(key));
          values.addAll(_animationToArray(value)!);
        }

        key = keyAt(i++);
      } while (key != null);
    } else {
      // otherwise push as-is
      do {
        value = valueOf(key);

        if (value != null) {
          times.add(timeOf(key));
          values.add(value);
        }

        key = keyAt(i++);
      } while (key != null);
    }
  }

  /// Creates a new clip, containing only the segment of the original clip between the given frames.
  static AnimationClip subclip(
    AnimationClip sourceClip,
    String name,
    double startFrame,
    double endFrame, [
    double fps = 30,
  ]) {
    final clip = sourceClip.clone();

    clip.name = name;

    final tracks = <KeyframeTrack>[];

    for (var i = 0; i < clip.tracks.length; ++i) {
      final track = clip.tracks[i];
      final valueSize = track.getValueSize();

      final times = <Object?>[];
      final values = <Object?>[];

      for (var j = 0; j < track.times.length; ++j) {
        final frame = track.times[j] * fps;

        if (frame < startFrame || frame >= endFrame) {
          continue;
        }

        times.add(track.times[j]);

        for (var k = 0; k < valueSize; ++k) {
          values.add(track.values[(j * valueSize + k).toInt()]);
        }
      }

      if (times.isEmpty) {
        continue;
      }

      track.times = convertArray(times, _animationArrayType(track.times))! as List<double>;
      track.values = convertArray(values, _animationArrayType(track.values))!;

      tracks.add(track);
    }

    clip.tracks = tracks;

    // find minimum .times value across all tracks in the trimmed clip

    var minStartTime = double.infinity;

    for (var i = 0; i < clip.tracks.length; ++i) {
      if (minStartTime > clip.tracks[i].times[0]) {
        minStartTime = clip.tracks[i].times[0];
      }
    }

    // shift all tracks such that clip begins at t=0

    for (var i = 0; i < clip.tracks.length; ++i) {
      clip.tracks[i].shift(-1 * minStartTime);
    }

    clip.resetDuration();

    return clip;
  }

  /// Converts the keyframes of the given animation clip to an additive format, relative to the values at
  /// [referenceFrame] of [referenceClip] (default: the target clip itself).
  static AnimationClip makeClipAdditive(
    AnimationClip targetClip, [
    double referenceFrame = 0,
    AnimationClip? referenceClip,
    double fps = 30,
  ]) {
    referenceClip ??= targetClip;

    if (fps <= 0) {
      fps = 30;
    }

    final numTracks = referenceClip.tracks.length;
    final referenceTime = referenceFrame / fps;

    // Make each track's values relative to the values at the reference frame
    for (var i = 0; i < numTracks; ++i) {
      final referenceTrack = referenceClip.tracks[i];
      final referenceTrackType = referenceTrack.ValueTypeName;

      // Skip this track if it's non-numeric
      if (referenceTrackType == 'bool' || referenceTrackType == 'string') {
        continue;
      }

      // Find the track in the target clip whose name and type matches the reference track
      final targetTrack = targetClip.tracks
          .where((track) => track.name == referenceTrack.name && track.ValueTypeName == referenceTrackType)
          .firstOrNull;

      if (targetTrack == null) {
        continue;
      }

      // The reference also skips a third of the values for glTF cubic-spline tracks, recognized by a flag on their
      // factory function; that factory lives in the glTF loader addon (not ported), so the offsets stay 0.
      const referenceOffset = 0;
      final referenceValueSize = referenceTrack.getValueSize().toInt();

      const targetOffset = 0;
      final targetValueSize = targetTrack.getValueSize().toInt();

      final lastIndex = referenceTrack.times.length - 1;
      final referenceValues = referenceTrack.values as List<double>;
      List<double> referenceValue;

      // Find the value to subtract out of the track
      if (referenceTime <= referenceTrack.times[0]) {
        // Reference frame is earlier than the first keyframe, so just use the first keyframe
        const startIndex = referenceOffset;
        final endIndex = referenceValueSize - referenceOffset;
        referenceValue = referenceValues.sublist(startIndex, endIndex);
      } else if (referenceTime >= referenceTrack.times[lastIndex]) {
        // Reference frame is after the last keyframe, so just use the last keyframe
        final startIndex = lastIndex * referenceValueSize + referenceOffset;
        final endIndex = startIndex + referenceValueSize - referenceOffset;
        referenceValue = referenceValues.sublist(startIndex, endIndex);
      } else {
        // Interpolate to the reference value
        final interpolant = referenceTrack.createInterpolant();
        interpolant.evaluate(referenceTime);
        referenceValue = interpolant.resultBuffer.sublist(0);
      }

      // Conjugate the quaternion
      if (referenceTrackType == 'quaternion') {
        final referenceQuat = Quaternion().fromArray(referenceValue).normalize().conjugate();
        referenceQuat.toArray(referenceValue);
      }

      // Subtract the reference value from all of the track values

      final targetValues = targetTrack.values as List<double>;
      final numTimes = targetTrack.times.length;

      for (var j = 0; j < numTimes; ++j) {
        final valueStart = j * targetValueSize + targetOffset;

        if (referenceTrackType == 'quaternion') {
          // Multiply the conjugate for quaternion track types
          Quaternion.multiplyQuaternionsFlat(targetValues, valueStart, referenceValue, 0, targetValues, valueStart);
        } else {
          final valueEnd = targetValueSize - targetOffset * 2;

          // Subtract each value for all other numeric track types
          for (var k = 0; k < valueEnd; ++k) {
            targetValues[valueStart + k] -= referenceValue[k];
          }
        }
      }
    }

    targetClip.blendMode = AdditiveAnimationBlendMode;

    return targetClip;
  }
}
