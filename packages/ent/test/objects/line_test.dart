// The reference unit tests of Line.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('Line', () {
      // INHERITANCE
      test('Extending', () {
        final line = Line();
        expect(line, isA<Object3D>(), reason: 'Line extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Line();
        expect(object, isNotNull, reason: 'Can instantiate a Line.');
      });

      // PROPERTIES
      test('type', () {
        final object = Line();
        expect(object.type == 'Line', isTrue, reason: 'Line.type should be Line');
      });

      // PUBLIC
      test('isLine', () {
        final object = Line();
        expect(object.isLine, isTrue, reason: 'Line.isLine should be true');
      });

      test('copy/material', () {
        // Material arrays are cloned
        final mesh1 = Line();
        mesh1.material = [Material()];

        final copy1 = mesh1.clone();
        expect(identical(mesh1.material, copy1.material), isFalse);

        // Non arrays are not cloned
        final mesh2 = Line();
        mesh1.material = Material();
        final copy2 = mesh2.clone();
        expect(identical(mesh2.material, copy2.material), isTrue);
      });

      test('copy/morphTargets', () {
        final geometry = BufferGeometry();
        geometry.setAttribute('position', Float32BufferAttribute([0, 0, 0, 1, 1, 1], 3));
        geometry.morphAttributes['position'] = [
          Float32BufferAttribute([1, 0, 0, 0, 1, 0], 3),
        ];
        geometry.morphAttributes['position']![0].name = 'target';

        final line = Line(geometry);
        line.morphTargetInfluences![0] = 0.5;

        final copy = line.clone();
        expect(copy.morphTargetInfluences, [0.5], reason: 'morphTargetInfluences are copied');
        expect(
          identical(copy.morphTargetInfluences, line.morphTargetInfluences),
          isFalse,
          reason: 'morphTargetInfluences are not shared',
        );
        expect(copy.morphTargetDictionary, {'target': 0}, reason: 'morphTargetDictionary is copied');
        expect(
          identical(copy.morphTargetDictionary, line.morphTargetDictionary),
          isFalse,
          reason: 'morphTargetDictionary is not shared',
        );
      });
    });

    group('Line (Dart)', () {
      test('defaults: geometry material morphTargetDictionary morphTargetInfluences', () {
        final line = Line();
        expect(line.geometry, isA<BufferGeometry>());
        expect(line.material, isA<LineBasicMaterial>());
        expect(line.morphTargetDictionary, isNull);
        expect(line.morphTargetInfluences, isNull);
      });

      test('computeLineDistances', () {
        final geometry = BufferGeometry().setFromPoints([Vector3(0, 0, 0), Vector3(3, 4, 0), Vector3(3, 4, 2)]);
        final line = Line(geometry);
        expect(identical(line.computeLineDistances(), line), isTrue);
        expect(geometry.attributes['lineDistance']!.array.toList(), [0, 5, 7]);
      });

      test('computeLineDistances warns for an indexed geometry', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$type $message'));
        addTearDown(() => setConsoleFunction(null));

        final geometry = BufferGeometry().setFromPoints([Vector3(), Vector3(1, 0, 0)])..setIndex(<int>[0, 1]);
        Line(geometry).computeLineDistances();
        expect(messages, [
          'warn ENT.Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.',
        ]);
        expect(geometry.attributes.containsKey('lineDistance'), isFalse);
      });

      test('raycast', () {
        final geometry = BufferGeometry().setFromPoints([Vector3(-1, 0, -5), Vector3(1, 0, -5)]);
        final hits = Raycaster(Vector3(), Vector3(0, 0, -1)).intersectObject(Line(geometry));
        expect(hits.length, 1);
        expect(hits[0].index, 0);
        expect(hits[0].point.toArray(), [0, 0, -5]);
        expect(hits[0].face, isNull);
      });

      test('intersectsFrustum', () {
        final frustum = Frustum().setFromProjectionMatrix(Matrix4().makePerspective(-1, 1, 1, -1, 1, 100));
        final geometry = BufferGeometry().setFromPoints([Vector3(-1, 0, -5), Vector3(1, 0, -5)]);
        expect(Line(geometry).intersectsFrustum(frustum), isTrue);
      });
    });
  });
}
