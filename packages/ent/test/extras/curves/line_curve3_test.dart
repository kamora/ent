// The reference unit tests of LineCurve3.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('LineCurve3', () {
        final points = [Vector3(0, 0, 0), Vector3(10, 10, 10), Vector3(-10, 10, -10), Vector3(-8, 5, -7)];
        final curve0 = LineCurve3(points[0], points[1]);

        // INHERITANCE
        test('Extending', () {
          final object = LineCurve3();
          expect(object, isA<Curve<Vector3>>(), reason: 'LineCurve3 extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = LineCurve3();
          expect(object, isNotNull, reason: 'Can instantiate a LineCurve3.');
        });

        // PROPERTIES
        test('type', () {
          final object = LineCurve3();
          expect(object.type == 'LineCurve3', isTrue, reason: 'LineCurve3.type should be LineCurve3');
        });

        // PUBLIC
        test('isLineCurve3', () {
          final object = LineCurve3();
          expect(object.isLineCurve3, isTrue, reason: 'LineCurve3.isLineCurve3 should be true');
        });

        test('getPointAt', () {
          final curve = LineCurve3(points[0], points[3]);

          final expectedPoints = [
            Vector3(0, 0, 0),
            Vector3(-2.4, 1.5, -2.1),
            Vector3(-4, 2.5, -3.5),
            Vector3(-8, 5, -7),
          ];

          final actual = [
            curve.getPointAt(0, Vector3()),
            curve.getPointAt(0.3, Vector3()),
            curve.getPointAt(0.5, Vector3()),
            curve.getPointAt(1, Vector3()),
          ];

          deepEqualPoints(actual, expectedPoints, 'Correct getPointAt points');
        });

        // OTHERS
        test('Simple curve', () {
          var curve = curve0;

          var expectedPoints = [
            Vector3(0, 0, 0),
            Vector3(2, 2, 2),
            Vector3(4, 4, 4),
            Vector3(6, 6, 6),
            Vector3(8, 8, 8),
            Vector3(10, 10, 10),
          ];

          var actual = curve.getPoints();

          deepEqualPoints(actual, expectedPoints, 'Correct points for first curve');

          //

          curve = LineCurve3(points[1], points[2]);

          expectedPoints = [
            Vector3(10, 10, 10),
            Vector3(6, 10, 6),
            Vector3(2, 10, 2),
            Vector3(-2, 10, -2),
            Vector3(-6, 10, -6),
            Vector3(-10, 10, -10),
          ];

          actual = curve.getPoints();

          deepEqualPoints(actual, expectedPoints, 'Correct points for second curve');
        });

        test('getLength/getLengths', () {
          final curve = curve0;

          final length = curve.getLength();
          final expectedLength = math.sqrt(300);

          numEqual(length, expectedLength, 'Correct length of curve');

          final lengths = curve.getLengths(5);
          final expectedLengths = [0.0, math.sqrt(12), math.sqrt(48), math.sqrt(108), math.sqrt(192), math.sqrt(300)];

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getTangent/getTangentAt', () {
          final curve = curve0;
          var tangent = Vector3();

          curve.getTangent(0.5, tangent);
          final expectedTangent = math.sqrt(1 / 3);

          numEqual(tangent.x, expectedTangent, 'tangent.x correct');
          numEqual(tangent.y, expectedTangent, 'tangent.y correct');
          numEqual(tangent.z, expectedTangent, 'tangent.z correct');

          tangent = curve.getTangentAt(0.5);

          numEqual(tangent.x, expectedTangent, 'tangentAt.x correct');
          numEqual(tangent.y, expectedTangent, 'tangentAt.y correct');
          numEqual(tangent.z, expectedTangent, 'tangentAt.z correct');
        });

        test('computeFrenetFrames', () {
          final curve = curve0;

          final expected = {
            'binormals': Vector3(-0.5 * math.sqrt(2), 0.5 * math.sqrt(2), 0),
            'normals': Vector3(math.sqrt(1 / 6), math.sqrt(1 / 6), -math.sqrt(2 / 3)),
            'tangents': Vector3(math.sqrt(1 / 3), math.sqrt(1 / 3), math.sqrt(1 / 3)),
          };

          final frames = curve.computeFrenetFrames(1, false);
          final actual = {'binormals': frames.binormals, 'normals': frames.normals, 'tangents': frames.tangents};

          for (final val in expected.keys) {
            numEqual(actual[val]![0].x, expected[val]!.x, 'Frenet frames $val.x correct');
            numEqual(actual[val]![0].y, expected[val]!.y, 'Frenet frames $val.y correct');
            numEqual(actual[val]![0].z, expected[val]!.z, 'Frenet frames $val.z correct');
          }
        });

        test('getUtoTmapping', () {
          final curve = curve0;

          final start = curve.getUtoTmapping(0, 0);
          final end = curve.getUtoTmapping(0, curve.getLength());
          final somewhere = curve.getUtoTmapping(0.7, 0);

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, 0.7, 'getUtoTmapping( 0.7, 0 ) is correct');
        });

        test('getSpacedPoints', () {
          final curve = curve0;

          final expectedPoints = [
            Vector3(0, 0, 0),
            Vector3(2.5, 2.5, 2.5),
            Vector3(5, 5, 5),
            Vector3(7.5, 7.5, 7.5),
            Vector3(10, 10, 10),
          ];

          final actual = curve.getSpacedPoints(4);

          expect(actual.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(actual, expectedPoints, 'Correct points calculated');
        });
      });
    });
  });
}
