// The reference unit tests of SkeletonHelper, plus Dart checks of clone/copy and dispose.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Helpers', () {
    group('SkeletonHelper', () {
      // INHERITANCE

      test('Extending', () {
        final object = SkeletonHelper(Bone());
        expect(object, isA<LineSegments>(), reason: 'SkeletonHelper extends from LineSegments');
      });

      // INSTANCING

      test('Instancing', () {
        final object = SkeletonHelper(Bone());
        expect(object, isNotNull, reason: 'Can instantiate a SkeletonHelper.');
      });

      // PROPERTIES

      test('type', () {
        final object = SkeletonHelper(Bone());
        expect(object.type, 'SkeletonHelper', reason: 'SkeletonHelper.type should be SkeletonHelper');
      });

      // PUBLIC

      test('dispose', () {
        final object = SkeletonHelper(Bone());
        var disposed = false;
        object.addEventListener('dispose', (event) => disposed = true);
        object.dispose();
        expect(disposed, isTrue);
      });

      test('isSkeletonHelper', () {
        final object = SkeletonHelper(Bone());
        expect(object.isSkeletonHelper, isTrue, reason: 'SkeletonHelper.isSkeletonHelper should be true');
      });

      // Dart

      test('bones: only bones with a bone parent get a line', () {
        final root = Object3D();
        final b0 = Bone(), b1 = Bone(), loose = Object3D(), b2 = Bone();
        root.add(b0);
        b0.add(b1);
        b1.add(loose);
        loose.add(b2);
        final helper = SkeletonHelper(root);
        expect(helper.bones, [b0, b1, b2]);
        expect(helper.geometry.getAttribute('position')!.count, 2);
        expect(helper.matrix, same(root.matrixWorld));
      });

      test('clone keeps the root (E-CLONE)', () {
        final bone = Bone()..add(Bone());
        final clone = SkeletonHelper(bone).clone();
        expect(clone, isA<SkeletonHelper>());
        expect(clone.root, same(bone));
      });
    });
  });
}
