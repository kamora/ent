// The animation loop in EntView under `flutter test --enable-impeller --enable-flutter-gpu`: `onFrame` updates a Timer
// and advances an AnimationMixer by its delta, as the reference's apps do. The core's time source (`performanceNow`)
// reads the test's fake clock, so the deltas are the pumped frame times.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

const tick = Duration(milliseconds: 16);

void main() {
  late FlutterGpuRenderer renderer;

  setUp(() async {
    renderer = await FlutterGpuRenderer.create();
  });

  tearDown(() => renderer.dispose());

  testWidgets('anim_loop: the mixer advances by the ticker deltas, stops while muted and catches up on resume', (
    tester,
  ) async {
    final now = performanceNow;
    performanceNow = () => tester.binding.clock.now().microsecondsSinceEpoch / 1000;
    addTearDown(() => performanceNow = now);
    tester.view
      ..physicalSize = const Size(64, 64)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // A quad moving from x = 0 to 1 in a second, repeating.
    final mesh = Mesh(PlaneGeometry(0.2, 0.2), MeshBasicMaterial());
    final scene = Scene()..add(mesh);
    final camera = PerspectiveCamera(50, 1, 0.1, 100)..position.z = 3;
    final mixer = AnimationMixer(scene);
    final timer = Timer();
    final clip = AnimationClip('move', -1, [
      VectorKeyframeTrack('.position', [0, 1], [0, 0, 0, 1, 0, 0]),
    ]);
    mixer.clipAction(clip, mesh)!.play();

    // Per frame: the ticker's elapsed time and the mixer's time after the update.
    final frames = <(Duration, double)>[];

    Widget view(bool enabled) {
      return TickerMode(
        enabled: enabled,
        child: EntView(
          renderer: renderer,
          scene: scene,
          camera: camera,
          onFrame: (elapsed) {
            timer.update();
            mixer.update(timer.getDelta());
            frames.add((elapsed, mixer.time));
          },
        ),
      );
    }

    await tester.pumpWidget(view(true));

    for (var i = 0; i < 10; i++) {
      await tester.pump(tick);
    }

    expect(frames.length, greaterThanOrEqualTo(9));

    // Every frame after the first advances the mixer by the ticker's delta.
    for (var i = 1; i < frames.length; i++) {
      final step = (frames[i].$1 - frames[i - 1].$1).inMicroseconds / 1e6;
      expect(frames[i].$2 - frames[i - 1].$2, closeTo(step, 1e-9));
    }

    // The clip is applied: x is the action's time, which LoopRepeat keeps in [0, 1).
    expect(mesh.position.x, closeTo(mixer.time % 1, 1e-6));

    // Muted (a covered route, an inactive tab): no frame, so the mixer stands still.
    await tester.pumpWidget(view(false));
    final count = frames.length;
    final time = mixer.time;

    for (var i = 0; i < 30; i++) {
      await tester.pump(tick);
    }

    expect(frames.length, count);
    expect(mixer.time, time);

    // On resume the first delta spans the pause (about half a second), as the reference's Clock or an unconnected Timer
    // gives after a hidden browser tab, and the ticker's elapsed time has kept running by the same amount.
    await tester.pumpWidget(view(true));
    await tester.pump(tick);
    await tester.pump(tick);
    expect(frames.length, greaterThan(count));

    final jump = frames[count].$2 - time;
    expect(jump, closeTo((frames[count].$1 - frames[count - 1].$1).inMicroseconds / 1e6, 1e-9));
    expect(jump, greaterThan(0.45));
    expect(mesh.position.x, closeTo(mixer.time % 1, 1e-6));
  });
}
