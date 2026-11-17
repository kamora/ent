// Reference image of a small scene, compared per pixel with fixtures/rendering/flutter_gpu_scene.png.
// Regenerate with `flutter test --enable-impeller --enable-flutter-gpu --update-goldens test/golden_test.dart`;
// tolerance and platform metadata: docs/flutter-gpu.md and fixtures/rendering/flutter_gpu_scene.json.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

const int tolerance = 2;

// More than this many differing pixels fails; edges may round differently on another GPU.
const int maxDifferentPixels = 0;

void main() {
  test('golden: normal-material cube in front of a basic-material triangle', () async {
    final renderer = await FlutterGpuRenderer.create()
      ..setSize(128, 128)
      ..setClearColor(0x202020);
    final camera = PerspectiveCamera(50, 1, 0.1, 100)..position.set(0, 0.6, 3);
    camera.lookAt(Vector3());

    final cube = Mesh(BoxGeometry(1, 1, 1), MeshNormalMaterial())..rotation.set(0.4, math.pi / 5, 0);
    final triangle = Mesh(
      BufferGeometry()..setAttribute('position', Float32BufferAttribute([-1.2, -0.8, 0, 1.2, -0.8, 0, 0, 1.2, 0], 3)),
      MeshBasicMaterial({'color': 0xff8000}),
    )..position.z = -0.8;
    final scene = Scene()
      ..add(cube)
      ..add(triangle);

    final image = renderer.render(scene, camera);
    final actual = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final file = File('../../fixtures/rendering/flutter_gpu_scene.png');

    if (autoUpdateGoldenFiles || !file.existsSync()) {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      file.writeAsBytesSync(png.buffer.asUint8List());
    }

    final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
    final golden = (await codec.getNextFrame()).image;
    final expected = (await golden.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    expect([golden.width, golden.height], [image.width, image.height]);

    var different = 0;

    for (var i = 0; i < actual.lengthInBytes; i += 4) {
      for (var c = 0; c < 4; c++) {
        if ((actual.getUint8(i + c) - expected.getUint8(i + c)).abs() > tolerance) {
          different++;
          break;
        }
      }
    }

    expect(different, lessThanOrEqualTo(maxDifferentPixels));
    renderer.dispose();
  });
}
