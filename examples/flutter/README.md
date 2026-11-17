# ent_example

A minimal ent scene rendered with Flutter GPU: an orange triangle behind a rotating, normal-shaded cube.

Flutter GPU must be enabled: the `Info.plist` files of `macos/` and `ios/` already set `FLTEnableFlutterGPU` and
`FLTEnableImpeller` to `true` (see `packages/ent_flutter/README.md`).

```sh
flutter run -d macos
flutter test integration_test/render_test.dart -d <device> --enable-flutter-gpu
```

On a fresh checkout or after `flutter clean`, build the app once (`flutter build macos --debug`, or any `flutter run`)
before the device tests: they look for the shader bundle before the build hook has made it.

## Getting started

`lib/getting_started.dart` is the scene of `ent`'s README as an app: a lit cube that turns, changes color when
tapped and orbits with the mouse or touch. It is the smallest app that uses the renderer, `EntView`, picking and
`OrbitControls` together.

```sh
flutter run -t lib/getting_started.dart -d macos
flutter test integration_test/getting_started_test.dart -d macos --enable-flutter-gpu
```

## Viewer

`lib/viewer.dart` is the example viewer: a skinned, textured glTF worm (`assets/worm.glb`) wiggling on a ground
plane with PCF shadows, orbited with the mouse (drag to rotate, right drag to pan, wheel to zoom; damping on).
Pipelines are warmed with `compileAsync` while a loading state shows.

```sh
flutter run -t lib/viewer.dart -d macos
flutter test integration_test/viewer_test.dart -d macos --enable-flutter-gpu
```

On the iPhone 11 the same tests run with `flutter test integration_test/viewer_test.dart -d <iphone id>` (Flutter
GPU is switched on by `ios/Runner/Info.plist`); they pass there with the same pixel numbers as on macOS. The last
test prints rough timings: on the iPhone 11 the cold load (parse plus `compileAsync`) takes about 0.8 s and the
running view holds 60 frames per second.

The asset is generated, not downloaded: `node tool/reference/js/worm_glb.mjs` (from the repository root)
rewrites it with the same bytes.
