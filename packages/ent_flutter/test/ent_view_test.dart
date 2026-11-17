// Widget tests of EntView under `flutter test --enable-impeller --enable-flutter-gpu`: frames are pumped on the
// fake clock, and every tick renders with a real FlutterGpuRenderer.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

const tick = Duration(milliseconds: 16);

// A perspective camera at z = 3 that counts its projection updates, already prepared by a render (the first
// render of a camera updates its projection once).
class Counted extends PerspectiveCamera {
  Counted(FlutterGpuRenderer renderer) : super(50, 1, 0.1, 100) {
    position.z = 3;
    renderer.render(Scene(), this).dispose();
    updates = 0;
  }

  int updates = 0;

  @override
  void updateProjectionMatrix() {
    updates++;
    super.updateProjectionMatrix();
  }
}

// [child] at the top left of the view, [width] × [height] logical pixels.
Widget sized(double width, double height, Widget child) {
  return Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, height: height, child: child),
  );
}

ui.Image? shown(WidgetTester tester) => tester.widget<RawImage>(find.byType(RawImage)).image;

List<int> dims(ui.Image? image) => [image!.width, image.height];

List<double> buffer(FlutterGpuRenderer renderer) => renderer.getDrawingBufferSize(Vector2()).toArray();

Future<void> pumps(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(tick);
  }
}

void main() {
  late FlutterGpuRenderer renderer;

  setUp(() async {
    renderer = await FlutterGpuRenderer.create()
      ..setSize(64, 64)
      ..setClearColor(0x336699);
  });

  tearDown(() => renderer.dispose());

  void view(WidgetTester tester, double width, double height, [double ratio = 1]) {
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
  }

  testWidgets('a layout change sizes the renderer and the perspective camera once; rotation is a resize', (
    tester,
  ) async {
    view(tester, 200, 100);
    final camera = Counted(renderer);
    await tester.pumpWidget(EntView(renderer: renderer, scene: Scene(), camera: camera));
    await pumps(tester, 6);
    expect(camera.aspect, 2);
    expect(camera.updates, 1);
    expect(buffer(renderer), [200, 100]);
    expect(dims(shown(tester)), [200, 100]);

    // The view's size swaps, as when a phone turns.
    tester.view.physicalSize = const Size(100, 200);
    await pumps(tester, 2);
    expect(camera.aspect, 0.5);
    expect(camera.updates, 2);
    expect(buffer(renderer), [100, 200]);
    expect(dims(shown(tester)), [100, 200]);
  });

  testWidgets('an empty layout renders nothing and leaves the camera alone', (tester) async {
    view(tester, 200, 100);
    final camera = Counted(renderer);
    final frames = renderer.info.render.frame;
    await tester.pumpWidget(sized(0, 50, EntView(renderer: renderer, scene: Scene(), camera: camera)));
    await pumps(tester, 3);
    expect(renderer.info.render.frame, frames);
    expect(camera.aspect, 1);
    expect(camera.updates, 0);

    await tester.pumpWidget(sized(50, 50, EntView(renderer: renderer, scene: Scene(), camera: camera)));
    await pumps(tester, 2);
    expect(renderer.info.render.frame, greaterThan(frames));
    expect(camera.updates, 1);
  });

  testWidgets('an OrthographicCamera is left to the app', (tester) async {
    view(tester, 200, 100);
    final camera = OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
    renderer.render(Scene(), camera).dispose();
    final projection = List.of(camera.projectionMatrix.elements);
    await tester.pumpWidget(EntView(renderer: renderer, scene: Scene(), camera: camera));
    await pumps(tester, 2);
    expect([camera.left, camera.right], [-1, 1]);
    expect(camera.projectionMatrix.elements, projection);
    expect(buffer(renderer), [200, 100]);
  });

  testWidgets('the device pixel ratio sizes the drawing buffer and a change re-sizes it', (tester) async {
    view(tester, 300, 150, 1.5);
    final camera = Counted(renderer);
    await tester.pumpWidget(EntView(renderer: renderer, scene: Scene(), camera: camera));
    await pumps(tester, 2);
    expect(renderer.getPixelRatio(), 1.5);
    expect(buffer(renderer), [300, 150]);
    expect(dims(shown(tester)), [300, 150]);

    // The window moves to a screen with another ratio; the logical size stays 200 × 100.
    tester.view
      ..physicalSize = const Size(600, 300)
      ..devicePixelRatio = 3;
    await pumps(tester, 2);
    expect(renderer.getPixelRatio(), 3);
    expect(buffer(renderer), [600, 300]);
    expect(dims(shown(tester)), [600, 300]);
    expect(camera.aspect, 2);
  });

  testWidgets('the frame is shown at one image pixel per physical pixel', (tester) async {
    view(tester, 150, 96, 1.5);
    final scene = Scene();

    for (var i = 0; i < 8; i++) {
      scene.add(
        Mesh(PlaneGeometry(0.1, 3), MeshBasicMaterial({'color': 0xffffff}))
          ..position.x = i * 0.25 - 0.9
          ..rotation.z = 0.7,
      );
    }

    // 67 × 40.3 logical pixels are 100.5 × 60.45 physical ones: the image has 100 × 60, so stretching it to the
    // box would resample it.
    final key = GlobalKey();
    await tester.pumpWidget(
      sized(
        67,
        40.3,
        RepaintBoundary(
          key: key,
          child: EntView(
            renderer: renderer,
            scene: scene,
            camera: OrthographicCamera(-1, 1, 1, -1, 0.1, 10)..position.set(0, 0, 5),
          ),
        ),
      ),
    );
    await pumps(tester, 2);
    final image = shown(tester)!;
    expect(dims(image), [100, 60]);
    final (frame, shot, width) = (await tester.runAsync(() async {
      final shot = await tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage(pixelRatio: 1.5);
      return ((await image.toByteData())!, (await shot.toByteData())!, shot.width);
    }))!;
    var edges = 0;
    var wrong = 0;

    for (var y = 0; y < 60; y++) {
      for (var x = 0; x < 100; x++) {
        final a = frame.getUint32((y * 100 + x) * 4);

        if (x > 0 && a != frame.getUint32((y * 100 + x - 1) * 4)) {
          edges++;
        }

        if (a != shot.getUint32((y * width + x) * 4)) {
          wrong++;
        }
      }
    }

    expect(edges, greaterThan(100));
    expect(wrong, 0);
  });

  testWidgets('each frame image is disposed once, without leaks over 300 frames; none after dispose', (tester) async {
    view(tester, 64, 64);
    var live = 0;
    final (create, dispose) = (ui.Image.onCreate, ui.Image.onDispose);
    ui.Image.onCreate = (image) {
      live++;
      create?.call(image);
    };
    ui.Image.onDispose = (image) {
      live--;
      dispose?.call(image);
    };
    addTearDown(() {
      ui.Image.onCreate = create;
      ui.Image.onDispose = dispose;
    });

    await tester.pumpWidget(
      EntView(
        renderer: renderer,
        scene: Scene()..add(Mesh(PlaneGeometry(1, 1), MeshBasicMaterial())),
        camera: Counted(renderer),
      ),
    );
    await pumps(tester, 10);
    final images = <ui.Image>[];
    final handles = live;
    final memory = [renderer.info.memory.geometries, renderer.info.memory.textures];

    for (var i = 0; i < 300; i++) {
      await tester.pump(tick);
      images.add(shown(tester)!);
    }

    // The view's handle and RawImage's clone of the shown frame.
    expect(handles, 2);
    expect(live, handles);
    expect(images.toSet().length, 300);
    expect(images.where((image) => image.debugDisposed).length, 299);
    expect([renderer.info.memory.geometries, renderer.info.memory.textures], memory);

    // The frame that removes the view ticks before the rebuild that disposes it.
    await tester.pumpWidget(const SizedBox());
    final frames = renderer.info.render.frame;
    await pumps(tester, 5);
    expect(images.last.debugDisposed, isTrue);
    expect(live, 0);
    expect(renderer.info.render.frame, frames);

    // The renderer is the app's: still holding the plane's buffers.
    expect(renderer.info.memory.geometries, 1);
  });

  testWidgets('a new renderer, camera or scene is used from the next frame', (tester) async {
    view(tester, 200, 100);
    await tester.pumpWidget(EntView(renderer: renderer, scene: Scene(), camera: Counted(renderer)));
    await pumps(tester, 2);

    final second = Counted(renderer);
    await tester.pumpWidget(EntView(renderer: renderer, scene: Scene(), camera: second));
    await pumps(tester, 2);
    expect(second.aspect, 2);
    expect(second.updates, 1);

    final other = (await tester.runAsync(FlutterGpuRenderer.create))!;
    addTearDown(other.dispose);
    await tester.pumpWidget(
      EntView(renderer: other, scene: Scene()..add(Mesh(PlaneGeometry(1, 1), MeshBasicMaterial())), camera: second),
    );
    final frames = renderer.info.render.frame;
    await pumps(tester, 2);
    expect(buffer(other), [200, 100]);
    expect(other.info.render.calls, 1);
    expect(renderer.info.render.frame, frames);
  });

  testWidgets('no renders while the app is paused or hidden; the elapsed time keeps running', (tester) async {
    view(tester, 64, 64);
    final times = <Duration>[];
    await tester.pumpWidget(EntView(renderer: renderer, scene: Scene(), camera: Counted(renderer), onFrame: times.add));
    await pumps(tester, 2);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    for (final state in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      final frames = renderer.info.render.frame;
      final count = times.length;
      tester.binding.handleAppLifecycleStateChanged(state);
      await pumps(tester, 10);
      expect(renderer.info.render.frame, frames, reason: '$state');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumps(tester, 1);
      expect(renderer.info.render.frame, frames + 1, reason: '$state');
      expect(times.length, count + 1);
      expect(times.last - times[count - 1], greaterThan(tick * 10));
    }
  });

  testWidgets('no renders while muted by TickerMode or covered by another route', (tester) async {
    view(tester, 64, 64);
    final camera = Counted(renderer);
    Widget muted(bool enabled) {
      return TickerMode(
        enabled: enabled,
        child: EntView(renderer: renderer, scene: Scene(), camera: camera),
      );
    }

    await tester.pumpWidget(muted(false));
    await pumps(tester, 3);
    final frames = renderer.info.render.frame;
    expect(camera.updates, 1);
    await tester.pumpWidget(muted(true));
    await pumps(tester, 2);
    expect(renderer.info.render.frame, frames + 2);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Navigator(
          key: navigator,
          onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => muted(true)),
        ),
      ),
    );
    await pumps(tester, 2);
    navigator.currentState!.push(
      PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox(), transitionDuration: Duration.zero),
    );
    await pumps(tester, 2);
    final covered = renderer.info.render.frame;
    await pumps(tester, 5);
    expect(renderer.info.render.frame, covered);

    navigator.currentState!.pop();
    await pumps(tester, 30);
    expect(renderer.info.render.frame, greaterThan(covered));
  });

  testWidgets('a frame slower than a tick renders once per tick', (tester) async {
    view(tester, 64, 64);
    final counts = <int>[];
    await tester.pumpWidget(
      EntView(
        renderer: renderer,
        scene: Scene(),
        camera: Counted(renderer),
        onFrame: (_) {
          counts.add(renderer.info.render.frame);
          final watch = Stopwatch()..start();

          while (watch.elapsed < tick * 2) {}
        },
      ),
    );
    await pumps(tester, 6);
    expect(counts.length, 6);

    for (var i = 1; i < counts.length; i++) {
      expect(counts[i], counts[i - 1] + 1);
    }
  });
}
