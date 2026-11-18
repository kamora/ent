// Runs the getting-started example (lib/getting_started.dart) inside the app: the lit cube in front of the
// background, and a tap that hits the cube changing its color while a tap beside it does not.
//
// flutter test integration_test/getting_started_test.dart -d macos --enable-flutter-gpu

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ent_example/getting_started.dart';
import 'package:ent_flutter/ent_flutter.dart';

const size = 200;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the getting-started cube is lit, and a tap on it changes its color', (tester) async {
    final renderer = await FlutterGpuRenderer.create();
    final demo = GettingStarted();
    renderer.setSize(size.toDouble(), size.toDouble());

    // The pixel at (x, y) of a fresh frame, as RGB.
    Future<List<int>> pixel(int x, int y) async {
      final image = renderer.render(demo.scene, demo.camera);
      await tester.runAsync(renderer.idle);
      final rgba = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      image.dispose();
      final i = (y * size + x) * 4;
      return [rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2)];
    }

    demo.frame(const Duration(milliseconds: 500));
    final green = await pixel(size ~/ 2, size ~/ 2);

    // ignore: avoid_print
    print('cube $green, corner ${await pixel(2, 2)}');
    expect(await pixel(2, 2), [32, 32, 32], reason: 'the background, 0x202020');
    expect(green[1], greaterThan(green[0] + 40), reason: 'the cube is green: $green');
    expect(green[1], greaterThan(green[2]), reason: 'the cube is green: $green');
    expect(green[1], greaterThan(90), reason: 'the directional light reaches the face: $green');

    // The top face, at (100, 80), faces the light above.
    final top = await pixel(size ~/ 2, 80);
    expect(top[1], greaterThan(green[1]), reason: 'the light from above reaches the top face: $top');

    // A tap beside the cube changes nothing; a tap on it makes it red.
    demo.tap(Vector2(0.9, 0.9));
    expect(await pixel(size ~/ 2, size ~/ 2), green);
    demo.tap(Vector2(0, 0));
    final red = await pixel(size ~/ 2, size ~/ 2);
    expect(red[0], greaterThan(red[1] + 40), reason: 'the cube is red after the tap: $red');
  });
}
