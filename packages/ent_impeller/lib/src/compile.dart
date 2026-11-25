// Compiles the shaders of ent_shaders for a renderer package's build hook.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:code_assets/code_assets.dart';
import 'package:ent_shaders/ent_shaders.dart';
import 'package:hooks/hooks.dart';

import 'bundles.dart';
import 'impellerc.dart';

/// Compiles the shaders a renderer package draws with into `build/shaderbundles/ent.shaderbundle` in that package
/// (the asset its pubspec declares): the fixed shaders of ent_shaders, plus the variants the app's registry lists
/// (`hooks: user_defines: <package>: shaders:`), keeping the target's [backends]. The keys of [backends] are the
/// platforms the renderer supports; a null value keeps every backend.
///
/// The bundle is empty on a platform the renderer does not support, and on one the registry's `renderers` map gives
/// to another renderer: the renderer's `create()` then says why. The build fails when the map gives this renderer a
/// platform it does not support, or names a package the app does not have.
Future<void> compileShaders(BuildInput input, BuildOutputBuilder output, Map<OS, Set<String>?> backends) async {
  final root = input.packageRoot;
  final package = input.packageName;
  final registry = input.userDefines.path('shaders');
  final text = registry == null ? null : File.fromUri(registry).readAsStringSync();
  final renderers = text == null ? null : readRenderers(text);
  final target = input.config.buildCodeAssets ? input.config.code.targetOS : null;

  if (registry != null) {
    output.dependencies.add(registry);
  }

  for (final MapEntry(key: platform, value: renderer) in renderers?.entries ?? const <MapEntry<String, String>>[]) {
    if (await Isolate.resolvePackageUri(Uri.parse('package:$renderer/')) == null) {
      throw StateError(
        '$package: the shader registry gives $platform to $renderer, which is not a package of this app.',
      );
    }

    if (renderer == package && !backends.keys.any((os) => os.name == platform)) {
      throw StateError(
        '$package: the shader registry gives $platform to $package, which supports only '
        '${backends.keys.map((os) => os.name).join(', ')}.',
      );
    }
  }

  // Every build of the package, from any app using it (by path, or through one pub cache), rewrites build/variants/
  // and the one bundle: they take turns, or one wipes the sources another is still compiling. Closing the file
  // releases the lock, and so does the process ending.
  final lock = await (File.fromUri(
    root.resolve('build/variants.lock'),
  )..createSync(recursive: true)).open(mode: FileMode.append);
  await lock.lock(FileLock.blockingExclusive);

  try {
    final bundle = File.fromUri(root.resolve('build/shaderbundles/ent.shaderbundle'))..parent.createSync();
    File? impellerc;

    // Drawn here: a supported target, which the registry's map (when it has one) gives to this renderer.
    if (target == null || backends.containsKey(target) && (renderers == null || renderers[target.name] == package)) {
      impellerc = findImpellerc();
      output.dependencies.addAll(await _compile(root, text, impellerc, bundle));
      final kept = backends[target];

      if (kept != null) {
        bundle.writeAsBytesSync(strip(bundle.readAsBytesSync(), kept));
      }
    } else {
      bundle.writeAsBytesSync(const []);
    }

    // Every target and registry writes this one bundle, so another build may have replaced it. The stamp says whose
    // it is: as an input of this build, a stamp another build rewrote reruns this hook. Backdated: a hook runner
    // reruns a hook whose input is dated after it started the hook.
    output.dependencies.add(
      (File.fromUri(root.resolve('build/shaderbundles/ent.shaderbundle.owner'))
            ..writeAsStringSync('${target?.name} $registry ${impellerc?.path}\n')
            ..setLastModifiedSync(DateTime.utc(2000)))
          .uri,
    );
  } finally {
    await lock.close();
  }
}

// Compiles the fixed shaders and the variants of the registry [text] into [bundle], with every backend. Returns the
// files to depend on: those impellerc read, but not the variants (written again on every build, they would rerun
// the hook every time; their registry stands for them), and the compiler, so a new Flutter recompiles.
Future<List<Uri>> _compile(Uri root, String? text, File impellerc, File bundle) async {
  final shaders = (await Isolate.resolvePackageUri(Uri.parse('package:ent_shaders/')))!.resolve('../');
  final fixed = shaders.resolve('ent.shaderbundle.json');
  final manifest = {
    for (final MapEntry(:key, :value) in (json.decode(File.fromUri(fixed).readAsStringSync()) as Map).entries)
      key as String: {...value as Map, 'file': shaders.resolve(value['file'] as String).toFilePath()},
  };
  final variants = Directory.fromUri(root.resolve('build/variants/'));

  if (variants.existsSync()) {
    variants.deleteSync(recursive: true);
  }

  variants.createSync(recursive: true);

  for (final key in text == null ? const <String>[] : readRegistry(text)) {
    final file = File.fromUri(variants.uri.resolve(fileOf(key)))..writeAsStringSync(sourceOf(key));
    manifest[key] = {'type': 'fragment', 'file': file.path};
  }

  return [
    fixed,
    for (final file in compileBundle(impellerc, manifest, bundle, includes: [shaders]))
      if (!file.absolute.path.startsWith(Directory.fromUri(root.resolve('build/')).path)) file.absolute.uri,
    impellerc.absolute.uri,
  ];
}
