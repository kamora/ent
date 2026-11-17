// The reference unit tests of TextureSource, plus Dart tests of members the reference does not test. Expected
// serializations were printed from the reference source in Node.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Textures', () {
    group('TextureSource', () {
      // INSTANCING
      test('Instancing', () {
        final object = TextureSource();
        expect(object, isNotNull, reason: 'Can instantiate a TextureSource.');
      });

      // PUBLIC
      test('isTextureSource', () {
        final object = TextureSource();
        expect(object.isTextureSource, isTrue, reason: 'TextureSource.isTextureSource should be true');
      });

      test('getSize', () {
        final target = Vector3();

        // data with defined dimensions
        TextureSource(DataImage(width: 8, height: 4, depth: 2)).getSize(target);
        expect([target.x, target.y, target.z], [8, 4, 2], reason: 'getSize() writes the source dimensions.');

        // null data
        TextureSource(null).getSize(target);
        expect([target.x, target.y, target.z], [0, 0, 0], reason: 'getSize() writes zeros when there is no data.');

        // undefined dimensions (e.g. a DepthTexture created without an explicit
        // size) must never be written into the target's numeric fields
        TextureSource(DataImage(depth: 1)).getSize(target);
        expect(
          target.x.isNaN || target.y.isNaN || target.z.isNaN,
          isFalse,
          reason: 'getSize() only ever writes numbers into the target vector.',
        );
        expect([target.x, target.y, target.z], [0, 0, 1], reason: 'getSize() coerces undefined dimensions to 0.');
      });

      // Dart tests of the source behaviour

      test('getSize into a Vector2', () {
        final target = TextureSource(DataImage(width: 8, height: 4, depth: 2)).getSize(Vector2());
        expect(target.toArray(), [8.0, 4.0]);
      });

      test('id, version, needsUpdate', () {
        final a = TextureSource();
        final b = TextureSource();
        expect(b.id, a.id + 1);
        expect(a.dataReady, isTrue);
        a.needsUpdate = false;
        expect(a.version, 0);
        a.needsUpdate = true;
        expect(a.version, 1);
      });

      test('toJSON', () {
        final source = TextureSource(DataImage(data: Uint8List.fromList([1, 2, 3]), width: 1, height: 1));
        expect(source.toJSON(), {
          'uuid': source.uuid,
          'url': {
            'data': [1, 2, 3],
            'width': 1,
            'height': 1,
            'type': 'Uint8Array',
          },
        });

        expect(TextureSource().toJSON(), {'uuid': isA<String>(), 'url': ''});

        final meta = <String, Object?>{'images': <String, Object?>{}};
        final first = source.toJSON(meta);
        expect(identical(source.toJSON(meta), first), isTrue, reason: 'cached in meta.images');

        final cube = TextureSource([
          DataImage(data: Float32List(1), width: 1, height: 1),
          DataImage(data: Float32List(1), width: 1, height: 1),
        ]).toJSON();
        expect((cube['url'] as List).map((u) => (u as Map)['type']), ['Float32Array', 'Float32Array']);
      });

      test('toJSON warns for an image it cannot serialize', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$type $message'));
        addTearDown(() => setConsoleFunction(null));

        expect(TextureSource(DataImage(width: 1, height: 1)).toJSON()['url'], <String, Object?>{});
        expect(messages, ['warn ENT.Texture: Unable to serialize Texture.']);
      });

      test('Source is deprecated', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        // ignore: deprecated_member_use_from_same_package
        final source = Source();
        expect(source.isSource && source.isTextureSource, isTrue);
        expect(messages.single, contains('"Source" has been renamed to "TextureSource"'));
      });
    });
  });
}
