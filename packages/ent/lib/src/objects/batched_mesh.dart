part of '../../ent.dart';

/// An entry of the render list a [BatchedMesh] sorts before drawing: the reference's `{ start, count, z, index }`
/// object (exception E-OBJECT). A custom sort ([BatchedMesh.setCustomSort]) receives a list of these.
class MultiDrawRenderItem {
  /// Constructs a new entry with the given draw range, depth and instance index.
  MultiDrawRenderItem(this.start, this.count, this.z, this.index);

  /// The start of the draw range: an index offset for indexed geometry, a vertex offset otherwise.
  int start;

  /// The number of indices (or vertices) to draw.
  int count;

  /// The depth of the instance along the camera's forward axis, used for sorting.
  double z;

  /// The instance id.
  int index;
}

/// A custom sort for [BatchedMesh]: sorts the render `list` in place for the given `camera`. The reference calls it
/// with `this` bound to the mesh; a Dart closure captures the mesh instead (exception E-EVENT).
typedef BatchedMeshSort = void Function(List<MultiDrawRenderItem> list, Camera camera);

/// The draw range of one geometry of a [BatchedMesh], as [BatchedMesh.getGeometryRangeAt] reports it:
/// the reference's plain object with the same field names (exception E-OBJECT).
class BatchedMeshGeometryRange {
  /// The geometry's first vertex in the batch.
  int vertexStart = -1;

  /// The geometry's vertex count.
  int vertexCount = -1;

  /// The vertices reserved for the geometry.
  int reservedVertexCount = -1;

  /// The geometry's first index in the batch, or -1 without an index.
  int indexStart = -1;

  /// The geometry's index count, or -1 without an index.
  int indexCount = -1;

  /// The indices reserved for the geometry, or -1 without an index.
  int reservedIndexCount = -1;

  /// The first element drawn: [indexStart] with an index, else [vertexStart].
  int start = -1;

  /// The elements drawn: [indexCount] with an index, else [vertexCount].
  int count = -1;
}

/// The bookkeeping of one geometry of a [BatchedMesh] (in the reference: a plain object).
class _BatchedMeshGeometryInfo extends BatchedMeshGeometryRange {
  Box3? boundingBox;

  Sphere? boundingSphere;

  bool active = true;

  _BatchedMeshGeometryInfo copy() {
    return _BatchedMeshGeometryInfo()
      ..vertexStart = vertexStart
      ..vertexCount = vertexCount
      ..reservedVertexCount = reservedVertexCount
      ..indexStart = indexStart
      ..indexCount = indexCount
      ..reservedIndexCount = reservedIndexCount
      ..start = start
      ..count = count
      ..boundingBox = boundingBox?.clone()
      ..boundingSphere = boundingSphere?.clone()
      ..active = active;
  }

  /// The serialized form, keys in the reference's order. A missing bounding volume is `undefined` in the reference,
  /// which JSON drops, so its key is left out.
  Map<String, Object?> toJSON() {
    return {
      'vertexStart': vertexStart,
      'vertexCount': vertexCount,
      'reservedVertexCount': reservedVertexCount,
      'indexStart': indexStart,
      'indexCount': indexCount,
      'reservedIndexCount': reservedIndexCount,
      'start': start,
      'count': count,
      'boundingBox': ?boundingBox?.toJSON(),
      'boundingSphere': ?boundingSphere?.toJSON(),
      'active': active,
    };
  }
}

/// The state of one instance of a [BatchedMesh] (in the reference: a plain object).
class _BatchedMeshInstanceInfo {
  _BatchedMeshInstanceInfo(this.geometryIndex);

  bool visible = true;

  bool active = true;

  int geometryIndex;

  _BatchedMeshInstanceInfo copy() {
    return _BatchedMeshInstanceInfo(geometryIndex)
      ..visible = visible
      ..active = active;
  }

  Map<String, Object?> toJSON() {
    return {'visible': visible, 'active': active, 'geometryIndex': geometryIndex};
  }
}

class _MultiDrawRenderList {
  int index = 0;

  final List<MultiDrawRenderItem> pool = [];

  final List<MultiDrawRenderItem> list = [];

  void push(int start, int count, double z, int index) {
    final pool = this.pool;
    final list = this.list;

    if (this.index >= pool.length) {
      pool.add(MultiDrawRenderItem(-1, -1, -1, -1));
    }

    final item = pool[this.index];
    list.add(item);
    this.index++;

    item.start = start;
    item.count = count;
    item.z = z;
    item.index = index;
  }

  void reset() {
    list.length = 0;
    index = 0;
  }
}

int _batchedMeshAscIdSort(int a, int b) {
  return a - b;
}

double _batchedMeshSortOpaque(MultiDrawRenderItem a, MultiDrawRenderItem b) {
  return a.z - b.z;
}

double _batchedMeshSortTransparent(MultiDrawRenderItem a, MultiDrawRenderItem b) {
  return b.z - a.z;
}

/// `array.sort( compare )` with JS semantics: stable, and a NaN comparison counts as equal. Dart's
/// `List.sort` is not guaranteed to be stable.
void _batchedMeshStableSort<T>(List<T> list, num Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];

  indexed.sort((a, b) {
    final order = compare(a.$2, b.$2);

    if (order < 0) {
      return -1;
    }

    if (order > 0) {
      return 1;
    }

    return a.$1 - b.$1;
  });

  for (var i = 0; i < list.length; i++) {
    list[i] = indexed[i].$2;
  }
}

final _batchedMeshMatrix = Matrix4();
final _batchedMeshWhiteColor = Color(1, 1, 1);
final _batchedMeshFrustum = Frustum();
final _batchedMeshFrustumArray = FrustumArray();
final _batchedMeshBox = Box3();
final _batchedMeshSphere = Sphere();
final _batchedMeshVector = Vector3();
final _batchedMeshCameraPosition = Vector3();
final _batchedMeshForward = Vector3();
final _batchedMeshTemp = Vector3();
final _batchedMeshRenderList = _MultiDrawRenderList();
final _batchedMeshMesh = Mesh();
final List<Intersection> _batchedMeshBatchIntersects = [];

// copies data from attribute "src" into "target" starting at "targetOffset"
void _batchedMeshCopyAttributeData(BufferAttributeLike src, BufferAttributeLike target, [int targetOffset = 0]) {
  final itemSize = target.itemSize;

  if (src.isInterleavedBufferAttribute || _typedArrayName(src.array) != _typedArrayName(target.array)) {
    // use the component getters and setters if the array data cannot
    // be copied directly
    final vertexCount = src.count;

    for (var i = 0; i < vertexCount; i++) {
      for (var c = 0; c < itemSize; c++) {
        target.setComponent(i + targetOffset, c, src.getComponent(i, c));
      }
    }
  } else {
    // faster copy approach using typed array set function
    target.array.setAll(targetOffset * itemSize, src.array);
  }

  target.needsUpdate = true;
}

// safely copies array contents to a potentially smaller array
void _batchedMeshCopyArrayContents(List<num> src, List<num> target) {
  final len = math.min(src.length, target.length);

  if (_typedArrayName(src) != _typedArrayName(target)) {
    // if arrays are of a different type (eg due to index size increasing) then data must be per-element copied
    for (var i = 0; i < len; i++) {
      _typedArraySet(target, i, src[i]);
    }
  } else {
    // if the arrays use the same data layout we can use a fast block copy
    target.setRange(0, len, src);
  }
}

/// The typed data array of a data texture's image.
List<num> _batchedMeshTextureData(DataTexture texture) {
  return (texture.image as DataImage).data as List<num>;
}

/// `value === true` for a property that only some classes declare (the reference reads it duck-typed, and a missing
/// property is `undefined`): reads it dynamically, `false` when the object has no such member.
bool _batchedMeshIsTrue(Object? object, Object? Function(dynamic object) read) {
  try {
    return read(object) == true;
  } on NoSuchMethodError {
    return false;
  }
}

/// A special version of a mesh with multi draw batch rendering support. Use this class if you have to
/// render a large number of objects with the same material but with different geometries or world
/// transformations. The usage of `BatchedMesh` will help you to reduce the number of draw calls and thus
/// improve the overall rendering performance in your application.
///
/// ```dart
/// final box = BoxGeometry(1, 1, 1);
/// final sphere = SphereGeometry(1, 12, 12);
/// final material = MeshBasicMaterial({'color': 0x00ff00});
///
/// // initialize and add geometries into the batched mesh
/// final batchedMesh = BatchedMesh(10, 5000, 10000, material);
/// final boxGeometryId = batchedMesh.addGeometry(box);
/// final sphereGeometryId = batchedMesh.addGeometry(sphere);
///
/// // create instances of those geometries
/// final boxInstancedId1 = batchedMesh.addInstance(boxGeometryId);
/// final boxInstancedId2 = batchedMesh.addInstance(boxGeometryId);
///
/// final sphereInstancedId1 = batchedMesh.addInstance(sphereGeometryId);
/// final sphereInstancedId2 = batchedMesh.addInstance(sphereGeometryId);
///
/// // position the geometries
/// batchedMesh.setMatrixAt(boxInstancedId1, boxMatrix1);
/// batchedMesh.setMatrixAt(boxInstancedId2, boxMatrix2);
///
/// batchedMesh.setMatrixAt(sphereInstancedId1, sphereMatrix1);
/// batchedMesh.setMatrixAt(sphereInstancedId2, sphereMatrix2);
///
/// scene.add(batchedMesh);
/// ```
class BatchedMesh extends Mesh {
  /// Constructs a new batched mesh for at most `maxInstanceCount` instances, `maxVertexCount` vertices and
  /// `maxIndexCount` indices (default: twice `maxVertexCount`).
  BatchedMesh(int maxInstanceCount, int maxVertexCount, [int? maxIndexCount, Object? material])
    : _maxInstanceCount = maxInstanceCount,
      _maxVertexCount = maxVertexCount,
      _maxIndexCount = maxIndexCount ?? maxVertexCount * 2,
      _multiDrawCounts = Int32List(maxInstanceCount),
      _multiDrawStarts = Int32List(maxInstanceCount),
      _mergedDrawCounts = Int32List(maxInstanceCount),
      _mergedDrawStarts = Int32List(maxInstanceCount),
      _mergedDrawInstanceCounts = Int32List(maxInstanceCount),
      super(BufferGeometry(), material) {
    _initMatricesTexture();
    _initIndirectTexture();

    // The reference declares these as methods; Object3D holds them as replaceable callbacks (exception E-EVENT).
    onBeforeRender = (renderer, scene, camera, geometry, material, group) {
      if (_batchedMeshIsTrue(renderer, (r) => r.isWebGPURenderer)) {
        // WebGPU handles the draw parameters itself; only signal the change

        if (_visibilityChanged || perObjectFrustumCulled || sortObjects) {
          _indirectTexture!.needsUpdate = true;
        }
      } else {
        _updateDrawParameters(camera! as Camera, geometry! as BufferGeometry, material);
      }
    };

    onBeforeShadow = (renderer, object, camera, shadowCamera, geometry, depthMaterial, group) {
      if (!_batchedMeshIsTrue(renderer, (r) => r.isWebGPURenderer)) {
        _updateDrawParameters(shadowCamera! as Camera, geometry! as BufferGeometry, depthMaterial);
      }
    };
  }

  /// This flag can be used for type testing.
  bool get isBatchedMesh => true;

  /// When set to `true`, the individual objects of a batch are frustum culled.
  bool perObjectFrustumCulled = true;

  /// When set to `true`, the individual objects of a batch are sorted to improve overdraw-related artifacts.
  /// If the material is marked as "transparent" objects are rendered back to front and if not then they
  /// are rendered front to back.
  bool sortObjects = true;

  /// The bounding box of the batched mesh. Can be computed via [computeBoundingBox].
  Box3? boundingBox;

  /// The bounding sphere of the batched mesh. Can be computed via [computeBoundingSphere].
  Sphere? boundingSphere;

  /// Takes a sort function that is run before render. The function takes a list of items to sort and a
  /// camera. The objects in the list include a "z" field to perform a depth-ordered sort with.
  BatchedMeshSort? customSort;

  // stores visible, active, and geometry id per instance and reserved buffer ranges for geometries
  List<_BatchedMeshInstanceInfo> _instanceInfo = [];
  List<_BatchedMeshGeometryInfo> _geometryInfo = [];

  // instance, geometry ids that have been set as inactive, and are available to be overwritten
  List<int> _availableInstanceIds = [];
  List<int> _availableGeometryIds = [];

  // used to track where the next point is that geometry should be inserted
  int _nextIndexStart = 0;
  int _nextVertexStart = 0;
  int _geometryCount = 0;

  // flags
  bool _visibilityChanged = true;
  bool _geometryInitialized = false;

  // cached user options
  int _maxInstanceCount;
  int _maxVertexCount;
  int _maxIndexCount;

  // buffers for multi draw
  Int32List _multiDrawCounts;
  Int32List _multiDrawStarts;
  int _multiDrawCount = 0; // read by the renderers
  int _multiDrawBytesPerElement = 1;

  // buffers for instanced draws, consecutive draws with the same range are merged
  Int32List _mergedDrawCounts;
  Int32List _mergedDrawStarts;
  Int32List _mergedDrawInstanceCounts;
  // ignore: unused_field
  int _mergedDrawCount = 0; // read by the renderers

  // Local matrix per geometry by using data texture
  DataTexture? _matricesTexture;
  DataTexture? _indirectTexture;
  DataTexture? _colorsTexture;

  // previous frame matrices for motion vectors, created by the renderer
  DataTexture? _previousMatricesTexture;

  /// The maximum number of individual instances that can be stored in the batch.
  int get maxInstanceCount {
    return _maxInstanceCount;
  }

  /// The instance count.
  int get instanceCount {
    return _instanceInfo.length - _availableInstanceIds.length;
  }

  /// The number of unused vertices.
  int get unusedVertexCount {
    return _maxVertexCount - _nextVertexStart;
  }

  /// The number of unused indices.
  int get unusedIndexCount {
    return _maxIndexCount - _nextIndexStart;
  }

  /// The draw ranges' starts (in bytes for an indexed geometry, in vertices otherwise) of the last `onBeforeRender`,
  /// read by the renderers (the reference's `_multiDrawStarts`); the first [multiDrawCount] are set.
  Int32List get multiDrawStarts => _multiDrawStarts;

  /// For tests: the index buffer's bytes per element that the multi draw ranges are counted in.
  @visibleForTesting
  int get multiDrawBytesPerElement => _multiDrawBytesPerElement;

  /// For tests: the number of merged draws the last `'merged'` update produced.
  @visibleForTesting
  int get mergedDrawCount => _mergedDrawCount;

  /// For tests: updates the draw ranges for [camera] as a render does; [drawFormat] `'merged'` is the renderers' merged
  /// path, which onBeforeRender does not take.
  @visibleForTesting
  void updateDrawParameters(
    Camera camera,
    BufferGeometry geometry,
    Object? material, [
    String drawFormat = 'multiDraw',
  ]) {
    _updateDrawParameters(camera, geometry, material, drawFormat);
  }

  /// The draw ranges' index or vertex counts (the reference's `_multiDrawCounts`).
  Int32List get multiDrawCounts => _multiDrawCounts;

  /// How many draw ranges the last `onBeforeRender` set (the reference's `_multiDrawCount`).
  int get multiDrawCount => _multiDrawCount;

  /// The instance matrices, 4 RGBA float texels each (the reference's `_matricesTexture`).
  DataTexture get matricesTexture => _matricesTexture!;

  /// The instance of each draw range, in draw order (the reference's `_indirectTexture`).
  DataTexture get indirectTexture => _indirectTexture!;

  /// The instance colors, one RGBA float texel each, once [setColorAt] was called (the reference's `_colorsTexture`).
  DataTexture? get colorsTexture => _colorsTexture;

  void _initMatricesTexture() {
    // layout (1 matrix = 4 pixels)
    //      RGBA RGBA RGBA RGBA (=> column1, column2, column3, column4)
    //  with  8x8  pixel texture max   16 matrices * 4 pixels =  (8 * 8)
    //       16x16 pixel texture max   64 matrices * 4 pixels = (16 * 16)
    //       32x32 pixel texture max  256 matrices * 4 pixels = (32 * 32)
    //       64x64 pixel texture max 1024 matrices * 4 pixels = (64 * 64)

    var size = math.sqrt(_maxInstanceCount * 4); // 4 pixels needed for 1 matrix
    size = (size / 4).ceilToDouble() * 4;
    size = math.max(size, 4.0);

    final pixels = size.toInt();
    final matricesArray = Float32List(pixels * pixels * 4); // 4 floats per RGBA pixel
    final matricesTexture = DataTexture(matricesArray, pixels, pixels, RGBAFormat, FloatType);

    _matricesTexture = matricesTexture;
  }

  void _initIndirectTexture() {
    final size = math.sqrt(_maxInstanceCount).ceil();

    final indirectArray = Uint32List(size * size);
    final indirectTexture = DataTexture(indirectArray, size, size, RedIntegerFormat, UnsignedIntType);

    _indirectTexture = indirectTexture;
  }

  void _initColorsTexture() {
    final size = math.sqrt(_maxInstanceCount).ceil();

    // 4 floats per RGBA pixel initialized to white
    final colorsArray = Float32List(size * size * 4)..fillRange(0, size * size * 4, 1);
    final colorsTexture = DataTexture(colorsArray, size, size, RGBAFormat, FloatType);
    colorsTexture.colorSpace = ColorManagement.workingColorSpace;

    _colorsTexture = colorsTexture;
  }

  void _initializeGeometry(BufferGeometry reference) {
    final geometry = this.geometry;
    final maxVertexCount = _maxVertexCount;
    final maxIndexCount = _maxIndexCount;

    if (_geometryInitialized == false) {
      for (final attributeName in reference.attributes.keys) {
        final srcAttribute = reference.getAttribute(attributeName)!;
        final array = srcAttribute.array;
        final itemSize = srcAttribute.itemSize;
        final normalized = srcAttribute.normalized;

        final dstArray = _typedArrayOfLength(array, maxVertexCount * itemSize);
        final dstAttribute = BufferAttribute(dstArray, itemSize, normalized);

        geometry.setAttribute(attributeName, dstAttribute);
      }

      if (reference.getIndex() != null) {
        // Reserve last u16 index for primitive restart.
        final List<num> indexArray = maxVertexCount > 65535 ? Uint32List(maxIndexCount) : Uint16List(maxIndexCount);

        geometry.setIndex(BufferAttribute(indexArray, 1));
      }

      _geometryInitialized = true;
    }
  }

  // Make sure the geometry is compatible with the existing combined geometry attributes
  void _validateGeometry(BufferGeometry geometry) {
    // check to ensure the geometries are using consistent attributes and indices
    final batchGeometry = this.geometry;

    if ((geometry.getIndex() != null) != (batchGeometry.getIndex() != null)) {
      throw EntError('ENT.BatchedMesh: All geometries must consistently have "index".');
    }

    for (final attributeName in batchGeometry.attributes.keys) {
      if (!geometry.hasAttribute(attributeName)) {
        throw EntError(
          'ENT.BatchedMesh: Added geometry missing "$attributeName". All geometries must have consistent attributes.',
        );
      }

      final srcAttribute = geometry.getAttribute(attributeName)!;
      final dstAttribute = batchGeometry.getAttribute(attributeName)!;

      if (srcAttribute.itemSize != dstAttribute.itemSize || srcAttribute.normalized != dstAttribute.normalized) {
        throw EntError(
          'ENT.BatchedMesh: Added geometry attribute "$attributeName" has an inconsistent itemSize or normalized value.',
        );
      }
    }
  }

  /// Validates the instance defined by the given ID; throws if it is out of range or deleted.
  void validateInstanceId(int instanceId) {
    final instanceInfo = _instanceInfo;

    if (instanceId < 0 || instanceId >= instanceInfo.length || instanceInfo[instanceId].active == false) {
      throw EntError(
        'ENT.BatchedMesh: Invalid instanceId $instanceId. Instance is either out of range or has been deleted.',
      );
    }
  }

  /// Validates the geometry defined by the given ID; throws if it is out of range or deleted.
  void validateGeometryId(int geometryId) {
    final geometryInfoList = _geometryInfo;

    if (geometryId < 0 || geometryId >= geometryInfoList.length || geometryInfoList[geometryId].active == false) {
      throw EntError(
        'ENT.BatchedMesh: Invalid geometryId $geometryId. Geometry is either out of range or has been deleted.',
      );
    }
  }

  /// Takes a sort function that is run before render. The function takes a list of items to sort and a
  /// camera. The objects in the list include a "z" field to perform a depth-ordered sort with.
  BatchedMesh setCustomSort(BatchedMeshSort? func) {
    customSort = func;
    return this;
  }

  /// Computes the bounding box, updating [boundingBox]. Bounding boxes aren't computed by default. They
  /// need to be explicitly computed, otherwise they are `null`.
  void computeBoundingBox() {
    this.boundingBox ??= Box3();

    final boundingBox = this.boundingBox!;
    final instanceInfo = _instanceInfo;

    boundingBox.makeEmpty();

    for (var i = 0, l = instanceInfo.length; i < l; i++) {
      if (instanceInfo[i].active == false) {
        continue;
      }

      final geometryId = instanceInfo[i].geometryIndex;
      getMatrixAt(i, _batchedMeshMatrix);
      getBoundingBoxAt(geometryId, _batchedMeshBox)!.applyMatrix4(_batchedMeshMatrix);
      boundingBox.union(_batchedMeshBox);
    }
  }

  /// Computes the bounding sphere, updating [boundingSphere]. Bounding spheres aren't computed by default.
  /// They need to be explicitly computed, otherwise they are `null`.
  void computeBoundingSphere() {
    this.boundingSphere ??= Sphere();

    final boundingSphere = this.boundingSphere!;
    final instanceInfo = _instanceInfo;

    boundingSphere.makeEmpty();

    for (var i = 0, l = instanceInfo.length; i < l; i++) {
      if (instanceInfo[i].active == false) {
        continue;
      }

      final geometryId = instanceInfo[i].geometryIndex;
      getMatrixAt(i, _batchedMeshMatrix);
      getBoundingSphereAt(geometryId, _batchedMeshSphere)!.applyMatrix4(_batchedMeshMatrix);
      boundingSphere.union(_batchedMeshSphere);
    }
  }

  /// Adds a new instance to the batch using the geometry of the given ID and returns a new id referring to
  /// the new instance to be used by other functions.
  int addInstance(int geometryId) {
    final atCapacity = _instanceInfo.length >= maxInstanceCount;

    // ensure we're not over geometry
    if (atCapacity && _availableInstanceIds.isEmpty) {
      throw EntError('ENT.BatchedMesh: Maximum item count reached.');
    }

    final instanceInfo = _BatchedMeshInstanceInfo(geometryId);

    int drawId;

    // Prioritize using previously freed instance ids
    if (_availableInstanceIds.isNotEmpty) {
      _batchedMeshStableSort(_availableInstanceIds, _batchedMeshAscIdSort);

      drawId = _availableInstanceIds.removeAt(0);
      _instanceInfo[drawId] = instanceInfo;
    } else {
      drawId = _instanceInfo.length;
      _instanceInfo.add(instanceInfo);
    }

    final matricesTexture = _matricesTexture!;
    _batchedMeshMatrix.identity().toArray(_batchedMeshTextureData(matricesTexture) as List<double>, drawId * 16);
    matricesTexture.needsUpdate = true;

    final colorsTexture = _colorsTexture;

    if (colorsTexture != null) {
      _batchedMeshWhiteColor.toArray(_batchedMeshTextureData(colorsTexture) as List<double>, drawId * 4);
      colorsTexture.needsUpdate = true;
    }

    _visibilityChanged = true;
    return drawId;
  }

  /// Adds the given geometry to the batch and returns the associated geometry id referring to it to be used
  /// in other functions. `reservedVertexCount` and `reservedIndexCount` (default `-1`: the geometry's own
  /// counts) reserve room for a larger geometry set later with [setGeometryAt].
  int addGeometry(BufferGeometry geometry, [int reservedVertexCount = -1, int reservedIndexCount = -1]) {
    _initializeGeometry(geometry);

    _validateGeometry(geometry);

    final geometryInfo = _BatchedMeshGeometryInfo();

    final geometryInfoList = _geometryInfo;
    geometryInfo.vertexStart = _nextVertexStart;
    geometryInfo.reservedVertexCount = reservedVertexCount == -1
        ? geometry.getAttribute('position')!.count
        : reservedVertexCount;

    final index = geometry.getIndex();
    final hasIndex = index != null;

    if (hasIndex) {
      geometryInfo.indexStart = _nextIndexStart;
      geometryInfo.reservedIndexCount = reservedIndexCount == -1 ? index.count : reservedIndexCount;
    }

    if (geometryInfo.indexStart != -1 && geometryInfo.indexStart + geometryInfo.reservedIndexCount > _maxIndexCount ||
        geometryInfo.vertexStart + geometryInfo.reservedVertexCount > _maxVertexCount) {
      throw EntError('ENT.BatchedMesh: Reserved space request exceeds the maximum buffer size.');
    }

    // update id
    int geometryId;

    if (_availableGeometryIds.isNotEmpty) {
      _batchedMeshStableSort(_availableGeometryIds, _batchedMeshAscIdSort);

      geometryId = _availableGeometryIds.removeAt(0);
      geometryInfoList[geometryId] = geometryInfo;
    } else {
      geometryId = _geometryCount;
      _geometryCount++;
      geometryInfoList.add(geometryInfo);
    }

    // update the geometry
    setGeometryAt(geometryId, geometry);

    // increment the next geometry position
    _nextIndexStart = geometryInfo.indexStart + geometryInfo.reservedIndexCount;
    _nextVertexStart = geometryInfo.vertexStart + geometryInfo.reservedVertexCount;

    return geometryId;
  }

  /// Replaces the geometry at `geometryId` with the provided geometry. Throws an error if there is not
  /// enough space reserved for geometry. Calling this will change all instances that are rendering that
  /// geometry.
  int setGeometryAt(int geometryId, BufferGeometry geometry) {
    if (geometryId >= _geometryCount) {
      throw EntError('ENT.BatchedMesh: Maximum geometry count reached.');
    }

    _validateGeometry(geometry);

    final batchGeometry = this.geometry;
    final hasIndex = batchGeometry.getIndex() != null;
    final dstIndex = batchGeometry.getIndex();
    final srcIndex = geometry.getIndex();
    final geometryInfo = _geometryInfo[geometryId];

    if (hasIndex && srcIndex!.count > geometryInfo.reservedIndexCount ||
        geometry.attributes['position']!.count > geometryInfo.reservedVertexCount) {
      throw EntError('ENT.BatchedMesh: Reserved space not large enough for provided geometry.');
    }

    // copy geometry buffer data over
    final vertexStart = geometryInfo.vertexStart;
    final reservedVertexCount = geometryInfo.reservedVertexCount;
    geometryInfo.vertexCount = geometry.getAttribute('position')!.count;

    for (final attributeName in batchGeometry.attributes.keys) {
      // copy attribute data
      final srcAttribute = geometry.getAttribute(attributeName)!;
      final dstAttribute = batchGeometry.getAttribute(attributeName)! as BufferAttribute;
      _batchedMeshCopyAttributeData(srcAttribute, dstAttribute, vertexStart);

      // fill the rest in with zeroes
      final itemSize = srcAttribute.itemSize;

      for (var i = srcAttribute.count, l = reservedVertexCount; i < l; i++) {
        final index = vertexStart + i;

        for (var c = 0; c < itemSize; c++) {
          dstAttribute.setComponent(index, c, 0);
        }
      }

      dstAttribute.needsUpdate = true;
      dstAttribute.addUpdateRange(vertexStart * itemSize, reservedVertexCount * itemSize);
    }

    // copy index
    if (hasIndex) {
      final indexStart = geometryInfo.indexStart;
      final reservedIndexCount = geometryInfo.reservedIndexCount;
      geometryInfo.indexCount = geometry.getIndex()!.count;

      // copy index data over
      for (var i = 0; i < srcIndex!.count; i++) {
        dstIndex!.setX(indexStart + i, vertexStart + srcIndex.getX(i));
      }

      // fill the rest in with zeroes
      for (var i = srcIndex.count, l = reservedIndexCount; i < l; i++) {
        dstIndex!.setX(indexStart + i, vertexStart.toDouble());
      }

      dstIndex!.needsUpdate = true;
      dstIndex.addUpdateRange(indexStart, geometryInfo.reservedIndexCount);
    }

    // update the draw range
    geometryInfo.start = hasIndex ? geometryInfo.indexStart : geometryInfo.vertexStart;
    geometryInfo.count = hasIndex ? geometryInfo.indexCount : geometryInfo.vertexCount;

    // store the bounding boxes
    geometryInfo.boundingBox = null;

    if (geometry.boundingBox != null) {
      geometryInfo.boundingBox = geometry.boundingBox!.clone();
    }

    geometryInfo.boundingSphere = null;

    if (geometry.boundingSphere != null) {
      geometryInfo.boundingSphere = geometry.boundingSphere!.clone();
    }

    _visibilityChanged = true;
    return geometryId;
  }

  /// Deletes the geometry defined by the given ID from this batch. Any instances referencing this geometry
  /// will also be removed as a side effect.
  BatchedMesh deleteGeometry(int geometryId) {
    final geometryInfoList = _geometryInfo;

    if (geometryId >= geometryInfoList.length || geometryInfoList[geometryId].active == false) {
      return this;
    }

    // delete any instances associated with this geometry
    final instanceInfo = _instanceInfo;

    for (var i = 0, l = instanceInfo.length; i < l; i++) {
      if (instanceInfo[i].active && instanceInfo[i].geometryIndex == geometryId) {
        deleteInstance(i);
      }
    }

    geometryInfoList[geometryId].active = false;
    _availableGeometryIds.add(geometryId);
    _visibilityChanged = true;

    return this;
  }

  /// Deletes an existing instance from the batch using the given ID.
  BatchedMesh deleteInstance(int instanceId) {
    validateInstanceId(instanceId);

    _instanceInfo[instanceId].active = false;
    _availableInstanceIds.add(instanceId);
    _visibilityChanged = true;

    return this;
  }

  /// Repacks the sub geometries in BatchedMesh to remove any unused space remaining from previously deleted
  /// geometry, freeing up space to add new geometry.
  BatchedMesh optimize() {
    // track the next indices to copy data to
    var nextVertexStart = 0;
    var nextIndexStart = 0;

    // Iterate over all geometry ranges in order sorted from earliest in the geometry buffer to latest
    // in the geometry buffer. Because draw range objects can be reused there is no guarantee of their order.
    final geometryInfoList = _geometryInfo;
    final indices = [for (var i = 0; i < geometryInfoList.length; i++) i];
    _batchedMeshStableSort<int>(indices, (a, b) => geometryInfoList[a].vertexStart - geometryInfoList[b].vertexStart);

    final geometry = this.geometry;

    for (var i = 0, l = geometryInfoList.length; i < l; i++) {
      // if a geometry range is inactive then don't copy anything
      final index = indices[i];
      final geometryInfo = geometryInfoList[index];

      if (geometryInfo.active == false) {
        continue;
      }

      // if a geometry contains an index buffer then shift it, as well
      if (geometry.index != null) {
        if (geometryInfo.indexStart != nextIndexStart) {
          final indexStart = geometryInfo.indexStart;
          final vertexStart = geometryInfo.vertexStart;
          final reservedIndexCount = geometryInfo.reservedIndexCount;
          final index = geometry.index!;
          final array = index.array;

          // shift the index pointers based on how the vertex data will shift
          // adjusting the index must happen first so the original vertex start value is available
          final elementDelta = nextVertexStart - vertexStart;

          for (var j = indexStart; j < indexStart + reservedIndexCount; j++) {
            _typedArraySet(array, j, array[j] + elementDelta);
          }

          array.setRange(nextIndexStart, nextIndexStart + reservedIndexCount, array, indexStart);
          index.addUpdateRange(nextIndexStart, reservedIndexCount);
          index.needsUpdate = true;

          geometryInfo.indexStart = nextIndexStart;
        }

        nextIndexStart += geometryInfo.reservedIndexCount;
      }

      // if a geometry needs to be moved then copy attribute data to overwrite unused space
      if (geometryInfo.vertexStart != nextVertexStart) {
        final vertexStart = geometryInfo.vertexStart;
        final reservedVertexCount = geometryInfo.reservedVertexCount;
        final attributes = geometry.attributes;

        for (final key in attributes.keys) {
          final attribute = attributes[key]! as BufferAttribute;
          final array = attribute.array;
          final itemSize = attribute.itemSize;
          array.setRange(
            nextVertexStart * itemSize,
            (nextVertexStart + reservedVertexCount) * itemSize,
            array,
            vertexStart * itemSize,
          );
          attribute.addUpdateRange(nextVertexStart * itemSize, reservedVertexCount * itemSize);
          attribute.needsUpdate = true;
        }

        geometryInfo.vertexStart = nextVertexStart;
      }

      nextVertexStart += geometryInfo.reservedVertexCount;
      geometryInfo.start = geometry.index != null ? geometryInfo.indexStart : geometryInfo.vertexStart;
    }

    _nextIndexStart = nextIndexStart;
    _nextVertexStart = nextVertexStart;
    _visibilityChanged = true;

    return this;
  }

  /// Returns the bounding box for the given geometry, copied into `target`, or `null` (in the reference: `null`) for an
  /// id past the geometry count.
  Box3? getBoundingBoxAt(int geometryId, Box3 target) {
    if (geometryId >= _geometryCount) {
      return null;
    }

    // compute bounding box
    final geometry = this.geometry;
    final geometryInfo = _geometryInfo[geometryId];

    if (geometryInfo.boundingBox == null) {
      final box = Box3();
      final index = geometry.index;
      final position = geometry.attributes['position']!;

      for (var i = geometryInfo.start, l = geometryInfo.start + geometryInfo.count; i < l; i++) {
        var iv = i;

        if (index != null) {
          iv = index.getX(iv).toInt();
        }

        box.expandByPoint(_batchedMeshVector.fromBufferAttribute(position, iv));
      }

      geometryInfo.boundingBox = box;
    }

    target.copy(geometryInfo.boundingBox!);
    return target;
  }

  /// Returns the bounding sphere for the given geometry, copied into `target`, or `null` for an id past the
  /// geometry count.
  Sphere? getBoundingSphereAt(int geometryId, Sphere target) {
    if (geometryId >= _geometryCount) {
      return null;
    }

    // compute bounding sphere
    final geometry = this.geometry;
    final geometryInfo = _geometryInfo[geometryId];

    if (geometryInfo.boundingSphere == null) {
      final sphere = Sphere();
      getBoundingBoxAt(geometryId, _batchedMeshBox);
      _batchedMeshBox.getCenter(sphere.center);

      final index = geometry.index;
      final position = geometry.attributes['position']!;

      var maxRadiusSq = 0.0;

      for (var i = geometryInfo.start, l = geometryInfo.start + geometryInfo.count; i < l; i++) {
        var iv = i;

        if (index != null) {
          iv = index.getX(iv).toInt();
        }

        _batchedMeshVector.fromBufferAttribute(position, iv);
        maxRadiusSq = math.max(maxRadiusSq, sphere.center.distanceToSquared(_batchedMeshVector));
      }

      sphere.radius = math.sqrt(maxRadiusSq);
      geometryInfo.boundingSphere = sphere;
    }

    target.copy(geometryInfo.boundingSphere!);
    return target;
  }

  /// Sets the given local transformation matrix to the defined instance. Negatively scaled matrices are not
  /// supported.
  BatchedMesh setMatrixAt(int instanceId, Matrix4 matrix) {
    validateInstanceId(instanceId);

    final matricesTexture = _matricesTexture!;
    final matricesArray = _batchedMeshTextureData(matricesTexture) as List<double>;
    matrix.toArray(matricesArray, instanceId * 16);
    matricesTexture.needsUpdate = true;

    return this;
  }

  /// Returns the local transformation matrix of the defined instance, copied into `matrix`.
  Matrix4 getMatrixAt(int instanceId, Matrix4 matrix) {
    validateInstanceId(instanceId);
    return matrix.fromArray(_batchedMeshTextureData(_matricesTexture!), instanceId * 16);
  }

  /// Sets the given color to the defined instance.
  BatchedMesh setColorAt(int instanceId, Color color) {
    validateInstanceId(instanceId);

    if (_colorsTexture == null) {
      _initColorsTexture();
    }

    color.toArray(_batchedMeshTextureData(_colorsTexture!) as List<double>, instanceId * 4);
    _colorsTexture!.needsUpdate = true;

    return this;
  }

  /// Returns the color of the defined instance, copied into `color`: a [Color] or a [Vector4] (exception
  /// E-UNION; a Vector4 also receives the alpha component).
  T getColorAt<T extends Object>(int instanceId, T color) {
    validateInstanceId(instanceId);

    final colorsTexture = _colorsTexture;

    if (color is Vector4) {
      return (colorsTexture == null
              ? color.set(1, 1, 1, 1)
              : color.fromArray(_batchedMeshTextureData(colorsTexture), instanceId * 4))
          as T;
    }

    if (color is Color) {
      return (colorsTexture == null
              ? color.setRGB(1, 1, 1)
              : color.fromArray(_batchedMeshTextureData(colorsTexture), instanceId * 4))
          as T;
    }

    throw ArgumentError.value(color, 'color', 'must be a Color or a Vector4');
  }

  /// Sets the visibility of the instance.
  BatchedMesh setVisibleAt(int instanceId, bool visible) {
    validateInstanceId(instanceId);

    if (_instanceInfo[instanceId].visible == visible) {
      return this;
    }

    _instanceInfo[instanceId].visible = visible;
    _visibilityChanged = true;

    return this;
  }

  /// Returns the visibility state of the defined instance.
  bool getVisibleAt(int instanceId) {
    validateInstanceId(instanceId);

    return _instanceInfo[instanceId].visible;
  }

  /// Sets the geometry ID of the instance at the given index.
  BatchedMesh setGeometryIdAt(int instanceId, int geometryId) {
    validateInstanceId(instanceId);
    validateGeometryId(geometryId);

    _instanceInfo[instanceId].geometryIndex = geometryId;
    _visibilityChanged = true;

    return this;
  }

  /// Returns the geometry ID of the defined instance.
  int getGeometryIdAt(int instanceId) {
    validateInstanceId(instanceId);

    return _instanceInfo[instanceId].geometryIndex;
  }

  /// Get the range representing the subset of triangles related to the attached geometry, indicating the
  /// starting offset and count, or `null` if invalid.
  BatchedMeshGeometryRange getGeometryRangeAt(int geometryId, [BatchedMeshGeometryRange? target]) {
    target ??= BatchedMeshGeometryRange();

    validateGeometryId(geometryId);

    final geometryInfo = _geometryInfo[geometryId];
    target.vertexStart = geometryInfo.vertexStart;
    target.vertexCount = geometryInfo.vertexCount;
    target.reservedVertexCount = geometryInfo.reservedVertexCount;

    target.indexStart = geometryInfo.indexStart;
    target.indexCount = geometryInfo.indexCount;
    target.reservedIndexCount = geometryInfo.reservedIndexCount;

    target.start = geometryInfo.start;
    target.count = geometryInfo.count;

    return target;
  }

  /// Resizes the necessary buffers to support the provided number of instances. If the provided arguments
  /// shrink the number of instances but there are not enough unused Ids at the end of the list then an
  /// error is thrown.
  void setInstanceCount(int maxInstanceCount) {
    // shrink the available instances as much as possible
    final availableInstanceIds = _availableInstanceIds;
    final instanceInfo = _instanceInfo;
    _batchedMeshStableSort(availableInstanceIds, _batchedMeshAscIdSort);

    while (availableInstanceIds.isNotEmpty && availableInstanceIds.last == instanceInfo.length - 1) {
      instanceInfo.removeLast();
      availableInstanceIds.removeLast();
    }

    // throw an error if it can't be shrunk to the desired size
    if (maxInstanceCount < instanceInfo.length) {
      throw EntError(
        'ENT.BatchedMesh: Instance ids outside the range $maxInstanceCount are being used. Cannot shrink instance count.',
      );
    }

    // copy the multi draw counts
    final multiDrawCounts = Int32List(maxInstanceCount);
    final multiDrawStarts = Int32List(maxInstanceCount);
    _batchedMeshCopyArrayContents(_multiDrawCounts, multiDrawCounts);
    _batchedMeshCopyArrayContents(_multiDrawStarts, multiDrawStarts);

    _multiDrawCounts = multiDrawCounts;
    _multiDrawStarts = multiDrawStarts;

    final mergedDrawCounts = Int32List(maxInstanceCount);
    final mergedDrawStarts = Int32List(maxInstanceCount);
    final mergedDrawInstanceCounts = Int32List(maxInstanceCount);
    _batchedMeshCopyArrayContents(_mergedDrawCounts, mergedDrawCounts);
    _batchedMeshCopyArrayContents(_mergedDrawStarts, mergedDrawStarts);
    _batchedMeshCopyArrayContents(_mergedDrawInstanceCounts, mergedDrawInstanceCounts);

    _mergedDrawCounts = mergedDrawCounts;
    _mergedDrawStarts = mergedDrawStarts;
    _mergedDrawInstanceCounts = mergedDrawInstanceCounts;
    _maxInstanceCount = maxInstanceCount;

    // update texture data for instance sampling
    final indirectTexture = _indirectTexture!;
    final matricesTexture = _matricesTexture!;
    final colorsTexture = _colorsTexture;

    indirectTexture.dispose();
    _initIndirectTexture();
    _batchedMeshCopyArrayContents(_batchedMeshTextureData(indirectTexture), _batchedMeshTextureData(_indirectTexture!));

    matricesTexture.dispose();
    _initMatricesTexture();
    _batchedMeshCopyArrayContents(_batchedMeshTextureData(matricesTexture), _batchedMeshTextureData(_matricesTexture!));

    if (colorsTexture != null) {
      colorsTexture.dispose();
      _initColorsTexture();
      _batchedMeshCopyArrayContents(_batchedMeshTextureData(colorsTexture), _batchedMeshTextureData(_colorsTexture!));
    }

    if (_previousMatricesTexture != null) {
      _previousMatricesTexture!.dispose();
      _previousMatricesTexture = null;
    }
  }

  /// Resizes the available space in the batch's vertex and index buffer attributes to the provided sizes.
  /// If the provided arguments shrink the geometry buffers but there is not enough unused space at the end
  /// of the geometry attributes then an error is thrown.
  void setGeometrySize(int maxVertexCount, int maxIndexCount) {
    // Check if we can shrink to the requested vertex attribute size
    final validRanges = _geometryInfo.where((info) => info.active).toList();
    final requiredVertexLength = validRanges.fold<double>(
      double.negativeInfinity,
      (max, range) => math.max(max, (range.vertexStart + range.reservedVertexCount).toDouble()),
    );

    if (requiredVertexLength > maxVertexCount) {
      throw EntError(
        'ENT.BatchedMesh: Geometry vertex values are being used outside the range $maxVertexCount. Cannot shrink further.',
      );
    }

    // Check if we can shrink to the requested index attribute size
    if (this.geometry.index != null) {
      final requiredIndexLength = validRanges.fold<double>(
        double.negativeInfinity,
        (max, range) => math.max(max, (range.indexStart + range.reservedIndexCount).toDouble()),
      );

      if (requiredIndexLength > maxIndexCount) {
        throw EntError(
          'ENT.BatchedMesh: Geometry index values are being used outside the range $maxIndexCount. Cannot shrink further.',
        );
      }
    }

    //

    // dispose of the previous geometry
    final oldGeometry = this.geometry;
    oldGeometry.dispose();

    // recreate the geometry needed based on the previous variant
    _maxVertexCount = maxVertexCount;
    _maxIndexCount = maxIndexCount;

    if (_geometryInitialized) {
      _geometryInitialized = false;
      this.geometry = BufferGeometry();
      _initializeGeometry(oldGeometry);
    }

    // copy data from the previous geometry
    final geometry = this.geometry;

    if (oldGeometry.index != null) {
      _batchedMeshCopyArrayContents(oldGeometry.index!.array, geometry.index!.array);
    }

    for (final key in oldGeometry.attributes.keys) {
      _batchedMeshCopyArrayContents(oldGeometry.attributes[key]!.array, geometry.attributes[key]!.array);
    }

    _visibilityChanged = true;
  }

  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final instanceInfo = _instanceInfo;
    final geometryInfoList = _geometryInfo;
    final matrixWorld = this.matrixWorld;
    final batchGeometry = geometry;
    final mesh = _batchedMeshMesh;

    // iterate over each geometry
    mesh.material = material;
    mesh.geometry.index = batchGeometry.index;
    mesh.geometry.attributes = batchGeometry.attributes;

    mesh.geometry.boundingBox ??= Box3();

    mesh.geometry.boundingSphere ??= Sphere();

    for (var i = 0, l = instanceInfo.length; i < l; i++) {
      if (!instanceInfo[i].visible || !instanceInfo[i].active) {
        continue;
      }

      final geometryId = instanceInfo[i].geometryIndex;
      final geometryInfo = geometryInfoList[geometryId];
      mesh.geometry.setDrawRange(geometryInfo.start.toDouble(), geometryInfo.count.toDouble());

      // get the intersects
      getMatrixAt(i, mesh.matrixWorld).premultiply(matrixWorld);
      getBoundingBoxAt(geometryId, mesh.geometry.boundingBox!);
      getBoundingSphereAt(geometryId, mesh.geometry.boundingSphere!);
      mesh.raycast(raycaster, _batchedMeshBatchIntersects);

      // add batch id to the intersects
      for (var j = 0, l = _batchedMeshBatchIntersects.length; j < l; j++) {
        final intersect = _batchedMeshBatchIntersects[j];
        intersect.object = this;
        intersect.batchId = i;
        intersects.add(intersect);
      }

      _batchedMeshBatchIntersects.length = 0;
    }

    mesh.material = null;
    mesh.geometry.index = null;
    mesh.geometry.attributes = {};
    mesh.geometry.setDrawRange(0, double.infinity);

    return null;
  }

  @override
  BatchedMesh copy(covariant BatchedMesh source, [bool? recursive]) {
    super.copy(source);

    geometry = source.geometry.clone();
    perObjectFrustumCulled = source.perObjectFrustumCulled;
    sortObjects = source.sortObjects;
    boundingBox = source.boundingBox?.clone();
    boundingSphere = source.boundingSphere?.clone();

    _geometryInfo = source._geometryInfo.map((info) => info.copy()).toList();
    _instanceInfo = source._instanceInfo.map((info) => info.copy()).toList();

    _availableInstanceIds = source._availableInstanceIds.toList();
    _availableGeometryIds = source._availableGeometryIds.toList();

    _nextIndexStart = source._nextIndexStart;
    _nextVertexStart = source._nextVertexStart;
    _geometryCount = source._geometryCount;

    _maxInstanceCount = source._maxInstanceCount;
    _maxVertexCount = source._maxVertexCount;
    _maxIndexCount = source._maxIndexCount;

    _geometryInitialized = source._geometryInitialized;
    _multiDrawCounts = Int32List.fromList(source._multiDrawCounts);
    _multiDrawStarts = Int32List.fromList(source._multiDrawStarts);
    _multiDrawBytesPerElement = source._multiDrawBytesPerElement;
    _mergedDrawCounts = Int32List.fromList(source._mergedDrawCounts);
    _mergedDrawStarts = Int32List.fromList(source._mergedDrawStarts);
    _mergedDrawInstanceCounts = Int32List.fromList(source._mergedDrawInstanceCounts);

    _indirectTexture = _cloneDataTexture(source._indirectTexture!);
    _matricesTexture = _cloneDataTexture(source._matricesTexture!);

    if (source._colorsTexture != null) {
      _colorsTexture = _cloneDataTexture(source._colorsTexture!);
    } else {
      _colorsTexture = null;
    }

    return this;
  }

  /// `texture.clone()` then `clone.image.data = clone.image.data.slice()`. The clone shares its image with the source
  /// texture (as the reference's does), so the source then reads the copied array too.
  static DataTexture _cloneDataTexture(DataTexture texture) {
    final clone = texture.clone();
    final image = clone.image as DataImage;
    image.data = _typedArrayLike(image.data as List<num>, image.data as List<num>);
    return clone;
  }

  @override
  BatchedMesh clone([bool? recursive]) {
    return BatchedMesh(0, 0, 0, material).copy(this, recursive);
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    // Assuming the geometry is not shared with other meshes
    geometry.dispose();

    _matricesTexture!.dispose();
    _matricesTexture = null;

    _indirectTexture!.dispose();
    _indirectTexture = null;

    if (_colorsTexture != null) {
      _colorsTexture!.dispose();
      _colorsTexture = null;
    }

    if (_previousMatricesTexture != null) {
      _previousMatricesTexture!.dispose();
      _previousMatricesTexture = null;
    }
  }

  void _updateDrawParameters(
    Camera camera,
    BufferGeometry geometry,
    Object? material, [
    String drawFormat = 'multiDraw',
  ]) {
    // if visibility has not changed and frustum culling and object sorting is not required
    // then skip iterating over all items
    if (!_visibilityChanged && !this.perObjectFrustumCulled && !sortObjects) {
      return;
    }

    // the indexed version of the multi draw function requires specifying the start
    // offset in bytes.
    final index = geometry.getIndex();
    var bytesPerElement = index == null ? 1 : (index.array as TypedData).elementSizeInBytes;

    // the "wireframe" attribute implicitly creates a line attribute in the renderer, which is double
    // the vertices to draw (3 lines per triangle) so we multiply the draw counts / starts and make
    // assumptions about the index buffer byte size.
    var multiDrawMultiplier = 1;

    if (_batchedMeshIsTrue(material, (m) => m.wireframe)) {
      multiDrawMultiplier = 2;
      bytesPerElement = geometry.attributes['position']!.count > 65535 ? 4 : 2;
    }

    final instanceInfo = _instanceInfo;
    final multiDrawStarts = _multiDrawStarts;
    final multiDrawCounts = _multiDrawCounts;
    final mergedDrawStarts = _mergedDrawStarts;
    final mergedDrawCounts = _mergedDrawCounts;
    final mergedDrawInstanceCounts = _mergedDrawInstanceCounts;
    final geometryInfoList = _geometryInfo;
    final perObjectFrustumCulled = this.perObjectFrustumCulled;
    final indirectTexture = _indirectTexture!;
    final indirectArray = _batchedMeshTextureData(indirectTexture);

    // prepare the frustum in the local frame
    if (perObjectFrustumCulled) {
      if (camera is ArrayCamera) {
        _batchedMeshFrustumArray.setFromArrayCamera(camera);
      } else {
        _batchedMeshMatrix.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse).multiply(matrixWorld);

        _batchedMeshFrustum.setFromProjectionMatrix(_batchedMeshMatrix, camera.coordinateSystem, camera.reversedDepth);
      }
    }

    bool intersectsSphere(Sphere sphere) {
      return camera is ArrayCamera
          ? _batchedMeshFrustumArray.intersectsSphere(sphere)
          : _batchedMeshFrustum.intersectsSphere(sphere);
    }

    var multiDrawCount = 0;
    var mergedDrawCount = 0;

    if (sortObjects) {
      // get the camera position in the local frame
      _batchedMeshMatrix.copy(matrixWorld).invert();
      _batchedMeshCameraPosition.setFromMatrixPosition(camera.matrixWorld).applyMatrix4(_batchedMeshMatrix);
      _batchedMeshForward.set(0, 0, -1).transformDirection(camera.matrixWorld).transformDirection(_batchedMeshMatrix);

      for (var i = 0, l = instanceInfo.length; i < l; i++) {
        if (instanceInfo[i].visible && instanceInfo[i].active) {
          final geometryId = instanceInfo[i].geometryIndex;

          // get the bounds in world space
          getMatrixAt(i, _batchedMeshMatrix);
          getBoundingSphereAt(geometryId, _batchedMeshSphere)!.applyMatrix4(_batchedMeshMatrix);

          // determine whether the batched geometry is within the frustum
          var culled = false;

          if (perObjectFrustumCulled) {
            culled = !intersectsSphere(_batchedMeshSphere);
          }

          if (!culled) {
            // get the distance from camera used for sorting
            final geometryInfo = geometryInfoList[geometryId];
            final z = _batchedMeshTemp
                .subVectors(_batchedMeshSphere.center, _batchedMeshCameraPosition)
                .dot(_batchedMeshForward);
            _batchedMeshRenderList.push(geometryInfo.start, geometryInfo.count, z, i);
          }
        }
      }

      // Sort the draw ranges and prep for rendering
      final list = _batchedMeshRenderList.list;
      final customSort = this.customSort;

      if (customSort == null) {
        _batchedMeshStableSort(
          list,
          _batchedMeshIsTrue(material, (m) => m.transparent) ? _batchedMeshSortTransparent : _batchedMeshSortOpaque,
        );
      } else {
        customSort(list, camera);
      }

      for (var i = 0, l = list.length; i < l; i++) {
        final item = list[i];
        final start = item.start * bytesPerElement * multiDrawMultiplier;
        final count = item.count * multiDrawMultiplier;

        if (drawFormat == 'merged') {
          if (mergedDrawCount > 0 &&
              mergedDrawStarts[mergedDrawCount - 1] == start &&
              mergedDrawCounts[mergedDrawCount - 1] == count) {
            mergedDrawInstanceCounts[mergedDrawCount - 1]++;
          } else {
            mergedDrawStarts[mergedDrawCount] = start;
            mergedDrawCounts[mergedDrawCount] = count;
            mergedDrawInstanceCounts[mergedDrawCount] = 1;
            mergedDrawCount++;
          }
        } else {
          multiDrawStarts[multiDrawCount] = start;
          multiDrawCounts[multiDrawCount] = count;
        }

        _typedArraySet(indirectArray, multiDrawCount, item.index);
        multiDrawCount++;
      }

      _batchedMeshRenderList.reset();
    } else {
      for (var i = 0, l = instanceInfo.length; i < l; i++) {
        if (instanceInfo[i].visible && instanceInfo[i].active) {
          final geometryId = instanceInfo[i].geometryIndex;

          // determine whether the batched geometry is within the frustum
          var culled = false;

          if (perObjectFrustumCulled) {
            // get the bounds in world space
            getMatrixAt(i, _batchedMeshMatrix);
            getBoundingSphereAt(geometryId, _batchedMeshSphere)!.applyMatrix4(_batchedMeshMatrix);
            culled = !intersectsSphere(_batchedMeshSphere);
          }

          if (!culled) {
            final geometryInfo = geometryInfoList[geometryId];
            final start = geometryInfo.start * bytesPerElement * multiDrawMultiplier;
            final count = geometryInfo.count * multiDrawMultiplier;

            if (drawFormat == 'merged') {
              if (mergedDrawCount > 0 &&
                  mergedDrawStarts[mergedDrawCount - 1] == start &&
                  mergedDrawCounts[mergedDrawCount - 1] == count) {
                mergedDrawInstanceCounts[mergedDrawCount - 1]++;
              } else {
                mergedDrawStarts[mergedDrawCount] = start;
                mergedDrawCounts[mergedDrawCount] = count;
                mergedDrawInstanceCounts[mergedDrawCount] = 1;
                mergedDrawCount++;
              }
            } else {
              multiDrawStarts[multiDrawCount] = start;
              multiDrawCounts[multiDrawCount] = count;
            }

            _typedArraySet(indirectArray, multiDrawCount, i);
            multiDrawCount++;
          }
        }
      }
    }

    indirectTexture.needsUpdate = true;
    _multiDrawCount = multiDrawCount;
    _mergedDrawCount = mergedDrawCount;
    _multiDrawBytesPerElement = bytesPerElement;
    _visibilityChanged = false;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isBatchedMesh' => isBatchedMesh,
      'perObjectFrustumCulled' => perObjectFrustumCulled,
      'sortObjects' => sortObjects,
      'boundingBox' => boundingBox,
      'boundingSphere' => boundingSphere,
      'customSort' => customSort,
      'maxInstanceCount' => maxInstanceCount,
      'instanceCount' => instanceCount,
      'unusedVertexCount' => unusedVertexCount,
      'unusedIndexCount' => unusedIndexCount,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'perObjectFrustumCulled':
        perObjectFrustumCulled = value as bool;
      case 'sortObjects':
        sortObjects = value as bool;
      case 'boundingBox':
        boundingBox = value as Box3?;
      case 'boundingSphere':
        boundingSphere = value as Sphere?;
      case 'customSort':
        customSort = value as BatchedMeshSort?;
      default:
        super[key] = value;
    }
  }
}
