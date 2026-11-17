// The reference unit tests of FramebufferTexture and CanvasTexture, plus Dart tests of the source behaviour and of
// ExternalTexture (no reference test; expected values printed from the reference source in Node).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Textures', () {
    group('FramebufferTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = FramebufferTexture();
        expect(object is Texture, true, reason: 'FramebufferTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = FramebufferTexture();
        expect(object, isNotNull, reason: 'Can instantiate a FramebufferTexture.');
      });

      // PUBLIC
      test('isFramebufferTexture', () {
        final object = FramebufferTexture();
        expect(object.isFramebufferTexture, isTrue, reason: 'FramebufferTexture.isFramebufferTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: image magFilter minFilter generateMipmaps needsUpdate', () {
        expectTextureState(
          FramebufferTexture(4, 2),
          stateWith({
            'version': 1,
            'magFilter': 1003,
            'minFilter': 1003,
            'generateMipmaps': false,
            'width': 4,
            'height': 2,
          }),
        );
      });

      test('copy clone', () {
        final texture = FramebufferTexture(4, 2);
        final clone = texture.clone();
        expect(clone, isA<FramebufferTexture>());
        expect(clone.source, isNot(same(texture.source)));
        final image = clone.image as DataImage;
        expect([image.width, image.height, image.depth], [4, 2, null]);
        expect(clone.version, 2);
      });
    });

    group('CanvasTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = CanvasTexture();
        expect(object is Texture, true, reason: 'CanvasTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = CanvasTexture();
        expect(object, isNotNull, reason: 'Can instantiate a CanvasTexture.');
      });

      // PUBLIC
      test('isCanvasTexture', () {
        final object = CanvasTexture();
        expect(object.isCanvasTexture, isTrue, reason: 'CanvasTexture.isCanvasTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: needsUpdate image', () {
        final texture = CanvasTexture();
        expectTextureState(texture, stateWith({'version': 1}));
        expect(texture.image, Texture.DEFAULT_IMAGE);

        final canvas = Object();
        expect(CanvasTexture(canvas).image, same(canvas));
      });

      test('clone', () {
        expect(CanvasTexture().clone(), isA<CanvasTexture>());
      });
    });

    group('ExternalTexture', () {
      test('Extending', () {
        final Object object = ExternalTexture();
        expect(object is Texture, true);
      });

      test('isExternalTexture', () {
        expect(ExternalTexture().isExternalTexture, isTrue);
      });

      test('defaults: sourceTexture', () {
        final texture = ExternalTexture();
        expectTextureState(texture, baseState);
        expect(texture.sourceTexture, isNull);
      });

      test('copy clone', () {
        final handle = Object();
        final clone = ExternalTexture(handle).clone();
        expect(clone, isA<ExternalTexture>());
        expect(clone.sourceTexture, same(handle));
      });
    });
  });
}
