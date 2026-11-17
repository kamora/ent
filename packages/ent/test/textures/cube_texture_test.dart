// The reference unit tests of CubeTexture, plus Dart tests of the source behaviour (expected values printed from the
// reference source in Node).

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Textures', () {
    group('CubeTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = CubeTexture();
        expect(object is Texture, true, reason: 'CubeTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = CubeTexture();
        expect(object, isNotNull, reason: 'Can instantiate a CubeTexture.');
      });

      // PUBLIC
      test('isCubeTexture', () {
        final object = CubeTexture();
        expect(object.isCubeTexture, isTrue, reason: 'CubeTexture.isCubeTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: images mapping flipY', () {
        final texture = CubeTexture();
        expectTextureState(texture, stateWith({'mapping': 301, 'flipY': false}));
        expect(texture.images, isEmpty);
      });

      test('images', () {
        final faces = <Object?>[DataImage(), DataImage()];
        final texture = CubeTexture()..images = faces;
        expect(texture.image, same(faces));
        expect(texture.images, same(faces));
      });

      test('clone', () {
        final texture = CubeTexture([DataImage()]);
        final clone = texture.clone();
        expect(clone, isA<CubeTexture>());
        expect(clone.source, same(texture.source));
      });

      test('toJSON of DataTexture faces', () {
        final texture = CubeTexture([
          DataTexture(Uint8List.fromList([1, 2, 3, 4]), 1, 1),
          DataTexture(Float32List.fromList([0.5]), 1, 1),
        ]);
        expect(texture.source.toJSON()['url'], [
          {
            'data': [1, 2, 3, 4],
            'width': 1,
            'height': 1,
            'type': 'Uint8Array',
          },
          {
            'data': [0.5],
            'width': 1,
            'height': 1,
            'type': 'Float32Array',
          },
        ]);
      });
    });
  });
}
