// Compiles every variant of the test registry for Metal and checks that the shader uses every uniform block and
// sampler its reflection lists. impellerc drops what a stage declares but never reads while the reflection keeps it,
// so the renderer binds it out of range: Metal crashes (a bus error in setFragmentBuffer), SwiftShader does not, so
// the GPU tests under flutter test would not catch it. A dropped sampler also keeps binding 0 in the reflection, and
// a Vulkan descriptor layout that repeats a binding hung the Galaxy S10.

import 'dart:convert';
import 'dart:io';

import 'package:ent_shaders/ent_shaders.dart';
import 'package:flutter_gpu_shaders/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every registered variant uses each uniform block and sampler it declares (Metal)', () async {
    final impellerc = (await findImpellerC()).toFilePath();

    // ent_shaders' root, where pub resolved it: the variants include its shaders/.
    final config = json.decode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, Object?>;
    final package = (config['packages']! as List<Object?>).cast<Map<String, Object?>>().firstWhere(
      (p) => p['name'] == 'ent_shaders',
    );
    final root = Directory.current.uri.resolve('.dart_tool/').resolve('${package['rootUri']}/');
    final temp = Directory.systemTemp.createTempSync('ent_variants');
    final keys = readRegistry(File('test/ent_shaders.json').readAsStringSync());
    final problems = <String>[];

    try {
      for (var i = 0; i < keys.length; i += 8) {
        await Future.wait([
          for (final key in keys.skip(i).take(8))
            () async {
              final name = '${temp.path}/${fileOf(key).replaceAll('.frag', '')}';
              File('$name.frag').writeAsStringSync(sourceOf(key));
              final result = await Process.run(impellerc, [
                '--metal-desktop',
                '--input=$name.frag',
                '--input-type=frag',
                '--sl=$name.metal',
                '--spirv=$name.spv',
                '--reflection-json=$name.json',
                '--include=${root.toFilePath()}',
                '--include=${File(impellerc).parent.path}/shader_lib',
              ]);

              if (result.exitCode != 0) {
                problems.add('$key: does not compile: ${result.stderr}');
                return;
              }

              final reflection = json.decode(File('$name.json').readAsStringSync()) as Map<String, Object?>;
              final msl = File('$name.metal').readAsStringSync();
              final blocks = {for (final m in RegExp(r'constant (\w+)& ').allMatches(msl)) m[1]};
              final samplers = {for (final m in RegExp(r'texture\w*<float> (\w+) \[\[texture').allMatches(msl)) m[1]};

              for (final block in reflection['buffers'] as List<Object?>) {
                if (!blocks.contains((block as Map)['name'])) {
                  problems.add('$key: declares uniform block ${block['name']} but does not use it');
                }
              }

              for (final sampler in reflection['sampled_images'] as List<Object?>) {
                if (!samplers.contains((sampler as Map)['name'])) {
                  problems.add('$key: declares sampler ${sampler['name']} but does not use it');
                }
              }
            }(),
        ]);
      }
    } finally {
      temp.deleteSync(recursive: true);
    }

    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
