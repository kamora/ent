# Shader variants

Design note, implemented for every material that draws meshes, lines, points and sprites (ShadowMaterial keeps its
fixed shader). Each material kind's fragment stage is a variant an app registers and the build compiles (E-SHADERS);
nothing compiles on the device. The shaders and the variant scheme are in `packages/ent_shaders`, shared by every
renderer. Each renderer package compiles them into its own form with its own build hook: `ent_flutter` and `ent_opengl`
both through `packages/ent_impeller`, the toolchain on Impeller's shader compiler.

## Goal

- The bundle holds only the variants the app uses, for the GPU backends its renderer runs on its target.
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

The app lists its variants in a JSON file and points its renderer's build hook at it from its `pubspec.yaml`, under
the renderer package's name (a hook reads only the user defines under its own package):

```yaml
hooks:
  user_defines:
    ent_flutter:
      shaders: ent_shaders.json
```

An app that uses `ent_opengl` names it under `ent_opengl:`. An app that uses both renderers, one per platform, names
the same file under both, and says in it which renderer draws on which platform:

```json
{
	"renderers": {
		"ios": "ent_flutter",
		"macos": "ent_flutter",
		"android": "ent_opengl"
	},
	"variants": ["basic", "lambert map"]
}
```

Each renderer's hook then compiles only for the platforms given to it, and writes an empty bundle elsewhere; its
`create()` there throws a `StateError` saying it was not built for the platform. Without `renderers`, a renderer
compiles for every platform it supports. The build fails when the map gives a renderer a platform it does not support
(`ent_opengl` on `ios`), or names a package the app does not have. A platform missing from the map gets no renderer.

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
3. Compile them, with the fixed shaders `ent_shaders`' `ent.shaderbundle.json` lists, into the renderer package's
   `build/shaderbundles/ent.shaderbundle` with impellerc. `ent_impeller` runs the Flutter SDK's impellerc itself
   (`IMPELLERC` when Flutter's tools set it, else the SDK's engine artifacts), with `ent_shaders`' root as the include
   folder, and declares every file impellerc's depfile lists as an input of the hook, the compiler too, so editing a
   shader or upgrading Flutter rebuilds the bundle.
4. Strip the bundle to the backends the renderer runs on the target. `ent_flutter`: Metal iOS (iOS); Metal desktop and
   Vulkan (macOS, where `flutter test` runs Vulkan); Vulkan (Android). `ent_opengl`: OpenGL ES, as GLSL ES 3.00
   (`--gles-language-version=300`), on macOS and Android. On a platform the renderer does not support, or one the
   registry gives to the other renderer, the hook compiles nothing and writes an empty bundle (checked in a scratch app
   with both renderers, 2026-11-25: macOS, iOS and Android each carry only their renderer's shaders). impellerc ignores
   platform flags in bundle mode, so `ent_impeller`'s `lib/src/bundles.dart` rewrites its FlatBuffer output
   (`flat_buffers`), with the target OS from the hook's code config. The test registry's macOS bundles (2026-11-25):
   22.0 MB for `ent_flutter`, 12.6 MB for `ent_opengl`; one bundle with both took 33.3 MB. `readBundle` reads one
   backend's shaders, with their inputs, uniform blocks and textures, for a renderer that loads the bundle itself.
5. Write `build/shaderbundles/ent.shaderbundle.owner` (the target OS, the registry and the compiler) and declare it
   an input of the hook: every build writes the same bundle, so one for another target or registry replaces it and
   rewrites the stamp, and the next build for this one reruns the hook. The stamp is dated 2000, so the hook runner
   does not take it for a file changed during the build; the bundle keeps its own date, so `flutter test` copies it
   into its assets.
6. The renderer loads the bundle as `packages/<renderer>/build/shaderbundles/ent.shaderbundle`, or, in the renderer
   package's own tests (where it is the root package and its assets have no prefix), as
   `build/shaderbundles/ent.shaderbundle`.

The engine's internal shaders (environment maps, mips, shadows, clear, frame) and the post-processing effects are always
compiled; they are not material variants.

## Tests

The test suite registers its own list: every key the parity scenes need, recorded the same way.

## Open questions

- Shared output: the bundle is written inside the renderer package's own `build/`, so two apps using one copy of the
  package (the pub cache) rebuild it for each other's registry. Dart data assets, which write into the hook's own
  output, would fix that; the hooks API has them, still experimental.
- Android: the stripping is checked for macOS and `flutter test`, not yet in an Android or iOS build since the hooks
  moved into the renderer packages.
- An app with both renderers runs impellerc twice, once per renderer hook, though each keeps different backends.
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
   for its maps, vertex colors and polygon offset (`ent_shaders`' `lib/src/variants.dart`, `ent_impeller`'s
   `compileShaders`).
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
