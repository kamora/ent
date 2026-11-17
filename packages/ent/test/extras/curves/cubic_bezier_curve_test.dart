// The reference unit tests of CubicBezierCurve.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('CubicBezierCurve', () {
        final curve = CubicBezierCurve(Vector2(-10, 0), Vector2(-5, 15), Vector2(20, 15), Vector2(10, 0));

        // INHERITANCE
        test('Extending', () {
          final object = CubicBezierCurve();
          expect(object, isA<Curve<Vector2>>(), reason: 'CubicBezierCurve extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = CubicBezierCurve();
          expect(object, isNotNull, reason: 'Can instantiate a CubicBezierCurve.');
        });

        // PROPERTIES
        test('type', () {
          final object = CubicBezierCurve();
          expect(object.type == 'CubicBezierCurve', isTrue, reason: 'CubicBezierCurve.type should be CubicBezierCurve');
        });

        // PUBLIC
        test('isCubicBezierCurve', () {
          final object = CubicBezierCurve();
          expect(object.isCubicBezierCurve, isTrue, reason: 'CubicBezierCurve.isCubicBezierCurve should be true');
        });

        // OTHERS
        test('Simple curve', () {
          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(-3.359375, 8.4375),
            Vector2(5.625, 11.25),
            Vector2(11.796875, 8.4375),
            Vector2(10, 0),
          ];

          var points = curve.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');

          // symmetry
          final curveRev = CubicBezierCurve(curve.v3, curve.v2, curve.v1, curve.v0);

          points = curveRev.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Reversed: Correct number of points');
          deepEqualPoints(points, expectedPoints.reversed.toList(), 'Reversed: Correct points curve');
        });

        test('getLength/getLengths', () {
          final length = curve.getLength();
          const expectedLength = 36.64630888504102;

          numEqual(length, expectedLength, 'Correct length of curve');

          final expectedLengths = [0.0, 10.737285813492393, 20.15159143794633, 26.93408340370825, 35.56079575637337];

          final lengths = curve.getLengths(expectedLengths.length - 1);

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getPointAt', () {
          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(-3.3188282598022596, 8.463722639089221),
            Vector2(3.4718554735926617, 11.07899406116314),
            Vector2(10, 0),
          ];

          final points = [
            curve.getPointAt(0, Vector2()),
            curve.getPointAt(0.3, Vector2()),
            curve.getPointAt(0.5, Vector2()),
            curve.getPointAt(1, Vector2()),
          ];

          deepEqualPoints(points, expectedPoints, 'Correct points');
        });

        test('getTangent/getTangentAt', () {
          var expectedTangents = [
            Vector2(0.316370061632252, 0.9486358543207215),
            Vector2(0.838961283088303, 0.5441911111721949),
            Vector2(1, 0),
            Vector2(0.47628313192245453, -0.8792919755383518),
            Vector2(-0.5546041767829665, -0.8321142992972107),
          ];

          var tangents = [
            curve.getTangent(0, Vector2()),
            curve.getTangent(0.25, Vector2()),
            curve.getTangent(0.5, Vector2()),
            curve.getTangent(0.75, Vector2()),
            curve.getTangent(1, Vector2()),
          ];

          for (var i = 0; i < expectedTangents.length; i++) {
            numEqual(tangents[i].x, expectedTangents[i].x, 'getTangent #$i: x correct');
            numEqual(tangents[i].y, expectedTangents[i].y, 'getTangent #$i: y correct');
          }

          //

          expectedTangents = [
            Vector2(0.316370061632252, 0.9486358543207215),
            Vector2(0.7794223085548987, 0.6264988945935596),
            Vector2(0.988266153082452, 0.15274164681452052),
            Vector2(0.5004110404199416, -0.8657879593906534),
            Vector2(-0.5546041767829665, -0.8321142992972107),
          ];

          tangents = [
            curve.getTangentAt(0, Vector2()),
            curve.getTangentAt(0.25, Vector2()),
            curve.getTangentAt(0.5, Vector2()),
            curve.getTangentAt(0.75, Vector2()),
            curve.getTangentAt(1, Vector2()),
          ];

          for (var i = 0; i < expectedTangents.length; i++) {
            numEqual(tangents[i].x, expectedTangents[i].x, 'getTangentAt #$i: x correct');
            numEqual(tangents[i].y, expectedTangents[i].y, 'getTangentAt #$i: y correct');
          }
        });

        test('getUtoTmapping', () {
          final start = curve.getUtoTmapping(0, 0);
          final end = curve.getUtoTmapping(0, curve.getLength());
          final somewhere = curve.getUtoTmapping(0.5, 1);

          const expectedSomewhere = 0.02130029182257093;

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, expectedSomewhere, 'getUtoTmapping( 0.5, 1 ) is correct');
        });

        test('getSpacedPoints', () {
          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(-6.16826457740703, 6.17025727295411),
            Vector2(-0.058874033259857184, 10.1240558653185),
            Vector2(7.123523032625162, 11.154913869041575),
            Vector2(12.301846885754463, 6.808865855469985),
            Vector2(10, 0),
          ];

          final points = curve.getSpacedPoints();

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');
        });
      });
    });
  });
}
