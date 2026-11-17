# Upstream

| | |
|---|---|
| Repository | https://github.com/mrdoob/three.js |
| Tag | `r187` (annotated tag object `456a78fd22f4ce11d929fd62c8579b83be06008a`) |
| Commit | `7e89746a687bb88271253698fa108b1dd59825d0` (committed 2026-10-30T16:56:52+09:00, "r187") |
| `package.json` version | `0.187.0` |
| License | MIT, "Copyright © 2010-2026 three.js authors"; copied to `packages/ent/LICENSE` |
| Retrieved | 2026-11-04, `git clone --depth 1 --branch r187 --filter=blob:none --sparse` |

The tag was verified with `git ls-remote --tags` before cloning; no other release was substituted.

## Reference checkout

`third_party/three.js/` is a sparse, read-only checkout of `src/`, `test/unit/`, `examples/jsm/lights/`,
`examples/jsm/controls/`, `examples/jsm/loaders/GLTFLoader.js`, `examples/jsm/loaders/HDRLoader.js`,
`examples/jsm/loaders/RGBELoader.js`, `examples/jsm/utils/BufferGeometryUtils.js`,
`examples/jsm/utils/SkeletonUtils.js`, `LICENSE` and `package.json`. It is git-ignored; `tool/fetch_upstream.sh`
recreates it, sets the sparse paths on every run (so an existing checkout picks up added ones, fetching their blobs
at the pinned commit) and fails if the checkout is not at the pinned commit. `tool/reference/js/generate.mjs`
refuses to run against any other tag. Each path serves a port or a reference:

- `examples/jsm/lights/`: RectAreaLightUniformsLib, which the reference page calls as r187 apps do, and the LTC
  tables below.
- `examples/jsm/controls/`: `OrbitControls.js` and `MapControls.js`, ported to `packages/ent`
  (`lib/src/controls/`) and checked by `node tool/reference/js/orbit_controls.mjs`, which imports them from the
  checkout with the bare `three` specifier resolved to `src/Three.Core.js`.
- `GLTFLoader.js`, `BufferGeometryUtils.js` and `SkeletonUtils.js`: `GLTFLoader` and the two helpers it imports
  (`toTrianglesDrawMode`, `clone`), ported to `packages/ent` (`lib/src/loaders/`, `lib/src/utils/`) and
  checked by `node tool/reference/js/gltf_loader.mjs` the same way; the reference page imports `GLTFLoader.js`
  through its `three/addons/` import map entry.
- `HDRLoader.js` and `RGBELoader.js` (r187's deprecated alias of it, a subclass that only warns): `HDRLoader` and
  `RGBELoader` in `packages/ent` (`lib/src/loaders/hdr_loader.dart`), checked by
  `node tool/reference/js/hdr_loader.mjs` the same way and by the `hdr_environment` reference scenes.

## Data derived from the checkout

| Data | Source | Generator | Output |
|---|---|---|---|
| LTC tables of RectAreaLight | `examples/jsm/lights/RectAreaLightTexturesLib.js` at the pinned commit: `LTC_MAT_1` and `LTC_MAT_2` (64 × 64 RGBA each; from selfshadow/ltc_code `fit/results/ltc.js`, Heitz, Dupuy, Hill and Neubelt, as the file credits) | `node tool/ltc.mjs` (from the repository root) | `packages/ent_flutter/lib/src/gpu/ltc_data.dart`: base64 of the values converted with r187's `DataUtils.toHalfFloat` (imported from the checkout), little-endian, the data of r187's `LTC_HALF_1` and `LTC_HALF_2`; regenerate, never edit |

## Vendored code inside three.js

| Code | Version | License | Where |
|---|---|---|---|
| mapbox/earcut (`src/extras/lib/earcut.js`) | 3.0.2 | ISC, "Copyright (c) 2024, Mapbox" | The r187 file carries no license text; the ISC notice from mapbox/earcut v3.0.2 is reproduced in the header of `packages/ent/lib/src/extras/lib/earcut.dart` |

## Third-party tooling

| Package | Version | License | Use |
|---|---|---|---|
| puppeteer-core | 25.15.0 (pinned in `tool/package.json`, installed with `--ignore-scripts`) | Apache-2.0 | Drives the installed Chrome to draw the renderer reference frames (`tool/reference/render/render.mjs`); downloads no browser; not shipped. The installed Chrome updates itself, so `meta.json` names the version that drew the set (157.0.8103.39); after an update, redraw every scene and compare before keeping the new set |
| package:test, package:lints | per `pubspec.lock` | BSD-3-Clause | Dart dev dependencies; not shipped |

`ent` itself has no runtime dependencies (`dart:math`, `dart:typed_data` only).
