// The reference unit tests of Group.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('Group', () {
      // INHERITANCE
      test('Extending', () {
        final group = Group();
        expect(group, isA<Object3D>(), reason: 'Group extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Group();
        expect(object, isNotNull, reason: 'Can instantiate a Group.');
      });

      // PROPERTIES
      test('type', () {
        final object = Group();
        expect(object.type == 'Group', isTrue, reason: 'Group.type should be Group');
      });

      // PUBLIC
      test('isGroup', () {
        final object = Group();
        expect(object.isGroup, isTrue, reason: 'Group.isGroup should be true');
      });
    });

    group('Group (Dart)', () {
      test('clone', () {
        final group = Group()..add(Group());
        final clone = group.clone();
        expect(clone, isA<Group>());
        expect(clone.children.single, isA<Group>());
      });
    });
  });
}
