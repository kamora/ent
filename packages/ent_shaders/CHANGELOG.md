## 0.1.0-dev.2

- **Breaking:** the package holds only what every renderer shares: the GLSL, the list of fixed shaders and the variant
  scheme, in pure Dart. Its build hook and shader bundle are gone: each renderer package compiles the shaders with its
  own hook (through `ent_impeller`), and the app names its registry under the renderer, such as
  `hooks: user_defines: ent_flutter: shaders:`, instead of `ent_shaders:`. `strip` moved to `ent_impeller`.
- `readRenderers` reads the registry's `renderers` map, which says which renderer draws on which platform in an app
  that uses two.
- The output uniforms carry which way rows run (`rows`, `target_rows`), so a renderer can draw its targets bottom-up,
  as OpenGL ES does.

## 0.1.0-dev.1

- First release: the shaders of Ent Engine, moved out of `ent_flutter`, and the build hook that compiles them with
  the variants named in the app's `pubspec.yaml`.
