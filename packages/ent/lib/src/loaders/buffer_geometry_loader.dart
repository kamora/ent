part of '../../ent.dart';

/// A JSON object as the loaders receive it: from `jsonDecode` or straight from a `toJSON()`.
Map<String, Object?> _loaderMap(Object? value) => (value! as Map).cast<String, Object?>();

/// A number from loader JSON as a `double`.
double _loaderDouble(Object? value) => (value! as num).toDouble();

/// A number from loader JSON as an `int`.
int _loaderInt(Object? value) => (value! as num).toInt();

/// A typed-array source from loader JSON: a `ByteBuffer`, or a list of numbers (`jsonDecode` gives
/// `List<dynamic>`) as the `List<num>` [getTypedArray] takes.
Object _loaderArray(Object? value) => value is List ? value.cast<num>() : value!;

/// A number list from loader JSON as `double`s.
List<double> _loaderDoubles(Object? value) => [for (final v in value! as List) (v as num).toDouble()];

/// Class for loading geometries. The files are internally loaded via [FileLoader].
class BufferGeometryLoader extends Loader<BufferGeometry> {
  /// Constructs a new geometry loader.
  BufferGeometryLoader([super.manager]);

  /// Starts loading from the given URL and pass the loaded geometry to the [onLoad] callback.
  @override
  void load(
    covariant String url, [
    void Function(BufferGeometry geometry)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setPath(path)
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    loader.load(
      url,
      (text) {
        try {
          onLoad!(parse(_loaderMap(jsonDecode(text! as String))));
        } catch (e) {
          if (onError != null) {
            onError(e);
          } else {
            error(e);
          }

          manager.itemError(url);
        }
      },
      onProgress,
      onError,
    );
  }

  /// Parses the given JSON object and returns a geometry.
  @override
  BufferGeometry parse(covariant Map<String, Object?> json) {
    final interleavedBufferMap = <String, InterleavedBuffer>{};
    final arrayBufferMap = <String, ByteBuffer>{};

    ByteBuffer getArrayBuffer(Map<String, Object?> json, String uuid) {
      final cached = arrayBufferMap[uuid];

      if (cached != null) {
        return cached;
      }

      final arrayBuffers = _loaderMap(json['arrayBuffers']);
      final arrayBuffer = arrayBuffers[uuid]! as List;

      final ab = Uint32List.fromList([for (final v in arrayBuffer) (v as num).toInt()]).buffer;

      arrayBufferMap[uuid] = ab;

      return ab;
    }

    InterleavedBuffer getInterleavedBuffer(Map<String, Object?> json, String uuid) {
      final cached = interleavedBufferMap[uuid];

      if (cached != null) {
        return cached;
      }

      final interleavedBuffers = _loaderMap(json['interleavedBuffers']);
      final interleavedBuffer = _loaderMap(interleavedBuffers[uuid]);

      final buffer = getArrayBuffer(json, interleavedBuffer['buffer']! as String);

      final array = getTypedArray(interleavedBuffer['type']! as String, buffer);
      final ib = InterleavedBuffer(array, _loaderInt(interleavedBuffer['stride']));
      ib.uuid = interleavedBuffer['uuid']! as String;

      if (interleavedBuffer['usage'] != null) {
        ib.setUsage(_loaderInt(interleavedBuffer['usage']));
      }

      interleavedBufferMap[uuid] = ib;

      return ib;
    }

    BufferAttributeLike attributeOf(Map<String, Object?> attribute, Map<String, Object?> data, bool instanced) {
      BufferAttributeLike bufferAttribute;

      if (attribute['isInterleavedBufferAttribute'] == true) {
        final interleavedBuffer = getInterleavedBuffer(data, attribute['data']! as String);
        bufferAttribute = InterleavedBufferAttribute(
          interleavedBuffer,
          _loaderInt(attribute['itemSize']),
          _loaderInt(attribute['offset']),
          attribute['normalized'] as bool? ?? false,
        );
      } else {
        final typedArray = getTypedArray(attribute['type']! as String, _loaderArray(attribute['array']));
        final itemSize = _loaderInt(attribute['itemSize']);
        final normalized = attribute['normalized'] as bool? ?? false;

        bufferAttribute = instanced && attribute['isInstancedBufferAttribute'] == true
            ? InstancedBufferAttribute(typedArray, itemSize, normalized)
            : BufferAttribute(typedArray, itemSize, normalized);
      }

      if (attribute['name'] != null) {
        bufferAttribute.name = attribute['name']! as String;
      }

      // An InterleavedBufferAttribute has no usage or gpuType; the reference would fail on `setUsage` and add an unused
      // `gpuType` property.
      if (attribute['usage'] != null) {
        (bufferAttribute as BufferAttribute).setUsage(_loaderInt(attribute['usage']));
      }

      if (attribute['gpuType'] != null && bufferAttribute is BufferAttribute) {
        bufferAttribute.gpuType = _loaderInt(attribute['gpuType']);
      }

      return bufferAttribute;
    }

    final geometry = json['isInstancedBufferGeometry'] == true ? InstancedBufferGeometry() : BufferGeometry();
    final data = _loaderMap(json['data']);

    final index = data['index'];

    if (index != null) {
      final indexJson = _loaderMap(index);
      final typedArray = getTypedArray(indexJson['type']! as String, _loaderArray(indexJson['array']));
      geometry.setIndex(BufferAttribute(typedArray, 1));
    }

    final attributes = _loaderMap(data['attributes']);

    for (final key in attributes.keys) {
      geometry.setAttribute(key, attributeOf(_loaderMap(attributes[key]), data, true));
    }

    final morphAttributes = data['morphAttributes'];

    if (morphAttributes != null) {
      final morphMap = _loaderMap(morphAttributes);

      for (final key in morphMap.keys) {
        final attributeArray = morphMap[key]! as List;

        final array = <BufferAttributeLike>[];

        for (var i = 0, il = attributeArray.length; i < il; i++) {
          array.add(attributeOf(_loaderMap(attributeArray[i]), data, false));
        }

        geometry.morphAttributes[key] = array;
      }
    }

    final morphTargetsRelative = data['morphTargetsRelative'];

    if (morphTargetsRelative == true) {
      geometry.morphTargetsRelative = true;
    }

    final groups = data['groups'] ?? data['drawcalls'] ?? data['offsets'];

    if (groups != null) {
      final list = groups as List;

      for (var i = 0, n = list.length; i != n; ++i) {
        final group = _loaderMap(list[i]);

        // a missing materialIndex is `undefined` in the reference, which takes addGroup's default
        if (group['materialIndex'] == null) {
          geometry.addGroup(_loaderInt(group['start']), _loaderInt(group['count']));
        } else {
          geometry.addGroup(_loaderInt(group['start']), _loaderInt(group['count']), group['materialIndex']);
        }
      }
    }

    final boundingSphere = data['boundingSphere'];

    if (boundingSphere != null) {
      geometry.boundingSphere = Sphere().fromJSON(_loaderMap(boundingSphere));
    }

    final name = json['name'];

    if (name is String && name != '') {
      geometry.name = name;
    }

    final userData = json['userData'];

    if (userData != null) {
      geometry.userData = _loaderMap(userData);
    }

    return geometry;
  }
}
