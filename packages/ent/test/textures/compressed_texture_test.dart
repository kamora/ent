// The reference unit tests of CompressedTexture and CompressedArrayTexture, plus Dart tests of the source behaviour and
// of CompressedCubeTexture (no reference test; expected values printed from the reference source in Node).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Textures', () {
    group('CompressedTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = CompressedTexture();
        expect(object is Texture, true, reason: 'CompressedTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = CompressedTexture();
        expect(object, isNotNull, reason: 'Can instantiate a CompressedTexture.');
      });

      // PUBLIC
      test('isCompressedTexture', () {
        final object = CompressedTexture();
        expect(object.isCompressedTexture, isTrue, reason: 'CompressedTexture.isCompressedTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: image mipmaps flipY generateMipmaps', () {
        final mipmaps = <Object?>[];
        final texture = CompressedTexture(mipmaps, 8, 4);
        expectTextureState(texture, stateWith({'generateMipmaps': false, 'flipY': false, 'width': 8, 'height': 4}));
        expect(texture.mipmaps, same(mipmaps));
        expect(CompressedTexture().mipmaps, isEmpty);
      });

      test('clone', () {
        expect(CompressedTexture(<Object?>[], 8, 4).clone(), isA<CompressedTexture>());
      });
    });

    group('CompressedArrayTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = CompressedArrayTexture();
        expect(object is CompressedTexture, true, reason: 'CompressedArrayTexture extends from CompressedTexture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = CompressedArrayTexture();
        expect(object, isNotNull, reason: 'Can instantiate a CompressedArrayTexture.');
      });

      // PUBLIC
      test('isCompressedArrayTexture', () {
        final object = CompressedArrayTexture();
        expect(
          object.isCompressedArrayTexture,
          isTrue,
          reason: 'CompressedArrayTexture.isCompressedArrayTexture should be true',
        );
      });

      // Dart tests of the source behaviour

      test('defaults: image wrapR', () {
        final texture = CompressedArrayTexture(<Object?>[], 8, 4, 3);
        expectTextureState(
          texture,
          stateWith({'generateMipmaps': false, 'flipY': false, 'width': 8, 'height': 4, 'depth': 3}),
        );
        expect(texture.wrapR, 1001);
      });

      test('copy wrapR', () {
        final source = CompressedArrayTexture(<Object?>[], 1, 1, 1)..wrapR = 1000;
        expect(CompressedArrayTexture().copy(source).wrapR, 1000);
        expect(source.clone(), isA<CompressedArrayTexture>());
      });

      test('addLayerUpdate clearLayerUpdates layerUpdates', () {
        final texture = CompressedArrayTexture()
          ..addLayerUpdate(1)
          ..addLayerUpdate(1);
        expect(texture.layerUpdates.toList(), [1]);
        texture.clearLayerUpdates();
        expect(texture.layerUpdates, isEmpty);
      });
    });

    group('CompressedCubeTexture', () {
      test('Extending', () {
        final Object object = CompressedCubeTexture([DataImage(width: 16, height: 8)]);
        expect(object is CompressedTexture, true);
      });

      test('isCompressedCubeTexture isCubeTexture', () {
        final object = CompressedCubeTexture([DataImage(width: 16, height: 8)]);
        expect(object.isCompressedCubeTexture, isTrue);
        expect(object.isCubeTexture, isTrue);
      });

      test('defaults: image mapping', () {
        final faces = <Object?>[
          {'width': 16, 'height': 8},
          for (var i = 0; i < 5; i++) <String, Object?>{},
        ];
        final texture = CompressedCubeTexture(faces);

        // The faces replace the dimension image, so the texture reports a size of 0 (an array has no width).
        expectTextureState(texture, stateWith({'mapping': 301, 'generateMipmaps': false, 'flipY': false}));
        expect(texture.image, same(faces));
      });

      test('clone (the reference throws; E-CLONE)', () {
        final texture = CompressedCubeTexture([DataImage(width: 2, height: 2)]);
        final clone = texture.clone();
        expect(clone, isA<CompressedCubeTexture>());
        expect(clone.source, same(texture.source));
      });
    });
  });
}
