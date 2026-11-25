## 0.1.0-dev.3

- Anisotropic filtering: `texture.anisotropy` applies up to the GPU's limit, read from
  EXT_texture_filter_anisotropic (`maxSamplerAnisotropy` was 1).

## 0.1.0-dev.2

- Needs `ent_renderer` 0.1.0-dev.2: warnings from the shared core start with `ENT.OpenGlRenderer:`, not
  `ENT.FlutterGpuRenderer:`.
- The example is the one file `example/main.dart`; the example app moved to the repository's `examples/opengl`.

## 0.1.0-dev.1

- First release: `OpenGlRenderer` on OpenGL ES 3, on ANGLE (from `wrangle`) on macOS and the system's OpenGL ES on
  Android, with `EntView` showing its frames through a platform texture. Its build hook compiles the shaders as
  GLSL ES 3.00 only; the app names its shader registry under `hooks: user_defines: ent_opengl: shaders:`.
