## 0.1.0-dev.4

- Needs `ent` 0.1.0-dev.4. The Flutter side of `ent`'s input map: `KeyboardInput` feeds keys (by their W3C
  `KeyboardEvent.code`) and gamepad buttons delivered as key events to an `Input` while it has focus, releasing them
  when it loses it; `Joystick`, an on-screen stick reporting two analog sources; `TouchButton`, a source held while
  touched; `keyCode` maps a Flutter physical key to its source name.

## 0.1.0-dev.3

- Internal: conditional expressions test one condition each; behaviour and frames unchanged.

## 0.1.0-dev.2

- The core's warnings name the renderer that prints them (`ENT.OpenGlRenderer: …`, `ENT.FlutterGpuRenderer: …`)
  through the new `GpuRenderer.name`, which each renderer overrides; the default is `GpuRenderer`. The blend
  equation and blend color warnings no longer name Flutter GPU.

## 0.1.0-dev.1

- First release: the renderer core shared by `ent_flutter` and `ent_opengl` (`GpuRenderer` and its GPU interface in
  `package:ent_renderer/gpu.dart`), with `EntView`, `OrbitControlsListener` and `FlutterPlatform`, which used to be
  in `ent_flutter`.
