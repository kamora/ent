part of '../../ent.dart';

/// Creates the interpolant of a keyframe track: the reference's `track.createInterpolant`, a prototype method called
/// with `this` bound to the track. In Dart the track is passed in, so a factory copied to another track (as
/// [KeyframeTrack.clone] does) works on that track (exception E-FACTORY).
typedef KeyframeInterpolantFactory = Interpolant Function(KeyframeTrack track, List<Object?>? result);

Interpolant _keyframeDiscrete(KeyframeTrack track, List<Object?>? result) {
  return track.InterpolantFactoryMethodDiscrete(result);
}

Interpolant _keyframeLinear(KeyframeTrack track, List<Object?>? result) {
  return track.InterpolantFactoryMethodLinear(result);
}

Interpolant _keyframeSmooth(KeyframeTrack track, List<Object?>? result) {
  return track.InterpolantFactoryMethodSmooth(result);
}

Interpolant _keyframeBezier(KeyframeTrack track, List<Object?>? result) {
  return track.InterpolantFactoryMethodBezier(result);
}

/// Represents a timed sequence of keyframes, which are composed of lists of times and related values, and
/// which are used to animate a specific property of an object.
class KeyframeTrack {
  /// Constructs a new keyframe track.
  ///
  /// [name] can refer to morph targets, bones or other values within an animated object (see
  /// [PropertyBinding.parseTrackName]); [times] and [values] are converted to [TimeBufferType] and
  /// [ValueBufferType]; [interpolation] defaults to [DefaultInterpolation].
  KeyframeTrack(this.name, List<Object?> times, List<Object?> values, [int? interpolation])
    : times = const <double>[],
      values = const [] {
    if (times.isEmpty) {
      throw EntError('ENT.KeyframeTrack: no keyframes in track named $name');
    }

    this.times = AnimationUtils.convertArray(times, TimeBufferType)! as List<double>;
    this.values = AnimationUtils.convertArray(values, ValueBufferType)!;

    setInterpolation(interpolation == null || interpolation == 0 ? DefaultInterpolation : interpolation);
  }

  /// The track's name can refer to morph targets or bones or possibly other values within an animated
  /// object. See [PropertyBinding.parseTrackName] for the forms of strings that can be parsed for property
  /// binding.
  String name;

  /// The keyframe times.
  List<double> times;

  /// The keyframe values: a `Float32List` for numeric tracks, a plain list for boolean and string tracks.
  List<Object?> values;

  /// Bezier tangent data (`inTangents`, `outTangents`), set by loaders before creating the interpolant. The reference
  /// assigns this property dynamically; it is `null` when unset (`undefined` in the reference).
  Map<String, Object?>? settings;

  /// The value type name.
  String get ValueTypeName => '';

  /// The time buffer type of this keyframe track, by constructor name.
  String get TimeBufferType => 'Float32Array';

  /// The value buffer type of this keyframe track, by constructor name (`'Array'` for a plain list).
  String get ValueBufferType => 'Float32Array';

  /// The default interpolation type of this keyframe track.
  int get DefaultInterpolation => InterpolateLinear;

  // The factory per interpolation type; `null` where a subclass sets the reference's prototype method to undefined.

  KeyframeInterpolantFactory? get _factoryDiscrete => _keyframeDiscrete;

  KeyframeInterpolantFactory? get _factoryLinear => _keyframeLinear;

  KeyframeInterpolantFactory? get _factorySmooth => _keyframeSmooth;

  KeyframeInterpolantFactory? get _factoryBezier => _keyframeBezier;

  /// The factory used by [createInterpolant]: the reference assigns `track.createInterpolant` directly (e.g. the glTF
  /// loader's cubic-spline factory). Set by [setInterpolation] (exception E-FACTORY).
  KeyframeInterpolantFactory? interpolantFactory;

  /// Creates the interpolant for this track with the current interpolation; [result] is the result buffer
  /// (a new one when omitted).
  Interpolant createInterpolant([List<Object?>? result]) {
    return interpolantFactory!(this, result);
  }

  /// Converts the keyframe track to JSON.
  static Map<String, Object?> toJSON(KeyframeTrack track) {
    // by default, we assume the data can be serialized as-is
    final json = <String, Object?>{
      'name': track.name,
      'times': AnimationUtils.convertArray(track.times, 'Array'),
      'values': AnimationUtils.convertArray(track.values, 'Array'),
    };

    final interpolation = track.getInterpolation();

    if (interpolation != track.DefaultInterpolation) {
      json['interpolation'] = interpolation;
    }

    final settings = track.settings;

    if (AnimationUtils.hasTangents(settings)) {
      json['settings'] = {
        'inTangents': AnimationUtils.convertArray(settings!['inTangents'] as List<Object?>?, 'Array'),
        'outTangents': AnimationUtils.convertArray(settings['outTangents'] as List<Object?>?, 'Array'),
      };
    }

    json['type'] = track.ValueTypeName; // mandatory

    return json;
  }

  /// Factory method for creating a new discrete interpolant.
  Interpolant InterpolantFactoryMethodDiscrete([List<Object?>? result]) {
    final values = this.values;

    if (values is List<double>) {
      return DiscreteInterpolant(times, values, _keyframeValueSize(this), result as List<double>?);
    }

    return KeyframeObjectInterpolant(times, values, _keyframeValueSize(this), result);
  }

  /// Factory method for creating a new linear interpolant.
  Interpolant InterpolantFactoryMethodLinear([List<Object?>? result]) {
    return LinearInterpolant(times, values as List<double>, _keyframeValueSize(this), result as List<double>?);
  }

  /// Factory method for creating a new smooth interpolant.
  Interpolant InterpolantFactoryMethodSmooth([List<Object?>? result]) {
    return CubicInterpolant(times, values as List<double>, _keyframeValueSize(this), result as List<double>?);
  }

  /// Factory method for creating a new Bezier interpolant.
  ///
  /// The Bezier interpolant requires tangent data in [settings] before creating the interpolant:
  /// `inTangents` and `outTangents`, each with `[time, value]` pairs per keyframe per component.
  Interpolant InterpolantFactoryMethodBezier([List<Object?>? result]) {
    final interpolant = BezierInterpolant(
      times,
      values as List<double>,
      _keyframeValueSize(this),
      result as List<double>?,
    );

    final settings = this.settings;

    if (settings != null) {
      interpolant.inTangents = settings['inTangents'] as List<double>?;
      interpolant.outTangents = settings['outTangents'] as List<double>?;
    }

    return interpolant;
  }

  /// Defines the interpolation factor method for this keyframe track (`InterpolateDiscrete`,
  /// `InterpolateLinear`, `InterpolateSmooth` or `InterpolateBezier`).
  KeyframeTrack setInterpolation(int interpolation) {
    final factoryMethod = switch (interpolation) {
      InterpolateDiscrete => _factoryDiscrete,
      InterpolateLinear => _factoryLinear,
      InterpolateSmooth => _factorySmooth,
      InterpolateBezier => _factoryBezier,
      _ => null,
    };

    if (factoryMethod == null) {
      final message = 'unsupported interpolation for $ValueTypeName keyframe track named $name';

      if (interpolantFactory == null) {
        // fall back to default, unless the default itself is messed up
        if (interpolation != DefaultInterpolation) {
          setInterpolation(DefaultInterpolation);
        } else {
          throw EntError(message); // fatal, in this case
        }
      }

      warn('KeyframeTrack:', [message]);
      return this;
    }

    interpolantFactory = factoryMethod;

    return this;
  }

  /// Returns the current interpolation type, or `null` (`undefined` in the reference) for a custom factory.
  int? getInterpolation() {
    final current = interpolantFactory;

    if (current == null) {
      return null;
    }

    if (current == _factoryDiscrete) {
      return InterpolateDiscrete;
    } else if (current == _factoryLinear) {
      return InterpolateLinear;
    } else if (current == _factorySmooth) {
      return InterpolateSmooth;
    } else if (current == _factoryBezier) {
      return InterpolateBezier;
    }

    return null;
  }

  /// Returns the value size: the number of values per keyframe (fractional for an invalid track, as the reference's
  /// division).
  double getValueSize() {
    return values.length / times.length;
  }

  /// Moves all keyframes either forward or backward in time.
  KeyframeTrack shift(double timeOffset) {
    if (timeOffset != 0.0) {
      final times = this.times;

      for (var i = 0, n = times.length; i != n; ++i) {
        times[i] += timeOffset;
      }

      final settings = this.settings;

      if (AnimationUtils.hasTangents(settings)) {
        _keyframeShiftTangentTimes(settings!['inTangents'] as List<double>, timeOffset);
        _keyframeShiftTangentTimes(settings['outTangents'] as List<double>, timeOffset);
      }
    }

    return this;
  }

  /// Scale all keyframe times by a factor (useful for frame - seconds conversions).
  KeyframeTrack scale(double timeScale) {
    if (timeScale != 1.0) {
      final times = this.times;

      for (var i = 0, n = times.length; i != n; ++i) {
        times[i] *= timeScale;
      }

      final settings = this.settings;

      if (AnimationUtils.hasTangents(settings)) {
        _keyframeScaleTangentTimes(settings!['inTangents'] as List<double>, timeScale);
        _keyframeScaleTangentTimes(settings['outTangents'] as List<double>, timeScale);
      }
    }

    return this;
  }

  /// Removes keyframes before and after animation without changing any values within the defined time
  /// range.
  ///
  /// Note: The method does not shift around keys to the start of the track time, because for interpolated
  /// keys this will change their values.
  KeyframeTrack trim(double startTime, double endTime) {
    final times = this.times;
    final nKeys = times.length;

    var from = 0;
    var to = nKeys - 1;

    while (from != nKeys && times[from] < startTime) {
      ++from;
    }

    while (to != -1 && times[to] > endTime) {
      --to;
    }

    ++to; // inclusive -> exclusive bound

    if (from != 0 || to != nKeys) {
      // empty tracks are forbidden, so keep at least one keyframe
      if (from >= to) {
        to = math.max(to, 1);
        from = to - 1;
      }

      final stride = getValueSize().toInt();
      this.times = times.sublist(from, to);
      values = values.sublist(from * stride, to * stride);
    }

    return this;
  }

  /// Performs minimal validation on the keyframe track. Returns `true` if the values are valid.
  bool validate() {
    var valid = true;

    final valueSize = getValueSize();

    if (valueSize - valueSize.floorToDouble() != 0) {
      error('KeyframeTrack: Invalid value size in track.', [this]);
      valid = false;
    }

    final times = this.times;
    final values = this.values;
    final nKeys = times.length;

    if (nKeys == 0) {
      error('KeyframeTrack: Track is empty.', [this]);
      valid = false;
    }

    double? prevTime;

    for (var i = 0; i != nKeys; i++) {
      final currTime = times[i];

      if (currTime.isNaN) {
        error('KeyframeTrack: Time is not a valid number.', [this, i, currTime]);
        valid = false;
        break;
      }

      if (prevTime != null && prevTime > currTime) {
        error('KeyframeTrack: Out of order keys.', [this, i, currTime, prevTime]);
        valid = false;
        break;
      }

      prevTime = currTime;
    }

    if (AnimationUtils.isTypedArray(values)) {
      for (var i = 0, n = values.length; i != n; ++i) {
        final value = values[i] as num;

        if (value.isNaN) {
          error('KeyframeTrack: Value is not a valid number.', [this, i, value]);
          valid = false;
          break;
        }
      }
    }

    return valid;
  }

  /// Optimizes this keyframe track by removing equivalent sequential keys (which are common in morph target
  /// sequences).
  KeyframeTrack optimize() {
    // (0,0,0,0,1,1,1,0,0,0,0,0,0,0) --> (0,0,1,1,0,0)

    // times or values may be shared with other tracks, so overwriting is unsafe
    final times = this.times.sublist(0);
    final values = this.values.sublist(0);
    final stride = getValueSize().toInt();

    final smoothInterpolation = getInterpolation() == InterpolateSmooth;

    final lastIndex = times.length - 1;

    var writeIndex = 1;

    for (var i = 1; i < lastIndex; ++i) {
      var keep = false;

      final time = times[i];
      final timeNext = times[i + 1];

      // remove adjacent keyframes scheduled at the same time

      if (time != timeNext && (i != 1 || time != times[0])) {
        if (!smoothInterpolation) {
          // remove unnecessary keyframes same as their neighbors

          final offset = i * stride;
          final offsetP = offset - stride;
          final offsetN = offset + stride;

          for (var j = 0; j != stride; ++j) {
            final value = values[offset + j];

            if (value != values[offsetP + j] || value != values[offsetN + j]) {
              keep = true;
              break;
            }
          }
        } else {
          keep = true;
        }
      }

      // in-place compaction

      if (keep) {
        if (i != writeIndex) {
          times[writeIndex] = times[i];

          final readOffset = i * stride;
          final writeOffset = writeIndex * stride;

          for (var j = 0; j != stride; ++j) {
            values[writeOffset + j] = values[readOffset + j];
          }
        }

        ++writeIndex;
      }
    }

    // flush last keyframe (compaction looks ahead)

    if (lastIndex > 0) {
      times[writeIndex] = times[lastIndex];

      for (var readOffset = lastIndex * stride, writeOffset = writeIndex * stride, j = 0; j != stride; ++j) {
        values[writeOffset + j] = values[readOffset + j];
      }

      ++writeIndex;
    }

    if (writeIndex != times.length) {
      this.times = times.sublist(0, writeIndex);
      this.values = values.sublist(0, writeIndex * stride);
    } else {
      this.times = times;
      this.values = values;
    }

    return this;
  }

  /// Creates a track of this class; the reference's `new this.constructor( name, times, values )`. Subclasses override
  /// it so that [clone] keeps their type (exception E-CLONE).
  KeyframeTrack _create(String name, List<Object?> times, List<Object?> values) {
    return KeyframeTrack(name, times, values);
  }

  /// Returns a new keyframe track with copied values from this instance.
  KeyframeTrack clone() {
    final times = this.times.sublist(0);
    final values = this.values.sublist(0);

    final track = _create(name, times, values);

    // Interpolant argument to constructor is not saved, so copy the factory method directly.
    track.interpolantFactory = interpolantFactory;

    final settings = this.settings;

    if (AnimationUtils.hasTangents(settings)) {
      track.settings = {
        'inTangents': (settings!['inTangents'] as List<Object?>).sublist(0),
        'outTangents': (settings['outTangents'] as List<Object?>).sublist(0),
      };
    }

    return track;
  }
}

/// The interpolant sample size: the reference passes `getValueSize()` straight to a typed-array constructor.
int _keyframeValueSize(KeyframeTrack track) => track.getValueSize().toInt();

void _keyframeShiftTangentTimes(List<double> tangents, double timeOffset) {
  // tangents are [ time, value ] pairs, so only every second entry is a time

  for (var i = 0, n = tangents.length; i != n; i += 2) {
    tangents[i] += timeOffset;
  }
}

void _keyframeScaleTangentTimes(List<double> tangents, double timeScale) {
  // tangents are [ time, value ] pairs, so only every second entry is a time

  for (var i = 0, n = tangents.length; i != n; i += 2) {
    tangents[i] *= timeScale;
  }
}

/// The discrete interpolant of a track whose values are not numbers (boolean and string tracks).
///
/// The reference runs a `DiscreteInterpolant` over the plain value array. The Dart interpolants hold `double` lists, so
/// this subclass interpolates the value *indices* and copies the selected values into [objectResult] after each
/// [evaluate]; that is where the mixer's buffer goes (exception E-OBJTRACK).
class KeyframeObjectInterpolant extends DiscreteInterpolant {
  /// Constructs a new interpolant over [objectValues] at the given positions, with the sample size and an optional
  /// result list.
  KeyframeObjectInterpolant(
    List<double> parameterPositions,
    this.objectValues,
    int sampleSize, [
    List<Object?>? objectResult,
  ]) : objectResult = objectResult ?? List<Object?>.filled(sampleSize, null, growable: true),
       super(
         parameterPositions,
         Float64List.fromList([for (var i = 0; i < objectValues.length; i++) i.toDouble()]),
         sampleSize,
       );

  /// The keyframe values, as the reference's `sampleValues`.
  List<Object?> objectValues;

  /// The interpolated values, as the reference's `resultBuffer`.
  List<Object?> objectResult;

  @override
  List<double> evaluate(double t) {
    final indices = super.evaluate(t);

    for (var i = 0; i < valueSize; i++) {
      final index = indices[i];
      _animationStore(objectResult, i, index.isNaN ? null : objectValues[index.toInt()]);
    }

    return indices;
  }
}
