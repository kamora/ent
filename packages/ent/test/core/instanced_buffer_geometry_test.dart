// The reference unit tests of InstancedBufferGeometry.
//
// Adaptations: the reference builds attributes without an itemSize (`new BufferAttribute( array )`); Dart passes 1. The
// reference's clonable index mock becomes a BufferAttribute subclass, since `index` is a BufferAttribute.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// The reference's `createClonableMock()`: an index whose clone() counts calls and returns itself.
class ClonableMock extends BufferAttribute {
  ClonableMock() : super(Uint16List(0), 1);

  int callCount = 0;

  @override
  BufferAttribute clone([Map<String, Object?>? data]) {
    callCount++;
    return this;
  }
}

void main() {
  group('Core', () {
    group('InstancedBufferGeometry', () {
      // INHERITANCE
      test('Extending', () {
        final object = InstancedBufferGeometry();
        expect(object, isA<BufferGeometry>(), reason: 'InstancedBufferGeometry extends from BufferGeometry');
      });

      // INSTANCING
      test('Instancing', () {
        final object = InstancedBufferGeometry();
        expect(object, isNotNull, reason: 'Can instantiate an InstancedBufferGeometry.');
      });

      // PROPERTIES
      test('type', () {
        final object = InstancedBufferGeometry();
        expect(
          object.type,
          'InstancedBufferGeometry',
          reason: 'InstancedBufferGeometry.type should be InstancedBufferGeometry',
        );
      });

      // PUBLIC
      test('isInstancedBufferGeometry', () {
        final object = InstancedBufferGeometry();
        expect(
          object.isInstancedBufferGeometry,
          isTrue,
          reason: 'InstancedBufferGeometry.isInstancedBufferGeometry should be true',
        );
      });

      test('copy', () {
        final instanceMock1 = Object();
        final instanceMock2 = Object();
        final indexMock = ClonableMock();
        final defaultAttribute1 = BufferAttribute(Float32List.fromList([1]), 1);
        final defaultAttribute2 = BufferAttribute(Float32List.fromList([2]), 1);

        final instance = InstancedBufferGeometry();

        instance.addGroup(0, 10, instanceMock1);
        instance.addGroup(10, 5, instanceMock2);
        instance.setIndex(indexMock);
        instance.setAttribute('defaultAttribute1', defaultAttribute1);
        instance.setAttribute('defaultAttribute2', defaultAttribute2);

        final copiedInstance = InstancedBufferGeometry().copy(instance);

        expect(copiedInstance, isA<InstancedBufferGeometry>(), reason: 'the clone has the correct type');

        expect(copiedInstance.index, indexMock, reason: 'index was copied');
        expect((copiedInstance.index! as ClonableMock).callCount, 1, reason: 'index.clone was called once');

        expect(copiedInstance.attributes['defaultAttribute1'], isA<BufferAttribute>(), reason: 'attribute was created');
        expect(
          copiedInstance.attributes['defaultAttribute1']!.array,
          defaultAttribute1.array,
          reason: 'attribute was copied',
        );
        expect(
          copiedInstance.attributes['defaultAttribute2']!.array,
          defaultAttribute2.array,
          reason: 'attribute was copied',
        );

        expect(copiedInstance.groups[0].start, 0, reason: 'group was copied');
        expect(copiedInstance.groups[0].count, 10, reason: 'group was copied');
        expect(copiedInstance.groups[0].materialIndex, instanceMock1, reason: 'group was copied');

        expect(copiedInstance.groups[1].start, 10, reason: 'group was copied');
        expect(copiedInstance.groups[1].count, 5, reason: 'group was copied');
        expect(copiedInstance.groups[1].materialIndex, instanceMock2, reason: 'group was copied');
      });
    });

    group('InstancedBufferGeometry (Dart)', () {
      test('instanceCount defaults to Infinity and is copied', () {
        final a = InstancedBufferGeometry();
        expect(a.instanceCount, double.infinity);

        a.instanceCount = 7;
        expect(InstancedBufferGeometry().copy(a).instanceCount, 7);
      });

      test('clone keeps the subclass (E-CLONE)', () {
        final a = InstancedBufferGeometry()..instanceCount = 3;
        final b = a.clone();
        expect(b, isA<InstancedBufferGeometry>());
        expect(b.instanceCount, 3);
        expect(b.type, 'InstancedBufferGeometry');
      });

      test('toJSON adds instanceCount and the flag', () {
        final a = InstancedBufferGeometry()..instanceCount = 4;
        final json = a.toJSON();
        expect(json['type'], 'InstancedBufferGeometry');
        expect(json['instanceCount'], 4);
        expect(json['isInstancedBufferGeometry'], isTrue);
      });
    });
  });
}
