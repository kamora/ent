// The render proof: a rotating, depth-tested cube with MeshNormalMaterial in front of a MeshBasicMaterial
// triangle, drawn by FlutterGpuRenderer and resized with the window. Drag, pinch, scroll or two-finger drag to
// orbit, dolly and pan with OrbitControls. Run with `flutter run -t lib/proof.dart`.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:ent_flutter/ent_flutter.dart';

/// The demo scene; `rotate(seconds)` turns the cube as the frame callback does.
class DemoScene {
  DemoScene() {
    camera.position.set(0, 0.6, 3);
    camera.lookAt(Vector3());
    triangle.position.z = -0.8;
    scene
      ..add(cube)
      ..add(triangle);
  }

  final Scene scene = Scene();

  final PerspectiveCamera camera = PerspectiveCamera(50, 1, 0.1, 100);

  final Mesh cube = Mesh(BoxGeometry(1, 1, 1), MeshNormalMaterial());

  final Mesh triangle = Mesh(
    BufferGeometry()..setAttribute('position', Float32BufferAttribute([-1.2, -0.8, 0, 1.2, -0.8, 0, 0, 1.2, 0], 3)),
    MeshBasicMaterial({'color': 0xff8000}),
  );

  /// Orbits the camera around the cube, with inertia; created on first use, so the camera starts as set above.
  late final OrbitControls controls = OrbitControls(camera)..enableDamping = true;

  void rotate(double seconds) {
    cube.rotation.set(0.4, seconds * math.pi / 4, 0);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final renderer = await FlutterGpuRenderer.create();
  renderer.setClearColor(0x202020);
  runApp(DemoApp(renderer: renderer, demo: DemoScene()));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.renderer, required this.demo});

  final FlutterGpuRenderer renderer;

  final DemoScene demo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ent Engine',
      home: Scaffold(
        body: OrbitControlsListener(
          controls: demo.controls,
          child: EntView(
            renderer: renderer,
            scene: demo.scene,
            camera: demo.camera,
            onFrame: (elapsed) {
              demo.rotate(elapsed.inMicroseconds / 1e6);

              // Damping needs an update every frame.
              demo.controls.update();
            },
          ),
        ),
      ),
    );
  }
}
