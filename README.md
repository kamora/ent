<h1 align="center">Ent Engine</h1>

<p align="center">
  <strong>A 3D engine for Dart, drawn on the GPU by Flutter.</strong>
</p>

<p align="center">
  <em>“…we do not say anything in it, unless it is worth taking a long time to say, and to listen to.”</em><br>
  <sub>Treebeard on Entish, the language of the Ents, in J. R. R. Tolkien's <em>The Two Towers</em></sub>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2f7d4f" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-3.47.6%2B-02569B?logo=flutter" alt="Flutter 3.47.6 or later">
  <img src="https://img.shields.io/badge/platforms-iOS%20%C2%B7%20macOS%20%C2%B7%20Android-6b4f2a" alt="Platforms: iOS, macOS, Android">
  <img src="https://img.shields.io/badge/status-preview-c27c0e" alt="Status: preview">
</p>

<p align="center">
  <a href="#get-started">Get started</a> ·
  <a href="docs/usage.md">Documentation</a> ·
  <a href="examples/worm">Example</a> ·
  <a href="#platforms">Platforms</a>
</p>

---

Build 3D scenes in Dart and show them in your Flutter app. Ent is a pure-Dart engine (scenes, materials, lights,
animation, model loading) with two renderers, one on Flutter GPU (Impeller) and one on OpenGL ES, so the whole scene
lives in the same code as the rest of your app.

Ent Engine is based on [three.js](https://threejs.org) and keeps partial compatibility with its API; the
differences are listed in the [compatibility exceptions](docs/compatibility-exceptions.md).

<div align="center">

![Ent Engine's mascot, an old tree spirit](media/concept.jpg)

</div>

## What's inside

- **Scenes**: cameras, geometries, materials and lights, with shadows.
- **Models and motion**: glTF and GLB loading, skeletal animation and morph targets.
- **Rendering**: physically based materials, environment maps, MSAA and post-processing (bloom, FXAA, vignette).
- **Interaction**: picking, orbit controls and pointer input.
- **Flutter**: `EntView`, a widget with its own frame loop that sizes itself to the layout.

> [!NOTE]
> Ent is a preview, and so is Flutter GPU, which it draws with. Read the
> [requirements](packages/ent_flutter/README.md#requirements) before you build on it.

## Get started

Run the example, a skinned glTF worm wiggling under a shadow-casting light:

```sh
git clone https://github.com/kamora/ent.git
cd ent/examples/worm
flutter run -d macos
```

A smaller start, a lit cube you can tap and orbit:

```sh
flutter run -t lib/getting_started.dart -d macos
```

The OpenGL ES renderer has its own example, a turning cube (macOS, or an Android phone):

```sh
cd ../opengl
flutter run -d macos
```

To draw in your own app, follow the [setup guide](packages/ent_flutter/README.md#getting-started): enable Flutter
GPU and list the shader variants your materials need.

## Packages

| Package | What it is |
| --- | --- |
| [`ent`](packages/ent) | The engine in pure Dart: scenes, loaders, controls and post-processing. No Flutter needed. |
| [`ent_engine`](packages/ent_engine) | The game layer, in pure Dart: a game loop with pause and time scale, timers owned by scene objects, tweens and an input map. Not published yet. |
| [`ent_shaders`](packages/ent_shaders) | The shaders every renderer shares. |
| [`ent_impeller`](packages/ent_impeller) | The toolchain that compiles them for both renderers when the app is built. |
| [`ent_renderer`](packages/ent_renderer) | The renderer core both renderers share, and `EntView`. |
| [`ent_flutter`](packages/ent_flutter) | The Flutter GPU renderer. Exports all of `ent` and `EntView`. |
| [`ent_opengl`](packages/ent_opengl) | The OpenGL ES renderer, on ANGLE on macOS. Exports all of `ent` and `EntView`. |

A Flutter app depends on one renderer package: `ent_flutter` where Flutter GPU runs, `ent_opengl` on Android phones
where it does not (see Platforms). The scene code is the same for both.

## Platforms

| Platform | `ent_flutter` (Flutter GPU) | `ent_opengl` (OpenGL ES) |
| --- | --- | --- |
| macOS | Yes, on Metal; verified on an M1 and GitHub's macOS runner | Yes, ANGLE on Metal (`wrangle`); verified on an M1 and GitHub's macOS runner |
| iOS | Yes, on Metal; verified on an iPhone 11 and the simulator | No |
| Android | Only where Impeller runs on Vulkan; elsewhere `create()` throws (flutter/flutter#196045). Verified on a Galaxy S10 forced to Vulkan | Yes, the system's OpenGL ES; verified on a Galaxy S10 (Mali-G76) |
| Windows, Linux, web | No | No |

## Learn more

- [Usage](docs/usage.md): controls, model loading and post-processing
- [Shader variants](docs/shader-variants.md): how material shaders are built with your app
- [Flutter GPU renderer](docs/flutter-gpu.md): what it draws, and its limits
- [OpenGL ES renderer](docs/opengl.md): how it draws, its platforms and limits
- [Roadmap](docs/implementation-roadmap.md)

## Tests

```sh
(cd packages/ent && dart test)
(cd packages/ent_shaders && dart test)
(cd packages/ent_impeller && dart test)
(cd packages/ent_flutter && flutter test --enable-impeller --enable-flutter-gpu)
(cd examples/worm && flutter test integration_test/parity_metal_test.dart -d macos --enable-flutter-gpu)
(cd packages/ent_opengl && flutter test --enable-impeller --enable-flutter-gpu)
(cd examples/cube && flutter test integration_test/parity_test.dart -d macos)
```

The device tests and what they need are in the [example's README](examples/worm/README.md).

## License

[MIT](LICENSE), © 2026 KAMORA Ltd. Third-party notices are in [`ent`](packages/ent/THIRD_PARTY_NOTICES.md),
[`ent_shaders`](packages/ent_shaders/THIRD_PARTY_NOTICES.md) and
[`ent_flutter`](packages/ent_flutter/THIRD_PARTY_NOTICES.md). The test models in `fixtures/gltf/khronos/` are Khronos
glTF samples under their own licenses (see their `ATTRIBUTION.md`).
