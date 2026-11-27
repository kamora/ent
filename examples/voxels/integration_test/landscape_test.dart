import 'dart:io';
import 'dart:ui' as ui;

import 'package:ent_flutter/ent_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voxels/main.dart';

// Drives the landscape as the app does, without widgets: frames, a click that blasts, a drag that does not. Frames
// are written as PNGs to the app's temporary directory (FRAMES=1) for looking at.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a click blasts a crater and debris flies; a drag only turns the view', (tester) async {
    await tester.runAsync(() async {
      final landscape = Landscape(await FlutterGpuRenderer.create(antialias: true));
      final input = landscape.game.input;
      landscape.renderer.setSize(800, 500);
      landscape.camera
        ..aspect = 800 / 500
        ..updateProjectionMatrix();

      var time = Duration.zero;

      Future<void> frames(int count, [String? name]) async {
        for (var k = 0; k < count; k++) {
          time += const Duration(microseconds: 16667);
          landscape.game.frame(time);
        }

        final image = landscape.renderer.render(landscape.scene, landscape.camera);

        if (name != null) {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          File('${Directory.systemTemp.path}/$name.png').writeAsBytesSync(png.buffer.asUint8List());
        }
      }

      await frames(2, 'before');
      final chunks = landscape.world.chunkCount;

      // A drag: down at one place, up at another. The view turns; nothing is blasted.
      input
        ..move('PointerX', -0.3)
        ..move('PointerY', -0.2)
        ..press('Pointer');
      await frames(1);
      input
        ..move('PointerX', 0.1)
        ..release('Pointer');
      await frames(1);
      expect(landscape.debris.count, 0);

      // A click near the middle of the view.
      input
        ..move('PointerX', 0.05)
        ..move('PointerY', -0.1)
        ..press('Pointer');
      await frames(1);
      input.release('Pointer');
      await frames(1);
      expect(landscape.debris.count, greaterThan(50));

      // The crater reaches the bottom layer here; every column keeps its bedrock.
      for (var x = 0; x < Landscape.size; x++) {
        for (var z = 0; z < Landscape.size; z++) {
          expect(landscape.world.getVoxel(x, 0, z), isNot(0), reason: 'bedrock at ($x, $z)');
        }
      }

      await frames(12, 'flying');
      await frames(240, 'after');
      expect(landscape.debris.count, 0, reason: 'gone after their lifetime');
      expect(landscape.world.chunkCount, chunks);
      expect(landscape.world.dirtyChunks, 0);

      landscape.dispose();
    });

    // ignore: avoid_print
    print('frames: ${Directory.systemTemp.path}');
  });
}
