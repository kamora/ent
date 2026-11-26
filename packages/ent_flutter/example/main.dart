// A lit cube turning in an EntView; drag to orbit, scroll or pinch to zoom. The app around it enables Flutter GPU
// (README, Requirements) and registers the one shader variant it draws with, "physical" (MeshStandardMaterial). More
// examples, a glTF viewer with shadows and animation among them, are in the repository's examples/worm.

import 'package:material_ui/material_ui.dart' hide Color;
import 'package:ent_flutter/ent_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final renderer = await FlutterGpuRenderer.create();
  final camera = PerspectiveCamera(60, 1, 0.1, 100)
    ..position.set(0, 1.5, 4)
    ..lookAt(Vector3(0, 0, 0));
  final cube = Mesh(BoxGeometry(1, 1, 1), MeshStandardMaterial({'color': 0x44aa88, 'roughness': 0.4}));
  final scene = Scene()
    ..background = Color(0x202020)
    ..add(cube)
    ..add(AmbientLight(0xffffff, 0.3))
    ..add(DirectionalLight(0xffffff, 2)..position.set(3, 5, 2));
  final controls = OrbitControls(camera)..enableDamping = true;

  runApp(
    MaterialApp(
      home: OrbitControlsListener(
        controls: controls,
        child: EntView(
          renderer: renderer,
          scene: scene,
          camera: camera,
          onFrame: (elapsed) {
            cube.rotation.y = elapsed.inMicroseconds / 1e6;

            // Damping needs an update every frame.
            controls.update();
          },
        ),
      ),
    ),
  );
}
