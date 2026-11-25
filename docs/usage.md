# Usage

How to use the parts of `ent` that need a platform or a renderer: camera controls, GLTFLoader and
post-processing. In Flutter, each renderer package (`package:ent_flutter/ent_flutter.dart` for Flutter GPU,
`package:ent_opengl/ent_opengl.dart` for OpenGL ES) exports all of `ent`, and the code below is the same for both.

## Controls without a DOM

The reference's controls listen on an HTML element. Here the element is a `ControlsElement` the platform keeps sized,
and the listeners are methods the platform calls with plain events (exception E-DOM-CONTROLS,
`docs/compatibility-exceptions.md`):

```dart
final controls = OrbitControls(camera, ControlsElement(clientWidth: 800, clientHeight: 600))
  ..enableDamping = true;

controls.onPointerDown(ControlsPointerEvent(pointerId: 1, clientX: 400, clientY: 300));
controls.onPointerMove(ControlsPointerEvent(pointerId: 1, clientX: 430, clientY: 300));
controls.onPointerUp(ControlsPointerEvent(pointerId: 1, clientX: 430, clientY: 300));
controls.onMouseWheel(ControlsWheelEvent(clientX: 400, clientY: 300, deltaY: -100));

// Every frame, for damping and auto-rotation:
controls.update();
```

In Flutter, wrap the view: `OrbitControlsListener(controls: controls, child: EntView(...))`.

## GLTFLoader

`GLTFLoader` reads meshes, lines and points, materials (factors, alpha modes, double-sided, vertex colors, unlit,
emissive strength, clearcoat, diffuse roughness, dispersion, sheen, transmission, volume, IOR, specular, iridescence,
anisotropy, bump), textures with their samplers and KHR_texture_transform, nodes, cameras, punctual lights and scenes,
skins (bones, inverse bind matrices), morph targets (position, normal and color, names from `extras.targetNames`, mesh
and node weights) and animations (`gltf.animations`: translation, rotation, scale and weights, LINEAR, STEP and
CUBICSPLINE, normalized outputs), from glTF JSON or GLB with embedded, GLB or external buffers and images. Play a clip
with the core `AnimationMixer`: `AnimationMixer(gltf.scene!).clipAction(gltf.animations[0])!.play()`, then
`mixer.update(delta)` per frame. KTX2 (`KHR_texture_basisu`), Draco and meshopt are not ported (exception E-GLTF,
`docs/compatibility-exceptions.md`).

Textures in Flutter: images in a buffer view (GLB) or a data URI, and external image files next to the model, decode
through `FlutterPlatform`'s `createImageBitmap` (dart:ui's codecs; PNG is what the tests cover, and AVIF is untested and
depends on the platform's codecs). An image in a buffer view becomes a `data:` URI of its `mimeType` in place of the
reference's `Blob` object URL. Images decode with premultiplied alpha in dart:ui, so translucent texels may move
slightly (E-DECODE).

Loads go through the core `Loader`/`FileLoader`, so a platform must be installed first; in Flutter,
`FlutterPlatform.install()` serves data URIs, http(s) and the app's asset bundle:

```dart
FlutterPlatform.install();

// From the asset bundle (pubspec `assets:`); relative buffer URIs resolve next to the file.
final gltf = await GLTFLoader().loadAsync('assets/models/robot.glb');
scene.add(gltf.scene!);

// From bytes already in memory: the ByteBuffer must hold exactly the file.
final data = await rootBundle.load('assets/models/robot.glb');
final bytes = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
final model = await GLTFLoader().parseAsync(bytes.buffer, 'assets/models/');
```

`crossOrigin` has no effect outside a browser (only `use-credentials`, which sends credentials).

## Post-processing

The passes call an `EffectComposerRenderer`, which both renderers implement. Each effect is an
`EffectMaterial` with typed settings and no shader code: the renderer recognises it by its class and draws it with its
own shader (exception E-POSTPROCESSING, `docs/compatibility-exceptions.md`). An `EffectPass` draws one over the whole
target:

```dart
final composer = EffectComposer(renderer)
  ..addPass(RenderPass(scene, camera))
  ..addPass(VignettePass()..material.darkness = 0.8)
  ..addPass(OutputPass());

// Every frame, in place of renderer.render(scene, camera); the last pass draws the frame (renderer.texture).
composer.render();
```

In Flutter, hand the composer to `EntView` instead of calling `render` yourself: the view runs it every frame, shows
its frame and sizes it with the renderer. The app owns and disposes it:

```dart
EntView(renderer: renderer, scene: scene, camera: camera, composer: composer);
```

## HologramMaterial

Ent's own material, with no counterpart in the reference: a see-through glow, brightest at the silhouette, banded
by scanlines that move up, with an optional flicker. It ignores lights. By default it blends additively, draws both
sides and writes no depth, so holograms add up where they overlap. A transparent double-sided object draws its back
faces, then its front faces, so a closed shape shows both its walls.

```dart
final material = HologramMaterial({'color': Color(0x4fd8ff), 'rim': 1.5, 'flicker': 0.1});
final clock = Clock();

// Every frame, before rendering: the scanlines and the flicker follow time.
material.time = clock.getElapsedTime();
```

| Property | Default | Effect |
| --- | --- | --- |
| `color`, `opacity` | `0x4fd8ff`, `1` | The glow's color and overall strength |
| `fill` | `0.15` | The glow where the surface faces the camera |
| `rim`, `rimPower` | `1`, `2` | The glow added at the silhouette, and how tightly it hugs the edge |
| `scanlines` | `0.5` | How deep the lines cut, `0` to `1` |
| `scanlineDensity`, `scanlineSpeed` | `40`, `0.5` | Lines per world unit along y, and their speed up in units per second |
| `flicker` | `0` | Random dimming, a new amount 30 times a second, `0` to `1` |
| `time` | `0` | Seconds; the app advances it |

Above a glow of 1 the color gets brighter instead of more opaque, so a bloom pass (`TuningPass`) picks up a strong
rim. Its shader variant is `hologram` (with `polygon_offset` when the material sets it).

## Shader variants

The material shaders are compiled when the app is built, one variant per material setup it uses: a kind and its
flags, such as `lambert map normal_map` (docs/shader-variants.md). The app lists them in a registry file its
pubspec names, under its renderer package (`ent_flutter` or `ent_opengl`; an app with both names it under each):

```yaml
hooks:
  user_defines:
    ent_flutter:
      shaders: ent_shaders.json
```

```json
{
	"variants": [
		"basic",
		"lambert map normal_map"
	]
}
```

Drawing a material whose variant is not listed throws a `StateError` naming its key. To fill the registry, set
`recorded` and run the app through its scenes: it collects every key a draw or `compile` needs, and skips (with a
warning) the objects whose variant is missing instead of throwing. A run collects only what it actually draws, so it
should reach every scene and material state. Then print the keys as the registry and save them in place of the file:

```dart
renderer.recorded = {};

// After the scenes:
debugPrint(JsonEncoder.withIndent('\t').convert({'variants': renderer.recorded!.toList()..sort()}));
```

## Checks

```
node tool/reference/js/orbit_controls.mjs    # the reference in Node: fixtures/values/orbit_controls.json
node tool/reference/js/gltf_files.mjs        # writes the test assets in fixtures/gltf/
node tool/reference/js/gltf_loader.mjs       # the reference in Node: fixtures/values/gltf_loader.json
node tool/reference/js/effect_composer.mjs   # the reference in Node: fixtures/values/effect_composer.json
(cd packages/ent && dart analyze --fatal-infos && dart test)
```

The OrbitControls test replays every scenario (rotate, dolly, pan, damping, limits, reset, touch, keys, auto-rotate,
zoom to cursor, orthographic, a z-up camera, MapControls) step by step against the reference's camera, target, angles,
state, events and `update()` results.