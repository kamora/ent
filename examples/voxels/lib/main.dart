// A voxel landscape to blast apart: rolling terrain built from a generated heightmap, orbited with OrbitControls
// (drag to turn, pinch or scroll to zoom). A click or tap on the ground blows a crater into it and the voxels fly
// out as debris, down to the bottom layer, which is bedrock; KeyR raises a fresh landscape.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ent_flutter/ent_flutter.dart';
import 'package:flutter/widgets.dart' hide Color, Texture;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(Landscape(await FlutterGpuRenderer.create(antialias: true))));
}

/// The scene and its per-frame loop, without widgets, so a test can drive it directly.
class Landscape {
  Landscape(this.renderer) {
    renderer.setClearColor(0x9cc4e4);
    camera.position.set(0, 38, 48);
    controls
      ..enableDamping = true
      ..target.set(0, 6, 0)
      ..maxPolarAngle = math.pi * 0.45
      ..update();

    scene
      ..add(HemisphereLight(0xe8f0ff, 0x6a5a48, 1.4))
      ..add(DirectionalLight(0xffffff, 2)..position.set(-3, 5, 2))
      ..add(world);
    world.add(debris);
    raise(1);

    game
      ..input.bind('blast', ['Pointer'])
      ..input.bind('raise', ['KeyR'])
      ..everyFrame((_) => frame());
    game.everyFrame(debris.update);
  }

  /// Sand, grass, dark grass, rock and snow, by height.
  static const palette = [0x000000, 0xd8c890, 0x6aa84f, 0x4e8a3a, 0x8a8076, 0xf2f4f6];

  /// The landscape's side, in voxels.
  static const size = 128;

  final FlutterGpuRenderer renderer;

  final Scene scene = Scene();

  late final Game game = Game(scene);

  final PerspectiveCamera camera = PerspectiveCamera(45, 1, 0.1, 500);

  late final OrbitControls controls = OrbitControls(camera, ControlsElement());

  final VoxelWorld world = VoxelWorld(palette: palette)..position.set(-size / 2, 0, -size / 2);

  late final VoxelDebris debris = VoxelDebris(world, capacity: 2048);

  final Raycaster raycaster = Raycaster();

  // Where the pointer went down, to tell a click from a drag that turns the view.
  Vector2? _down;

  /// Raises a fresh landscape from the heightmap of [seed], replacing what is there.
  void raise(int seed) {
    final random = math.Random(seed);
    final waves = [for (var k = 0; k < 6; k++) (random.nextDouble() * 2 * math.pi, 8 + random.nextDouble() * 30)];
    final heights = Uint8List(size * size * 4);
    final colors = Uint8List(size * size * 4);

    for (var z = 0; z < size; z++) {
      for (var x = 0; x < size; x++) {
        var height = 0.5;

        for (final (k, (phase, length)) in waves.indexed) {
          height += 0.16 * math.sin((k.isEven ? x : z) / length + phase) * math.cos((x + z) / (length * 1.7) + k);
        }

        // From 20, so every column has ground (a voxel at least), up to 255.
        final level = (20 + height.clamp(0.0, 1.0) * 235).round();
        final hex = palette[1 + [70, 125, 165, 200].where((top) => level >= top).length];
        heights[(z * size + x) * 4] = level;
        colors.setRange((z * size + x) * 4, (z * size + x) * 4 + 3, [hex >> 16 & 0xff, hex >> 8 & 0xff, hex & 0xff]);
      }
    }

    for (var x = 0; x < size; x++) {
      for (var z = 0; z < size; z++) {
        for (var y = 0; y < 32; y++) {
          world.setVoxel(x, y, z, 0);
        }
      }
    }

    world
      ..addHeightmap(heights, size, maxHeight: 24, colors: colors)
      ..update();
  }

  /// Blows a crater where [pointer] (normalized device coordinates) meets the ground, if it does, and returns how many
  /// voxels flew.
  int blast(Vector2 pointer) {
    world.updateMatrixWorld();
    raycaster.setFromCamera(pointer, camera);

    final hit = world.pick(raycaster.ray);

    if (hit == null) {
      return 0;
    }

    final center = Vector3(hit.x + 0.5, hit.y + 0.5, hit.z + 0.5);
    final removed = world.removeSphere(center, 6);

    // The bottom layer is bedrock: it stays, so no crater opens onto the sky below.
    for (final voxel in removed.where((voxel) => voxel.y == 0)) {
      world.setVoxel(voxel.x, 0, voxel.z, voxel.value);
    }

    removed.removeWhere((voxel) => voxel.y == 0);
    debris.spawn(removed, center, speed: 14);
    return removed.length;
  }

  /// One frame: a click blasts, KeyR raises a new landscape, changed chunks rebuild within 4 ms, the view damps.
  void frame() {
    final input = game.input;

    if (input.wasPressed('blast')) {
      _down = input.pointer?.clone();
    }

    if (input.wasReleased('blast')) {
      final pointer = input.pointer;

      // A click: released close to where it went down (a drag turns the view instead).
      if (pointer != null && _down != null && pointer.distanceTo(_down!) < 0.02) {
        blast(pointer);
      }
    }

    if (input.wasPressed('raise')) {
      raise(DateTime.now().millisecondsSinceEpoch);
    }

    world.update(budget: const Duration(milliseconds: 4));
    controls.update();
  }

  void dispose() {
    controls.dispose();
    world.dispose();
    debris.dispose();
    renderer.dispose();
  }
}

class App extends StatefulWidget {
  const App(this.landscape, {super.key});

  final Landscape landscape;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Landscape get landscape => widget.landscape;

  @override
  void dispose() {
    landscape.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: KeyboardInput(
        input: landscape.game.input,
        child: PointerInput(
          input: landscape.game.input,
          child: OrbitControlsListener(
            controls: landscape.controls,
            child: EntView(
              renderer: landscape.renderer,
              scene: landscape.scene,
              camera: landscape.camera,
              onFrame: landscape.game.frame,
            ),
          ),
        ),
      ),
    );
  }
}
