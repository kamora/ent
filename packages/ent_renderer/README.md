# ent_renderer

The renderer core of Ent Engine, shared by its renderers: render lists, programs and uniforms, lights, shadows,
textures, environment maps, passes and post-processing, plus `EntView`, `OrbitControlsListener`, the Flutter
platform services of [`ent`][ent], and the Flutter side of its game layer's input map (`KeyboardInput`, `PointerInput`,
`Joystick`, `TouchButton`).

An app does not depend on this package directly. It depends on a renderer package, which exports what an app needs
from here:

- [`ent_flutter`][ent_flutter]: `FlutterGpuRenderer`, on Flutter GPU (Impeller).
- [`ent_opengl`][ent_opengl]: `OpenGlRenderer`, on OpenGL ES 3.

## For renderer packages

`GpuRenderer` draws through the small GPU interface in `package:ent_renderer/gpu.dart`: a `GpuContext` that makes
buffers, textures and command buffers, render passes, pipelines and a `ShaderLibrary` over the shaders of
[`ent_shaders`][ent_shaders]. A renderer package implements that interface for its GPU API, subclasses `GpuRenderer`
with a `create()` that runs the creation checks (`checkLoad`, `checkFloatFilter`, `checkDepthRead`), and returns a
`FrameDisplay` from `createDisplay()` to show its frames in `EntView`.

Two properties of the context change what the core does: `rowsUp` (whether 2D targets and the frame are drawn with
their first row at the bottom, as in GL) and `maxMipLevelCount` (how many mip levels a texture can have).

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

The notices of the third-party code it builds on are in `THIRD_PARTY_NOTICES.md`.

[ent]: https://github.com/kamora/ent/tree/master/packages/ent
[ent_flutter]: https://github.com/kamora/ent/tree/master/packages/ent_flutter
[ent_opengl]: https://github.com/kamora/ent/tree/master/packages/ent_opengl
[ent_shaders]: https://github.com/kamora/ent/tree/master/packages/ent_shaders
