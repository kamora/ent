## 0.1.0-dev.6

- `Input.pointer`: the pointer's position from the sources `'PointerX'` and `'PointerY'`, in normalized device
  coordinates for `Raycaster.setFromCamera`; the pointer's buttons are the sources `'Pointer'`, `'PointerSecondary'`
  and `'PointerMiddle'`.

## 0.1.0-dev.5

- `VOXLoader`, the reference's loader for MagicaVoxel files: models (`VOXChunk`) and version 200 scene graphs, with
  `VOXLoader.buildMesh` (greedy meshing, vertex colors) and `VOXLoader.buildData3DTexture`.
- `VoxelWorld`, Ent's own design: voxels on an unbounded grid, drawn by chunk meshes rebuilt after changes within a
  count or time budget; `pick` finds the voxel a ray hits (`VoxelHit`), `removeSphere` empties a ball of voxels;
  `addHeightmap` builds terrain from an image's heights and colors.

## 0.1.0-dev.4

- A game layer, Ent's own design: `Game`, a game loop driven by a frame tick, with pause and time scale; `Task`s
  (`after`, `every`, `everyFrame`) owned by scene objects; tweens (`move`, `turn`, `face`, `resize`, `fade`, `tween`)
  with delays and `Ease` curves; `Input`, an input map of actions and axes over named sources.
- Every public member has a doc comment.

## 0.1.0-dev.3

- Internal: conditional expressions test one condition each (a JS `value || fallback` on numbers is one helper);
  behaviour unchanged, every fixture number the same.

## 0.1.0-dev.2

- Test-only members, marked `@visibleForTesting` (new dependency: `package:meta`), where the tests read state the
  reference keeps private: `Camera.reversedDepth=`, `Euler.onChangeCallback`, `Quaternion.onChangeCallback`,
  `Interpolant.cachedIndex`, `CubicInterpolant`'s weights and offsets, `StereoCamera.cache`, `FrustumArray.frustums`
  and `count`, `Audio.progress`, `AnimationAction.loopCount` and `startTime`, `ColorManagement.getMatrix`,
  `Earcut.deviation` and `flatten`, `BatchedMesh.multiDrawBytesPerElement`, `mergedDrawCount` and
  `updateDrawParameters`, `LightShadow.updateMatrix`. The analyzer warns when code outside tests uses them.
- The tests no longer use `dart:mirrors`, deprecated in Dart 3.14.

## 0.1.0-dev.1

- First release: the scene graph, math, cameras, geometries, materials, lights and shadows, animation, `GLTFLoader`,
  `HDRLoader` and the core loaders, `OrbitControls` and `MapControls`, and `EffectComposer` with its passes.
