# voxels

A voxel landscape to blast apart, drawn by `ent_flutter`'s `FlutterGpuRenderer` on macOS: rolling terrain raised
from a generated heightmap (`VoxelWorld.addHeightmap`), turned and zoomed with `OrbitControls`. A click or tap on
the ground finds the voxel under the pointer (`PointerInput`, `Raycaster.setFromCamera`, `VoxelWorld.pick`), blows a
crater into it (`VoxelWorld.removeSphere`) and throws the voxels out as debris (`VoxelDebris`); the bottom layer is
bedrock and stays. Each blast is heard from where it opens (`ent_audio`'s `NativeAudioContext`, a `PositionalAudio`
with a sound made in code in `lib/sound.dart`). KeyR raises a fresh landscape.

Flutter GPU must be enabled: `macos/Runner/Info.plist` already sets `FLTEnableFlutterGPU` and `FLTEnableImpeller` to
`true` (see `packages/ent_flutter/README.md`).

```sh
flutter run -d macos
```

On a fresh checkout or after `flutter clean`, build the app once (`flutter build macos --debug`, or any `flutter run`)
before the device test: it looks for the shader bundle before the build hook has made it.

```sh
flutter test integration_test/landscape_test.dart -d macos
flutter test integration_test/sound_test.dart -d macos
```

The sound test plays on the Mac's output device at a master volume of 0, so it is silent.
