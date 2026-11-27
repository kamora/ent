part of '../../ent.dart';

/// One model of a VOX file: its [size] in voxels, its voxels in [data] and the [palette] they index.
class VOXChunk {
  VOXChunk._(this.size, this.palette);

  /// The model's extent in voxels along the VOX axes (x right, y forward, z up).
  final ({int x, int y, int z}) size;

  /// The colors, one 32-bit integer each with red in the lowest byte; index 0 is unused (empty voxels).
  List<int> palette;

  /// The voxels, four bytes each: x, y, z and a palette index.
  Uint8List data = Uint8List(0);
}

/// What [VOXLoader.parse] returns: the file's models ([chunks]) and, when it has a scene graph (version 200), the
/// [scene] built from it.
class VOXResult {
  VOXResult._(this.chunks, this.scene);

  /// The models, in file order.
  final List<VOXChunk> chunks;

  /// The scene graph as objects (groups and meshes with their transforms), or `null` for a file without one.
  final Object3D? scene;
}

/// A loader for the VOX format of MagicaVoxel.
///
/// ```dart
/// final result = await VOXLoader().loadAsync('models/vox/monu10.vox');
/// scene.add(result!.scene!.children[0]);
/// ```
class VOXLoader extends Loader<VOXResult?> {
  /// Constructs a new VOX loader.
  VOXLoader([super.manager]);

  /// Starts loading from the given URL and passes the loaded VOX asset to the [onLoad] callback.
  @override
  void load(
    covariant String url, [
    void Function(VOXResult? result)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setPath(path)
      ..setResponseType('arraybuffer')
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    loader.load(
      url,
      (buffer) {
        try {
          onLoad!(parse(buffer! as ByteBuffer));
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

  /// Parses the given VOX data and returns its chunks and scene; `null`, with an error logged, for data that is not
  /// a VOX file of version 150 or 200.
  @override
  VOXResult? parse(covariant ByteBuffer buffer) {
    final data = ByteData.view(buffer);

    final id = data.getUint32(0, Endian.little);
    final version = data.getUint32(4, Endian.little);

    if (id != 542658390) {
      error('VOXLoader: Invalid VOX file.');
      return null;
    }

    if (version != 150 && version != 200) {
      error('VOXLoader: Invalid VOX file. Unsupported version:', [version]);
      return null;
    }

    var i = 8;

    VOXChunk? chunk;
    final chunks = <VOXChunk>[];

    // Extension data
    final nodes = <int, _VOXNode>{};
    var palette = _voxDefaultPalette;

    while (i < data.lengthInBytes) {
      final id = String.fromCharCodes(Uint8List.view(buffer, i, 4));
      i += 4;

      final chunkSize = data.getUint32(i, Endian.little);
      i += 4;
      i += 4; // childChunks

      if (id == 'SIZE') {
        final x = data.getUint32(i, Endian.little);
        final y = data.getUint32(i + 4, Endian.little);
        final z = data.getUint32(i + 8, Endian.little);
        i += 12;

        chunk = VOXChunk._((x: x, y: y, z: z), _voxDefaultPalette);
        chunks.add(chunk);

        i += chunkSize - (3 * 4);
      } else if (id == 'XYZI') {
        final numVoxels = data.getUint32(i, Endian.little);
        i += 4;
        chunk!.data = Uint8List.view(buffer, i, numVoxels * 4);

        i += numVoxels * 4;
      } else if (id == 'RGBA') {
        palette = [0];

        for (var j = 0; j < 256; j++) {
          palette.add(data.getUint32(i, Endian.little));
          i += 4;
        }

        chunk!.palette = palette;
      } else if (id == 'nTRN') {
        // Transform Node
        final nodeId = data.getUint32(i, Endian.little);
        i += 4;
        final attributes = _voxReadDict(data, i);
        i += attributes.size;

        final childNodeId = data.getUint32(i, Endian.little);
        i += 4;
        i += 4; // reserved (-1)
        final layerId = data.getInt32(i, Endian.little);
        i += 4;
        final numFrames = data.getUint32(i, Endian.little);
        i += 4;

        final frames = <_VOXFrame>[];

        for (var f = 0; f < numFrames; f++) {
          final frameDict = _voxReadDict(data, i);
          i += frameDict.size;

          final frame = _VOXFrame();

          if (frameDict.value['_r'] case final rotation?) {
            frame.rotation = _voxDecodeRotation(int.tryParse(rotation) ?? 0);
          }

          if (frameDict.value['_t'] case final translation?) {
            final parts = translation.split(' ').map((part) => double.tryParse(part) ?? double.nan).toList();
            frame.translation = (x: parts[0], y: parts[1], z: parts[2]);
          }

          frames.add(frame);
        }

        nodes[nodeId] = _VOXTransform(attributes.value, childNodeId, layerId, frames);
      } else if (id == 'nGRP') {
        // Group Node
        final nodeId = data.getUint32(i, Endian.little);
        i += 4;
        final attributes = _voxReadDict(data, i);
        i += attributes.size;

        final numChildren = data.getUint32(i, Endian.little);
        i += 4;
        final childIds = <int>[];

        for (var c = 0; c < numChildren; c++) {
          childIds.add(data.getUint32(i, Endian.little));
          i += 4;
        }

        nodes[nodeId] = _VOXGroup(attributes.value, childIds);
      } else if (id == 'nSHP') {
        // Shape Node
        final nodeId = data.getUint32(i, Endian.little);
        i += 4;
        final attributes = _voxReadDict(data, i);
        i += attributes.size;

        final numModels = data.getUint32(i, Endian.little);
        i += 4;
        final models = <int>[];

        for (var m = 0; m < numModels; m++) {
          models.add(data.getUint32(i, Endian.little));
          i += 4;
          i += _voxReadDict(data, i).size;
        }

        nodes[nodeId] = _VOXShape(attributes.value, models);
      } else {
        // Skip unknown chunks
        i += chunkSize;
      }
    }

    // Apply palette to all chunks
    for (final chunk in chunks) {
      chunk.palette = palette;
    }

    // Build the scene graph from nodes
    Object3D? scene;

    if (nodes.isNotEmpty) {
      scene = _voxBuildObject(0, nodes, chunks);
    }

    return VOXResult._(chunks, scene);
  }

  /// Builds a mesh from a VOX chunk: greedy meshing merges coplanar faces of one color into quads, colored per
  /// vertex from the palette (in sRGB, converted to the working color space) unless every color used is black.
  static Mesh buildMesh(VOXChunk chunk) {
    final data = chunk.data;
    final palette = chunk.palette;

    final sx = chunk.size.x;
    final sy = chunk.size.y;
    final sz = chunk.size.z;

    // Build volume with color indices
    final volume = Uint8List(sx * sy * sz);

    for (var j = 0; j < data.length; j += 4) {
      volume[data[j] + data[j + 1] * sx + data[j + 2] * sx * sy] = data[j + 3];
    }

    // Greedy meshing
    final vertices = <double>[];
    final indices = <int>[];
    final colors = <double>[];

    final color = Color();
    var hasColors = false;

    // Process each of the 6 face directions; dims: the 3 axis sizes, d: which axis is normal to the face
    final dims = [sx, sy, sz];

    for (var d = 0; d < 3; d++) {
      final u = (d + 1) % 3;
      final v = (d + 2) % 3;

      final dimsD = dims[d];
      final dimsU = dims[u];
      final dimsV = dims[v];

      final q = [0, 0, 0];
      final mask = Int16List(dimsU * dimsV);

      q[d] = 1;

      // Sweep through slices
      for (var slice = 0; slice <= dimsD; slice++) {
        // Build mask for this slice
        var n = 0;

        for (var vv = 0; vv < dimsV; vv++) {
          for (var uu = 0; uu < dimsU; uu++) {
            final pos = [0, 0, 0];
            pos[d] = slice;
            pos[u] = uu;
            pos[v] = vv;

            // Get voxel behind and in front of this face
            var behind = 0;
            var infront = 0;

            if (slice > 0) {
              behind = volume[(pos[0] - q[0]) + (pos[1] - q[1]) * sx + (pos[2] - q[2]) * sx * sy];
            }

            if (slice < dimsD) {
              infront = volume[pos[0] + pos[1] * sx + pos[2] * sx * sy];
            }

            // Face exists if exactly one side is solid
            if (behind > 0 && infront == 0) {
              mask[n] = behind; // positive face
            } else if (infront > 0 && behind == 0) {
              mask[n] = -infront; // negative face
            } else {
              mask[n] = 0;
            }

            n++;
          }
        }

        // Greedy merge mask into quads
        n = 0;

        for (var vv = 0; vv < dimsV; vv++) {
          for (var uu = 0; uu < dimsU;) {
            final c = mask[n];

            if (c == 0) {
              uu++;
              n++;
              continue;
            }

            // Find width
            var w = 1;

            while (uu + w < dimsU && mask[n + w] == c) {
              w++;
            }

            // Find height
            var h = 1;
            var done = false;

            while (vv + h < dimsV && !done) {
              for (var k = 0; k < w; k++) {
                if (mask[n + k + h * dimsU] != c) {
                  done = true;
                  break;
                }
              }

              if (!done) {
                h++;
              }
            }

            // Add quad
            final pos = [0, 0, 0];
            pos[d] = slice;
            pos[u] = uu;
            pos[v] = vv;

            final du = [0, 0, 0];
            final dv = [0, 0, 0];
            du[u] = w;
            dv[v] = h;

            // Get color
            final hex = palette[c.abs()];
            final r = (hex >> 0 & 0xff) / 0xff;
            final g = (hex >> 8 & 0xff) / 0xff;
            final b = (hex >> 16 & 0xff) / 0xff;

            if (r > 0 || g > 0 || b > 0) {
              hasColors = true;
            }

            color.setRGB(r, g, b, SRGBColorSpace);

            // Convert VOX coords (X right, Y forward, Z up) to Y-up (X right, Y up, Z back)
            List<double> toThree(int x, int y, int z) => [x - sx / 2, z - sz / 2, -y + sy / 2];

            final v0 = toThree(pos[0], pos[1], pos[2]);
            final v1 = toThree(pos[0] + du[0], pos[1] + du[1], pos[2] + du[2]);
            final v2 = toThree(pos[0] + du[0] + dv[0], pos[1] + du[1] + dv[1], pos[2] + du[2] + dv[2]);
            final v3 = toThree(pos[0] + dv[0], pos[1] + dv[1], pos[2] + dv[2]);

            final idx = vertices.length ~/ 3;

            // Winding order depends on face direction
            if (c > 0) {
              vertices.addAll([...v0, ...v1, ...v2, ...v3]);
            } else {
              vertices.addAll([...v0, ...v3, ...v2, ...v1]);
            }

            indices.addAll([idx, idx + 1, idx + 2, idx, idx + 2, idx + 3]);

            for (var corner = 0; corner < 4; corner++) {
              colors.addAll([color.r, color.g, color.b]);
            }

            // Clear mask
            for (var hh = 0; hh < h; hh++) {
              for (var ww = 0; ww < w; ww++) {
                mask[n + ww + hh * dimsU] = 0;
              }
            }

            uu += w;
            n += w;
          }
        }
      }
    }

    final geometry = BufferGeometry()
      ..setAttribute('position', Float32BufferAttribute(vertices, 3))
      ..setIndex(indices)
      ..computeVertexNormals();

    final material = MeshStandardMaterial();

    if (hasColors) {
      geometry.setAttribute('color', Float32BufferAttribute(colors, 3));
      material.vertexColors = true;
    }

    return Mesh(geometry, material);
  }

  /// Builds a 3D texture from a VOX chunk: one byte per voxel, 255 where a voxel is set.
  static Data3DTexture buildData3DTexture(VOXChunk chunk) {
    final data = chunk.data;
    final size = chunk.size;

    final offsety = size.x;
    final offsetz = size.x * size.y;

    final array = Uint8List(size.x * size.y * size.z);

    for (var j = 0; j < data.length; j += 4) {
      array[data[j] + (data[j + 1] * offsety) + (data[j + 2] * offsetz)] = 255;
    }

    return Data3DTexture(array, size.x, size.y, size.z)
      ..format = RedFormat
      ..minFilter = NearestFilter
      ..magFilter = LinearFilter
      ..unpackAlignment = 1
      ..needsUpdate = true;
  }
}

// A node of a VOX scene graph.
sealed class _VOXNode {
  _VOXNode(this.attributes);

  final Map<String, String> attributes;
}

final class _VOXTransform extends _VOXNode {
  _VOXTransform(super.attributes, this.childNodeId, this.layerId, this.frames);

  final int childNodeId;

  final int layerId;

  final List<_VOXFrame> frames;
}

final class _VOXGroup extends _VOXNode {
  _VOXGroup(super.attributes, this.childIds);

  final List<int> childIds;
}

final class _VOXShape extends _VOXNode {
  _VOXShape(super.attributes, this.models);

  // The model (chunk) ids.
  final List<int> models;
}

// A frame of a transform node: a rotation (already in Y-up) and a translation (in VOX coordinates), each optional.
class _VOXFrame {
  Matrix4? rotation;

  ({double x, double y, double z})? translation;
}

// The palette of a file without an RGBA chunk.
const List<int> _voxDefaultPalette = [
  0x00000000, 0xffffffff, 0xffccffff, 0xff99ffff, 0xff66ffff, 0xff33ffff, 0xff00ffff, 0xffffccff, //
  0xffccccff, 0xff99ccff, 0xff66ccff, 0xff33ccff, 0xff00ccff, 0xffff99ff, 0xffcc99ff, 0xff9999ff, //
  0xff6699ff, 0xff3399ff, 0xff0099ff, 0xffff66ff, 0xffcc66ff, 0xff9966ff, 0xff6666ff, 0xff3366ff, //
  0xff0066ff, 0xffff33ff, 0xffcc33ff, 0xff9933ff, 0xff6633ff, 0xff3333ff, 0xff0033ff, 0xffff00ff, //
  0xffcc00ff, 0xff9900ff, 0xff6600ff, 0xff3300ff, 0xff0000ff, 0xffffffcc, 0xffccffcc, 0xff99ffcc, //
  0xff66ffcc, 0xff33ffcc, 0xff00ffcc, 0xffffcccc, 0xffcccccc, 0xff99cccc, 0xff66cccc, 0xff33cccc, //
  0xff00cccc, 0xffff99cc, 0xffcc99cc, 0xff9999cc, 0xff6699cc, 0xff3399cc, 0xff0099cc, 0xffff66cc, //
  0xffcc66cc, 0xff9966cc, 0xff6666cc, 0xff3366cc, 0xff0066cc, 0xffff33cc, 0xffcc33cc, 0xff9933cc, //
  0xff6633cc, 0xff3333cc, 0xff0033cc, 0xffff00cc, 0xffcc00cc, 0xff9900cc, 0xff6600cc, 0xff3300cc, //
  0xff0000cc, 0xffffff99, 0xffccff99, 0xff99ff99, 0xff66ff99, 0xff33ff99, 0xff00ff99, 0xffffcc99, //
  0xffcccc99, 0xff99cc99, 0xff66cc99, 0xff33cc99, 0xff00cc99, 0xffff9999, 0xffcc9999, 0xff999999, //
  0xff669999, 0xff339999, 0xff009999, 0xffff6699, 0xffcc6699, 0xff996699, 0xff666699, 0xff336699, //
  0xff006699, 0xffff3399, 0xffcc3399, 0xff993399, 0xff663399, 0xff333399, 0xff003399, 0xffff0099, //
  0xffcc0099, 0xff990099, 0xff660099, 0xff330099, 0xff000099, 0xffffff66, 0xffccff66, 0xff99ff66, //
  0xff66ff66, 0xff33ff66, 0xff00ff66, 0xffffcc66, 0xffcccc66, 0xff99cc66, 0xff66cc66, 0xff33cc66, //
  0xff00cc66, 0xffff9966, 0xffcc9966, 0xff999966, 0xff669966, 0xff339966, 0xff009966, 0xffff6666, //
  0xffcc6666, 0xff996666, 0xff666666, 0xff336666, 0xff006666, 0xffff3366, 0xffcc3366, 0xff993366, //
  0xff663366, 0xff333366, 0xff003366, 0xffff0066, 0xffcc0066, 0xff990066, 0xff660066, 0xff330066, //
  0xff000066, 0xffffff33, 0xffccff33, 0xff99ff33, 0xff66ff33, 0xff33ff33, 0xff00ff33, 0xffffcc33, //
  0xffcccc33, 0xff99cc33, 0xff66cc33, 0xff33cc33, 0xff00cc33, 0xffff9933, 0xffcc9933, 0xff999933, //
  0xff669933, 0xff339933, 0xff009933, 0xffff6633, 0xffcc6633, 0xff996633, 0xff666633, 0xff336633, //
  0xff006633, 0xffff3333, 0xffcc3333, 0xff993333, 0xff663333, 0xff333333, 0xff003333, 0xffff0033, //
  0xffcc0033, 0xff990033, 0xff660033, 0xff330033, 0xff000033, 0xffffff00, 0xffccff00, 0xff99ff00, //
  0xff66ff00, 0xff33ff00, 0xff00ff00, 0xffffcc00, 0xffcccc00, 0xff99cc00, 0xff66cc00, 0xff33cc00, //
  0xff00cc00, 0xffff9900, 0xffcc9900, 0xff999900, 0xff669900, 0xff339900, 0xff009900, 0xffff6600, //
  0xffcc6600, 0xff996600, 0xff666600, 0xff336600, 0xff006600, 0xffff3300, 0xffcc3300, 0xff993300, //
  0xff663300, 0xff333300, 0xff003300, 0xffff0000, 0xffcc0000, 0xff990000, 0xff660000, 0xff330000, //
  0xff0000ee, 0xff0000dd, 0xff0000bb, 0xff0000aa, 0xff000088, 0xff000077, 0xff000055, 0xff000044, //
  0xff000022, 0xff000011, 0xff00ee00, 0xff00dd00, 0xff00bb00, 0xff00aa00, 0xff008800, 0xff007700, //
  0xff005500, 0xff004400, 0xff002200, 0xff001100, 0xffee0000, 0xffdd0000, 0xffbb0000, 0xffaa0000, //
  0xff880000, 0xff770000, 0xff550000, 0xff440000, 0xff220000, 0xff110000, 0xffeeeeee, 0xffdddddd, //
  0xffbbbbbb, 0xffaaaaaa, 0xff888888, 0xff777777, 0xff555555, 0xff444444, 0xff222222, 0xff111111, //
];

// A STRING: a 32-bit length and that many bytes; the value and the bytes it took.
({String value, int size}) _voxReadString(ByteData data, int offset) {
  final size = data.getUint32(offset, Endian.little);
  return (
    value: String.fromCharCodes(Uint8List.view(data.buffer, data.offsetInBytes + offset + 4, size)),
    size: 4 + size,
  );
}

// A DICT: a 32-bit count and that many key and value STRINGs; the map and the bytes it took.
({Map<String, String> value, int size}) _voxReadDict(ByteData data, int offset) {
  final dict = <String, String>{};
  final count = data.getUint32(offset, Endian.little);
  var at = offset + 4;

  for (var i = 0; i < count; i++) {
    final key = _voxReadString(data, at);
    at += key.size;

    final value = _voxReadString(data, at);
    at += value.size;

    dict[key.value] = value.value;
  }

  return (value: dict, size: at - offset);
}

// The ROTATION byte as a Y-up rotation matrix. The byte encodes a row-major 3×3 matrix with one non-zero entry per row:
// bits 0-1 the column of the first row's, bits 2-3 the second row's, bits 4, 5 and 6 the signs of the three rows'
// entries; the third row's column is the remaining one. The matrix is turned from VOX's Z-up (x right, y forward)
// to Y-up (x right, z back): C · R · C⁻¹ with x' = x, y' = z, z' = -y.
Matrix4 _voxDecodeRotation(int byte) {
  final index1 = byte & 0x3;
  final index2 = (byte >> 2) & 0x3;
  final sign1 = (byte >> 4) & 0x1 == 1 ? -1.0 : 1.0;
  final sign2 = (byte >> 5) & 0x1 == 1 ? -1.0 : 1.0;
  final sign3 = (byte >> 6) & 0x1 == 1 ? -1.0 : 1.0;

  final r = [
    [0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0],
  ];

  r[0][index1] = sign1;
  r[1][index2] = sign2;
  r[2][3 - index1 - index2] = sign3;

  return Matrix4().set(
    r[0][0],
    r[0][2],
    -r[0][1],
    0, //
    r[2][0],
    r[2][2],
    -r[2][1],
    0, //
    -r[1][0],
    -r[1][2],
    r[1][1],
    0, //
    0,
    0,
    0,
    1, //
  );
}

// Applies a transform node's name and first frame to [object]: the rotation, then the translation turned to Y-up.
void _voxApplyTransform(Object3D object, _VOXTransform node) {
  if (node.attributes['_name'] case final name?) {
    object.name = name;
  }

  if (node.frames.isEmpty) {
    return;
  }

  final frame = node.frames[0];

  if (frame.rotation case final rotation?) {
    object.applyMatrix4(rotation);
  }

  if (frame.translation case final translation?) {
    object.position.set(translation.x, translation.z, -translation.y);
  }
}

// Builds the object of the node [nodeId] and its descendants. A transform over a single-model shape becomes that
// mesh, transformed; a transform without data passes its child through; otherwise a transform or a group becomes a
// Group.
Object3D? _voxBuildObject(int nodeId, Map<int, _VOXNode> nodes, List<VOXChunk> chunks) {
  switch (nodes[nodeId]) {
    case final _VOXTransform node:
      final childNode = nodes[node.childNodeId];

      // Flatten: if child is a single-model shape, apply transform directly to mesh
      if (childNode case _VOXShape(models: [final model])) {
        final mesh = VOXLoader.buildMesh(chunks[model]);
        _voxApplyTransform(mesh, node);
        return mesh;
      }

      // If no transform, just return the child directly (avoid unnecessary group)
      if (!_voxTransforms(node)) {
        final child = _voxBuildObject(node.childNodeId, nodes, chunks);

        if (node.attributes['_name'] case final name? when child != null) {
          child.name = name;
        }

        return child;
      }

      // Otherwise create a group
      final group = Group();
      _voxApplyTransform(group, node);

      if (_voxBuildObject(node.childNodeId, nodes, chunks) case final child?) {
        group.add(child);
      }

      return group;
    case final _VOXGroup node:
      final group = Group();

      for (final childId in node.childIds) {
        if (_voxBuildObject(childId, nodes, chunks) case final child?) {
          group.add(child);
        }
      }

      return group;
    case final _VOXShape node:
      // Shape reached directly (shouldn't happen in well-formed files, but handle it)
      if (node.models case [final model]) {
        return VOXLoader.buildMesh(chunks[model]);
      }

      final group = Group();

      for (final model in node.models) {
        group.add(VOXLoader.buildMesh(chunks[model]));
      }

      return group;
    case null:
      return null;
  }
}

// Whether a transform node's first frame has a rotation or a translation.
bool _voxTransforms(_VOXTransform node) {
  if (node.frames.isEmpty) {
    return false;
  }

  if (node.frames[0].rotation != null) {
    return true;
  }

  return node.frames[0].translation != null;
}
