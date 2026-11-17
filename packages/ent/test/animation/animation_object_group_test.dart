// The reference unit tests of AnimationObjectGroup. The reference's variadic constructor, add, remove and uncache take
// a list (E-VARIADIC).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('AnimationObjectGroup', () {
      final objectA = Object3D();
      final objectB = Object3D();
      final objectC = Object3D();
      const pathA = 'object.position';
      const pathB = 'object.rotation';
      const pathC = 'object.scale';
      final parsedPathA = PropertyBinding.parseTrackName(pathA);
      final parsedPathB = PropertyBinding.parseTrackName(pathB);
      final parsedPathC = PropertyBinding.parseTrackName(pathC);

      // INSTANCING
      test('Instancing', () {
        final groupA = AnimationObjectGroup();
        expect(groupA, isA<AnimationObjectGroup>(), reason: 'AnimationObjectGroup can be instantiated');
      });

      // PUBLIC
      test('isAnimationObjectGroup', () {
        final object = AnimationObjectGroup();
        expect(
          object.isAnimationObjectGroup,
          isTrue,
          reason: 'AnimationObjectGroup.isAnimationObjectGroup should be true',
        );
      });

      // OTHERS
      test('smoke test', () {
        void check(
          int testIndex,
          AnimationObjectGroup group,
          List<PropertyBinding?> bindings,
          String path,
          int cached,
          List<Object3D> roots,
        ) {
          final rootNodes = <Object?>[];
          var pathsOk = true;
          var nodesOk = true;

          for (var i = group.nCachedObjects_, n = bindings.length; i != n; ++i) {
            if (bindings[i]!.path != path) {
              pathsOk = false;
            }

            rootNodes.add(bindings[i]!.rootNode);
          }

          for (var i = 0, n = roots.length; i != n; ++i) {
            if (!rootNodes.contains(roots[i])) {
              nodesOk = false;
            }
          }

          expect(pathsOk, isTrue, reason: '$testIndex paths');
          expect(nodesOk, isTrue, reason: '$testIndex nodes');
          expect(group.nCachedObjects_ == cached, isTrue, reason: '$testIndex cache size');
          expect(bindings.length - group.nCachedObjects_ == roots.length, isTrue, reason: '$testIndex object count');
        }

        // initial state

        final groupA = AnimationObjectGroup();
        expect(groupA, isA<AnimationObjectGroup>(), reason: 'constructor (w/o args)');

        final bindingsAA = groupA.subscribe_(pathA, parsedPathA);
        check(0, groupA, bindingsAA, pathA, 0, []);

        final groupB = AnimationObjectGroup([objectA, objectB]);
        expect(groupB, isA<AnimationObjectGroup>(), reason: 'constructor (with args)');

        final bindingsBB = groupB.subscribe_(pathB, parsedPathB);
        check(1, groupB, bindingsBB, pathB, 0, [objectA, objectB]);

        // add

        groupA.add([objectA, objectB]);
        check(2, groupA, bindingsAA, pathA, 0, [objectA, objectB]);

        groupB.add([objectC]);
        check(3, groupB, bindingsBB, pathB, 0, [objectA, objectB, objectC]);

        // remove

        groupA.remove([objectA, objectC]);
        check(4, groupA, bindingsAA, pathA, 1, [objectB]);

        groupB.remove([objectA, objectB, objectC]);
        check(5, groupB, bindingsBB, pathB, 3, []);

        // subscribe after re-add

        groupA.add([objectC]);
        check(6, groupA, bindingsAA, pathA, 1, [objectB, objectC]);

        final bindingsAC = groupA.subscribe_(pathC, parsedPathC);
        check(7, groupA, bindingsAC, pathC, 1, [objectB, objectC]);

        // re-add after subscribe

        final bindingsBC = groupB.subscribe_(pathC, parsedPathC);
        groupB.add([objectA, objectB]);
        check(8, groupB, bindingsBB, pathB, 1, [objectA, objectB]);

        // unsubscribe

        final copyOfBindingsBC = bindingsBC.sublist(0);
        groupB.unsubscribe_(pathC);
        groupB.add([objectC]);
        expect(bindingsBC, copyOfBindingsBC, reason: 'no more update after unsubscribe');

        // uncache active

        groupB.uncache([objectA]);
        check(9, groupB, bindingsBB, pathB, 0, [objectB, objectC]);

        // uncache cached

        groupA.uncache([objectA]);
        check(10, groupA, bindingsAC, pathC, 0, [objectB, objectC]);
      });

      // Dart-specific
      test('stats', () {
        final group = AnimationObjectGroup([objectA, objectB]);
        group.subscribe_(pathA, parsedPathA);
        group.remove([objectA]);
        expect(group.stats.objects.total, 2);
        expect(group.stats.objects.inUse, 1);
        expect(group.stats.bindingsPerObject, 1);
      });
    });
  });
}
