# ent_shaders

The shaders of Ent Engine, written once for every renderer. An app does not use this package directly: a renderer
package such as [`ent_flutter`][ent_flutter] or [`ent_opengl`][ent_opengl] compiles these shaders into its own form
when the app is built, and the app names the shader variants it draws with.

- `shaders/`: the GLSL of the fixed shaders (vertex stages, backgrounds, environment maps, shadows, post-processing)
  and of the materials.
- `ent.shaderbundle.json`: the list of the fixed shaders, each with its stage and file.
- `package:ent_shaders/ent_shaders.dart`: the variant scheme, which turns a material setup such as
  `lambert map normal_map` into a key, and a key into a shader source with its defines.

Nothing here compiles anything: each renderer package carries its own toolchain. Both of today's renderers compile
through [`ent_impeller`][ent_impeller], on Impeller's shader compiler. Shaders are never compiled at runtime.

## Shader variants

The app lists its variants in a registry file and names it in its `pubspec.yaml`, under its renderer package:

```yaml
hooks:
  user_defines:
    ent_flutter:
      shaders: ent_shaders.json
```

```json
{
	"variants": [
		"physical ao_map metalness_map roughness_map"
	]
}
```

An app with two renderers, one per platform, adds which renderer draws where, such as
`"renderers": {"ios": "ent_flutter", "android": "ent_opengl"}`; `readRenderers` reads it.

A key is a material kind followed by its flags; [`docs/shader-variants.md`][variants] lists them. A renderer
throws a `StateError` naming the key of a draw whose variant is missing.

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

The notices of the third-party code it builds on are in `THIRD_PARTY_NOTICES.md`.

[ent_flutter]: https://github.com/kamora/ent/tree/master/packages/ent_flutter
[ent_opengl]: https://github.com/kamora/ent/tree/master/packages/ent_opengl
[ent_impeller]: https://github.com/kamora/ent/tree/master/packages/ent_impeller
[variants]: https://github.com/kamora/ent/blob/master/docs/shader-variants.md
