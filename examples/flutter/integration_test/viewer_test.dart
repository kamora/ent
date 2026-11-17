// Runs the example viewer (lib/viewer.dart) inside the app on macOS: loads assets/worm.glb, then checks the skin
// and clip, that compileAsync finished before anything rendered, two animation times, the shadow on the ground,
// a mouse drag through OrbitControls and the frame loop driving the mixer.
//
// flutter test integration_test/viewer_test.dart -d macos --enable-flutter-gpu

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ent_example/viewer.dart';
import 'package:ent_flutter/ent_flutter.dart';

const size = 200;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FlutterPlatform.install);

  testWidgets('the viewer loads, warms, animates, casts a shadow and orbits', (tester) async {
    final viewer = Viewer(await FlutterGpuRenderer.create());
    final renderer = viewer.renderer;
    final data = (await tester.runAsync(() => rootBundle.load('assets/worm.glb')))!.buffer;
    final watch = Stopwatch()..start();
    await tester.runAsync(() => viewer.load(data));
    final load = watch.elapsedMilliseconds;
    watch.reset();
    await tester.runAsync(() => GLTFLoader().parseAsync(data));

    // ignore: avoid_print
    print('rough, cold: load $load ms (parse + compileAsync), parse alone ${watch.elapsedMilliseconds} ms');

    // The asset: a skinned, textured body with five bones and the 2 s `wiggle` clip.
    final gltf = viewer.gltf!;
    final body = gltf.scene!.getObjectByName('Body')! as SkinnedMesh;
    expect(body.skeleton!.bones.map((bone) => bone.name), ['Bone0', 'Bone1', 'Bone2', 'Bone3', 'Bone4']);
    expect((body.material! as MeshStandardMaterial).map, isNotNull);
    expect(gltf.animations.map((clip) => clip.name), ['wiggle']);
    expect(gltf.animations.single.duration, closeTo(2, 1e-6));
    expect(viewer.compiled, isTrue);
    expect(renderer.info.render.frame, 0, reason: 'compileAsync completed before the first rendered frame');

    renderer.setSize(size.toDouble(), size.toDouble());
    viewer.camera
      ..aspect = 1
      ..updateProjectionMatrix();

    Future<ByteData> shot(double time, [String? name]) async {
      viewer.mixer.setTime(time);
      final image = renderer.render(viewer.scene, viewer.camera);

      if (name != null) {
        final path = '${Directory.systemTemp.path}/$name.png';
        File(path).writeAsBytesSync(
          (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!.buffer.asUint8List(),
        );
        // ignore: avoid_print
        print('viewer frame saved to $path');
      }

      final rgba = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      image.dispose();
      return rgba;
    }

    final a = await shot(0, 'ent_viewer_0');
    final b = await shot(0.5);
    var changed = 0;

    for (var i = 0; i < size * size; i++) {
      if ([0, 1, 2].any((c) => (a.getUint8(i * 4 + c) - b.getUint8(i * 4 + c)).abs() > 8)) {
        changed++;
      }
    }

    // ignore: avoid_print
    print('pixels changed between 0 s and 0.5 s: $changed');
    expect(changed, greaterThan(200), reason: 'the worm bends between the two times');

    // The shadow: where the upper bones project onto the ground along the light, against open ground.
    final frame = await shot(0);
    viewer.scene.updateMatrixWorld();

    double luma(Vector3 point) {
      final ndc = point.clone().project(viewer.camera);
      final (x, y) = (((ndc.x + 1) / 2 * size).round(), ((1 - ndc.y) / 2 * size).round());
      var dark = double.infinity;

      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final i = ((y + dy) * size + x + dx) * 4;
          final l = 0.2126 * frame.getUint8(i) + 0.7152 * frame.getUint8(i + 1) + 0.0722 * frame.getUint8(i + 2);
          dark = l < dark ? l : dark;
        }
      }

      return dark;
    }

    // A point's shadow on the ground (y = 0), cast along the light's direction.
    Vector3 cast(Vector3 p) => p.sub(Viewer.sun.clone().multiplyScalar(p.y / Viewer.sun.y));
    final shade = [
      for (final bone in body.skeleton!.bones.skip(2)) luma(cast(Vector3().setFromMatrixPosition(bone.matrixWorld))),
    ].reduce((p, q) => p < q ? p : q);
    final open = luma(Vector3(-1.2, 0, 1));
    // ignore: avoid_print
    print('ground luma: shadow $shade, open $open');
    expect(shade, lessThan(open * 0.75), reason: 'the worm casts a shadow on the ground');

    // The page: the frame loop advances the mixer and a mouse drag orbits the camera, with damping.
    await tester.pumpWidget(MaterialApp(home: ViewerPage(viewer: viewer)));
    await tester.pump();
    final time = viewer.mixer.time;
    final bend = body.skeleton!.bones[2].quaternion.clone();
    final from = viewer.camera.position.clone();
    await tester.dragFrom(tester.getCenter(find.byType(EntView)), const Offset(160, 40), kind: PointerDeviceKind.mouse);
    final released = viewer.camera.position.clone();

    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }

    // ignore: avoid_print
    print(
      'mixer ${viewer.mixer.time - time} s over ${renderer.info.render.frame} frames; camera moved '
      '${viewer.camera.position.distanceTo(from)}',
    );
    expect(viewer.early, 0, reason: 'no frame ran before compileAsync completed');
    expect(renderer.info.render.frame, greaterThan(5));
    expect(viewer.mixer.time - time, greaterThan(0.1), reason: 'the loop advances the mixer');
    expect(body.skeleton!.bones[2].quaternion.equals(bend), isFalse, reason: 'the loop poses the bones');
    expect(viewer.camera.position.distanceTo(from), greaterThan(0.3), reason: 'the drag orbits the camera');
    expect(
      viewer.camera.position.distanceTo(released),
      greaterThan(0.05),
      reason: 'the loop updates the controls, so damping glides on after the release',
    );
    expect(
      viewer.camera.position.distanceTo(viewer.controls.target),
      closeTo(from.distanceTo(Vector3(0, 0.9, 0)), 1e-6),
    );

    await tester.pumpWidget(const SizedBox());
    viewer.dispose();
    renderer.dispose();
  });

  testWidgets('the page shows a loading state, then the view, and disposes what it created', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ViewerPage()));
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(EntView), findsNothing);

    for (var i = 0; i < 100 && find.byType(EntView).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(find.byType(EntView), findsOneWidget);
    expect(find.textContaining('Failed'), findsNothing);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a viewer disposed while loading stops and leaves nothing on the renderer', (tester) async {
    final viewer = Viewer(await FlutterGpuRenderer.create());
    final renderer = viewer.renderer;
    final data = (await tester.runAsync(() => rootBundle.load('assets/worm.glb')))!.buffer;
    await tester.runAsync(() async {
      final loading = viewer.load(data);

      // What the page does when it goes away mid-load.
      viewer.dispose();
      renderer.dispose();
      await loading;
    });

    // ignore: avoid_print
    print(
      'after a mid-load dispose: ${renderer.info.memory.geometries} geometries, '
      '${renderer.info.memory.textures} textures, compiled ${viewer.compiled}',
    );
    expect(viewer.compiled, isFalse, reason: 'load stops once the viewer is disposed');
    expect(renderer.info.memory.geometries, 0);
    expect(renderer.info.memory.textures, 0);
  });

  testWidgets('the page disposed while loading reports no error', (tester) async {
    for (final wait in [0, 20, 200]) {
      await tester.pumpWidget(const MaterialApp(home: ViewerPage()));
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: wait)));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('rough frame times of the running viewer', (tester) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    final viewer = Viewer(await FlutterGpuRenderer.create());
    final renderer = viewer.renderer;
    await tester.runAsync(() async => viewer.load((await rootBundle.load('assets/worm.glb')).buffer));
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    await tester.pumpWidget(MaterialApp(home: ViewerPage(viewer: viewer)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    final frames = renderer.info.render.frame;
    final watch = Stopwatch()..start();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    final count = renderer.info.render.frame - frames;
    final live = watch.elapsedMicroseconds / count / 1000;

    // The loop and render alone, on the CPU, at the view's size (the GPU runs behind).
    final size = renderer.getSize(Vector2());
    watch.reset();

    for (var i = 0; i < 60; i++) {
      viewer.frame(Duration.zero);
      renderer.render(viewer.scene, viewer.camera).dispose();
    }

    // ignore: avoid_print
    print(
      'rough: $count live frames in 2 s, ${live.toStringAsFixed(1)} ms each; loop + render on the CPU '
      '${(watch.elapsedMicroseconds / 60 / 1000).toStringAsFixed(1)} ms at ${size.x}x${size.y} logical px, '
      'pixel ratio ${renderer.getPixelRatio()}',
    );
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;
    await tester.pumpWidget(const SizedBox());
    viewer.dispose();
    renderer.dispose();
  });
}
