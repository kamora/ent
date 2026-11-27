part of '../../ent.dart';

/// A voxel world, Ent's own design (not part of the reference): palette indices on an unbounded integer grid, Y up,
/// split into cubic chunks of [chunkSize] voxels a side, each drawn by its own [Mesh], a child of this object. The
/// voxel (x, y, z) fills the cube from (x, y, z) to (x + 1, y + 1, z + 1) in this object's space; scale the object for
/// other voxel sizes.
///
/// [setVoxel] changes the grid and marks the chunks whose faces change; [update] rebuilds them, all at once or within
/// a count or a time budget, so a large change spreads over frames. A chunk's mesh is greedy: faces of one color in
/// one plane merge into rectangles, and faces between two solid voxels are not drawn, also across chunks.
class VoxelWorld extends Object3D {
  /// A world of chunks [chunkSize] voxels a side, colored by [palette] (`0xRRGGBB` sRGB colors; index 0, empty, is
  /// never drawn), drawn with [material] (a [MeshStandardMaterial] with vertex colors by default).
  VoxelWorld({required List<int> palette, this.chunkSize = 16, Material? material})
    : palette = List.of(palette),
      material = material ?? MeshStandardMaterial({'vertexColors': true}) {
    if (chunkSize < 1) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be positive');
    }

    type = 'VoxelWorld';
  }

  /// The voxels a chunk has along each axis.
  final int chunkSize;

  /// The colors of the palette indices, as `0xRRGGBB` sRGB values; changing it shows in chunks rebuilt afterwards.
  final List<int> palette;

  /// The material every chunk mesh shares.
  final Material material;

  final Map<(int, int, int), _VoxelChunk> _chunks = {};

  final Set<(int, int, int)> _dirty = {};

  /// How many chunks wait for [update].
  int get dirtyChunks => _dirty.length;

  /// How many chunks hold at least one voxel.
  int get chunkCount => _chunks.length;

  /// The palette index at (x, y, z), 0 where it is empty.
  int getVoxel(int x, int y, int z) {
    final local = (x % chunkSize, y % chunkSize, z % chunkSize);
    final chunk = _chunks[_chunkOf(x, y, z, local)];

    if (chunk == null) {
      return 0;
    }

    return chunk.voxels[_index(local.$1, local.$2, local.$3)];
  }

  /// Sets the voxel at (x, y, z) to the palette index [value] (0 empties it), and marks its chunk for [update],
  /// with the neighbouring chunk when the voxel lies on the chunk's side.
  void setVoxel(int x, int y, int z, int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError.value(value, 'value', 'must be a palette index from 0 to 255');
    }

    final local = (x % chunkSize, y % chunkSize, z % chunkSize);
    final key = _chunkOf(x, y, z, local);
    var chunk = _chunks[key];

    if (chunk == null) {
      if (value == 0) {
        return;
      }

      chunk = _chunks[key] = _VoxelChunk(chunkSize * chunkSize * chunkSize);
    }

    final index = _index(local.$1, local.$2, local.$3);
    final previous = chunk.voxels[index];

    if (previous == value) {
      return;
    }

    chunk.voxels[index] = value;

    if (previous == 0) {
      chunk.count++;
    }

    if (value == 0) {
      chunk.count--;
    }

    _dirty.add(key);

    for (final (axis, coordinate) in [local.$1, local.$2, local.$3].indexed) {
      if (coordinate == 0) {
        _markNeighbour(key, axis, -1);
      }

      if (coordinate == chunkSize - 1) {
        _markNeighbour(key, axis, 1);
      }
    }
  }

  /// Rebuilds the meshes of the chunks [setVoxel] changed, in the order they changed, stopping after [maxChunks]
  /// chunks or once [budget] has passed (after at least one chunk), whichever comes first; without either, all of
  /// them. Returns how many it rebuilt.
  int update({int? maxChunks, Duration? budget}) {
    final clock = Stopwatch()..start();
    var rebuilt = 0;

    while (_dirty.isNotEmpty) {
      if (maxChunks != null && rebuilt >= maxChunks) {
        break;
      }

      if (budget != null && rebuilt > 0 && clock.elapsed >= budget) {
        break;
      }

      final key = _dirty.first;
      _dirty.remove(key);
      _rebuild(key);
      rebuilt++;
    }

    return rebuilt;
  }

  /// The first solid voxel along [ray] (in world space, with a normalized direction, as [Raycaster.ray]) within [far]
  /// of its origin, or `null` when it meets none. It reads the voxels, not the meshes, so it sees changes [update] has
  /// not drawn yet. The world's [matrixWorld] must be current. A ray starting inside a solid voxel hits it at distance
  /// 0 with a zero normal.
  VoxelHit? pick(Ray ray, {double far = double.infinity}) {
    if (_chunks.isEmpty) {
      return null;
    }

    // The ray in grid space, its direction not normalized, so that a step t along it is t in world space.
    final inverse = Matrix4().copy(matrixWorld).invert();
    final origin = ray.origin.clone().applyMatrix4(inverse);
    final direction = ray.origin.clone().add(ray.direction).applyMatrix4(inverse).sub(origin);

    final o = [origin.x, origin.y, origin.z];
    final dir = [direction.x, direction.y, direction.z];
    final cell = [for (final value in o) value.floor()];
    final step = [for (final value in dir) value.sign.toInt()];
    final delta = [for (final value in dir) (1 / value).abs()];
    final next = [
      for (var a = 0; a < 3; a++)
        if (step[a] > 0)
          (cell[a] + 1 - o[a]) / dir[a]
        else if (step[a] < 0)
          (o[a] - cell[a]) / -dir[a]
        else
          double.infinity,
    ];

    // The grid area the chunks cover; once the ray is past it along an axis it moves away on, nothing is left to hit.
    final low = [1 << 62, 1 << 62, 1 << 62];
    final high = [-(1 << 62), -(1 << 62), -(1 << 62)];

    for (final (x, y, z) in _chunks.keys) {
      for (final (a, value) in [x, y, z].indexed) {
        low[a] = math.min(low[a], value * chunkSize);
        high[a] = math.max(high[a], value * chunkSize + chunkSize - 1);
      }
    }

    final normal = [0, 0, 0];
    var distance = 0.0;

    while (distance <= far) {
      final value = getVoxel(cell[0], cell[1], cell[2]);

      if (value > 0) {
        return VoxelHit._(
          cell[0],
          cell[1],
          cell[2],
          value,
          Vector3(normal[0].toDouble(), normal[1].toDouble(), normal[2].toDouble()),
          origin.clone().addScaledVector(direction, distance).applyMatrix4(matrixWorld),
          distance,
        );
      }

      var a = 0;

      if (next[1] < next[a]) {
        a = 1;
      }

      if (next[2] < next[a]) {
        a = 2;
      }

      if (next[a] == double.infinity) {
        return null;
      }

      distance = next[a];
      next[a] += delta[a];
      cell[a] += step[a];
      normal.setAll(0, [0, 0, 0]);
      normal[a] = -step[a];

      if (step[a] > 0 && cell[a] > high[a]) {
        return null;
      }

      if (step[a] < 0 && cell[a] < low[a]) {
        return null;
      }
    }

    return null;
  }

  /// Empties every voxel whose center lies within [radius] of [center], both in grid units (the voxel (x, y, z) has
  /// its center at (x + 0.5, y + 0.5, z + 0.5)), and returns the voxels it removed with their former values.
  List<({int x, int y, int z, int value})> removeSphere(Vector3 center, double radius) {
    final removed = <({int x, int y, int z, int value})>[];

    for (var x = (center.x - radius - 0.5).floor(); x <= (center.x + radius - 0.5).ceil(); x++) {
      for (var y = (center.y - radius - 0.5).floor(); y <= (center.y + radius - 0.5).ceil(); y++) {
        for (var z = (center.z - radius - 0.5).floor(); z <= (center.z + radius - 0.5).ceil(); z++) {
          final dx = x + 0.5 - center.x;
          final dy = y + 0.5 - center.y;
          final dz = z + 0.5 - center.z;

          if (dx * dx + dy * dy + dz * dz > radius * radius) {
            continue;
          }

          final value = getVoxel(x, y, z);

          if (value == 0) {
            continue;
          }

          setVoxel(x, y, z, 0);
          removed.add((x: x, y: y, z: z, value: value));
        }
      }
    }

    return removed;
  }

  /// Fills solid columns from a heightmap: [heights] holds RGBA bytes, 4 per pixel, row by row, [width] pixels a row
  /// (a decoded image's raw RGBA, such as Flutter's `Image.toByteData(format: ImageByteFormat.rawRgba)`). The pixel
  /// in column c of row r makes the column of voxels at (x + c, z + r) from [y] up, as many as its red channel scaled
  /// from 0–255 to 0–[maxHeight], rounded; a grey image reads the same. Row 0 lies at the smallest z. Each voxel gets
  /// the palette index nearest to the same pixel of [colors] (RGBA bytes of the same size; alpha ignored), or
  /// [value] without them. Columns replace nothing above their height.
  void addHeightmap(
    Uint8List heights,
    int width, {
    int maxHeight = 32,
    Uint8List? colors,
    int value = 1,
    int x = 0,
    int y = 0,
    int z = 0,
  }) {
    if (width < 1 || heights.length % (width * 4) != 0) {
      throw ArgumentError('heights must hold whole rows of $width RGBA pixels, not ${heights.length} bytes');
    }

    if (colors != null && colors.length != heights.length) {
      throw ArgumentError('colors must be as large as heights: ${colors.length} bytes, not ${heights.length}');
    }

    final nearest = <int, int>{};

    for (var pixel = 0; pixel < heights.length ~/ 4; pixel++) {
      final height = (heights[pixel * 4] * maxHeight / 255).round();
      var index = value;

      if (colors != null) {
        final rgb = colors[pixel * 4] << 16 | colors[pixel * 4 + 1] << 8 | colors[pixel * 4 + 2];
        index = nearest[rgb] ??= _nearest(rgb);
      }

      for (var level = 0; level < height; level++) {
        setVoxel(x + pixel % width, y + level, z + pixel ~/ width, index);
      }
    }
  }

  /// Disposes every chunk's geometry and [material], which the world owns, then fires the `dispose` event.
  @override
  void dispose() {
    for (final chunk in _chunks.values) {
      chunk.mesh?.geometry.dispose();
    }

    material.dispose();
    super.dispose();
  }

  // The palette index (from 1) whose color is nearest to the 0xRRGGBB [rgb], by squared distance in sRGB; the first
  // of equals.
  int _nearest(int rgb) {
    var best = 1;
    var distance = 1 << 30;

    for (var index = 1; index < palette.length; index++) {
      final dr = (palette[index] >> 16 & 0xff) - (rgb >> 16 & 0xff);
      final dg = (palette[index] >> 8 & 0xff) - (rgb >> 8 & 0xff);
      final db = (palette[index] & 0xff) - (rgb & 0xff);

      if (dr * dr + dg * dg + db * db < distance) {
        distance = dr * dr + dg * dg + db * db;
        best = index;
      }
    }

    return best;
  }

  // The chunk holding (x, y, z), whose coordinates within it are [local].
  (int, int, int) _chunkOf(int x, int y, int z, (int, int, int) local) {
    return ((x - local.$1) ~/ chunkSize, (y - local.$2) ~/ chunkSize, (z - local.$3) ~/ chunkSize);
  }

  int _index(int x, int y, int z) => x + chunkSize * (y + chunkSize * z);

  // Marks the chunk next to [key] along [axis] in [direction], when it exists.
  void _markNeighbour((int, int, int) key, int axis, int direction) {
    final neighbour = switch (axis) {
      0 => (key.$1 + direction, key.$2, key.$3),
      1 => (key.$1, key.$2 + direction, key.$3),
      _ => (key.$1, key.$2, key.$3 + direction),
    };

    if (_chunks.containsKey(neighbour)) {
      _dirty.add(neighbour);
    }
  }

  // Replaces the mesh of the chunk [key]; removes the chunk once it is empty.
  void _rebuild((int, int, int) key) {
    final chunk = _chunks[key];

    if (chunk == null) {
      return;
    }

    if (chunk.mesh case final mesh?) {
      remove(mesh);
      mesh.geometry.dispose();
      chunk.mesh = null;
    }

    if (chunk.count == 0) {
      _chunks.remove(key);
      return;
    }

    final geometry = _mesh(key, chunk);

    if (geometry == null) {
      return;
    }

    chunk.mesh = Mesh(geometry, material)
      ..name = 'chunk ${key.$1} ${key.$2} ${key.$3}'
      ..position.set((key.$1 * chunkSize).toDouble(), (key.$2 * chunkSize).toDouble(), (key.$3 * chunkSize).toDouble());
    add(chunk.mesh!);
  }

  // The greedy mesh of a chunk in its own space (its corner at the origin), or `null` when no face shows. Each face
  // belongs to the chunk of its solid voxel, so a face on the chunk's side is drawn by this chunk only when its solid
  // voxel is inside it; the voxel beyond the side is read from the neighbouring chunk.
  BufferGeometry? _mesh((int, int, int) key, _VoxelChunk chunk) {
    final size = chunkSize;
    final origin = [key.$1 * size, key.$2 * size, key.$3 * size];
    final positions = <double>[];
    final normals = <double>[];
    final colors = <double>[];
    final indices = <int>[];
    final color = Color();
    final mask = Int16List(size * size);

    // The palette index at local (a, b, c), from a neighbouring chunk when it lies outside this one.
    int voxel(List<int> local) {
      if (local.every((value) => value >= 0 && value < size)) {
        return chunk.voxels[_index(local[0], local[1], local[2])];
      }

      return getVoxel(origin[0] + local[0], origin[1] + local[1], origin[2] + local[2]);
    }

    for (var d = 0; d < 3; d++) {
      final u = (d + 1) % 3;
      final v = (d + 2) % 3;

      for (var slice = 0; slice <= size; slice++) {
        var n = 0;

        for (var vv = 0; vv < size; vv++) {
          for (var uu = 0; uu < size; uu++) {
            final pos = [0, 0, 0];
            pos[d] = slice;
            pos[u] = uu;
            pos[v] = vv;

            final infront = voxel(pos);
            pos[d] -= 1;
            final behind = voxel(pos);
            mask[n] = 0;

            // A face toward +d belongs to the voxel behind it, inside this chunk when slice ≥ 1; one toward -d to
            // the voxel in front, inside when slice < size.
            if (slice >= 1 && behind > 0 && infront == 0) {
              mask[n] = behind;
            }

            if (slice < size && infront > 0 && behind == 0) {
              mask[n] = -infront;
            }

            n++;
          }
        }

        n = 0;

        for (var vv = 0; vv < size; vv++) {
          for (var uu = 0; uu < size;) {
            final c = mask[n];

            if (c == 0) {
              uu++;
              n++;
              continue;
            }

            var w = 1;

            while (uu + w < size && mask[n + w] == c) {
              w++;
            }

            var h = 1;
            var done = false;

            while (vv + h < size && !done) {
              for (var k = 0; k < w; k++) {
                if (mask[n + k + h * size] != c) {
                  done = true;
                  break;
                }
              }

              if (!done) {
                h++;
              }
            }

            final p0 = [0.0, 0.0, 0.0];
            p0[d] = slice.toDouble();
            p0[u] = uu.toDouble();
            p0[v] = vv.toDouble();

            final p1 = [...p0];
            p1[u] += w;
            final p2 = [...p1];
            p2[v] += h;
            final p3 = [...p0];
            p3[v] += h;

            final base = positions.length ~/ 3;

            // Counterclockwise seen from the side the face looks to: u × v = +d.
            if (c > 0) {
              positions.addAll([...p0, ...p1, ...p2, ...p3]);
            } else {
              positions.addAll([...p0, ...p3, ...p2, ...p1]);
            }

            indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);

            final normal = [0.0, 0.0, 0.0];
            normal[d] = c.sign.toDouble();
            color.setHex(palette[c.abs()]);

            for (var corner = 0; corner < 4; corner++) {
              normals.addAll(normal);
              colors.addAll([color.r, color.g, color.b]);
            }

            for (var hh = 0; hh < h; hh++) {
              for (var ww = 0; ww < w; ww++) {
                mask[n + ww + hh * size] = 0;
              }
            }

            uu += w;
            n += w;
          }
        }
      }
    }

    if (positions.isEmpty) {
      return null;
    }

    return BufferGeometry()
      ..setAttribute('position', Float32BufferAttribute(positions, 3))
      ..setAttribute('normal', Float32BufferAttribute(normals, 3))
      ..setAttribute('color', Float32BufferAttribute(colors, 3))
      ..setIndex(indices)
      ..computeBoundingSphere();
  }
}

/// A voxel [VoxelWorld.pick] hit.
class VoxelHit {
  VoxelHit._(this.x, this.y, this.z, this.value, this.normal, this.point, this.distance);

  /// The voxel's grid coordinates.
  final int x, y, z;

  /// Its palette index.
  final int value;

  /// The grid direction out of the face the ray entered, each component -1, 0 or 1: the voxel at (x, y, z) plus the
  /// normal is the empty one in front of that face, where a new voxel would go.
  final Vector3 normal;

  /// Where the ray entered the voxel, in world space.
  final Vector3 point;

  /// The distance from the ray's origin to [point], in world space.
  final double distance;
}

// The voxels of one chunk and its current mesh.
class _VoxelChunk {
  _VoxelChunk(int length) : voxels = Uint8List(length);

  final Uint8List voxels;

  // How many voxels are set.
  int count = 0;

  Mesh? mesh;
}
