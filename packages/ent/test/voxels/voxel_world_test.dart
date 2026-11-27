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

  group('pick', () {
    test('matches the nearest voxel box along random rays, through a moved and scaled world', () {
      final random = math.Random(11);
      final world = VoxelWorld(palette: palette, chunkSize: 4)
        ..position.set(3, -2, 1)
        ..scale.setScalar(0.5);
      final voxels = <(int, int, int)>{};

      for (var k = 0; k < 120; k++) {
        final key = (random.nextInt(12) - 6, random.nextInt(12) - 6, random.nextInt(12) - 6);
        voxels.add(key);
        world.setVoxel(key.$1, key.$2, key.$3, 1 + random.nextInt(4));
      }

      world.updateMatrixWorld();
      var hits = 0;

      for (var k = 0; k < 300; k++) {
        final origin = Vector3(
          random.nextDouble() * 16 - 8,
          random.nextDouble() * 16 - 8,
          random.nextDouble() * 16 - 8,
        );
        // Aimed at a point of the voxels' area (world x 0 to 6, y -5 to 1, z -2 to 4), so most rays hit.
        final target = Vector3(random.nextDouble() * 6, random.nextDouble() * 6 - 5, random.nextDouble() * 6 - 2);
        final ray = Ray(origin, target.sub(origin).normalize());

        // A ray starting inside a voxel hits it at 0, which the boxes below do not show.
        final local = origin.clone().applyMatrix4(Matrix4().copy(world.matrixWorld).invert());

        if (voxels.contains((local.x.floor(), local.y.floor(), local.z.floor()))) {
          continue;
        }

        (int, int, int)? nearest;
        var best = double.infinity;

        for (final (x, y, z) in voxels) {
          final box = Box3(Vector3(x.toDouble(), y.toDouble(), z.toDouble()), Vector3(x + 1.0, y + 1.0, z + 1.0))
            ..applyMatrix4(world.matrixWorld);
          final point = ray.intersectBox(box, Vector3());

          if (point != null && point.distanceTo(origin) < best) {
            best = point.distanceTo(origin);
            nearest = (x, y, z);
          }
        }

        final hit = world.pick(ray);

        if (nearest == null) {
          expect(hit, isNull, reason: 'ray $k');
          continue;
        }

        hits++;
        expect((hit!.x, hit.y, hit.z), nearest, reason: 'ray $k');
        expect(hit.value, world.getVoxel(hit.x, hit.y, hit.z));
        expect(hit.distance, closeTo(best, 1e-9), reason: 'ray $k');
        expect(hit.point.distanceTo(ray.at(best, Vector3())), closeTo(0, 1e-9));
        expect(
          world.getVoxel(hit.x + hit.normal.x.toInt(), hit.y + hit.normal.y.toInt(), hit.z + hit.normal.z.toInt()),
          0,
        );
        expect(hit.normal.dot(ray.direction), lessThan(0), reason: 'the normal faces the ray');
      }

      expect(hits, greaterThan(100));
    });

    test('through a turned world, sees voxels update has not drawn, and stops at far', () {
      final world = VoxelWorld(palette: palette)
        ..setVoxel(0, 0, 2, 3)
        ..rotation.y = math.pi / 2
        ..updateMatrixWorld();

      // Turned a quarter around Y, the grid's +z points along world +x and its +x along world -z.
      final hit = world.pick(Ray(Vector3(-5, 0.5, -0.5), Vector3(1, 0, 0)))!;
      expect((hit.x, hit.y, hit.z, hit.value), (0, 0, 2, 3));
      expect(hit.normal.toArray(), [0.0, 0.0, -1.0]);
      expect(hit.distance, closeTo(7, 1e-12));
      expect(world.children, isEmpty);
      expect(world.pick(Ray(Vector3(-5, 0.5, -0.5), Vector3(1, 0, 0)), far: 6.9), isNull);
    });

    test('misses in an empty direction and an empty world; inside a voxel hits it at 0', () {
      final world = VoxelWorld(palette: palette)..setVoxel(0, 0, 0, 1);

      expect(VoxelWorld(palette: palette).pick(Ray(Vector3(), Vector3(1, 0, 0))), isNull);
      expect(world.pick(Ray(Vector3(0.5, 5, 0.5), Vector3(0, 1, 0))), isNull);
      expect(world.pick(Ray(Vector3(1e6, 0.5, 0.5), Vector3(-1, 0, 0)))!.distance, closeTo(1e6 - 1, 1e-6));

      // A voxel on the last row of the chunks' area, reached from inside it, along each axis and direction.
      final edges = VoxelWorld(palette: palette, chunkSize: 4)
        ..setVoxel(3, 1, 1, 2)
        ..setVoxel(0, 1, 1, 2)
        ..setVoxel(1, 3, 1, 2)
        ..setVoxel(1, 1, 3, 2);
      expect(edges.pick(Ray(Vector3(1.5, 1.5, 1.5), Vector3(1, 0, 0)))?.x, 3);
      expect(edges.pick(Ray(Vector3(1.5, 1.5, 1.5), Vector3(-1, 0, 0)))?.x, 0);
      expect(edges.pick(Ray(Vector3(1.5, 1.5, 1.5), Vector3(0, 1, 0)))?.y, 3);
      expect(edges.pick(Ray(Vector3(1.5, 1.5, 1.5), Vector3(0, 0, 1)))?.z, 3);

      final inside = world.pick(Ray(Vector3(0.5, 0.5, 0.5), Vector3(0, 0, 1)))!;
      expect(inside.distance, 0);
      expect(inside.normal.toArray(), [0, 0, 0]);
    });
  });

  test('removeSphere empties the voxels whose centers are within the radius and returns them', () {
    final random = math.Random(5);
    final voxels = <(int, int, int), int>{};
    final world = VoxelWorld(palette: palette, chunkSize: 4);

    for (var x = -6; x < 6; x++) {
      for (var y = -6; y < 6; y++) {
        for (var z = -6; z < 6; z++) {
          voxels[(x, y, z)] = 1 + random.nextInt(4);
          world.setVoxel(x, y, z, voxels[(x, y, z)]!);
        }
      }
    }

    world.update();

    final center = Vector3(1.3, -0.2, 0.7);
    final removed = world.removeSphere(center, 3.6);
    final inside = {
      for (final MapEntry(key: (x, y, z), :value) in voxels.entries)
        if (Vector3(x + 0.5, y + 0.5, z + 0.5).distanceTo(center) <= 3.6) (x, y, z): value,
    };

    expect({for (final v in removed) (v.x, v.y, v.z): v.value}, inside);
    expect(removed, hasLength(inside.length));
    expect(world.removeSphere(center, 3.6), isEmpty);

    for (final key in inside.keys) {
      voxels.remove(key);
    }

    world.update();
    expect(drawn(world), expected(voxels));
  });
}
