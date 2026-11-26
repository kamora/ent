// The animation loop: two skinned bars driven by an AnimationMixer in a EntView, the scene of the parity test
// `anim_skinned` (tool/reference/render/scenes.mjs). Run with `flutter run -t lib/animation.dart`.

import 'package:material_ui/material_ui.dart' hide Material;
import 'package:ent_flutter/ent_flutter.dart';

/// `anim_skinned`: the left bar (attached, MeshBasicMaterial) plays `bend` at weight 0.7 and `lift` at 0.6; the
/// right one (detached, MeshNormalMaterial) fades `sway` out and `twist` in over 0.8 s, `twist` ping-ponging.
class AnimatedScene {
  AnimatedScene() {
    camera.position.set(0, 0, 3);
    final left = bar(MeshBasicMaterial({'color': 0xff8844}), -0.5, -0.05);
    final right = bar(MeshNormalMaterial(), 0.55, 0.03, detached: true);
    final foot = left.skeleton!.bones[0].position;
    scene.add(left);
    scene.add(right);

    final actions = [
      ...play(left, [
        AnimationClip('bend', -1, [
          QuaternionKeyframeTrack(
            'middle.quaternion',
            [0, 0.5, 1],
            [...turn(0, 0, 0), ...turn(0.5, 0, 0.7), ...turn(0, 0, 0)],
          ),
        ]),
        AnimationClip('lift', -1, [
          VectorKeyframeTrack(
            'root.position',
            [0, 0.8],
            [foot.x, foot.y, foot.z, foot.x + 0.15, foot.y + 0.23, foot.z],
          ),
        ]),
      ]),
      ...play(right, [
        AnimationClip('sway', -1, [
          QuaternionKeyframeTrack('middle.quaternion', [0, 0.6], [...turn(0, 0, 0), ...turn(-0.7, 0.3, -0.4)]),
        ]),
        AnimationClip('twist', -1, [
          QuaternionKeyframeTrack('middle.quaternion', [0, 0.5], [...turn(0, 0, 0), ...turn(0.4, 0.5, 0.6)]),
        ]),
      ]),
    ];
    actions[0].setEffectiveWeight(0.7);
    actions[1].setEffectiveWeight(0.6);
    actions[2].fadeOut(0.8);
    actions[3]
      ..fadeIn(0.8)
      ..setLoop(LoopPingPong, double.infinity);
  }

  final Scene scene = Scene();

  final PerspectiveCamera camera = PerspectiveCamera(50, 1, 0.1, 100);

  late final AnimationMixer mixer = AnimationMixer(scene);

  /// The animation timer: it reads `performanceNow`, a monotonic clock.
  final Timer timer = Timer();

  /// The loop, as in the reference: the timer is updated once per frame and the mixer advanced by its delta. EntView calls
  /// it before each render; it is not called while the view is paused, so the first delta after a pause spans it.
  void frame(Duration elapsed) {
    timer.update();
    mixer.update(timer.getDelta());
  }

  List<AnimationAction> play(SkinnedMesh mesh, List<AnimationClip> clips) {
    mesh.animations.addAll(clips);
    return [for (final clip in clips) mixer.clipAction(clip, mesh)!..play()];
  }

  static List<double> turn(double x, double y, double z) => Quaternion().setFromEuler(Euler(x, y, z)).toArray();

  // A vertical bar of 8 quads, 0.4 × 1.6, skinned to two bones: `root` at its foot, `middle` at its middle; the
  // weights blend linearly between y = -0.4 and 0.4. The bones are the mesh's children, or the scene's when
  // [detached].
  SkinnedMesh bar(Material material, double x, double y, {bool detached = false}) {
    final positions = <double>[], normals = <double>[], indices = <int>[], skinIndices = <int>[], weights = <double>[];

    for (var i = 0; i <= 8; i++) {
      final v = -0.8 + 0.2 * i;
      final w = ((v + 0.4) / 0.8).clamp(0.0, 1.0);

      for (final u in [-0.2, 0.2]) {
        positions.addAll([u, v, 0]);
        normals.addAll([0, 0, 1]);
        skinIndices.addAll([0, 1, 0, 0]);
        weights.addAll([1 - w, w, 0, 0]);
      }

      if (i < 8) {
        indices.addAll([2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 1, 2 * i + 3, 2 * i + 2]);
      }
    }

    final geometry = BufferGeometry()
      ..setAttribute('position', Float32BufferAttribute(positions, 3))
      ..setAttribute('normal', Float32BufferAttribute(normals, 3))
      ..setAttribute('skinIndex', Uint16BufferAttribute(skinIndices, 4))
      ..setAttribute('skinWeight', Float32BufferAttribute(weights, 4))
      ..setIndex(indices);
    final mesh = SkinnedMesh(geometry, material)..position.set(x, y, 0);
    final root = Bone()
      ..name = 'root'
      ..position.set(x, y - 0.8, 0);
    final middle = Bone()
      ..name = 'middle'
      ..position.y = 0.8;
    root.add(middle);

    if (detached) {
      mesh.bindMode = DetachedBindMode;
      scene.add(root);
    } else {
      root.position.sub(mesh.position);
      mesh.add(root);
    }

    mesh.updateMatrixWorld(true);
    root.updateMatrixWorld(true);
    mesh.bind(Skeleton([root, middle]), mesh.matrixWorld);
    return mesh;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final renderer = await FlutterGpuRenderer.create();
  final animated = AnimatedScene();
  renderer.setClearColor(0x202020);

  // Pipelines are built while loading, not on the first frames (docs/flutter-gpu.md, Pipeline compile cost).
  await renderer.compileAsync(animated.scene, animated.camera);
  runApp(
    MaterialApp(
      title: 'Ent Engine animation',
      home: Scaffold(
        body: EntView(renderer: renderer, scene: animated.scene, camera: animated.camera, onFrame: animated.frame),
      ),
    ),
  );
}
