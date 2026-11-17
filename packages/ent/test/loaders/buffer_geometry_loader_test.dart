import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Loaders', () {
    group('BufferGeometryLoader', () {
      tearDown(() => Loader.platform = null);

      // INHERITANCE
      test('Extending', () {
        expect(
          BufferGeometryLoader(),
          isA<Loader<BufferGeometry>>(),
          reason: 'BufferGeometryLoader extends from Loader',
        );
      });

      // INSTANCING
      test('Instancing', () {
        expect(BufferGeometryLoader(), isNotNull, reason: 'Can instantiate a BufferGeometryLoader.');
      });

      // OTHERS
      test('parser - attributes - circlable', () {
        final loader = BufferGeometryLoader();
        final geometry = BufferGeometry();
        final attr = BufferAttribute(Float32List.fromList([7, 8, 9, 10, 11, 12]), 2, true);
        attr.name = 'attribute';
        attr.setUsage(DynamicDrawUsage);

        geometry.setAttribute('attr', attr);

        final geometry2 = loader.parse(geometry.toJSON());

        expect(
          geometry2.getAttribute('attr'),
          isNotNull,
          reason: 'Serialized attribute can be deserialized under the same attribute key.',
        );

        // deepEqual: the same state
        final attr2 = geometry2.getAttribute('attr')! as BufferAttribute;
        expect(
          [attr2.name, attr2.array, attr2.itemSize, attr2.normalized, attr2.usage, attr2.array.runtimeType],
          [attr.name, attr.array, attr.itemSize, attr.normalized, attr.usage, attr.array.runtimeType],
          reason: 'Serialized attribute can be deserialized correctly.',
        );
      });

      test('parser - interleaved attributes - views into a shared array buffer', () {
        final buffer = Float32List.fromList([1, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0, 10, 11, 12, 0]).buffer;

        final position = InterleavedBufferAttribute(InterleavedBuffer(Float32List.view(buffer, 0, 8), 4), 3, 0);
        final normal = InterleavedBufferAttribute(InterleavedBuffer(Float32List.view(buffer, 32, 8), 4), 3, 0);

        final geometry = BufferGeometry();
        geometry.setAttribute('position', position);
        geometry.setAttribute('normal', normal);

        final geometry2 = BufferGeometryLoader().parse(geometry.toJSON());

        expect((geometry2.getAttribute('position')! as InterleavedBufferAttribute).data.array.toList(), [
          1,
          2,
          3,
          0,
          4,
          5,
          6,
          0,
        ], reason: 'first view was deserialized');
        expect((geometry2.getAttribute('normal')! as InterleavedBufferAttribute).data.array.toList(), [
          7,
          8,
          9,
          0,
          10,
          11,
          12,
          0,
        ], reason: 'second view was deserialized');
        expect(geometry2.getAttribute('normal')!.count, 2, reason: 'count is preserved');
      });

      // Dart: the rest of parse (the reference output in object_loader_reference_test covers it against Node too)
      test('parse index morph groups bounds name userData instancing', () {
        final geometry = InstancedBufferGeometry()
          ..setIndex([0, 1, 2])
          ..setAttribute('position', Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0], 3))
          ..setAttribute('offset', InstancedBufferAttribute(Float32List.fromList([1, 2, 3]), 3))
          ..addGroup(0, 3, 2)
          ..name = 'tri'
          ..userData = {'a': 1};
        geometry.morphAttributes['position'] = [
          Float32BufferAttribute([0, 0, 1, 0, 0, 1, 0, 0, 1], 3),
        ];
        geometry.morphTargetsRelative = true;
        geometry.computeBoundingSphere();

        final parsed = BufferGeometryLoader().parse(geometry.toJSON());

        expect(parsed, isA<InstancedBufferGeometry>());
        expect(parsed.index!.array.toList(), [0, 1, 2]);
        expect(parsed.getAttribute('offset'), isA<InstancedBufferAttribute>());
        expect(parsed.morphAttributes['position']!.single.count, 3);
        expect(parsed.morphTargetsRelative, isTrue);
        expect(parsed.groups.single.materialIndex, 2);
        expect(parsed.boundingSphere!.equals(geometry.boundingSphere!), isTrue);
        expect(
          [parsed.name, parsed.userData],
          [
            'tri',
            {'a': 1},
          ],
        );

        // legacy group names; a missing materialIndex takes addGroup's default
        final legacy = BufferGeometryLoader().parse({
          'data': {
            'attributes': <String, Object?>{},
            'drawcalls': [
              {'start': 0, 'count': 3},
            ],
          },
        });
        expect(legacy.groups.single.materialIndex, 0);
      });

      test('load', () async {
        final platform = FakeLoaderPlatform();
        Loader.platform = platform;
        platform.resources['g.json'] = FakeResource.text(
          '{"data":{"attributes":{"position":{"itemSize":3,"type":"Float32Array","array":[1,2,3],"normalized":false}}}}',
        );

        final geometry = await BufferGeometryLoader().loadAsync('g.json');
        expect(geometry.getAttribute('position')!.count, 1);
      });
    });
  });
}
