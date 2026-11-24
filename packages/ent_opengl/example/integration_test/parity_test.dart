// Renderer parity with the reference frames on a device, drawn by OpenGlRenderer: the system's OpenGL ES on Android,
// ANGLE on macOS. The scenes and the comparison are ent_flutter's test/parity.dart; the references reach the app as
// assets (integration_test/fixtures links to the repository's fixtures directory). The skipped scenes run too: one
// that fails is reported as skipped, with its numbers. A failing frame is saved to parity_failures in the app's
// temporary directory.
//
// flutter test integration_test/parity_test.dart -d <device>
// One scene or a few: add --dart-define=PARITY_ONLY=name,name.
// Other frames to compare with, such as the reference scenes drawn by another device's Chrome
// (tool/reference/render/render.mjs with REMOTE): add --dart-define=PARITY_REFERENCE=<asset folder> of <name>.png
// files; the scenes stay the fixtures'.

import 'dart:io';

import 'package:ent_opengl/ent_opengl.dart';
import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';

import '../../../ent_flutter/test/parity.dart';

const only = String.fromEnvironment('PARITY_ONLY');

const reference = String.fromEnvironment('PARITY_REFERENCE');

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final assets = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
  const frames = 'fixtures/rendering/reference/';
  const prefix = 'integration_test/$frames';

  declare(
    [
      for (final a in assets)
        if (a.startsWith(prefix) && a.endsWith('.json') && !a.endsWith('meta.json'))
          a.substring(prefix.length).replaceAll('.json', ''),
    ].where((name) => only.isEmpty || only.split(',').contains(name)),
    (path) async {
      final frame = reference.isNotEmpty && path.startsWith(frames) && path.endsWith('.png');
      final asset = frame ? '$reference/${path.substring(frames.length)}' : 'integration_test/$path';
      return Uint8List.fromList((await rootBundle.load(asset)).buffer.asUint8List());
    },
    measure: skipped,
    failures: Directory('${Directory.systemTemp.path}/parity_failures'),
    create: OpenGlRenderer.create,
    mipmapAllowances: false,
  );
}
