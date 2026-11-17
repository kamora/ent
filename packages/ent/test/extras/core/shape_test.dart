// The reference unit tests of Shape, plus regression tests against values computed by the reference source
// (reference/extras_reference.mjs).

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

Shape _shape() {
  final shape = Shape([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]);
  shape.holes.add(Path().moveTo(2, 2).absarc(5, 5, 2, 0, math.pi * 2, true));
  return shape;
}

void main() {
  group('Extras', () {
    group('Core', () {
      group('Shape', () {
        // INHERITANCE
        test('Extending', () {
          final object = Shape();
          expect(object, isA<Path>(), reason: 'Shape extends from Path');
        });

        // INSTANCING
        test('Instancing', () {
          final object = Shape();
          expect(object, isNotNull, reason: 'Can instantiate a Shape.');
        });

        // PROPERTIES
        test('type', () {
          final object = Shape();
          expect(object.type == 'Shape', isTrue, reason: 'Shape.type should be Shape');
        });

        // Regression against the reference.

        test('extractPoints getPointsHoles', () {
          final extracted = _shape().extractPoints(6);
          final expected = reference['shapeExtract'] as Map<String, Object?>;

          closePoints(extracted.shape, expected['shape'], 'shape');
          expect(extracted.holes.length, 1);
          closePoints(extracted.holes[0], (expected['holes'] as List)[0], 'hole');
          closePoints(_shape().getPointsHoles(6)[0], (expected['holes'] as List)[0], 'getPointsHoles');
        });

        test('uuid', () {
          expect(
            Shape().uuid,
            matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
          );
          expect(Shape().uuid, isNot(Shape().uuid));
        });

        test('copy clone toJSON fromJSON', () {
          final shape = _shape();
          final json = shape.toJSON();

          expect(json['uuid'], shape.uuid);
          expect((json['holes'] as List).length, 1);

          final restored = Shape().fromJSON(json);
          expect(restored.uuid, shape.uuid);
          expect(restored.holes.single, isA<Path>());
          expect(restored.toJSON(), json);

          final clone = shape.clone();
          expect(clone.holes.length, 1);
          expect(identical(clone.holes[0], shape.holes[0]), isFalse);
          closePoints(clone.extractPoints(6).shape, (reference['shapeExtract'] as Map)['shape'], 'clone');
        });
      });
    });
  });
}
