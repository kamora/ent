// The reference unit tests of BoxGeometry.

import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'geometry_helpers.dart';

/// `geometry._transformed`, library-private in Dart (exception E-PRIVATE).
bool _transformed(BufferGeometry geometry) {
  final library = reflectClass(BufferGeometry).owner as LibraryMirror;
  return reflect(geometry).getField(MirrorSystem.getSymbol('_transformed', library)).reflectee as bool;
}

void main() {
  group('Geometries', () {
    group('BoxGeometry', () {
      late List<BufferGeometry> geometries;

      setUp(() {
        geometries = [BoxGeometry(), BoxGeometry(10, 20, 30), BoxGeometry(10, 20, 30, 2, 3, 4)];
      });

      // INHERITANCE

      test('Extending', () {
        final object = BoxGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'BoxGeometry extends from BufferGeometry');
      });

      // INSTANCING

      test('Instancing', () {
        final object = BoxGeometry();
        expect(object, isNotNull, reason: 'Can instantiate a BoxGeometry.');
      });

      // PROPERTIES

      test('type', () {
        final object = BoxGeometry();
        expect(object.type, 'BoxGeometry', reason: 'BoxGeometry.type should be BoxGeometry');
      });

      // OTHERS

      test('Standard geometry tests', () {
        runStdGeometryTests(geometries, BoxGeometry.fromJSON);
      });

      test('toJSON: parametric serialization for untransformed geometry', () {
        final geometry = BoxGeometry(10, 20, 30);
        final json = geometry.toJSON();

        expect(_transformed(geometry), isFalse, reason: '_transformed defaults to false');
        expect(json['type'], 'BoxGeometry', reason: 'type is preserved');
        expect(json['width'], 10, reason: 'width is serialized');
        expect(json['height'], 20, reason: 'height is serialized');
        expect(json['depth'], 30, reason: 'depth is serialized');
        expect(json.containsKey('data'), isFalse, reason: 'attribute data is not serialized');
      });

      test('toJSON: attribute serialization after translate()', () {
        final geometry = BoxGeometry(10, 20, 30);
        geometry.translate(1, 2, 3);
        final json = geometry.toJSON();

        expect(_transformed(geometry), isTrue, reason: '_transformed is true after translate()');
        expect(json['type'], 'BufferGeometry', reason: 'type is downgraded to BufferGeometry');
        expect(json.containsKey('width'), isFalse, reason: 'parameters are not serialized');
        expect(
          ((json['data'] as Map?)?['attributes'] as Map?)?['position'],
          isNotNull,
          reason: 'attribute data is serialized',
        );
      });

      test('toJSON: clone of a transformed geometry preserves _transformed', () {
        final source = BoxGeometry(10, 20, 30);
        source.translate(1, 2, 3);
        final clone = source.clone();
        final json = clone.toJSON();

        expect(_transformed(clone), isTrue, reason: '_transformed propagates through copy()');
        expect(json['type'], 'BufferGeometry', reason: 'cloned type is downgraded to BufferGeometry');
        expect(
          ((json['data'] as Map?)?['attributes'] as Map?)?['position'],
          isNotNull,
          reason: 'cloned attribute data is serialized',
        );
      });
    });
  });
}
