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
  extensions; not Draco, meshopt, KTX2 or GPU instancing), `HDRLoader`, `VOXLoader` (MagicaVoxel models and scene
  graphs, built into meshes), `TextureLoader`, `FileLoader` and the other core loaders.
- Controls: `OrbitControls` and `MapControls`.
- Post-processing: `EffectComposer` with `RenderPass`, `OutputPass`, `CopyPass`, `FXAAPass`, `VignettePass` and
  `TuningPass` (bloom).
- A game layer: a game loop, timers and tweens owned by scene objects, an input map, and voxel worlds (below).

## Game layer

Ent's own design, not part of the reference: a `Game` over a scene that a frame tick drives, with timers, tweens and
input in game time.

```dart
import 'package:ent_flutter/ent_flutter.dart';

final scene = Scene();
final game = Game(scene);

final door = Mesh(BoxGeometry(1, 2, 0.1), MeshStandardMaterial());
scene.add(door);

// Two seconds into the game the door slides open; while it is in the scene.
game.after(2, () => game.move(door, Vector3(1.2, 0, 0), 1.5, easing: Ease.inOutCubic), owner: door);

game.input
  ..bind('jump', ['Space', 'GamepadA'])
  ..bindAxis('moveX', negative: ['KeyA', 'ArrowLeft'], positive: ['KeyD', 'ArrowRight'], analog: ['LeftStickX']);

// In the widget tree, EntView drives the game:
EntView(renderer: renderer, scene: scene, camera: camera, onFrame: game.frame);
```

- The loop: `Game.update(delta)` advances game time by `delta` real seconds times `timeScale`; nothing moves while
  `paused`. `Game.frame(elapsed)` does the same from a running total, as `EntView`'s `onFrame` passes it.
  `Game.mixers` advance by game time, so animations pause and slow down with the game.
- Tasks: `after`, `every` and `everyFrame` run code in game time. A task with an `owner` runs while that object is in
  the scene and ends the first frame it is not, so removing an object ends what it scheduled. `Task.cancel` and
  `Game.cancelAll(owner)` end tasks early; `Task.done` completes `true` when a task ran to its end, `false` otherwise.
- Tweens: `move`, `turn`, `face`, `resize` (scale), `fade` (a material's opacity) and `tween` (any number) change a
  value over game time, after an optional `delay`, along an `Ease` curve or your own. Each reads its start value when
  it starts; a new tween of the same kind on the same target replaces the running one (`turn` and `face` are one
  kind). `await game.move(...).done` waits for it.
- Input: game code reads actions (`isDown`, `wasPressed`, `wasReleased`) and axes (`axis`, from -1 to 1) by name.
  Sources are names too: keys by their W3C `KeyboardEvent.code` (`'KeyW'`, `'Space'`), gamepad and joystick parts by
  the names an adapter gives them; an adapter reports them with `press`, `release` and `move`. `Game.update` ends the
  input frame, also while paused, so `wasPressed` holds for exactly one frame.
- In Flutter, the renderer packages bring the adapter: wrap the view in `KeyboardInput(input: game.input, child: ...)`
  for the keyboard (and gamepad buttons the platform sends as keys), and add a `Joystick` (sources `'JoystickX'` and
  `'JoystickY'`) or `TouchButton`s on touch screens.
- Voxels: `VoxelWorld` is an object holding palette indices on an unbounded grid, split into chunks (16 voxels a
  side by default), each drawn as one greedy mesh with vertex colors. `setVoxel` marks the chunks a change affects;
  `update` rebuilds them, all at once or within `maxChunks` or a time `budget`, so a large change spreads over
  frames: `game.everyFrame((_) => world.update(budget: const Duration(milliseconds: 4)))`. `pick(ray)` finds the
  first voxel along a world-space ray (`Raycaster.ray`) with the face it entered, reading the voxels, so it sees
  changes not yet drawn; `removeSphere(center, radius)` empties a ball of voxels and returns them, for craters and
  debris. `addHeightmap(rgba, width)` builds terrain from a decoded image's raw RGBA bytes: each pixel's red channel
  is a column's height, and an optional color image picks each column's nearest palette color.

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

Version `0.1.0-dev.4`, a preview: the API may still change before 0.1.0. The API is listed in `test/api.txt`,
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
