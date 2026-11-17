// The reference unit tests of ShapePath, plus regression tests of toShapes against values computed by the reference
// source (reference/extras_reference.mjs).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

/// The subpaths of reference/extras_reference.mjs: an outer square, a hole, an island in the hole, a separate
/// square with a same-winding square inside, and a degenerate path.
List<Shape> _shapes([String? fillRule]) {
  final s = ShapePath();

  if (fillRule != null) {
    s.userData['style'] = {'fillRule': fillRule};
  }

  void rect(double x0, double y0, double x1, double y1, bool cw) {
    s.moveTo(x0, y0);

    if (cw) {
      s.lineTo(x0, y1).lineTo(x1, y1).lineTo(x1, y0).lineTo(x0, y0);
    } else {
      s.lineTo(x1, y0).lineTo(x1, y1).lineTo(x0, y1).lineTo(x0, y0);
    }
  }

  rect(0, 0, 20, 20, false); // outer CCW
  rect(4, 4, 16, 16, true); // hole CW
  rect(7, 7, 13, 13, false); // island CCW
  rect(30, 0, 40, 10, false); // separate
  rect(32, 2, 38, 8, false); // same winding inside separate
  s.moveTo(50, 50).lineTo(51, 51); // degenerate

  return s.toShapes();
}

void _same(List<Shape> shapes, Object? expected) {
  final list = (expected as List).cast<Map<String, Object?>>();
  expect(shapes.length, list.length, reason: 'shape count');

  for (var i = 0; i < shapes.length; i++) {
    closePoints(shapes[i].getPoints(), list[i]['points'], 'shape[$i]');

    final holes = (list[i]['holes'] as List);
    expect(shapes[i].holes.length, holes.length, reason: 'shape[$i] holes');

    for (var j = 0; j < holes.length; j++) {
      closePoints(shapes[i].holes[j].getPoints(), holes[j], 'shape[$i].hole[$j]');
    }
  }
}

void main() {
  group('Extras', () {
    group('Core', () {
      group('ShapePath', () {
        // INSTANCING
        test('Instancing', () {
          final object = ShapePath();
          expect(object, isNotNull, reason: 'Can instantiate a ShapePath.');
        });

        // PROPERTIES
        test('type', () {
          final object = ShapePath();
          expect(object.type == 'ShapePath', isTrue, reason: 'ShapePath.type should be ShapePath');
        });

        // Regression against the reference.

        test('toShapes nonzero', () {
          _same(_shapes(), reference['toShapesNonzero']);
        });

        test('toShapes evenodd', () {
          _same(_shapes('evenodd'), reference['toShapesEvenodd']);
        });

        test('toShapes with an unsupported fill rule warns and uses nonzero', () {
          final messages = <String>[];
          setConsoleFunction((type, message, params) => messages.add('$type $message'));
          addTearDown(() => setConsoleFunction(null));

          _same(_shapes('weird'), reference['toShapesBadRule']);
          expect(messages, ['warn ENT.Fill-rule "weird" is not supported, falling back to "nonzero".']);
        });

        test('moveTo lineTo quadraticCurveTo bezierCurveTo splineThru subPaths currentPath', () {
          final s = ShapePath()
              .moveTo(0, 0)
              .lineTo(1, 0)
              .quadraticCurveTo(2, 1, 1, 2)
              .bezierCurveTo(0, 3, -1, 2, -1, 1)
              .splineThru([Vector2(-0.5, 0.5), Vector2(0, 0)]);

          expect(s.subPaths.length, 1);
          expect(identical(s.currentPath, s.subPaths[0]), isTrue);
          expect(s.currentPath!.curves.map((c) => c.type).toList(), [
            'LineCurve',
            'QuadraticBezierCurve',
            'CubicBezierCurve',
            'SplineCurve',
          ]);
          expect(s.color, isA<Color>());
          expect(s.userData, isEmpty);
        });

        test('lineTo without moveTo throws, as the reference does on a null currentPath', () {
          expect(() => ShapePath().lineTo(1, 1), throwsA(isA<TypeError>()));
        });
      });
    });
  });
}
