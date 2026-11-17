# Ent Engine

Ent Engine (`ent`) is a 3D engine for Dart built on three.js r187: the scene graph, math, geometries, materials, lights,
animation and loaders follow r187's API and behaviour, and scenes render on the GPU through Flutter GPU (Impeller).

## Packages

- `packages/ent`: the engine in pure Dart, with no Flutter dependency: the scene layer, GLTFLoader, HDRLoader,
  OrbitControls and post-processing.
- `packages/ent_flutter`: `FlutterGpuRenderer` and `EntView`, a widget with a frame loop and pointer
  coordinates for picking.
- `examples/flutter`: the example app (`ent_example`), a glTF viewer and the integration tests.

Each package and the example resolve on their own: `dart pub get` in `packages/ent`, `flutter pub get` in
`packages/ent_flutter` and `examples/flutter`. `ent_flutter` exports all of `ent`, so a Flutter app depends on
`ent_flutter` only, as the example does.

## Platforms

macOS and iOS on Metal are verified. Android needs a device where Impeller uses Vulkan and is not tested yet.
Flutter GPU must be enabled in every app: `--enable-flutter-gpu`, `FLTEnableFlutterGPU` in Info.plist, or
`io.flutter.embedding.android.EnableFlutterGPU` in AndroidManifest.xml.

## Tests

```sh
(cd packages/ent && dart test)

# Renderer and parity tests under flutter_tester (Impeller on Vulkan through SwiftShader)
(cd packages/ent_flutter && flutter test --enable-impeller --enable-flutter-gpu)

# Parity with r187 on Metal, in the macOS app
(cd examples/flutter && flutter test integration_test/parity_metal_test.dart -d macos --enable-flutter-gpu)
```

Expected values and reference frames are in `fixtures/`; they are written from the pinned r187 source by the
scripts in `tool/reference/` (`js/` in Node, `render/` in headless Chrome), each with its own README.

## Docs

`docs/` holds the porting conventions, the compatibility exceptions, the Flutter GPU notes, the usage of controls,
loaders and post-processing, the upstream pin and the roadmap. Each package and the example have a README.

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`. Each package carries the same `LICENSE` and a `THIRD_PARTY_NOTICES.md`.

Derived from [three.js](https://github.com/mrdoob/three.js) (MIT, © three.js authors). The test models in
`fixtures/gltf/khronos/` are Khronos glTF sample models under their own licenses; see their `ATTRIBUTION.md`.
