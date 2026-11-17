// The reference unit tests of Texture, plus Dart tests of members the reference does not test. Expected numbers of the
// Dart tests were printed from the reference source in Node.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Textures', () {
    group('Texture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Texture();
        expect(object is EventDispatcher, true, reason: 'Texture extends from EventDispatcher');
      });

      // INSTANCING
      test('Instancing', () {
        // no params
        final object = Texture();
        expect(object, isNotNull, reason: 'Can instantiate a Texture.');
      });

      // PUBLIC
      test('isTexture', () {
        final object = Texture();
        expect(object.isTexture, isTrue, reason: 'Texture.isTexture should be true');
      });

      test('dispose', () {
        final object = Texture();
        object.dispose();
      });

      // Dart tests of the source behaviour

      test('defaults', () {
        final t = Texture();
        expect(t.image, isNull);
        expect(
          [t.mapping, t.wrapS, t.wrapT, t.magFilter, t.minFilter, t.format, t.type],
          [
            UVMapping,
            ClampToEdgeWrapping,
            ClampToEdgeWrapping,
            LinearFilter,
            LinearMipmapLinearFilter,
            RGBAFormat,
            UnsignedByteType,
          ],
        );
        expect([t.anisotropy, t.colorSpace, t.flipY, t.unpackAlignment], [1.0, NoColorSpace, true, 4]);
        expect([t.width, t.height, t.depth], [0.0, 0.0, 0.0]);
        expect(Texture().id, t.id + 1);
        expect(Texture(DataImage(width: 2, height: 2, depth: 3)).isArrayTexture, isTrue);
      });

      test('DEFAULT_IMAGE and DEFAULT_MAPPING apply when the argument is omitted', () {
        final image = DataImage(width: 1, height: 1);
        Texture.DEFAULT_IMAGE = image;
        Texture.DEFAULT_MAPPING = CubeReflectionMapping;
        addTearDown(() {
          Texture.DEFAULT_IMAGE = null;
          Texture.DEFAULT_MAPPING = UVMapping;
        });

        expect(identical(Texture().image, image), isTrue);
        expect(Texture().mapping, CubeReflectionMapping);
        expect(Texture(null).image, isNull);
      });

      test('needsUpdate', () {
        final t = Texture();
        t.needsUpdate = false;
        expect([t.version, t.source.version], [0, 0]);
        t.needsUpdate = true;
        expect([t.version, t.source.version], [1, 1]);
        t.needsPMREMUpdate = true;
        expect(t.pmremVersion, 1);
      });

      test('updateRanges', () {
        final t = Texture()..addUpdateRange(2, 5);
        expect(t.updateRanges.map((r) => [r.start, r.count]), [
          [2, 5],
        ]);
        t.clearUpdateRanges();
        expect(t.updateRanges, isEmpty);
      });

      test('updateMatrix/transformUv', () {
        final t = Texture();
        t.offset.set(0.25, -0.5);
        t.repeat.set(2, 3);
        t.rotation = 0.3;
        t.center.set(0.5, 0.5);
        t.updateMatrix();

        const uvs = [
          [0.1, 0.2],
          [1.7, -0.4],
          [-2.3, 2.6],
          [0.5, 0.5],
        ];
        const expected = {
          (RepeatWrapping, RepeatWrapping, true): [
            [0.8084186847027115, 0.5051785922194378],
            [0.5108712019110433, 0.6432812646199584],
            [0.6413005288742331, 0.4990103825534291],
            [0.75, 0.9999999999999998],
          ],
          (ClampToEdgeWrapping, MirroredRepeatWrapping, false): [
            [0, 0.5051785922194378],
            [1, 0.3567187353800416],
            [0, 0.5009896174465709],
            [0.75, 2.220446049250313e-16],
          ],
          (MirroredRepeatWrapping, ClampToEdgeWrapping, true): [
            [0.19158131529728856, 1],
            [0.5108712019110433, 1],
            [0.6413005288742331, 0],
            [0.75, 0.9999999999999998],
          ],
        };

        expect(t.matrix.elements, [
          1.910672978251212,
          -0.8865606199840186,
          0,
          0.5910404133226791,
          2.866009467376818,
          0,
          -0.5008566957869456,
          -0.9897244236963996,
          1,
        ]);

        for (final MapEntry(key: (s, w, flip), value: rows) in expected.entries) {
          t.wrapS = s;
          t.wrapT = w;
          t.flipY = flip;

          for (var i = 0; i < uvs.length; i++) {
            final uv = t.transformUv(Vector2(uvs[i][0], uvs[i][1]));
            expect([uv.x, uv.y], rows[i], reason: 'wrap $s/$w flipY $flip uv ${uvs[i]}');
          }
        }

        t.mapping = CubeReflectionMapping;
        expect(t.transformUv(Vector2(3, 3)).toArray(), [3.0, 3.0], reason: 'only UVMapping transforms');
      });

      test('clone/copy', () {
        final source = Texture(DataImage(width: 2, height: 3), UVMapping, RepeatWrapping)
          ..name = 'a'
          ..rotation = 1
          ..userData = {
            'list': [
              1,
              {'b': 2},
            ],
          };
        source.offset.set(1, 2);
        final copy = source.clone();

        expect(identical(copy.source, source.source), isTrue, reason: 'the source is shared');
        expect([copy.name, copy.wrapS, copy.rotation], ['a', RepeatWrapping, 1.0]);
        expect(copy.offset.toArray(), [1.0, 2.0]);
        expect(identical(copy.offset, source.offset), isFalse);
        expect(copy.userData, source.userData);
        expect(identical(copy.userData['list'], source.userData['list']), isFalse, reason: 'userData is deep-copied');
        expect(copy.version, 1, reason: 'copy sets needsUpdate');
      });

      test('setValues', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        final t = Texture()
          ..onUpdate = (_) {}
          ..image = Object();
        final offset = t.offset;
        t.setValues({
          'magFilter': NearestFilter,
          'offset': Vector2(3, 4),
          'nothing': 1,
          'name': null,
          'onUpdate': null,
          'image': null,
        });

        expect(t.magFilter, NearestFilter);
        expect(identical(t.offset, offset), isTrue, reason: 'vectors are copied into');
        expect(t.offset.toArray(), [3.0, 4.0]);

        // The reference assigns null without a warning (checked in Node); Dart can store it only in nullable
        // properties.
        expect(t.onUpdate, isNull);
        expect(t.image, isNull);
        expect(t.name, '');
        expect(messages, [
          "ENT.Texture.setValues(): property 'nothing' does not exist.",
          "ENT.Texture.setValues(): property 'name' is not nullable in Dart; null is ignored.",
        ]);
        expect(() => t.setValues({'width': 3}), throwsArgumentError, reason: 'width only has a getter');
      });

      test('toJSON', () {
        final t = Texture()
          ..userData = {
            'a': [
              1,
              {'b': 2},
            ],
          };
        final json = t.toJSON();

        expect(json['uuid'], t.uuid);
        expect(json['image'], t.source.uuid);
        json
          ..remove('uuid')
          ..remove('image');
        expect(json, {
          'metadata': {'version': 4.7, 'type': 'Texture', 'generator': 'Texture.toJSON'},
          'name': '',
          'mapping': 300,
          'channel': 0,
          'repeat': [1, 1],
          'offset': [0, 0],
          'center': [0, 0],
          'rotation': 0,
          'wrap': [1001, 1001],
          'format': 1023,
          'internalFormat': null,
          'type': 1009,
          'normalized': false,
          'colorSpace': '',
          'minFilter': 1008,
          'magFilter': 1006,
          'anisotropy': 1,
          'flipY': true,
          'generateMipmaps': true,
          'mipmapsAutoUpdate': true,
          'premultiplyAlpha': false,
          'unpackAlignment': 4,
          'userData': {
            'a': [
              1,
              {'b': 2},
            ],
          },
        });

        final meta = <String, Object?>{'textures': <String, Object?>{}, 'images': <String, Object?>{}};
        final first = t.toJSON(meta);
        expect(identical(t.toJSON(meta), first), isTrue, reason: 'cached in meta.textures');
        expect((meta['images'] as Map).containsKey(t.source.uuid), isTrue);
      });

      test('dispose event', () {
        final t = Texture();
        final types = <String>[];
        t.addEventListener('dispose', (event) => types.add(event.type));
        t.dispose();
        expect(types, ['dispose']);
      });
    });
  });
}
