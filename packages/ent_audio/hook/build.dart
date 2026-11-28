import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Compiles miniaudio and ent_audio's own C into one library for the target platform.
void main(List<String> args) async {
  await build(args, (input, output) async {
    final os = input.config.code.targetOS;
    final apple = os == OS.macOS || os == OS.iOS;

    // On Apple platforms miniaudio is compiled as Objective-C (iOS needs it for its audio session), through a .m file
    // since clang takes the language from the extension, and links the audio frameworks instead of loading them at
    // run time.
    await CBuilder.library(
      name: 'ent_audio',
      assetName: 'src/bindings.dart',
      sources: [apple ? 'src/apple.m' : 'src/ent_audio.c'],
      defines: {if (apple) 'MA_NO_RUNTIME_LINKING': null},
      frameworks: [
        if (apple) ...['Foundation', 'CoreFoundation', 'CoreAudio', 'AudioToolbox'],
        if (os == OS.iOS) 'AVFoundation',
      ],
      libraries: [if (os == OS.android) 'm'],

      // No fused multiply-adds, which round differently from the separate operations Web Audio implementations use.
      flags: ['-ffp-contract=off'],
    ).run(input: input, output: output);
  });
}
