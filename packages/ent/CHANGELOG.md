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
