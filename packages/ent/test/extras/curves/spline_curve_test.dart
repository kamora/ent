// The reference unit tests of SplineCurve.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('SplineCurve', () {
        final curve0 = SplineCurve([Vector2(-10, 0), Vector2(-5, 5), Vector2(0, 0), Vector2(5, -5), Vector2(10, 0)]);

        // INHERITANCE
        test('Extending', () {
          final object = SplineCurve();
          expect(object, isA<Curve<Vector2>>(), reason: 'SplineCurve extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = SplineCurve();
          expect(object, isNotNull, reason: 'Can instantiate a SplineCurve.');
        });

        // PROPERTIES
        test('type', () {
          final object = SplineCurve();
          expect(object.type == 'SplineCurve', isTrue, reason: 'SplineCurve.type should be SplineCurve');
        });

        // PUBLIC
        test('isSplineCurve', () {
          final object = SplineCurve();
          expect(object.isSplineCurve, isTrue, reason: 'SplineCurve.isSplineCurve should be true');
        });

        // OTHERS
        test('Simple curve', () {
          final curve = curve0;

          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(-6.08, 4.56),
            Vector2(-2, 2.48),
            Vector2(2, -2.48),
            Vector2(6.08, -4.56),
            Vector2(10, 0),
          ];

          var points = curve.getPoints(5);

          expect(points.length, expectedPoints.length, reason: '1st: Correct number of points');

          for (var i = 0; i < points.length; i++) {
            numEqual(points[i].x, expectedPoints[i].x, 'points[$i].x');
            numEqual(points[i].y, expectedPoints[i].y, 'points[$i].y');
          }

          //

          points = curve.getPoints(4);

          deepEqualPoints(points, curve.points, '2nd: Returned points are identical to control points');
        });

        test('getLength/getLengths', () {
          final curve = curve0;

          final length = curve.getLength();
          const expectedLength = 28.876950901868135;

          numEqual(length, expectedLength, 'Correct length of curve');

          final expectedLengths = [0.0, math.sqrt(50), math.sqrt(200), math.sqrt(450), math.sqrt(800)];

          final lengths = curve.getLengths(4);

          expect(lengths, expectedLengths, reason: 'Correct segment lengths');
        });

        test('getPointAt', () {
          final curve = curve0;
          final point = Vector2();

          expect(curve.getPointAt(0, point).equals(curve.points[0]), isTrue, reason: 'PointAt 0.0 correct');
          expect(curve.getPointAt(1, point).equals(curve.points[4]), isTrue, reason: 'PointAt 1.0 correct');

          curve.getPointAt(0.5, point);

          numEqual(point.x, 0.0, 'PointAt 0.5 x correct');
          numEqual(point.y, 0.0, 'PointAt 0.5 y correct');
        });

        test('getTangent', () {
          final curve = curve0;

          final expectedTangent = [
            Vector2(0.7068243340243188, 0.7073891155729485), // 0
            Vector2(0.7069654305325396, -0.7072481035902046), // 0.5
            Vector2(0.7068243340245123, 0.7073891155727552), // 1
          ];

          final tangents = [
            curve.getTangent(0, Vector2()),
            curve.getTangent(0.5, Vector2()),
            curve.getTangent(1, Vector2()),
          ];

          for (var i = 0; i < tangents.length; i++) {
            numEqual(tangents[i].x, expectedTangent[i].x, 'tangent[$i].x');
            numEqual(tangents[i].y, expectedTangent[i].y, 'tangent[$i].y');
          }
        });

        test('getUtoTmapping', () {
          final curve = curve0;

          final start = curve.getUtoTmapping(0, 0);
          final end = curve.getUtoTmapping(0, curve.getLength());
          final middle = curve.getUtoTmapping(0.5, 0);

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(middle, 0.5, 'getUtoTmapping( 0.5, 0 ) is the middle');
        });

        test('getSpacedPoints', () {
          final curve = curve0;

          final expectedPoints = [
            Vector2(-10, 0),
            Vector2(-4.996509634683014, 4.999995128640857),
            Vector2(0, 0),
            Vector2(4.996509634683006, -4.999995128640857),
            Vector2(10, 0),
          ];

          final points = curve.getSpacedPoints(4);

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');

          for (var i = 0; i < points.length; i++) {
            numEqual(points[i].x, expectedPoints[i].x, 'points[$i].x');
            numEqual(points[i].y, expectedPoints[i].y, 'points[$i].y');
          }
        });
      });
    });
  });
}
