import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// VoxelDebris is Ent's own design: checked against what it promises. Pieces fall, land on and bounce off voxels
// without ever overlapping one, take their voxel's color, fly away from the blast and go after their lifetime.

const palette = [0x000000, 0xff0000, 0x00ff00, 0x3366cc];

// A floor of voxels from (-8, 0, -8) to (7, 0, 7), so its top is at y = 1.
VoxelWorld floor() {
  final world = VoxelWorld(palette: palette, chunkSize: 4);

  for (var x = -8; x < 8; x++) {
    for (var z = -8; z < 8; z++) {
      world.setVoxel(x, 0, z, 1);
    }
  }

  return world;
}

// Where piece [index] is, from its instance matrix.
Vector3 at(VoxelDebris debris, int index) => Vector3().setFromMatrixPosition(debris.getMatrixAt(index, Matrix4()));

// Whether a piece's cube at [position] overlaps a solid voxel (by more than a rounding error).
bool overlaps(VoxelDebris debris, Vector3 position) {
  final half = debris.size / 2 - 1e-4;

  for (var x = (position.x - half).floor(); x <= (position.x + half).floor(); x++) {
    for (var y = (position.y - half).floor(); y <= (position.y + half).floor(); y++) {
      for (var z = (position.z - half).floor(); z <= (position.z + half).floor(); z++) {
        if (debris.world.getVoxel(x, y, z) != 0) {
          return true;
        }
      }
    }
  }

  return false;
}

// Runs [debris] for [seconds] in frames of [delta], checking after each that no piece overlaps a voxel.
void run(VoxelDebris debris, double seconds, {double delta = 1 / 60}) {
  for (var time = 0.0; time < seconds; time += delta) {
    debris.update(delta);

    for (var index = 0; index < debris.count; index++) {
      expect(overlaps(debris, at(debris, index)), isFalse, reason: 'piece $index at ${at(debris, index).toArray()}');
    }
  }
}

void main() {
  test('a piece falls, lands on the floor and comes to rest there', () {
    final debris = VoxelDebris(floor(), random: math.Random(1), lifetime: 10);

    debris.spawn([(x: 0, y: 6, z: 0, value: 2)], Vector3(0.5, 6.5, 0.5), speed: 0);
    expect(at(debris, 0).toArray(), [0.5, 6.5, 0.5]);

    run(debris, 3);
    expect(at(debris, 0).y, closeTo(1 + debris.size / 2, 1e-3), reason: 'resting on the floor top');
    expect(at(debris, 0).x, 0.5);

    final before = at(debris, 0);
    run(debris, 0.5);
    expect(at(debris, 0).distanceTo(before), lessThan(1e-3), reason: 'it stays');
  });

  test('a blast scatters pieces away from its center, upwards, in their voxels\' colors, never into voxels', () {
    final world = floor();

    for (var x = -2; x < 2; x++) {
      for (var z = -2; z < 2; z++) {
        world.setVoxel(x, 1, z, x < 0 ? 2 : 3);
      }
    }

    final debris = VoxelDebris(world, random: math.Random(2));
    final center = Vector3(0, 1.5, 0);
    final removed = world.removeSphere(center, 3);
    debris.spawn(removed, center);

    expect(debris.count, removed.length);

    final starts = [for (var index = 0; index < debris.count; index++) at(debris, index)];

    for (final (index, voxel) in removed.indexed) {
      expect(debris.getColorAt(index, Color()).getHex(), Color().setHex(palette[voxel.value]).getHex());
    }

    debris.update(1 / 60);

    for (var index = 0; index < debris.count; index++) {
      final away = Vector2(starts[index].x - center.x, starts[index].z - center.z);
      final moved = Vector2(at(debris, index).x - starts[index].x, at(debris, index).z - starts[index].z);
      expect(moved.dot(away), greaterThan(0), reason: 'piece $index flies away from the center');
    }

    run(debris, 2.5);
  });

  test('a piece wider than a voxel lands on a ledge under its edge', () {
    final world = floor()..setVoxel(1, 1, 0, 1);
    final debris = VoxelDebris(world, random: math.Random(6), size: 1.2, lifetime: 10);

    // Centered over x = 0.5, the piece spans x from -0.1 to 1.1: its edge is over the ledge at x = 1.
    debris.spawn([(x: 0, y: 5, z: 0, value: 1)], Vector3(0.5, 5.5, 0.5), speed: 0);
    run(debris, 3);
    expect(at(debris, 0).y, closeTo(2 + debris.size / 2, 1e-3), reason: 'on the ledge, not the floor');
  });

  test('a piece thrown along the floor slides to a stop on it', () {
    final debris = VoxelDebris(floor(), random: math.Random(7), lifetime: 10);
    debris.spawn([(x: 0, y: 1, z: 0, value: 1)], Vector3(-1, 1.5, 0.5));

    run(debris, 3);
    final rest = at(debris, 0);
    expect(rest.y, closeTo(1 + debris.size / 2, 1e-3), reason: 'on the floor, which ends at x = 8');
    expect(rest.x, greaterThan(0.5));

    run(debris, 0.5);
    expect(at(debris, 0).distanceTo(rest), lessThan(1e-3), reason: 'stopped');
  });

  test('a fast piece bounces off a wall one voxel thick, even in a long frame', () {
    final world = floor();

    for (var y = 1; y < 6; y++) {
      for (var z = -8; z < 8; z++) {
        world.setVoxel(3, y, z, 1);
      }
    }

    final debris = VoxelDebris(world, random: math.Random(3), gravity: 0, bounce: 0.5);
    debris.spawn([(x: 0, y: 2, z: 0, value: 1)], Vector3(-1, 2.5, 0.5), speed: 40);

    // At up to 40 voxels a second, a frame of 0.2 s would jump eight voxels without steps.
    run(debris, 0.6, delta: 0.2);
    expect(at(debris, 0).x, lessThan(3 - debris.size / 2), reason: 'still on this side of the wall');
  });

  test('pieces shrink over the last quarter of their lifetime and then go', () {
    final debris = VoxelDebris(floor(), random: math.Random(4), lifetime: 2);
    debris.spawn([(x: 0, y: 3, z: 0, value: 1)], Vector3(0.5, 3.5, 0.5), speed: 0);

    double scale() => debris.getMatrixAt(0, Matrix4()).getMaxScaleOnAxis();

    debris.update(1);
    expect(scale(), closeTo(debris.size, 1e-6));

    debris.update(0.75);
    expect(scale(), closeTo(debris.size / 2, 1e-6), reason: 'halfway through the last quarter');

    debris.update(0.25);
    expect(debris.count, 0);
  });

  test('at capacity, new pieces replace the oldest', () {
    final debris = VoxelDebris(floor(), random: math.Random(5), capacity: 3);

    debris.spawn([for (var x = 0; x < 2; x++) (x: x, y: 5, z: 0, value: 1)], Vector3(0, 5.5, 0.5));
    debris.update(0.1);
    debris.spawn([for (var x = 4; x < 6; x++) (x: x, y: 5, z: 0, value: 3)], Vector3(4, 5.5, 0.5));

    expect(debris.count, 3);
    expect(
      [for (var index = 0; index < 3; index++) debris.getColorAt(index, Color()).getHex()],
      [0xff0000, 0x3366cc, 0x3366cc],
      reason: 'one of the two old pieces made room',
    );
  });
}
