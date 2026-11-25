# ent_impeller

The shader toolchain of Ent Engine's renderers on Impeller's shader compiler, `impellerc`, which ships with the
Flutter SDK. A renderer package's build hook calls it to compile the shaders of [`ent_shaders`][ent_shaders] into the
renderer's own shader bundle when an app is built. An app does not use this package directly.

- `compileShaders(input, output, backends)`: compiles the fixed shaders and the variants the app's registry lists
  (`hooks: user_defines: <renderer package>: shaders:`) into the renderer package's
  `build/shaderbundles/ent.shaderbundle`, keeping only the backends the renderer draws with on the target. The
  bundle is empty on a platform the renderer does not support, or one the registry's `renderers` map gives to
  another renderer.
- `strip(bundle, backends)`: a bundle with only those backends.
- `readBundle(bundle, backend)`: a bundle's shaders for one backend, with their inputs, uniform blocks and textures.
- `findImpellerc()`: the Flutter SDK's `impellerc` (or `IMPELLERC`, which Flutter's tools set for build hooks).

A renderer package's hook is then a few lines:

```dart
import 'package:code_assets/code_assets.dart';
import 'package:ent_impeller/ent_impeller.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await compileShaders(input, output, {
      OS.macOS: {'opengl_es'},
      OS.android: {'opengl_es'},
    });
  });
}
```

Its `pubspec.yaml` declares the bundle as an asset (`build/shaderbundles/ent.shaderbundle`).

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

[ent_shaders]: https://github.com/kamora/ent/tree/master/packages/ent_shaders
