// The reference unit tests of QuadraticBezierCurve3.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('QuadraticBezierCurve3', () {
        final curve = QuadraticBezierCurve3(Vector3(-10, 0, 2), Vector3(20, 15, -5), Vector3(10, 0, 10));

        // INHERITANCE
        test('Extending', () {
          final object = QuadraticBezierCurve3();
          expect(object, isA<Curve<Vector3>>(), reason: 'QuadraticBezierCurve3 extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = QuadraticBezierCurve3();
          expect(object, isNotNull, reason: 'Can instantiate a QuadraticBezierCurve3.');
        });

        // PROPERTIES
        test('type', () {
          final object = QuadraticBezierCurve3();
          expect(
            object.type == 'QuadraticBezierCurve3',
            isTrue,
            reason: 'QuadraticBezierCurve3.type should be QuadraticBezierCurve3',
          );
        });

        // PUBLIC
        test('isQuadraticBezierCurve3', () {
          final object = QuadraticBezierCurve3();
          expect(
            object.isQuadraticBezierCurve3,
            isTrue,
            reason: 'QuadraticBezierCurve3.isQuadraticBezierCurve3 should be true',
          );
        });

        // OTHERS
        test('Simple curve', () {
          final expectedPoints = [
            Vector3(-10, 0, 2),
            Vector3(2.5, 5.625, -0.125),
            Vector3(10, 7.5, 0.5),
            Vector3(12.5, 5.625, 3.875),
            Vector3(10, 0, 10),
          ];

          var points = curve.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');

          // symmetry
          final curveRev = QuadraticBezierCurve3(curve.v2, curve.v1, curve.v0);

          points = curveRev.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Reversed: Correct number of points');
          deepEqualPoints(points, expectedPoints.reversed.toList(), 'Reversed: Correct points curve');
        });

        test('getLength/getLengths', () {
          final length = curve.getLength();
          const expectedLength = 35.47294274967861;

          numEqual(length, expectedLength, 'Correct length of curve');

          final expectedLengths = [0.0, 13.871057998581074, 21.62710402732536, 26.226696400568883, 34.91037361704809];

          final lengths = curve.getLengths(expectedLengths.length - 1);

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getPointAt', () {
          final expectedPoints = [
            Vector3(-10, 0, 2),
            Vector3(-0.4981634504454243, 4.427089043881476, 0.19308849757196012),
            Vector3(6.149415812887238, 6.838853310980195, -0.20278120208668637),
            Vector3(10, 0, 10),
          ];

          final points = [
            curve.getPointAt(0, Vector3()),
            curve.getPointAt(0.3, Vector3()),
            curve.getPointAt(0.5, Vector3()),
            curve.getPointAt(1, Vector3()),
          ];

          deepEqualPoints(points, expectedPoints, 'Correct points');
        });

        test('getTangent/getTangentAt', () {
          var expectedTangents = [
            Vector3(0.8755715084258769, 0.4377711603816079, -0.2042815331129452),
            Vector3(0.9340289249885844, 0.3502608468707904, -0.07005216937416067),
            Vector3(0.9284766908853163, 0, 0.37139067635396156),
            Vector3(-3.669031233375946e-13, -0.6196442885791218, 0.7848827655333463),
            Vector3(-0.4263618889888853, -0.6396068005601663, 0.6396238584473043),
          ];

          var tangents = [
            curve.getTangent(0, Vector3()),
            curve.getTangent(0.25, Vector3()),
            curve.getTangent(0.5, Vector3()),
            curve.getTangent(0.75, Vector3()),
            curve.getTangent(1, Vector3()),
          ];

          for (var i = 0; i < expectedTangents.length; i++) {
            numEqual(tangents[i].x, expectedTangents[i].x, 'getTangent #$i: x correct');
            numEqual(tangents[i].y, expectedTangents[i].y, 'getTangent #$i: y correct');
          }

          //

          expectedTangents = [
            Vector3(0.8755715084258769, 0.4377711603816079, -0.2042815331129452),
            Vector3(0.9060725703490549, 0.3984742932857448, -0.14230507668907377),
            Vector3(0.9621604167456882, 0.2688562845452628, 0.044312872940942424),
            Vector3(0.016586454041780826, -0.6163270940470614, 0.7873155674098058),
            Vector3(-0.4263618889888853, -0.6396068005601663, 0.6396238584473043),
          ];

          tangents = [
            curve.getTangentAt(0, Vector3()),
            curve.getTangentAt(0.25, Vector3()),
            curve.getTangentAt(0.5, Vector3()),
            curve.getTangentAt(0.75, Vector3()),
            curve.getTangentAt(1, Vector3()),
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

          const expectedSomewhere = 0.014760890927167196;

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, expectedSomewhere, 'getUtoTmapping( 0.5, 1 ) is correct');
        });

        test('getSpacedPoints', () {
          final expectedPoints = [
            Vector3(-10, 0, 2),
            Vector3(-3.712652983516992, 3.015179001762753, 0.6957120710270492),
            Vector3(2.7830973773262975, 5.730399338061483, -0.1452668772806931),
            Vector3(9.575825284074465, 7.48754187603603, 0.3461104039841496),
            Vector3(12.345199937734154, 4.575759904730531, 5.142117429101656),
            Vector3(10, 0, 10),
          ];

          final points = curve.getSpacedPoints();

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');
        });

        test('computeFrenetFrames', () {
          final expected = {
            'binormals': [
              Vector3(-0.447201668889759, 0.8944331542056199, 0),
              Vector3(-0.2684231751110917, 0.9631753839815436, -0.01556209353802903),
              Vector3(0.3459273556592433, 0.53807011680075, 0.7686447905324219),
            ],
            'normals': [
              Vector3(-0.18271617600817133, -0.09135504253146765, -0.9789121795283909),
              Vector3(0.046865035058597876, -0.003078628350883253, -0.9988964863970807),
              Vector3(0.8357929194629689, -0.5489842348221077, 0.008155102228190641),
            ],
            'tangents': [
              Vector3(0.8755715084258767, 0.4377711603816078, -0.20428153311294514),
              Vector3(0.9621604167456884, 0.26885628454526284, 0.04431287294094243),
              Vector3(-0.4263618889888853, -0.6396068005601663, 0.6396238584473043),
            ],
          };

          final frames = curve.computeFrenetFrames(2, false);
          final actual = {'binormals': frames.binormals, 'normals': frames.normals, 'tangents': frames.tangents};

          var i = 0;

          for (final group in expected.keys) {
            for (var j = 0; j < expected[group]!.length; j++) {
              final vec = expected[group]![j];
              numEqual(actual[group]![j].x, vec.x, 'Frenet frames [$i, $j].x correct');
              numEqual(actual[group]![j].y, vec.y, 'Frenet frames [$i, $j].y correct');
              numEqual(actual[group]![j].z, vec.z, 'Frenet frames [$i, $j].z correct');
            }

            i++;
          }
        });
      });
    });
  });
}
