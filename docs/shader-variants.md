# Shader variants

Design note, implemented for every material that draws meshes, lines, points and sprites (ShadowMaterial keeps its
fixed shader). Each material kind's fragment stage is a variant an app registers and the build compiles (E-SHADERS);
nothing compiles on the device. The shaders, the registry code and the build hook are in `packages/ent_shaders`, shared
by every renderer.

## Goal

- The bundle holds only the variants the app uses, for the one GPU backend its target runs.
- A shader is written the way the reference writes it: `#ifdef USE_MAP` and similar flags instead of uniform switches.
- A missing variant is a clear error naming the variant and the registry line to add, never a silent fallback.
- Custom shaders later use the same path.

## Model

**Flags** are what the reference expresses as program defines: the presence or kind of a feature, such as `USE_MAP`,
`USE_NORMALMAP_TANGENTSPACE` or `POLYGON_OFFSET`. Values stay uniforms: colours, factors, matrices, light data.

Flags are **material facts only**: what the material and its textures are, known from the assets and fixed while the app
runs. Object and scene features (skinning, morphs, instancing, batching, instance and batch colours, vertex colours,
lights, shadows, fog, tone mapping) belong to the engine: it picks the vertex stage per object and switches the rest by
uniforms, so the registry never lists them and a runtime change (a light on, a mesh instanced) never needs a new
variant. Vertex colours follow that rule: the vertex stage reads white for a material without `vertexColors`, and a
variant always multiplies by them.

A **variant** is one material kind with a set of flags, built as a fragment shader over the engine's vertex stages. Its
**key** is the kind and the sorted flags, for example `lambert map normal_map`. The bundle names its shader after the
key.

The renderer computes a draw's flags from the material, keeps those its kind accepts (`ent_shaders`'
`lib/src/variants.dart`), then looks the key up in the bundle.

## Registry

The app lists its variants in a JSON file and points `ent_shaders`' build hook at it from its `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    ent_shaders:
      shaders: ent_shaders.json
```

```json
{
	"variants": [
		"basic",
		"basic map",
		"standard map normal_map env_map skinning",
		"standard map polygon_offset"
	]
}
```

The hook reads it through `input.userDefines.path('shaders')` and declares it a dependency, so editing it rebuilds the
bundle. The app writes no hook of its own.

**Recording.** While `FlutterGpuRenderer.recorded` is set, the renderer adds every key a draw or `compile` needs,
registered or not, and skips an object whose variant is missing (with a warning) instead of throwing. Running the
app once through its scenes and saving the keys fills the registry (docs/usage.md). It is off by default, in debug
and release alike.

**Missing variant.** Outside recording, the draw throws a `StateError` naming the key and the line to add. Debug and
release behave the same.

## Build

1. Read the registry and validate each key against the flags its kind accepts.
2. Generate one small source per shader into `build/`: the flags as `#define` lines, then `#include` of the kind's GLSL.
   Bundle entries cannot carry defines of their own (`impeller/compiler/shader_bundle.cc` accepts only `file`, `type`,
   `language` and `entry_point`), so the defines live in these generated files.
3. Compile them into the bundle with impellerc.
4. Strip the bundle to the target's backends: Metal iOS; Metal desktop, Vulkan (`flutter test` runs Vulkan) and
   OpenGL ES (macOS); Vulkan and OpenGL ES (Android); another target keeps all five. The OpenGL ES backend is GLSL ES
   3.00 (`--gles-language-version=300`), for the GL renderer. impellerc ignores platform flags in bundle mode, so
   `lib/src/bundles.dart` rewrites its FlatBuffer output (`flat_buffers`), with the target OS from the hook's code
   config. Measured before OpenGL ES was kept: 14.9 MB becomes 3.1 MB (iOS), 5.6 MB (macOS), 2.5 MB (Vulkan only).
   Keeping OpenGL ES took the test registry's macOS bundle from 21.2 MB to 33.3 MB (2026-11-23); an app should keep
   only the backends of the renderers it uses (not done yet). `readBundle` reads one backend's shaders, with their
   inputs, uniform blocks and textures, for a renderer that loads the bundle itself.
5. Write `build/shaderbundles/ent.shaderbundle.owner` (the target OS and the registry) and declare it an input of
   the hook: every build writes the same bundle, so one for another target or registry replaces it and rewrites the
   stamp, and the next build for this one reruns the hook (checked: iOS, then macOS, then iOS). The stamp is dated
   2000, so the hook runner does not take it for a file changed during the build; the bundle keeps its own date, so
   `flutter test` copies it into its assets.

The engine's internal shaders (environment maps, mips, shadows, clear, frame) and the post-processing effects are always
compiled; they are not material variants.

## Tests

The test suite registers its own list: every key the parity scenes need, recorded the same way.

## Open questions

- Shared output: the bundle is written inside `ent_flutter`'s own `build/`, so two apps using one copy of the
  package (the pub cache) rebuild it for each other's registry. Dart data assets, which write into the hook's own
  output, would fix that; `flutter_gpu_shaders` supports them, still experimental.
- Android: the stripping is checked for iOS, macOS and `flutter test`, not yet in an Android build.
- Basic still switches its env map, fog, tone mapping and line rule by uniforms, Normal its flat shading, double
  side and tangents; only their maps, vertex colors and polygon offset are flags so far.
- Missing variant mid-frame: the StateError leaves that frame half drawn, and in a long run the frames after it went
  wrong too (seen in the parity runs); the renderer should fail before it starts drawing, or skip only that object.
- Build time: impellerc compiles each variant for five backends before stripping; a large registry builds slowly.
- Size: a lit variant carries the whole light code: Lambert about 140 KB (Metal) and 90 KB (Vulkan), a physical
  variant about 160 KB and 115 KB; the legacy shaders stay in the bundle until job 5.
- No registry: whether an app without one gets a small default list or a build error naming the setting.

## Rules the compiler and the engine impose

- **Declare only what you read.** impellerc drops a uniform block or sampler a stage never reads while its reflection
  keeps it, so the renderer binds it out of range: a bus error on Metal, a segfault or silence under SwiftShader. A
  guard therefore covers a declaration and every read of it alike; a physical variant without maps declares no
  SlotInfo, UvInfo or map slots (`SLOT_MAPS`, `shaders/slots.glsl`), and with a normal map a bump map is not a flag.
  `test/variants_metal_test.dart` compiles every registered variant for Metal and checks this.
- **One entry point per shader.** impellerc names a shader's entry point after its source file and the engine
  registers shaders by it, so two files with one stem replace each other silently. Variant sources are
  `variant__<key with __>.frag`, or past 100 characters `variant__<kind>__x<FNV-1a of the key>.frag` (a file name
  holds 255 bytes); `test/variants_test.dart` checks every entry point is unique.

## Jobs

1. MeshBasicMaterial end to end: flags, generated sources, registry, lookup, the missing-variant error, parity. Done
   for its maps, vertex colors and polygon offset (`ent_shaders`' `lib/src/variants.dart` and `hook/build.dart`).
2. Backend stripping in the hook. Done.
3. The other materials, one per job. Done: Normal (`normals.glsl`, with `flags.glsl` shared by every chunk),
   Lambert, Phong and Toon (their maps and Toon's gradient map; their lights still switch by uniforms), Matcap,
   and Standard as the kind `physical` without layers (its maps, roughness and metalness; texture slots kept).
   Physical's layers (B) are flags too: `clearcoat`, `sheen`, `iridescence`, `anisotropy`, `diffuse_roughness`
   (LAYER_*), and every physical map one bit of PHYSICAL_MAPS (`useMap`). Transmission (C) too: `transmission`
   (TRANSMISSION, which also reads the scene behind the object from slot 14), `dispersion`, `transmission_map` and
   `thickness_map`; the last three only with `transmission`. The widest variant reads 21 maps, through the
   texture slots.
4. Recording mode (`recorded`). Done.
5. Remove the uniform-switch shaders and their programs; rewrite E-SHADERS. Done: the fixed mesh material shaders
   (5a), the switches of the variant-only chunks (5b), Depth (`rgba_packing`, `rgb_packing`, `rg_packing`; drawing a
   shadow map stays a uniform), Distance and Dashed as kinds, and the shared map switches (5c), Points and Sprite
   (5d), E-SHADERS and docs/flutter-gpu.md (5e).
