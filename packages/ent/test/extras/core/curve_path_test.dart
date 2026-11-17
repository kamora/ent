// The reference unit tests of CurvePath, plus regression tests against values computed by the reference source
// (reference/extras_reference.mjs).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

CurvePath<Vector3> _closedPath() {
  final cp = CurvePath<Vector3>();
  cp.add(LineCurve3(Vector3(0, 0, 0), Vector3(1, 2, 3)));
  cp.add(CubicBezierCurve3(Vector3(1, 2, 3), Vector3(4, 0, 1), Vector3(2, -2, 5), Vector3(5, 5, 5)));
  cp.closePath();
  cp.autoClose = true;
  return cp;
}

void main() {
  group('Extras', () {
    group('Core', () {
      group('CurvePath', () {
        // INHERITANCE
        test('Extending', () {
          final object = CurvePath<Vector2>();
          expect(object, isA<Curve<Vector2>>(), reason: 'CurvePath extends from Curve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = CurvePath<Vector2>();
          expect(object, isNotNull, reason: 'Can instantiate a CurvePath.');
        });

        // PROPERTIES
        test('type', () {
          final object = Curve<Vector2>();
          expect(object.type == 'Curve', isTrue, reason: 'Curve.type should be Curve');
        });

        // Regression against the reference.

        test('closePath adds a LineCurve3 for 3D paths', () {
          expect(_closedPath().curves.map((c) => c.type).toList(), reference['cpTypes']);
        });

        test('getPoints with autoClose', () {
          closePoints(_closedPath().getPoints(4), reference['cpPoints'], 'getPoints');
        });

        test('getSpacedPoints with autoClose', () {
          closePoints(_closedPath().getSpacedPoints(6), reference['cpSpaced'], 'getSpacedPoints');
        });

        test('getPoint beyond the path returns null', () {
          expect(_closedPath().getPoint(1.5), reference['cpPointBeyond']);
        });

        test('getCurveLengths cacheLengths updateArcLengths', () {
          final cp = _closedPath();
          final lengths = cp.getCurveLengths();
          expect(identical(cp.cacheLengths, lengths), isTrue);
          expect(identical(cp.getCurveLengths(), lengths), isTrue);

          cp.updateArcLengths();
          expect(identical(cp.cacheLengths, lengths), isFalse);
          expect(cp.cacheLengths, lengths);
        });

        test('copy clone toJSON fromJSON', () {
          final cp = _closedPath();
          final json = cp.toJSON();
          final restored = CurvePath<Vector3>().fromJSON(json);

          expect(restored.toJSON(), json);
          expect(restored.curves.map((c) => c.runtimeType).toList(), [LineCurve3, CubicBezierCurve3, LineCurve3]);
          closePoints(restored.getPoints(4), reference['cpPoints'], 'restored');

          final clone = cp.clone();
          expect(clone.autoClose, isTrue);
          expect(identical(clone.curves[0], cp.curves[0]), isFalse);
          expect(clone.toJSON(), json);
        });

        test('fromJSON with an unknown curve type throws', () {
          final json = CurvePath<Vector2>().toJSON()
            ..['curves'] = [
              {'type': 'NoSuchCurve'},
            ];
          expect(() => CurvePath<Vector2>().fromJSON(json), throwsArgumentError);
        });

        test('computeFrenetFrames closed', () {
          final frames = CatmullRomCurve3([
            Vector3(0, 0, 0),
            Vector3(1, 2, 0),
            Vector3(3, 2, 1),
            Vector3(4, 0, 3),
          ], true).computeFrenetFrames(6, true);

          final expected = reference['closedFrames'] as Map<String, Object?>;
          closePoints(frames.tangents, expected['t'], 'tangents');
          closePoints(frames.normals, expected['n'], 'normals');
          closePoints(frames.binormals, expected['b'], 'binormals');
        });
      });
    });
  });
}
