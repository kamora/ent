# ent_opengl

The OpenGL ES renderer of Ent Engine: `OpenGlRenderer` draws through OpenGL ES 3, on ANGLE (Metal) on macOS and on
the system's OpenGL ES on Android. It exports all of [`ent`][ent], `EntView` and `OrbitControlsListener`, so an app
depends on `ent_opengl` only.

It draws what [`ent_flutter`][ent_flutter]'s Flutter GPU renderer draws, from the same renderer core and the same
shaders, and is checked against the same reference frames. Use it where Flutter GPU does not run, such as Android phones
where Impeller falls back to OpenGL ES.

## Requirements

- Flutter 3.47.6 or later. Flutter GPU does not need to be enabled.
- macOS: ANGLE comes from the [`wrangle`][wrangle] package, bundled with the app (arm64 and x64).
- Android: OpenGL ES 3.0, API level 24 or later.

| Platform | Status |
|---|---|
| macOS | Verified on an M1 |
| Android | Verified on a Galaxy S10 (Mali-G76) |
| iOS, Windows, Linux, web | Not supported in this version |

## Getting started

1. Depend on `ent_opengl`.
2. List the shader variants the app draws with, in a registry file as for `ent_flutter` ([its README][getting_started],
   step 2), and name it under `ent_opengl`, whose build hook compiles them:

   ```yaml
   hooks:
     user_defines:
       ent_opengl:
         shaders: ent_shaders.json
   ```

   An app that uses Flutter GPU on some platforms and OpenGL ES on others depends on both renderer packages, names
   the same file under each, and says in it which renderer draws where, so each platform carries only its renderer's
   shaders:

   ```json
   {
   	"renderers": {
   		"ios": "ent_flutter",
   		"macos": "ent_flutter",
   		"android": "ent_opengl"
   	},
   	"variants": ["basic"]
   }
   ```
3. Install the platform services, create the renderer and show the scene:

   ```dart
   FlutterPlatform.install();
   final renderer = await OpenGlRenderer.create(antialias: true);

   EntView(
     renderer: renderer,
     scene: scene,
     camera: camera,
     onFrame: (elapsed) => cube.rotation.y = elapsed.inMicroseconds / 1e6,
   );
   ```

   `EntView` shows the frames in a Flutter `Texture` widget. It does not own the renderer: the app disposes it.

`example/lib/main.dart` is this as a whole app. Flutter's widgets define `Color` and `Texture` too: import them with
`hide Color, Texture`.

How it draws, which way its rows run, how frames reach the screen and how it compares with the reference frames is in
[`docs/opengl.md`][opengl].

## Tests

```sh
flutter test --enable-impeller --enable-flutter-gpu
cd example && flutter build macos --debug && flutter test integration_test/parity_test.dart -d macos
```

The host tests compare its frames with Flutter GPU's, which needs the flags, and run the parity scenes on ANGLE.

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

[ent]: https://github.com/kamora/ent/tree/master/packages/ent
[ent_flutter]: https://github.com/kamora/ent/tree/master/packages/ent_flutter
[wrangle]: https://pub.dev/packages/wrangle
[getting_started]: https://github.com/kamora/ent/tree/master/packages/ent_flutter#getting-started
[opengl]: https://github.com/kamora/ent/blob/master/docs/opengl.md
