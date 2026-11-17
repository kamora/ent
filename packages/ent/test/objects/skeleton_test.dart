// The reference unit tests of Skeleton, plus Dart regression tests whose expected values were printed from the
// reference source in Node.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// A three-bone chain, as the Node reference builds it.
List<Bone> chain() {
  final b0 = Bone()..name = 'root';
  final b1 = Bone()..name = 'mid';
  final b2 = Bone()..name = 'tip';

  b0.add(b1);
  b1.add(b2);
  b0.position.set(0, -1, 0);
  b1.position.set(0, 1, 0);
  b2.position.set(0, 1, 0.5);
  b0.updateMatrixWorld(true);

  return [b0, b1, b2];
}

void expectNumbers(Iterable<num> actual, List<num> expected, [double tolerance = 1e-12]) {
  final list = actual.toList();
  expect(list.length, expected.length);

  for (var i = 0; i < list.length; i++) {
    expect(list[i], closeTo(expected[i], tolerance), reason: 'index $i');
  }
}

void main() {
  group('Objects', () {
    group('Skeleton', () {
      // INSTANCING
      test('Instancing', () {
        final object = Skeleton();
        expect(object, isNotNull, reason: 'Can instantiate a Skeleton.');
      });

      // PUBLIC
      test('dispose', () {
        final object = Skeleton();
        object.dispose();
      });

      // DART
      test('calculateInverses', () {
        final skeleton = Skeleton(chain());

        expectNumbers(skeleton.boneInverses[0].elements, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1]);
        expectNumbers(skeleton.boneInverses[1].elements, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
        expectNumbers(skeleton.boneInverses[2].elements, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, -1, -0.5, 1]);
      });

      test('update', () {
        final bones = chain();
        final skeleton = Skeleton(bones);
        bones[1].rotation.set(0.3, -0.2, 0.7);
        bones[2].scale.set(1, 2, 1);
        bones[0].updateMatrixWorld(true);
        skeleton.update();

        // Float32 values, exactly as the reference stores them
        expect(skeleton.boneMatrices, [
          1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, //
          0.7495962381362915, 0.570540189743042, 0.33554336428642273, 0, //
          -0.6313762068748474, 0.7685042023658752, 0.10375633835792542, 0, //
          -0.19866932928562164, -0.2896294891834259, 0.936293363571167, 0, 0, 0, 0, 1, //
          0.7495962381362915, 0.570540189743042, 0.33554336428642273, 0, //
          -1.2627524137496948, 1.5370084047317505, 0.20751267671585083, 0, //
          -0.19866932928562164, -0.2896294891834259, 0.936293363571167, 0, //
          0.6313762068748474, -0.7685042023658752, -0.10375633835792542, 1,
        ]);
      });

      test('pose', () {
        final bones = chain();
        final skeleton = Skeleton(bones);
        bones[1].rotation.set(0.3, -0.2, 0.7);
        bones[2].scale.set(1, 2, 1);
        bones[0].updateMatrixWorld(true);
        skeleton.pose();

        final expected = [
          [0, -1, 0, 0, 0, 0, 1, 1, 1, 1],
          [0, 1, 0, 0, 0, 0, 1, 1, 1, 1],
          [0, 1, 0.5, 0, 0, 0, 1, 1, 1, 1],
        ];

        for (var i = 0; i < 3; i++) {
          final b = bones[i];
          expectNumbers([...b.position.toArray(), ...b.quaternion.toArray(), ...b.scale.toArray()], expected[i]);
        }
      });

      test('computeBoneTexture', () {
        final skeleton = Skeleton(chain());
        expect(skeleton.computeBoneTexture(), same(skeleton));
        expect((skeleton.boneTexture!.image as DataImage).width, 4);
        expect(skeleton.boneMatrices!.length, 64);
        expect(skeleton.boneTexture!.version, greaterThan(0), reason: 'needsUpdate was set');

        final big = Skeleton(List.generate(20, (_) => Bone()))..computeBoneTexture();
        expect((big.boneTexture!.image as DataImage).width, 12);
        expect(big.boneMatrices!.length, 576);
        expect(big.boneTexture!.image, isA<DataImage>());
        expect((big.boneTexture!.image as DataImage).data, same(big.boneMatrices));

        big.dispose();
        expect(big.boneTexture, isNull);
      });

      test('init: mismatched inverses are replaced with identities, with a warning', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        final skeleton = Skeleton(chain(), [Matrix4()]);
        expect(skeleton.boneInverses.length, 3);
        expect(messages, ['ENT.Skeleton: Number of inverse bone matrices does not match amount of bones.']);
      });

      test('getBoneByName', () {
        final skeleton = Skeleton(chain());
        expect(skeleton.getBoneByName('mid'), same(skeleton.bones[1]));
        expect(skeleton.getBoneByName('missing'), isNull);
      });

      test('clone', () {
        final skeleton = Skeleton(chain());
        final clone = skeleton.clone();
        expect(clone.bones, skeleton.bones);
        expect(clone.bones, isNot(same(skeleton.bones)), reason: 'bones are copied into a new list');
        expect(clone.boneInverses, same(skeleton.boneInverses), reason: 'inverses are shared, as in the reference');
        expect(clone.uuid, isNot(skeleton.uuid));
      });

      test('toJSON/fromJSON', () {
        final bones = chain();
        final skeleton = Skeleton(bones);
        final json = skeleton.toJSON();

        expect(json['metadata'], {'version': 4.7, 'type': 'Skeleton', 'generator': 'Skeleton.toJSON'});
        expect(json['uuid'], skeleton.uuid);
        expect(json['bones'], bones.map((b) => b.uuid).toList());

        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$message ${params.join(' ')}'));
        addTearDown(() => setConsoleFunction(null));

        final restored = Skeleton().fromJSON(json, {bones[0].uuid: bones[0], bones[2].uuid: bones[2]});
        expect(restored.uuid, skeleton.uuid);
        expect(restored.bones[0], same(bones[0]));
        expect(restored.bones[1], isNot(same(bones[1])), reason: 'a missing bone is replaced by a new Bone');
        expect(restored.bones[2], same(bones[2]));
        expectNumbers(restored.boneInverses[2].elements, skeleton.boneInverses[2].elements);
        expect(messages, ['ENT.Skeleton: No bone found with UUID: ${bones[1].uuid}']);
        expect(restored.boneMatrices, isA<Float32List>());
      });
    });
  });
}
