// Getting started: the scene of ent's README as an app. A lit cube turns in front of the camera; tap it to change
// its color, drag to orbit, scroll or pinch to zoom.
//
// flutter run -t lib/getting_started.dart -d macos

import 'package:material_ui/material_ui.dart' hide Color;
import 'package:ent_flutter/ent_flutter.dart';

/// The scene, its camera and controls, and what a frame and a tap do to them.
class GettingStarted {
  GettingStarted() {
    camera
      ..position.set(0, 1.5, 4)
      ..lookAt(Vector3(0, 0, 0));
    scene
      ..add(cube)
      ..add(AmbientLight(0xffffff, 0.3))
      ..add(DirectionalLight(0xffffff, 2)..position.set(3, 5, 2));
  }

  /// The colors a tap on the cube cycles through.
  static const colors = [0x44aa88, 0xaa4466, 0x4466aa];

  final Scene scene = Scene()..background = Color(0x202020);

  final PerspectiveCamera camera = PerspectiveCamera(60, 1, 0.1, 100);

  final Mesh cube = Mesh(BoxGeometry(1, 1, 1), MeshStandardMaterial({'color': colors[0], 'roughness': 0.4}));

  /// Orbits the camera around the cube, with inertia.
  late final OrbitControls controls = OrbitControls(camera)..enableDamping = true;

  final Raycaster _raycaster = Raycaster();

  var _color = 0;

  /// Turns the cube with the time since the view started, and moves the camera on with the controls' inertia.
  void frame(Duration elapsed) {
    cube.rotation.y = elapsed.inMicroseconds / 1e6;
    controls.update();
  }

  /// Gives the cube the next color when a ray through [ndc], the tap in normalized device coordinates, hits it.
  void tap(Vector2 ndc) {
    _raycaster.setFromCamera(ndc, camera);

    if (_raycaster.intersectObject(cube).isNotEmpty) {
      _color = (_color + 1) % colors.length;
      (cube.material! as MeshStandardMaterial).color.setHex(colors[_color]);
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterPlatform.install();
  final renderer = await FlutterGpuRenderer.create();
  final demo = GettingStarted();

  runApp(
    MaterialApp(
      title: 'Getting started',
      home: OrbitControlsListener(
        controls: demo.controls,
        child: EntView(
          renderer: renderer,
          scene: demo.scene,
          camera: demo.camera,
          onFrame: demo.frame,
          onPointerDown: (event, ndc) => demo.tap(ndc),
        ),
      ),
    ),
  );
}
