// Compiles the renderer's shaders into build/shaderbundles/ent.shaderbundle with impellerc: the fixed ones in
// ent.shaderbundle.json, plus the variants the app's registry lists (hooks: user_defines: ent_flutter: shaders:);
// then keeps only the GPU backends the target runs.

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:ent_flutter/src/gpu/bundles.dart';
import 'package:ent_flutter/src/gpu/variants.dart';
import 'package:flutter_gpu_shaders/build.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final root = input.packageRoot;
    final fixed = root.resolve('ent.shaderbundle.json');
    final manifest = json.decode(File.fromUri(fixed).readAsStringSync()) as Map<String, Object?>;
    final registry = input.userDefines.path('shaders');
    final directory = Directory.fromUri(root.resolve('build/variants/'));

    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }

    directory.createSync(recursive: true);
    output.dependencies.add(fixed);

    if (registry != null) {
      output.dependencies.add(registry);

      for (final key in readRegistry(File.fromUri(registry).readAsStringSync())) {
        final file = 'build/variants/${fileOf(key)}';
        File.fromUri(root.resolve(file)).writeAsStringSync(sourceOf(key));
        manifest[key] = {'type': 'fragment', 'file': file};
      }
    }

    File.fromUri(directory.uri.resolve('ent.shaderbundle.json'))
        .writeAsStringSync(const JsonEncoder.withIndent('\t').convert(manifest));
    final bundle = File.fromUri(
      (await buildShaderBundleJson(
        buildInput: input,
        buildOutput: output,
        manifestFileName: 'build/variants/ent.shaderbundle.json',
        includeDirectories: [root],
      )).outputFile,
    );

    // macOS keeps Vulkan for flutter test (flutter_tester runs Impeller on Vulkan); a target not listed (Linux,
    // Windows) keeps all: neither is supported, and on Linux flutter_tester still reads Vulkan.
    final target = input.config.buildCodeAssets ? input.config.code.targetOS : null;
    final kept = switch (target) {
      OS.iOS => {'metal_ios'},
      OS.macOS => {'metal_desktop', 'vulkan'},
      OS.android => {'vulkan'},
      _ => null,
    };

    if (kept != null) {
      bundle.writeAsBytesSync(strip(bundle.readAsBytesSync(), kept));
    }

    // Every target and registry writes this one bundle, so another build may have replaced it. The stamp says whose it
    // is: as an input of this build, a stamp another build rewrote reruns this hook. Backdated, as flutter_gpu_shaders
    // backdates its own: a hook runner reruns a hook whose input is dated after it started the hook.
    output.dependencies.add(
      (File.fromUri(root.resolve('build/shaderbundles/ent.shaderbundle.owner'))
            ..writeAsStringSync('${target?.name} $registry\n')
            ..setLastModifiedSync(DateTime.utc(2000)))
          .uri,
    );
  });
}
