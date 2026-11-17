// The reference unit tests of Bone.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('Bone', () {
      // INHERITANCE
      test('Extending', () {
        final bone = Bone();
        expect(bone, isA<Object3D>(), reason: 'Bone extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Bone();
        expect(object, isNotNull, reason: 'Can instantiate a Bone.');
      });

      // PROPERTIES
      test('type', () {
        final object = Bone();
        expect(object.type, 'Bone', reason: 'Bone.type should be Bone');
      });

      // PUBLIC
      test('isBone', () {
        final object = Bone();
        expect(object.isBone, isTrue, reason: 'Bone.isBone should be true');
      });

      // DART
      test('clone keeps the type and the hierarchy', () {
        final root = Bone()..name = 'root';
        root.add(Bone()..position.set(0, 1, 0));

        final clone = root.clone();
        expect(clone, isA<Bone>());
        expect(clone.name, 'root');
        expect(clone.children.single, isA<Bone>());
        expect(clone.children.single.position.toArray(), [0.0, 1.0, 0.0]);
        expect(clone['isBone'], isTrue);
      });
    });
  });
}
