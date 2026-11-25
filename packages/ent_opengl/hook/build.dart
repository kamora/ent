// Compiles the shaders OpenGL ES draws with when an app is built: the fixed shaders of ent_shaders and the variants
// the app's registry lists (hooks: user_defines: ent_opengl: shaders:), keeping only their GLSL ES 3.00.

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
