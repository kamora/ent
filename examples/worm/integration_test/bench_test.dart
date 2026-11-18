// The CPU benchmark (lib/bench.dart) in a profile build. Each point warms up for 1 s, then measures 2 s of frames:
// the ticker's frame interval, scene.updateMatrixWorld and renderer.render on the UI thread, FrameTiming's build and
// raster times, and afterwards RenderList.build (projectObject and sorting) run 30 times back to back. Every point
// runs twice. With --dart-define=BENCH=profile it runs only N = 1000 meshes and shadowed for 3 s each and reports
// the windows, so test_driver/bench.dart reads the CPU samples taken in them.
//
// flutter drive --profile -d <device> --driver=test_driver/bench.dart --target=integration_test/bench_test.dart

import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ent_example/bench.dart';
import 'package:ent_flutter/ent_flutter.dart';
import 'package:ent_flutter/src/render_list.dart';

const profiling = String.fromEnvironment('BENCH') == 'profile';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FlutterPlatform.install);

  testWidgets('CPU cost per frame against object count', (tester) async {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final renderer = await FlutterGpuRenderer.create()
      ..setPixelRatio(tester.view.devicePixelRatio)
      ..setSize(400, 400);
    final points = <Map<String, Object>>[];
    final windows = <Map<String, Object>>[];
    final timings = <ui.FrameTiming>[];
    SchedulerBinding.instance.addTimingsCallback(timings.addAll);
    final cases = profiling ? [Case.meshes, Case.shadowed] : Case.values;

    for (final n in profiling ? [1000] : [1, 10, 100, 500, 1000, 2000]) {
      for (final kind in cases) {
        for (var run = 0; run < (profiling ? 1 : 2); run++) {
          final bench = Bench(kind, n)..setUp(renderer);
          final frames = <List<int>>[];
          await tester.runAsync(() => renderer.compileAsync(bench.scene, bench.camera));
          final view = GlobalKey<_BenchViewState>();
          await tester.pumpWidget(
            Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: _BenchView(key: view, bench: bench, renderer: renderer),
              ),
            ),
          );
          await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
          timings.clear();
          view.currentState!.frames = frames;
          final start = Timeline.now;
          await tester.runAsync(() => Future<void>.delayed(Duration(seconds: profiling ? 3 : 2)));
          view.currentState!.stop();
          final end = Timeline.now;
          expect(renderer.info.render.calls, bench.calls, reason: '${kind.name} $n: draw calls of the last frame');

          if (bench.instanced case final mesh?) {
            expect(
              mesh.instanceMatrix.version,
              greaterThanOrEqualTo(frames.length),
              reason: '${kind.name} $n: the instance matrices are uploaded every frame',
            );
          }

          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
          await tester.pumpWidget(const SizedBox());

          // projectObject and sorting alone, as render does it first.
          final list = RenderList();
          final watch = Stopwatch()..start();

          for (var i = 0; i < 30; i++) {
            list.build(bench.scene, bench.camera);
          }

          double mean(Iterable<num> values) =>
              values.isEmpty ? 0 : values.fold<num>(0, (a, b) => a + b) / values.length;
          final intervals = [for (var i = 1; i < frames.length; i++) frames[i][0] - frames[i - 1][0]];
          final point = {
            'case': kind.name,
            'n': n,
            'run': run,
            'frames': frames.length,
            'interval': mean(intervals) / 1000,
            'slow': intervals.where((us) => us > 20000).length,
            'turn': mean(frames.map((f) => f[1])) / 1000,
            'update': mean(frames.map((f) => f[2])) / 1000,
            'render': mean(frames.map((f) => f[3])) / 1000,
            'list': watch.elapsedMicroseconds / 30 / 1000,
            'build': mean(timings.map((t) => t.buildDuration.inMicroseconds)) / 1000,
            'raster': mean(timings.map((t) => t.rasterDuration.inMicroseconds)) / 1000,
            'calls': renderer.info.render.calls,
          };
          points.add(point);
          windows.add({'case': kind.name, 'n': n, 'start': start, 'end': end});

          // ignore: avoid_print
          print('bench $point');
        }
      }
    }

    binding.reportData = {'points': points, 'windows': windows};
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// Shows [bench] through [renderer], turning it every frame while running; [frames] collects, per frame, the
/// ticker time and the microseconds of turning, scene.updateMatrixWorld and render.
class _BenchView extends StatefulWidget {
  const _BenchView({super.key, required this.bench, required this.renderer});

  final Bench bench;

  final FlutterGpuRenderer renderer;

  @override
  State<_BenchView> createState() => _BenchViewState();
}

class _BenchViewState extends State<_BenchView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  ui.Image? _image;

  List<List<int>>? frames;

  final Stopwatch _watch = Stopwatch()..start();

  void stop() {
    _ticker.stop();
  }

  void _tick(Duration elapsed) {
    final bench = widget.bench;
    final t0 = _watch.elapsedMicroseconds;
    bench.turn(elapsed.inMicroseconds / 1e6);
    final t1 = _watch.elapsedMicroseconds;
    bench.scene.updateMatrixWorld();
    final t2 = _watch.elapsedMicroseconds;
    final image = widget.renderer.render(bench.scene, bench.camera);
    frames?.add([elapsed.inMicroseconds, t1 - t0, t2 - t1, _watch.elapsedMicroseconds - t2]);
    setState(() {
      _image?.dispose();
      _image = image;
    });
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawImage(image: _image, width: 400, height: 400, filterQuality: FilterQuality.none);
  }
}
