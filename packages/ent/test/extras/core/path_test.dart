// The reference unit tests of Path, plus regression tests against values computed by the reference source
// (reference/extras_reference.mjs).

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

/// Every Path command; the same calls as reference/extras_reference.mjs.
Path _path() {
  return Path()
      .moveTo(1, 2)
      .lineTo(3, 4)
      .quadraticCurveTo(5, 6, 7, 2)
      .bezierCurveTo(8, 0, 9, -3, 6, -4)
      .splineThru([Vector2(4, -5), Vector2(2, -3), Vector2(0, -4)])
      .arc(1, 1, 2, 0, math.pi / 2, false)
      .absellipse(-2, 0, 3, 1.5, 0, math.pi, true, 0.3);
}

/// Compares a JSON map with the reference: same keys, numbers within tolerance, nested maps and lists.
void _sameJson(Object? actual, Object? expected, String at) {
  if (expected is num) {
    close(actual as num, expected, at);
  } else if (expected is Map) {
    expect((actual as Map).keys.toSet(), expected.keys.toSet(), reason: at);

    for (final key in expected.keys) {
      _sameJson(actual[key], expected[key], '$at.$key');
    }
  } else if (expected is List) {
    expect((actual as List).length, expected.length, reason: at);

    for (var i = 0; i < expected.length; i++) {
      _sameJson(actual[i], expected[i], '$at[$i]');
    }
  } else {
    expect(actual, expected, reason: at);
  }
}

void main() {
  group('Extras', () {
    group('Core', () {
      group('Path', () {
        // INHERITANCE
        test('Extending', () {
          final object = Path();
          expect(object, isA<CurvePath<Vector2>>(), reason: 'Path extends from CurvePath');
        });

        // INSTANCING
        test('Instancing', () {
          final object = Path();
          expect(object, isNotNull, reason: 'Can instantiate a Path.');
        });

        // PROPERTIES
        test('type', () {
          final object = Path();
          expect(object.type == 'Path', isTrue, reason: 'Path.type should be Path');
        });

        // Regression against the reference.

        test('moveTo lineTo quadraticCurveTo bezierCurveTo splineThru arc absellipse: curves', () {
          expect(_path().curves.map((c) => c.type).toList(), reference['pathTypes']);
        });

        test('currentPoint', () {
          closePoints([_path().currentPoint], [reference['pathCurrent']], 'currentPoint');
        });

        test('getPoints', () {
          closePoints(_path().getPoints(), reference['pathPoints'], 'getPoints()');
          closePoints(_path().getPoints(5), reference['pathPoints5'], 'getPoints(5)');
        });

        test('getSpacedPoints', () {
          closePoints(_path().getSpacedPoints(10), reference['pathSpaced'], 'getSpacedPoints(10)');
        });

        test('getLength getCurveLengths', () {
          final path = _path();
          close(path.getLength(), reference['pathLength'] as num, 'getLength');

          final lengths = path.getCurveLengths();
          final expected = (reference['pathCurveLengths'] as List).cast<num>();
          expect(lengths.length, expected.length);

          for (var i = 0; i < lengths.length; i++) {
            close(lengths[i], expected[i], 'getCurveLengths[$i]');
          }
        });

        test('getPointAt getTangentAt', () {
          final path = _path();
          closePoints(
            [
              for (final t in [0, 0.13, 0.5, 0.77, 1]) path.getPointAt(t.toDouble())!,
            ],
            reference['pathPointAt'],
            'getPointAt',
          );
          closePoints(
            [
              for (final t in [0, 0.25, 0.5, 0.99]) path.getTangentAt(t.toDouble()),
            ],
            reference['pathTangents'],
            'getTangentAt',
          );
        });

        test('toJSON fromJSON', () {
          final json = _path().toJSON();
          _sameJson(json, reference['pathJSON'], 'toJSON');

          final restored = Path().fromJSON(json);
          _sameJson(restored.toJSON(), reference['pathJSON'], 'fromJSON');
          closePoints(restored.getPoints(), reference['pathPoints'], 'restored getPoints');
        });

        test('setFromPoints and the constructor', () {
          final path = Path([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]);
          expect(path.curves.length, 2);
          expect(path.curves.every((c) => c is LineCurve), isTrue);
          expect(path.currentPoint.toArray(), [1.0, 1.0]);
        });

        test('copy clone', () {
          final path = _path();
          final clone = path.clone();
          expect(clone, isA<Path>());
          expect(clone.currentPoint.equals(path.currentPoint), isTrue);
          closePoints(clone.getPoints(), reference['pathPoints'], 'clone');
        });
      });
    });
  });
}
