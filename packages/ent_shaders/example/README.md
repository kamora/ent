# Example

An app uses `ent_shaders` through a renderer, such as `ent_flutter`, and only tells it which material variants to
compile. List them in a registry file beside the app's `pubspec.yaml`, `ent_shaders.json`:

```json
{
	"variants": [
		"basic map",
		"lambert map normal_map",
		"physical ao_map metalness_map roughness_map"
	]
}
```

Name it in `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    ent_shaders:
      shaders: ent_shaders.json
```

The next build compiles these variants with the fixed shaders into the app's shader bundle. A renderer drawing a
material whose variant is missing throws a `StateError` naming the key to add.

To collect the keys an app needs, `ent_flutter`'s renderer can record them while the app runs through its scenes:

```dart
final renderer = await FlutterGpuRenderer.create();
renderer.recorded = {};

// After the scenes:
debugPrint(JsonEncoder.withIndent('\t').convert({'variants': renderer.recorded!.toList()..sort()}));
```
