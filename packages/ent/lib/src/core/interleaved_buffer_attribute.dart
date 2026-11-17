part of '../../ent.dart';

final _interleavedBufferAttributeVector = Vector3();

/// An alternative version of a buffer attribute with interleaved data. Interleaved attributes share a
/// common interleaved data storage ([InterleavedBuffer]) and refer with different offsets into the buffer.
class InterleavedBufferAttribute implements BufferAttributeLike {
  /// Constructs a new interleaved buffer attribute over [interleavedBuffer], with [itemSize] values per vertex starting
  /// at [offset] within each stride. Without a buffer (`undefined` in the reference) it views an empty
  /// [InterleavedBuffer], with an item size and offset of `0`.
  InterleavedBufferAttribute([
    InterleavedBuffer? interleavedBuffer,
    int? itemSize,
    int? offset,
    this.normalized = false,
  ]) : data = interleavedBuffer ?? InterleavedBuffer(),
       itemSize = itemSize ?? 0,
       offset = offset ?? 0,
       _normalizationScale = interleavedBuffer == null
           ? null
           : MathUtils.getNormalizationScale(interleavedBuffer.array);

  /// This flag can be used for type testing.
  @override
  bool get isInterleavedBufferAttribute => true;

  @override
  bool get isBufferAttribute => false;

  /// The name of the buffer attribute.
  @override
  String name = '';

  /// The buffer holding the interleaved data.
  InterleavedBuffer data;

  /// The item size, see [BufferAttribute.itemSize].
  @override
  int itemSize;

  /// The attribute offset into the buffer.
  int offset;

  /// Whether the data are normalized or not, see [BufferAttribute.normalized]
  @override
  bool normalized;

  /// Cached normalization factor, see [MathUtils.getNormalizationScale].
  final double? _normalizationScale;

  /// The item count of this buffer attribute.
  @override
  int get count {
    return data.count;
  }

  /// The array holding the interleaved buffer attribute data.
  @override
  List<num> get array {
    return data.array;
  }

  /// Flag to indicate that this attribute has changed and should be re-sent to the GPU. Set this to `true`
  /// when you modify the value of the array.
  @override
  set needsUpdate(bool value) {
    data.needsUpdate = value;
  }

  /// Applies the given 4x4 matrix to the given attribute. Only works with item size `3`.
  @override
  InterleavedBufferAttribute applyMatrix4(Matrix4 m) {
    for (var i = 0, l = data.count; i < l; i++) {
      _interleavedBufferAttributeVector.fromBufferAttribute(this, i);

      _interleavedBufferAttributeVector.applyMatrix4(m);

      setXYZ(
        i,
        _interleavedBufferAttributeVector.x,
        _interleavedBufferAttributeVector.y,
        _interleavedBufferAttributeVector.z,
      );
    }

    return this;
  }

  /// Applies the given 3x3 normal matrix to the given attribute. Only works with item size `3`.
  @override
  InterleavedBufferAttribute applyNormalMatrix(Matrix3 m) {
    for (var i = 0, l = count; i < l; i++) {
      _interleavedBufferAttributeVector.fromBufferAttribute(this, i);

      _interleavedBufferAttributeVector.applyNormalMatrix(m);

      setXYZ(
        i,
        _interleavedBufferAttributeVector.x,
        _interleavedBufferAttributeVector.y,
        _interleavedBufferAttributeVector.z,
      );
    }

    return this;
  }

  /// Applies the given 4x4 matrix to the given attribute. Only works with item size `3` and with direction
  /// vectors.
  @override
  InterleavedBufferAttribute transformDirection(Matrix4 m) {
    for (var i = 0, l = count; i < l; i++) {
      _interleavedBufferAttributeVector.fromBufferAttribute(this, i);

      _interleavedBufferAttributeVector.transformDirection(m);

      setXYZ(
        i,
        _interleavedBufferAttributeVector.x,
        _interleavedBufferAttributeVector.y,
        _interleavedBufferAttributeVector.z,
      );
    }

    return this;
  }

  /// Returns the given component of the vector at the given index.
  @override
  double getComponent(int index, int component) {
    var value = _typedArrayGet(data.array, index * data.stride + offset + component);

    if (normalized) {
      value = _denormalize(value);
    }

    return value;
  }

  /// Sets the given value to the given component of the vector at the given index.
  @override
  InterleavedBufferAttribute setComponent(int index, int component, double value) {
    if (normalized) {
      value = _normalize(value);
    }

    _typedArraySet(data.array, index * data.stride + offset + component, value);

    return this;
  }

  /// Sets the x component of the vector at the given index.
  @override
  InterleavedBufferAttribute setX(int index, double x) {
    if (normalized) {
      x = _normalize(x);
    }

    _typedArraySet(data.array, index * data.stride + offset, x);

    return this;
  }

  /// Sets the y component of the vector at the given index.
  @override
  InterleavedBufferAttribute setY(int index, double y) {
    if (normalized) {
      y = _normalize(y);
    }

    _typedArraySet(data.array, index * data.stride + offset + 1, y);

    return this;
  }

  /// Sets the z component of the vector at the given index.
  @override
  InterleavedBufferAttribute setZ(int index, double z) {
    if (normalized) {
      z = _normalize(z);
    }

    _typedArraySet(data.array, index * data.stride + offset + 2, z);

    return this;
  }

  /// Sets the w component of the vector at the given index.
  @override
  InterleavedBufferAttribute setW(int index, double w) {
    if (normalized) {
      w = _normalize(w);
    }

    _typedArraySet(data.array, index * data.stride + offset + 3, w);

    return this;
  }

  /// Returns the x component of the vector at the given index.
  @override
  double getX(int index) {
    var x = _typedArrayGet(data.array, index * data.stride + offset);

    if (normalized) {
      x = _denormalize(x);
    }

    return x;
  }

  /// Returns the y component of the vector at the given index.
  @override
  double getY(int index) {
    var y = _typedArrayGet(data.array, index * data.stride + offset + 1);

    if (normalized) {
      y = _denormalize(y);
    }

    return y;
  }

  /// Returns the z component of the vector at the given index.
  @override
  double getZ(int index) {
    var z = _typedArrayGet(data.array, index * data.stride + offset + 2);

    if (normalized) {
      z = _denormalize(z);
    }

    return z;
  }

  /// Returns the w component of the vector at the given index.
  @override
  double getW(int index) {
    var w = _typedArrayGet(data.array, index * data.stride + offset + 3);

    if (normalized) {
      w = _denormalize(w);
    }

    return w;
  }

  /// Sets the x and y component of the vector at the given index.
  @override
  InterleavedBufferAttribute setXY(int index, double x, double y) {
    index = index * data.stride + offset;

    if (normalized) {
      x = _normalize(x);
      y = _normalize(y);
    }

    _typedArraySet(data.array, index + 0, x);
    _typedArraySet(data.array, index + 1, y);

    return this;
  }

  /// Sets the x, y and z component of the vector at the given index.
  @override
  InterleavedBufferAttribute setXYZ(int index, double x, double y, double z) {
    index = index * data.stride + offset;

    if (normalized) {
      x = _normalize(x);
      y = _normalize(y);
      z = _normalize(z);
    }

    _typedArraySet(data.array, index + 0, x);
    _typedArraySet(data.array, index + 1, y);
    _typedArraySet(data.array, index + 2, z);

    return this;
  }

  /// Sets the x, y, z and w component of the vector at the given index.
  @override
  InterleavedBufferAttribute setXYZW(int index, double x, double y, double z, double w) {
    index = index * data.stride + offset;

    if (normalized) {
      x = _normalize(x);
      y = _normalize(y);
      z = _normalize(z);
      w = _normalize(w);
    }

    _typedArraySet(data.array, index + 0, x);
    _typedArraySet(data.array, index + 1, y);
    _typedArraySet(data.array, index + 2, z);
    _typedArraySet(data.array, index + 3, w);

    return this;
  }

  /// Returns a new buffer attribute with copied values from this instance.
  ///
  /// If no parameter is provided, cloning an interleaved buffer attribute will de-interleave buffer data
  /// and return a [BufferAttribute]. [data] is an object (map) holding shared interleaved buffers for
  /// cloning geometries with interleaved attributes (under `data['interleavedBuffers']`).
  @override
  BufferAttributeLike clone([Map<String, Object?>? data]) {
    if (data == null) {
      log(
        'InterleavedBufferAttribute.clone(): Cloning an interleaved buffer attribute will de-interleave buffer data.',
      );

      final values = <num>[];

      for (var i = 0; i < count; i++) {
        final index = i * this.data.stride + offset;

        for (var j = 0; j < itemSize; j++) {
          values.add(_typedArrayGet(this.data.array, index + j));
        }
      }

      return BufferAttribute(_typedArrayLike(array, values), itemSize, normalized);
    } else {
      final buffers = (data['interleavedBuffers'] ??= <String, Object?>{}) as Map<String, Object?>;

      if (buffers[this.data.uuid] == null) {
        buffers[this.data.uuid] = this.data.clone(data);
      }

      return InterleavedBufferAttribute(buffers[this.data.uuid] as InterleavedBuffer, itemSize, offset, normalized);
    }
  }

  /// Serializes the buffer attribute into JSON.
  ///
  /// If no parameter is provided, the interleaved data are de-interleaved and saved as an ordinary buffer
  /// attribute. [data] is an object (map) holding the interleaved buffers when serializing geometries with
  /// interleaved attributes (under `data['interleavedBuffers']`).
  @override
  Map<String, Object?> toJSON([Map<String, Object?>? data]) {
    if (data == null) {
      log(
        'InterleavedBufferAttribute.toJSON(): Serializing an interleaved buffer attribute will de-interleave buffer data.',
      );

      final values = <num>[];

      for (var i = 0; i < count; i++) {
        final index = i * this.data.stride + offset;

        for (var j = 0; j < itemSize; j++) {
          values.add(_typedArrayGet(this.data.array, index + j));
        }
      }

      // de-interleave data and save it as an ordinary buffer attribute for now

      return {'itemSize': itemSize, 'type': _typedArrayName(array), 'array': values, 'normalized': normalized};
    } else {
      // save as true interleaved attribute

      final buffers = (data['interleavedBuffers'] ??= <String, Object?>{}) as Map<String, Object?>;

      if (buffers[this.data.uuid] == null) {
        buffers[this.data.uuid] = this.data.toJSON(data);
      }

      return {
        'isInterleavedBufferAttribute': true,
        'itemSize': itemSize,
        'data': this.data.uuid,
        'offset': offset,
        'normalized': normalized,
      };
    }
  }

  /// Denormalizes the value using cached normalization factor.
  double _denormalize(double value) {
    final scale = _normalizationScale;

    return scale != null ? math.max(value / scale, -1.0) : MathUtils.denormalize(value, data.array);
  }

  /// Normalizes the value using cached normalization factor.
  double _normalize(double value) {
    final scale = _normalizationScale;

    return scale != null ? _jsRound(value * scale) : MathUtils.normalize(value, data.array);
  }
}
