// The reference unit tests of ArcCurve.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Extras', () {
    group('Curves', () {
      group('ArcCurve', () {
        // INHERITANCE
        test('Extending', () {
          final object = ArcCurve();
          expect(object, isA<EllipseCurve>(), reason: 'ArcCurve extends from EllipseCurve');
        });

        // INSTANCING
        test('Instancing', () {
          final object = ArcCurve();
          expect(object, isNotNull, reason: 'Can instantiate an ArcCurve.');
        });

        // PROPERTIES
        test('type', () {
          final object = ArcCurve();
          expect(object.type == 'ArcCurve', isTrue, reason: 'ArcCurve.type should be ArcCurve');
        });

        // PUBLIC
        test('isArcCurve', () {
          final object = ArcCurve();
          expect(object.isArcCurve, isTrue, reason: 'ArcCurve.isArcCurve should be true');
        });
      });
    });
  });
}
