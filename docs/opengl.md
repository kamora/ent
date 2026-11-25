# OpenGL ES backend

`ent_opengl`'s `OpenGlRenderer` draws through OpenGL ES 3.0, on ANGLE (Metal) on macOS and on the system's OpenGL ES
on Android. It is the second renderer beside `FlutterGpuRenderer` ([`flutter-gpu.md`](flutter-gpu.md)): both are
`GpuRenderer`s from `ent_renderer` and differ only in the small GPU interface they implement
(`package:ent_renderer/gpu.dart`), so everything the renderer core draws, its limits and the compatibility exceptions
are the same for both, except where this page says otherwise.

## Why a second renderer

Flutter GPU draws nothing where Impeller falls back to OpenGL ES (flutter/flutter#196045): emulators and many Android
phones, among them both test phones (Galaxy A22, Galaxy S10). OpenGL ES 3 runs on those, and through ANGLE on macOS.

## Platforms

| Platform | How | Status |
|---|---|---|
| macOS | ANGLE's `libGLESv2` on Metal, from the [`wrangle`](https://pub.dev/packages/wrangle) package (arm64 and x64) | Verified on an M1 and on GitHub's `macos-15` runner |
| Android | The system's `libEGL` and `libGLESv3` | Verified on a Galaxy S10 (Mali-G76) |
| iOS, Windows, Linux | Not yet | |

No Flutter GPU switch is needed. `ent_opengl`'s build hook compiles the shaders of `ent_shaders` into its own bundle
with the `opengl_es` backend only (through `ent_impeller`); the app names its shader registry under
`hooks: user_defines: ent_opengl: shaders:`.

## How it draws

- `GlContext.shared`: one EGL display, one OpenGL ES 3 context and a 1 × 1 pbuffer per process. Every renderer and
  surface uses it.
- `GlLibrary` reads the shaders' GLSL ES 3.00 from the bundle (`impellerc --gles-language-version=300`), with their
  uniform blocks and member offsets. Nothing compiles at runtime except the driver's own compile of that GLSL when a
  pipeline is first made.
- Pipelines number their own uniform block binding points and texture units. A render pass records its calls and
  replays them when the command buffer is submitted.
- MSAA: 4× multisampled renderbuffers, resolved into the target's texture with `glBlitFramebuffer` at the end of the
  pass.
- Mip levels: `glGenerateMipmap` for 8-bit textures, down to 1 × 1, as WebGL (E-MIPMAP, E-MIPFILTER); other formats
  are built on the CPU, as on Flutter GPU.
- The creation probes (`checkLoad`, `checkFloatFilter`, `checkDepthRead`) are the same as Flutter GPU's.

## Which way rows run

WebGL draws its frame and its 2D render targets with the first row at the bottom, and cube map faces with the first
row at the top. Flutter GPU draws everything top row first. `GpuContext.rowsUp` tells the core which one a backend
uses; on OpenGL ES it is true, and the GL backend draws as WebGL does:

- 2D targets and the frame bottom-up, cube faces top-down; the backend converts viewports and scissors, and turns the
  rows over when a texture is read back or presented.
- The shaders read two uniforms of `OutputInfo`: `rows` (the pass being drawn) and `target_rows` (2D targets being
  sampled). They feed `dFdy`, the shadow lookups, the PCF noise, the line rule, transmission and `gl_PointCoord`.

The first GL version kept Flutter GPU's top-down layout. On the Galaxy S10 that showed in `composer_fxaa` and
`shadow_vsm_spot`: the Mali GPU truncates the weights of 8-bit bilinear filtering where Apple GPUs round them (a raw
OpenGL ES probe), so sampling a target that is stored upside down lands the truncation on the other side of a texel.
Drawn bottom-up, the GL frames match Chrome on the same phone in those scenes.

## Display

`EntView` asks the renderer for a `FrameDisplay` (`GpuRenderer.createDisplay()`). OpenGL ES's display shows each
frame in a `GlSurface`, a Flutter `Texture` widget at one frame pixel per physical pixel; a new surface is made when
the frame's size changes.

- macOS: an IOSurface (BGRA) in a `CVPixelBuffer`, registered as a Flutter texture by the plugin (Swift; built with
  SwiftPM, the CocoaPods podspec is unbuilt), and bound to EGL as a pbuffer (`EGL_ANGLE_iosurface_client_buffer`). A blit stores the frame top row
  first.
- Android: a Flutter `SurfaceProducer`, an `ANativeWindow` from its surface (JNI) and an EGL window surface (swap
  interval 0); `present` blits the frame and swaps.

## Parity

The parity scenes are the same as Flutter GPU's, compared with the same reference frames and rules, with no
`mipmaps` allowances (`mipmapAllowances: false`).

- macOS (M1, ANGLE on Metal): every scene passes. `ent_opengl`'s host tests (169, one scene skipped everywhere) and
  the example app's parity test (162) pass there and on GitHub's runner (CI job `opengl`).
- Galaxy S10 (Mali-G76): compared both with the M1's reference frames and with frames the reference draws in Chrome
  on the same phone (`tool/reference/render/render.mjs` with `REMOTE`; the example's `PARITY_REFERENCE`). The
  differences left against the M1 are the GPU's: our frame and Chrome's on the phone differ from the M1 alike
  (`khronos_normal_tangent_mirror`, `khronos_clearcoat`, `khronos_transmission`, which is within 15/255 of Chrome on
  the phone). Chrome on the phone draws some scenes wrong itself (`hdr_environment_aces` black,
  `hdr_environment_mirror`, `hdr_environment_sphere`, `khronos_alpha_blend_mode`, `standard_grid_environment`,
  `standard_grid_light`), so it is no yardstick for them.

## Limits

- Reading back textures other than 8-bit RGBA (`readRenderTargetPixels` of a float target) throws
  `UnimplementedError`.
- No anisotropic filtering (`maxSamplerAnisotropy` is 1).
- A transmissive object drawn into a `CubeCamera` face takes its rows from the cube pass; no scene checks it.

## Tests

```sh
(cd packages/ent_opengl && flutter test --enable-impeller --enable-flutter-gpu)
(cd packages/ent_opengl/example && flutter build macos --debug)
(cd packages/ent_opengl/example && flutter test integration_test/parity_test.dart -d macos)
```

The host tests compare GL frames with Flutter GPU's (hence the flags) and run the parity scenes on ANGLE inside
flutter_tester. Run the example's integration tests one file at a time: several files in one run fail to relaunch the
macOS app. On Android, run them on the device (`-d <device>`).
