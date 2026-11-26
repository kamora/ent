part of '../../ent.dart';

final _bufferAttributeVector = Vector3();
final _bufferAttributeVector2 = Vector2();

int _bufferAttributeId = 0;

/// What [BufferAttribute] and [InterleavedBufferAttribute] share. The reference duck-types them: geometries hold either
/// in `attributes`, and `fromBufferAttribute()` reads either. Dart needs the common type spelled out; the members are
/// the ones the reference code calls on both (exception E-DUCK).
abstract interface class BufferAttributeLike {
  /// The name of the attribute.
  abstract String name;

  /// The array holding the attribute data (a `dart:typed_data` list).
  List<num> get array;

  /// The number of values of the array that belong to one vertex.
  int get itemSize;

  /// The number of items the attribute stores.
  int get count;

  /// Whether integer data maps to `[0, 1]` / `[-1, 1]` in shaders.
  abstract bool normalized;

  /// Marks the data as changed; it is sent to the GPU again.
  set needsUpdate(bool value);

  /// Whether this is a plain [BufferAttribute].
  bool get isBufferAttribute;

  /// Whether this is an [InterleavedBufferAttribute].
  bool get isInterleavedBufferAttribute;

  /// The [component] of the vector at [index].
  double getComponent(int index, int component);

  /// Sets the [component] of the vector at [index] to [value].
  BufferAttributeLike setComponent(int index, int component, double value);

  /// The x component of the vector at [index].
  double getX(int index);

  /// The y component of the vector at [index].
  double getY(int index);

  /// The z component of the vector at [index].
  double getZ(int index);

  /// The w component of the vector at [index].
  double getW(int index);

  /// Sets the x component of the vector at [index].
  BufferAttributeLike setX(int index, double x);

  /// Sets the y component of the vector at [index].
  BufferAttributeLike setY(int index, double y);

  /// Sets the z component of the vector at [index].
  BufferAttributeLike setZ(int index, double z);

  /// Sets the w component of the vector at [index].
  BufferAttributeLike setW(int index, double w);

  /// Sets the x and y components of the vector at [index].
  BufferAttributeLike setXY(int index, double x, double y);

  /// Sets the x, y and z components of the vector at [index].
  BufferAttributeLike setXYZ(int index, double x, double y, double z);

  /// Sets the x, y, z and w components of the vector at [index].
  BufferAttributeLike setXYZW(int index, double x, double y, double z, double w);

  /// Multiplies every vector, as a point, by [m].
  BufferAttributeLike applyMatrix4(Matrix4 m);

  /// Multiplies every vector by the normal matrix [m].
  BufferAttributeLike applyNormalMatrix(Matrix3 m);

  /// Transforms every vector as a direction by [m] and normalizes it.
  BufferAttributeLike transformDirection(Matrix4 m);

  /// The reference calls `attribute.clone( data )` on both kinds; a plain attribute ignores `data`.
  BufferAttributeLike clone([Map<String, Object?>? data]);

  /// The reference calls `attribute.toJSON( data )` on both kinds; a plain attribute ignores `data`.
  Map<String, Object?> toJSON([Map<String, Object?>? data]);
}

/// A range of the data array to upload, as added by `addUpdateRange( start, count )`. The reference pushes
/// `{ start, count }` object literals; renderers read the two fields (exception E-OBJECT).
class UpdateRange {
  /// Constructs a new range of [count] values from [start].
  UpdateRange(this.start, this.count);

  /// The index of the first value to upload.
  int start;

  /// How many values to upload.
  int count;
}

/// The constructor name of a typed list, as `array.constructor.name` reports it in the reference.
String _typedArrayName(List<num> array) {
  return switch (array) {
    Float32List() => 'Float32Array',
    Float64List() => 'Float64Array',
    Int8List() => 'Int8Array',
    Uint8ClampedList() => 'Uint8ClampedArray',
    Uint8List() => 'Uint8Array',
    Int16List() => 'Int16Array',
    Uint16List() => 'Uint16Array',
    Int32List() => 'Int32Array',
    Uint32List() => 'Uint32Array',
    _ => 'Array',
  };
}

/// `new array.constructor( source )`: a new typed list of the same kind holding `source`'s values.
List<num> _typedArrayLike(List<num> array, List<num> source) {
  final copy = _typedArrayOfLength(array, source.length);

  for (var i = 0; i < source.length; i++) {
    _typedArraySet(copy, i, source[i]);
  }

  return copy;
}

/// `new array.constructor( length )`.
List<num> _typedArrayOfLength(List<num> array, int length) {
  return switch (array) {
    Float32List() => Float32List(length),
    Float64List() => Float64List(length),
    Int8List() => Int8List(length),
    Uint8ClampedList() => Uint8ClampedList(length),
    Uint8List() => Uint8List(length),
    Int16List() => Int16List(length),
    Uint16List() => Uint16List(length),
    Int32List() => Int32List(length),
    Uint32List() => Uint32List(length),
    List<double>() => List<double>.filled(length, 0.0, growable: true),
    _ => List<num>.filled(length, 0, growable: true),
  };
}

/// `array[ index ]` with JS typed-array read semantics in numeric use: an index out of range reads `undefined` in the
/// reference, which arithmetic turns into NaN (exception E-ARRAY).
double _typedArrayGet(List<num> array, int index) {
  if (index < 0 || index >= array.length) {
    return double.nan;
  }

  return array[index].toDouble();
}

/// `ToInt32( array[ index ] )`: an index out of range reads `undefined`, which is `0` in bit operations.
int _typedArrayGetInt(List<num> array, int index) {
  if (index < 0 || index >= array.length) {
    return 0;
  }

  return array[index].toInt();
}

/// `array[ index ] = value` with JS typed-array store semantics: an index out of range is ignored; float
/// lists store the double (rounded to float32 by a Float32List); integer lists store `ToInt32( value )`
/// wrapped to their width, NaN and ±∞ as 0; a Uint8ClampedList clamps to [0, 255] and rounds half to even.
void _typedArraySet(List<num> array, int index, num value) {
  if (index < 0 || index >= array.length) {
    return;
  } else if (array is List<double>) {
    array[index] = value.toDouble();
  } else if (array is Uint8ClampedList) {
    array[index] = _typedArrayClamp(value.toDouble());
  } else if (array is Uint32List) {
    array[index] = _jsToUint32(value);
  } else {
    (array as List<int>)[index] = _jsToInt32(value);
  }
}

/// `ToUint8Clamp( value )`.
int _typedArrayClamp(double value) {
  if (value.isNaN || value <= 0) {
    return 0;
  }

  if (value >= 255) {
    return 255;
  }

  final floor = value.floorToDouble();
  final rest = value - floor;

  if (rest < 0.5) {
    return floor.toInt();
  }

  if (rest > 0.5) {
    return floor.toInt() + 1;
  }

  return floor.toInt().isEven ? floor.toInt() : floor.toInt() + 1;
}

/// A typed list of the given kind built from a number (its length) or from a list of values, as
/// `new Float32Array( array )` accepts both.
List<num> _typedArrayFrom(List<num> kind, Object array) {
  if (array is int) {
    return _typedArrayOfLength(kind, array);
  }

  return _typedArrayLike(kind, array as List<num>);
}

/// The constructor's array check: `Array.isArray( array )` throws in the reference, `undefined` stays empty.
List<num> _bufferAttributeArray(List<num>? array) {
  if (array == null) {
    return Float32List(0);
  }

  if (array is! TypedData) {
    throw EntError('ENT.BufferAttribute: array should be a Typed Array.');
  }

  return array;
}

/// This class stores data for an attribute (such as vertex positions, face indices, normals, colors, UVs,
/// and any custom attributes ) associated with a geometry, which allows for more efficient passing of data
/// to the GPU.
///
/// When working with vector-like data, the `fromBufferAttribute( attribute, index )` helper methods on
/// vector and color class might be helpful. E.g. [Vector3.fromBufferAttribute].
class BufferAttribute extends EventDispatcher implements BufferAttributeLike {
  /// Constructs a new buffer attribute. [array] must be a `dart:typed_data` list; [itemSize] is the number of values
  /// per vertex. Without an array (`undefined` in the reference) the attribute holds an empty Float32List, an item size
  /// of `0` and a count of `0`, ready for [copy]. A missing or zero item size gives a count of `0` (in the reference:
  /// NaN or Infinity).
  BufferAttribute([List<num>? array, int? itemSize, this.normalized = false])
    : id = _bufferAttributeId++,
      array = _bufferAttributeArray(array),
      itemSize = itemSize ?? 0,
      count = _count(array, itemSize),
      _normalizationScale = array == null ? null : MathUtils.getNormalizationScale(array);

  // The vertex count: 0 without an array or an item size.
  static int _count(List<num>? array, int? itemSize) {
    if (array == null) {
      return 0;
    }

    if (itemSize == null || itemSize == 0) {
      return 0;
    }

    return array.length ~/ itemSize;
  }

  /// This flag can be used for type testing.
  @override
  bool get isBufferAttribute => true;

  @override
  bool get isInterleavedBufferAttribute => false;

  /// The ID of the buffer attribute.
  final int id;

  /// The name of the buffer attribute.
  @override
  String name = '';

  /// The array holding the attribute data. It should have `itemSize * numVertices` elements, where
  /// `numVertices` is the number of vertices in the associated geometry.
  @override
  List<num> array;

  /// The number of values of the array that should be associated with a particular vertex. For instance,
  /// if this attribute is storing a 3-component vector (such as a position, normal, or color), then the
  /// value should be `3`.
  @override
  int itemSize;

  /// Represents the number of items this buffer attribute stores. It is internally computed by dividing
  /// the `array` length by the `itemSize`.
  @override
  int count;

  /// Applies to integer data only. Indicates how the underlying data in the buffer maps to the values in
  /// the GLSL code. For instance, if `array` is an instance of `UInt16Array`, and `normalized` is `true`,
  /// the values `0 - +65535` in the array data will be mapped to `0.0f - +1.0f` in the GLSL attribute. If
  /// `normalized` is `false`, the values will be converted to floats unmodified, i.e. `65535` becomes
  /// `65535.0f`.
  @override
  bool normalized;

  /// Defines the intended usage pattern of the data store for optimization purposes.
  ///
  /// Note: After the initial use of a buffer, its usage cannot be changed. Instead, instantiate a new one
  /// and set the desired usage before the next render.
  int usage = StaticDrawUsage;

  /// This can be used to only update some components of stored vectors (for example, just the component
  /// related to color). Use the `addUpdateRange()` function to add ranges to this array.
  final List<UpdateRange> updateRanges = [];

  /// Configures the bound GPU type for use in shaders.
  ///
  /// Note: this only has an effect for integer arrays and is not configurable for float arrays. For lower
  /// precision float types, use `Float16BufferAttribute`.
  int gpuType = FloatType;

  /// A version number, incremented every time the `needsUpdate` is set to `true`.
  int version = 0;

  /// Cached normalization factor, see [MathUtils.getNormalizationScale].
  double? _normalizationScale;

  /// A callback function that is executed after the renderer has transferred the attribute array data to
  /// the GPU.
  void Function() onUploadCallback = () {};

  /// Flag to indicate that this attribute has changed and should be re-sent to the GPU. Set this to `true`
  /// when you modify the value of the array.
  @override
  set needsUpdate(bool value) {
    if (value == true) {
      version++;
    }
  }

  /// Sets the usage of this buffer attribute.
  BufferAttribute setUsage(int value) {
    usage = value;

    return this;
  }

  /// Adds a range of data in the data array to be updated on the GPU.
  void addUpdateRange(int start, int count) {
    updateRanges.add(UpdateRange(start, count));
  }

  /// Clears the update ranges.
  void clearUpdateRanges() {
    updateRanges.clear();
  }

  /// Copies the values of the given buffer attribute to this instance.
  BufferAttribute copy(BufferAttribute source) {
    name = source.name;
    array = _typedArrayLike(source.array, source.array);
    itemSize = source.itemSize;
    count = source.count;
    normalized = source.normalized;

    usage = source.usage;
    gpuType = source.gpuType;

    _normalizationScale = source._normalizationScale;

    return this;
  }

  /// Copies a vector from the given buffer attribute to this one. The start and destination position in
  /// the attribute buffers are represented by the given indices.
  BufferAttribute copyAt(int index1, BufferAttribute attribute, int index2) {
    index1 *= itemSize;
    index2 *= attribute.itemSize;

    for (var i = 0, l = itemSize; i < l; i++) {
      _typedArraySet(array, index1 + i, _typedArrayGet(attribute.array, index2 + i));
    }

    return this;
  }

  /// Copies the given array data into this buffer attribute.
  BufferAttribute copyArray(List<num> array) {
    return set(array);
  }

  /// Applies the given 3x3 matrix to the given attribute. Works with item size `2` and `3`.
  BufferAttribute applyMatrix3(Matrix3 m) {
    if (itemSize == 2) {
      for (var i = 0, l = count; i < l; i++) {
        _bufferAttributeVector2.fromBufferAttribute(this, i);
        _bufferAttributeVector2.applyMatrix3(m);

        setXY(i, _bufferAttributeVector2.x, _bufferAttributeVector2.y);
      }
    } else if (itemSize == 3) {
      for (var i = 0, l = count; i < l; i++) {
        _bufferAttributeVector.fromBufferAttribute(this, i);
        _bufferAttributeVector.applyMatrix3(m);

        setXYZ(i, _bufferAttributeVector.x, _bufferAttributeVector.y, _bufferAttributeVector.z);
      }
    }

    return this;
  }

  /// Applies the given 4x4 matrix to the given attribute. Only works with item size `3`.
  @override
  BufferAttribute applyMatrix4(Matrix4 m) {
    for (var i = 0, l = count; i < l; i++) {
      _bufferAttributeVector.fromBufferAttribute(this, i);

      _bufferAttributeVector.applyMatrix4(m);

      setXYZ(i, _bufferAttributeVector.x, _bufferAttributeVector.y, _bufferAttributeVector.z);
    }

    return this;
  }

  /// Applies the given 3x3 normal matrix to the given attribute. Only works with item size `3`.
  @override
  BufferAttribute applyNormalMatrix(Matrix3 m) {
    for (var i = 0, l = count; i < l; i++) {
      _bufferAttributeVector.fromBufferAttribute(this, i);

      _bufferAttributeVector.applyNormalMatrix(m);

      setXYZ(i, _bufferAttributeVector.x, _bufferAttributeVector.y, _bufferAttributeVector.z);
    }

    return this;
  }

  /// Applies the given 4x4 matrix to the given attribute. Only works with item size `3` and with direction
  /// vectors.
  @override
  BufferAttribute transformDirection(Matrix4 m) {
    for (var i = 0, l = count; i < l; i++) {
      _bufferAttributeVector.fromBufferAttribute(this, i);

      _bufferAttributeVector.transformDirection(m);

      setXYZ(i, _bufferAttributeVector.x, _bufferAttributeVector.y, _bufferAttributeVector.z);
    }

    return this;
  }

  /// Sets the given array data in the buffer attribute, starting at [offset] (default `0`). Like
  /// `TypedArray.set()`, data that does not fit throws a `RangeError` and values are not normalized.
  BufferAttribute set(List<num> value, [int offset = 0]) {
    // Matching BufferAttribute constructor, do not normalize the array.

    if (offset < 0 || offset + value.length > array.length) {
      throw RangeError('offset is out of bounds');
    }

    for (var i = 0; i < value.length; i++) {
      _typedArraySet(array, offset + i, value[i]);
    }

    return this;
  }

  /// Returns the given component of the vector at the given index.
  @override
  double getComponent(int index, int component) {
    var value = _typedArrayGet(array, index * itemSize + component);

    if (normalized) {
      value = _denormalize(value);
    }

    return value;
  }

  /// Sets the given value to the given component of the vector at the given index.
  @override
  BufferAttribute setComponent(int index, int component, double value) {
    if (normalized) {
      value = _normalize(value);
    }

    _typedArraySet(array, index * itemSize + component, value);

    return this;
  }

  /// Returns the x component of the vector at the given index.
  @override
  double getX(int index) {
    var x = _typedArrayGet(array, index * itemSize);

    if (normalized) {
      x = _denormalize(x);
    }

    return x;
  }

  /// Sets the x component of the vector at the given index.
  @override
  BufferAttribute setX(int index, double x) {
    if (normalized) {
      x = _normalize(x);
    }

    _typedArraySet(array, index * itemSize, x);

    return this;
  }

  /// Returns the y component of the vector at the given index.
  @override
  double getY(int index) {
    var y = _typedArrayGet(array, index * itemSize + 1);

    if (normalized) {
      y = _denormalize(y);
    }

    return y;
  }

  /// Sets the y component of the vector at the given index.
  @override
  BufferAttribute setY(int index, double y) {
    if (normalized) {
      y = _normalize(y);
    }

    _typedArraySet(array, index * itemSize + 1, y);

    return this;
  }

  /// Returns the z component of the vector at the given index.
  @override
  double getZ(int index) {
    var z = _typedArrayGet(array, index * itemSize + 2);

    if (normalized) {
      z = _denormalize(z);
    }

    return z;
  }

  /// Sets the z component of the vector at the given index.
  @override
  BufferAttribute setZ(int index, double z) {
    if (normalized) {
      z = _normalize(z);
    }

    _typedArraySet(array, index * itemSize + 2, z);

    return this;
  }

  /// Returns the w component of the vector at the given index.
  @override
  double getW(int index) {
    var w = _typedArrayGet(array, index * itemSize + 3);

    if (normalized) {
      w = _denormalize(w);
    }

    return w;
  }

  /// Sets the w component of the vector at the given index.
  @override
  BufferAttribute setW(int index, double w) {
    if (normalized) {
      w = _normalize(w);
    }

    _typedArraySet(array, index * itemSize + 3, w);

    return this;
  }

  /// Sets the x and y component of the vector at the given index.
  @override
  BufferAttribute setXY(int index, double x, double y) {
    index *= itemSize;

    if (normalized) {
      x = _normalize(x);
      y = _normalize(y);
    }

    _typedArraySet(array, index + 0, x);
    _typedArraySet(array, index + 1, y);

    return this;
  }

  /// Sets the x, y and z component of the vector at the given index.
  @override
  BufferAttribute setXYZ(int index, double x, double y, double z) {
    index *= itemSize;

    if (normalized) {
      x = _normalize(x);
      y = _normalize(y);
      z = _normalize(z);
    }

    _typedArraySet(array, index + 0, x);
    _typedArraySet(array, index + 1, y);
    _typedArraySet(array, index + 2, z);

    return this;
  }

  /// Sets the x, y, z and w component of the vector at the given index.
  @override
  BufferAttribute setXYZW(int index, double x, double y, double z, double w) {
    index *= itemSize;

    if (normalized) {
      x = _normalize(x);
      y = _normalize(y);
      z = _normalize(z);
      w = _normalize(w);
    }

    _typedArraySet(array, index + 0, x);
    _typedArraySet(array, index + 1, y);
    _typedArraySet(array, index + 2, z);
    _typedArraySet(array, index + 3, w);

    return this;
  }

  /// Sets the given callback function that is executed after the Renderer has transferred the attribute
  /// array data to the GPU. Can be used to perform clean-up operations after the upload when attribute data
  /// are not needed anymore on the CPU side.
  BufferAttribute onUpload(void Function() callback) {
    onUploadCallback = callback;

    return this;
  }

  /// Returns a new buffer attribute with copied values from this instance. [data] is ignored (the reference's
  /// geometries pass it to every attribute; only interleaved ones use it).
  @override
  BufferAttribute clone([Map<String, Object?>? data]) {
    return BufferAttribute(array, itemSize).copy(this);
  }

  /// Serializes the buffer attribute into JSON. [data] is ignored, as the reference ignores it.
  @override
  Map<String, Object?> toJSON([Map<String, Object?>? data]) {
    final json = <String, Object?>{
      'itemSize': itemSize,
      'type': _typedArrayName(array),
      'array': List<num>.of(array),
      'normalized': normalized,
    };

    json['name'] = name;
    json['usage'] = usage;
    json['gpuType'] = gpuType;

    return json;
  }

  /// Frees the GPU-related resources allocated by this instance. Available only in `WebGPURenderer`.
  void dispose() {
    dispatchEvent(Event('dispose'));
  }

  /// Denormalizes the value using cached normalization factor.
  double _denormalize(double value) {
    final scale = _normalizationScale;

    return scale != null ? math.max(value / scale, -1.0) : MathUtils.denormalize(value, array);
  }

  /// Normalizes the value using cached normalization factor.
  double _normalize(double value) {
    final scale = _normalizationScale;

    return scale != null ? _jsRound(value * scale) : MathUtils.normalize(value, array);
  }
}

/// Convenient class that can be used when creating a `Int8` buffer attribute with a plain `Array` instance.
class Int8BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Int8BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Int8List(0) : _typedArrayFrom(Int8List(0), array), itemSize, normalized);

  @override
  Int8BufferAttribute clone([Map<String, Object?>? data]) {
    return Int8BufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `UInt8` buffer attribute with a plain `Array` instance.
class Uint8BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Uint8BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Uint8List(0) : _typedArrayFrom(Uint8List(0), array), itemSize, normalized);

  @override
  Uint8BufferAttribute clone([Map<String, Object?>? data]) {
    return Uint8BufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `UInt8Clamped` buffer attribute with a plain `Array`
/// instance.
class Uint8ClampedBufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Uint8ClampedBufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Uint8ClampedList(0) : _typedArrayFrom(Uint8ClampedList(0), array), itemSize, normalized);

  @override
  Uint8ClampedBufferAttribute clone([Map<String, Object?>? data]) {
    return Uint8ClampedBufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `Int16` buffer attribute with a plain `Array` instance.
class Int16BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Int16BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Int16List(0) : _typedArrayFrom(Int16List(0), array), itemSize, normalized);

  @override
  Int16BufferAttribute clone([Map<String, Object?>? data]) {
    return Int16BufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `UInt16` buffer attribute with a plain `Array` instance.
class Uint16BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Uint16BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Uint16List(0) : _typedArrayFrom(Uint16List(0), array), itemSize, normalized);

  @override
  Uint16BufferAttribute clone([Map<String, Object?>? data]) {
    return Uint16BufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `Int32` buffer attribute with a plain `Array` instance.
class Int32BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Int32BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Int32List(0) : _typedArrayFrom(Int32List(0), array), itemSize, normalized);

  @override
  Int32BufferAttribute clone([Map<String, Object?>? data]) {
    return Int32BufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `UInt32` buffer attribute with a plain `Array` instance.
class Uint32BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Uint32BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Uint32List(0) : _typedArrayFrom(Uint32List(0), array), itemSize, normalized);

  @override
  Uint32BufferAttribute clone([Map<String, Object?>? data]) {
    return Uint32BufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `Float16` buffer attribute with a plain `Array`
/// instance.
///
/// This class automatically converts to and from FP16 via `Uint16Array` since `Float16Array` browser support
/// is still problematic.
class Float16BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of (already half-float encoded) values or a length (none:
  /// an empty array).
  Float16BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Uint16List(0) : _typedArrayFrom(Uint16List(0), array), itemSize, normalized);

  /// This flag can be used for type testing.
  bool get isFloat16BufferAttribute => true;

  @override
  double getX(int index) {
    var x = DataUtils.fromHalfFloat(_typedArrayGetInt(array, index * itemSize));

    if (normalized) {
      x = MathUtils.denormalize(x, array);
    }

    return x;
  }

  @override
  Float16BufferAttribute setX(int index, double x) {
    if (normalized) {
      x = MathUtils.normalize(x, array);
    }

    _typedArraySet(array, index * itemSize, DataUtils.toHalfFloat(x));

    return this;
  }

  @override
  double getY(int index) {
    var y = DataUtils.fromHalfFloat(_typedArrayGetInt(array, index * itemSize + 1));

    if (normalized) {
      y = MathUtils.denormalize(y, array);
    }

    return y;
  }

  @override
  Float16BufferAttribute setY(int index, double y) {
    if (normalized) {
      y = MathUtils.normalize(y, array);
    }

    _typedArraySet(array, index * itemSize + 1, DataUtils.toHalfFloat(y));

    return this;
  }

  @override
  double getZ(int index) {
    var z = DataUtils.fromHalfFloat(_typedArrayGetInt(array, index * itemSize + 2));

    if (normalized) {
      z = MathUtils.denormalize(z, array);
    }

    return z;
  }

  @override
  Float16BufferAttribute setZ(int index, double z) {
    if (normalized) {
      z = MathUtils.normalize(z, array);
    }

    _typedArraySet(array, index * itemSize + 2, DataUtils.toHalfFloat(z));

    return this;
  }

  @override
  double getW(int index) {
    var w = DataUtils.fromHalfFloat(_typedArrayGetInt(array, index * itemSize + 3));

    if (normalized) {
      w = MathUtils.denormalize(w, array);
    }

    return w;
  }

  @override
  Float16BufferAttribute setW(int index, double w) {
    if (normalized) {
      w = MathUtils.normalize(w, array);
    }

    _typedArraySet(array, index * itemSize + 3, DataUtils.toHalfFloat(w));

    return this;
  }

  @override
  Float16BufferAttribute setXY(int index, double x, double y) {
    index *= itemSize;

    if (normalized) {
      x = MathUtils.normalize(x, array);
      y = MathUtils.normalize(y, array);
    }

    _typedArraySet(array, index + 0, DataUtils.toHalfFloat(x));
    _typedArraySet(array, index + 1, DataUtils.toHalfFloat(y));

    return this;
  }

  @override
  Float16BufferAttribute setXYZ(int index, double x, double y, double z) {
    index *= itemSize;

    if (normalized) {
      x = MathUtils.normalize(x, array);
      y = MathUtils.normalize(y, array);
      z = MathUtils.normalize(z, array);
    }

    _typedArraySet(array, index + 0, DataUtils.toHalfFloat(x));
    _typedArraySet(array, index + 1, DataUtils.toHalfFloat(y));
    _typedArraySet(array, index + 2, DataUtils.toHalfFloat(z));

    return this;
  }

  @override
  Float16BufferAttribute setXYZW(int index, double x, double y, double z, double w) {
    index *= itemSize;

    if (normalized) {
      x = MathUtils.normalize(x, array);
      y = MathUtils.normalize(y, array);
      z = MathUtils.normalize(z, array);
      w = MathUtils.normalize(w, array);
    }

    _typedArraySet(array, index + 0, DataUtils.toHalfFloat(x));
    _typedArraySet(array, index + 1, DataUtils.toHalfFloat(y));
    _typedArraySet(array, index + 2, DataUtils.toHalfFloat(z));
    _typedArraySet(array, index + 3, DataUtils.toHalfFloat(w));

    return this;
  }

  @override
  Float16BufferAttribute clone([Map<String, Object?>? data]) {
    return Float16BufferAttribute(array, itemSize)..copy(this);
  }
}

/// Convenient class that can be used when creating a `Float32` buffer attribute with a plain `Array`
/// instance.
class Float32BufferAttribute extends BufferAttribute {
  /// Constructs a new buffer attribute from a list of values or a length (none: an empty array).
  Float32BufferAttribute([Object? array, int? itemSize, bool normalized = false])
    : super(array == null ? Float32List(0) : _typedArrayFrom(Float32List(0), array), itemSize, normalized);

  @override
  Float32BufferAttribute clone([Map<String, Object?>? data]) {
    return Float32BufferAttribute(array, itemSize)..copy(this);
  }
}
