// Compiles the shaders Flutter GPU draws with when an app is built: the fixed shaders of ent_shaders and the variants
// the app's registry lists (hooks: user_defines: ent_flutter: shaders:), keeping the backends Impeller runs on the
// target. macOS keeps Vulkan for flutter test, which runs Impeller on Vulkan through SwiftShader.

import 'package:code_assets/code_assets.dart';
import 'package:ent_impeller/ent_impeller.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await compileShaders(input, output, {
      OS.iOS: {'metal_ios'},
      OS.macOS: {'metal_desktop', 'vulkan'},
      OS.android: {'vulkan'},
    });
  });
}
