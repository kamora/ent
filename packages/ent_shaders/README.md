# ent_shaders

The shaders of Ent Engine, shared by its renderers. An app does not use this package directly: a renderer package
such as [`ent_flutter`][ent_flutter] depends on it, and the app names the shader variants it draws with.

Shaders are compiled only when the app is built, never at runtime. This package's build hook compiles them with
`impellerc` into one shader bundle, the asset `packages/ent_shaders/build/shaderbundles/ent.shaderbundle`:

- the fixed shaders in `ent.shaderbundle.json` (vertex stages, backgrounds, environment maps, shadows,
  post-processing);
- one fragment variant per material setup the app lists, such as `lambert map normal_map`.

The bundle keeps only the GPU backends of the target the app is built for.

## Shader variants

Name the registry file in the app's `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    ent_shaders:
      shaders: ent_shaders.json
```

```json
{
	"variants": [
		"physical ao_map metalness_map roughness_map"
	]
}
```

A key is a material kind followed by its flags; [`docs/shader-variants.md`][variants] lists them. A renderer
throws a `StateError` naming the key of a draw whose variant is missing.

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

The notices of the third-party code it builds on are in `THIRD_PARTY_NOTICES.md`.

[ent_flutter]: https://github.com/kamora/ent/tree/master/packages/ent_flutter
[variants]: https://github.com/kamora/ent/blob/master/docs/shader-variants.md
