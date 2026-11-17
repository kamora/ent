// The reference unit tests of DepthTexture, plus Dart tests of the source behaviour and of CubeDepthTexture (no
// reference test; expected values printed from the reference source in Node).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Textures', () {
    group('DepthTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = DepthTexture();
        expect(object is Texture, true, reason: 'DepthTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = DepthTexture();
        expect(object, isNotNull, reason: 'Can instantiate a DepthTexture.');
      });

      // PUBLIC
      test('isDepthTexture', () {
        final object = DepthTexture();
        expect(object.isDepthTexture, isTrue, reason: 'DepthTexture.isDepthTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: image format type compareFunction', () {
        final texture = DepthTexture(4, 2);
        expectTextureState(
          texture,
          stateWith({
            'magFilter': 1003,
            'minFilter': 1003,
            'format': 1026,
            'type': 1014,
            'generateMipmaps': false,
            'flipY': false,
            'width': 4,
            'height': 2,
            'depth': 1,
          }),
        );
        expect(texture.compareFunction, isNull);
      });

      test('format validation', () {
        expect(
          () => DepthTexture(1, 1, UnsignedIntType, null, null, null, NearestFilter, NearestFilter, null, RGBAFormat),
          throwsA(
            isA<EntError>().having(
              (e) => e.message,
              'message',
              'ENT.DepthTexture: format must be either ENT.DepthFormat or ENT.DepthStencilFormat',
            ),
          ),
        );
        expect(
          DepthTexture(1, 1, UnsignedInt248Type, null, null, null, 1003, 1003, null, DepthStencilFormat).format,
          1027,
        );
      });

      test('copy clone', () {
        final texture = DepthTexture(4, 2)..compareFunction = LessCompare;
        final clone = texture.clone();
        expect(clone, isA<DepthTexture>());
        expect(clone.compareFunction, 513);
        expect(clone.source, isNot(same(texture.source)), reason: 'see #30540');
        expect(clone.image, isNot(same(texture.image)));
        final image = clone.image as DataImage;
        expect([image.width, image.height, image.depth], [4, 2, 1]);
        expect(clone.version, 1);
      });

      test('toJSON', () {
        final texture = DepthTexture(4, 2)..compareFunction = LessCompare;
        final previous = getConsoleFunction();
        setConsoleFunction((type, message, params) {});
        final json = texture.toJSON();
        setConsoleFunction(previous);
        expect(json['compareFunction'], 513);
      });
    });

    group('CubeDepthTexture', () {
      test('Extending', () {
        final Object object = CubeDepthTexture(8);
        expect(object is DepthTexture, true);
      });

      test('isCubeDepthTexture isCubeTexture', () {
        final object = CubeDepthTexture(8);
        expect(object.isCubeDepthTexture, isTrue);
        expect(object.isCubeTexture, isTrue);
      });

      test('defaults: images mapping', () {
        final texture = CubeDepthTexture(8);
        expectTextureState(
          texture,
          stateWith({
            'magFilter': 1003,
            'minFilter': 1003,
            'format': 1026,
            'type': 1014,
            'mapping': 301,
            'generateMipmaps': false,
            'flipY': false,
          }),
        );
        final images = texture.images as List<Object?>;
        expect(images.length, 6);
        expect(images[0], same(images[5]), reason: '6 identical image descriptors');
        final face = images[0] as DataImage;
        expect([face.width, face.height, face.depth], [8, 8, 1]);
      });

      test('clone (the reference uses Object.assign on the face array)', () {
        final clone = CubeDepthTexture(8).clone();
        expect(clone, isA<CubeDepthTexture>());
        final image = clone.image as Map<String, Object?>;
        expect(image.keys, ['0', '1', '2', '3', '4', '5']);
        final face = image['0'] as DataImage;
        expect([face.width, face.height, face.depth], [8, 8, 1]);
      });
    });
  });
}
