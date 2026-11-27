import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// VoxelWorld is Ent's own design, so there is no reference to compare with. The meshes are checked exactly against
// the voxels instead: every quad the chunk meshes draw is cut back into unit faces, and that set must equal the faces
// counted voxel by voxel (a solid voxel next to an empty one), each with its voxel's color, its normal and a winding
// that faces the normal.

const palette = [0x000000, 0xff0000, 0x00ff00, 0x3366cc, 0xffffff];

// A unit face: the solid voxel it belongs to, the axis it faces along and the direction (+1 or -1).
typedef Face = (int, int, int, int, int);

// The faces the voxels show, with their colors as float32 values (as the color attribute stores them).
Map<Face, List<double>> expected(Map<(int, int, int), int> voxels) {
  final faces = <Face, List<double>>{};

  for (final MapEntry(key: (x, y, z), :value) in voxels.entries) {
    final color = Color().setHex(palette[value]);

    for (var d = 0; d < 3; d++) {
      for (final sign in [-1, 1]) {
        final next = [x, y, z];
        next[d] += sign;

        if (!voxels.containsKey((next[0], next[1], next[2]))) {
          faces[(x, y, z, d, sign)] = Float32List.fromList([color.r, color.g, color.b]);
        }
      }
    }
  }

  return faces;
}

// The faces the world's chunk meshes draw, checking each quad's normals and winding on the way.
Map<Face, List<double>> drawn(VoxelWorld world) {
  final faces = <Face, List<double>>{};

  for (final child in world.children) {
    final mesh = child as Mesh;
    final position = mesh.geometry.getAttribute('position')!;
    final normal = mesh.geometry.getAttribute('normal')!;
    final color = mesh.geometry.getAttribute('color')!;
    final index = mesh.geometry.index!;

    for (var q = 0; q < index.count; q += 6) {
      final first = index.getX(q).toInt();
      final corners = [for (var k = 0; k < 4; k++) Vector3().fromBufferAttribute(position, first + k)];
      final n = Vector3().fromBufferAttribute(normal, first);
      final d = [n.x, n.y, n.z].indexWhere((value) => value != 0);
      final sign = [n.x, n.y, n.z][d].toInt();

      // Both triangles turn counterclockwise seen from where the normal points.
      for (final triangle in [
        [0, 1, 2],
        [0, 2, 3],
      ]) {
        final a = corners[triangle[0]];
        final cross = Vector3()
            .subVectors(corners[triangle[1]], a)
            .cross(Vector3().subVectors(corners[triangle[2]], a));
        expect(cross.dot(n), greaterThan(0), reason: '${mesh.name} quad ${q ~/ 6} winding');
      }

      final low = corners.reduce((a, b) => a.clone().min(b)).add(mesh.position);
      final high = corners.reduce((a, b) => a.clone().max(b)).add(mesh.position);
      final from = [low.x.toInt(), low.y.toInt(), low.z.toInt()];
      final to = [high.x.toInt(), high.y.toInt(), high.z.toInt()];
      final u = (d + 1) % 3;
      final v = (d + 2) % 3;
      final rgb = [color.getX(first), color.getY(first), color.getZ(first)];

      for (var a = from[u]; a < to[u]; a++) {
        for (var b = from[v]; b < to[v]; b++) {
          final cell = [0, 0, 0];
          cell[d] = sign > 0 ? from[d] - 1 : from[d];
          cell[u] = a;
          cell[v] = b;

          final face = (cell[0], cell[1], cell[2], d, sign);
          expect(faces.containsKey(face), isFalse, reason: 'face $face drawn twice');
          faces[face] = rgb.map((value) => value.toDouble()).toList();
        }
      }
    }
  }

  return faces;
}

void main() {
  test('one voxel draws a unit cube: six quads, outward normals, its color', () {
    final world = VoxelWorld(palette: palette)
      ..setVoxel(2, 3, 4, 1)
      ..update();

    expect(world.children, hasLength(1));
    expect(world.getVoxel(2, 3, 4), 1);
    expect((world.children[0] as Mesh).geometry.index!.count, 36);
    expect(drawn(world), expected({(2, 3, 4): 1}));
  });

  test('faces of one color in one plane merge; faces between voxels are not drawn', () {
    final voxels = {for (var x = 0; x < 4; x++) (x, 0, 0): 2};
    final world = VoxelWorld(palette: palette);

    for (final MapEntry(key: (x, y, z), :value) in voxels.entries) {
      world.setVoxel(x, y, z, value);
    }

    world.update();
    expect((world.children[0] as Mesh).geometry.index!.count, 36);
    expect(drawn(world), expected(voxels));

    world
      ..setVoxel(1, 0, 0, 3)
      ..update();
    expect(drawn(world), expected({...voxels, (1, 0, 0): 3}));
  });

  test('a row across chunks, negative coordinates included, has no face inside it', () {
    final voxels = {for (var x = -6; x < 7; x++) (x, -1, 5): 4};
    final world = VoxelWorld(palette: palette, chunkSize: 4);

    for (final MapEntry(key: (x, y, z), :value) in voxels.entries) {
      world.setVoxel(x, y, z, value);
    }

    world.update();
    expect(world.chunkCount, 4);
    expect(world.getVoxel(-6, -1, 5), 4);
    expect(world.getVoxel(-7, -1, 5), 0);
    expect(drawn(world), expected(voxels));
  });

  test('random edits across many chunks keep the meshes exact, and match a world built at once', () {
    final random = math.Random(7);
    final voxels = <(int, int, int), int>{};
    final world = VoxelWorld(palette: palette, chunkSize: 4);

    for (var round = 0; round < 6; round++) {
      for (var k = 0; k < 400; k++) {
        final key = (random.nextInt(14) - 7, random.nextInt(10) - 5, random.nextInt(12) - 3);
        final value = random.nextInt(3) == 0 ? 0 : 1 + random.nextInt(4);

        world.setVoxel(key.$1, key.$2, key.$3, value);

        if (value == 0) {
          voxels.remove(key);
        } else {
          voxels[key] = value;
        }
      }

      world.update();
      expect(drawn(world), expected(voxels), reason: 'round $round');
      expect(world.dirtyChunks, 0);
    }

    final fresh = VoxelWorld(palette: palette, chunkSize: 4);

    for (final MapEntry(key: (x, y, z), :value) in voxels.entries) {
      fresh.setVoxel(x, y, z, value);
    }

    fresh.update();
    expect(drawn(fresh), drawn(world));
  });

  test('a voxel on a chunk side marks the neighbouring chunk; one inside marks only its own', () {
    final world = VoxelWorld(palette: palette, chunkSize: 4)
      ..setVoxel(3, 1, 1, 1)
      ..setVoxel(4, 1, 1, 1)
      ..update();

    world.setVoxel(1, 1, 1, 2);
    expect(world.dirtyChunks, 1);
    world.update();

    world.setVoxel(4, 1, 1, 0);
    expect(world.dirtyChunks, 2);
    world.update();
    expect(world.chunkCount, 1);
    expect(drawn(world), expected({(3, 1, 1): 1, (1, 1, 1): 2}));
  });

  test('update stops at maxChunks, and at a budget after one chunk', () {
    final world = VoxelWorld(palette: palette, chunkSize: 2);

    for (var x = 0; x < 10; x += 2) {
      world.setVoxel(x, 0, 0, 1);
    }

    expect(world.dirtyChunks, 5);
    expect(world.update(maxChunks: 2), 2);
    expect(world.children, hasLength(2));
    expect(world.update(budget: Duration.zero), 1);
    expect(world.update(), 2);
    expect(world.dirtyChunks, 0);
  });

  test('emptying a chunk removes its mesh; setting a voxel to its value changes nothing', () {
    final world = VoxelWorld(palette: palette)
      ..setVoxel(0, 0, 0, 1)
      ..update()
      ..setVoxel(0, 0, 0, 1);

    expect(world.dirtyChunks, 0);

    world
      ..setVoxel(0, 0, 0, 0)
      ..setVoxel(5, 5, 5, 0)
      ..update();
    expect(world.chunkCount, 0);
    expect(world.children, isEmpty);
  });

  test('setVoxel rejects a value outside 0 to 255; the constructor a chunk size under 1', () {
    expect(() => VoxelWorld(palette: palette).setVoxel(0, 0, 0, 256), throwsArgumentError);
    expect(() => VoxelWorld(palette: palette).setVoxel(0, 0, 0, -1), throwsArgumentError);
    expect(() => VoxelWorld(palette: palette, chunkSize: 0), throwsArgumentError);
  });
}
