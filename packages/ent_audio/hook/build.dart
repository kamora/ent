import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Compiles miniaudio and ent_audio's own C into one library for the target platform.
void main(List<String> args) async {
  await build(args, (input, output) async {
    final os = input.config.code.targetOS;
    final apple = os == OS.macOS || os == OS.iOS;

    // On Apple platforms miniaudio is compiled as Objective-C (iOS needs it for its audio session) and links the
    // audio frameworks instead of loading them at run time.
    await CBuilder.library(
      name: 'ent_audio',
      assetName: 'src/bindings.dart',
      sources: ['src/ent_audio.c'],
      language: apple ? Language.objectiveC : Language.c,
      defines: {if (apple) 'MA_NO_RUNTIME_LINKING': null},
      frameworks: [
        if (apple) ...['CoreFoundation', 'CoreAudio', 'AudioToolbox'],
        if (os == OS.iOS) 'AVFoundation',
      ],
      libraries: [if (os == OS.android) 'm'],
    ).run(input: input, output: output);
  });
}
