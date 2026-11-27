import 'package:ent_renderer/ent_renderer.dart';
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
}
