// The reference unit tests of MathUtils, plus Dart-side checks for setQuaternionFromProperEuler and the typed-array
// normalization helpers.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Maths', () {
    group('Math', () {
      // PUBLIC STUFF
      test('generateUUID', () {
        final a = MathUtils.generateUUID();
        final regex = RegExp(r'[A-Z0-9]{8}-[A-Z0-9]{4}-4[A-Z0-9]{3}-[A-Z0-9]{4}-[A-Z0-9]{12}', caseSensitive: false);
        // note the fixed '4' here ----------^

        expect(regex.hasMatch(a), isTrue, reason: 'Generated UUID matches the expected pattern');
      });

      test('clamp', () {
        expect(MathUtils.clamp(0.5, 0, 1), 0.5, reason: 'Value already within limits');
        expect(MathUtils.clamp(0, 0, 1), 0, reason: 'Value equal to one limit');
        expect(MathUtils.clamp(-0.1, 0, 1), 0, reason: 'Value too low');
        expect(MathUtils.clamp(1.1, 0, 1), 1, reason: 'Value too high');
      });

      test('euclideanModulo', () {
        expect(MathUtils.euclideanModulo(6, 0).isNaN, isTrue, reason: 'Division by zero returns NaN');
        expect(MathUtils.euclideanModulo(6, 1), 0, reason: 'Division by trivial divisor');
        expect(MathUtils.euclideanModulo(6, 2), 0, reason: 'Division by non-trivial divisor');
        expect(MathUtils.euclideanModulo(6, 5), 1, reason: 'Division by itself - 1');
        expect(MathUtils.euclideanModulo(6, 6), 0, reason: 'Division by itself');
        expect(MathUtils.euclideanModulo(6, 7), 6, reason: 'Division by itself + 1');
      });

      test('mapLinear', () {
        expect(MathUtils.mapLinear(0.5, 0, 1, 0, 10), 5, reason: 'Value within range');
        expect(MathUtils.mapLinear(0.0, 0, 1, 0, 10), 0, reason: 'Value equal to lower boundary');
        expect(MathUtils.mapLinear(1.0, 0, 1, 0, 10), 10, reason: 'Value equal to upper boundary');
      });

      test('inverseLerp', () {
        expect(MathUtils.inverseLerp(1, 2, 1.5), 0.5, reason: '50% Percentage');
        expect(MathUtils.inverseLerp(1, 2, 2), 1, reason: '100% Percentage');
        expect(MathUtils.inverseLerp(1, 2, 1), 0, reason: '0% Percentage');
        expect(MathUtils.inverseLerp(1, 1, 1), 0, reason: '0% Percentage, no NaN value');
      });

      test('lerp', () {
        expect(MathUtils.lerp(1, 2, 0), 1, reason: 'Value equal to lower boundary');
        expect(MathUtils.lerp(1, 2, 1), 2, reason: 'Value equal to upper boundary');
        expect(MathUtils.lerp(1, 2, 0.4), 1.4, reason: 'Value within range');
      });

      test('damp', () {
        expect(MathUtils.damp(1, 2, 0, 0.016), 1, reason: 'Value equal to lower boundary');
        expect(MathUtils.damp(1, 2, 10, 0.016), 1.1478562110337887, reason: 'Value within range');
      });

      test('pingpong', () {
        expect(MathUtils.pingpong(2.5), 0.5, reason: 'Value at 2.5 is 0.5');
        expect(MathUtils.pingpong(2.5, 2), 1.5, reason: 'Value at 2.5 with length of 2 is 1.5');
        expect(MathUtils.pingpong(-1.5), 0.5, reason: 'Value at -1.5 is 0.5');
      });

      test('smoothstep', () {
        expect(MathUtils.smoothstep(-1, 0, 2), 0, reason: 'Value lower than minimum');
        expect(MathUtils.smoothstep(0, 0, 2), 0, reason: 'Value equal to minimum');
        expect(MathUtils.smoothstep(0.5, 0, 2), 0.15625, reason: 'Value within limits');
        expect(MathUtils.smoothstep(1, 0, 2), 0.5, reason: 'Value within limits');
        expect(MathUtils.smoothstep(1.5, 0, 2), 0.84375, reason: 'Value within limits');
        expect(MathUtils.smoothstep(2, 0, 2), 1, reason: 'Value equal to maximum');
        expect(MathUtils.smoothstep(3, 0, 2), 1, reason: 'Value higher than maximum');
      });

      test('smootherstep', () {
        expect(MathUtils.smootherstep(-1, 0, 2), 0, reason: 'Value lower than minimum');
        expect(MathUtils.smootherstep(0, 0, 2), 0, reason: 'Value equal to minimum');
        expect(MathUtils.smootherstep(0.5, 0, 2), 0.103515625, reason: 'Value within limits');
        expect(MathUtils.smootherstep(1, 0, 2), 0.5, reason: 'Value within limits');
        expect(MathUtils.smootherstep(1.5, 0, 2), 0.896484375, reason: 'Value within limits');
        expect(MathUtils.smootherstep(2, 0, 2), 1, reason: 'Value equal to maximum');
        expect(MathUtils.smootherstep(3, 0, 2), 1, reason: 'Value higher than maximum');
      });

      test('randInt', () {
        const low = 1, high = 3;
        final a = MathUtils.randInt(low, high);

        expect(a >= low, isTrue, reason: 'Value equal to or higher than lower limit');
        expect(a <= high, isTrue, reason: 'Value equal to or lower than upper limit');
      });

      test('randFloat', () {
        const low = 1.0, high = 3.0;
        final a = MathUtils.randFloat(low, high);

        expect(a >= low, isTrue, reason: 'Value equal to or higher than lower limit');
        expect(a <= high, isTrue, reason: 'Value equal to or lower than upper limit');
      });

      test('randFloatSpread', () {
        final a = MathUtils.randFloatSpread(3);

        expect(a > -3 / 2, isTrue, reason: 'Value higher than lower limit');
        expect(a < 3 / 2, isTrue, reason: 'Value lower than upper limit');
      });

      test('degToRad', () {
        expect(MathUtils.degToRad(0), 0, reason: '0 degrees');
        expect(MathUtils.degToRad(90), math.pi / 2, reason: '90 degrees');
        expect(MathUtils.degToRad(180), math.pi, reason: '180 degrees');
        expect(MathUtils.degToRad(360), math.pi * 2, reason: '360 degrees');
      });

      test('radToDeg', () {
        expect(MathUtils.radToDeg(0), 0, reason: '0 radians');
        expect(MathUtils.radToDeg(math.pi / 2), 90, reason: 'Math.PI / 2 radians');
        expect(MathUtils.radToDeg(math.pi), 180, reason: 'Math.PI radians');
        expect(MathUtils.radToDeg(math.pi * 2), 360, reason: 'Math.PI * 2 radians');
      });

      test('isPowerOfTwo', () {
        expect(MathUtils.isPowerOfTwo(0), false, reason: '0 is not a PoT');
        expect(MathUtils.isPowerOfTwo(1), true, reason: '1 is a PoT');
        expect(MathUtils.isPowerOfTwo(2), true, reason: '2 is a PoT');
        expect(MathUtils.isPowerOfTwo(3), false, reason: '3 is not a PoT');
        expect(MathUtils.isPowerOfTwo(4), true, reason: '4 is a PoT');
        expect(MathUtils.isPowerOfTwo(math.pow(2, 40)), true, reason: 'Large PoT');
        expect(MathUtils.isPowerOfTwo(3 * math.pow(2, 32)), false, reason: 'Large non-PoT');
      });

      test('ceilPowerOfTwo', () {
        expect(MathUtils.ceilPowerOfTwo(1), 1, reason: 'Closest higher PoT to 1 is 1');
        expect(MathUtils.ceilPowerOfTwo(3), 4, reason: 'Closest higher PoT to 3 is 4');
        expect(MathUtils.ceilPowerOfTwo(4), 4, reason: 'Closest higher PoT to 4 is 4');
      });

      test('floorPowerOfTwo', () {
        expect(MathUtils.floorPowerOfTwo(1), 1, reason: 'Closest lower PoT to 1 is 1');
        expect(MathUtils.floorPowerOfTwo(3), 2, reason: 'Closest lower PoT to 3 is 2');
        expect(MathUtils.floorPowerOfTwo(4), 4, reason: 'Closest lower PoT to 4 is 4');
      });
    });
  });

  // Not in the reference tests; behaviour checked against the reference source.
  group('MathUtils (Dart port)', () {
    test('DEG2RAD and RAD2DEG', () {
      expect(MathUtils.DEG2RAD, math.pi / 180);
      expect(MathUtils.RAD2DEG, 180 / math.pi);
    });

    test('setQuaternionFromProperEuler matches the equivalent rotation sequence', () {
      const a = 0.3, b = -0.7, c = 1.1;
      final axes = {'X': Vector3(1, 0, 0), 'Y': Vector3(0, 1, 0), 'Z': Vector3(0, 0, 1)};

      for (final order in ['XYX', 'XZX', 'YXY', 'YZY', 'ZXZ', 'ZYZ']) {
        final q = Quaternion();
        MathUtils.setQuaternionFromProperEuler(q, a, b, c, order);

        // Intrinsic rotations: a about the first axis, then b, then c about the rotated axes.
        final expected = Quaternion()
            .setFromAxisAngle(axes[order[0]]!, a)
            .multiply(Quaternion().setFromAxisAngle(axes[order[1]]!, b))
            .multiply(Quaternion().setFromAxisAngle(axes[order[2]]!, c));

        expect(q.x, closeTo(expected.x, 1e-12), reason: order);
        expect(q.y, closeTo(expected.y, 1e-12), reason: order);
        expect(q.z, closeTo(expected.z, 1e-12), reason: order);
        expect(q.w, closeTo(expected.w, 1e-12), reason: order);
      }
    });

    test('setQuaternionFromProperEuler warns on an unknown order and leaves the quaternion', () {
      final messages = <String>[];
      setConsoleFunction((type, message, params) => messages.add('$type $message'));
      addTearDown(() => setConsoleFunction(null));

      final q = Quaternion(1, 2, 3, 4);
      MathUtils.setQuaternionFromProperEuler(q, 1, 2, 3, 'XYZ');

      expect(q.equals(Quaternion(1, 2, 3, 4)), isTrue);
      expect(messages, ['warn ENT.MathUtils: .setQuaternionFromProperEuler() encountered an unknown order: XYZ']);
    });

    test('seededRandom is deterministic per seed', () {
      final first = MathUtils.seededRandom(42);
      final second = MathUtils.seededRandom();
      expect(MathUtils.seededRandom(42), first);
      expect(MathUtils.seededRandom(), second);
      expect(first, inInclusiveRange(0, 1));
    });

    test('normalize/denormalize/getNormalizationScale', () {
      expect(MathUtils.getNormalizationScale(Uint8List(1)), 255);
      expect(MathUtils.getNormalizationScale(Uint8ClampedList(1)), 255);
      expect(MathUtils.getNormalizationScale(Int16List(1)), 32767);
      expect(MathUtils.getNormalizationScale(Float32List(1)), isNull);
      expect(MathUtils.normalize(0.5, Uint8List(1)), 128);
      expect(MathUtils.normalize(-0.5, Int8List(1)), -63);
      expect(MathUtils.denormalize(-128, Int8List(1)), -1);
      expect(MathUtils.denormalize(0.25, Float32List(1)), 0.25);
      expect(() => MathUtils.normalize(0.5, Float64List(1)), throwsA(isA<EntError>()));
    });
  });
}
