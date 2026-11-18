// Renderer parity with the reference frames under flutter_tester (Impeller on Vulkan through SwiftShader): the scenes
// and the comparison are in parity.dart, shared with examples/worm/integration_test/parity_metal_test.dart.

// flutter_tester builds a Metal pipeline for each new material state in up to ~16 s (an app does it in a few
// hundred milliseconds; docs/flutter-gpu.md, Pipeline compile cost), so a scene meeting several new states can
// take longer than package:test's default 30 s.
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'parity.dart';

void main() {
  declare(
    [
      for (final f in Directory('../../fixtures/rendering/reference').listSync().whereType<File>())
        if (f.path.endsWith('.json') && !f.path.endsWith('meta.json')) f.uri.pathSegments.last.replaceAll('.json', ''),
    ],
    (path) async => File('../../$path').readAsBytesSync(),
    skip: {...skipped, ...swiftShader},
    failures: Directory('../../fixtures/rendering/failures'),
  );
}
