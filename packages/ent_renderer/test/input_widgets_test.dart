import 'package:ent_renderer/ent_renderer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ent/ent.dart' show Input;

void main() {
  group('KeyboardInput', () {
    testWidgets('keys go down and up by their KeyboardEvent.code; repeats change nothing', (tester) async {
      final input = Input()
        ..bind('jump', ['Space'])
        ..bindAxis('moveX', negative: ['KeyA'], positive: ['KeyD']);
      await tester.pumpWidget(KeyboardInput(input: input, child: const SizedBox()));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space, physicalKey: PhysicalKeyboardKey.space);
      expect([input.isDown('jump'), input.wasPressed('jump')], [true, true]);

      input.endFrame();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space, physicalKey: PhysicalKeyboardKey.space);
      expect(input.wasPressed('jump'), isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD, physicalKey: PhysicalKeyboardKey.keyD);
      expect(input.axis('moveX'), 1);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space, physicalKey: PhysicalKeyboardKey.space);
      expect([input.isDown('jump'), input.wasReleased('jump')], [false, true]);
    });

    testWidgets('losing the focus releases every source', (tester) async {
      final input = Input()..bind('jump', ['Space']);
      final other = FocusNode();
      addTearDown(other.dispose);
      await tester.pumpWidget(
        Column(
          children: [
            KeyboardInput(input: input, child: const SizedBox()),
            Focus(focusNode: other, child: const SizedBox()),
          ],
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space, physicalKey: PhysicalKeyboardKey.space);
      expect(input.isDown('jump'), isTrue);

      other.requestFocus();
      await tester.pump();
      expect(input.isDown('jump'), isFalse);
    });

    test('key codes: letters, digits, function keys, arrows, modifiers and gamepad buttons', () {
      expect(keyCode(PhysicalKeyboardKey.keyW), 'KeyW');
      expect(keyCode(PhysicalKeyboardKey.digit0), 'Digit0');
      expect(keyCode(PhysicalKeyboardKey.digit7), 'Digit7');
      expect(keyCode(PhysicalKeyboardKey.f12), 'F12');
      expect(keyCode(PhysicalKeyboardKey.arrowUp), 'ArrowUp');
      expect(keyCode(PhysicalKeyboardKey.shiftRight), 'ShiftRight');
      expect(keyCode(PhysicalKeyboardKey.gameButtonA), 'GamepadA');
      expect(keyCode(PhysicalKeyboardKey.gameButtonThumbRight), 'GamepadRightStick');
      expect(keyCode(PhysicalKeyboardKey.audioVolumeUp), isNull);
    });

    testWidgets('a key without a name is left to the rest of the app', (tester) async {
      final input = Input();
      var reached = false;
      await tester.pumpWidget(
        Focus(
          onKeyEvent: (node, event) {
            reached = true;
            return KeyEventResult.handled;
          },
          child: KeyboardInput(input: input, child: const SizedBox()),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.audioVolumeUp, physicalKey: PhysicalKeyboardKey.audioVolumeUp);
      expect(reached, isTrue);
    });
  });

  group('Joystick', () {
    testWidgets('reports its position from -1 to 1, clamped to the circle, and springs back', (tester) async {
      final input = Input()
        ..bindAxis('moveX', analog: ['JoystickX'])
        ..bindAxis('moveY', analog: ['JoystickY']);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Joystick(input: input, size: 100),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(50, 50));
      await gesture.moveTo(const Offset(75, 50));
      expect([input.axis('moveX'), input.axis('moveY')], [0.5, 0]);

      await gesture.moveTo(const Offset(50, 0));
      expect([input.axis('moveX'), input.axis('moveY')], [0, -1], reason: 'up is negative');

      await gesture.moveTo(const Offset(250, 50));
      expect([input.axis('moveX'), input.axis('moveY')], [1, 0], reason: 'clamped to the circle');

      await gesture.moveTo(const Offset(150, 150));
      expect(input.axis('moveX'), closeTo(0.7071, 1e-4), reason: 'diagonally, to the circle, not the square');
      expect(input.axis('moveY'), closeTo(0.7071, 1e-4));

      await gesture.up();
      expect([input.axis('moveX'), input.axis('moveY')], [0, 0]);
    });
  });

  group('TouchButton', () {
    testWidgets('holds its source down while touched', (tester) async {
      final input = Input()..bind('fire', ['ButtonFire']);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TouchButton(input: input, source: 'ButtonFire', child: const SizedBox.expand()),
        ),
      );

      final gesture = await tester.startGesture(const Offset(10, 10));
      expect([input.isDown('fire'), input.wasPressed('fire')], [true, true]);

      await gesture.up();
      expect([input.isDown('fire'), input.wasReleased('fire')], [false, true]);
    });
  });

  group('PointerInput', () {
    // A 200 × 100 view at the top left, with a tap counter inside to see that events still reach it.
    Future<List<int>> view(WidgetTester tester, Input input) async {
      final taps = [0];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: PointerInput(
              input: input,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps[0]++,
                child: const SizedBox(width: 200, height: 100),
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    Input pointers() => Input()
      ..deadZone = 0
      ..bindAxis('x', analog: ['PointerX'])
      ..bindAxis('y', analog: ['PointerY'])
      ..bind('fire', ['Pointer'])
      ..bind('alt', ['PointerSecondary'])
      ..bind('middle', ['PointerMiddle']);

    testWidgets('reports a hovering mouse in normalized device coordinates, y up', (tester) async {
      final input = pointers();
      await view(tester, input);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(150, 25));
      await mouse.moveTo(const Offset(150, 25));
      expect([input.axis('x'), input.axis('y')], [0.5, 0.5]);

      await mouse.moveTo(const Offset(0, 99));
      expect(input.axis('x'), -1);
      expect(input.axis('y'), closeTo(-0.98, 1e-12));
      expect(input.isDown('fire'), isFalse);
      await mouse.removePointer();
    });

    testWidgets('presses each mouse button as its source and releases it', (tester) async {
      final input = pointers();
      final taps = await view(tester, input);

      final mouse = await tester.startGesture(const Offset(50, 50), kind: PointerDeviceKind.mouse);
      expect([input.wasPressed('fire'), input.axis('x'), input.axis('y')], [true, -0.5, 0]);

      await mouse.up();
      expect([input.isDown('fire'), input.wasReleased('fire')], [false, true]);
      expect(taps[0], 1, reason: 'the view below gets the tap too');

      input.endFrame();
      final right = await tester.startGesture(
        const Offset(10, 10),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      expect([input.isDown('alt'), input.isDown('fire')], [true, false]);
      await right.up();
      expect(input.isDown('alt'), isFalse);

      final middle = await tester.startGesture(
        const Offset(10, 10),
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      expect(input.isDown('middle'), isTrue);
      await middle.cancel();
      expect(input.isDown('middle'), isFalse, reason: 'a cancelled pointer lets go');
    });

    testWidgets('a button pressed while another is held, then lifted alone', (tester) async {
      final input = pointers();
      await view(tester, input);

      // Moves pointer 7 to [x] holding [buttons], which TestGesture.moveTo cannot change.
      Future<void> move(TestGesture mouse, double x, int buttons) => mouse.updateWithCustomEvent(
        PointerMoveEvent(pointer: 7, kind: PointerDeviceKind.mouse, position: Offset(x, 50), buttons: buttons),
      );

      final mouse = await tester.startGesture(const Offset(50, 50), kind: PointerDeviceKind.mouse, pointer: 7);
      await move(mouse, 60, kPrimaryButton | kSecondaryButton);
      expect([input.isDown('fire'), input.isDown('alt')], [true, true]);

      await move(mouse, 70, kPrimaryButton);
      expect([input.isDown('fire'), input.isDown('alt'), input.wasReleased('alt')], [true, false, true]);
      await mouse.up();
    });

    testWidgets('Pointer stays down while any touch holds it, and goes up once', (tester) async {
      final input = pointers();
      await view(tester, input);

      final first = await tester.startGesture(const Offset(20, 20));
      final second = await tester.startGesture(const Offset(180, 80), pointer: 2);
      input.endFrame();

      await first.up();
      expect([input.isDown('fire'), input.wasReleased('fire')], [true, false]);
      expect([input.axis('x'), input.axis('y')], [-0.8, 0.6], reason: 'the last pointer that moved');

      await second.up();
      expect([input.isDown('fire'), input.wasReleased('fire')], [false, true]);
    });

    testWidgets('removing the widget releases what its pointers hold', (tester) async {
      final input = pointers();
      await view(tester, input);

      final mouse = await tester.startGesture(const Offset(20, 20), kind: PointerDeviceKind.mouse, pointer: 7);
      await tester.pumpWidget(const SizedBox());
      expect(input.isDown('fire'), isFalse);

      // The pointer still reaches the gone widget's listener; a button it presses now must not go down.
      await mouse.updateWithCustomEvent(
        const PointerMoveEvent(
          pointer: 7,
          kind: PointerDeviceKind.mouse,
          position: Offset(30, 20),
          buttons: kPrimaryButton | kSecondaryButton,
        ),
      );
      expect(input.isDown('alt'), isFalse);
      await mouse.up();
    });
  });
}
