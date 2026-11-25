## 0.1.0-dev.2

- The core's warnings name the renderer that prints them (`ENT.OpenGlRenderer: …`, `ENT.FlutterGpuRenderer: …`)
  through the new `GpuRenderer.name`, which each renderer overrides; the default is `GpuRenderer`. The blend
  equation and blend color warnings no longer name Flutter GPU.

## 0.1.0-dev.1

- First release: the renderer core shared by `ent_flutter` and `ent_opengl` (`GpuRenderer` and its GPU interface in
  `package:ent_renderer/gpu.dart`), with `EntView`, `OrbitControlsListener` and `FlutterPlatform`, which used to be
  in `ent_flutter`.
