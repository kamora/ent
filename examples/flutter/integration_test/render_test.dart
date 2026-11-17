// Runs inside the app on the device (macOS desktop or the iOS simulator): renders the demo scene through the
// real window's Flutter GPU context, checks pixels of the returned frame, then lets the widget run a few frames.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ent_example/main.dart';
import 'package:ent_flutter/ent_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo scene renders on the device', (tester) async {
    final renderer = await FlutterGpuRenderer.create();
    renderer
      ..setClearColor(0x202020)
      ..setSize(128, 128);
    final demo = DemoScene()..rotate(0.8);
    final image = renderer.render(demo.scene, demo.camera);
    final rgba = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;

    List<int> pixel(int x, int y) {
      final i = (y * 128 + x) * 4;
      return [rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2)];
    }

    // Evidence: the frame as a PNG in the app's temporary directory, and the sampled pixels.
    final png = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
    final file = File('${Directory.systemTemp.path}/ent_${Platform.operatingSystem}_frame.png')
      ..writeAsBytesSync(png.buffer.asUint8List());
    // ignore: avoid_print
    print(
      'frame ${image.width}x${image.height} saved to ${file.path}; pixels ${[pixel(2, 2), pixel(63, 20), pixel(64, 70)]}',
    );

    expect(pixel(2, 2), [0x20, 0x20, 0x20], reason: 'clear color');
    expect(pixel(63, 20), [0xff, 0x80, 0x00], reason: 'triangle apex above the cube');
    expect(pixel(64, 70)[2], greaterThan(150), reason: 'cube in front: a normal-material face, not the triangle');
    expect(renderer.info.render.calls, 2);

    await tester.pumpWidget(DemoApp(renderer: renderer, demo: demo));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(renderer.info.render.frame, greaterThan(1));
  });
}
