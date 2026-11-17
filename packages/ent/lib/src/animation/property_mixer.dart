part of '../../ent.dart';

/// A mix function over regions of a property mixer's buffer.
typedef _PropertyMixFunction = void Function(List<Object?> buffer, int dstOffset, int srcOffset, double t, int stride);

/// Buffered scene graph property that allows weighted accumulation; used internally.
class PropertyMixer {
  /// Constructs a new property mixer for [binding], whose keyframe tracks have the value type [typeName]
  /// (`'quaternion'`, `'string'`, `'bool'`, or any numeric type) and [valueSize] values per keyframe.
  PropertyMixer(this.binding, String typeName, this.valueSize) {
    // buffer layout: [ incoming | accu0 | accu1 | orig | addAccu | (optional work) ]
    //
    // interpolators can use .buffer as their .result
    // the data then goes to 'incoming'
    //
    // 'accu0' and 'accu1' are used frame-interleaved for
    // the cumulative result and are compared to detect
    // changes
    //
    // 'orig' stores the original state of the property
    //
    // 'add' is used for additive cumulative results
    //
    // 'work' is optional and is only present for quaternion types. It is used
    // to store intermediate quaternion multiplication results

    switch (typeName) {
      case 'quaternion':
        _mixBufferRegion = _slerp;
        _mixBufferRegionAdditive = _slerpAdditive;
        _setIdentity = _setAdditiveIdentityQuaternion;

        buffer = Float64List(valueSize * 6);
        _workIndex = 5;

      case 'string':
      case 'bool':
        _mixBufferRegion = _select;

        // Use the regular mix function and for additive on these types,
        // additive is not relevant for non-numeric types
        _mixBufferRegionAdditive = _select;

        _setIdentity = _setAdditiveIdentityOther;

        buffer = List<Object?>.filled(valueSize * 5, null);

      default:
        _mixBufferRegion = _lerp;
        _mixBufferRegionAdditive = _lerpAdditive;
        _setIdentity = _setAdditiveIdentityNumeric;

        buffer = Float64List(valueSize * 5);
    }
  }

  /// The property binding.
  PropertyBindingLike binding;

  /// The keyframe track value size.
  int valueSize;

  /// The mixing buffer: a `Float64List` for numeric types, a plain list for strings and booleans.
  late List<Object?> buffer;

  late final _PropertyMixFunction _mixBufferRegion;

  late final _PropertyMixFunction _mixBufferRegionAdditive;

  late final void Function() _setIdentity;

  int _workIndex = 0;

  final int _origIndex = 3;

  final int _addIndex = 4;

  /// The index of this mixer in its animation mixer's cache, or `null` (set by [AnimationMixer]).
  int? _cacheIndex;

  /// Accumulated weight of the property binding.
  double cumulativeWeight = 0;

  /// Accumulated additive weight of the property binding.
  double cumulativeWeightAdditive = 0;

  /// Number of active keyframe tracks currently using this property binding.
  int useCount = 0;

  /// Number of keyframe tracks referencing this property binding.
  int referenceCount = 0;

  /// Accumulates data in the `incoming` region into `accu<i>`.
  void accumulate(int accuIndex, double weight) {
    // note: happily accumulating nothing when weight = 0, the caller knows
    // the weight and shouldn't have made the call in the first place

    final buffer = this.buffer;
    final stride = valueSize;
    final offset = accuIndex * stride + stride;

    var currentWeight = cumulativeWeight;

    if (currentWeight == 0) {
      // accuN := incoming * weight

      for (var i = 0; i != stride; ++i) {
        buffer[offset + i] = buffer[i];
      }

      currentWeight = weight;
    } else {
      // accuN := accuN + incoming * weight

      currentWeight += weight;
      final mix = weight / currentWeight;
      _mixBufferRegion(buffer, offset, 0, mix, stride);
    }

    cumulativeWeight = currentWeight;
  }

  /// Accumulates data in the `incoming` region into `add`.
  void accumulateAdditive(double weight) {
    final buffer = this.buffer;
    final stride = valueSize;
    final offset = stride * _addIndex;

    if (cumulativeWeightAdditive == 0) {
      // add = identity

      _setIdentity();
    }

    // add := add + incoming * weight

    _mixBufferRegionAdditive(buffer, offset, 0, weight, stride);
    cumulativeWeightAdditive += weight;
  }

  /// Applies the state of `accu<i>` to the binding when accus differ.
  void apply(int accuIndex) {
    final stride = valueSize;
    final buffer = this.buffer;
    final offset = accuIndex * stride + stride;

    final weight = cumulativeWeight;
    final weightAdditive = cumulativeWeightAdditive;

    final binding = this.binding;

    cumulativeWeight = 0;
    cumulativeWeightAdditive = 0;

    if (weight < 1) {
      // accuN := accuN + original * ( 1 - cumulativeWeight )

      final originalValueOffset = stride * _origIndex;

      _mixBufferRegion(buffer, offset, originalValueOffset, 1 - weight, stride);
    }

    if (weightAdditive > 0) {
      // accuN := accuN + additive accuN

      _mixBufferRegionAdditive(buffer, offset, _addIndex * stride, 1, stride);
    }

    for (var i = stride, e = stride + stride; i != e; ++i) {
      if (buffer[i] != buffer[i + stride]) {
        // value has changed -> update scene graph

        binding.setValue(buffer, offset);
        break;
      }
    }
  }

  /// Remembers the state of the bound property and copy it to both accus.
  void saveOriginalState() {
    final binding = this.binding;

    final buffer = this.buffer;
    final stride = valueSize;

    final originalValueOffset = stride * _origIndex;

    binding.getValue(buffer, originalValueOffset);

    // accu[0..1] := orig -- initially detect changes against the original
    for (var i = stride, e = originalValueOffset; i != e; ++i) {
      buffer[i] = buffer[originalValueOffset + (i % stride)];
    }

    // Add to identity for additive
    _setIdentity();

    cumulativeWeight = 0;
    cumulativeWeightAdditive = 0;
  }

  /// Applies the state previously taken via [saveOriginalState] to the binding.
  void restoreOriginalState() {
    final originalValueOffset = valueSize * 3;
    binding.setValue(buffer, originalValueOffset);
  }

  // internals

  void _setAdditiveIdentityNumeric() {
    final startIndex = _addIndex * valueSize;
    final endIndex = startIndex + valueSize;

    for (var i = startIndex; i < endIndex; i++) {
      buffer[i] = 0.0;
    }
  }

  void _setAdditiveIdentityQuaternion() {
    _setAdditiveIdentityNumeric();
    buffer[_addIndex * valueSize + 3] = 1.0;
  }

  void _setAdditiveIdentityOther() {
    final startIndex = _origIndex * valueSize;
    final targetIndex = _addIndex * valueSize;

    for (var i = 0; i < valueSize; i++) {
      buffer[targetIndex + i] = buffer[startIndex + i];
    }
  }

  // mix functions

  void _select(List<Object?> buffer, int dstOffset, int srcOffset, double t, int stride) {
    if (t >= 0.5) {
      for (var i = 0; i != stride; ++i) {
        buffer[dstOffset + i] = buffer[srcOffset + i];
      }
    }
  }

  void _slerp(List<Object?> buffer, int dstOffset, int srcOffset, double t, int stride) {
    final b = buffer as List<double>;
    Quaternion.slerpFlat(b, dstOffset, b, dstOffset, b, srcOffset, t);
  }

  void _slerpAdditive(List<Object?> buffer, int dstOffset, int srcOffset, double t, int stride) {
    final b = buffer as List<double>;
    final workOffset = _workIndex * stride;

    // Store result in intermediate buffer offset
    Quaternion.multiplyQuaternionsFlat(b, workOffset, b, dstOffset, b, srcOffset);

    // Slerp to the intermediate result
    Quaternion.slerpFlat(b, dstOffset, b, dstOffset, b, workOffset, t);
  }

  void _lerp(List<Object?> buffer, int dstOffset, int srcOffset, double t, int stride) {
    final b = buffer as List<double>;
    final s = 1 - t;

    for (var i = 0; i != stride; ++i) {
      final j = dstOffset + i;

      b[j] = b[j] * s + b[srcOffset + i] * t;
    }
  }

  void _lerpAdditive(List<Object?> buffer, int dstOffset, int srcOffset, double t, int stride) {
    final b = buffer as List<double>;

    for (var i = 0; i != stride; ++i) {
      final j = dstOffset + i;

      b[j] = b[j] + b[srcOffset + i] * t;
    }
  }
}
