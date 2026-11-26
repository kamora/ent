# ent

The scene layer of Ent Engine, a 3D engine for Dart, in pure Dart: scene graph, math, cameras, geometries,
materials, lights, animation, loaders, camera controls and post-processing. It imports no Flutter, `dart:ui` or
`dart:io`, so it runs anywhere Dart does.

`ent` does not draw. A renderer package draws its scenes: today that is
[`ent_flutter`][ent_flutter], a renderer on Flutter GPU, which also exports all of `ent`. A Flutter
app depends on `ent_flutter` only.

## A scene

```dart
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

  // Each frame, before it is drawn:
  cube.rotation.y += 0.01;

  // Picking needs no renderer: cast a ray through the center of the view.
  scene.updateMatrixWorld();
  camera.updateMatrixWorld();
  final hits = (Raycaster()..setFromCamera(Vector2(0, 0), camera)).intersectObject(cube);
  print('${hits.length} hits, the nearest ${hits.first.distance.toStringAsFixed(2)} away');
}
```

To draw it in Flutter, with `ent_flutter`:

```dart
final renderer = await FlutterGpuRenderer.create();

EntView(
  renderer: renderer,
  scene: scene,
  camera: camera,
  onFrame: (elapsed) => cube.rotation.y = elapsed.inMicroseconds / 1e6,
);
```

## What is included

- Core, math, cameras, the built-in geometries and curves, every mesh, line, points and sprite material, lights and
  shadows, `InstancedMesh`, `BatchedMesh`, `SkinnedMesh`, morph targets, `LOD`, fog and the animation system.
- Loaders: `ObjectLoader` (the JSON format), `GLTFLoader` (glTF 2.0 and GLB, with most `KHR_materials_*`
  extensions; not Draco, meshopt, KTX2 or GPU instancing), `HDRLoader`, `TextureLoader`, `FileLoader` and the
  other core loaders.
- Controls: `OrbitControls` and `MapControls`.
- Post-processing: `EffectComposer` with `RenderPass`, `OutputPass`, `CopyPass`, `FXAAPass`, `VignettePass` and
  `TuningPass` (bloom).

## Platform services

Loading images and files needs the platform: set `ImageUtils.platform` and `Loader.platform` once before loading.
`ent_flutter`'s `FlutterPlatform.install()` sets both for Flutter (data URLs, http(s) and asset keys). Without a
platform, loaders that parse what they are given (`ObjectLoader.parse`, `GLTFLoader.parse` of a GLB without images)
still work.

## Design notes

Ent Engine is based on three.js and keeps partial compatibility with its API. Where Dart or the renderer needs its
own shape, the choice is recorded, with its reason and tests, in
[the compatibility exceptions][compatibility-exceptions]. The ones a user meets first:

- No shaders at runtime: there is no `ShaderMaterial`, `RawShaderMaterial` or `onBeforeCompile`; a loader reads a
  shader material as a plain `Material`, with a warning.
- Post-processing effects are typed materials (`CopyMaterial`, `VignetteMaterial`, ...) drawn by `EffectPass`; the
  renderer owns their shaders. Bloom is `TuningPass`.
- Controls take a `ControlsElement` and plain pointer, wheel and key events instead of a DOM element; in Flutter,
  `OrbitControlsListener` feeds them.
- Ranges, raycast hits and camera views are small typed classes, not maps.

More usage, for controls, GLTFLoader and post-processing, is in [`docs/usage.md`][usage].

## Status

Version `0.1.0-dev.3`, a preview: the API may still change before 0.1.0. The API is listed in `test/api.txt`,
which `test/api_test.dart` checks, so every change to it is deliberate.

```sh
dart test
```

The tests compare ent with reference values in [`fixtures/`][fixtures], written by the scripts in
[`tool/reference/js/`][reference].

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

The notices of the third-party code it builds on are in `THIRD_PARTY_NOTICES.md`.

[ent_flutter]: https://github.com/kamora/ent/tree/master/packages/ent_flutter
[compatibility-exceptions]: https://github.com/kamora/ent/blob/master/docs/compatibility-exceptions.md
[usage]: https://github.com/kamora/ent/blob/master/docs/usage.md
[fixtures]: https://github.com/kamora/ent/tree/master/fixtures
[reference]: https://github.com/kamora/ent/tree/master/tool/reference/js
