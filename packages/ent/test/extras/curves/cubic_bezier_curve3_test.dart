// The reference unit tests of CubicBezierCurve3.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('CubicBezierCurve3', () {
        final curve = CubicBezierCurve3(
          Vector3(-10, 0, 2),
          Vector3(-5, 15, 4),
          Vector3(20, 15, -5),
          Vector3(10, 0, 10),
        );

        // INHERITANCE
        test('Extending', () {
          final object = CubicBezierCurve3();
          expect(object, isA<Curve<Vector3>>(), reason: 'CubicBezierCurve3 extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = CubicBezierCurve3();
          expect(object, isNotNull, reason: 'Can instantiate a CubicBezierCurve3.');
        });

        // PROPERTIES
        test('type', () {
          final object = CubicBezierCurve3();
          expect(
            object.type == 'CubicBezierCurve3',
            isTrue,
            reason: 'CubicBezierCurve3.type should be CubicBezierCurve3',
          );
        });

        // PUBLIC
        test('isCubicBezierCurve3', () {
          final object = CubicBezierCurve3();
          expect(object.isCubicBezierCurve3, isTrue, reason: 'CubicBezierCurve3.isCubicBezierCurve3 should be true');
        });

        // OTHERS
        test('Simple curve', () {
          final expectedPoints = [
            Vector3(-10, 0, 2),
            Vector3(-3.359375, 8.4375, 1.984375),
            Vector3(5.625, 11.25, 1.125),
            Vector3(11.796875, 8.4375, 2.703125),
            Vector3(10, 0, 10),
          ];

          var points = curve.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');

          // symmetry
          final curveRev = CubicBezierCurve3(curve.v3, curve.v2, curve.v1, curve.v0);

          points = curveRev.getPoints(expectedPoints.length - 1);

          expect(points.length, expectedPoints.length, reason: 'Reversed: Correct number of points');
          deepEqualPoints(points, expectedPoints.reversed.toList(), 'Reversed: Correct points curve');
        });

        test('getLength/getLengths', () {
          final length = curve.getLength();
          const expectedLength = 39.58103024989427;

          numEqual(length, expectedLength, 'Correct length of curve');

          final expectedLengths = [0.0, 10.73729718231036, 20.19074500737662, 27.154413277853756, 38.453287150114214];

          final lengths = curve.getLengths(expectedLengths.length - 1);

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getPointAt', () {
          final expectedPoints = [
            Vector3(-10, 0, 2),
            Vector3(-2.591880240484318, 8.908333501170798, 1.8953420625251136),
            Vector3(4.866251460832755, 11.22787914038507, 1.150832855206874),
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
            Vector3(0.3138715439944244, 0.9411440474105875, 0.12542940601858074),
            Vector3(0.8351825262580098, 0.54174002562179, -0.09480449605683638),
            Vector3(0.9997531780538501, 0, -0.02221672728433752),
            Vector3(0.40693407933981185, -0.7512629496079668, 0.5196235518317053),
            Vector3(-0.42632467075185815, -0.6396469221230213, 0.6396085444448543),
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
            Vector3(0.3138715439944244, 0.9411440474105875, 0.12542940601858074),
            Vector3(0.8016539573770751, 0.5918626760037707, -0.08396133262002324),
            Vector3(0.997337559412928, 0.05740742907719314, -0.044968652092444425),
            Vector3(0.1389373097746809, -0.7882209938358005, 0.5995032016837588),
            Vector3(-0.42632467075185815, -0.6396469221230213, 0.6396085444448543),
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

          const expectedSomewhere = 0.021163245321323316;

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, expectedSomewhere, 'getUtoTmapping( 0.5, 1 ) is correct');
        });

        test('getSpacedPoints', () {
          final expectedPoints = [
            Vector3(-10, 0, 2),
            Vector3(-5.756524515061918, 6.568020242700483, 2.22116711170301),
            Vector3(1.0003511895116906, 10.49656064587831, 1.4727101010850698),
            Vector3(8.767656412295171, 10.784286845278622, 1.2873599519775174),
            Vector3(12.306772513558396, 5.545103788071547, 4.909948454535794),
            Vector3(10, 0, 10),
          ];

          final points = curve.getSpacedPoints();

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');
        });

        test('computeFrenetFrames', () {
          final expected = {
            'binormals': [
              Vector3(-0.9486358543207215, 0.316370061632252, -6.938893903907228e-18),
              Vector3(-0.05491430765311864, 0.9969838307670049, 0.054842137122173326),
              Vector3(0.5944656510461876, 0.334836503700931, 0.7310917216844742),
            ],
            'normals': [
              Vector3(0.03968210891259515, 0.11898683173537697, -0.9921025471723304),
              Vector3(-0.047981365124836806, 0.05222670079466692, -0.9974819097732357),
              Vector3(0.6818048583242511, -0.6919077473246573, -0.23749906180354932),
            ],
            'tangents': [
              Vector3(0.3138715439944244, 0.9411440474105875, 0.12542940601858074),
              Vector3(0.9973375594129282, 0.05740742907719315, -0.04496865209244443),
              Vector3(-0.42632467075185815, -0.6396469221230213, 0.6396085444448543),
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
