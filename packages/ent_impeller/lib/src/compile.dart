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
/// (`hooks: user_defines: <package>: shaders:`), keeping only [backends] of the target. A target missing from
/// [backends] keeps every backend.
Future<void> compileShaders(BuildInput input, BuildOutputBuilder output, Map<OS, Set<String>> backends) async {
  final root = input.packageRoot;

  // Every build of the package, from any app using it (by path, or through one pub cache), rewrites build/variants/
  // and the one bundle: they take turns, or one wipes the sources another is still compiling. Closing the file
  // releases the lock, and so does the process ending.
  final lock = await (File.fromUri(
    root.resolve('build/variants.lock'),
  )..createSync(recursive: true)).open(mode: FileMode.append);
  await lock.lock(FileLock.blockingExclusive);

  try {
    final shaders = (await Isolate.resolvePackageUri(Uri.parse('package:ent_shaders/')))!.resolve('../');
    final fixed = shaders.resolve('ent.shaderbundle.json');
    final manifest = {
      for (final MapEntry(:key, :value) in (json.decode(File.fromUri(fixed).readAsStringSync()) as Map).entries)
        key as String: {...value as Map, 'file': shaders.resolve(value['file'] as String).toFilePath()},
    };
    final registry = input.userDefines.path('shaders');
    final variants = Directory.fromUri(root.resolve('build/variants/'));

    if (variants.existsSync()) {
      variants.deleteSync(recursive: true);
    }

    variants.createSync(recursive: true);
    output.dependencies.add(fixed);

    if (registry != null) {
      output.dependencies.add(registry);

      for (final key in readRegistry(File.fromUri(registry).readAsStringSync())) {
        final file = File.fromUri(variants.uri.resolve(fileOf(key)))..writeAsStringSync(sourceOf(key));
        manifest[key] = {'type': 'fragment', 'file': file.path};
      }
    }

    final impellerc = findImpellerc();
    final bundle = File.fromUri(root.resolve('build/shaderbundles/ent.shaderbundle'))..parent.createSync();
    final read = compileBundle(impellerc, manifest, bundle, includes: [shaders]);

    // The variants are written again on every build: depending on them would rerun the hook every time; their
    // registry stands for them. The compiler is an input too, so a new Flutter recompiles.
    output.dependencies.addAll([
      for (final file in read)
        if (!file.absolute.path.startsWith(Directory.fromUri(root.resolve('build/')).path)) file.absolute.uri,
      impellerc.absolute.uri,
    ]);

    // The target and its backends: a target missing from [backends] (Linux, Windows) keeps all.
    final target = input.config.buildCodeAssets ? input.config.code.targetOS : null;
    final kept = backends[target];

    if (kept != null) {
      bundle.writeAsBytesSync(strip(bundle.readAsBytesSync(), kept));
    }

    // Every target and registry writes this one bundle, so another build may have replaced it. The stamp says whose
    // it is: as an input of this build, a stamp another build rewrote reruns this hook. Backdated: a hook runner
    // reruns a hook whose input is dated after it started the hook.
    output.dependencies.add(
      (File.fromUri(root.resolve('build/shaderbundles/ent.shaderbundle.owner'))
            ..writeAsStringSync('${target?.name} $registry ${impellerc.path}\n')
            ..setLastModifiedSync(DateTime.utc(2000)))
          .uri,
    );
  } finally {
    await lock.close();
  }
}
