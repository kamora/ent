// A lit cube in a scene, turned for a few frames and picked with a ray through the center of the view. Nothing is
// drawn: a renderer package (ent_flutter in a Flutter app) draws the same scene.
//
// dart run example/ent_example.dart

import 'package:ent/ent.dart';

void main() {
  final scene = Scene()..background = Color(0x202020);
  final camera = PerspectiveCamera(60, 16 / 9, 0.1, 100)..position.set(0, 1.5, 4);
  camera.lookAt(Vector3(0, 0, 0));

  final cube = Mesh(BoxGeometry(1, 1, 1), MeshStandardMaterial({'color': 0x44aa88, 'roughness': 0.4}));
  scene
    ..add(cube)
    ..add(AmbientLight(0xffffff, 0.3))
    ..add(DirectionalLight(0xffffff, 2)..position.set(3, 5, 2));

  // What a frame callback would do before each frame is drawn.
  for (var frame = 0; frame < 60; frame++) {
    cube.rotation.y += 0.01;
  }

  // Picking needs no renderer.
  scene.updateMatrixWorld();
  camera.updateMatrixWorld();
  final hits = (Raycaster()..setFromCamera(Vector2(0, 0), camera)).intersectObject(cube);
  print('${hits.length} hits, the nearest ${hits.first.distance.toStringAsFixed(2)} away');
}
