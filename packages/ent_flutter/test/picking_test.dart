// Picking through EntView's pointer callbacks under `flutter test --enable-impeller --enable-flutter-gpu`: a tap at the
// screen position of a known world point gives its NDC, and a Raycaster set from it picks what the reference would.

import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:flutter/widgets.dart' hide Matrix4;
import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

const tick = Duration(milliseconds: 16);

// A scene seen from z = 5, picked on pointer down and hover as the reference's examples do.
class Picker {
  Picker(this.scene) {
    camera.position.z = 5;
  }

  final Scene scene;

  final camera = PerspectiveCamera(50, 1, 0.1, 100);

  final raycaster = Raycaster();

  Vector2? ndc;

  Vector2? hover;

  List<Intersection> hits = [];

  EntView view(FlutterGpuRenderer renderer, [EntFrameCallback? onFrame]) {
    return EntView(
      renderer: renderer,
      scene: scene,
      camera: camera,
      onFrame: onFrame,
      onPointerDown: (event, ndc) {
        this.ndc = ndc;
        raycaster.setFromCamera(ndc, camera);
        hits = raycaster.intersectObjects(scene.children);
      },
      onPointerHover: (event, ndc) => hover = ndc,
    );
  }

  // The NDC of [world] through the camera, as the core computes it.
  Vector2 project(Vector3 world) {
    final p = world.clone().project(camera);
    return Vector2(p.x, p.y);
  }

  // The logical screen position of [world] in a full-screen view.
  Offset screen(WidgetTester tester, Vector3 world) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final p = project(world);
    return Offset((p.x + 1) / 2 * size.width, (1 - p.y) / 2 * size.height);
  }

  // The hits of a ray cast directly through [world]'s NDC, without the view.
  List<Intersection> direct(Vector3 world) {
    return (Raycaster()..setFromCamera(project(world), camera)).intersectObjects(scene.children);
  }

  // Taps at [world] and checks that the view passed its NDC.
  Future<List<Intersection>> tap(WidgetTester tester, Vector3 world) async {
    await tester.tapAt(screen(tester, world));
    final p = project(world);
    expect(ndc!.x, closeTo(p.x, 1e-9));
    expect(ndc!.y, closeTo(p.y, 1e-9));
    return hits;
  }
}

Future<void> pumps(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(tick);
  }
}

MeshBasicMaterial basic() => MeshBasicMaterial({'color': 0xffffff});

void main() {
  late FlutterGpuRenderer renderer;

  setUp(() async {
    renderer = await FlutterGpuRenderer.create();
  });

  tearDown(() => renderer.dispose());

  void view(WidgetTester tester, double width, double height, [double ratio = 1]) {
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
  }

  // A unit box at x = -1 and a sphere behind it at z = -3, centred on the camera's ray through the box's centre.
  Picker boxes() {
    return Picker(
      Scene()
        ..add(Mesh(BoxGeometry(1, 1, 1), basic())..position.x = -1)
        ..add(Mesh(SphereGeometry(1), basic())..position.set(-1.6, 0, -3)),
    );
  }

  // Checks the first hit through [world] on the box's front face against a direct cast.
  void front(List<Intersection> hits, Picker picker, Vector3 world, double u, double v) {
    final direct = picker.direct(world);
    expect(hits.map((hit) => hit.object), [picker.scene.children[0], picker.scene.children[1]]);
    expect(hits[0].distance, closeTo(direct[0].distance, 1e-9));
    expect(hits[0].distance, closeTo(world.distanceTo(picker.camera.position), 1e-6));
    expect(hits[0].faceIndex, direct[0].faceIndex);
    expect(hits[0].face!.normal.toArray(), [0, 0, 1]);
    expect(hits[0].uv!.x, closeTo(u, 1e-6));
    expect(hits[0].uv!.y, closeTo(v, 1e-6));
  }

  testWidgets('a tap picks the box in front of the sphere, as a direct cast does; empty space picks nothing', (
    tester,
  ) async {
    view(tester, 400, 200);
    final picker = boxes();
    await tester.pumpWidget(picker.view(renderer));
    await pumps(tester, 2);
    final world = Vector3(-0.8, 0.2, 0.5);
    front(await picker.tap(tester, world), picker, world, 0.7, 0.7);
    expect(await picker.tap(tester, Vector3(1.5, 0.8, 0)), isEmpty);

    // A mouse moving over the view without a button hovers.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(100, 150));
    expect(picker.hover!.toArray(), [-0.5, -0.5]);
  });

  testWidgets('picking follows a resize and does not depend on the device pixel ratio', (tester) async {
    view(tester, 400, 200);
    final picker = boxes();
    await tester.pumpWidget(picker.view(renderer));
    await pumps(tester, 2);
    final world = Vector3(-1.2, -0.3, 0.5);
    front(await picker.tap(tester, world), picker, world, 0.3, 0.2);

    // The same logical size at twice the pixels.
    tester.view
      ..physicalSize = const Size(800, 400)
      ..devicePixelRatio = 2;
    await pumps(tester, 2);
    expect(renderer.getPixelRatio(), 2);
    front(await picker.tap(tester, world), picker, world, 0.3, 0.2);

    // A square view at ratio 1.5: the camera's aspect changes, and so do the box's screen position and NDC.
    tester.view
      ..physicalSize = const Size(450, 450)
      ..devicePixelRatio = 1.5;
    await pumps(tester, 2);
    expect(picker.camera.aspect, 1);
    front(await picker.tap(tester, world), picker, world, 0.3, 0.2);
  });

  testWidgets('an InstancedMesh gives the picked instanceId', (tester) async {
    view(tester, 400, 200);
    final mesh = InstancedMesh(BoxGeometry(0.8, 0.8, 0.8), basic(), 3);

    for (var i = 0; i < 3; i++) {
      mesh.setMatrixAt(i, Matrix4().makeTranslation(i * 1.5 - 1.5, 0, 0));
    }

    final picker = Picker(Scene()..add(mesh));
    await tester.pumpWidget(picker.view(renderer));
    await pumps(tester, 2);

    for (final i in [2, 0, 1]) {
      final world = Vector3(i * 1.5 - 1.5, 0.1, 0.4);
      final hits = await picker.tap(tester, world);
      expect(hits.single.object, mesh);
      expect(hits.single.instanceId, i);
      expect(hits.single.distance, closeTo(world.distanceTo(picker.camera.position), 1e-6));
    }
  });

  testWidgets('a SkinnedMesh is picked in the pose of the last animation frame', (tester) async {
    view(tester, 400, 200);

    // A 2-unit bar from y = -1 to 1: its upper half follows the bone at y = 0.
    final geometry = BoxGeometry(0.4, 2, 0.4, 1, 4, 1);
    final position = geometry.getAttribute('position')!;
    final indices = <int>[];
    final weights = <double>[];

    for (var i = 0; i < position.count; i++) {
      final upper = position.getY(i) > 0.01;
      indices.addAll([upper ? 1 : 0, 0, 0, 0]);
      weights.addAll([1, 0, 0, 0]);
    }

    geometry
      ..setAttribute('skinIndex', Uint16BufferAttribute(indices, 4))
      ..setAttribute('skinWeight', Float32BufferAttribute(weights, 4));
    final mesh = SkinnedMesh(geometry, basic());
    final root = Bone()..position.y = -1;
    final upper = Bone()
      ..name = 'upper'
      ..position.y = 1;
    mesh.add(root..add(upper));
    mesh.updateMatrixWorld(true);
    mesh.bind(Skeleton([root, upper]), mesh.matrixWorld);

    // The clip moves the upper bone 1.5 to the right in its first second; each frame shows it moved.
    final mixer = AnimationMixer(mesh);
    mixer
        .clipAction(
          AnimationClip('slide', 2, [
            VectorKeyframeTrack('upper.position', [0, 1], [0, 1, 0, 1.5, 1, 0]),
          ]),
        )!
        .play();
    final picker = Picker(Scene()..add(mesh));
    await tester.pumpWidget(picker.view(renderer, (elapsed) => mixer.setTime(1.5)));
    await pumps(tester, 2);
    expect(upper.position.x, 1.5);

    final moved = Vector3(1.5, 0.75, 0.2);
    final hits = await picker.tap(tester, moved);
    expect(hits.single.object, mesh);
    expect(hits.single.distance, closeTo(moved.distanceTo(picker.camera.position), 1e-6));
    expect(hits.single.point.x, closeTo(1.5, 1e-6));
    expect(hits.single.distance, closeTo(picker.direct(moved).single.distance, 1e-9));

    // Where the upper half was in the bind pose there is nothing now; the lower half stays.
    expect(await picker.tap(tester, Vector3(0, 0.75, 0.2)), isEmpty);
    expect((await picker.tap(tester, Vector3(0, -0.5, 0.2))).single.object, mesh);
  });

  testWidgets('a BatchedMesh gives the picked batchId', (tester) async {
    view(tester, 400, 200);
    final mesh = BatchedMesh(2, 48, 72, basic());
    final box = mesh.addGeometry(BoxGeometry(0.8, 0.8, 0.8));

    for (final x in [-1.0, 1.0]) {
      mesh.setMatrixAt(mesh.addInstance(box), Matrix4().makeTranslation(x, 0, 0));
    }

    final picker = Picker(Scene()..add(mesh));
    await tester.pumpWidget(picker.view(renderer));
    await pumps(tester, 2);

    for (final i in [1, 0]) {
      final world = Vector3(i * 2 - 1, -0.2, 0.4);
      final hits = await picker.tap(tester, world);
      expect(hits.single.object, mesh);
      expect(hits.single.batchId, i);
      expect(hits.single.distance, closeTo(world.distanceTo(picker.camera.position), 1e-6));
    }
  });
}
