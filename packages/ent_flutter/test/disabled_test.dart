// When Flutter GPU is not enabled, FlutterGpuRenderer.create names the switch instead of failing later.
// Checked by running without the flag: `flutter test --enable-impeller test/disabled_test.dart`; under
// --enable-flutter-gpu the test is skipped.

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

bool get enabled {
  try {
    gpu.gpuContext.defaultColorFormat;
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  test('create names the Flutter GPU switch when it is off', () async {
    await expectLater(
      FlutterGpuRenderer.create(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('Flutter GPU is not enabled'), contains('FLTEnableFlutterGPU'), contains('EnableFlutterGPU')),
        ),
      ),
    );
  }, skip: enabled ? 'Flutter GPU is enabled in this run' : false);
}
