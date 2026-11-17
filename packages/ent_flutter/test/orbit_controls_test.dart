// OrbitControlsListener: Flutter pointers drive OrbitControls with the reference's arithmetic. The core is checked
// against the reference fixtures in packages/ent; here the gestures must reach it as the DOM events would.

import 'dart:math' as math;

import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Matrix4;
import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

const width = 400.0;
const height = 300.0;
const center = Offset(200, 150);

OrbitControls controls() {
  final camera = PerspectiveCamera(50, width / height, 0.1, 100)..position.set(0, 0, 5);
  return OrbitControls(camera);
}

Future<void> pump(WidgetTester tester, OrbitControls controls) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: height,
          child: OrbitControlsListener(controls: controls, child: const SizedBox.expand()),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a one-finger drag of N px rotates by angle 2 PI N rotateSpeed / clientHeight', (tester) async {
    final c = controls()..rotateSpeed = 0.7;
    await pump(tester, c);

    final azimuth = c.getAzimuthalAngle();
    final polar = c.getPolarAngle();
    final gesture = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(15, -20));
    await gesture.up();

    expect(c.getAzimuthalAngle() - azimuth, closeTo(-2 * math.pi * 45 * 0.7 / height, 1e-12));
    expect(c.getPolarAngle() - polar, closeTo(2 * math.pi * 20 * 0.7 / height, 1e-12));
    expect(c.getDistance(), closeTo(5, 1e-12));
    expect((c.domElement! as ControlsElement).clientHeight, height);
  });

  testWidgets('a left mouse drag rotates, a right drag and shift + left drag pan', (tester) async {
    final c = controls();
    await pump(tester, c);

    final mouse = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    await mouse.moveBy(const Offset(-60, 0));
    await mouse.up();
    expect(c.getAzimuthalAngle(), closeTo(2 * math.pi * 60 / height, 1e-12));
    expect(c.target.length(), 0);

    final right = await tester.startGesture(center, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await right.moveBy(const Offset(30, 0));
    await right.up();

    // The reference's _pan: 2 deltaX targetDistance tan(fov / 2) / clientHeight along the camera's -x.
    final pan = 2 * 30 * 5 * math.tan(25 * math.pi / 180) / height;
    expect(c.target.length(), closeTo(pan, 1e-12));
    expect(c.getDistance(), closeTo(5, 1e-12));

    final before = c.target.clone();
    final azimuth = c.getAzimuthalAngle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final shift = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    await shift.moveBy(const Offset(0, 30));
    await shift.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(c.target.distanceTo(before), closeTo(pan, 1e-12));
    expect(c.getAzimuthalAngle(), closeTo(azimuth, 1e-12));
  });

  testWidgets('a pinch changes the distance by dolly scale (d0 / d1) ^ zoomSpeed', (tester) async {
    final c = controls()..zoomSpeed = 1.5;
    await pump(tester, c);

    final a = await tester.startGesture(center - const Offset(40, 0), kind: PointerDeviceKind.touch, pointer: 1);
    final b = await tester.startGesture(center + const Offset(40, 0), kind: PointerDeviceKind.touch, pointer: 2);

    // Symmetric spread from 80 to 120 px: the midpoint stays, so there is no pan.
    await a.moveBy(const Offset(-20, 0));
    await b.moveBy(const Offset(20, 0));
    await a.up();
    await b.up();

    expect(c.getDistance(), closeTo(5 / math.pow(120 / 80, 1.5), 1e-12));

    // Each finger moves alone, so the midpoint pans out and back at different distances; the same pointer
    // events sent straight to the reference-verified core give the same camera and target.
    final r = controls()..zoomSpeed = 1.5;
    r.connect(ControlsElement(clientWidth: width, clientHeight: height));

    ControlsPointerEvent touch(int id, double x) =>
        ControlsPointerEvent(pointerId: id, pointerType: 'touch', clientX: x, clientY: 150);

    r.onPointerDown(touch(1, 160));
    r.onPointerDown(touch(2, 240));
    r.onPointerMove(touch(1, 140));
    r.onPointerMove(touch(2, 260));
    r.onPointerUp(touch(1, 140));
    r.onPointerUp(touch(2, 260));
    expect(c.object.position.toArray(), r.object.position.toArray());
    expect(c.target.toArray(), r.target.toArray());
  });

  testWidgets('a two-finger drag pans by the midpoint', (tester) async {
    final c = controls();
    await pump(tester, c);

    final a = await tester.startGesture(center - const Offset(40, 0), kind: PointerDeviceKind.touch, pointer: 1);
    final b = await tester.startGesture(center + const Offset(40, 0), kind: PointerDeviceKind.touch, pointer: 2);
    await a.moveBy(const Offset(0, 25));
    await b.moveBy(const Offset(0, 25));
    await a.up();
    await b.up();

    expect(c.target.y, greaterThan(0));
    expect(c.target.x, closeTo(0, 1e-12));
    expect(c.getAzimuthalAngle(), closeTo(0, 1e-12));
  });

  testWidgets('the wheel dollies by scale 0.95 ^ (zoomSpeed |deltaY| / 100)', (tester) async {
    final c = controls();
    await pump(tester, c);

    final events = <String>[];
    c.addEventListener('start', (e) => events.add('start'));
    c.addEventListener('end', (e) => events.add('end'));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: center, scrollDelta: const Offset(0, 100)));
    expect(c.getDistance(), closeTo(5 / 0.95, 1e-12));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: center, scrollDelta: const Offset(0, -250)));
    expect(c.getDistance(), closeTo(5 / 0.95 * math.pow(0.95, 2.5), 1e-12));
    expect(events, ['start', 'end', 'start', 'end']);
  });

  testWidgets('with damping the camera keeps moving after release, over update() ticks', (tester) async {
    final c = controls()
      ..enableDamping = true
      ..dampingFactor = 0.1;
    await pump(tester, c);

    final gesture = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await gesture.moveBy(const Offset(60, 0));
    await gesture.up();

    // As in the reference, each update applies dampingFactor of the remaining delta, then keeps 1 - dampingFactor of it.
    final delta = -2 * math.pi * 60 / height;
    var expected = c.getAzimuthalAngle();
    expect(expected, closeTo(delta * 0.1, 1e-12));

    var remaining = delta * 0.9;

    for (var i = 0; i < 5; i++) {
      expect(c.update(), true);
      expected += remaining * 0.1;
      remaining *= 0.9;
      expect(c.getAzimuthalAngle(), closeTo(expected, 1e-12));
    }
  });
}
