// The reference unit tests of RenderTarget3D.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Core', () {
    group('RenderTarget3D', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = RenderTarget3D();
        expect(object is EventDispatcher, true, reason: 'RenderTarget3D extends from EventDispatcher');

        final options = RenderTarget3D(1, 1, 1, {'magFilter': NearestFilter, 'wrapR': RepeatWrapping});
        expect(
          options.width == 1 &&
              options.height == 1 &&
              options.depth == 1 &&
              options.texture.magFilter == NearestFilter &&
              (options.texture as Data3DTexture).wrapR == RepeatWrapping,
          isTrue,
          reason: 'Can instantiate a RenderTarget3D with texture options.',
        );
      });

      // Dart test of the source behaviour

      test('3D textures', () {
        final target = RenderTarget3D(4, 3, 2, {'count': 2});
        expect(target.isRenderTarget3D, isTrue);
        expect(target.textures.every((t) => t is Data3DTexture && identical(t.renderTarget, target)), isTrue);
        expect([target.texture.width, target.texture.height, target.texture.depth], [4.0, 3.0, 2.0]);
        expect(target.texture.isRenderTargetTexture, isTrue);
        expect([target.texture.minFilter, target.texture.flipY], [LinearFilter, false]);
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('RenderTarget3D coverage', () {
    test('Instancing', () {
      final target = RenderTarget3D(2, 3, 4);
      expect([target.width, target.height, target.depth], [2, 3, 4]);
      expect(target.texture, isA<Data3DTexture>());
      final image = target.texture.image as DataImage;
      expect([image.width, image.height, image.depth], [2, 3, 4]);
      final small = RenderTarget3D();
      expect([small.width, small.height, small.depth], [1, 1, 1]);
    });

    test('defaults: isRenderTarget3D depth', () {
      final target = RenderTarget3D();
      expect([target.isRenderTarget3D, target.isRenderTarget, target.depth], [true, true, 1]);
    });
  });
}
