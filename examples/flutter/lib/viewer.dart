// The example viewer: a skinned, textured glTF worm (assets/worm.glb, written by
// tool/reference/js/worm_glb.mjs) on a ground plane, lit by a hemisphere light and a directional light that
// casts PCF shadows, its `wiggle` clip looping through an AnimationMixer, orbited with OrbitControls (damping on).
// The pipelines are warmed with compileAsync while a loading state shows. Run with `flutter run -t lib/viewer.dart`.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:ent_flutter/ent_flutter.dart';

/// The scene, its loading and its per-frame loop, without widgets, so a test can drive it directly.
class Viewer {
  Viewer(this.renderer) {
    renderer
      ..setClearColor(0x9fb4c8)
      ..shadowMap.enabled = true
      ..shadowMap.type = PCFShadowMap;
    camera.position.set(2.6, 2.2, 3.6);
    controls.target.set(0, 0.9, 0);
    controls.update();

    light.position.copy(sun);
    light.castShadow = true;
    light.shadow.mapSize.set(1024, 1024);
    (light.shadow.camera as OrthographicCamera)
      ..left = -2
      ..right = 2
      ..top = 2
      ..bottom = -2
      ..near = 1
      ..far = 14;
    light.shadow.bias = -0.0005;
    ground.rotation.x = -math.pi / 2;
    ground.receiveShadow = true;
    scene
      ..add(HemisphereLight(0xdde8ff, 0x5a4a3a, 1.2))
      ..add(light)
      ..add(ground);
  }

  /// The direction the sunlight comes from, as the light's position (its target is the origin).
  static final Vector3 sun = Vector3(-3, 6, 2);

  final FlutterGpuRenderer renderer;

  final Scene scene = Scene();

  final PerspectiveCamera camera = PerspectiveCamera(45, 1, 0.1, 100);

  // Connected from the start, as the reference connects controls created with an element, so [dispose] can disconnect
  // them even when no view ever showed.
  late final OrbitControls controls = OrbitControls(camera, ControlsElement())..enableDamping = true;

  final DirectionalLight light = DirectionalLight(0xffffff, 2.2);

  final Mesh ground = Mesh(PlaneGeometry(8, 8), MeshStandardMaterial({'color': 0xc8c2b0, 'roughness': 0.9}));

  late final AnimationMixer mixer = AnimationMixer(scene);

  /// The animation timer: the mixer advances by its delta once per frame.
  final Timer timer = Timer();

  /// The loaded asset; null while loading.
  GLTF? gltf;

  /// Set once compileAsync has completed.
  bool compiled = false;

  /// Set by [dispose]; a load still running then stops.
  bool disposed = false;

  /// Frames whose loop ran before compileAsync completed: none, since the view is built only after it.
  int early = 0;

  /// Parses the glTF bytes, adds the model, starts its clips and warms the pipelines with compileAsync.
  Future<void> load(ByteBuffer data) async {
    final asset = await GLTFLoader().parseAsync(data);

    if (disposed) {
      return;
    }

    asset.scene!.traverse((object) {
      if (object is Mesh) {
        object.castShadow = true;
      }
    });
    scene.add(asset.scene!);

    for (final clip in asset.animations) {
      mixer.clipAction(clip)!.play();
    }

    gltf = asset;
    await renderer.compileAsync(scene, camera);
    compiled = true;
    timer.reset();
  }

  /// The loop, called by the view before each render.
  void frame(Duration elapsed) {
    if (!compiled) {
      early++;
    }

    timer.update();
    mixer.update(timer.getDelta());
    controls.update();
  }

  /// Stops the clips and releases the controls, geometries, materials and textures (the renderer is the app's).
  void dispose() {
    disposed = true;
    mixer
      ..stopAllAction()
      ..uncacheRoot(scene);
    controls.dispose();
    scene.traverse((object) {
      if (object is Mesh) {
        object.geometry.dispose();

        for (final material in [?object.material].expand((m) => m is List ? m : [m])) {
          if (material is MeshStandardMaterial) {
            material.map?.dispose();
          }

          (material as Material).dispose();
        }
      }
    });
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterPlatform.install();
  runApp(const MaterialApp(title: 'Ent Engine viewer', home: ViewerPage()));
}

/// Creates the renderer and the viewer, loads the asset, then shows the view; disposes everything with itself.
class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, this.viewer});

  /// A viewer that is already loaded (tests); when null, the page creates and loads its own.
  final Viewer? viewer;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  // The viewer shown, set once it is loaded.
  Viewer? _viewer;

  // The viewer this page created, released with it.
  Viewer? _own;

  Object? _error;

  @override
  void initState() {
    super.initState();

    if (widget.viewer != null) {
      _viewer = widget.viewer;
    } else {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final renderer = await FlutterGpuRenderer.create();

      // The page went away while the renderer was created: nothing else holds it.
      if (!mounted) {
        renderer.dispose();
        return;
      }

      final viewer = _own = Viewer(renderer);
      await viewer.load((await rootBundle.load('assets/worm.glb')).buffer);

      if (mounted) {
        setState(() => _viewer = viewer);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  void dispose() {
    if (_own case final viewer?) {
      viewer
        ..dispose()
        ..renderer.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;

    return Scaffold(
      body: viewer == null
          ? Center(child: Text(_error == null ? 'Loading…' : 'Failed: $_error'))
          : OrbitControlsListener(
              controls: viewer.controls,
              child: EntView(
                renderer: viewer.renderer,
                scene: viewer.scene,
                camera: viewer.camera,
                onFrame: viewer.frame,
              ),
            ),
    );
  }
}
