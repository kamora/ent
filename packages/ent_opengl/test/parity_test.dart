// Renderer parity with the reference frames on OpenGL ES (ANGLE on Metal): the scenes and the comparison of
// ent_flutter's test/parity.dart, drawn by OpenGlRenderer. ANGLE is bundled for macOS only.
@TestOn('mac-os')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:ent_opengl/ent_opengl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ent_flutter/test/parity.dart';

void main() {
  // The renderer loads the shader bundle through rootBundle, as an app does.
  TestWidgetsFlutterBinding.ensureInitialized();
  declare(
    [
      for (final f in Directory('../../fixtures/rendering/reference').listSync().whereType<File>())
        if (f.path.endsWith('.json') && !f.path.endsWith('meta.json')) f.uri.pathSegments.last.replaceAll('.json', ''),
    ],
    (path) async => File('../../$path').readAsBytesSync(),
    skip: skipped,
    failures: Directory('build/parity_failures'),
    create: OpenGlRenderer.create,
    mipmapAllowances: false,
  );
}
