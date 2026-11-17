// The reference unit tests of LOD.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('LOD', () {
      // INHERITANCE
      test('Extending', () {
        final lod = LOD();
        expect(lod, isA<Object3D>(), reason: 'LOD extends from Object3D');
      });

      // PROPERTIES
      test('type', () {
        final object = LOD();
        expect(object.type == 'LOD', isTrue, reason: 'LOD.type should be LOD');
      });

      test('levels', () {
        final lod = LOD();
        final levels = lod.levels;

        expect(levels, isA<List<LODLevel>>(), reason: 'LOD.levels is of type array.');
        expect(levels.length, 0, reason: 'LOD.levels is empty by default.');
      });

      test('autoUpdate', () {
        final lod = LOD();

        expect(lod.autoUpdate, isTrue, reason: 'LOD.autoUpdate is of type boolean and true by default.');
      });

      // PUBLIC
      test('isLOD', () {
        final lod = LOD();
        expect(lod.isLOD, isTrue, reason: '.isLOD property is defined.');
      });

      test('copy', () {
        final lod1 = LOD();
        final lod2 = LOD();

        final high = Object3D();
        final mid = Object3D();
        final low = Object3D();

        lod1.addLevel(high, 5);
        lod1.addLevel(mid, 25);
        lod1.addLevel(low, 50);

        lod1.autoUpdate = false;

        lod2.copy(lod1);

        expect(lod2.autoUpdate, isFalse, reason: 'LOD.autoUpdate is correctly copied.');
        expect(lod2.levels.length, 3, reason: 'LOD.levels has the correct length after the copy.');
      });

      test('addLevel', () {
        final lod = LOD();

        final high = Object3D();
        final mid = Object3D();
        final low = Object3D();

        lod.addLevel(high, 5, 0.00);
        lod.addLevel(mid, 25, 0.05);
        lod.addLevel(low, 50, 0.10);

        List<Object> entry(LODLevel l) => [l.distance, l.object, l.hysteresis];

        expect(lod.levels.length, 3, reason: 'LOD.levels has the correct length.');
        expect(entry(lod.levels[0]), [5, high, 0.00], reason: 'First entry correct.');
        expect(entry(lod.levels[1]), [25, mid, 0.05], reason: 'Second entry correct.');
        expect(entry(lod.levels[2]), [50, low, 0.10], reason: 'Third entry correct.');
      });

      test('getObjectForDistance', () {
        final lod = LOD();

        final high = Object3D();
        final mid = Object3D();
        final low = Object3D();

        expect(lod.getObjectForDistance(5), isNull, reason: 'Returns null if no LOD levels are defined.');

        lod.addLevel(high, 5);

        expect(
          identical(lod.getObjectForDistance(0), high),
          isTrue,
          reason: 'Returns always the same object if only one LOD level is defined.',
        );
        expect(
          identical(lod.getObjectForDistance(10), high),
          isTrue,
          reason: 'Returns always the same object if only one LOD level is defined.',
        );

        lod.addLevel(mid, 25);
        lod.addLevel(low, 50);

        expect(identical(lod.getObjectForDistance(0), high), isTrue, reason: 'Returns the high resolution object.');
        expect(identical(lod.getObjectForDistance(10), high), isTrue, reason: 'Returns the high resolution object.');
        expect(identical(lod.getObjectForDistance(25), mid), isTrue, reason: 'Returns the mid resolution object.');
        expect(identical(lod.getObjectForDistance(50), low), isTrue, reason: 'Returns the low resolution object.');
        expect(identical(lod.getObjectForDistance(60), low), isTrue, reason: 'Returns the low resolution object.');
      });

      test('raycast', () {
        final lod = LOD();
        final raycaster = Raycaster();
        final intersections = <Intersection>[];

        lod.raycast(raycaster, intersections);

        expect(
          intersections.length,
          0,
          reason: 'Does not fail if raycasting is used with a LOD object without levels.',
        );
      });
    });

    group('LOD (Dart)', () {
      test('removeLevel', () {
        final lod = LOD();
        final near = Object3D(), far = Object3D();
        lod
          ..addLevel(near, 0)
          ..addLevel(far, 10);

        expect(lod.removeLevel(5), isFalse);
        expect(lod.removeLevel(10), isTrue);
        expect(lod.levels.single.object, same(near));
        expect(lod.children, [near], reason: 'the removed level object is removed from the children');
      });

      test('getCurrentLevel', () {
        expect(LOD().getCurrentLevel(), 0);
      });

      test('update', () {
        final lod = LOD();
        final near = Object3D(), far = Object3D();
        lod
          ..addLevel(near, 0)
          ..addLevel(far, 10);

        final camera = PerspectiveCamera();
        camera.position.set(0, 0, 20);
        camera.updateMatrixWorld();
        lod.update(camera);

        expect(lod.getCurrentLevel(), 1);
        expect([near.visible, far.visible], [false, true]);
      });

      test('raycast picks the level for the distance', () {
        final lod = LOD();
        final near = Mesh(BoxGeometry(1, 1, 1));
        final far = Mesh(BoxGeometry(1, 1, 1));
        lod
          ..addLevel(near, 0)
          ..addLevel(far, 10);
        lod.position.set(0, 0, -20);
        lod.updateMatrixWorld();

        final hits = <Intersection>[];
        lod.raycast(Raycaster(Vector3(), Vector3(0, 0, -1)), hits);

        expect(hits, isNotEmpty);
        expect(hits.every((h) => identical(h.object, far)), isTrue);
      });

      test('clone', () {
        final lod = LOD()..addLevel(Object3D()..name = 'a', 3, 0.5);
        final clone = lod.clone();
        expect(clone, isA<LOD>());
        expect(clone.levels.single.distance, 3);
        expect(clone.levels.single.hysteresis, 0.5);
        expect(clone.levels.single.object.name, 'a');
        expect(clone.children.length, 1, reason: 'copy() ignores recursive and adds the level clones once');
      });

      test('toJSON', () {
        final lod = LOD()
          ..addLevel(Object3D(), 3, 0.5)
          ..autoUpdate = false;
        final object = lod.toJSON()['object'] as Map<String, Object?>;
        expect(object['autoUpdate'], isFalse);
        expect(object['levels'], [
          {'object': lod.levels[0].object.uuid, 'distance': 3.0, 'hysteresis': 0.5},
        ]);
      });
    });
  });
}
