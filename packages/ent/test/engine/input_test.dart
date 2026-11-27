import 'dart:math' as math;

import 'package:ent/ent.dart';
import 'package:test/test.dart';

void main() {
  group('Input', () {
    test('an action is down while any of its sources is', () {
      final input = Input()..bind('jump', ['Space', 'GamepadA']);
      expect(input.isDown('jump'), isFalse);

      input.press('GamepadA');
      expect(input.isDown('jump'), isTrue);

      input
        ..press('Space')
        ..release('GamepadA');
      expect(input.isDown('jump'), isTrue, reason: 'Space is still down');

      input.release('Space');
      expect(input.isDown('jump'), isFalse);
      expect(input.isDown('unbound'), isFalse);
    });

    test('wasPressed and wasReleased hold for the frame they happened in', () {
      final input = Input()..bind('fire', ['KeyF']);
      input.press('KeyF');
      expect(input.wasPressed('fire'), isTrue);

      input.endFrame();
      expect(input.wasPressed('fire'), isFalse);
      expect(input.isDown('fire'), isTrue);

      input.press('KeyF');
      expect(input.wasPressed('fire'), isFalse, reason: 'pressing a source that is down changes nothing');

      input.release('KeyF');
      expect(input.wasReleased('fire'), isTrue);

      input.endFrame();
      expect(input.wasReleased('fire'), isFalse);
    });

    test('a tap within one frame is pressed and released, and not down', () {
      final input = Input()..bind('fire', ['KeyF']);
      input
        ..press('KeyF')
        ..release('KeyF');

      expect([input.wasPressed('fire'), input.wasReleased('fire'), input.isDown('fire')], [true, true, false]);
    });

    test('an axis adds its keys and its strongest analog source, past the dead zone, within -1…1', () {
      final input = Input()
        ..bindAxis('moveX', negative: ['KeyA'], positive: ['KeyD'], analog: ['LeftStickX', 'JoystickX']);
      expect(input.axis('moveX'), 0);

      input.press('KeyD');
      expect(input.axis('moveX'), 1);

      input.press('KeyA');
      expect(input.axis('moveX'), 0, reason: 'both keys cancel');

      input
        ..release('KeyA')
        ..release('KeyD')
        ..move('LeftStickX', 0.05);
      expect(input.axis('moveX'), 0, reason: 'inside the dead zone');

      input
        ..move('LeftStickX', -0.5)
        ..move('JoystickX', 0.25);
      expect(input.axis('moveX'), -0.5, reason: 'the strongest stick');

      input
        ..press('KeyA')
        ..move('LeftStickX', -2);
      expect(input.axis('moveX'), -1, reason: 'clamped');
      expect(input.axis('unbound'), 0);
    });

    test('binding a name again replaces its sources; reset releases everything', () {
      final input = Input()
        ..bind('jump', ['Space'])
        ..bind('jump', ['KeyW'])
        ..bindAxis('moveY', analog: ['LeftStickY'])
        ..press('Space');
      expect(input.isDown('jump'), isFalse);

      input
        ..press('KeyW')
        ..move('LeftStickY', 0.75)
        ..reset();
      expect([input.isDown('jump'), input.wasReleased('jump'), input.axis('moveY')], [false, true, 0]);
    });

    test('Game.update ends the input frame, also while paused', () {
      final game = Game(Scene());
      final seen = <bool>[];
      game
        ..input.bind('jump', ['Space'])
        ..everyFrame((_) => seen.add(game.input.wasPressed('jump')))
        ..input.press('Space')
        ..update(0.1)
        ..update(0.1);
      expect(seen, [true, false]);

      game
        ..paused = true
        ..input.press('KeyQ')
        ..input.bind('quit', ['KeyQ']);
      expect(game.input.wasPressed('quit'), isTrue);

      game.update(0.1);
      expect(game.input.wasPressed('quit'), isFalse);
    });

    test('pointer is the PointerX and PointerY sources together, until reset', () {
      final input = Input();
      expect(input.pointer, isNull);

      input.move('PointerX', -0.5);
      expect(input.pointer, isNull, reason: 'only one coordinate reported');

      input.move('PointerY', 0.25);
      expect(input.pointer!.toArray(), [-0.5, 0.25]);

      input
        ..bind('fire', ['Pointer'])
        ..press('Pointer');
      expect(input.wasPressed('fire'), isTrue);

      input.reset();
      expect(input.pointer, isNull);
      expect(input.isDown('fire'), isFalse);
    });

    test('pointer aims a raycaster through the camera, as setFromCamera takes it', () {
      final camera = PerspectiveCamera(90, 1, 0.1, 100)..updateMatrixWorld();
      final input = Input()
        ..move('PointerX', 1)
        ..move('PointerY', 0);
      final ray = (Raycaster()..setFromCamera(input.pointer!, camera)).ray;

      // At the right edge of a 90° view the ray leaves at 45° to the right.
      expect(ray.direction.x, closeTo(math.sqrt1_2, 1e-12));
      expect(ray.direction.z, closeTo(-math.sqrt1_2, 1e-12));
    });
  });
}
