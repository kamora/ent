# ent_flutter

Flutter for Ent Engine: `FlutterGpuRenderer`, a 3D renderer on Flutter GPU (Impeller), and the widgets and
adapters an app needs around it. It exports all of
[`ent`][ent], so an app depends on `ent_flutter` only.

- `FlutterGpuRenderer`: the renderer (`render`, `setSize`, `setRenderTarget`, `compile`, `info`, `shadowMap`,
  ...).
- `EntView`: a widget that draws a scene every frame, sized to its layout, with pointer callbacks for picking.
- `OrbitControlsListener`: feeds Flutter's pointer events to `OrbitControls` or `MapControls`.
- `FlutterPlatform.install()`: the image and loader services of `ent` for Flutter.

Its frames are checked pixel by pixel against reference frames: 159 scenes under `flutter test`, and 176
on Metal, on an M1 Mac and an iPhone 11 ([`docs/flutter-gpu.md`][flutter-gpu], "Parity on Metal").

## Requirements

- Flutter 3.47.6 or later, with Impeller.
- Flutter GPU, a preview feature that is off by default, enabled on every platform the app ships on; otherwise
  `FlutterGpuRenderer.create()` throws a `StateError` naming the switch:

  | Where | Setting |
  |---|---|
  | `flutter run`, `flutter test` | `--enable-flutter-gpu` (`flutter test` also needs `--enable-impeller`) |
  | iOS, macOS | `FLTEnableFlutterGPU` and `FLTEnableImpeller` set to `true` in `Info.plist` |
  | Android | `io.flutter.embedding.android.EnableFlutterGPU` set to `true` as `<meta-data>` in `AndroidManifest.xml` |

- On Android, a device where Impeller runs on Vulkan. Flutter falls back to OpenGL ES on emulators, Huawei, MediaTek
  below vendor API 32, Exynos 9825 and older, Adreno 650 and older, older PowerVR and the first Samsung Xclipse; there
  Flutter GPU draws nothing (flutter/flutter#196045), and `create()` throws a `StateError` that says so. On those
  devices, use [`ent_opengl`][ent_opengl], the OpenGL ES renderer, with the same scene code.

| Platform | Status |
|---|---|
| macOS | Verified on an M1 (Metal) |
| iOS | Verified on an iPhone 11 (A13) and the simulator |
| Android | Not verified by default: the tested phones fall back to OpenGL ES. A Galaxy S10 forced to Vulkan passes the getting-started and render tests and draws correctly |
| Web, Windows, Linux | Not supported in this version (Flutter GPU has no web backend; the desktop ones are untested) |

## Getting started

1. Depend on `ent_flutter` and enable Flutter GPU (above).
2. List the shader variants the app draws with. The material shaders are compiled when the app is built, one
   variant per material setup, such as `lambert map normal_map`, by this package's build hook. Name the registry
   file in `pubspec.yaml`, under `ent_flutter`:

   ```yaml
   hooks:
     user_defines:
       ent_flutter:
         shaders: ent_shaders.json
   ```

   ```json
   {
   	"variants": [
   		"physical ao_map metalness_map roughness_map"
   	]
   }
   ```

   A draw whose variant is missing throws a `StateError` naming its key. To collect the keys, set
   `renderer.recorded = {}` and run the app through its scenes; [`docs/usage.md`][usage], "Shader
   variants", shows how to save them.
3. Install the platform services, create the renderer and show the scene:

   ```dart
   FlutterPlatform.install();
   final renderer = await FlutterGpuRenderer.create();

   EntView(
     renderer: renderer,
     scene: scene,
     camera: camera,
     onFrame: (elapsed) => cube.rotation.y = elapsed.inMicroseconds / 1e6,
   );
   ```

   `EntView` draws at the device pixel ratio, resizes the renderer and a PerspectiveCamera's aspect when its layout
   changes, and pauses while muted by `TickerMode` or while the app is in the background. It does not own the
   renderer: the app disposes it.

[`examples/worm/lib/getting_started.dart`][getting_started] is this as a whole app, with picking and `OrbitControls`;
the same example app has a glTF viewer.

## What it draws

Every mesh material from MeshBasicMaterial to MeshPhysicalMaterial (clearcoat, sheen, iridescence, anisotropy,
transmission, dispersion), lines, points and sprites; directional, point, spot, hemisphere, ambient and rect area
lights; Basic, PCF and VSM shadows; environment maps and HDR backgrounds; skinning, morph targets, instancing and
batching; render targets with depth textures and samples; `CubeCamera`; antialias; and `EffectComposer` with
bloom, FXAA and vignette.

Limits (the full list is in [`docs/flutter-gpu.md`][flutter-gpu], "Limits"):

- At most 4 directional, 8 point, 4 spot, 2 hemisphere and 2 rect area lights, and 6 shadow or spot-light maps,
  per frame; lights past them are dropped with a one-time warning.
- At most 15 distinct textures per MeshStandardMaterial or MeshPhysicalMaterial draw (maps that share a texture
  count once); a draw that needs more throws a `StateError`.
- Not drawn, with a one-time warning: `wireframe`, video, compressed and 3D textures, multiple render targets.
- Not ported: clipping planes, stencil, logarithmic depth, dithering, alphaHash.

## Picking

The pointer callbacks get the Flutter `PointerEvent` and its normalized device coordinates, computed from logical
pixels:

```dart
EntView(
  renderer: renderer,
  scene: scene,
  camera: camera,
  onPointerDown: (event, ndc) {
    raycaster.setFromCamera(ndc, camera);
    hits = raycaster.intersectObjects(scene.children);
  },
)
```

An app with its own gesture handling converts a local position with `EntView.ndc(offset, size)`.

## Warming up pipelines

Impeller builds a pipeline the first time a draw meets a new state, a few hundred milliseconds each. Call
`await renderer.compileAsync(scene, camera)` while loading, after the lights and environment are set, so the first
frame does not stall.

## Tests

```sh
flutter test --enable-impeller --enable-flutter-gpu
flutter test --enable-impeller test/disabled_test.dart
```

The first runs the renderer, parity and adapter tests under flutter_tester (Impeller on Vulkan through SwiftShader,
on the CPU); the second checks the error when Flutter GPU is off. The parity run on Metal is in `examples/worm`
([`integration_test/parity_metal_test.dart`][parity_metal_test]).

An app's device tests (`flutter test integration_test -d <device>`) look for the shader bundle before the build hook
has made it: on a fresh checkout or after `flutter clean` they stop with "No file or variants found for asset:
packages/ent_flutter/build/shaderbundles/ent.shaderbundle". `flutter build`, `flutter run` and host tests run the hook
first, so run one of them once before the device tests.

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

The notices of the third-party code it builds on are in `THIRD_PARTY_NOTICES.md`.

[ent]: https://github.com/kamora/ent/tree/master/packages/ent
[ent_opengl]: https://github.com/kamora/ent/tree/master/packages/ent_opengl
[flutter-gpu]: https://github.com/kamora/ent/blob/master/docs/flutter-gpu.md
[usage]: https://github.com/kamora/ent/blob/master/docs/usage.md
[getting_started]: https://github.com/kamora/ent/blob/master/examples/worm/lib/getting_started.dart
[parity_metal_test]: https://github.com/kamora/ent/blob/master/examples/worm/integration_test/parity_metal_test.dart
