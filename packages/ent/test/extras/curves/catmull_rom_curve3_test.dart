// The reference unit tests of CatmullRomCurve3.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void checkPoints(List<Vector3> points, List<Vector3> expectedPoints) {
  expect(points.length, expectedPoints.length, reason: 'correct number of points.');

  for (var i = 0; i < points.length; i++) {
    numEqual(points[i].x, expectedPoints[i].x, 'points[$i].x');
    numEqual(points[i].y, expectedPoints[i].y, 'points[$i].y');
    numEqual(points[i].z, expectedPoints[i].z, 'points[$i].z');
  }
}

void main() {
  group('Extras', () {
    group('Curves', () {
      group('CatmullRomCurve3', () {
        final positions = [
          Vector3(-60, -100, 60),
          Vector3(-60, 20, 60),
          Vector3(-60, 120, 60),
          Vector3(60, 20, -60),
          Vector3(60, -100, -60),
        ];

        // INHERITANCE
        test('Extending', () {
          final object = CatmullRomCurve3();
          expect(object, isA<Curve<Vector3>>(), reason: 'CatmullRomCurve3 extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = CatmullRomCurve3();
          expect(object, isNotNull, reason: 'Can instantiate a CatmullRomCurve3.');
        });

        // PROPERTIES
        test('type', () {
          final object = CatmullRomCurve3();
          expect(object.type == 'CatmullRomCurve3', isTrue, reason: 'CatmullRomCurve3.type should be CatmullRomCurve3');
        });

        // PUBLIC
        test('isCatmullRomCurve3', () {
          final object = CatmullRomCurve3();
          expect(object.isCatmullRomCurve3, isTrue, reason: 'CatmullRomCurve3.isCatmullRomCurve3 should be true');
        });

        // OTHERS
        test('catmullrom check', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';

          final expectedPoints = [
            Vector3(-60, -100, 60),
            Vector3(-60, -51.04, 60),
            Vector3(-60, -2.7199999999999998, 60),
            Vector3(-61.92, 44.48, 61.92),
            Vector3(-68.64, 95.36000000000001, 68.64),
            Vector3(-60, 120, 60),
            Vector3(-14.880000000000017, 95.36000000000001, 14.880000000000017),
            Vector3(41.75999999999997, 44.48000000000003, -41.75999999999997),
            Vector3(67.68, -2.720000000000023, -67.68),
            Vector3(65.75999999999999, -51.04000000000001, -65.75999999999999),
            Vector3(60, -100, -60),
          ];

          checkPoints(curve.getPoints(10), expectedPoints);
        });

        test('chordal basic check', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'chordal';

          final expectedPoints = [
            Vector3(-60, -100, 60),
            Vector3(-60, -52, 60),
            Vector3(-60, -4, 60),
            Vector3(-60.656435889910924, 41.62455386421379, 60.656435889910924),
            Vector3(-62.95396150459915, 87.31049238896205, 62.95396150459915),
            Vector3(-60, 120, 60),
            Vector3(-16.302568199486444, 114.1500463116312, 16.302568199486444),
            Vector3(42.998098664956586, 54.017050116427455, -42.998098664956586),
            Vector3(63.542500175682434, -1.137153397546383, -63.542500175682434),
            Vector3(62.65687513176183, -49.85286504815978, -62.65687513176183),
            Vector3(60.00000000000001, -100, -60.00000000000001),
          ];

          checkPoints(curve.getPoints(10), expectedPoints);
        });

        test('centripetal basic check', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'centripetal';

          final expectedPoints = [
            Vector3(-60, -100, 60),
            Vector3(-60, -51.47527724919028, 60),
            Vector3(-60, -3.300369665587032, 60),
            Vector3(-61.13836565863938, 42.86306307781241, 61.13836565863938),
            Vector3(-65.1226454638772, 90.69743905511538, 65.1226454638772),
            Vector3(-60, 120, 60),
            Vector3(-15.620412575504497, 103.10790870179872, 15.620412575504497),
            Vector3(42.384384731047874, 48.35477686933143, -42.384384731047874),
            Vector3(65.25545512241153, -1.646250966068339, -65.25545512241153),
            Vector3(63.94159134180865, -50.234688224551256, -63.94159134180865),
            Vector3(59.99999999999999, -100, -59.99999999999999),
          ];

          checkPoints(curve.getPoints(10), expectedPoints);
        });

        test('closed catmullrom basic check', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';
          curve.closed = true;

          final expectedPoints = [
            Vector3(-60, -100, 60),
            Vector3(-67.5, -46.25, 67.5),
            Vector3(-60, 20, 60),
            Vector3(-67.5, 83.75, 67.5),
            Vector3(-60, 120, 60),
            Vector3(0, 83.75, 0),
            Vector3(60, 20, -60),
            Vector3(75, -46.25, -75),
            Vector3(60, -100, -60),
            Vector3(0, -115, 0),
            Vector3(-60, -100, 60),
          ];

          checkPoints(curve.getPoints(10), expectedPoints);
        });

        //
        // curve.type = 'catmullrom'; only from here on
        //
        test('getLength/getLengths', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';

          final length = curve.getLength();
          const expectedLength = 551.549686276872;

          numEqual(length, expectedLength, 'Correct length of curve');

          final expectedLengths = [0.0, 120.0, 220.0, 416.9771560359221, 536.9771560359221];

          final lengths = curve.getLengths(expectedLengths.length - 1);

          expect(lengths.length, expectedLengths.length, reason: 'Correct number of segments');

          for (var i = 0; i < lengths.length; i++) {
            numEqual(lengths[i], expectedLengths[i], 'segment[$i] correct');
          }
        });

        test('getPointAt', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';

          final expectedPoints = [
            Vector3(-60, -100, 60),
            Vector3(-64.84177333183106, 64.86956465359813, 64.84177333183106),
            Vector3(-28.288507045700854, 104.83101184518996, 28.288507045700854),
            Vector3(60, -100, -60),
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
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';

          var expectedTangents = [
            Vector3(0, 1, 0),
            Vector3(-0.0001090274561657922, 0.9999999881130137, 0.0001090274561657922),
            Vector3(0.7071067811865475, -2.0930381713877622e-13, -0.7071067811865475),
            Vector3(0.43189437062802816, -0.7917919583070032, -0.43189437062802816),
            Vector3(-0.00019991333100812723, -0.9999999600346592, 0.00019991333100812723),
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
            Vector3(0, 1, 0),
            Vector3(-0.10709018822205997, 0.9884651653817284, 0.10709018822205997),
            Vector3(0.6396363672964268, -0.4262987629159402, -0.6396363672964268),
            Vector3(0.5077298411616501, -0.6960034603275557, -0.5077298411616501),
            Vector3(-0.00019991333100812723, -0.9999999600346592, 0.00019991333100812723),
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

        test('computeFrenetFrames', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';

          final expected = {
            'binormals': [
              Vector3(-1, 0, 0),
              Vector3(-0.28685061854203, 0.6396363672964267, -0.7131493814579701),
              Vector3(-1.9982670528160395e-8, -0.0001999133310081272, -0.9999999800173295),
            ],
            'normals': [
              Vector3(0, 0, -1),
              Vector3(-0.7131493814579699, -0.6396363672964268, -0.2868506185420297),
              Vector3(-0.9999999800173294, 0.00019991333100810582, -1.99826701852146e-8),
            ],
            'tangents': [
              Vector3(0, 1, 0),
              Vector3(0.6396363672964269, -0.4262987629159403, -0.6396363672964269),
              Vector3(-0.0001999133310081273, -0.9999999600346594, 0.0001999133310081273),
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

        test('getUtoTmapping', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';

          final start = curve.getUtoTmapping(0, 0);
          final end = curve.getUtoTmapping(0, curve.getLength());
          final somewhere = curve.getUtoTmapping(0.5, 500);

          const expectedSomewhere = 0.8964116382083199;

          expect(start, 0, reason: 'getUtoTmapping( 0, 0 ) is the starting point');
          expect(end, 1, reason: 'getUtoTmapping( 0, length ) is the ending point');
          numEqual(somewhere, expectedSomewhere, 'getUtoTmapping( 0.5, 500 ) is correct');
        });

        test('getSpacedPoints', () {
          final curve = CatmullRomCurve3(positions);
          curve.curveType = 'catmullrom';

          final expectedPoints = [
            Vector3(-60, -100, 60),
            Vector3(-60, 10.311489426555056, 60),
            Vector3(-65.05889864636504, 117.99691802595966, 65.05889864636504),
            Vector3(6.054276900088592, 78.7153118386369, -6.054276900088592),
            Vector3(64.9991491385602, 8.386980812799566, -64.9991491385602),
            Vector3(60, -100, -60),
          ];

          final points = curve.getSpacedPoints();

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');
        });

        test('two points', () {
          final curve = CatmullRomCurve3([Vector3(0, 0, 0), Vector3(10, 0, 0)], false, 'catmullrom');

          final expectedPoints = [Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(10, 0, 0)];

          final points = curve.getPoints(2);

          expect(points.length, expectedPoints.length, reason: 'Correct number of points');
          deepEqualPoints(points, expectedPoints, 'Correct points calculated');
        });
      });
    });
  });
}
