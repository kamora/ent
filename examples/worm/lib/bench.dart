// The CPU benchmark (docs/flutter-gpu.md, CPU cost per frame): N boxes on a grid under a fixed camera, in
// three cases, each frame turning every box. `integration_test/bench_test.dart` drives it.

import 'dart:math' as math;

import 'package:ent_flutter/ent_flutter.dart';

/// The cases: N meshes sharing a geometry and a MeshStandardMaterial; the same with a PCF shadow; one
/// InstancedMesh of N instances.
enum Case { meshes, shadowed, instanced }

/// One benchmark point: [count] boxes in [kind]'s set-up, on a ground plane.
class Bench {
  Bench(this.kind, this.count) {
    final side = math.sqrt(count).ceil();
    final step = 20 / side;
    final geometry = BoxGeometry(step * 0.6, step * 0.6, step * 0.6);
    final material = MeshStandardMaterial({'color': 0x6688cc, 'roughness': 0.6});
    final light = DirectionalLight(0xffffff, 2)..position.set(5, 12, 8);
    camera
      ..position.set(0, 24, 26)
      ..lookAt(Vector3());
    scene
      ..add(AmbientLight(0xffffff, 0.4))
      ..add(light)
      ..add(
        Mesh(PlaneGeometry(24, 24), MeshStandardMaterial({'color': 0x999999}))
          ..rotation.x = -math.pi / 2
          ..receiveShadow = kind == Case.shadowed,
      )
      ..matrixWorldAutoUpdate = false;

    for (var i = 0; i < count; i++) {
      spots.add(Vector3((i % side + 0.5) * step - 10, step * 0.3, (i ~/ side + 0.5) * step - 10));
    }

    if (kind == Case.instanced) {
      instanced = InstancedMesh(geometry, material, count);
      scene.add(instanced!);
    } else {
      for (final spot in spots) {
        final mesh = Mesh(geometry, material)
          ..position.copy(spot)
          ..castShadow = true
          ..receiveShadow = true;
        meshes.add(mesh);
        scene.add(mesh);
      }
    }

    if (kind == Case.shadowed) {
      light.castShadow = true;
      light.shadow.mapSize.set(1024, 1024);
      (light.shadow.camera as OrthographicCamera)
        ..left = -14
        ..right = 14
        ..top = 14
        ..bottom = -14;
    }
  }

  final Case kind;

  final int count;

  final Scene scene = Scene();

  final PerspectiveCamera camera = PerspectiveCamera(50, 1, 0.1, 100);

  final List<Vector3> spots = [];

  final List<Mesh> meshes = [];

  InstancedMesh? instanced;

  final Object3D _dummy = Object3D();

  /// The draw calls one frame makes: the ground and every box, and every box again in the shadow pass.
  int get calls {
    return switch (kind) {
      Case.meshes => count + 1,
      Case.shadowed => 2 * count + 1,
      Case.instanced => 2,
    };
  }

  /// Sets the renderer's shadow switch for this case.
  void setUp(FlutterGpuRenderer renderer) {
    renderer.shadowMap
      ..enabled = kind == Case.shadowed
      ..type = PCFShadowMap;
  }

  /// Turns every box to its angle at [seconds] (a matrix update per box, or per instance).
  void turn(double seconds) {
    final instanced = this.instanced;

    if (instanced == null) {
      for (var i = 0; i < meshes.length; i++) {
        meshes[i].rotation.set(0.3, seconds * 0.5 + i * 0.1, 0);
      }

      return;
    }

    for (var i = 0; i < count; i++) {
      _dummy
        ..position.copy(spots[i])
        ..rotation.set(0.3, seconds * 0.5 + i * 0.1, 0)
        ..updateMatrix();
      instanced.setMatrixAt(i, _dummy.matrix);
    }

    instanced.instanceMatrix.needsUpdate = true;
  }
}
