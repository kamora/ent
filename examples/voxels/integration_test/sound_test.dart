import 'package:ent_audio/ent_audio.dart';
import 'package:ent_flutter/ent_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voxels/main.dart';

// The blast's sound inside the app, on its output device, at a master volume of 0 so the test is silent: the device
// context opens in the sandboxed app, a blast plays a PositionalAudio where it lands, and it is gone once played.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a blast plays its sound where it lands', (tester) async {
    await tester.runAsync(() async {
      NativeAudioContext.install();

      final landscape = Landscape(await FlutterGpuRenderer.create(antialias: true));
      final blasts = landscape.blasts!;
      final context = blasts.listener.context as NativeAudioContext;

      blasts.listener.setMasterVolume(0);
      landscape.world.updateMatrixWorld();

      final start = context.currentTime;
      final voxels = landscape.blast(Vector2(0, -0.3));
      final sounds = landscape.world.children.whereType<PositionalAudio>().toList();

      expect(context.playing, isTrue);
      expect(voxels, greaterThan(0));
      expect(sounds, hasLength(1));
      expect(sounds.single.isPlaying, isTrue);

      var time = Duration.zero;

      for (var k = 0; k < 120; k++) {
        time += const Duration(microseconds: 16667);
        landscape.game.frame(time);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      expect(context.currentTime - start, greaterThan(1.5));
      expect(sounds.single.isPlaying, isFalse);
      expect(landscape.world.children.whereType<PositionalAudio>(), isEmpty);

      context.close();
    });
  });
}
