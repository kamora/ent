part of '../../ent.dart';

/// "Interleaved" means that multiple attributes, possibly of different types, (e.g., position, normal, uv,
/// color) are packed into a single array buffer.
///
/// An introduction into interleaved arrays can be found here:
/// [Interleaved array basics](https://blog.tojicode.com/2011/05/interleaved-array-basics.html)
class InterleavedBuffer {
  /// Constructs a new interleaved buffer from a typed list and the number of values per vertex ([stride]). Without an
  /// array (`undefined` in the reference) it holds an empty Float32List, a stride and a count of `0`.
  InterleavedBuffer([List<num>? array, int? stride])
    : array = array ?? Float32List(0),
      stride = stride ?? 0,
      count = _count(array, stride);

  // The vertex count: 0 without an array or a stride.
  static int _count(List<num>? array, int? stride) {
    if (array == null) {
      return 0;
    }

    if (stride == null || stride == 0) {
      return 0;
    }

    return array.length ~/ stride;
  }

  /// This flag can be used for type testing.
  bool get isInterleavedBuffer => true;

  /// A typed array with a shared buffer storing attribute data.
  List<num> array;

  /// The number of typed-array elements per vertex.
  int stride;

  /// The total number of elements in the array
  int count;

  /// Defines the intended usage pattern of the data store for optimization purposes.
  ///
  /// Note: After the initial use of a buffer, its usage cannot be changed. Instead, instantiate a new one
  /// and set the desired usage before the next render.
  int usage = StaticDrawUsage;

  /// This can be used to only update some components of stored vectors (for example, just the component
  /// related to color). Use the `addUpdateRange()` function to add ranges to this array.
  final List<UpdateRange> updateRanges = [];

  /// A version number, incremented every time the `needsUpdate` is set to `true`.
  int version = 0;

  /// The UUID of the interleaved buffer.
  String uuid = MathUtils.generateUUID();

  /// A callback function that is executed after the renderer has transferred the attribute array data to
  /// the GPU.
  void Function() onUploadCallback = () {};

  /// Flag to indicate that this attribute has changed and should be re-sent to the GPU. Set this to `true`
  /// when you modify the value of the array.
  set needsUpdate(bool value) {
    if (value == true) {
      version++;
    }
  }

  /// Sets the usage of this interleaved buffer.
  InterleavedBuffer setUsage(int value) {
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

  /// Copies the values of the given interleaved buffer to this instance.
  InterleavedBuffer copy(InterleavedBuffer source) {
    array = _typedArrayLike(source.array, source.array);
    count = source.count;
    stride = source.stride;
    usage = source.usage;

    return this;
  }

  /// Copies a vector from the given interleaved buffer to this one. The start and destination position in
  /// the attribute buffers are represented by the given indices.
  InterleavedBuffer copyAt(int index1, InterleavedBuffer interleavedBuffer, int index2) {
    index1 *= stride;
    index2 *= interleavedBuffer.stride;

    for (var i = 0, l = stride; i < l; i++) {
      _typedArraySet(array, index1 + i, _typedArrayGet(interleavedBuffer.array, index2 + i));
    }

    return this;
  }

  /// Sets the given array data in the interleaved buffer, starting at [offset] (default `0`). Like
  /// `TypedArray.set()`, data that does not fit throws a `RangeError`.
  InterleavedBuffer set(List<num> value, [int offset = 0]) {
    if (offset < 0 || offset + value.length > array.length) {
      throw RangeError('offset is out of bounds');
    }

    for (var i = 0; i < value.length; i++) {
      _typedArraySet(array, offset + i, value[i]);
    }

    return this;
  }

  /// Returns a new interleaved buffer with copied values from this instance.
  ///
  /// [data] is an object (map) holding shared array buffers for cloning geometries with interleaved
  /// attributes: buffers that view the same data stay shared in the clones (under `data['arrayBuffers']`).
  InterleavedBuffer clone(Map<String, Object?> data) {
    final buffers = (data['arrayBuffers'] ??= <String, Object?>{}) as Map<String, Object?>;

    final key = _interleavedBufferArrayKey(array as TypedData);

    if (buffers[key] == null) {
      buffers[key] = (_typedArrayLike(array, array) as TypedData).buffer;
    }

    final source = buffers[key] as ByteBuffer;
    final ib = _cloneWith(_typedArrayView(array, source), stride);
    ib.setUsage(usage);

    return ib;
  }

  /// `new this.constructor( array, stride )`; subclasses override it to keep their type (E-CLONE).
  InterleavedBuffer _cloneWith(List<num> array, int stride) {
    return InterleavedBuffer(array, stride);
  }

  /// Sets the given callback function that is executed after the Renderer has transferred the array data
  /// to the GPU. Can be used to perform clean-up operations after the upload when data are not needed
  /// anymore on the CPU side.
  InterleavedBuffer onUpload(void Function() callback) {
    onUploadCallback = callback;

    return this;
  }

  /// Serializes the interleaved buffer into JSON. The array data are stored once per buffer view in
  /// `data['arrayBuffers']`, as a list of 32-bit words.
  Map<String, Object?> toJSON(Map<String, Object?> data) {
    final buffers = (data['arrayBuffers'] ??= <String, Object?>{}) as Map<String, Object?>;

    final key = _interleavedBufferArrayKey(array as TypedData);

    if (buffers[key] == null) {
      buffers[key] = List<int>.of(Uint32List.view((_typedArrayLike(array, array) as TypedData).buffer));
    }

    //

    final json = <String, Object?>{'uuid': uuid, 'buffer': key, 'type': _typedArrayName(array), 'stride': stride};

    json['usage'] = usage;

    return json;
  }
}

/// `new array.constructor( buffer )`: a typed list of the same kind viewing the whole buffer.
List<num> _typedArrayView(List<num> array, ByteBuffer buffer) {
  return switch (array) {
    Float32List() => Float32List.view(buffer),
    Float64List() => Float64List.view(buffer),
    Int8List() => Int8List.view(buffer),
    Uint8ClampedList() => Uint8ClampedList.view(buffer),
    Uint8List() => Uint8List.view(buffer),
    Int16List() => Int16List.view(buffer),
    Uint16List() => Uint16List.view(buffer),
    Int32List() => Int32List.view(buffer),
    Uint32List() => Uint32List.view(buffer),
    _ => throw EntError('ENT.InterleavedBuffer: array should be a Typed Array.'),
  };
}

/// UUIDs of array buffers, the `array.buffer._uuid` the reference attaches to the `ArrayBuffer` itself.
///
/// On the Dart VM `typedList.buffer` returns a new (equal) wrapper on every call, so an `Expando` on the buffer cannot
/// hold the UUID. Entries keep a weak reference to a view of the buffer and compare buffers with `==`; an entry
/// disappears with its last view, as the property disappears with the buffer in the reference.
final List<(WeakReference<TypedData>, String)> _interleavedBufferUuids = [];

String _interleavedBufferUuid(TypedData array) {
  final buffer = array.buffer;

  _interleavedBufferUuids.removeWhere((e) => e.$1.target == null);

  for (final (view, uuid) in _interleavedBufferUuids) {
    if (view.target?.buffer == buffer) {
      return uuid;
    }
  }

  // generate UUID for array buffer if necessary

  final uuid = MathUtils.generateUUID();
  _interleavedBufferUuids.add((WeakReference(array), uuid));

  return uuid;
}

/// Returns the key under which the data of the given typed array is shared when cloning or serializing.
/// Interleaved buffers can be views at different offsets into the same array buffer (e.g. the interleaved
/// accessors of a glTF buffer view), so only views over the same range share their data.
String _interleavedBufferArrayKey(TypedData array) {
  final uuid = _interleavedBufferUuid(array);

  if (array.offsetInBytes == 0 && array.lengthInBytes == array.buffer.lengthInBytes) {
    return uuid;
  }

  return '$uuid:${array.offsetInBytes}:${array.lengthInBytes}';
}
