part of '../../ent.dart';

/// Flying pieces of a [VoxelWorld], Ent's own design (not part of the reference): small cubes, drawn as one instanced
/// mesh, that fall, bounce off the world's voxels and shrink away. Add it to the world (`world.add(debris)`), so it
/// works in the world's grid units and follows its transform; [spawn] turns removed voxels (as
/// [VoxelWorld.removeSphere] returns them) into pieces, and [update] moves them, usually every frame:
/// `game.everyFrame(debris.update)`.
///
/// A piece is a cube of [size] grid units colored like its voxel. It moves one axis at a time: when its leading face
/// would enter a solid voxel, it stops at that voxel's face and bounces back with [bounce] of its speed, and a landing
/// slows its sliding by [friction]. Fast pieces move in steps of at most half a voxel, so they do not pass through a
/// wall one voxel thick. Pieces live [lifetime] seconds and shrink over the last quarter of it; at [capacity], new
/// pieces replace the oldest.
class VoxelDebris extends InstancedMesh {
  /// Debris of [world]'s voxels, up to [capacity] pieces; [random] makes the scatter repeatable.
  VoxelDebris(
    this.world, {
    this.capacity = 1024,
    this.size = 0.5,
    this.lifetime = 3,
    this.gravity = 30,
    this.bounce = 0.4,
    this.friction = 0.8,
    math.Random? random,
  }) : _random = random ?? math.Random(),
       super(BoxGeometry(1, 1, 1), MeshStandardMaterial(), capacity) {
    type = 'VoxelDebris';
    count = 0;
    frustumCulled = false;
    setColorAt(0, Color(0xffffff));
  }

  /// The world whose voxels the pieces bounce off.
  final VoxelWorld world;

  /// The most pieces at once.
  final int capacity;

  /// The edge of a piece, in grid units.
  double size;

  /// How long a piece lives, in seconds.
  double lifetime;

  /// The downward acceleration, in grid units per second squared.
  double gravity;

  /// The share of its speed a piece keeps, reversed, when it hits a voxel.
  double bounce;

  /// The share of its sliding speed a piece keeps when it lands.
  double friction;

  final math.Random _random;

  final List<_VoxelPiece> _pieces = [];

  /// Turns [voxels] into pieces at their centers, flying away from [center] (in grid units) at up to [speed] grid units
  /// a second, and upwards; each piece takes its voxel's palette color.
  void spawn(List<({int x, int y, int z, int value})> voxels, Vector3 center, {double speed = 8}) {
    final color = Color();

    for (final voxel in voxels) {
      final position = Vector3(voxel.x + 0.5, voxel.y + 0.5, voxel.z + 0.5);
      final direction = position.clone().sub(center);

      if (direction.lengthSq() == 0) {
        direction.set(_random.nextDouble() - 0.5, 1, _random.nextDouble() - 0.5);
      }

      direction.normalize().multiplyScalar(speed * (0.5 + _random.nextDouble() / 2));
      direction.y += speed * _random.nextDouble() / 2;

      if (_pieces.length == capacity) {
        _pieces.remove(_pieces.reduce((a, b) => a.age >= b.age ? a : b));
      }

      _pieces.add(_VoxelPiece(position, direction, color.setHex(world.palette[voxel.value]).clone()));
    }

    _write();
  }

  /// Moves the pieces [delta] seconds on, and removes those past their [lifetime].
  void update(double delta) {
    _pieces.removeWhere((piece) => (piece.age += delta) >= lifetime);

    for (final piece in _pieces) {
      piece.velocity.y -= gravity * delta;

      final steps = math.max(1, (piece.velocity.length() * delta / 0.5).ceil());

      for (var step = 0; step < steps; step++) {
        for (var axis = 0; axis < 3; axis++) {
          _move(piece, axis, delta / steps);
        }
      }
    }

    _write();
  }

  // Moves [piece] along [axis] for [time] seconds, stopping and bouncing at a solid voxel.
  void _move(_VoxelPiece piece, int axis, double time) {
    final speed = piece.velocity.getComponent(axis);

    if (speed == 0) {
      return;
    }

    final half = size / 2;
    final position = piece.position;
    position.setComponent(axis, position.getComponent(axis) + speed * time);

    // The cell the leading face is in, and the cells the piece's other two extents cover.
    final lead = (position.getComponent(axis) + (speed > 0 ? half : -half)).floor();
    final u = (axis + 1) % 3;
    final v = (axis + 2) % 3;

    for (var a = (position.getComponent(u) - half).floor(); a <= (position.getComponent(u) + half).floor(); a++) {
      for (var b = (position.getComponent(v) - half).floor(); b <= (position.getComponent(v) + half).floor(); b++) {
        final cell = [0, 0, 0];
        cell[axis] = lead;
        cell[u] = a;
        cell[v] = b;

        if (world.getVoxel(cell[0], cell[1], cell[2]) == 0) {
          continue;
        }

        // Back to the voxel's face, just outside it, and bounce.
        position.setComponent(axis, speed > 0 ? lead - half - 1e-6 : lead + 1 + half + 1e-6);
        piece.velocity.setComponent(axis, -speed * bounce);

        if (axis == 1 && speed < 0) {
          piece.velocity
            ..x *= friction
            ..z *= friction;
        }

        return;
      }
    }
  }

  // Writes the pieces into the instances: position, size (shrinking over the last quarter of the lifetime), color.
  void _write() {
    final matrix = Matrix4();
    final scale = Vector3();

    for (final (index, piece) in _pieces.indexed) {
      scale.setScalar(size * math.min(1, (lifetime - piece.age) / (lifetime / 4)));
      setMatrixAt(index, matrix.compose(piece.position, _voxelDebrisTurn, scale));
      setColorAt(index, piece.color);
    }

    count = _pieces.length;
    instanceMatrix.needsUpdate = true;
    instanceColor!.needsUpdate = true;
  }
}

final _voxelDebrisTurn = Quaternion();

// One piece: where it is, how it moves, its color and how long it has lived.
class _VoxelPiece {
  _VoxelPiece(this.position, this.velocity, this.color);

  final Vector3 position;

  final Vector3 velocity;

  final Color color;

  double age = 0;
}
