// The reference unit tests of DataUtils.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Extras', () {
    group('DataUtils', () {
      // PUBLIC
      test('toHalfFloat', () {
        expect(DataUtils.toHalfFloat(0) == 0, isTrue, reason: 'Passed!');

        // suppress the following console message during testing
        // DataUtils.toHalfFloat(): Value out of range.

        final warnings = <String>[];
        setConsoleFunction((type, message, params) => warnings.add(message));
        expect(DataUtils.toHalfFloat(100000) == 31743, isTrue, reason: 'Passed!');
        expect(DataUtils.toHalfFloat(-100000) == 64511, isTrue, reason: 'Passed!');
        setConsoleFunction(null);
        expect(warnings, [
          'ENT.DataUtils.toHalfFloat(): Value out of range.',
          'ENT.DataUtils.toHalfFloat(): Value out of range.',
        ]);

        expect(DataUtils.toHalfFloat(65504) == 31743, isTrue, reason: 'Passed!');
        expect(DataUtils.toHalfFloat(-65504) == 64511, isTrue, reason: 'Passed!');
        expect(DataUtils.toHalfFloat(math.pi) == 16968, isTrue, reason: 'Passed!');
        expect(DataUtils.toHalfFloat(-math.pi) == 49736, isTrue, reason: 'Passed!');
      });

      test('fromHalfFloat', () {
        expect(DataUtils.fromHalfFloat(0) == 0, isTrue, reason: 'Passed!');
        expect(DataUtils.fromHalfFloat(31744) == double.infinity, isTrue, reason: 'Passed!');
        expect(DataUtils.fromHalfFloat(64512) == double.negativeInfinity, isTrue, reason: 'Passed!');
        expect(DataUtils.fromHalfFloat(31743) == 65504, isTrue, reason: 'Passed!');
        expect(DataUtils.fromHalfFloat(64511) == -65504, isTrue, reason: 'Passed!');
        expect(DataUtils.fromHalfFloat(16968) == 3.140625, isTrue, reason: 'Passed!');
        expect(DataUtils.fromHalfFloat(49736) == -3.140625, isTrue, reason: 'Passed!');
      });
    });
  });
}
