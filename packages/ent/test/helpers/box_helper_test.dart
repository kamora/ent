// The reference unit tests of BoxHelper, plus Dart checks of clone/copy and dispose.

import '../geometries/geometry_helpers.dart';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('BoxHelper', () {
      // INHERITANCE

      test('Extending', () {
        final object = BoxHelper();
        expect(object, isA<LineSegments>(), reason: 'BoxHelper extends from LineSegments');
      });

      // INSTANCING

      test('Instancing', () {
        final object = BoxHelper();
        expect(object, isNotNull, reason: 'Can instantiate a BoxHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = BoxHelper();
        expect(object.type, 'BoxHelper', reason: 'BoxHelper.type should be BoxHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = BoxHelper();
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      // OTHERS

      test('Standard geometry tests', () {
        // Test with a normal cube and a box helper
        final boxHelper = BoxHelper(Mesh(BoxGeometry()));

        // The same should happen with a comparable sphere
        final sphereBoxHelper = BoxHelper(Mesh(SphereGeometry()));

        // Note that unlike what I'd like to, these doesn't check the equivalency
        // of the two generated geometries

        runStdGeometryTests([boxHelper.geometry, sphereBoxHelper.geometry], _bufferGeometryFromJSON);
      });

      // Dart

      test('copy/clone keep the object', () {
        final mesh = Mesh(BoxGeometry());
        final helper = BoxHelper(mesh);
        final clone = helper.clone();
        expect(clone, isA<BoxHelper>());
        expect(clone.object, same(mesh));
        expect(BoxHelper().copy(helper).object, same(mesh));
      });

      test('a helper without an object reuses the shared box of the last update', () {
        BoxHelper(Mesh(BoxGeometry(2, 2, 2)));
        final orphan = BoxHelper();
        expect((orphan.geometry.getAttribute('position')!.array as List<double>).take(3), [1.0, 1.0, 1.0]);
      });
    });
  });
}

// The reference reads the JSON back through ObjectLoader.parseGeometries (BufferGeometryLoader for plain geometries);
// until the loaders are ported, the attributes and index are rebuilt from the JSON here.
BufferGeometry _bufferGeometryFromJSON(Map<String, Object?> json) {
  final data = json['data']! as Map<String, Object?>;
  final geometry = BufferGeometry();
  final index = data['index'] as Map<String, Object?>?;

  if (index != null) {
    geometry.setIndex(BufferAttribute(getTypedArray(index['type']! as String, index['array']!), 1));
  }

  for (final MapEntry(key: name, value: value) in (data['attributes']! as Map<String, Object?>).entries) {
    final attribute = value! as Map<String, Object?>;
    geometry.setAttribute(
      name,
      BufferAttribute(
        getTypedArray(attribute['type']! as String, attribute['array']!),
        attribute['itemSize']! as int,
        attribute['normalized']! as bool,
      ),
    );
  }

  return geometry;
}
