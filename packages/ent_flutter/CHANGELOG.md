## 0.1.0-dev.4

- Needs `ent_renderer` 0.1.0-dev.4 and `ent` 0.1.0-dev.4: exports `ent`'s game layer (`Game`, tweens, `Input`) and the
  input widgets `KeyboardInput`, `Joystick` and `TouchButton`.
- The example imports `package:material_ui/material_ui.dart`, the replacement for the deprecated
  `package:flutter/material.dart`.

## 0.1.0-dev.3

- Needs `ent_renderer` 0.1.0-dev.2: warnings from the shared core start with `ENT.FlutterGpuRenderer:`.

## 0.1.0-dev.2

- **Breaking:** the app names its shader registry under `ent_flutter` (`hooks: user_defines: ent_flutter: shaders:`)
  instead of `ent_shaders`. This package's own build hook compiles the shaders, keeping only the backends Flutter GPU
  runs on the target (Metal, Vulkan), into its asset `packages/ent_flutter/build/shaderbundles/ent.shaderbundle`.
- The renderer core moved to `ent_renderer`, shared with `ent_opengl`: `FlutterGpuRenderer` extends its
  `GpuRenderer`. `EntView`, `OrbitControlsListener` and `FlutterPlatform` come from there too; `ent_flutter` still
  exports them, so apps import nothing new.
- Needs `ent_shaders` 0.1.0-dev.2.

## 0.1.0-dev.1

- First release: `FlutterGpuRenderer` on Flutter GPU, `EntView`, `OrbitControlsListener` and `FlutterPlatform`, with
  build-time shader variants named in the app's `pubspec.yaml`.
