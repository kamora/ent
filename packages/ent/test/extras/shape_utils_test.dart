// Tests of ShapeUtils against values computed by the reference source (reference/extras_reference.mjs). The reference
// has no ShapeUtils test.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Extras', () {
    group('ShapeUtils', () {
      test('area', () {
        final square = [Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)];
        expect(ShapeUtils.area(square), 4);
        expect(ShapeUtils.area(square.reversed.toList()), -4);
        expect(ShapeUtils.area([]), 0);
      });

      test('isClockWise', () {
        final square = [Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)];
        expect(ShapeUtils.isClockWise(square), isFalse);
        expect(ShapeUtils.isClockWise(square.reversed.toList()), isTrue);
      });

      test('triangulateShape', () {
        // The calls of reference/extras_reference.mjs: triangulateShape removes duplicated end points
        // from the given lists, and area/isClockWise then run on the modified lists.
        final shape = Shape([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]);
        shape.holes.add(Path().moveTo(2, 2).absarc(5, 5, 2, 0, math.pi * 2, true));

        final extracted = shape.extractPoints(6);
        final faces = ShapeUtils.triangulateShape(extracted.shape, extracted.holes);

        expect(faces, reference['shapeTriangles']);
        close(ShapeUtils.area(extracted.shape), reference['shapeArea'] as num, 'area');
        expect(ShapeUtils.isClockWise(extracted.holes[0]), reference['holeClockWise']);
      });
    });
  });
}
