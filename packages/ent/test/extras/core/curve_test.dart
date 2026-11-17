// The reference unit tests of Curve, plus Dart tests derived from the source.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support.dart';

void main() {
  group('Extras', () {
    group('Core', () {
      group('Curve', () {
        // INSTANCING
        test('Instancing', () {
          final object = Curve<Vector2>();
          expect(object, isNotNull, reason: 'Can instantiate a Curve.');
        });

        // PROPERTIES
        test('type', () {
          final object = Curve<Vector2>();
          expect(object.type == 'Curve', isTrue, reason: 'Curve.type should be Curve');
        });

        // Dart tests derived from the reference source.

        test('getPoint warns and returns null on the base class', () {
          final messages = <String>[];
          setConsoleFunction((type, message, params) => messages.add('$type $message'));
          addTearDown(() => setConsoleFunction(null));

          expect(Curve<Vector2>().getPoint(0.5), isNull);
          expect(messages, ['warn ENT.Curve: .getPoint() not implemented.']);
        });

        test('arcLengthDivisions needsUpdate updateArcLengths cacheArcLengths', () {
          final curve = LineCurve(Vector2(0, 0), Vector2(3, 4));

          expect(curve.arcLengthDivisions, 200);
          expect(curve.needsUpdate, isFalse);
          expect(curve.cacheArcLengths, isNull);

          final lengths = curve.getLengths();
          expect(lengths.length, 201);
          expect(identical(curve.cacheArcLengths, lengths), isTrue);
          expect(identical(curve.getLengths(), lengths), isTrue, reason: 'cached');

          curve.v2.set(6, 8);
          curve.updateArcLengths();
          expect(curve.needsUpdate, isFalse);
          close(curve.getLength(), 10);
        });

        test('getUtoTmapping outside [0, 1] reads past the lengths like JavaScript (NaN)', () {
          final curve = LineCurve(Vector2(0, 0), Vector2(1, 0));
          expect(curve.getUtoTmapping(-0.5).isNaN, isTrue);
          expect(curve.getUtoTmapping(1.5).isNaN, isTrue);
        });

        test('copy clone toJSON fromJSON', () {
          final curve = EllipseCurve(1, 2, 3, 4, 0.5, 2, true, 0.25)..arcLengthDivisions = 50;
          final json = curve.toJSON();

          expect(json['metadata'], {'version': 4.7, 'type': 'Curve', 'generator': 'Curve.toJSON'});
          expect(json['type'], 'EllipseCurve');
          expect(json['arcLengthDivisions'], 50);

          final copy = EllipseCurve().fromJSON(json);
          expect(copy.toJSON(), json);

          final clone = curve.clone();
          expect(clone, isA<EllipseCurve>());
          expect(clone.toJSON(), json);
        });
      });
    });
  });
}
