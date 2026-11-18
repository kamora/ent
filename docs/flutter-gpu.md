# Flutter GPU backend

How `FlutterGpuRenderer` in `packages/ent_flutter` uses Flutter GPU, what it draws, and how it is checked against
three.js r187. Every statement is measured on the Flutter installed here unless it is marked as a guess; nothing is
assumed from documentation alone.

## Environment

| | |
|---|---|
| Flutter | 3.47.6 (stable), Dart 3.13.5, at `/opt/homebrew/share/flutter` |
| `flutter_gpu` | ships in the SDK (`bin/cache/pkg/flutter_gpu`), imported as `flutter_gpu: sdk: flutter` |
| Shader compiler | `impellerc` in `bin/cache/artifacts/engine/darwin-x64`, driven by `flutter_gpu_shaders` 0.5.2 (pub.dev, BSD-3-Clause) through a build hook (`hooks` 2.2.0, BSD-3-Clause) |
| Machine | macOS 26.5.2 (25F84), Apple M1 (8-core GPU, Metal 4) |
| Devices | macOS desktop, iOS 26.5 simulators (iPhone 17), iPhone 11 (wired), Galaxy A22 (wired), Chrome |

## Platforms

| Target | Result |
|---|---|
| `flutter test --enable-impeller --enable-flutter-gpu` (flutter_tester) | Works: offscreen rendering, readback through `Texture.asImage()` + `toByteData`. flutter_tester runs Impeller on Vulkan through its bundled SwiftShader, on the CPU, not Metal; SwiftShader logs `VkImage.cpp` warnings at run time, and only here does `LoadAction.load` clear (flutter/flutter#196199). The renderer and parity unit tests run here, so they check SwiftShader; Metal is checked by the app integration tests (macOS, iPhone) |
| macOS desktop app | Works on Metal; see "macOS run" |
| Web (Chrome) | Not supported: `flutter_gpu` binds native engine symbols (`dart:ffi`, `@Native`) |
| iOS simulator (iPhone 17, iOS 26.5) | Works: `flutter test integration_test/render_test.dart -d <id> --enable-flutter-gpu` in `examples/worm` passes; the three sampled pixels equal the golden exactly. `ios/Runner/Info.plist` sets `FLTEnableImpeller` and `FLTEnableFlutterGPU` |
| iPhone 11 (iPhone12,1, A13, iOS 16.3.1, wired) | Works: the render test passes, and the Metal parity suite passes with three recorded allowances (see "iPhone 11"). The A13 skips, without an error, the draw of a pipeline whose stage declares more than 16 sampler states (hence the texture slots, "Programs and uniforms"), samples float32 textures with nearest filtering (hence the half-float LTC tables and E-FLOATFILTER), and reads a depth buffer as a texture |
| Android, Galaxy A22 (SM-A225F, MediaTek MT6768, Mali-G52, Android 13, vendor API 31) | Fails: Impeller picks OpenGL ES, because Flutter avoids Vulkan on MediaTek devices below vendor API 32 (`android_context_dynamic_impeller.cc`, a workaround for AHB import crashes); on that backend the render test reads an all-black frame. A probe isolated it to Flutter GPU itself: uploading a texture and reading it back works, but a render pass writes nothing to its color attachment, not even the clear, in device-private or host-visible storage, also after waiting for the command buffer to complete. Android therefore needs a device where Impeller picks Vulkan; `FlutterGpuRenderer.create()` checks this and throws. Reported upstream: flutter/flutter#196045. Flutter also avoids Vulkan on Adreno 650 and older, older PowerVR, Huawei Maleoon and Samsung Xclipse below Vulkan 1.3 (`driver_info_vk.cc`) |
| Android, Galaxy S10 (SM-G973F, Exynos 9820, Mali-G76, Android 12, Vulkan 1.1) | Fails: Impeller picks OpenGL ES, because Flutter lists `exynos9820` among its known-bad SoCs (`android_context_dynamic_impeller.cc`, graphical errors, flutter/flutter#171992); `create()` throws its StateError. Forced to Vulkan (`io.flutter.embedding.android.ImpellerBackend` set to `vulkan`, honored in debug and profile only), Impeller starts on Vulkan, then about 8 s later logs "Fence waiter encountered an unexpected error" and the getting-started test never completes, twice in two runs. Isolated (2026-11-18): plain Flutter widgets and `create()`'s clear and readback pass on it; one frame each of a clear, MeshBasicMaterial, unlit MeshLambertMaterial and MeshPhongMaterial, and MeshNormalMaterial draws correctly; MeshStandardMaterial (no lights) and MeshPhysicalMaterial hang reading the frame back, with the fence error. It hangs even when the physical fragment shader returns on its first line (a uniform-keyed exit, scratch copy); lambert uses the same vertex shader. Cause found: the physical stage declares samplers it never reads (`roughness_map`, `metalness_map`, `dfg_lut` and the other map names it reads through `slot_k`, and `light_texture_0` to `_5` from `lights.glsl`). The compiler drops them, but its reflection keeps all nine at binding 0, and Flutter GPU makes a descriptor-layout entry for each, so the layout repeats binding 0; lambert's stage has no such samplers. Textured variants also declared `map`, `normal_map` and the other shared map samplers that way. Fixed (2026-11-18): a stage that reads through slots declares no sampler by name (`physical.glsl`, and `#ifndef TEXTURE_SLOTS` in `lights.glsl`, `maps.glsl` and `normals.glsl`), and `test/variants_metal_test.dart` no longer exempts the physical stages. On the S10 with the fix, Vulkan still forced: no fence error in any run; the getting-started test passes (3 of 3); unlit standard, lit physical (clearcoat) and a textured lit standard draw what macOS draws. Two more findings: (1) the draw probe stopped silently while the phone was locked (Android stops the activity behind the lock screen); unlocked, it completes. (2) A frame read back right after `render` is sometimes empty: in 2 of 2 runs the lit standard frame read [0,0,0,0] everywhere (not even cleared), and once the lit physical frame had its background but not its sphere, while the same image read 1 s later was right every time. Flutter GPU submits straight to the Vulkan queue and the readback is queued after it, so the readback seems not to wait for the render's writes on this driver (an inference from the engine source, not proven). Worked around (2026-11-18): `readRenderTargetPixels` and the checks in `check.dart` wait until every submitted command buffer has completed (`HostBuffers.idle`). On the S10, lit standard, physical and lambert frames read through `readRenderTargetPixels` right after rendering: 12 of 12 right with the wait; without it, the first physical and lambert reads were [0,0,0,0] in 2 of 2 runs. `render`'s returned image: an app reads its pixels after awaiting `renderer.idle()` (2026-11-18), which waits as `readRenderTargetPixels` does. On the S10, lit standard, physical and lambert images read with `toByteData` right after `render`: 18 of 18 right after `idle()` (2 runs); without it, 6 of 36 reads were [0,0,0,0] (2 runs). On screen it does not show: an `EntView` with a lit standard sphere and a lit physical cube, recorded with `adb shell screenrecord` (about 60 frames a second), had both objects in every frame, 1198 of 1198 over 20 s, and in each of 3 cold starts from the first frame the app showed (946 frames); none was black or background only (2026-11-18). |

## Flags

- `flutter test` and `flutter run` (desktop) take `--enable-flutter-gpu`; `--enable-impeller` for flutter_tester.
- A built macOS or iOS app reads `FLTEnableImpeller` and `FLTEnableFlutterGPU` from `Info.plist`; both are set to
  `true` in `examples/worm/macos/Runner/Info.plist` and `examples/worm/ios/Runner/Info.plist`.
- Android reads the `io.flutter.embedding.android.EnableFlutterGPU` metadata key in `AndroidManifest.xml` (named
  by Flutter's own error message; not tried on a device where Impeller uses Vulkan).
- The bundle is an asset `ent_flutter` declares (`build/shaderbundles/ent.shaderbundle`), written by its build hook.
  `flutter build`, `flutter run` and `flutter test` on the host run the hook before they collect assets; `flutter
  test integration_test -d <device>` collects them first, so with no bundle yet (a fresh checkout, `flutter clean`)
  it stops with "No file or variants found for asset" (Flutter 3.47.6, macOS, 2026-11-17; the app's own build then
  copies the hook's bundle, byte for byte). Building once first avoids it. `flutter_gpu_shaders`' data-asset mode
  would drop the pubspec entry, but Flutter 3.47.6 stable reports data assets as unavailable.
- Without the switch, `gpu.gpuContext` throws; `FlutterGpuRenderer.create()` turns that into a `StateError` that
  names the switch (`test/disabled_test.dart`, run without the flag).

## API surface used (this Flutter version)

- `gpu.gpuContext`: `createTexture(StorageMode, w, h, format:, mipLevelCount:, enableRenderTargetUsage:,
  enableShaderReadUsage:, textureType:, sampleCount:)`, `createDeviceBufferWithCopy(ByteData)`,
  `createDeviceBuffer(StorageMode, size)`, `createCommandBuffer()`, `createRenderPipeline(vertex, fragment,
  vertexLayout:)`, `defaultColorFormat` (`b8g8r8a8UNormInt` here), `defaultDepthStencilFormat` (`d32FloatS8UInt`
  here), `maxSamplerAnisotropy`, `minimumUniformByteAlignment`, `doesSupportOffscreenMSAA`.
- `gpu.ShaderLibrary.fromAsset(key)` (async), `library['Name']` → `gpu.Shader`, `shader.getUniformSlot('Block')`
  with `sizeInBytes` and `getMemberOffsetInBytes(member)` (std140 offsets from shader reflection); a sampler is
  a uniform slot by its name.
- `Texture.overwrite(ByteData, mipLevel:, slice:)` (a blit per level; cube faces +X, -X, +Y, -Y, +Z, -Z),
  `Texture.fullMipCount`, `Texture.asImage()`.
- `CommandBuffer.createRenderPass(RenderTarget.singleColor(ColorAttachment(...), depthStencilAttachment:
  DepthStencilAttachment(...)))`, `submit(completionCallback:)`. `ColorAttachment(mipLevel:, slice:)` renders into
  one level of one face; `ColorAttachment(resolveTexture:, storeAction: StoreAction.multisampleResolve /
  storeAndMultisampleResolve)` resolves 4× samples; `LoadAction.load` continues a target.
- `RenderPass`: `clearBindings`, `bindPipeline`, `bindVertexBuffer(BufferView, slot:)`,
  `bindIndexBuffer(BufferView, IndexType)`, `bindUniform(UniformSlot, BufferView)`,
  `bindTexture(UniformSlot, Texture, sampler: SamplerOptions(...))`, `setCullMode`, `setWindingOrder`,
  `setDepthWriteEnable`, `setDepthCompareOperation`, `setColorBlendEnable`, `setColorBlendEquation`,
  `setPrimitiveType`, `setViewport`, `setScissor`, `draw` and `drawIndexed` (with `instanceCount`).
- `VertexLayout(buffers: [VertexBuffer(strideInBytes:, stepMode:, attributes: [VertexAttribute(name:, format:)])])`:
  one buffer per attribute, slot = list index; `VertexStepMode.instance` for instanced attributes.
- `DeviceBuffer.overwrite(ByteData, destinationOffsetInBytes:)` on host-visible blocks for per-draw uniforms and
  generated indices (`HostBuffers`, below; Flutter GPU's own `HostBuffer` is not used).
- Formats: `PixelFormat.r16g16b16a16Float` and `r32Float` as render targets and textures,
  `r8g8b8a8UNormIntSRGB` for sRGB textures. One pipeline renders into 8-bit, sRGB, half-float and 4× multisampled
  targets alike (Flutter GPU builds the variant per pass). A pass may sample one mip level of the texture it renders
  into another level of (checked against a CPU box filter: exact).

Not available in this version, and what the renderer does instead: no color write mask (`colorWrite: false`
blends with factors ZERO, ONE), no depth bias (`polygonOffset` writes the fragment depth in a shader variant),
no blend constant color and no MIN/MAX blend operations (exception E-BLEND), no `generateMipmap` (`CommandBuffer`
and `Texture` offer none, though a doc comment names a `CommandBuffer.generateMipmap`; levels of uploaded textures
are box-filtered on the CPU, those of render targets by a render pass per level), no 1×1 mip level (exception
E-MIPMAP), no line width, no line loop, no multi-draw and no `gl_DrawID`, no RG half-float format.

Hardware behaviour measured: cube textures sample with the GL cube map table (a face's first row is t = 0),
seamlessly across faces; on the M1 a fragment stage may bind more than 16 samplers (24 tested), the A13 skips a
pipeline with 17; `dFdx` and `dFdy` are coarse, one value per 2 × 2 quad taken from its
top-left pixel (Apple M1).

## Conventions the renderer handles

- **Depth range.** Impeller clip space has z in [0, 1]. The renderer sets `camera.coordinateSystem =
  WebGPUCoordinateSystem` and calls `updateProjectionMatrix()`, exactly what three.js's WebGPURenderer does,
  so projection matrices and frustum culling use the [0, 1] range. Depth clears to 1 and compares with the
  material's `depthFunc`; with `depthTest: false` depth is neither tested nor written, as in GL.
- **Winding.** Front faces are counter-clockwise (three.js convention). As `WebGLState.setFlipSided`, the winding
  flips to clockwise for `BackSide` and for a mirrored object (`matrixWorld.determinant() < 0`), and back faces
  are culled unless the side is `DoubleSide`; `gl_FrontFacing` follows.
- **Orientation.** The rendered texture comes out upright (+y up in NDC is the top row of the image), verified
  by the triangle test. Window y points down, so `dFdy` has the opposite sign of WebGL's; the shaders negate it
  wherever upstream uses it (`dFdyGL` in `normals.glsl`: flat shading, the tangent frame, bump mapping).
- **Bindings persist across draws.** A program with fewer vertex slots inherits the previous draw's buffers;
  the renderer calls `clearBindings()` before each draw. The primitive type persists in a pass too and is set per
  draw.
- **Blend state persists too.** After a draw with non-default blend factors, `setColorBlendEnable(false)` alone
  leaves the next opaque draws invisible (the factors stay in effect). The renderer resets the equation to the
  default whenever it disables blending.
- **Color.** Material colors are linear; the output color space (`renderer.outputColorSpace`, sRGB by default)
  is applied in the shader (`colorspace_fragment`); MeshNormalMaterial writes raw `normalize(n) * 0.5 + 0.5`.
  The clear color and a `Color` background are converted to the output color space and premultiplied by
  alpha, as WebGLBackground does.
- **sRGB textures.** 8-bit RGBA textures whose color space has the sRGB transfer use
  `r8g8b8a8UNormIntSRGB`, so the hardware decodes before filtering, as WebGL's `SRGB8_ALPHA8`; generated
  mip levels average in linear light (the same as Chrome's levels in `map_mipmaps_minified`).

## Programs and uniforms

A material kind's fragment stage is a build-time variant the app registers (`lib/src/gpu/variants.dart`,
`docs/shader-variants.md`, exception E-SHADERS); the mesh kinds share the vertex stage `shaders/mesh.glsl`, compiled
as:

| Entry | Defines | Source |
|---|---|---|
| `MeshVertex` | | `mesh.vert` |
| `MeshSkinVertex` | SKINNING | `mesh_skin.vert` |
| `MeshMorphVertex` | MORPHTARGETS | `mesh_morph.vert` |
| `MeshSkinMorphVertex` | SKINNING, MORPHTARGETS | `mesh_skin_morph.vert` |
| `MeshInstanceVertex` | INSTANCING | `mesh_instance.vert` |
| `MeshInstanceMorphVertex` | INSTANCING, MORPHTARGETS | `mesh_instance_morph.vert` |
| `MeshInstanceMorphTextureVertex` | INSTANCING, MORPHTARGETS, INSTANCING_MORPH | `mesh_instance_morph_texture.vert` |
| `MeshBatchVertex` | BATCHING | `mesh_batch.vert` |

The vertex stage computes the uv transforms and channels of nine maps, vertex color, the view-space normal with
FLIP_SIDED, tangent and bitangent (USE_TANGENT), the displacement map, view and world position, clip-space z and w,
the raw `uv` and `uv1` (`v_uv`, for the physical maps, whose transforms run in the fragment stage: fifteen more uv
varyings would not fit), and MeshBasicMaterial's `vReflect` (envmap_vertex). Fragment stages are built from shared
parts: `maps.glsl` (map, color, alphaMap, alphaTest, aoMap, lightMap, emissiveMap, specularMap), `normals.glsl`
(normal_fragment_begin and normal_fragment_maps: flat shading, double-sided flip, tangent-space and object-space
normal maps, bump maps; the tangent frame on its own for the physical material), `lights.glsl`
(lights_pars_begin and lights_fragment_begin), `envmaps.glsl` (envmap_common_pars_fragment, envmap_fragment's
cube map combine, envmap_physical_pars_fragment's PMREM irradiance and radiance), `common.glsl`, and
`output.glsl`, the common tail of r187's fragment shaders (OPAQUE, tone mapping, output color space, fog,
PREMULTIPLIED_ALPHA), which includes `offset.glsl` (the polygon offset). MeshStandardMaterial and
MeshPhysicalMaterial share the kind `physical` (`physical.glsl`, with `transmission.glsl`). Points and sprites
have their own vertex stages (`PointsVertex`, `SpriteVertex`) and fragment kinds. The fragment stage's `#ifdef`
features are the variant's defines; the vertex stage's, and the environment map, fog, tone mapping, lights and
shadows in both, are `float` uniforms (1 or 0) in these blocks:

| Block | Stage | Content |
|---|---|---|
| `VertInfo` | vertex | `projection_matrix`, `model_view_matrix`, `model_matrix`; `normal_matrix` and the `<map>_transform`s (mat3 as the upper-left of a mat4); `<map>_channel` (0: uv, 1: uv1); `flip_sided`, `use_tangent`, `use_displacement_map`, `displacement_scale`, `displacement_bias`; `env_vertex` (0, 1 reflection, 2 refraction), `refraction_ratio`, `is_orthographic`, `camera_position`, `view_matrix`, `line_scale` (dashed lines); sampler `displacement_map` |
| `SkinInfo` | vertex | skinned stages only: `bind_matrix`, `bind_matrix_inverse`, `bone_texture_size` (skinning_pars_vertex); sampler `bone_texture` |
| `MorphInfo` | vertex | morphed stages only: `influences[16]` (vec4s, 64 influences), `base_influence`, `count`, `stride`, `width`, `rows`, `height` (the texture's), `first` (a non-indexed range's first vertex), `positions`, `normals`, `colors` (0, 1 USE_COLOR, 2 USE_COLOR_ALPHA), `instance_width`, `instance_height` (INSTANCING_MORPH); sampler `morph_targets_texture` |
| `BatchInfo` | vertex | batched stage only: the instance's matrix and color |
| `FragInfo` | fragment | the kind's own uniforms (basic: `diffuse`, `opacity`, `line_projection`, `line` (target width, height, 1 for a line), and for dashed lines `dash_size`, `total_size`; normal: `opacity`; Lambert and Toon: `diffuse`, `opacity`, `emissive` (× emissiveIntensity); Phong: + `specular`, `shininess`; Matcap: `diffuse`, `opacity`; Depth: `opacity`, `shadow` (1 while drawing a shadow map); Distance: `reference_position`, `near_distance`, `far_distance`; points: `diffuse`, `opacity`, `uv_transform`, `points_uv` (USE_POINTS_UV), `alpha_test`; sprite: `diffuse`, `opacity`, `alpha_test`; physical: `diffuse`, `opacity`, `emissive`, `roughness`, `metalness`, `ior`, `specular_intensity`, `specular_color`, `clearcoat`, `clearcoat_roughness`, `clearcoat_normal_scale`, `iridescence`, `iridescence_ior`, `iridescence_thickness_minimum`/`_maximum`, `sheen_color` (× sheen), `sheen_roughness`, `anisotropy_vector`, `diffuse_roughness`, `retroreflectivity`, `transmission`, `thickness`, `attenuation_distance`, `attenuation_color`, `dispersion`, `transmission_size`; every variant declares them all, and reads a layer's only when the layer is one of its flags) |
| `MapInfo` | fragment | `alpha_test`, `ao_map_intensity`, `light_map_intensity`; vertex colors always multiply (white without them) |
| `NormalInfo` | fragment | `normal_matrix` (object-space normal maps), `normal_scale`, `bump_scale` (both negated for BackSide, as refreshUniformsCommon), `double_sided`, `flat_shaded`, `flip_sided`, `use_tangent` |
| `LightInfo` | fragment | `view_matrix`, `ambient_light_color`, `is_orthographic`, `light_probe[9]`, `light_probes`, `receive_shadow`, `light_counts` (directional, point, spot, hemisphere), then per type vec4 arrays: `directional_direction`/`_color`, `point_position` (w distance)/`point_color` (w decay), `spot_position` (w distance)/`spot_direction` (w decay)/`spot_color`/`spot_cone` (coneCos, penumbraCos), `hemi_direction`/`hemi_sky_color`/`hemi_ground_color`, `rect_areas` with `rect_position`/`rect_half_width`/`rect_half_height`/`rect_color` (view space; read by the physical program only); then the shadows: `shadow_info` (NUM_DIR_LIGHT_SHADOWS, the type: 0 Basic, 1 PCF, the target's height for gl_FragCoord in GL's orientation, HAS_NORMAL), `directional_shadow_matrix[4]`, `directional_shadow[4]` (intensity, bias, normalBias, radius), `directional_shadow_size[4]` (mapSize; z: the map's light texture); `spot_shadows`, `spot_light_matrix[4]`, `spot_shadow[4]`, `spot_shadow_size[4]` (mapSize, shadow slot, map slot); samplers `light_texture_0` … `_5` (Lambert, Phong, Toon, physical, ShadowMaterial) |
| `EnvInfo` | fragment | `env_rotation` (envMapRotation or environmentRotation, transposed, mirrored in x for a CubeTexture), `view_matrix`, `camera_position`, `env_type` (0 none, 1 ENVMAP_TYPE_CUBE, 2 ENVMAP_TYPE_PMREM), `env_intensity`, `env_max_lod`, `reflectivity`, `refraction_ratio`, `env_refraction`, `combine`, `world_position` (ENV_WORLDPOS), `is_orthographic`; samplerCube `env_map` (Basic, Lambert, Phong, physical) |
| `UvInfo` | fragment | physical only: `transform[15]`, `channel[4]` of the maps roughness, metalness, clearcoat, clearcoatRoughness, clearcoatNormal, sheenColor, sheenRoughness, iridescence, iridescenceThickness, anisotropy, specularIntensity, specularColor, diffuseRoughness, transmission, thickness |
| `SlotInfo` | fragment | physical only: each map's texture slot (−1 for none) |
| `TransmissionInfo` | fragment | physical only: `model_matrix`, `projection_matrix` (the refracted ray's projection) |
| `OutputInfo` | fragment | `fog_color`, `fog_mode` (0, 1: Fog, 2: FogExp2), `fog_near`, `fog_far`, `fog_density`, `opaque`, `premultiplied_alpha`, `tone_mapping` (the constant), `tone_mapping_exposure`, `output_srgb` |
| `OffsetInfo` | fragment | `polygon_offset` (factor, units); declared only in variants with `polygon_offset` |

The light uniforms are WebGLLights.setup and setupView once per frame (`lib/src/gpu/lights.dart`): lights
sorted shadow-casting first (`shadowCastingAndTexturingLightsFirst`), colors times intensity, ambient lights and
light probes summed, positions and directions in view space, `coneCos = cos(angle)`, `penumbraCos =
cos(angle × (1 − penumbra))`. The shaders hold at most 4 directional, 8 point, 4 spot, 2 hemisphere and 2 rect area
lights; the loops run to the counts in `light_counts`, lights past a maximum are dropped with one warning
(E-SHADERS).

The vertex layout is fixed for mesh programs: slots `position` (vec3), `normal` (vec3), `uv` (vec2), `uv1`
(vec2), `color` (vec4; a vec3 attribute is padded with alpha 1), `tangent` (vec4). A slot the geometry lacks is
bound to a shared default stream that reads as WebGL's disabled attribute, (0, 0, 0, 1). Samplers a material
does not use are bound to a 1×1 opaque black texture (a 1×1 black cube texture for `env_map`), which is also
what an unloaded texture reads as (WebGL samples an unbound texture as (0, 0, 0, 1)). Attributes are converted to
float32 streams per slot (interleaved attributes read through `getX`...).

Variants. The build hook (`hook/build.dart`) writes one source per registered key into `build/variants/`: the
key's defines, then its kind's GLSL (`sourceOf`), named `variant__<flags>.frag` (`fileOf`; impellerc names the entry
point after the file, and the engine registers shaders by it, so a stem must not repeat a fixed shader's). It
compiles them with the fixed shaders of `ent.shaderbundle.json` into one bundle, keyed by the variant key. Per
draw, `_variantOf` builds the key from the material (its maps, physical layers, depth packing, `polygonOffset`;
only the flags the kind accepts) and draws that bundle entry, with the samplers its flags add (`samplersOf`). The
flag `polygon_offset` (POLYGON_OFFSET) writes `gl_FragDepth` (factor × depth slope + units × 2^(exponent − 23), the
float-depth rule); writing the depth disables early depth testing, so only materials with `polygonOffset` use it.
In the kind `physical`, a layer or a specular map defines PHYSICAL, transmission TRANSMISSION, and each physical
map sets one bit of PHYSICAL_MAPS, as WebGLPrograms compiles a layer only for a material that uses it; the widest
variant reads 21 maps, through the texture slots below. Vertex stages are separate bundle entries, so a variant pairs with any vertex
stage at pipeline creation without more bundle entries.

Texture slots. Impeller gives every texture its own Metal sampler state, and the A13 binds at most 16 per stage.
So the physical variants bind through texture slots (`shaders/slots.glsl`, included first): 15 generic 2D
samplers `slot_0` … `slot_14` plus `env_map`, 16 sampler states on every platform. The light textures in use keep
their pool slot (light texture k in slot k, read directly, which keeps the inlined shadow lookups small), the DFG
table slot 13 (`dfgSlot`), the LTC tables of rect area lights slots 11 and 12 (`ltcSlots`, kept only while the
frame has a RectAreaLight, otherwise free for maps) and the transmission target slot 14. A variant without maps
declares no `SlotInfo` and only `slot_0` to `slot_5`, `slot_11` to `slot_13` (and `slot_14` with transmission)
and `env_map` (`SLOT_MAPS`, `ProgramVariant.endSlots`). Every other 2D texture of
the draw takes the next free slot (`ProgramVariant.bindTexture`), and the `SlotInfo` block names each map's slot. A
draw with more than 15 2D textures (maps, light textures, the DFG table, the transmission target) throws a
`StateError` naming the map that found no slot, as an unregistered variant does. Maps with the same texture and
sampler share a slot (glTF's metallicRoughness texture, for one): without transmission, LTC tables or shadow-casting
lights a material fits 14 distinct textures, and each light texture in use takes one more slot. So the widest variants
draw only with shared textures.

impellerc inlines every call, so where a slot read is written decides the shader's size: routing the shadow lookups
through the 15-way branch makes the Standard stage 1.36 MB of MSL, which flutter_tester does not finish compiling
in 2 minutes. So `readSlots` (`physical.glsl`) reads every map of the draw once at the start of `main`, in a loop
over the variant's map reads (12, 23 or 25; the bump map counts three, at its uv and one pixel right and up) whose
body holds the stage's only 15-way branch; impellerc keeps it a loop. Each read lands in `slot_reads`, and the
macros turn `texture(name, uv)` of a map into its entry (the uv argument is ignored: readSlots read the map at
the same uv). Each read is stored at a constant index (an `if` per entry inside the loop): stored at
`slot_reads[i]`, the A13 draws parts of `standard_maps` wrong, differently every frame (752–1483 wrong pixels; the
M1 draws it right), and sampling with explicit gradients taken outside the loop does not change that.

Flutter GPU behaviours that shape the shaders (3.47.6):

- **A declared but unread uniform block must not exist.** impellerc removes it from the compiled shader while the
  reflection still reports it (`sizeInBytes`, member offsets); binding it moves the following blocks onto the
  wrong buffers. So `OffsetInfo` is a block of its own (depth and distance stages do not include `output.glsl`,
  and `OffsetInfo` exists only in variants with `polygon_offset`), and a variant declares only the samplers and
  blocks its flags read. Every stage reads every block it declares.
- **Binding a texture to a sampler the compiler removed crashes the process** (segmentation fault when the pass
  is encoded, or EXC_BAD_ACCESS in `setFragmentTexture` on Metal; `bindTexture` itself reports success). So each
  `Program` lists the fragment samplers its shader reads (`Program.samplers`: the kind's own, plus those the
  variant's flags add, `samplersOf`) and only those are bound; `test/renderer_test.dart` draws every kind with all
  of its maps, which crashes if a list names a removed sampler. A kind accepts only the flags its shader reads
  (MeshToonMaterial and the physical kind take no `specular_map`). A read multiplied by a constant 0 is folded away
  by Metal's compiler and removes the sampler as well.
- **A draw binds at most 32 textures over both stages.** A 33rd binding takes the place of another without an
  error. No draw comes near it: at most 16 fragment textures (the texture slots and `env_map`) and 4 vertex ones
  (counts under "Skinning").
- **impellerc aborts (SIGABRT in SPIRV-Cross) on `texelFetch`, `textureSize`, `interpolateAtOffset` and
  `dFdxFine`.** The bone, morph and instance-morph textures are read with `textureLod` at texel centres (nearest
  filtering) instead of `texelFetch`. Transmission's bicubic filter computes the level size from the target size
  instead (WebGL's `textureSize`), and the PMREM GGX shader computes the Van der Corput sequence with float
  arithmetic (exact for its 256 samples) instead of upstream's `uint` bit operations. Compiling each bundle entry
  alone with `impellerc --shader-bundle` finds the entry that aborts.
- **A failing shader fails the run.** A shader that does not compile keeps the previous bundle on disk, but the
  run exits 1 with "Failed to build shader bundle" naming the shader, under flutter_tester and in the macOS app; a
  stale bundle shows only when that error is filtered out of the log, so read the run's exit status, not only the
  test lines. Whether the build hook notices edits to included `.glsl` files is not settled: edits to `mesh.glsl`
  rebuilt the bundle (its mtime and size changed), while an older note says included files are not watched;
  touching `ent.shaderbundle.json` forces a rebuild either way.

To add a material kind: write `shaders/<kind>.glsl` (include `output.glsl` or `offset.glsl` and the shared
parts it reads, each optional part under its flag's define), add the kind and its flags to `kinds`
(`lib/src/gpu/variants.dart`), a `Program` with its sampler list in `FlutterGpuRenderer`, a case in `_programOf`,
`_materialUniforms` and `_Surface.of`, and its keys to the test registry (`test/ent_shaders.json`). Extra attributes
(skin, morph, instance, batch) get their own vertex layouts, a program per layout (`Program.skinned`,
`Program.morphed`, `Program.instanced`, `Program.batched` and their combinations).

## What the renderer draws

### Renderer, lights and basic materials

`FlutterGpuRenderer` (three.js names: `setSize`, `setPixelRatio`, `getSize`, `getDrawingBufferSize`,
`setClearColor`, `getClearColor`, `setClearAlpha`, `render(scene, camera)`, `compile`, `compileAsync`, `dispose`,
`info.render`, `info.memory.geometries` and `.textures`, `autoClear`, `sortObjects`, `toneMapping`,
`toneMappingExposure`, `outputColorSpace`, `shadowMap`, `setRenderTarget`, `readRenderTargetPixels`, viewport and
scissor) draws `Mesh` objects with indexed or non-indexed `BufferGeometry`, draw ranges and groups with material
arrays, after `updateMatrixWorld`, `scene.onBeforeRender`, layer tests, frustum culling and `render_list.dart` (a
port of `projectObject` and WebGLRenderList: groupOrder, renderOrder, material id and bounding-sphere depth for
opaque items, back to front for transparent ones; visible lights are collected). Per object:
`scene.overrideMaterial` (unless `allowOverride` is false), `onBeforeRender`/`onAfterRender` of object and
material, transparent `DoubleSide` materials in two passes (back faces, then front).

- **Lights**: AmbientLight, HemisphereLight (sky and ground colors, direction from its position), DirectionalLight
  (from its target, which must be in the scene to move), PointLight (`distance` window, `decay`), SpotLight
  (`angle`, `penumbra`, `distance`, `decay`, target, `map`), LightProbe (spherical harmonics, in world space),
  RectAreaLight (Standard and Physical only, below), with r187's physically based intensities.
- **MeshBasicMaterial**: color, opacity, `vertexColors` (vec3 and vec4), `map` and `alphaMap` with
  offset/repeat/rotation/center, channel `uv` or `uv1`, alphaTest, `aoMap` and `aoMapIntensity`, `lightMap` and
  `lightMapIntensity`, `envMap` (below; `specularMap` scales it), fog (`material.fog`), `toneMapped`,
  `premultipliedAlpha`, `transparent`, every `blending` mode, `side`, `depthTest`, `depthWrite`, `depthFunc`,
  `colorWrite`, `polygonOffset`, `visible`.
- **MeshLambertMaterial**, **MeshPhongMaterial** (`specular`, `shininess`, `specularMap`), **MeshToonMaterial**
  (`gradientMap`, or the default two-tone ramp): color, opacity, `emissive`, `emissiveIntensity`,
  `emissiveMap`, `map`, `alphaMap`, alphaTest, `vertexColors`, `aoMap`, `lightMap`, `normalMap` (tangent space
  with `normalScale`, from geometry tangents or derivatives; object space), `bumpMap` (`bumpScale`),
  `displacementMap` (`displacementScale`, `displacementBias`), `flatShading` (Lambert, Phong), `side`, fog, shadows,
  and the common state above.
- **MeshMatcapMaterial**: `matcap` (or the default gray ramp), color, `map`, `alphaMap`, `vertexColors`,
  `normalMap`, `bumpMap`, `displacementMap`, `flatShading`, fog.
- **MeshNormalMaterial**: view-space normals, `flatShading`, `DoubleSide` flip, `BackSide` (FLIP_SIDED),
  opacity, `normalMap`, `bumpMap`, `displacementMap`. Its stage holds a `discard` under a never-true uniform
  condition (`flat_shaded < 0.0`) at the top of `normal.glsl`: without a possible `discard`, Metal mixes the
  derivatives of neighbouring triangles in a 2 × 2 quad, so flat-shaded facet seams come out as 2-pixel bands of
  an in-between normal (`normal_flat_and_back`: 241 wrong pixels, up to 111/255). Why is a guess (Apple's deferred
  shading after hidden-surface removal), not checked. SwiftShader draws it right either way, so only the Metal run
  guards it. The other stages that use derivatives across triangles include `maps.glsl`, which can `discard`.
- **MeshDepthMaterial**: `depthPacking` Basic (1 − depth, with opacity), RGBA, RGB and RG; `map`, `alphaMap`,
  alphaTest, `displacementMap`. The depth is the clip-space z / w passed from the vertex stage (vHighPrecisionZW):
  with Impeller's [0, 1] range it is the value WebGL computes as 0.5 × z / w + 0.5.
- **MeshDistanceMaterial**: the distance to a point light between its shadow camera's near and far, with `map`,
  `alphaMap`, `displacementMap`. Upstream draws it only into point light shadow maps (WebGLShadowMap sets the
  light in the material's renderer properties; a plain render throws); a plain render here skips it with a
  warning unless `distanceLight` (visible for testing) names the light.
- **ShadowMaterial**: under "Shadows".
- **Textures**: `DataTexture` (RGBA, RGB, RG, Red, Alpha formats; UnsignedByte, HalfFloat, Float types;
  `unpackAlignment`), image textures through `FlutterImage` (below), `flipY`, `premultiplyAlpha`, sRGB,
  `wrapS`/`wrapT` (repeat, clamp, mirror), `magFilter`/`minFilter` with generated or user mipmaps
  (`texture.mipmaps`), `anisotropy`; re-uploaded when `version` changes, dropped on `dispose`. HalfFloatType data
  is uploaded as half floats (`r16g16b16a16Float`), as WebGL keeps it (RGBA16F). Where the creation probe
  `checkFloatFilter` (`filtersFloat`: a 2 × 1 RGBA32F texture of black and white sampled linearly between its texels
  into a 1 × 1 target; 128 on the M1 and under flutter_tester, 255 on the A13) finds float32 unfiltered, linearly
  filtered FloatType data textures and the background cube converted from one are stored as half floats
  (E-FLOATFILTER). The displacement map is sampled in the vertex stage at level 0, as WebGL samples it there.
- **Renderer**: tone mapping (Linear, Reinhard, Cineon, ACESFilmic, AgX, Neutral, Custom as identity),
  `outputColorSpace` sRGB or linear, `Color` backgrounds, `Fog` and `FogExp2`.
- **Images**: `FlutterPlatform.install()` sets `ImageUtils.platform` and `Loader.platform` (exception
  E-PLATFORM): `FlutterImage` decodes data URLs, http(s) and asset keys into straight RGBA, so textures loaded by
  `ObjectLoader` (r187 serializes a CanvasTexture or image as a PNG data URL and a DataTexture as its data array;
  `texture.mipmaps` are not serialized upstream) render after `parseAsync`. PNGs are decoded in Dart
  (`lib/src/png.dart`, on another isolate) to the straight values a browser hands WebGL; other formats go through
  dart:ui, which premultiplies, so a translucent WebP or AVIF texel's color may move by up to 255 / alpha steps and
  a transparent one loses it (E-DECODE). The PNG decoder matches headless Chrome byte for byte on 55 fixtures
  (`node tool/png_fixtures.mjs --chrome`; `test/png_test.dart`): every color type and bit depth, tRNS, the five
  filters, Adam7, split IDAT; Chrome keeps a 16-bit sample's high byte (rounding changes 12 fixtures). It is slower
  than dart:ui under flutter_tester (JIT: 1024² 36 ms against 4.7 ms, 2048² 54–134 ms against 8–16 ms), but off
  the UI isolate.

### Standard and physical materials

**MeshStandardMaterial** and **MeshPhysicalMaterial** (the kind `physical`, `shaders/physical.glsl`):
color, opacity, `roughness`, `metalness` and their maps (channels G and B), emissive, and every map of the basic
kinds (normal, bump, displacement, ao with specular occlusion, light, alpha, map), `vertexColors`, `flatShading`
(also WebGLPrograms' rule: no normal attribute and no normal map), fog and the output path; direct light through
the GGX BRDF with the DFG LUT (`lib/src/gpu/dfg.dart`, r187's 16 × 16 RG16F table) and multiple-scattering
compensation, indirect light through the split-sum model. Physical: `ior`, `specularIntensity` and `specularColor`
(+ maps), `clearcoat`, `clearcoatRoughness`, `clearcoatNormalScale` (+ the three maps), `sheen`, `sheenColor`,
`sheenRoughness` (+ maps), `iridescence`, `iridescenceIOR`, thickness range (+ maps), `anisotropy`,
`anisotropyRotation` (+ map; tangents from geometry or derivatives), `diffuseRoughness` (EON, + map),
`retroreflectivity`, `transmission` (+ map), `thickness` (+ map), `attenuationColor`, `attenuationDistance`,
`dispersion`.

geometryRoughness differentiates `normalize(vNormal)`. The GPU's derivatives are coarse while WebGL's frames match
per-pixel differences, so the shader rebuilds the neighbours from `vNormal / w` and `1 / w`, which are linear in the
window: the neighbour's perspective-correct normal is exact even outside the triangle. Upstream's other derivatives
are of window-linear values (positions, uvs), where coarse and fine agree; texture levels of detail still come from
the GPU's coarse derivatives.

### Environments and backgrounds

- **Environment maps**, resolved as WebGLRenderer.setProgram and WebGLEnvironments do
  (`lib/src/gpu/environments.dart`): `scene.environment` for Standard, Physical, Lambert and Phong, with
  `environmentIntensity` and `environmentRotation`; `material.envMap` with `envMapIntensity` and
  `envMapRotation`. Standard and Physical always read a PMREM (also of their own envMap), Lambert and Phong a
  PMREM of the scene's environment (irradiance only) or their own envMap as a cube map; MeshBasicMaterial its
  envMap as a cube map, reflected in the vertex stage. Cube maps combine with `combine` (Multiply, Mix, Add),
  `reflectivity`, the `specularMap` and `refractionRatio` (CubeRefractionMapping). Sources: CubeTexture (six
  images or DataTexture faces, uploaded as a cube texture, mirrored in x as upstream), equirectangular textures
  (8-bit, HalfFloat, Float), converted to a cube render target of the image's height
  (fromEquirectangularTexture), and a CubeCamera's target (below).
- **PMREM**: PMREMGenerator's r187 algorithm on cube render targets: the source at max(256, size) per face
  (cube maps with flipEnvMap, equirectangular maps with four subsamples) and its mip levels, then the levels of a
  HalfFloatType cube target, the sharp ones by GGX importance sampling (256 samples, the source level matched to
  each sample's solid angle), the three roughest by integrating the 16 × 16 source level; `roughnessToMip` reads
  them back. Cube faces and mip levels are drawn by `GpuPasses` (`lib/src/gpu/passes.dart`): a fragment pass over
  one level of one face of a target, a triangle covering it, uniform blocks and textures by name, one command buffer
  per pass (submitted in order before the frame's); `shaders/face.glsl` gives the direction through a cube texel
  from the face and the window position (the GL cube map table), which is what upstream's 5 × 5 × 5 box under a
  CubeCamera interpolates, without a camera or depth buffer. Render-target mip levels are generated by a pass per
  level, each texel a bilinear sample at the centre of a 2 × 2 block of the level above.
- **Backgrounds** (WebGLBackground): a texture on a full-frame plane (uv transform, `backgroundIntensity`), a cube
  or equirectangular map on a box around the camera (`backgroundRotation`, `backgroundIntensity`), through the
  PMREM with `backgroundBlurriness`; tone mapped unless the map is sRGB; drawn first, in the transmission pass too.

### Transmission

WebGLRenderer.renderTransmissionPass: before the frame, the background and the opaque objects are drawn without
tone mapping, in linear color, into a 4× multisampled HalfFloatType target of `transmissionResolutionScale` × the
drawing buffer (`_TransmissionTarget`: multisampled color and depth, two resolve textures; `_intoTarget`), resolved
and mipmapped; double-sided transmissive objects then add their back faces (Chrome has no
WEBGL_multisampled_render_to_texture, so upstream takes this path), resolved into a second texture. Transmissive
materials sample it with the mipped bicubic filter. The target's mip chain stops at 2 × 2 (E-MIPMAP), which no scene
shows. Its size is the frame's, not the viewport's (upstream: the viewport's); transmission inside a viewport is not
checked.

### RectAreaLight

`RE_Direct_RectArea_Physical` with `LTC_Uv`, `LTC_Evaluate` and the clearcoat term (`physical.glsl`), after the
other direct lights as lights_fragment_begin orders them; position, halfWidth and halfHeight in view space as
WebGLLights.setupView sets them (`lights.dart`), at most 2 per frame (`maxRectAreaLights`, warning once beyond).
The LTC tables are r187's `LTC_HALF_1` and `LTC_HALF_2` (`ltc_data.dart`, generated by `tool/ltc.mjs`, see
docs/upstream.md): 64 × 64 `r16g16b16a16Float`, LinearFilter magnification, NearestFilter minification, clamped,
as WebGLLights picks them without OES_texture_float_linear. The reference Chrome (ANGLE Metal on the M1) uses
`LTC_FLOAT_1/2`, but the A13 samples float32 textures with nearest filtering, so the half tables are used on every
platform (on the iPhone 11 the float tables gave 19 and 45 wrong pixels, the half tables 0). They sit in slots 11
and 12 of the Standard, Physical and Transmission stages, read directly at a constant slot, only while the frame
has a RectAreaLight; a draw then has two slots fewer for maps, and one that runs out warns as above. Lambert, Phong
and Toon ignore rect area lights (r187 defines `RE_Direct_RectArea` only for the physical model); no shadows (r187
has none). Scenes `rect_area_standard` and `rect_area_physical`.

### Shadows

- `renderer.shadowMap` (`ShadowMap`: `enabled`, `type`, `autoUpdate`, `needsUpdate`), WebGLShadowMap.render: per
  shadow-casting light (`castShadow`, in the frame's lights) its shadow camera (switched to the WebGPU coordinate
  system and its projection updated when the map is created, as upstream does then; `prepareShadow` in
  `shadows.dart`), `shadow.updateMatrices`, and the scene's meshes with `castShadow` in the shadow camera's layers
  (or the camera's) and frustum, drawn with a shared MeshDepthMaterial that takes each material's `shadowSide` (or
  the opposite side), `map`, `alphaMap`, `alphaTest` and displacement; `onBeforeShadow`/`onAfterShadow`;
  `shadow.autoUpdate`/`needsUpdate`; `mapSize` (the map is recreated when it changes). Skinned, morphed, instanced
  and batched casters use the depth program's matching variant. Shadow draws count in `info.render`, as upstream
  (reset before the shadow pass).
- The map (`lib/src/gpu/shadows.dart`, exception E-SHADOWMAP) is an `r32Float` color target cleared to 1, with a
  transient depth buffer; MeshDepthMaterial with packing 0 writes `gl_FragCoord.z` (`shaders/depth.glsl`). The
  receivers (Lambert, Phong, Toon, Standard, Physical, ShadowMaterial; MeshBasicMaterial receives nothing upstream
  either) apply shadowmap_vertex and getShadow in `shaders/lights.glsl`: the shadow coordinate from the
  interpolated world position plus the world normal × `normalBias` (the same values as upstream's varying, both
  being linear), `bias`, the frustum test, `intensity`, `receiveShadow`. The rendered map's first row is at the
  top, so v is mirrored.
- Shadow maps and spot light maps share one pool of six samplers (`light_texture_0` … `_5`, `maxLightTextures`;
  each light names its slot), which keeps the widest physical variant at 30 logical textures.
- BasicShadowMap: one nearest texel. PCFShadowMap (the default): five samples on a Vogel disk of `radius` texels,
  rotated per pixel by interleaved gradient noise of gl_FragCoord in GL's orientation (y from the bottom: the
  target's height minus Impeller's), each a LessEqual comparison of the four nearest texels weighted bilinearly,
  what the hardware does for a `sampler2DShadow` with LinearFilter. PCFSoftShadowMap warns and becomes
  PCFShadowMap, as in r187.
- SpotLight: a perspective shadow camera; SpotLightShadow.updateMatrices rebuilds fov (2 × angle × focus), aspect
  and far in the WebGPU system. LightShadow's shadow matrix keeps z for that system, so the stored and compared
  depths are both z / w (both 0.5 × z / w + 0.5 in WebGL): equivalent, rounded differently. `SpotLight.map` is
  projected through the same matrix (`spotLightCoord` in `lights.glsl`, normalBias only for a shadowed light),
  white outside the frustum.
- PointLight: r187 renders a cube render target with a CubeDepthTexture (the casters drawn with
  MeshDistanceMaterial, whose color is not sampled) and compares the perspective depth along the face's axis (the
  major component of the light-to-fragment vector) with `textureCube`. Here the six faces lie side by side in one
  r32Float target (6 × mapSize.x wide, one slot of the light texture pool), drawn with the depth material, one
  viewport and scissor per face, the shadow camera turned by WebGLShadowMap's `_cubeDirections` and `_cubeUps` (its
  far the light's `distance` when set); `cubeFace` in `lights.glsl` picks the face and (s, t) by the GL table, and
  texels are read with t mirrored like the 2D maps. BasicShadowMap reads the nearest texel. PCFShadowMap follows
  r187's `samplerCubeShadow` path (LessEqualCompare, LinearFilter): five Vogel disk samples rotated per pixel by IGN,
  offset by `radius / mapSize.x` in the tangent plane of the light-to-fragment direction, each compared with the
  perspective depth of the point at the fragment's distance in its own direction (`depthA + depthB / max(|d|)`),
  averaged. `pointCompare` compares as the hardware does: the four nearest texels of the face the direction
  selects, weighted bilinearly; a texel past the face's edge is read where the direction of its centre falls
  (`cubeDirection`, then `cubeFace`), on the neighbouring face, as WebGL 2's always seamless cube maps filter (a
  corner texel lands on one of the two neighbours). Metal matches r187 exactly (`point_shadow_pcf`,
  `point_shadow_pcf_radius`); SwiftShader differs by 3–9/255 over the penumbras, so only the Metal run checks them.
- VSMShadowMap (directional and spot lights), WebGLShadowMap's VSM path: the casters and the receivers are drawn
  into the depth map with their own side (not the opposite one), then VSMPass blurs it with `shaders/vsm.frag`
  (ShaderLib vsm; VSM_SAMPLES and HORIZONTAL_PASS are uniforms): vertically from the depth (nearest) into
  `ShadowTarget.pass` (upstream `shadow.mapPass`), horizontally (LinearFilter) into `ShadowTarget.map` (upstream
  `shadow.map`), `blurSamples` samples over ± `radius` texels, each storing the mean and standard deviation. Both
  blur targets are RGBA half floats (Flutter GPU has no RG half-float format; the same precision as upstream's
  RG16F); the receivers read `.rg` of `map` with LinearFilter, one light texture slot per light, and getShadow
  applies Chebyshev's bound with r187's constants (variance ≥ 1e-7, the remap (p − 0.3) / 0.65) and `intensity`.
  Point lights under VSM warn with r187's message and cast none, as upstream. On Metal `shadow_vsm_directional` and
  `shadow_vsm_spot` equal r187 (0 wrong, 0 edge pixels). Under SwiftShader they differ (2 wrong, worst 3/255, and
  44, worst 14/255, all lighter in the penumbra): measured texel by texel against r187's depth texture,
  `shadow.mapPass` and `shadow.map`, SwiftShader's spot depth pass leaves out 3 texels whose centres lie 0.004 to
  0.012 texel inside the floating box's silhouette, and every blurred texel that differs lies within the blur's
  reach of them; the blur passes and the receiver lookup match. Because a measured cap would hide a bug as large as
  a missing vertical blur (46 wrong), only the Metal run guards VSM. The iPhone 11 differs slightly (see "iPhone 11").
- ShadowMaterial: its own program (`shadow.glsl`, ShaderLib.shadow): `color` with alpha
  `opacity × (1 − getShadowMask())`, the product of every shadow-casting directional, spot and point light's shadow
  (1 without `receiveShadow`), then tone mapping, color space, fog and premultiplied alpha without
  opaque_fragment, as upstream. It includes `lights.glsl` without LIGHT_MATERIAL, which leaves out
  `directLights` and the lightMap (no MapInfo block); it reads only the six light texture samplers. Scenes cover
  directional (PCF, fog) and spot (BasicShadowMap) lights, not point lights.
- Not drawn: `customDepthMaterial`, `customDistanceMaterial`, lines, points and sprites as casters (sprites cast
  none upstream either).

### Lines, points and sprites

- `Line`, `LineSegments` and `LineLoop` with `LineBasicMaterial` (color, opacity, `vertexColors`, `map`, fog,
  transparency and the common state), drawn by the basic program with `PrimitiveType.lineStrip` and `line`;
  `info.render.lines` counts as WebGLInfo. Flutter GPU has no line loop: a LineLoop draws a strip through a 32-bit
  index list of its range plus its first vertex (an indexed geometry's indices copied, per draw, into the host
  buffer). Lines are one pixel wide (`linewidth` is ignored: Flutter GPU has no line width, and WebGL on ANGLE
  (Metal) draws width 1 only).
- Rasterization: Flutter GPU covers extra pixels at each step of a slanted line (measured under flutter_tester).
  ANGLE keeps a line's fragment only where the line passes through the pixel's diamond (GL's diamond-exit rule, its
  Bresenham line emulation); `shaders/basic.glsl` applies the same test, with the point on the line rebuilt from
  the interpolated view position and the projection matrix. GL also leaves out the pixel where a line ends inside
  the diamond, which the fragment stage cannot tell without the endpoint, so the scenes keep vertices outside their
  pixel's diamond. Pixel centres where a line passes the diamond's boundary are ties that go either way (within
  about 0.02 in the test's measure).
- The parity test's edge rule hides a missing or extra one-pixel line: its neighbours always hold the colour.
  `line_basic` therefore puts a steep gradient (more than 2/255 per pixel in x and y) behind the loop's closing
  segment, where a missing line pixel finds no neighbour of its colour and counts as wrong, and the line scenes cap
  their edge pixels.
- `LineDashedMaterial`: ShaderLib dashed as the basic program with DASHED defined (`shaders/mesh_dashed.vert`,
  `dashed.frag`, `dashed_offset.frag`): the vertex layout adds a `lineDistance` slot (`dashedSlots`;
  `computeLineDistances` writes it, and a geometry without it reads 0, all dash, as WebGL's disabled attribute),
  the vertex stage passes `scale × lineDistance` (`line_scale` in VertInfo), and the fragment stage discards where
  `mod(vLineDistance, dashSize + gapSize) > dashSize`, after the diamond test. Color, opacity, `vertexColors`, `map`
  and fog as LineBasicMaterial; alphaTest is not applied (linedashed_frag has no alphatest_fragment). Morph targets
  on dashed lines are not drawn morphed (no morph variant of the dashed vertex stage; one warning). Scenes keep
  dash ends off pixel centres: on a corner pixel whose centre lies past the end of one segment and behind the start
  of the next, Flutter GPU (flutter_tester) draws nothing, GL draws it from the starting segment.
- `Points` with `PointsMaterial`: `PrimitiveType.point` and a program of its own, `shaders/points.vert` (slots
  position, uv, color; `gl_PointSize` = size × pixel ratio, times scale / −mvPosition.z with sizeAttenuation and a
  perspective projection, scale = height / 2 as refreshUniformsPoints) and `shaders/points.glsl`
  (map_particle_fragment: map and alphaMap at `(gl_PointCoord.x, 1 − gl_PointCoord.y)` through the map's
  uvTransform, or at the uv attribute (USE_POINTS_UV, WebGLPrograms' pointsUvs), vertex colors, alphaTest, the
  common output with fog). impellerc turns `gl_PointSize` into Metal's `[[point_size]]` and `gl_PointCoord` into
  `[[point_coord]]`, top-left origin as GL's, so no emulation is needed. The alphaMap's own transform is not read,
  as upstream (points read `uvTransform`, the map's, only). `info.render.points` counts as WebGLInfo. A point covers
  the pixel centres within size / 2 of its window position on both paths, so the scenes put an even-sized point
  near a pixel corner and an odd-sized one near a pixel centre (`at()` in `scenes.mjs`).
- `Sprite` with `SpriteMaterial`: a program of its own, `shaders/sprite.vert` (slots position and uv of the shared
  interleaved quad; ShaderLib sprite's vertex stage: the view-space origin plus the quad scaled by the world
  matrix's column lengths, by −mvPosition.z without sizeAttenuation under a perspective projection, shifted by
  `center` and turned by `rotation`; the map's and the alphaMap's own uv transforms) and `shaders/sprite.glsl`
  (map, alphaMap, alphaTest, the common output with fog). RenderList pushes a sprite with its own position's z
  after `Frustum.intersectsSprite`; as upstream's frontFaceCW (meshes only) the winding never flips for a sprite,
  so a negative scale still draws. Sprites count as triangles in `info.render`; `compile` warms them like meshes.
  r187's `toJSON` drops a sprite's `center` (ObjectLoader reads it), so `page.html` adds it to the sprites' JSON.
- Not drawn: lit or other materials on lines (they draw with the GPU's line coverage, without the diamond test),
  `wireframe`. A draw range on a LineLoop is honoured, but toJSON does not keep it, so no reference scene covers it.

### Skinning

- `SkinnedMesh` with `Skeleton` and `Bone`: a skinned mesh draws with `Program.skinned`, the same fragment stage
  over `MeshSkinVertex` and the layout `skinSlots` (the mesh slots plus `skinIndex` and `skinWeight`, vec4 floats;
  WebGLPrograms' `skinning`). The vertex stage runs skinbase_vertex, skinnormal_vertex (normal and tangent through
  bindMatrixInverse × Σ weight × bone × bindMatrix) and skinning_vertex, and displaces along the skinned normal, as
  upstream. Every mesh kind has the variant (Basic, Lambert, Phong, Toon, Standard/Physical, Normal, Matcap, Depth,
  Distance), so skinned meshes also cast skinned shadows; a kind without one (points, sprite programs on a
  SkinnedMesh) draws unskinned with one warning.
- Bone matrices reach the vertex stage in upstream's float `boneTexture`: `Skeleton.computeBoneTexture` on first
  draw (setProgram), RGBA32F, size = ⌈√(bones × 4) / 4⌉ × 4 (at least 4), 4 texels per bone (the matrix columns), so
  a bone's texels share a row; `skeleton.update()` writes `boneMatrices` and marks the texture, which `GpuTextures`
  uploads again on its new version (counted in `info.memory.textures`, as upstream). The vertex stage reads it with
  `textureLod` at texel centres and nearest filtering. No bone maximum. Without a skeleton the unbound texture reads
  (0, 0, 0, 1), as WebGL's unbound boneTexture.
- Textures per draw over both stages: the fragment stage's own (at most 16), plus 1 for the bone texture, 1 for the
  morph texture, 1 for an InstancedMesh.morphTexture, 1 for a displacementMap; at most 20, within the 32 a draw
  binds, so every variant keeps them all (the widest one tested in `renderer_test.dart`). The plain mesh stage
  always binds `displacement_map` (the fallback when there is none); the skinned and morphed stages bind it only
  when there is one.
- `skeleton.update()` runs once per frame for each skeleton drawn (WebGLObjects.update), on the first draw that
  meets it (the shadow pass included); `compile` does not update skeletons. bindMode (attached, detached) is the
  core's `updateMatrixWorld`. Scenes `skin_basic`, `skin_lit`, `skin_bones` (a 120-bone skeleton, 24 × 24 texels)
  and `skin_morph`.

### Morph targets

- A geometry with `morphAttributes` (position, normal, color) draws with `Program.morphed`, the same fragment stage
  over `MeshMorphVertex` (WebGLPrograms' `morphTargets`), on every mesh kind, shadow casters included; points and
  sprites draw unmorphed with one warning. The vertex stage runs morphcolor_vertex, morphnormal_vertex (not with
  flat shading) and morphtarget_vertex before the skinning chunks, with `morphTargetBaseInfluence` 1 for
  `morphTargetsRelative`, else 1 − Σ influences (WebGLMorphtargets.update).
- The targets reach the GPU as upstream's texture (`GpuGeometries.morph`): RGBA float texels, per vertex the
  position, normal and color of a target (stride 1 to 3, color alpha 1 for vec3 colors), `width` = vertices ×
  stride (wrapped into rows past 16384), the targets stacked in rows of one 2D texture in place of a
  DataArrayTexture's layers. Like upstream it is built again only when the number of targets changes. The vertex
  index is `gl_VertexIndex` plus the first vertex of a non-indexed range (the renderer offsets those vertex
  buffers). At most 64 influences, in `MorphInfo` (992 + 144 + about 300 bytes beside `VertInfo` and `SkinInfo`, of
  impellerc's 6208 per stage). A SkinnedMesh with morph targets draws with `MeshSkinMorphVertex`
  (`Program.skinnedMorphed`), the targets applied before the bones as upstream. Scenes `morph_basic`, `morph_lit`,
  `skin_morph`.

### Instancing

- `InstancedMesh`: Flutter GPU draws instanced (`draw` and `drawIndexed` take `instanceCount`; a `VertexBuffer` has
  `stepMode: VertexStepMode.instance`), so instances reach the GPU as WebGL's instanced attributes:
  `instanceMatrix` as four vec4 columns (`instanceMatrix0` to `3`, views at offsets 0, 16, 32, 48 of one
  64-byte-stride stream) and `instanceColor` (vec3), uploaded again on a new attribute version
  (`GpuGeometries.instance`). `Program.instanced` pairs the fragment stage with `MeshInstanceVertex` (INSTANCING)
  and the layout `instanceSlots`; `Program.instancedMorphed` with `MeshInstanceMorphVertex` for morph targets on
  instances. The vertex stage applies the instance matrix before the object's (project_vertex, worldpos_vertex)
  and to normals and tangents as defaultnormal_vertex (divided by the squared column lengths, no per-instance
  normal matrix); the displacement still runs along the untransformed normal, as upstream. USE_INSTANCING_COLOR:
  `v_color.rgb *= instanceColor` before morphcolor_vertex; without instanceColor the slot is bound to white, and
  with instanceColor on a material without vertexColors the `color` slot is white.
- `count` is the draw's instance count; a draw of 0 instances is not counted (WebGLInfo.update), triangles count
  every instance. Frustum culling uses the InstancedMesh's own bounding sphere (core's Frustum.intersectsObject),
  in the main and the shadow passes. Instancing binds no texture, so the texture counts are those of the plain and
  morphed variants. SkinnedMesh and InstancedMesh are separate classes, so skinning and instancing never meet.
  Points and sprite programs have no instancing variant: drawn once, with one warning.
- `InstancedMesh.morphTexture` (USE_INSTANCING_MORPH, setMorphAt): with morph attributes and a morphTexture the
  draw uses `Program.instancedMorphTexture` (`MeshInstanceMorphTextureVertex`), whose morphinstance_vertex reads the
  instance's row of the RedFormat float texture (texel 0 morphTargetBaseInfluence, texel i + 1 influence i) with
  `textureLod` at texel centres, the row `gl_InstanceIndex` (impellerc's Vulkan GLSL; gl_InstanceID upstream).
  `MorphInfo`'s `instance_width` and `instance_height` give the texture's size (an influence past the width reads
  0); the mesh's morphTargetInfluences and `base_influence` are not read there, as upstream. Shadow casters take
  the same variant of the depth and distance programs. The variant binds two vertex textures. toJSON drops the morphTexture, so the scenes keep the influences in
  `userData.morphs` and `parity_test.dart` calls setMorphAt again. Scenes `instanced_basic`, `instanced_lit`,
  `instanced_morph`, `instanced_morph_lit` (`edges.mjs` projects each instance).

### Batching

- `BatchedMesh`: Flutter GPU has no multi-draw and no `gl_DrawID`, so the renderer does what r187's WebGLRenderer
  does without WEBGL_multi_draw: one `drawIndexed` per range of the last `onBeforeRender` (core's
  `_updateDrawParameters`: per-object frustum culling, sorting, hidden instances dropped; `multiDrawStarts`,
  `multiDrawCounts`, `multiDrawCount`, read through public getters), with the range's index view bound and the
  draw id resolved on the CPU. The instance (`indirectTexture`'s entry, getIndirectIndex( gl_DrawID )) picks its
  matrix (16 floats of `matricesTexture`'s data) and color (`colorsTexture`, white without setColorAt) and writes
  them into the vertex block `BatchInfo` before that draw; the textures are not uploaded. `Program.batched` pairs
  the fragment stage with `MeshBatchVertex` (BATCHING), which applies the matrix as INSTANCING applies
  instanceMatrix (normals as defaultnormal_vertex, position and world position before the object's) and
  `v_color = (USE_COLOR ? color : 1) * batchingColor` (vec4, as color_vertex); `BatchInfo`'s `vertex_colors` is
  on with a colors texture. A non-indexed batch draws through a sequential 32-bit index buffer, one per frame.
- Per-draw cost: each range is a draw (one small uniform block emplaced and an index view bound; the pipeline, the
  other blocks, the textures and the vertex buffers are bound once per object). WebGLInfo counts the object as one
  call (multiDrawArraysWEBGL), triangles as the sum of the ranges. Batching binds no texture, so a batched draw has
  the plain program's texture budget (the widest variant's 30 fit).
- Shadows: a batched caster goes through the shadow passes like any mesh, as WebGLShadowMap's renderObject does:
  `onBeforeShadow` (BatchedMesh's own) culls and sorts its ranges against the shadow camera, for a point light once
  per cube face against that face's camera, and `_draw` draws them with the depth material's batching variant, one
  `drawIndexed` per range with its `BatchInfo`. The main pass's `onBeforeRender` then sets the ranges for the camera
  again. Receiving needs nothing of its own.
- Not drawn: morph attributes of a batched geometry (one warning), wireframe. Kinds without the mesh vertex stage
  (points, sprites) have no batching variant: not drawn, with one warning.
- Scenes `batched_basic`, `batched_colors`, `batched_shadow` (PCF, directional) and `batched_shadow_point`
  (BasicShadowMap). In `batched_basic` the instances draw in identity order and `batched_colors`' order is a
  palindrome, so a draw index taken as the instance or a reversed draw order shows in only one of them.

## Render targets

`setRenderTarget(target)` makes `render` draw into a plain 2D `RenderTarget` (`WebGLRenderTarget` is the core
subclass r187 has); `null` returns to the frame, and `getRenderTarget()` reads it back. Internal targets
(transmission, PMREM, shadow maps) are described with their features.

- Storage: `GpuTextures.target` (`lib/src/gpu/textures.dart`) creates a color texture (8-bit RGBA, SRGB8_ALPHA8 for
  an sRGB texture, RGBA16F for HalfFloatType, RGBA32F for FloatType) and a depth buffer on first use and drops
  both on the target's `dispose` event, which `RenderTarget.setSize` also fires (the next render recreates them at
  the new size). They count in `renderer.info.memory.textures`.
- Drawing: the frame's path (`_frame`) with the target's textures, linear output without tone mapping (as
  WebGLPrograms for a render target, the transmission pass's `_intoTarget`), the clear color in the working color
  space (WebGLBackground's `getUnlitUniformColorSpace`), the target's viewport and, with `scissorTest`, its scissor
  (given from the bottom left, as GL; converted to Flutter GPU's top-left origin). `setViewport` on the renderer
  does not apply to a target (upstream it does); targets always use their own. `render` returns the target's
  texture as an image; `renderer.texture` keeps the last frame's.
- Without `autoClear` the pass loads the target's color and depth (`LoadAction.load`). On Metal that keeps the
  earlier render, with and without `samples` (the LoadAction check in `parity_metal_test.dart`). Under
  flutter_tester (SwiftShader) Flutter GPU 3.47.6 clears an attachment whose load action is `load`, with its clear
  value, or to transparent black without one (flutter/flutter#196199), so a render without `autoClear` into a target
  loses the earlier one there, and the renderer test for it is skipped. `FlutterGpuRenderer.create()` probes it
  (`loadKeepsColor`, `gpu/check.dart`: a 1 × 1 texture cleared red in one command buffer, then an empty pass that
  loads it, clear value blue, in a second, read back; red means kept): true on Metal, false under flutter_tester. A
  renderer test checks that the probe agrees with a real render without autoClear on whichever backend runs it.
  `TuningPass` reads `loadKeepsColor` (EffectComposer, below).
- Orientation: Flutter GPU stores NDC +y in row 0, WebGL in the last row. A render target texture is sampled with
  its uv transform flipped in t (`t' = 1 - t`, in `_transform`), which matches Chrome texel for texel (texel
  grids are symmetric, so filtering is unchanged). `readRenderTargetPixels` reads rows from the bottom, as
  glReadPixels, and is asynchronous (E-READPIXELS).
- `samples` above 0: 4× MSAA ("Render targets with samples"); cube, 3D and array targets ignore it.
- `depthTexture` (2D targets): what the target's `DepthTexture` reads is a 32-bit float color texture written after
  each render into the target. Where the creation probe `checkDepthRead` (`readsDepth`: a 1 × 1 depth buffer cleared
  to 0.25, stored, read through `MipFragment`'s plain `sampler2D`) succeeds, the target's depth buffer
  (`d32FloatS8UInt`) is created shader-readable and `_copyDepth` copies its red channel texel for texel with
  `MipFragment` (nearest, one fullscreen draw). Metal on the M1 and the iPhone 11 reads the depth as (d, d, d, 1), a
  cleared 0.25 as 64/255 and a written `gl_FragDepth` of 1 as 255, with no error or crash (no `depth2d` needed);
  flutter_tester reads black (SwiftShader's Vulkan rejects a depth-stencil texture bound with both aspects).
  Elsewhere (`_depthTexture`, the replay): the meshes that wrote depth are drawn again in the same order with a
  MeshDepthMaterial of their depthFunc and side (packing 0, the fragment's z / w, which equals WebGL's window depth
  since the cameras project to Impeller's [0, 1] range) against a depth buffer of its own, both cleared to 1 when the
  pass cleared the target's depth. The texture is sampled as (depth, 0, 0, 1), as Chrome r187 shows a
  DEPTH_COMPONENT texture (red only), with its rows flipped like the target's texture (`topDown`). Every r187 type
  and format is 32-bit float here (E-DEPTHTEXTURE). Lines, points and sprites are not in it; `samples` with a
  depthTexture draws without MSAA (one warning). Scenes `depth_texture_view` (UnsignedIntType, DepthFormat) and
  `depth_texture_float` (FloatType, DepthStencilFormat) draw the depth texel for pixel: at 64 × 64 magnified twice,
  two silhouette texels are covered differently (a rasterization tie, not depth). A renderer test checks the depths
  read (sRGB 187 and 203 for 0.495 and 0.596), the clear, color reads, draw calls and dispose; the Metal test checks
  that `readsDepth` is true. Cost: "Cost of the workarounds".
- Not supported, one warning each: `count > 1` (MRT), stencil, `depthBuffer: false` (a depth buffer is attached
  anyway), `generateMipmaps`, 3D and array targets, a mip level in `setRenderTarget`. A 2D render target texture is
  only sampled as a 2D map, not as an environment; cube targets are under "CubeCamera".
- Scenes `rt_basic` (Basic and Lambert shapes in a 64 × 64 target with linear filtering, shown texel for pixel) and
  `rt_read` (the target's clear color, a far quad drawn after a near one and kept behind it by the target's depth
  buffer, nearest filtering magnified twice). The JSON carries the target pass (`target`: scene, camera, size, clear,
  options; scenes.mjs and page.html), the parity test draws it first and sets the map of materials with
  `userData.renderTarget`. A renderer test reads pixels back.

## Frame viewport

The frame (no render target) as r187 draws the default framebuffer:

- `autoClear: false` across renders (E-FRAME): every render gets a fresh color texture (a texture pool would save
  the allocation). A render that keeps the color draws the previous render's texture into it first
  (`FrameFragment`, nearest, one triangle, no depth test or write; with antialias into the samples, which are then
  resolved as usual), or starts from transparent black without one of the same size; while autoClear is off the
  frame's depth is a stored `devicePrivate` texture (4× with antialias), loaded unless `clear()`/`clearDepth()` came
  first. With autoClear on: transient depth, `dontCare` store. The copy is needed on Metal too, since the frame's
  own texture is new each render; on the M1 and the iPhone 11 the frame keeps the first render, with and without
  antialias (the LoadAction check).
- `setViewport`, `setScissor`, `setScissorTest` and their getters and `getCurrentViewport` as r187 (logical pixels
  times the pixel ratio, rounded in the setters, floored by `setRenderTarget(null)`; `setSize`/`setPixelRatio`
  reset the viewport, not the scissor), flipped to the top-left origin and set on the pass after the copy.
- gl.clear is scissored, the load action is not: a clear with the scissor test on (and a scissor smaller than the
  frame) loads the color as a kept frame does, `FrameFragment` writes the clear value inside the scissor rectangle
  in the same triangle as the copy, and when the depth is loaded (autoClear off) `ClearFragment` writes depth 1
  inside the scissor with the color kept by blending (ZERO, ONE). A full-frame viewport without the scissor test
  sets nothing, so the common path is unchanged.
- Under flutter_tester a second `GpuPasses.draw` in one pass reads the first draw's uniform block (the copy's)
  instead of its own, and a fragment stage without a sampler crashes the shell (segfault); causes unknown (a guess:
  binding state that Flutter GPU 3.47.6 keeps between draws); neither was tried on Metal. Hence one uniform block
  for copy and clear and a dummy sampler in `ClearFragment`, which outputs its sample (the blend discards it): a
  read multiplied by 0 is folded away by Metal's compiler, which removes the sampler, and binding a texture to it
  ends the macOS app (EXC_BAD_ACCESS in `setFragmentTexture`).
- Scenes `frame_views` and `frame_inset`: 0 wrong under flutter_tester and on Metal. Not checked: transmission
  inside a viewport (its target is the frame's size, upstream the viewport's), `setViewport` while a render target
  is set (upstream applies it to the target; here targets always use their own), the iPhone.

## CubeCamera

`CubeCamera.update(renderer, scene)` draws the six faces into a `WebGLCubeRenderTarget` (core, r187's constructor;
E-CUBECAMERA): `setRenderTarget(target, face)` makes `render` draw into that slice of a cube color texture
(`GpuTextures.target`, one 2D depth buffer for all faces).

- Orientation: the renderer reports WebGPUCoordinateSystem, so the cube camera turns its cameras as for WebGPU and
  the faces hold a CubeTexture's layout (row 0 at NDC +y, as Flutter GPU stores it). The target's texture is then
  sampled with the x mirror of a CubeTexture (`GpuEnvironment.renderTarget` false, the PMREM's `flip` -1), as
  WebGPURenderer's CubeTextureNode does; WebGL's own orientation without the mirror gives the same texels.
- As an envMap: MeshBasicMaterial samples it directly; MeshStandardMaterial through a PMREM rebuilt when
  `pmremVersion` changes (`needsPMREMUpdate`, which `update` sets). Before the first update it reads black.
- Mipmaps: with `generateMipmaps` and a mipmap minFilter the texture gets `fullMipCount` levels, generated after
  the last face (`mipmapsAutoUpdate`, which `update` turns off for the first five) with the cube mip pass; mip
  levels other than 0 in `setRenderTarget` are not drawn (one warning). The scenes do not use mipmaps.
- Uniforms: each face is a render of its own, with its own host memory ("Host buffers"); a shared Flutter GPU
  `HostBuffer` would draw earlier faces with later faces' cameras.
- Scenes `cube_camera_basic` (a 32² target at a Basic sphere in a room whose corners have distinct vertex colors;
  the sphere hidden during update, as the application does upstream) and `cube_camera_standard` (metalness 1,
  roughness 0.4, through the PMREM, on a front-facing quad whose normals turn toward +x). The JSON carries the pass
  (`cube`: size, options, near, far, position; scenes.mjs, page.html). A reflecting sphere keeps 1–6 rim pixels
  3–8/255 off, and sharp-edged quads in the room differ by up to 9/255 at their reflected edges (texels about a
  pixel), so neither is in the scenes (measured under flutter_tester).

## Host buffers

Flutter GPU's `HostBuffer` (flutter_gpu `buffer.dart`, `_kFrameCount = 4`; Impeller's `kHostBufferArenaSize = 4u`
in `impeller/core/host_buffer.h`) is a bump allocator over host-visible 1 MB blocks in 4 frames: `reset()` moves to
the next frame and rewinds it, with no regard for the GPU. Its blocks are read when the command buffer executes, so
a fifth reset while an earlier frame is in flight rewrites that frame's uniforms: render calls in a row without
awaiting (a CubeCamera's faces, render targets, `compile`) draw with the uniforms of a later render sharing the
frame (16 unawaited renders into 16 targets each showed the color of the last). It also appends a block on every
overflow and never reuses it.

The renderer and `GpuPasses` use `HostBuffers` (`lib/src/gpu/host_buffers.dart`) instead: a bump allocator over
pooled 64 KB host-visible blocks (larger data gets a buffer of its own), one frame per `render` (per batch of
passes; `HostBuffers.frame`, bumped by `next()`). Every command buffer that reads a frame is submitted through it
and counted; the frame's blocks return to the pool when the frame has ended and its last command buffer has
completed (`submit(completionCallback:)`). The pool keeps at most 64 free blocks (4 MB), the rest are released.
Measured: 50 awaited renders reuse one block; a burst of 100 unawaited renders creates 100 blocks, the pool keeps
64 after it. Checked by the renderer test "renders in a row" (two rounds of 16 unawaited 256² targets, each 64
full-target quads, so the GPU is still drawing one render when the next writes, with warm pipelines too) and the
`cube_camera` scenes. Uniform blocks reuse their upload within a frame ("CPU cost per frame").

## Limits

- Lights: at most 4 directional, 8 point, 4 spot, 2 hemisphere and 2 rect area lights, 4 shadowed directional
  lights, 6 light textures (shadow maps and spot maps) per frame; more are dropped with one warning.
- Morph targets: at most 64 influences.
- Shader variants: a draw whose variant the app has not registered throws a `StateError` naming its key (in
  recording mode it is skipped with a warning).
- At most 15 distinct 2D textures per physical draw (texture slots; maps with the same texture share one); a draw that
  needs more throws a `StateError`.
- Not drawn, with a one-time warning: `wireframe`, VSM on point lights (as upstream), texture channels above 1, video,
  compressed and 3D textures. ent has no `ShaderMaterial` or `RawShaderMaterial` (E-SHADERMATERIAL).
- A PMREM supplied by the application (`texture.isPMREMTexture`, PMREMGenerator's own output) is not read:
  PMREMGenerator is not part of the core port; scene and material maps are prefiltered by the renderer.
- Not ported: dithering, alphaHash, alphaToCoverage, clipping planes, stencil, logarithmic depth, light probe
  grids (`NUM_LIGHT_PROBE_GRIDS`), packed normal maps, multiple render targets.
- FloatType render targets sampled linearly stay unfiltered on a GPU without float filtering (the A13): only data
  textures are converted to half floats (E-FLOATFILTER). Unaffected: shadow maps and the depth texture's r32Float
  (nearest on purpose), the morph texture (nearest), PMREM and VSM blur targets (half).
- `flutter_gpu` objects have no explicit `dispose`; buffers and textures are released when unreachable.

## Verification and tolerances

- `packages/ent_flutter/test/renderer_test.dart`: clear color, color encoding and image orientation, culling per side,
  depth order in both draw orders, `depthTest: false`, view-space normals, program switching, groups, draw range,
  drawing-buffer size, disposal, attribute re-upload, user mipmaps by level of detail including the missing 1×1 level,
  the light maximums, every material kind drawn with all of its maps (the sampler lists; every physical map and layer,
  transmission included), MeshDistanceMaterial skipped without a light, the orientation of an uploaded cube texture, a
  uniform environment staying uniform through the PMREM at blurriness 0.6, render targets and their readback, the
  probes, `compile`, host buffers. `test/platform_test.dart`: the image adapter. Tolerance 2/255 per channel.
- Timeouts: the file's default is 2 minutes; the three slowest tests (all maps, skinned or morphed displacementMap,
  `compile`/`compileAsync`) set 5, 6 and 10 minutes and use a renderer of their own (`own()`): a test past its
  timeout keeps running, and on a shared renderer it would change what the next test draws. Under flutter_tester
  the first draw of a new pipeline state takes seconds ("Pipeline compile cost").
- `packages/ent_flutter/test/golden_test.dart` compares a 128×128 frame with
  `fixtures/rendering/flutter_gpu_scene.png` (metadata in `flutter_gpu_scene.json`): 2/255 per channel, 0
  differing pixels on the generating machine.
- Parity: `test/parity.dart` holds the scenes and the comparison (`declare`, given a file reader);
  `test/parity_test.dart` runs it under flutter_tester and `examples/worm/integration_test/parity_metal_test.dart`
  in the example app on Metal ("Parity on Metal"). It compares every scene in `fixtures/rendering/reference/` (162
  scene files; animated scenes compare several frames each) with the frame r187's `WebGLRenderer` drew in headless
  Chrome (`tool/reference/render/`; `meta.json`: Chrome 157.0.8103.39, ANGLE on Metal, Apple M1, macOS 26.5.2).
  Chrome updates itself; a redraw on a new version is compared with the existing set before `meta.json` changes
  (the JSONs differ only by their random uuids). The reference PNG holds the drawing buffer's raw bytes
  (`readPixels`): `toDataURL` un-premultiplies a premultiplied-alpha canvas and loses colors where alpha is below 1.
  The test decodes the reference PNG itself (dart:ui premultiplies on decoding and loses the colors of alpha-0
  pixels, as in `depth_packing`).
- Rule: 2/255 per channel; a pixel off by more is accepted only as an edge pixel (our color appears within one
  pixel in the reference), at most 0.5% of the frame, and at most the scene's `edges` where `scenes.mjs` sets it
  (saved in the JSON): the edge rule hides a missing or extra one-pixel feature, whose neighbours hold its color.
  Recorded allowances in `parity.dart`: `ties` (exact ties in r187's own arithmetic: `composer_fxaa` under
  flutter_tester, 3 wrong, worst 42), `ios` (iPhone 11, replacing `ties`), `mipmaps` (E-MIPFILTER), `antialiased`
  (per-scene tolerance, edge cap and blended count). `swiftShader` lists the scenes only `parity_test.dart` skips
  (they match on Metal); `skipped` those both skip (`khronos_box_textured`).
- Differences between the two GPU paths that the scenes are built around. They were measured under flutter_tester
  (SwiftShader) against Chrome; on Metal the frames match exactly, so many are SwiftShader's, but the scenes keep
  them because flutter_tester still runs every scene not in `swiftShader`:
  - Edges through pixel centres rasterize differently (ANGLE draws upside down; ties and sub-pixel snapping go
    the other way). With flat colors they count as edge pixels; under a color gradient they do not find their
    color nearby, so scene coordinates keep edges off pixel centres and gradients gentle.
  - Sample positions differ by about 0.02 pixel (an 8×8 black and white texture minified to 9 pixels differed
    by up to 6/255; magnified, within 1/255). Where a texel covers about a pixel and neighbors differ strongly,
    values differ by up to 10/255, so trilinear and receding-plane scenes use low-contrast textures.
  - Levels of detail match exactly at constant derivatives (flat-color mip levels at nine sizes, identical),
    but on a receding plane the level differs by up to about 0.05: the GPU takes coarse derivatives per 2×2
    quad, and ANGLE's upside-down quads take them from the other row.
  - Next to a zero channel, linear filtering differences in the last bits of the weights grow past 2/255 under
    the sRGB encoding (slope 12.92 near zero), so linearly filtered test textures have no zero channels.
  - Silhouettes of lit curved objects: pixel coverage flips between the paths for pixel centres up to 0.025 pixel
    from a silhouette edge, in no consistent direction, and a lit rim changes by far more than 2/255 per pixel, so
    such a pixel fails. Rim pixels covered on both sides still differ by 3 to 13/255 where the rim is dark or
    steep. The scenes place objects so no silhouette passes within 0.02 to 0.03 pixel of a pixel centre
    (`edges.mjs`), use 16 segments where rims stay steep, add ambient light against near-black rims, and test
    BackSide normal maps on a quad. Flat-shaded slivers at silhouettes, toon steps and steep highlights behave the
    same way.
  - Packed depths: the paths compute the depth differently (z / w here, 0.5 × z / w + 0.5 there); the last
    bits show in the packed bytes unless the depth is exact, so `depth_packing` uses binary depths.
  - geometryRoughness is per triangle, so on a curved mesh every triangle edge is a shading discontinuity, steep
    in the slivers next to a silhouette. The sphere grids keep pixel centres 0.025 pixel off silhouettes and off
    interior edges near them (`edges.mjs --threshold 0.025 --rim 0.35`, 12 segments, radius 0.44) and start at
    roughness 0.45; `physical_clearcoat` uses a clearcoat roughness of 0.35.
  - Steep highlights at low roughness (not reference scenes, not run on Metal): the grid at roughness 0.15, 0.25 and
    0.35 (directional and point light) has 11 wrong pixels, up to 7/255; a clearcoat of roughness 0.2 over normal
    maps on front-facing quads has 1, off by 3/255. The cause is not the derivatives: with geometryRoughness set to
    0 on both paths (r187's chunk patched in the page) the rim pixels go away, but 10 highlight pixels stay, up to
    12/255. Writing `fract(normal * 64)` on both paths shows the interpolated normal itself differs, by 5e-4
    (median of the wrong pixels) up to about 1e-3, smoothly within each triangle and changing from triangle to
    triangle; under a highlight of roughness 0.15 that is 2 to 4/255 per 1e-3. No constant sample shift (±0.01,
    0.02 pixel in x or y) nor one growing across the frame reduces it, nor rounding the normal to half precision
    in either stage, nor drawing upside down (y negated, winding swapped). It looks like the two paths' triangle
    setup (interpolation weights), which the shader cannot reach (a guess). Plain coarse `dFdx` on the normal gives
    35 wrong pixels (up to 24/255) against the rebuild's 11. On a front-facing quad w is constant, so coarse and
    fine derivatives of positions and uvs agree and the normal-map tangent frame is not the cause either. Scenes
    keep roughness at 0.45 and up.
  - Minified cube maps (a reflecting sphere with 16 × 16 faces): levels of detail from coarse derivatives and the
    canvas faces' seams give up to 9/255 in 66 pixels; a smooth map without seams (`smoothCube()`) and without
    mipmaps passes, and `background_cube` uses low-contrast discs.
  - The transmission target is drawn 4× multisampled on both paths, with the same sample positions; samples
    within about 0.03 pixel of an edge are covered differently, like pixel centres in the frame (stripes behind a
    transmissive quad: 526 wrong pixels, up to 20/255, moving with the stripes' sub-pixel position). The scenes
    keep such edges between sample positions.
  - Shadow maps are rasterized too, so their edges count like screen edges: with rotated boxes and an oblique
    light, PCF penumbras differ by 3 to 6/255 in a few pixels (a map texel covered on one side only), lit faces
    next to a box's silhouette in the map by 3/255 (equal depths of the lit and the stored faces), and the lit faces
    of a DoubleSide caster, which stores them, by up to 40/255. The shadow scenes therefore light in the xy plane
    with axis-aligned boxes, so silhouettes are rectangles in the map with edges off texel centres (texel
    coordinates in `scenes.mjs`), and avoid casters that store their lit faces without a bias. Spot scenes keep map
    rows off texel centres and use BasicShadowMap where slanted perspective edges cross texel centres under PCF. PCF
    shadows of skinned bars miss by up to 26/255 at slanted shadow edges, so the skinned shadow scenes use
    BasicShadowMap. Toon boxes differ at face edges (the default ramp's step), so `shadow_bias` uses Toon for the
    flat floor only.
- Not covered by any scene: a PMREM GGX lod bias of 0 (the scenes' environments are smooth; finer source levels
  change the GGX average by at most 2/255), a point-light scene with a non-zero bias, ShadowMaterial under a point
  light, `customDistanceMaterial`, a multi-frame scene (only `UniformBlock.check` guards the lifetime of reused
  uniform views).

## Parity on Metal

`examples/worm/integration_test/parity_metal_test.dart` runs `parity.dart` in the example app (debug, Metal),
with the `swiftShader` scenes included. The references reach the app as assets:
`examples/worm/integration_test/fixtures` is a symlink to the repository's `fixtures/`, and the example's pubspec
lists `fixtures/rendering/reference/`, `fixtures/gltf/`, each used Khronos model's variant folder (a Flutter asset
folder is not recursive) and `fixtures/hdr/` under it (7.2 MB of reference frames and 6.8 MB of glTF fixtures in
every build of the example; entitlements unchanged). A failing frame is saved to `parity_failures` in the app's
temporary directory. `flutter test integration_test/parity_metal_test.dart -d macos --enable-flutter-gpu` runs the
144 scenes it had when timed in about 11 s (flutter_tester: about 5 min).

On the M1 every frame equals r187's Chrome frame exactly (0 wrong, 0 edge pixels) except these (wrong / edge
pixels; worst channel difference in brackets):

| Frame | Metal (M1) | SwiftShader |
|---|---|---|
| `line_fog` | 0 / 1 | 0 / 5 |
| `aa_basic`: antialiased edge pixels / blended | 457 (119) / 433 | 462 (119) / 431 |
| `aa_standard` | 126 (47) / 301 | 129 (47) / 298 |
| `rt_samples` | 457 (175) / 433 | 486 (175) / 431 |
| `composer_samples` | 457 (188) / 433 | 462 (188) / 431 |
| `khronos_normal_tangent_mirror` (`mipmaps`) | 202 (18) | 330 (69), in `swiftShader` |
| `khronos_clearcoat` (`mipmaps`) | 19 (14) | 234 (65), in `swiftShader` |
| `khronos_alpha_blend_mode` (`mipmaps`) | 8 (89) | 96 (179), in `swiftShader` |
| `khronos_transmission` (`mipmaps`) | 3 (119) | 569 (185), in `swiftShader` |
| `khronos_box_textured` (skipped) | 2 (3) | 205 (146) |

Under SwiftShader the other frames have 0 wrong pixels and 0 to 38 edge pixels (`normal_cube_over_triangle` 38,
`normal_flat_and_back` 13, `rect_area_standard` 12 at its cap); `composer_fxaa` has 3 wrong (worst 42) and 4 edge
pixels (`ties`); the scenes in `swiftShader` differ as listed there. None of these appear on Metal. The antialiased
frames' edge counts stay within their caps (145 to 535).

Only the Metal run guards: VSM, point-light PCF, the `discard` in `normal.glsl`, and the `swiftShader` scenes.

The LoadAction check in the same test draws a red top half, then without autoClear a green bottom half: into a
render target, without and with 4 samples, and into the frame, with and without antialias. On the M1 every case
keeps the first render (2048 red, 2048 green pixels).

### Cost of the workarounds

Measured on the M1 with temporary profile-build tests (`flutter drive --profile -d macos`, removed): 300 frames at
1280 × 720 after 30 warm-up frames, the CPU time of the calls and the wall time until a readback after the last one,
plus 50 frames each awaited by a readback. The wall time equalled the CPU time in every case, so the GPU kept up
and its own time is not separated (at most the CPU's, an inference). Runs of the same build vary by about 10%.

| Case | CPU ms / frame (runs) | Awaited ms / frame |
|---|---|---|
| RenderPass, OutputPass (12 quads) | 0.31, 0.34, 0.32 | 0.31–0.34 |
| with TuningPass, copying the read buffer (flutter_tester's path) | 1.08, 1.02 | 1.17 |
| with TuningPass, r187's blend (Metal's path) | 1.00, 0.99 | 1.21–1.23 |

So the bloom copy costs less than the noise; on Metal the pass skips it, which saves its target
(`TuningPass.base`, 7 MiB of HalfFloat at this size) and keeps r187's call order.

Depth textures, 200 Lambert boxes into a target, three runs each in one build: no depth texture 3.52–3.63 ms CPU
(awaited 5.18–5.33), the depth copy (Metal) 3.52–3.63 (5.33–5.48), the replay (flutter_tester's path) 5.25–5.77
(6.71–6.80). The copy costs about nothing; the replay repeats every depth-writing draw, about 1.7–2.1 ms per such
render here. The iPhone was not measured.

### iPhone 11

`flutter test integration_test/parity_metal_test.dart -d <iPhone 11> --enable-flutter-gpu` (debug build, wired;
iPhone12,1, A13, iOS 16.3.1): 176 frames and the LoadAction check run in about 38 s after a 3 min 33 s Xcode
build (2026-11-15), no timeout change needed. Every frame equals the M1's, including the antialiased ones,
`normal_flat_and_back`, both point-PCF scenes, `rect_area_standard`, the composer scenes and both depth texture
scenes, except three, recorded as `ios` allowances in `parity.dart` (they replace `ties` when `Platform.isIOS`):

| Frame | iPhone 11 (wrong (worst) / edge) |
|---|---|
| `composer_fxaa` | 22 (8) / 0 |
| `shadow_vsm_directional` | 3 (5) / 1 |
| `shadow_vsm_spot` | 27 (6) / 32 |

- `composer_fxaa`: all 22 pixels lie on one slanted edge from (86, 25) to (5, 55), one pixel per stair step (every
  2 to 5 pixels), and all are the same color, (207, 197, 115) where r187 has (215, 205, 120): FXAA blends those
  pixels a little more. A guess, not checked: the same kind of tie as SwiftShader's (the end search stopping where
  `abs(delta)` equals `gradient * 0.25`), decided the other way by the A13's arithmetic or bilinear weights.
  `composer_output` and `composer_effect`, which share its passes except FXAA, are 0 / 0.
- VSM: every wrong pixel is in the penumbra and lighter than Chrome by 2 to 6/255 (directional (34, 54), (36, 55),
  (38, 56), at the contact shadow; spot along the shadows' borders), the same pattern as SwiftShader, smaller. Not
  the float32-nearest limit: the blur reads the r32Float depth with nearest filtering anyway, and the half-float
  blur targets filter linearly on the A13. A guess, not checked: the depth pass rasterizes silhouette texel centres
  differently on the A13 (as SwiftShader's does), or the A13's half-float filtering rounds the blurred moments
  differently.
- `hdr_environment_aces` (the FloatType texture) is 0 / 0 with the float-filter probe (E-FLOATFILTER); without it
  the A13's nearest filtering gives 2519 wrong pixels (worst 18), exactly what the M1 gives with that texture
  forced to nearest.
- LoadAction: render targets with and without samples keep the first render.
- The failure frames stay in the app's temporary directory on the phone: `devicectl` does not reach iOS 16.3.1
  (CoreDevice: "does not support acquiring a usage assertion"); a temporary print in `compare` lists pixels.

- Khronos models (2026-11-15, 162 tests in 36 s): the same five frames as the M1 differ from r187, within their
  allowances and within 1 pixel of the M1's counts (`khronos_clearcoat` 18 (13), `khronos_normal_tangent_mirror`
  201 (18), `khronos_transmission` 2 (119); `khronos_alpha_blend_mode` and `khronos_box_textured` equal).
- Shader variants: no Metal function of the example's bundle binds more than 16 textures (counted from the
  `[[texture(n)]]` arguments of each entry's MSL; the widest physical variants bind exactly 16), though the
  reflection lists up to 45 (the named map samplers impellerc dropped; the renderer binds only `Program.samplers`).
  No parity scene draws the widest variant, so that one is checked by its MSL only, not drawn on the A13.
- Bundle size (the example's iOS build, metal_ios only): 11.4 MB for 93 variants and 36 fixed shaders, 1.4 MB
  gzipped. A lit variant is 135–200 KB of MSL (physical 154 KB plain, 203 KB with every flag; Lambert, Phong, Toon
  about 140 KB), most of it the inlined light and shadow loops, so a map flag adds 1–3 KB; unlit kinds are 2–14 KB.

Not run on the iPhone: release or profile builds of the parity suite, the steep-highlight scenes.

## EntView

`EntView` (`lib/src/ent_view.dart`) renders its scene through its camera on every tick of a `Ticker` and shows
the returned `ui.Image`. Checked by `test/ent_view_test.dart` (widget tests with a real renderer).

- Ownership: the app creates and disposes the renderer. The view never disposes it, so one renderer can be shared
  or outlive the view. Disposing the view stops its ticker and disposes its last image; a render happens only in a
  tick, so none follows. A new `renderer` or `camera` in `didUpdateWidget` is sized on the next layout; a new
  `scene` is drawn from the next tick.
- Resize: on a layout change, and only then, it calls `setPixelRatio` and `setSize` with the logical size, and for
  a `PerspectiveCamera` sets `aspect` and calls `updateProjectionMatrix` once, as r187's examples do in their
  resize handler. An `OrthographicCamera` (or any other camera) is left to the app, as in the examples, where
  its frustum is the app's choice. An empty or unbounded layout renders nothing. A rotation is a resize.
- Device pixel ratio: read with `MediaQuery.devicePixelRatioOf`, so a change (a window moved to another screen)
  re-sizes. The frame is `floor(size * ratio)` physical pixels, drawn by `RawImage` at `scale: ratio`,
  `BoxFit.none` from the top left and `FilterQuality.none`: one image pixel per physical pixel, never resampled
  (with `BoxFit.fill` a 67-pixel box at ratio 1.5 stretches 100 pixels over 100.5 and 1806 of 6000 differ).
- Pausing: no render while the ticker is muted by `TickerMode` (a route covered by an opaque one, an inactive tab
  that uses `TickerMode`) or while the app is hidden or paused (`SchedulerBinding.framesEnabled`; an app gets no
  frames then anyway, the check makes it explicit and testable). It resumes on the next frame.
- Elapsed time: `onFrame` gets the `Ticker`'s elapsed time, which, as in Flutter, keeps running while muted or in
  the background; an animation driven by it jumps ahead on resume, as one driven by r187's `Clock` does after a
  hidden browser tab. An app that wants to freeze can accumulate its own deltas.
- Frames: each tick creates one image; setting the next disposes it (`RawImage` holds a clone, which it disposes).
  Over 300 frames the open image handles stay at 2 and `info.memory` stays the same. `render` is synchronous
  in the tick, so a frame slower than a tick delays the next one and renders never overlap; the GPU work of
  successive frames goes through the host buffer pool ("Host buffers").

## Picking

`EntView` takes `onPointerDown`, `onPointerMove`, `onPointerUp` and `onPointerHover`, each called with the
Flutter `PointerEvent` and its normalized device coordinates as a new `Vector2`, ready for
`raycaster.setFromCamera(ndc, camera)` and `intersectObjects(scene.children)`, the r187 idiom. A `Listener`
around the view delivers them; hover comes only from a mouse (or stylus) without a button, as on desktop.

- NDC: `EntView.ndc(local, size)` is r187's `( x / width ) * 2 - 1, - ( y / height ) * 2 + 1` on the event's
  local position and the view's layout size, both in logical pixels as r187 uses CSS pixels, so the device pixel
  ratio never enters it. It is public for apps with their own gesture detectors. No callback runs while the
  layout is empty.
- Why callbacks and not a gesture recognizer: a `Listener` gets raw pointer events without entering the gesture
  arena, so the view does not compete with an app's own detectors (such as `OrbitControlsListener`); taps, drags
  and hover thresholds stay the app's choice, as with r187's `pointerdown`/`pointermove`/`pointerup` listeners.
- Checked by `test/picking_test.dart` (widget tests with a real renderer): a tap at the projected screen position
  of a known point passes that point's NDC (1e-9) and picks the box before the sphere behind it, with the distance
  of a direct core `Raycaster` cast (1e-9), the box's front face and its uv (0.7, 0.7); empty space picks nothing;
  a mouse hover passes its NDC. The same pick holds after the ratio doubles at the same logical size and after a
  resize to a square at ratio 1.5 (new aspect, new screen position). An `InstancedMesh` gives `instanceId`, a
  `BatchedMesh` `batchId` (r187 raycasts each instance's geometry). A `SkinnedMesh` is picked in the pose of the
  last frame: r187's `getVertexPosition` applies the bones' current `matrixWorld`, which the render updates, so
  after a mixer moves the upper bone 1.5 to the right the hit is there and the bind-pose place is empty.
- r187 keeps a skinned mesh's `boundingSphere` once computed (its first raycast or frustum test); a pose that
  moves far beyond it misses the sphere test until the app calls `computeBoundingSphere()`, as in r187.

## OrbitControls

`OrbitControlsListener` (ent_flutter) wraps a `EntView` and feeds every pointer to an `OrbitControls`
or `MapControls` from `package:ent` as the browser feeds r187's listeners, so r187's own pointer
bookkeeping decides the gesture; the core is checked against r187 in Node (`orbit_controls.mjs`: 17 scenarios,
161 steps, max relative deviation 3.6e-15).

| Input | Event given to the controls | r187 action (OrbitControls defaults) |
|---|---|---|
| one finger drag | `touch` pointer down/move/up | rotate (`touches.ONE`) |
| two fingers, spread or pinch | two `touch` pointers | dolly by (d0 / d1) ^ zoomSpeed (`touches.TWO`, DOLLY_PAN) |
| two fingers, drag | two `touch` pointers | pan by the midpoint (DOLLY_PAN) |
| left mouse drag | `mouse`, button 0 | rotate; with shift, ctrl or meta held: pan |
| right mouse drag | `mouse`, button 2 | pan; with a modifier: rotate |
| middle mouse drag | `mouse`, button 1 | dolly |
| scroll wheel | wheel, `deltaY` = `scrollDelta.dy` (pixels, deltaMode 0) | dolly by 0.95 ^ (zoomSpeed · abs(deltaY) / 100) |
| trackpad pinch (macOS) | `dollyOut((scale / previous) ^ zoomSpeed)` | dolly, as a touch pinch (E-DOM-CONTROLS) |

- Logical pixels stand for CSS pixels: the child's layout size is `clientWidth`/`clientHeight`, so a drag of
  N logical pixels rotates by 2π · N · rotateSpeed / height at any device pixel ratio. Modifier keys come from
  `HardwareKeyboard`. The scroll is claimed through `pointerSignalResolver`.
- The listener is a plain `Listener` (no gesture arena), like `EntView`'s own, so picking callbacks still
  fire under it. Keyboard input is not wired: call `controls.listenToKeyEvents(element)` and `onKeyDown` from a
  `Focus` if an app wants arrow keys.
- Damping and auto-rotation need `controls.update()` every frame, as in r187: call it from `EntView.onFrame`
  (the example app does, with damping on).
- Checked by `test/orbit_controls_test.dart` (6 widget tests): a touch drag rotates by r187's angle (1e-12), left
  drag rotates and right drag and shift + left pan by r187's pan distance, a pinch changes the distance by
  (80/120)^1.5 and matches the core fed the same events exactly, a two-finger drag pans, the wheel dollies by 0.95^1
  and 0.95^-2.5 with start/end events, and with damping the azimuth keeps moving over `update()` ticks after release
  by r187's geometric series.

## EffectComposer

ent ports r187's `EffectComposer`, `RenderPass`, `OutputPass`, `FXAAPass` and `TuningPass`, with
`EffectPass` (`CopyPass`, `VignettePass`) in place of `ShaderPass`; the renderer implements their
`EffectComposerRenderer`. Each effect is an `EffectMaterial` with typed settings and no shader code, and its shader is
the renderer's (exception E-POSTPROCESSING):

- `lib/src/gpu/effects.dart` registers an `Effect` per material class: `CopyMaterial`, `OutputMaterial`,
  `VignetteMaterial`, `FXAAMaterial` and the bloom's `HighPassMaterial`, `BlurMaterial` and `BloomMaterial`
  (below). Each draws with `EffectVertex` (`shaders/effect.vert`: `vUv` and the projected position) and its
  fragment stage (`copy.frag`, `output_pass.frag`, `vignette.frag`, `fxaa.frag`, the bloom's three). The
  material's fields fill FragInfo; OutputMaterial's tone mapping and output color space become OutputInfo's
  `tone_mapping` and `output_srgb`, so it reuses `shaders/output.glsl`'s tone mapping and sRGB transfer. An
  `Effect` lists its samplers and the texture each reads (default `map` → `t_diffuse`); FragInfo's `flip` follows
  the first.
- A `map` from a render target is read with t flipped (`effectUv`), as the renderer reads every target's
  texture. The material's blending, depth and side apply as for other materials (`_setMaterial`).
- `clear()` and `clearDepth()` make the next `render` clear its target (load actions), since a frame's texture is
  created by `render`; `autoClearColor` and `autoClearDepth` choose what RenderPass clears. No stencil.
- The composer's targets are HalfFloatType (RGBA16F); the last pass draws the frame, which `renderer.texture`
  holds. Adding an effect means adding its material to ent, writing its fragment stage in the bundle and
  registering it.
- Checked by `composer_output` (RenderPass + OutputPass, ACES and sRGB) and `composer_effect` (RenderPass,
  VignettePass, CopyPass, OutputPass under Neutral), and by r187's call log in Node
  (`test/postprocessing/effect_composer_test.dart` in ent, which writes each effect material as the reference's shader
  material: its defines and its uniforms by their names).
- FXAA: `FXAAPass` is an `EffectPass` of `FXAAMaterial` (r187's ShaderPass of `FXAAShader`), whose `setSize` sets
  `resolution` to 1 / width,
  1 / height. `fxaa.frag` keeps the shader's arithmetic in WebGL's vUv and flips t only inside `Sample`, so every
  offset reaches the texel it reaches in r187 (one sampler; the edge-step table is a const array read, never
  stored). `composer_fxaa` shows a 128 × 128 nearest-filtered DataTexture texel for pixel (hard edges at several
  slopes, two one-texel lines): the frame without the FXAAPass equals r187's. With it, the M1 app matches r187;
  flutter_tester gives 3 wrong pixels (worst 42/255) and 4 edge pixels, all on the red line over the blue wedge,
  where a float64 run of the shader shows the search ending where `abs(delta)` equals `gradient * 0.25` exactly (a
  stair corner's bilinear sample), so rounding picks the end (`ties`). Why the app and flutter_tester differ is not
  known. The iPhone 11 differs in 22 pixels (worst 8; "iPhone 11").
- `examples/worm/integration_test/composer_test.dart` draws three chains (RenderPass + OutputPass under ACES with
  sRGB; + VignettePass + CopyPass under Neutral; + FXAAPass on composer_fxaa's pattern) and compares them with
  the frames the macOS app drew (`integration_test/composer/*.png`). On the iPhone 11: output 0 pixels over 2/255
  (worst 0), vignette 0 (worst 1), FXAA 22 pixels (worst 8, at the yellow edge's stair corners, 8/255 darker; cause
  unknown), recorded in the test (at most 24 pixels, 10/255).
- Bloom: `TuningPass` is r187's, with typed materials: `HighPassMaterial` (r187's `LuminosityHighPassShader`;
  `luminosity_high_pass.frag`, WebGLProgram's `luminance()` with Rec. 709 coefficients), the separable blur
  (`BlurMaterial`, `bloom_blur.frag`: one program for the five kernel radii; the number of tap pairs is a uniform
  bounding a loop of at most 11, the offsets and weights packed four to a vec4; t flipped at every sample point)
  and the composite (`BloomMaterial`, `bloom_composite.frag`, five samplers). The mip targets are HalfFloatType (linearly filtered on the A13 too).
  Where `loadKeepsColor` is true (Metal) the final additive blend loads the read buffer as r187 does; where it is
  false (flutter_tester, flutter/flutter#196199) the pass copies the read buffer into its own target and draws that
  copy and the bloom in one scene render (E-POSTPROCESSING; "Cost of the workarounds"). `composer_bloom` (the
  example's 1.5, 0.4, 0.85) and `composer_bloom_wide` (0.8, 1, 0.2), small quads above 1 on black under ACES, match
  r187 on both runners and on the iPhone 11. The `renderToScreen` path is checked by the port's call log only.

## Antialias

`FlutterGpuRenderer.create(antialias: true)` is WebGLRenderer's `antialias` (default false, as r187); exception
E-ANTIALIAS.

- The main frame draws into a 4× multisampled color texture (the frame's format) and a 4× depth texture, both
  `deviceTransient` and kept while the size stays, and resolves into the frame's own fresh texture at the end of the
  one pass (`StoreAction.multisampleResolve`; the depth is not stored while autoClear is on). The samples are not
  kept between renders: without autoClear a render copies the previous resolved texture into them and loads the
  stored 4× depth ("Frame viewport"), as the frame without antialias does.
- Render targets (`setRenderTarget`, the composer's targets, CubeCamera), shadow maps and the transmission target
  (always 4×) are untouched by `antialias`; a target is multisampled by its own `samples` (below).
  `renderer.texture`, `EntView` and `readRenderTargetPixels` see only resolved, single-sample textures.
- Pipelines: Flutter GPU builds the pipeline variant for the pass's sample count, and `compile`/`compileAsync` draw
  their 1×1 frame through the same multisampled path, so they prepare the 4× variants.
- Without `gpuContext.doesSupportOffscreenMSAA` (some OpenGL ES devices) the frame is drawn without MSAA, with one
  warning.
- Checked by `aa_basic` (MeshBasic quads and a triangle turned off the pixel grid, white lines) and `aa_standard`
  (MeshStandardMaterial, a turned box, the standing box's PCF shadow) against Chrome with `antialias: true`, by the
  rule in `parity.dart` (`antialiased`): away from a geometric edge 2/255 as everywhere; within 1 px of one a
  per-scene tolerance and count cap; and at least a recorded count of blended pixels (colors found nowhere in the
  3×3 neighbourhood of our frame without antialias). No pixel outside the edges differs. Counts per runner are
  under "Parity on Metal"; under flutter_tester `aa_basic`'s 462 edge pixels split into lines 269 (up to 119/255)
  and triangle edges 193 (up to 102, median 47, about one of four samples of the 220/255 contrast). Chrome's blended
  counts are 598 (`aa_basic`) and 289 (`aa_standard`).
- The edge differences are expected to be about the sample pattern: ANGLE draws the default framebuffer upside down
  and flips it, so its pattern is probably ours mirrored vertically (a guess: drawing `aa_basic` mirrored in y and
  flipping the rows back cuts the differing pixels from 462 to 206, the worst staying 119, so the pattern explains
  part of it and the lines keep their own difference). The transmission target, an offscreen framebuffer in Chrome,
  matches with the same pattern.
- Cost: not measured. A timing in flutter_tester (1024 × 1024, with readback) is dominated by the readback (about
  309 ms a frame without antialias); it needs the running app (`examples/worm`).

## Render targets with samples

`WebGLRenderTarget(w, h, {'samples': n})` with `n > 0` is drawn with 4× MSAA, as r187 draws into a multisampled
renderbuffer and blits it into the target's texture after each render (`updateMultisampleRenderTarget`); exception
E-ANTIALIAS.

- Attachments (`GpuTextures.target`): besides the resolved color texture (the target's texture), a 4× color texture
  of the same format and a 4× depth texture, all `devicePrivate`. Any `samples` above 0 maps to 4 (WebGL clamps to
  MAX_SAMPLES; Flutter GPU on Metal offers 4).
- The pass (`_frame`) draws into the 4× color with the target's texture as the resolve texture,
  `StoreAction.storeAndMultisampleResolve`, depth stored: every render resolves into the texture, and the samples
  and depth are kept for a later render without `autoClear`, which loads them. On Metal that keeps what an earlier
  render drew (the LoadAction check, 4 samples); under flutter_tester the load clears (flutter/flutter#196199;
  "Render targets").
- Ignored with one warning: `samples` of a cube target (CubeCamera), of a 3D or array target, with a
  `depthTexture`, and without `gpuContext.doesSupportOffscreenMSAA`. Shadow maps are never multisampled.
  `readRenderTargetPixels` and every sampler read the resolved texture.
- Pipelines: Flutter GPU builds the variant for the pass's sample count at the first draw; `compile` and
  `compileAsync` warm only the main frame's count, so the first render into a multisampled target may build 4×
  variants the frame (without `antialias`) did not need.
- Checked by `rt_samples` (aa_basic's scene in a 128 × 128 target with `samples: 4`, shown texel for pixel with
  nearest filtering on a frame without antialias) and `composer_samples` (aa_basic's scene, black clear, through an
  EffectComposer whose HalfFloatType targets have `samples: 4`: RenderPass and OutputPass), by the `antialiased`
  rule with tolerance 200: the resolve averages linear color and the frame then applies the sRGB transfer, so one or
  two samples of difference against a dark color reach about 190/255. No wrong pixels outside the edges; counts
  under "Parity on Metal" (the blended count equals `aa_basic`'s: the same pattern; Chrome 598 each). A renderer
  test reads a multisampled target back (edges blended, a second render resolved again).
- `composer_samples` clears to black on purpose: r187's RenderPass calls `renderer.clear()` into the target, which
  uses the clear value WebGLBackground last set, in sRGB because `setClearColor` ran without a target; the port
  clears a target in linear color. With aa_basic's 0x101018 Chrome's background comes out about 0x4a4a55. Not
  ported.

## HDR environments

ent ports r187's `HDRLoader` (RGBE `.hdr`, HalfFloatType by default or FloatType through
`setDataType`) and `RGBELoader`, its deprecated alias. The loaded DataTexture, with
`EquirectangularReflectionMapping`, works as `scene.environment` and `scene.background` through the renderer's
existing paths: `environments.dart` converts it to a cube render target (background) and a PMREM (environment), and
`textures.dart` uploads the half floats with `flipY` (float32 data as half floats where `filtersFloat` is false).

- `fixtures/hdr/sky.hdr` is written by `tool/reference/js/hdr_files.mjs` (no download); the
  reference page loads it with r187's HDRLoader (scenes.mjs `hdr`), the Dart test with the port.
- `hdr_environment` (HalfFloatType, no tone mapping) and `hdr_environment_aces` (FloatType, ACES, exposure 0.7):
  four front-facing MeshStandardMaterial quads (mirror to rough); 0 wrong pixels under flutter_tester and on Metal
  (M1 and iPhone 11).
- `hdr_environment_sphere` (grid(), roughness 0.45 to 0.95): 0 wrong pixels under flutter_tester and on Metal.
  `hdr_environment_mirror` (grid(), roughness 0 to 0.25): 0 wrong on Metal, 7 wrong (6/255) under flutter_tester,
  so it is in `swiftShader`.
- Lit spheres under SwiftShader: silhouette centres 0.003 to 0.007 pixel from the edge (edges.mjs) are covered by
  the sphere on one path and by the background on the other (up to 153/255), with the file or with the in-memory
  `sky()` alike; spheres of roughness 0 to 0.25 also differ at a few rim pixels by up to 11/255 there. On Metal every
  variant equals r187 (0 wrong, 0 edge pixels), so it is no HDR, PMREM or shader gap.

## Animation

`AnimationMixer` and the keyframe tracks are the core's port; the renderer draws what they set (bones, morph
influences, material properties, transforms). Checked against r187 at fixed times: the harness's `animate` option
(tool/reference/render/README.md) draws one frame per time with `mixer.setTime`, and `parity_test.dart` plays the
clips it reads through ObjectLoader (`AnimationClip.toJSON` in the objects' `animations`, interpolation kept) the
same way, so nothing in the check depends on timing.

- `anim_skinned` (skinned() bars: `bend`, a three-key bone quaternion at weight 0.7, and `lift`, a bone position
  at 0.6, on the attached bar; `sway` fading out and `twist` fading in over 0.8 s, ping-pong, on the detached
  MeshNormalMaterial bar) at 0, 0.37, 1.25 and 2.6 s: 0 wrong pixels, edge pixels 0, 1, 1 and 5 under
  flutter_tester (cap 5).
- `anim_morph` (a morphed() bar: influence 0 linear, influence 1 smooth, `.material.color` and
  `.material.opacity` through PropertyBinding over a grey quad; three quads moving through `.position` keys,
  linear, discrete and smooth, the smooth one with wider keys, so smooth taken as linear moves the quad's edges 2 to
  4 pixels) at 0, 0.37, 0.825 and 1.62 s: 0 wrong pixels, edge pixels 0, 3, 1 and 2 under flutter_tester (cap 3), 0
  on Metal; stable over repeated runs on both.
- The Khronos models AnimatedMorphCube and CesiumMan ("Khronos sample models").

The loop (`examples/worm/lib/animation.dart`, which builds `anim_skinned` in Dart): `onFrame` updates a `Timer`
and advances the mixer by its delta, as in r187, where `Clock` is deprecated since r183:

```dart
onFrame: (elapsed) {
  timer.update();
  mixer.update(timer.getDelta());
},
```

- Pausing: a muted `EntView` (TickerMode) or a backgrounded app calls no `onFrame`, so the mixer stands still.
  On resume the first delta spans the whole pause and the animation jumps ahead by it: the same as r187's `Clock`
  (and a `Timer` not connected to a document) after a hidden browser tab. r187's `Timer.connect(document)` makes
  that delta 0 in a browser; here an app that wants to freeze clamps the delta or connects a `TimerDocument`
  adapter. `test/animation_loop_test.dart` (core time source on the test's fake clock) checks that the mixer
  advances by each ticker delta, stands still while muted for 30 frames, and catches up by the pause on resume.
- iPhone 11 (iOS 16.3.1, profile build, `flutter drive`): `anim_skinned` in a full-screen EntView,
  `compileAsync` first (271 ms), 390 frames, the first 60 dropped. `onFrame` (timer and mixer) 0.16 ms mean,
  0.24 ms p95; the UI thread's build phase (onFrame, render and the view's build and layout; FrameTiming)
  2.50 ms mean, 2.79 ms p95; raster 0.56 ms mean, 0.69 ms p95; total span 3.66 ms mean, 4.10 ms p95.

## macOS run

The example app (`examples/worm`) runs on Metal on the M1 with `FLTEnableImpeller` and `FLTEnableFlutterGPU` in
`macos/Runner/Info.plist`. Its integration tests run with `flutter test integration_test/<test>.dart -d macos
--enable-flutter-gpu`: `render_test.dart`, `parity_metal_test.dart` ("Parity on Metal"), `composer_test.dart`,
`viewer_test.dart`, and the profile benchmark `bench_test.dart` through `flutter drive --profile` ("CPU cost per
frame").

## Pipeline compile cost

Impeller builds a pipeline the first time a program meets a new state (cull side, blending, sample count), and the
lit shaders make that expensive. Render plus readback of one box under a point light, first draw → second draw:

| Material state | `flutter_tester` (unit tests) | macOS app (M1) | iPhone 11 app |
|---|---|---|---|
| Basic (first draw of the process) | 476 ms | 2403 ms | 195–197 ms |
| Phong, front side | 10049 ms | 434 ms | 335 ms |
| Phong, BackSide | 7638 ms | 1 ms | 1 ms |
| Phong, DoubleSide | 14158 ms | 1 ms | 1 ms |
| Phong, transparent | 16057 ms | 113 ms | 139 ms |
| Standard, front side | 6426 ms * | 306 ms * | 417–421 ms |
| Physical (clearcoat), front side | | | 502–508 ms |
| Transmission, front side | | | 612–614 ms |
| Any of them, second draw (BackSide) | 0–21 ms | 0–8 ms | 1–2 ms |

\* Measured with the Standard stage before the texture slots, which made it larger; the iPhone column's physical
rows are current (stages of 133/181/195 KB of MSL), from one fresh app drawing Basic, then Standard, Physical and
Transmission in turn, each followed by its BackSide draw, two runs. The Phong rows of the iPhone column come from a
separate run.

The multi-second cost is specific to `flutter_tester`: there it pushes scenes that meet several new states
(`lit_sides`, `physical_transmission_double_side`, `ao_light_maps`, the all-materials renderer test) past
`package:test`'s 30 s timeout, and a timed-out test body keeps running and changes the renderer the next test
uses, which looks like nondeterministic rendering. In apps the first draw of a new state costs a few hundred
milliseconds once (a first-frame hitch), then about 1 ms.

To pay that during loading, call `renderer.compile(scene, camera)` or `await renderer.compileAsync(scene, camera)`
(upstream signatures, with the optional `targetScene`): they draw every material state of the scene, its shadow
casters, background and transmission pass into a 1×1 offscreen frame, without changing what the next render shows
or counts; `compileAsync` completes when the GPU has run it. A renderer test checks with a debug set of draw states
that the next frame meets no state compile did not draw.

On the iPhone 11, a group of three new states (Standard, Physical and Transmission, DoubleSide and transparent)
drawn cold takes 1312–1315 ms in its first frame; `compileAsync` on the same three kinds opaque and DoubleSide takes
903–907 ms, and its first real frame 3 ms (both measured with the larger pre-`readSlots` stages, 163/244/266 KB; not
remeasured). A cold Standard or Physical state is a hitch of half a second on the A13, so `compileAsync` during
loading matters.

The example viewer (`examples/worm/lib/main.dart`), rough numbers from `integration_test/viewer_test.dart` in
a debug build (`flutter test -d <device>`), two runs each: on the iPhone 11 `load` (GLTFLoader `parseAsync` plus
`compileAsync` of the skinned Standard worm, the Standard ground, the PCF shadow pass and the hemisphere and
directional lights) takes 807 and 765 ms in a freshly installed app, of which parsing takes about 10 ms, so
`compileAsync` is about 750–800 ms cold; on the M1 115 and 306 ms load, 8 and 21 ms parse. With the view running
full screen on the iPhone (828 × 1792 px, pixel ratio 2) the live loop delivers 120 frames in 2 s, 16.7 ms each:
the display's 60 Hz, no dropped frames. The loop plus `render` on the CPU, 60 times back to back, takes 7.0 ms each
(M1: 1.2 ms at 800 × 600); that is JIT debug code and the GPU work runs behind it, so it is an upper bound for the
CPU side, not a frame time (the profile-build numbers are under "Animation").

## CPU cost per frame

Benchmark: `examples/worm/lib/bench.dart` draws N boxes on a 20 × 20 grid on a ground plane under a fixed
camera, in a 400 × 400 view (800 × 800 px at pixel ratio 2), every box turned each frame. Cases: `meshes`, N meshes
sharing one BoxGeometry and one MeshStandardMaterial under an ambient and a directional light (N + 1 draws);
`shadowed`, the same with the directional light casting a 1024² PCF shadow (2N + 1 draws); `instanced`, one
InstancedMesh of N instances whose N matrices are set every frame (2 draws). `integration_test/bench_test.dart`
runs each point twice in a profile build (`flutter drive --profile --driver=test_driver/bench.dart
--target=integration_test/bench_test.dart -d <device>`): `compileAsync`, 1 s warm-up, then 2 s measured. Per frame
it times, with a Stopwatch on the UI thread, turning the boxes, `scene.updateMatrixWorld()` (the scene's
`matrixWorldAutoUpdate` is off so `render` skips it) and `renderer.render`; the frame interval comes from the
ticker's vsync times. `RenderList.build` (projectObject: culling and sorting) is timed afterwards on its own, 30
times back to back, since `render` runs it inside. Each point checks that `info.render.calls` is the case's draw
count. With `--dart-define=BENCH=profile` the driver reads `getCpuSamples` from the profile app's VM service for a
3 s window at N = 1000 (1 ms period). A full run, 36 points, takes about 2 min 44 s of test time (about 4.5 s a
point: the script's own floor), so a run that reaches the 15-minute test timeout has stalled. One run on macOS did,
not reproduced; a guess: the test waits on frames, and macOS stops delivering them to a window that is hidden or on
a sleeping display (the drive's log says "Failed to foreground app").

`render` (encode and submit, `RenderList.build` included), ms per frame, both runs:

| N | meshes, iPhone 11 | shadowed, iPhone 11 | meshes, M1 | shadowed, M1 |
|---|---|---|---|---|
| 500 | 12.37 / 12.41 | 16.38 / 16.30 | 12.30 / 12.17 | 15.48 / 15.28 |
| 1000 | 22.38 / 22.42 | 31.46 / 31.52 | 22.35 / 22.68 | 30.22 / 31.00 |
| 2000 | 45.63 / 45.62 | 63.16 / 63.26 | 46.16 / 44.88 | 65.17 / 61.21 |

iPhone 11: iOS 16.3.1, A13, profile build. M1: macOS, profile build, a 60 Hz display. `instanced` stays at
2.5–3.2 ms on the iPhone and 0.8–1.9 ms on the M1 up to N = 2000.

- The cost is draw encoding: about 22 µs of `render` per main-pass draw on both machines (22.4 ms at 1001 draws)
  and about 9 µs per shadow-caster draw (derived from the table). Both machines cost about the same per draw: the
  time goes to the per-draw path (uniform packing, FFI, Impeller's recording), not to raw CPU speed.
- Outside `render` (both runs of the first benchmark; the renderer work since does not touch them), at N = 1000 on
  the iPhone: turning the boxes 0.22–0.31 ms, `updateMatrixWorld` 0.05–0.06 ms (the boxes keep
  `matrixWorldAutoUpdate`, so all are recomposed), `RenderList.build` 1.3 ms, raster 0.5–0.6 ms; setting 1000
  instance matrices (`Object3D.updateMatrix` plus `setMatrixAt`) 1.1 ms. On the M1 `RenderList.build` is 0.7–0.9 ms
  at 1000.
- Frame rate: in the CPU-profile windows on the iPhone at N = 1000, `meshes` draws 95 frames in 3 s (31.6 ms
  interval, 22.8 ms `render`) and `shadowed` 88 (34.5 ms interval, 31.4 ms `render`). The interval exceeds the CPU
  time; the cause is not measured (a guess: the GPU or the host-buffer pool waiting). Where 60 Hz breaks is not
  measured with the current `render`; from the table (a guess) `meshes` holds near 500 and `shadowed` drops there.
  `instanced` holds 60 Hz up to 2000.

How the uniform path works (`gpu/programs.dart`):

- `UniformBlock` keeps one `ByteData` per block (`begin()` zeroes it) and writes through a `Float32List` view of it
  (member offsets are float-aligned; arm64 and x64 are little-endian like the GPU): `floats` with an indexed loop
  (`Float32List.setRange` takes a slow element-by-element path for sources that are not `Float32List`s, such as
  `Matrix4.elements`, a `Float64List`), direct stores for `float`, `flag` and `mat3`, no temporary lists. Member
  offsets are resolved once per block as float indices in a map (`-1` for a member the shader lacks, ignored;
  `has()`), keyed by constant names: `_vertexUniforms` takes the 9 maps' `*_transform` and `*_channel` names from
  `_mapMembers`, `_draw` the light texture names from `_lightTextures`, so every lookup gets the same `String`
  instance with its hash computed. `ProgramVariant` keeps its fragment `slot_i` `UniformSlot`s in a list and named
  samplers in a map per stage, and reads a light texture's slot from the name's one digit.
- Reuse: `UniformBlock` also keeps the last copy it uploaded, with that copy's `BufferView`, its `HostBuffers` and
  the frame number. `bind` compares the block's words with the uploaded copy bit for bit; when they are equal and
  the view belongs to the same `HostBuffers` and the same open frame, it binds that view again instead of emplacing
  a new copy. A view is valid for the whole frame across passes and command buffers ("Host buffers") and is never
  reused across frames. This is WebGLUniforms' "skip a value equal to the cache", keyed on the bytes themselves, so
  the shader reads exactly what a fresh upload would give. With one shared material it saves the upload of every
  block but `VertInfo` and `TransmissionInfo` (they hold the object's matrices); every block is still filled member
  by member per draw.
- Check mode: `UniformBlock.check` (`--dart-define=UNIFORM_CHECK=true`, or set in a test; off by default, one
  static read per reuse when off) compares, on every reuse, the block byte by byte with the uploaded copy and checks
  that the view's buffer is one of the open frame's blocks (`HostBuffers.holds`), throwing on either. The suite
  passes with it on and off. It is the only guard of the views' lifetime: the parity scenes render one frame each,
  so stale views hold the same bytes there.

Profile (iPhone 11, N = 1000, one run; 1699 and 2136 UI-thread samples), `render` split by what each sample is
doing, share of `render`'s samples and ms per frame:

| Group | meshes | shadowed |
|---|---|---|
| (a) filling uniform blocks: member writes, `begin()`, `_same`, the fill functions | 42.4% (9.7) | 43.5% (13.7) |
| (b) binding and uploading: `bind`/`bindUniform`/`emplace`, texture binds incl. the slot name FFI | 24.1% (5.5) | 20.9% (6.6) |
| (c) Impeller recording: `drawIndexed`, `clearBindings`, pipeline, vertex buffers, state | 26.7% (6.1) | 28.3% (8.9) |
| (d) scene side: culling, sorting, matrices | 0.6% (0.1) | 1.6% (0.5) |
| (e) other: `_draw`'s own code and the rest | 6.2% (1.4) | 5.6% (1.8) |

Each stack goes to the first group with a frame on it, in the order (a) `_same`, (b), (a), (c), (d); the rest is
(e). The raw stacks and split scripts are kept outside the repository.

- (a) in detail, `meshes` / `shadowed`, % of `render`: member writes 23.3 / 26.1, the fill functions' own code 6.1 /
  6.2, `begin()` 5.2 / 4.3, `_same` 4.4 / 3.8, `LightState.write`'s own 3.4 / 3.3; `floats`' own loop is 8.5 / 9.5%
  of all samples, self. By owner: `_vertexUniforms` 10.8 / 15.7, `LightState.write` 8.8 / 8.6,
  `_physicalUniforms` 8.1 / 4.3, `_draw`'s blocks (transmission, offset, light `begin()` and `_same`) 7.0 / 5.7.
- The member lookup (`UniformBlock._index`, a string-keyed map read per write) is 6.1 / 7.3% of `render`.
- (b): the texture binds are about 13–14% of `render` though the boxes have no maps: `endSlots` binds the fallback
  to every unused slot, and each bind sends its slot name through FFI (tonic's UTF-8 conversion 4.2 / 4.0%). The
  upload itself (`HostBuffers.emplace`, `DeviceBuffer.overwrite`) is about 2%.
- (c): `drawIndexed` costs about 4.8 ms per frame (`meshes`); inside it Impeller copies the
  `ShaderStructMemberMetadata` vectors of the bound blocks (4.7 / 4.4%) and looks up the shader function from the
  library per draw (`Shader::GetFunctionFromLibrary`, 1.5 / 2.3%). An engine floor.
- (d) is under 2% in the profile, while the benchmark times `RenderList.build` at 1.3 ms on its own (30 calls back
  to back after the frame). Not explained. Native frames without symbols are 8–9% self.

Remaining ideas, gains guessed:

- Resolve each block's members once into int fields or an index table instead of the map read per write: most of
  the lookup's 6–7% of `render`.
- Split the blocks by how often their inputs change and refill material and frame uniforms only when the program
  or material changes, as r187's `setProgram` does (`refreshMaterial`). Today the blocks mix per-object,
  per-material and per-frame members: `VertInfo` has the matrices next to the maps' uv transforms, `FragInfo` the
  line projection next to the colours, `LightInfo` is written per object (`_lights.write` takes the object). Per
  object are `VertInfo`'s `model_view_matrix`, `model_matrix`, `normal_matrix`, `flip_sided` and `use_tangent`
  (about 46 of about 190 floats), `TransmissionInfo`'s `model_matrix` and `LightInfo`'s `receive_shadow`. The rest
  of (a), about 40% of `render` with one shared material, is the most this could save; less in practice, since the
  shared blocks are still bound per draw ((b) stays) and the reuse has to be keyed on every input.
- Binding only the blocks a variant uses may trim a few percent of (c). The fallback binds of unused texture slots
  stay as long as Flutter GPU clears a pass's bindings after each draw.

Not covered: other materials and textured or transparent objects, GPU time per frame, the frame-interval gap,
memory and GC, Android, a CPU profile on the M1, a second profile run.

## Khronos sample models

`tool/fetch_gltf_samples.sh` fetches `KhronosGroup/glTF-Sample-Assets` at `8f492390` (sparse, blobs on demand) into
the git-ignored `third_party/glTF-Sample-Assets` and copies one variant per model (`glTF-Binary`, `glTF` for
TextureTransformTest), its LICENSE.md, metadata.json and README.md and the license texts into
`fixtures/gltf/khronos/` (10 models, 6.7 MB; `ATTRIBUTION.md` lists licenses and authors). MetalRoughSpheres is not
fetched: its smallest variant is 11.2 MB. DamagedHelmet is not included: its license includes CC-BY-NC-4.0.

The Metal app reads each model as an asset: the example's pubspec lists each model's variant folder under
`integration_test/fixtures/gltf/khronos/`. TextureTransformTest is the `glTF/` variant, whose `.bin` and PNGs are
separate files: the parity test reads every buffer and image a `.gltf` names by URI through its `read` (files under
flutter_tester, assets in the Metal app) and hands them to GLTFLoader as data URLs through its manager's URL
modifier.

Scenes (scenes.mjs `khronos()`: sky.hdr as environment and background, one directional light, a hand-placed
camera), wrong pixels (worst) SwiftShader / Metal (M1):

| Scene | Model | SwiftShader | Metal | Status |
|---|---|---|---|---|
| `khronos_texture_coordinate` | TextureCoordinateTest | 161 (11) | 0 | `swiftShader` |
| `khronos_vertex_color` | VertexColorTest | 252 (174) | 0 | `swiftShader` |
| `khronos_box_textured` | BoxTextured | 205 (146) | 2 (3) | skipped |
| `khronos_alpha_blend_mode` | AlphaBlendModeTest | 96 (179) | 8 (89) | `mipmaps` |
| `khronos_texture_transform` | TextureTransformTest | 312 (122) | 0 | `swiftShader` |
| `khronos_normal_tangent_mirror` | NormalTangentMirrorTest | 330 (69) | 202 (18) | `mipmaps` |
| `khronos_clearcoat` | ClearCoatTest | 234 (65) | 19 (14) | `mipmaps` |
| `khronos_transmission` | TransmissionTest | 569 (185) | 3 (119) | `mipmaps` |
| `khronos_animated_morph_cube` | AnimatedMorphCube | 0 (edge 1–3) | 0 | runs on both |
| `khronos_cesium_man` | CesiumMan | 214–287 (up to 170) | 0 | `swiftShader` |

- `khronos_alpha_blend_mode`: the 8 Metal pixels lie on the small far panels and their green dots (ours greener,
  Chrome whiter): the label's mip levels. Its OPAQUE strip shows the label PNG's transparent texels, which need the
  straight-color PNG decoder (E-DECODE).
- `khronos_normal_tangent_mirror`: sparse, on the highlights of the gold spheres. Close-ups where the maps are
  sampled near 1:1 give 1 wrong (4/255) and 0, a view 4–5× minified 101 (10/255): the gap grows with minification,
  from the mip levels.
- `khronos_clearcoat` (`KHR_materials_clearcoat`, six rows of base, coated and coating-only spheres): the Metal
  pixels lie on the two rows with normal maps under a 0.03-rough surface (coat normals, a 1024² JPEG; shared
  normals, a 512² PNG), in the coated and coating-only columns. The PNG decoder gives that normal map bit-exact
  against an independent decoder; the meshes carry tangents, so the derivative tangent frame is not involved.
- `khronos_transmission` (`KHR_materials_transmission`, plain, textured, masked, rough and metallic shapes over a
  textured backdrop): the 3 pixels (and 2 edge pixels) are texels at the alpha-masked cutout edges of the green
  shapes, kept by us and discarded by r187. The transmission target's mip chain stopping at 2×2 (E-MIPMAP) does not
  show: the rough and metallic transmissive shapes match.
- AnimatedMorphCube (two morph targets weighted by one LINEAR `weights` channel, 127 keys over 4.2 s) at 0, 0.85,
  2.1 and 3.5 s, and CesiumMan (a skinned, JPEG-textured walk: 57 LINEAR channels on 19 joints, keys every 1/24 s
  from 1/24 to 2 s) at 0, 0.55, 1.1 and 1.75 s (t = 0 clamps to the first key), each played through `animate`
  ("Animation") with a camera framing the model over the whole clip. `khronos_animated_morph_cube` caps its edge
  pixels at 8 (`edges`): LINEAR taken as discrete draws 0 wrong but 68 edge pixels at 0.85 s.

### Mip levels against ANGLE

Flutter GPU has no generateMipmap, so `textures.dart` builds the levels of uploaded textures on the CPU: each level
a 2×2 box of the one above, rounded half up, averaged in linear light for sRGB textures. r187 calls
`gl.generateMipmap`, which ANGLE on Metal runs on the GPU; the GL specification leaves its filter to the
implementation (E-MIPFILTER). Probes in headless Chrome (ANGLE Metal, M1) read every level back through a
framebuffer and compared it with the same filter ported to JS, on noise:

- 2048² RGBA8: level 1 differs on 12.4% of the texel channels, all exactly the .5 ties (sum of 4 ≡ 2 mod 4), split
  about evenly between up and down, so neither half-up nor half-to-even on the exact value; levels 2–6 differ on
  25–71%, by 1 (2 on a few from level 3). sRGB8_ALPHA8: 4–35% per level, by ±1 (2 on a few). The rounding of
  level 1 is not reproduced by any float32 model of a 4-texel average tried (sum orders, ×0.25 or ÷4, converted
  half-even or half-up): the best still misses 3%.
- A render pass that samples the level above once, bilinearly, at the centre of each 2×2 block (WebGL on the same
  GPU, 512² noise) gives level 1 bit-exact for both formats. Levels 2–6 then still differ on 13–20%; taking even
  levels from two levels up (4 bilinear taps of a 4×4 block) brings them to 0.2–6%, the closest model found, which
  suggests ANGLE keeps unquantized intermediates for pairs of levels (a guess). Non-power-of-two sizes differ more
  (a 100×60 texture: levels from 12×7 down off by up to 27/255; a guess: WebGL filters odd sizes otherwise than our
  repeated edge texel).

In the scenes, measured by swapping the levels in Chrome (a temporary probe that overwrote each map's levels 1+
after three.js uploaded it):

- With our CPU levels, r187's frame moves away from its own reference by what we differ by, and onto our Metal
  frame: `khronos_normal_tangent_mirror` 217 pixels over 2/255 (max 18) from the reference, 0 over 1/255 from ours;
  `khronos_alpha_blend_mode` 9 over 2/255 (max 89), 0 over 1/255 from ours. So both scenes' Metal gaps are the mip
  levels (the glossy gold highlights amplify ±1 in the 2048² metallic-roughness and normal maps).
  `khronos_box_textured` keeps its 2 pixels at 3/255 from ours either way: not the mip levels.
- With the render-pass model above (1 bilinear tap, even levels 4 taps from two levels up), the three frames land
  within 1/255 of the references, except 2 pixels at 4/255 in `khronos_normal_tangent_mirror`.

A fix is GPU-side generation: a 2D mip fragment pass beside `cube_mip.frag`, mipmapped textures created with render
target usage (sRGB formats as targets), the levels drawn after the upload. It changes every mipmapped texture, on
SwiftShader and the iPhone too, and is exact only at level 1. Kai chose to record the measured gaps instead:
`mipmaps` in `test/parity.dart` holds them, so those scenes pass on Metal and only flutter_tester skips them
(`swiftShader`); `khronos_box_textured` stays skipped.

### Causes of the Khronos model gaps

Temporary probes changed both sides the same way (page.html after GLTFLoader, parity.dart after the Dart
GLTFLoader, a debug output in our shader and an `onBeforeCompile` in r187's), drew both on Metal and compared.

- `khronos_transmission` (verified): the green shapes' mask (a 256² palette PNG with 78 alpha levels, antialiased
  edges) is sampled through its mip levels. The alpha before the test, written out on both sides, is 0.4988 in r187
  and 0.5047 here at (51, 52), 0.4990 and 0.5025 at (47, 74): a tie at the 0.5 cutoff, which r187 discards and we
  keep. Over the green shapes our alpha is 1/255 higher on 288 of 1250 pixels and lower on 6, a bias of our half-up
  box filter (E-MIPFILTER). With the mask's minFilter LinearFilter on both sides (base level only), the alpha
  differs on 3 of 1250 pixels by at most 2/255, and the full frame matches: 0 wrong, worst 0. Every view of the
  scene, close-up or far, still minifies the mask.
- `khronos_clearcoat` (verified that mipmapping is needed for the gap; our levels and the level of detail are not
  separated): with every map of the model on LinearFilter on both sides, the coat-normal and shared-normal rows
  match (no pixel over 2/255 there), so the JPEG and PNG decoding, the RG→XYZ normal reconstruction,
  clearcoatNormalScale and the coat normal's tangent frame all read the base level alike. The 19 come from the mip
  chain: our levels, or the level the GPU picks, as for `khronos_box_textured`. The same probe draws 117 wrong
  (55/255) in rows 24–47 of the frame instead (coated and coating-only columns), where the aliased base level is
  sampled; not examined.
- `khronos_box_textured` (verified that it is the level of detail; why is a guess): the sampler is
  NEAREST_MIPMAP_LINEAR. With the map's minFilter NearestFilter on both sides the frame matches exactly (0 wrong,
  worst 0), so texel selection, the texture coordinates and the flipY rows agree. With NEAREST_MIPMAP_NEAREST it
  draws 6 wrong pixels (56/255): the two pick a different level there, which level contents differing by 1–2/255
  cannot make. So the GPU's level of detail differs slightly at some pixels, and NEAREST_MIPMAP_LINEAR's level
  blend shows it as 3/255. A guess, not checked: if our frame is drawn upside down against ANGLE's, a coarse
  derivative comes from the other row of each 2×2 quad.
