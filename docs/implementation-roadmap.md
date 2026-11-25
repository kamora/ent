# Roadmap

Status is measured, never declared: behavioural parity (reference fixtures and ported tests), rendering parity and
platform parity are reported separately. Where Ent differs from the reference on purpose, the row is in
`docs/compatibility-exceptions.md`.

## Where it stands

- `ent`: math, core, cameras, objects, geometries, materials, lights, textures and animation, with GLTFLoader,
  HDRLoader, OrbitControls and EffectComposer (render, FXAA, vignette, copy, bloom and output passes), checked
  against values the reference produced (`fixtures/values/`).
- `ent_shaders`: the GLSL every renderer shares and the variant scheme (pure Dart). Each renderer package compiles
  them into its own bundle with its own build hook when the app is built; nothing compiles at runtime.
- `ent_impeller`: the toolchain of both renderers on Impeller's shader compiler: it runs `impellerc`, keeps the
  backends a renderer draws with, and reads a bundle back.
- `ent_renderer`: the renderer core both renderers share (render lists, programs, lights, shadows, textures,
  environment maps, passes, `EntView`), written against the small GPU interface of `package:ent_renderer/gpu.dart`.
- `ent_flutter`: `FlutterGpuRenderer` on Flutter GPU. About 160 scenes are compared pixel by pixel with the reference's
  frames from headless Chrome (2/255 per channel, edge pixels within 1 px, at most 0.5% of pixels): shadows, PBR and
  physical materials, environment maps, skinning, morphs, instancing, render targets, MSAA, post-processing, depth
  textures, viewport and scissor, and ten Khronos glTF sample models.
- Metal on the M1 matches except for recorded allowances (`test/parity.dart`: `mipmaps`, `ties`); the iPhone 11 has
  three more (`ios`). Under flutter_tester (Impeller on Vulkan through SwiftShader) scenes that SwiftShader filters or
  rasterizes differently run on Metal only (`swiftShader`).
- `ent_opengl`: `OpenGlRenderer` on OpenGL ES 3, on ANGLE (the `wrangle` package, on pub.dev) on macOS and the
  system's OpenGL ES on Android (`docs/opengl.md`). It passes the same scenes on the M1 with no `mipmaps` allowances,
  and on a Galaxy S10 differs from the M1 only where Chrome on that phone differs alike.
- Android: `ent_opengl` draws on OpenGL ES devices (checked on the Galaxy S10). Flutter GPU needs a device where
  Impeller runs on Vulkan and draws nothing on its OpenGL ES fallback (flutter/flutter#196045); no such device has
  been tested.

## Next milestone: ready for others

Only this repository's own tests use the packages. This milestone makes `ent` and `ent_flutter` usable by someone else:
a deliberate public API, docs to start from, publishable metadata and checks that run without us. Nothing is published,
pushed or posted without Kai's go-ahead for that step. Small jobs, in this order unless Kai reorders them:

1. P1, public API audit: what each package exports, what is internal (`src/` only), what a user needs; every public
   member documented (`dart doc` builds without warnings); the exceptions a user meets (the Flutter GPU switch, the
   `E-*` rows) linked from the API where they apply.
2. P2, READMEs and a getting-started example: a README per package (`ent` has none), covering what it is, platforms,
   the Flutter GPU switch and a minimal scene; a small example app beside the viewer; a user-facing summary of what
   differs from the reference.
3. P3, licenses and metadata. Licenses done: MIT, © KAMORA Ltd., in the root and every package; each package's
   `THIRD_PARTY_NOTICES.md` holds the reference's notice (and earcut's in `ent`); the Khronos models' attribution stays
   with the models in `fixtures/gltf/khronos/`. Metadata done: descriptions, topics, CHANGELOGs, version `0.1.0-dev.1`,
   caret ranges, and every package and example asking for the others from pub.dev: the repository has no path
   dependencies or overrides (Kai, 2026-11-25), so its tests and CI run against the published versions, and a change
   to one package reaches the others once it is published. `dart pub publish --dry-run` warns only of
   uncommitted files. The repository is `github.com/kamora/ent` (public): every pubspec names it, and the READMEs link
   into it, so the links work on pub.dev. `ent` and `ent_shaders` must be published before `ent_flutter` (`ent_shaders`
   was free on 2026-11-23). `ent` and `ent_flutter` were free on pub.dev on 2026-11-10; a name is held only by its first
   upload.
4. P4, CI: a workflow running the unit tests, the flutter_tester suite, the Metal parity suite and analyze/format.
   Two probes (2026-11-17) answered the guesses: GitHub's `macos-15` runner gives Flutter GPU Metal, and its 176
   parity frames equal the M1's line for line (after one `flutter build macos --debug`, which the device test needs on
   a fresh checkout); `ubuntu-latest` runs the flutter_tester suite and every test passes, but flutter_tester crashes
   (segmentation fault) while shutting down after `parity_test.dart`, in both probes and not on the Mac. This release
   supports neither Linux nor Windows (Kai, 2026-11-17), so CI runs on macOS only and the crash waits for Linux
   support (known gaps). The workflow is `.github/workflows/ci.yml`: a host job (format, analyze, `ent`'s tests, the
   flutter_tester suite, the disabled-GPU test) and a Metal job (one build, the parity suite, getting started), both
   on `macos-15`, for pushes to master and pull requests. Its first full run passed on 2026-11-17 (`051c5d4`): host
   about 30 min, Metal about 8 min. macOS arm64 runners were short that day: two attempts timed out in the queue. A
   third job, `opengl`, runs `ent_opengl`'s tests and its example's backend, surface and parity tests on ANGLE; its
   first run passed on 2026-11-24 (`1db439f`, about 21 min).

## Known gaps

Rendering:

- Multiple render targets (`count > 1`) are ignored with a warning.
- On Flutter GPU, mip levels are built on the CPU; ANGLE builds them on the GPU, which is behind the `mipmaps`
  allowances (E-MIPFILTER). A GPU build matches its first level, not the deeper ones. `ent_opengl` builds them on the
  GPU and needs no allowance.
- `ent_opengl`: no readback of non-8-bit textures; iOS, Windows and Linux not yet (`docs/opengl.md`, Limits).
- BoxTextured is skipped: 2 pixels at 3/255, the GPU's level of detail, cause unknown.
- Shadows: PCF on point lights is checked on Metal only (filtering across cube seams under SwiftShader); no point
  scene with a non-zero bias, no ShadowMaterial scene with a point light; `customDistanceMaterial` not checked.
- Steep highlights at low roughness differ 3–7/255 from Chrome, so scenes keep roughness ≥ 0.45
  (docs/flutter-gpu.md).
- FloatType render targets sampled linearly stay unfiltered on GPUs without float filtering (the A13).
- Lines, points and sprites in depth textures; transmission inside a viewport.

Devices:

- Flutter GPU on Android has run nothing by default; a Vulkan device is needed. Both test phones fall back to
  OpenGL ES (Galaxy A22, MediaTek; Galaxy S10, Exynos 9820), and Flutter never picks Vulkan on an emulator. They run
  `ent_opengl` instead; the A22 has not run it yet.

Performance, for when an app needs more than a few hundred separate draws at 60 fps on the iPhone 11 (one
InstancedMesh holds 60 fps at 2000):

- Uniform members resolved once into int fields (a guess: 4–6% of `render`).
- Uniform blocks split by per-object, per-material and per-frame members and filled only when they change, as the
  reference does (a guess: up to about 30%).
- GPU time per frame, and the cost of MSAA, are not measured.

Linux (not in this release): flutter_tester on GitHub's `ubuntu-latest` passes every test but crashes (segmentation
fault) while shutting down after `parity_test.dart`; cause unknown. No renderer's hook builds for Linux yet, so its
bundles are empty there; which backends Linux keeps is decided when it is supported.

Tooling: on a fresh checkout an app's device tests need one build first (Flutter collects assets before the shader
hook runs on that path; `docs/flutter-gpu.md`, "Flags"). Data assets would remove it once Flutter stable has them.

Content: MetalRoughSpheres (11.2 MB, not fetched); Draco, KTX2/Basis, sheen and anisotropy are not supported.
