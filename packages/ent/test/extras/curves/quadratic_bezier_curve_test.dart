// The reference unit tests of QuadraticBezierCurve.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('QuadraticBezierCurve', () {
        final curve = QuadraticBezierCurve(Vector2(-10, 0), Vector2(20, 15), Vector2(10, 0));

        // INHERITANCE
        test('Extending', () {
          final object = QuadraticBezierCurve();
          expect(object, isA<Curve<Vector2>>(), reason: 'QuadraticBezierCurve extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = QuadraticBezierCurve();
          expect(object, isNotNull, reason: 'Can instantiate a QuadraticBezierCurve.');
        });

        // PROPERTIES
        test('type', () {
          final object = QuadraticBezierCurve();
          expect(
            object.type == 'QuadraticBezierCurve',
            isTrue,
            reason: 'QuadraticBezierCurve.type should be QuadraticBezierCurve',
          );
        });

        // PUBLIC
        test('isQuadraticBezierCurve', () {
          final object = QuadraticBezierCurve();
          expect(
            object.isQuadraticBezierCurve,
            isTrue,
            reason: 'QuadraticBezierCurve.isQuadraticBezierCurve should be true',
          );
        });

        // OTHERS
        test('Simple curve', () {
          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(2.5, 5.625),
            Vector2(10, 7.5),
            Vector2(12.5, 5.625),
            Vector2(10, 0),
          ];

          var points = curve.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');

          // symmetry
          final curveRev = QuadraticBezierCurve(curve.v2, curve.v1, curve.v0);

          points = curveRev.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Reversed: Correct number of points');
          deepEqualPoints(points, expectedPoints.reversed.toList(), 'Reversed: Correct points curve');
        });

        test('getLength/getLengths', () {
          final length = curve.getLength();
          const expectedLength = 31.269026549416683;

          numEqual(length, expectedLength, 'Correct length of curve');

          final expectedLengths = [0.0, 13.707320124663317, 21.43814317269643, 24.56314317269643, 30.718679298818998];

          final lengths = curve.getLengths(expectedLengths.length - 1);

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getPointAt', () {
          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(-1.5127849599387615, 3.993582003773624),
            Vector2(4.310076165722796, 6.269921971403917),
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
            Vector2(0.89443315420562, 0.44720166888975904),
            Vector2(0.936329177569021, 0.3511234415884543),
            Vector2(1, 0),
            Vector2(-5.921189464667277e-13, -1),
            Vector2(-0.5546617882904897, -0.8320758983472577),
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
            Vector2(0.89443315420562, 0.44720166888975904),
            Vector2(0.9125211423360805, 0.40902954024086674),
            Vector2(0.9480289098765387, 0.3181842014278863),
            Vector2(0.7969127189169473, -0.6040944615111106),
            Vector2(-0.5546617882904897, -0.8320758983472577),
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

          const expectedSomewhere = 0.015073978276116116;

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, expectedSomewhere, 'getUtoTmapping( 0.5, 1 ) is correct');
        });

        test('getSpacedPoints', () {
          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(-4.366603655406173, 2.715408933540383),
            Vector2(1.3752241477827831, 5.191972084404416),
            Vector2(7.312990279153634, 7.136310044848586),
            Vector2(12.499856644824826, 5.653289188715387),
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
