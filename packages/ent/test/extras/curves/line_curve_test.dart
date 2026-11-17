// The reference unit tests of LineCurve.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('LineCurve', () {
        final points = [Vector2(0, 0), Vector2(10, 10), Vector2(-10, 10), Vector2(-8, 5)];
        final curve0 = LineCurve(points[0], points[1]);

        // INHERITANCE
        test('Extending', () {
          final object = LineCurve();
          expect(object, isA<Curve<Vector2>>(), reason: 'LineCurve extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = LineCurve();
          expect(object, isNotNull, reason: 'Can instantiate a LineCurve.');
        });

        // PROPERTIES
        test('type', () {
          final object = LineCurve();
          expect(object.type == 'LineCurve', isTrue, reason: 'LineCurve.type should be LineCurve');
        });

        // PUBLIC
        test('isLineCurve', () {
          final object = LineCurve();
          expect(object.isLineCurve, isTrue, reason: 'LineCurve.isLineCurve should be true');
        });

        test('getPointAt', () {
          final curve = LineCurve(points[0], points[3]);

          final expectedPoints = [Vector2(0, 0), Vector2(-2.4, 1.5), Vector2(-4, 2.5), Vector2(-8, 5)];

          final actual = [
            curve.getPointAt(0, Vector2()),
            curve.getPointAt(0.3, Vector2()),
            curve.getPointAt(0.5, Vector2()),
            curve.getPointAt(1, Vector2()),
          ];

          deepEqualPoints(actual, expectedPoints, 'Correct points');
        });

        test('getTangent/getTangentAt', () {
          final curve = curve0;
          final tangent = Vector2();

          curve.getTangent(0, tangent);
          final expectedTangent = math.sqrt(0.5);

          numEqual(tangent.x, expectedTangent, 'tangent.x correct');
          numEqual(tangent.y, expectedTangent, 'tangent.y correct');

          curve.getTangentAt(0, tangent);

          numEqual(tangent.x, expectedTangent, 'tangentAt.x correct');
          numEqual(tangent.y, expectedTangent, 'tangentAt.y correct');
        });

        // OTHERS
        test('Simple curve', () {
          var curve = curve0;

          var expectedPoints = [
            Vector2(0, 0),
            Vector2(2, 2),
            Vector2(4, 4),
            Vector2(6, 6),
            Vector2(8, 8),
            Vector2(10, 10),
          ];

          var actual = curve.getPoints();

          deepEqualPoints(actual, expectedPoints, 'Correct points for first curve');

          //

          curve = LineCurve(points[1], points[2]);

          expectedPoints = [
            Vector2(10, 10),
            Vector2(6, 10),
            Vector2(2, 10),
            Vector2(-2, 10),
            Vector2(-6, 10),
            Vector2(-10, 10),
          ];

          actual = curve.getPoints();

          deepEqualPoints(actual, expectedPoints, 'Correct points for second curve');
        });

        test('getLength/getLengths', () {
          final curve = curve0;

          final length = curve.getLength();
          final expectedLength = math.sqrt(200);

          numEqual(length, expectedLength, 'Correct length of curve');

          final lengths = curve.getLengths(5);
          final expectedLengths = [0.0, math.sqrt(8), math.sqrt(32), math.sqrt(72), math.sqrt(128), math.sqrt(200)];

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getUtoTmapping', () {
          final curve = curve0;

          final start = curve.getUtoTmapping(0, 0);
          final end = curve.getUtoTmapping(0, curve.getLength());
          final somewhere = curve.getUtoTmapping(0.3, 0);

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, 0.3, 'getUtoTmapping( 0.3, 0 ) is correct');
        });

        test('getSpacedPoints', () {
          final curve = curve0;

          final expectedPoints = [Vector2(0, 0), Vector2(2.5, 2.5), Vector2(5, 5), Vector2(7.5, 7.5), Vector2(10, 10)];

          final actual = curve.getSpacedPoints(4);

          expect(actual.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(actual, expectedPoints, 'Correct points calculated');
        });
      });
    });
  });
}
