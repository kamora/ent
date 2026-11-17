// The reference unit tests of EllipseCurve.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('EllipseCurve', () {
        final curve = EllipseCurve(
          0,
          0, // ax, aY
          10,
          10, // xRadius, yRadius
          0,
          2 * math.pi, // aStartAngle, aEndAngle
          false, // aClockwise
          0, // aRotation
        );

        // INHERITANCE
        test('Extending', () {
          final object = EllipseCurve();
          expect(object, isA<Curve<Vector2>>(), reason: 'EllipseCurve extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = EllipseCurve();
          expect(object, isNotNull, reason: 'Can instantiate an EllipseCurve.');
        });

        // PROPERTIES
        test('type', () {
          final object = EllipseCurve();
          expect(object.type == 'EllipseCurve', isTrue, reason: 'EllipseCurve.type should be EllipseCurve');
        });

        // PUBLIC
        test('isEllipseCurve', () {
          final object = EllipseCurve();
          expect(object.isEllipseCurve, isTrue, reason: 'EllipseCurve.isEllipseCurve should be true');
        });

        // OTHERS
        test('Simple curve', () {
          final expectedPoints = [Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0), Vector2(0, -10), Vector2(10, 0)];

          final points = curve.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');

          for (var i = 0; i < points.length; i++) {
            numEqual(points[i].x, expectedPoints[i].x, 'point[$i].x correct');
            numEqual(points[i].y, expectedPoints[i].y, 'point[$i].y correct');
          }
        });

        test('getLength/getLengths', () {
          final length = curve.getLength();
          const expectedLength = 62.829269247282795;

          numEqual(length, expectedLength, 'Correct length of curve');

          final lengths = curve.getLengths(5);
          final expectedLengths = [
            0.0,
            11.755705045849462,
            23.51141009169892,
            35.26711513754839,
            47.02282018339785,
            58.77852522924731,
          ];

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getPoint/getPointAt', () {
          final testValues = [0.0, 0.3, 0.5, 0.7, 1.0];

          final p = Vector2();
          final a = Vector2();

          for (final val in testValues) {
            final expectedX = math.cos(val * math.pi * 2) * 10;
            final expectedY = math.sin(val * math.pi * 2) * 10;

            curve.getPoint(val, p);
            curve.getPointAt(val, a);

            numEqual(p.x, expectedX, 'getPoint($val).x correct');
            numEqual(p.y, expectedY, 'getPoint($val).y correct');

            numEqual(a.x, expectedX, 'getPointAt($val).x correct');
            numEqual(a.y, expectedY, 'getPointAt($val).y correct');
          }
        });

        test('getTangent', () {
          final expectedTangents = [
            Vector2(-0.000314159260186071, 0.9999999506519786),
            Vector2(-1, 0),
            Vector2(0, -1),
            Vector2(1, 0),
            Vector2(0.00031415926018600165, 0.9999999506519784),
          ];

          final tangents = [
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
        });

        test('getUtoTmapping', () {
          final start = curve.getUtoTmapping(0, 0);
          final end = curve.getUtoTmapping(0, curve.getLength());
          final somewhere = curve.getUtoTmapping(0.7, 1);

          const expectedSomewhere = 0.01591614882650014;

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, expectedSomewhere, 'getUtoTmapping( 0.7, 1 ) is correct');
        });

        test('getSpacedPoints', () {
          final expectedPoints = [
            Vector2(10, 0),
            Vector2(3.0901699437494603, 9.51056516295154),
            Vector2(-8.090169943749492, 5.877852522924707),
            Vector2(-8.090169943749459, -5.877852522924751),
            Vector2(3.0901699437494807, -9.510565162951533),
            Vector2(10, -2.4492935982947065e-15),
          ];

          final points = curve.getSpacedPoints();

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');

          for (var i = 0; i < expectedPoints.length; i++) {
            numEqual(points[i].x, expectedPoints[i].x, 'Point #$i: x correct');
            numEqual(points[i].y, expectedPoints[i].y, 'Point #$i: y correct');
          }
        });
      });
    });
  });
}
