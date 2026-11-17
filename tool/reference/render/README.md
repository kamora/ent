# Reference frames

Frames drawn by three.js r187's own `WebGLRenderer`, the yardstick for `FlutterGpuRenderer`.

- `scenes.mjs`: the scenes, built with the pinned r187 source. A scene may also set WebGLRenderer properties
  (`toneMapping`, `toneMappingExposure`, `outputColorSpace`, `sortObjects`), and a `distance` point light: the
  light WebGLShadowMap would set for its MeshDistanceMaterials (page.html puts it in the renderer's material
  properties; the JSON names it by uuid and the Dart test passes it as `distanceLight`).
  A scene may also return a render target pass (`target`: scene, camera, size, clear, WebGLRenderTarget options),
  drawn first; its texture becomes the map of the materials with `userData.renderTarget`. The pass's
  `depthTexture` (`{ type, format }`, r187's defaults when left out) attaches a `DepthTexture` of the target's size,
  which becomes the map of the materials with `userData.depthTexture` (scenes `depth_texture_view`,
  `depth_texture_float`).
  A scene may also return a CubeCamera pass (`cube`: size, WebGLCubeRenderTarget options, near, far, position),
  updated once before the frame with the meshes whose material has `userData.cubeTarget` hidden; its texture then
  becomes their envMap.
  A scene may also return `animate` (`times`, and `actions` keyed by clip name: weight, loop, timeScale, fadeIn,
  fadeOut): page.html takes the JSON first (the rest pose, with the clips in the objects' `animations`), plays every
  clip of every object in one `AnimationMixer` (LoopRepeat by default) and draws a frame per time with
  `mixer.setTime( time )`, in the order given (a finished fade stays finished). render.mjs writes
  `<name>@<time>.png` per time and no `<name>.png`; the Dart test loads the clips through ObjectLoader, plays them
  the same way and compares each frame. Scenes: `anim_skinned`, `anim_morph`.
  A scene may also return `gltf`, the URL of a glTF asset (`/fixtures/gltf/render.gltf`): page.html loads it
  with r187's `GLTFLoader` (`three/addons/`) and adds its scene last, its `animations` set to the asset's clips (so
  `animate` plays them), then takes the JSON without it; the JSON keeps the URL and the Dart test loads the same
  file with the Dart `GLTFLoader` (ent) and adds its scene last too. Scenes: `gltf_meshes`,
  `gltf_textured` (`render_textured.gltf`: textures, PBR extensions, lines and points), `gltf_skinned_anim`
  (`skinned.gltf`: a skin, morph targets and two clips with LINEAR, STEP and CUBICSPLINE channels, 3 frames).
  A scene may also return `hdr` (`{ url, type }`): page.html loads the RGBE image at `url`
  (`/fixtures/hdr/sky.hdr`, written by `tool/reference/js/hdr_files.mjs`) with r187's `HDRLoader`
  (`type`, HalfFloatType when left out) as an equirectangular map and makes it `scene.environment` and
  `scene.background`, cleared again before `toJSON`; the Dart test parses the same file with the Dart `HDRLoader`.
  Scenes: `hdr_environment`, `hdr_environment_aces`, `hdr_environment_sphere`, `hdr_environment_mirror`.
  Khronos sample models (`fixtures/gltf/khronos/`, fetched by `tool/fetch_gltf_samples.sh` at a pinned commit,
  licenses in its `ATTRIBUTION.md`) use both hooks through scenes.mjs `khronos()`: `gltf` with the model, `hdr` with
  sky.hdr, one directional light and a hand-placed camera. Scenes: `khronos_box_textured`,
  `khronos_texture_coordinate`, `khronos_vertex_color`, `khronos_alpha_blend_mode`,
  `khronos_normal_tangent_mirror`, `khronos_texture_transform`, `khronos_clearcoat`, `khronos_transmission`, and
  with `animate` the animated `khronos_animated_morph_cube` and `khronos_cesium_man` (4 frames each). A
  `.gltf` loads its buffers and images by URI: the page from the served repository, the Dart test through its `read`,
  as data URLs.
  A scene may also return `composer` (`{}`, or `{ fxaa: true, vignette: { offset, darkness }, copy: opacity,
  bloom: { strength, radius, threshold, tints }, samples }`): page.html draws the frame through r187's `EffectComposer` (a
  `RenderPass`, an `FXAAPass` with `fxaa`, a `ShaderPass` of `VignetteShader` with those uniforms and one of
  `CopyShader` with that opacity when given, an `UnrealBloomPass` of the frame's resolution with `bloom`'s settings
  when given, an `OutputPass`) in place of `renderer.render`; the JSON keeps it and the Dart test builds the same chain
  with ent and compares the frame the last pass drew; with `samples` both sides pass the composer a
  HalfFloatType target of the frame's size with that many samples. Scenes: `composer_output`, `composer_effect`,
  `composer_samples`, `composer_fxaa`, `composer_bloom`, `composer_bloom_wide`.
  A scene may set `antialias: true`, WebGLRenderer's constructor parameter: page.html creates the renderer with it
  and the JSON keeps it; the Dart test creates `FlutterGpuRenderer.create(antialias: true)`, draws the scene once
  more without antialias and compares by its `antialiased` rule (exception E-ANTIALIAS: edges within a looser
  per-scene tolerance and cap, and a minimum of blended pixels). Scenes: `aa_basic`, `aa_standard`. Scenes listed
  in that map without `antialias` (`rt_samples`, `composer_samples`) are compared the same way, the frame without
  MSAA drawn with the target's or composer's `samples` set to 0.
  A scene may also return `overlay` (`{ scene, camera, clearDepth }`): page.html sets `autoClear = false`, calls
  `clear()`, renders the scene, calls `clearDepth()` when `clearDepth` is set and renders the overlay into the same
  frame, as an r187 HUD; the JSON keeps it and the Dart test draws the same sequence and compares the last render's
  image. Scenes: `frame_hud`, `frame_overlay_depth` (exception E-FRAME).
  A scene may also return `views` (`{ autoClear, list }`, with its `overlay`): page.html sets `autoClear` and per
  view calls `setViewport`, `setScissor` (default the viewport), `setScissorTest`, `setClearColor( color )` when given,
  `clear()` or `clearDepth()` for `clear: 'all'` or `'depth'`, and renders the scene, or the overlay's with
  `overlay: true`. Scenes: `frame_views` (split screen, scissored autoClear), `frame_inset` (an inset after a
  scissored clearDepth).
  A scene may cap its edge pixels (`edges`, saved in the JSON): the edge rule passes a differing pixel whose color
  appears within one pixel, which hides a missing or extra one-pixel feature such as a line or point pixel.
- `page.html`: renders one scene (128×128, `antialias: false` unless the scene sets it, pixel ratio 1) and returns the drawing buffer's
  raw bytes (`readPixels`; `toDataURL` would un-premultiply them) and the scene's JSON, with each sprite's
  `center` added (r187's `toJSON` drops it; its ObjectLoader reads it).
- `render.mjs`: serves the repository on localhost, drives the installed Chrome headless through
  `puppeteer-core` (pinned in `tool/`, no browser download) and writes `fixtures/rendering/reference/<name>.png`
  (the raw bytes as an 8-bit RGBA PNG), `<name>.json` (scene, camera, clear color, size, renderer properties)
  and `meta.json` (Chrome version, GPU, three.js pin). It does not delete the files of a removed scene.

- `edges.mjs`: lists the pixel centres a silhouette edge passes closer than a threshold (no browser; Node with
  the pinned source); with `--rim <cos>` also interior edges near silhouettes (both vertex normals facing the
  camera less than `<cos>`). It projects each instance of an InstancedMesh (morph targets not applied). Run it
  after placing curved or slanted objects.

```sh
(cd tool && npm ci --ignore-scripts)
node tool/reference/render/render.mjs            # all scenes
node tool/reference/render/render.mjs basic_triangle
node tool/reference/render/edges.mjs --threshold 0.03 light_hemisphere
node tool/reference/render/edges.mjs --threshold 0.025 --rim 0.35 standard_grid_light
```

The Dart side is `packages/ent_flutter/test/parity_test.dart`: it loads each JSON with `ObjectLoader`
(`parseAsync`, so data-URL images are decoded), renders it and compares the frames (tolerances in
`docs/flutter-gpu.md`). It decodes the reference PNG itself (filter type 0 rows, as `render.mjs` writes them):
dart:ui premultiplies on decoding and would lose the colors of pixels whose alpha is 0. Chrome is only the reference; the port never runs in a browser.

Writing a scene:

- Only what `toJSON` keeps reaches the Dart side: a material color is clamped hex (use vertex colors for values
  above 1), a `PlaneGeometry` keeps only its parameters (copy it into a `BufferGeometry` before adding
  attributes), `texture.mipmaps` are dropped.
- Keep edges and linearly filtered texel centres off pixel centres, gradients across edges gentle, filtered
  textures free of zero channels, and texels of about a pixel low in contrast: the two GPU paths differ there
  by more than the tolerance (measurements in `docs/flutter-gpu.md`).
- Lit curved objects: their rims change color steeply, so a rim pixel covered on one side only fails. Place
  spheres so `edges.mjs --threshold 0.03` lists no pixel centre on their silhouette (coverage flipped up to
  0.025 pixel away from an edge), prefer 16 segments where the rim still fails (a wider rim band shades more
  gently), keep near-black rims away with some ambient light, and test lighting on front-facing quads where
  possible (straight edges are easy to keep off pixel centres).
- Shading discontinuities count like edges: flat-shaded faces seen edge-on at a silhouette (slivers covered on
  one side only), toon steps (a nearest-filtered gradientMap, the default ramp's one-pixel smoothing) and steep
  highlights.
- Animated scenes: keep straight edges off pixel centres at every time, not only at rest (a horizontal bar foot
  0.015 pixel from a row of centres at one time flipped 18 pixels); check the vertices' window positions per time
  with r187's mixer before rendering.
- A light's `target` moves only if it is in the scene (`scene.add( light.target )`); otherwise it stays at the
  origin on both sides.
- Packed depths (MeshDepthMaterial RGBA, RGB, RG) expose the last bits of the depth, which the two paths compute
  differently (z / w on Flutter GPU, 0.5 × z / w + 0.5 in WebGL): use an orthographic camera with binary
  near and far and planes at depths with few bits (`depth_packing`).
- MeshStandardMaterial and MeshPhysicalMaterial on curved meshes: geometryRoughness comes from derivatives of the
  normal, per triangle, so every triangle edge is a shading discontinuity, steep in the slivers next to a
  silhouette. Keep pixel centres 0.025 pixel off silhouettes and off interior edges near them
  (`edges.mjs --threshold 0.025 --rim 0.35`), with spheres large enough to place (`grid()`: radius 0.44, 12
  segments). Prefer front-facing quads for the material's features. Steep highlights still differ: a clearcoat of
  roughness 0.2 over a normal map, metal spheres of roughness 0.3 to 0.4 under a directional light.
- Cube maps reflected on a sphere are minified, texels about a pixel: use smooth content (`smoothCube()`, no
  seams between faces) without mipmaps there; a magnified CubeTexture background with the canvas `skybox()` needs
  its contrast lowered at the discs.
- Transmission samples a 4× multisampled render of the opaque objects: keep their edges, in the target, off the
  sample positions (x offsets 0.125, 0.375, 0.625, 0.875 within a pixel), for example at x.0, x.25 or x.75
  (`physical_transmission`); samples within about 0.03 pixel of an edge are covered differently.
