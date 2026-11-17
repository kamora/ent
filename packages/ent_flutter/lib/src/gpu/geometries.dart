// Vertex and index buffers of BufferGeometry objects on Flutter GPU: one float32 stream per attribute and vertex slot,
// re-uploaded when the attribute's version changes and dropped on the geometry's 'dispose' event, plus shared default
// streams for attributes a geometry lacks, the morph target textures and the per-instance streams of InstancedMesh
// attributes.

import 'dart:typed_data';

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:ent/ent.dart';

import 'programs.dart';

/// An uploaded buffer and what it was made from.
class GpuBuffer {
  GpuBuffer(this.version, this.buffer, this.lengthInBytes);

  final int version;

  final gpu.DeviceBuffer buffer;

  final int lengthInBytes;
}

/// An uploaded index buffer.
class GpuIndex extends GpuBuffer {
  GpuIndex(super.version, super.buffer, super.lengthInBytes, this.type, this.bytesPerIndex);

  final gpu.IndexType type;

  final int bytesPerIndex;
}

/// The morph targets of a geometry as the reference renderer lays them out: per target a [width] × [rows] block of
/// [stride] RGBA float texels per vertex (position, normal, color), the targets stacked in rows of one 2D texture
/// (in the reference: the layers of a DataArrayTexture).
class GpuMorph {
  GpuMorph(this.texture, this.count, this.stride, this.width, this.rows);

  final gpu.Texture texture;

  final int count;

  final int stride;

  final int width;

  final int rows;
}

class _Entry {
  _Entry(this.listener);

  final EventListener listener;

  /// Streams by attribute name and component count.
  final Map<(String, int), GpuBuffer> attributes = {};

  GpuIndex? index;

  GpuMorph? morph;
}

/// The geometry buffers a renderer holds; [count] is reported as `renderer.info.memory.geometries`.
class GpuGeometries {
  final Map<BufferGeometry, _Entry> _entries = {};

  final Map<(int, bool), (int, gpu.DeviceBuffer)> _defaults = {};

  final Map<int, (int, gpu.DeviceBuffer)> _ones = {};

  final Expando<GpuBuffer> _instances = Expando();

  int get count => _entries.length;

  _Entry _entry(BufferGeometry geometry) {
    final cached = _entries[geometry];

    if (cached != null) {
      return cached;
    }

    late final _Entry entry;
    entry = _Entry((_) {
      geometry.removeEventListener('dispose', entry.listener);
      _entries.remove(geometry);
    });
    geometry.addEventListener('dispose', entry.listener);

    return _entries[geometry] = entry;
  }

  /// The stream of [slot] for [geometry]: its attribute as `slot.size` floats per vertex (missing components
  /// read as `(0, 0, 0, 1)`, as WebGL fills them), or `null` when the geometry has no such attribute.
  GpuBuffer? attribute(BufferGeometry geometry, VertexSlot slot) {
    final attribute = geometry.getAttribute(slot.name);

    if (attribute == null) {
      return null;
    }

    final entry = _entry(geometry);
    final version = switch (attribute) {
      BufferAttribute a => a.version,
      InterleavedBufferAttribute a => a.data.version,
      _ => -1,
    };
    final key = (slot.name, slot.size);
    final cached = entry.attributes[key];

    if (cached != null && cached.version == version) {
      return cached;
    }

    final count = attribute.count;
    final size = slot.size;
    final floats = Float32List(count * size);
    final items = attribute.itemSize;

    for (var i = 0; i < count; i++) {
      final o = i * size;
      floats[o] = attribute.getX(i);

      if (size > 1) {
        floats[o + 1] = items > 1 ? attribute.getY(i) : 0;
      }

      if (size > 2) {
        floats[o + 2] = items > 2 ? attribute.getZ(i) : 0;
      }

      if (size > 3) {
        floats[o + 3] = items > 3 ? attribute.getW(i) : 1;
      }
    }

    return entry.attributes[key] = GpuBuffer(
      version,
      gpu.gpuContext.createDeviceBufferWithCopy(floats.buffer.asByteData()),
      floats.lengthInBytes,
    );
  }

  /// A stream of [count] vertices of WebGL's default attribute value for [slot] (0, 0, 0, 1), or with [white] of
  /// white (the vertex colors of a material without vertexColors), shared by all geometries.
  gpu.DeviceBuffer fallback(VertexSlot slot, int count, {bool white = false}) {
    final cached = _defaults[(slot.size, white)];

    if (cached != null && cached.$1 >= count) {
      return cached.$2;
    }

    final length = count < 1024 ? 1024 : count;
    final floats = Float32List(length * slot.size);

    if (white) {
      floats.fillRange(0, floats.length, 1);
    } else if (slot.size == 4) {
      for (var i = 3; i < floats.length; i += 4) {
        floats[i] = 1;
      }
    }

    final buffer = gpu.gpuContext.createDeviceBufferWithCopy(floats.buffer.asByteData());
    _defaults[(slot.size, white)] = (length, buffer);

    return buffer;
  }

  /// A stream of [count] elements of [size] ones (white for a color slot), shared by all draws.
  gpu.DeviceBuffer ones(int size, int count) {
    final cached = _ones[size];

    if (cached != null && cached.$1 >= count) {
      return cached.$2;
    }

    final length = count < 1024 ? 1024 : count;
    final buffer = gpu.gpuContext.createDeviceBufferWithCopy(
      (Float32List(length * size)..fillRange(0, length * size, 1)).buffer.asByteData(),
    );
    _ones[size] = (length, buffer);

    return buffer;
  }

  /// The stream of an InstancedMesh attribute (instanceMatrix, instanceColor) as float32, uploaded again when
  /// its version changes and released with the attribute.
  GpuBuffer instance(BufferAttribute attribute) {
    final cached = _instances[attribute];

    if (cached != null && cached.version == attribute.version) {
      return cached;
    }

    final floats = Float32List.fromList([for (final v in attribute.array) v.toDouble()]);

    return _instances[attribute] = GpuBuffer(
      attribute.version,
      gpu.gpuContext.createDeviceBufferWithCopy(floats.buffer.asByteData()),
      floats.lengthInBytes,
    );
  }

  /// The index buffer of [geometry], or `null` for a non-indexed geometry.
  GpuIndex? index(BufferGeometry geometry) {
    final index = geometry.index;

    if (index == null) {
      return null;
    }

    final entry = _entry(geometry);
    final cached = entry.index;

    if (cached != null && cached.version == index.version) {
      return cached;
    }

    final array = index.array;
    final wide = array is! Uint16List;
    final data = wide ? Uint32List.fromList([for (final i in array) i.toInt()]) : array;

    return entry.index = GpuIndex(
      index.version,
      gpu.gpuContext.createDeviceBufferWithCopy(data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes)),
      data.lengthInBytes,
      wide ? gpu.IndexType.int32 : gpu.IndexType.int16,
      wide ? 4 : 2,
    );
  }

  /// The morph texture of [geometry], or `null` without morph attributes. As in the reference, it is built again
  /// only when the number of targets changes.
  GpuMorph? morph(BufferGeometry geometry) {
    final attributes = geometry.morphAttributes;
    final targets = attributes['position'] ?? attributes['normal'] ?? attributes['color'];

    if (targets == null || targets.isEmpty) {
      return null;
    }

    final entry = _entry(geometry);
    final cached = entry.morph;

    if (cached != null && cached.count == targets.length) {
      return cached;
    }

    final positions = attributes['position'];
    final normals = attributes['normal'];
    final colors = attributes['color'];
    final stride = colors != null ? 3 : (normals != null ? 2 : 1);
    var width = geometry.getAttribute('position')!.count * stride;
    var rows = 1;

    if (width > maxTextureSize) {
      rows = (width / maxTextureSize).ceil();
      width = maxTextureSize;
    }

    final floats = Float32List(width * rows * 4 * targets.length);

    for (var i = 0; i < targets.length; i++) {
      final offset = width * rows * 4 * i;

      for (var j = 0; j < targets[i].count; j++) {
        final o = offset + j * stride * 4;

        if (positions != null) {
          floats
            ..[o] = positions[i].getX(j)
            ..[o + 1] = positions[i].getY(j)
            ..[o + 2] = positions[i].getZ(j);
        }

        if (normals != null) {
          floats
            ..[o + 4] = normals[i].getX(j)
            ..[o + 5] = normals[i].getY(j)
            ..[o + 6] = normals[i].getZ(j);
        }

        if (colors != null) {
          final color = colors[i];
          floats
            ..[o + 8] = color.getX(j)
            ..[o + 9] = color.getY(j)
            ..[o + 10] = color.getZ(j)
            ..[o + 11] = color.itemSize == 4 ? color.getW(j) : 1;
        }
      }
    }

    final texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      rows * targets.length,
      format: gpu.PixelFormat.r32g32b32a32Float,
      enableRenderTargetUsage: false,
    )..overwrite(floats.buffer.asByteData());

    return entry.morph = GpuMorph(texture, targets.length, stride, width, rows);
  }

  /// The widest morph texture row (WebGL's MAX_TEXTURE_SIZE, as Chrome reports it on Apple GPUs).
  static const int maxTextureSize = 16384;

  /// Starts tracking [geometry] (counted in [count]) even before an attribute is uploaded.
  void track(BufferGeometry geometry) => _entry(geometry);

  void dispose() {
    for (final MapEntry(key: geometry, value: entry) in _entries.entries) {
      geometry.removeEventListener('dispose', entry.listener);
    }

    _entries.clear();
    _defaults.clear();
    _ones.clear();
  }
}
