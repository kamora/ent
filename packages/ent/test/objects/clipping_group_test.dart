// Tests of ClippingGroup, which has no reference unit test.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('ClippingGroup', () {
      test('Extending', () {
        final group = ClippingGroup();
        expect(group, isA<Group>(), reason: 'ClippingGroup extends from Group');
        expect(group, isA<Object3D>());
      });

      test('Instancing', () {
        expect(ClippingGroup(), isNotNull);
      });

      test('type', () {
        expect(ClippingGroup().type, 'Group', reason: 'the reference does not change the Group type');
      });

      test('isClippingGroup', () {
        final group = ClippingGroup();
        expect(group.isClippingGroup, isTrue);
        expect(group.isGroup, isTrue);
      });

      test('defaults: clippingPlanes enabled clipIntersection clipShadows', () {
        final group = ClippingGroup();
        expect(group.clippingPlanes, isEmpty);
        expect(group.enabled, isTrue);
        expect(group.clipIntersection, isFalse);
        expect(group.clipShadows, isFalse);
      });

      test('clone', () {
        final group = ClippingGroup()
          ..clippingPlanes.add(Plane())
          ..enabled = false;
        final clone = group.clone();
        expect(clone, isA<ClippingGroup>());
        expect(clone.clippingPlanes, isEmpty, reason: 'the reference copy() does not copy the clipping state');
        expect(clone.enabled, isTrue);
      });
    });
  });
}
