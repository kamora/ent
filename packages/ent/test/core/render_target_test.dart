// The reference unit tests of RenderTarget, plus Dart tests of members the reference does not test.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

DataImage _image(Texture texture) => texture.image as DataImage;

void main() {
  group('Core', () {
    group('RenderTarget', () {
      // Constructor options
      test('Constructor', () {
        final empty = RenderTarget();
        expect(empty.textures.length == 1, isTrue, reason: 'Can instantiate a RenderTarget with no arguments.');

        final sized = RenderTarget(1, 1);
        expect(
          sized.width == 1 && sized.height == 1 && sized.textures.length == 1,
          isTrue,
          reason: 'Can instantiate a RenderTarget with custom size.',
        );

        final mrt = RenderTarget(1, 1, {'count': 2});
        expect(
          mrt.width == 1 && mrt.height == 1 && mrt.textures.length == 2,
          isTrue,
          reason: 'Can instantiate a RenderTarget with custom count (MRT).',
        );

        final options = RenderTarget(1, 1, {'magFilter': NearestFilter});
        expect(
          options.width == 1 && options.height == 1 && options.texture.magFilter == NearestFilter,
          isTrue,
          reason: 'Can instantiate a RenderTarget with texture options.',
        );
      });

      // PUBLIC
      test('setSize', () {
        final renderTarget = RenderTarget();
        renderTarget.setSize(128, 128);
        expect(
          renderTarget.width == 128 && renderTarget.height == 128,
          isTrue,
          reason: 'Sets a size with width and height',
        );
        expect(
          _image(renderTarget.texture).width == 128 && _image(renderTarget.texture).height == 128,
          isTrue,
          reason: 'Texture image is updated on resize',
        );
        expect(
          renderTarget.viewport.width == 128 && renderTarget.viewport.height == 128,
          isTrue,
          reason: 'Viewport is updated on resize',
        );
        expect(
          renderTarget.scissor.width == 128 && renderTarget.scissor.height == 128,
          isTrue,
          reason: 'Scissor is updated on resize',
        );

        final mrt = RenderTarget(0, 0, {'count': 2});
        mrt.setSize(128, 128);
        expect(mrt.width == 128 && mrt.height == 128, isTrue, reason: 'Sets a size with width and height');
        expect(
          _image(mrt.textures[0]).width == 128 &&
              _image(mrt.textures[0]).height == 128 &&
              _image(mrt.textures[1]).width == 128 &&
              _image(mrt.textures[1]).height == 128,
          isTrue,
          reason: 'Texture images are updated on resize',
        );
        expect(
          mrt.viewport.width == 128 && mrt.viewport.height == 128,
          isTrue,
          reason: 'Viewport is updated on resize',
        );
        expect(mrt.scissor.width == 128 && mrt.scissor.height == 128, isTrue, reason: 'Scissor is updated on resize');

        final renderTarget3D = RenderTarget();
        renderTarget3D.setSize(128, 128, 16);
        expect(
          renderTarget3D.width == 128 && renderTarget3D.height == 128 && renderTarget3D.depth == 16,
          isTrue,
          reason: 'Sets a size with width, height, and depth',
        );
        expect(
          _image(renderTarget3D.texture).width == 128 &&
              _image(renderTarget3D.texture).height == 128 &&
              _image(renderTarget3D.texture).depth == 16,
          isTrue,
          reason: 'Texture image is updated on resize',
        );
        expect(
          renderTarget3D.viewport.width == 128 && renderTarget3D.viewport.height == 128,
          isTrue,
          reason: 'Viewport is updated on resize',
        );
        expect(
          renderTarget3D.scissor.width == 128 && renderTarget3D.scissor.height == 128,
          isTrue,
          reason: 'Scissor is updated on resize',
        );
      });

      // Dart tests of the source behaviour

      test('defaults', () {
        final target = RenderTarget(4, 2);
        final texture = target.texture;
        expect(target.isRenderTarget, isTrue);
        expect([target.depthBuffer, target.stencilBuffer, target.samples, target.multiview], [true, false, 0, false]);
        expect(target.viewport.toArray(), [0.0, 0.0, 4.0, 2.0]);
        expect(texture.isRenderTargetTexture, isTrue);
        expect(identical(texture.renderTarget, target), isTrue);
        expect([texture.minFilter, texture.generateMipmaps, texture.flipY], [LinearFilter, false, false]);
        expect([texture.width, texture.height, texture.depth], [4.0, 2.0, 1.0]);
        expect(texture.isArrayTexture, isFalse);
      });

      test('setSize dispatches dispose only when the size changes', () {
        final target = RenderTarget(2, 2);
        var disposed = 0;
        target.addEventListener('dispose', (_) => disposed++);
        target.setSize(2, 2);
        expect(disposed, 0);
        target.setSize(3, 2, 4);
        expect(disposed, 1);
        expect(target.texture.isArrayTexture, isTrue);
      });

      test('depthTexture back reference', () {
        final target = RenderTarget();
        final depth = Texture();
        target.depthTexture = depth;
        expect(identical(depth.renderTarget, target), isTrue);
        target.depthTexture = null;
        expect(depth.renderTarget, isNull);
      });

      test('clone/copy', () {
        final source = RenderTarget(8, 4, {'count': 2, 'samples': 4});
        source.depthTexture = Texture();
        source.scissorTest = true;
        final copy = source.clone();

        expect([copy.width, copy.height, copy.samples, copy.scissorTest, copy.textures.length], [8, 4, 4, true, 2]);
        expect(identical(copy.texture.renderTarget, copy), isTrue);
        expect(identical(copy.texture.image, source.texture.image), isFalse, reason: 'image object is not shared');
        expect(_image(copy.texture).width, 8);
        expect(identical(copy.depthTexture, source.depthTexture), isFalse, reason: 'own depth texture is cloned');
        expect(identical(copy.depthTexture!.renderTarget, copy), isTrue);

        final shared = Texture();
        final other = RenderTarget()..depthTexture = shared;
        shared.renderTarget = null;
        expect(
          identical(RenderTarget().copy(other).depthTexture, shared),
          isTrue,
          reason: 'foreign depth texture is shared',
        );
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('RenderTarget coverage', () {
    test('Instancing', () {
      final target = RenderTarget();
      expect([target.width, target.height, target.depth], [1, 1, 1]);
      expect(target.isRenderTarget, isTrue);
      expect(target.textures.length, 1);
      expect(target.texture, same(target.textures[0]));
      final sized = RenderTarget(4, 3, {'samples': 2, 'depthBuffer': false, 'count': 2});
      expect([sized.width, sized.height, sized.samples, sized.depthBuffer, sized.textures.length], [4, 3, 2, false, 2]);
      expect(sized.viewport.toArray(), [0, 0, 4, 3]);
    });

    test('defaults: isRenderTarget width height depth scissor scissorTest viewport textures texture depthBuffer '
        'stencilBuffer resolveColorBuffer resolveDepthBuffer resolveStencilBuffer storeMultisampledColorBuffer '
        'storeMultisampledDepthBuffer storeMultisampledStencilBuffer samples multiview useArrayDepthTexture', () {
      final target = RenderTarget();
      expect(target.isRenderTarget, isTrue);
      expect([target.width, target.height, target.depth], [1, 1, 1]);
      expect(target.scissor.toArray(), [0, 0, 1, 1]);
      expect(target.scissorTest, isFalse);
      expect(target.viewport.toArray(), [0, 0, 1, 1]);
      expect(target.textures.length, 1);
      expect(target.texture, same(target.textures[0]));
      expect(
        [
          target.depthBuffer,
          target.stencilBuffer,
          target.resolveColorBuffer,
          target.resolveDepthBuffer,
          target.resolveStencilBuffer,
          target.storeMultisampledColorBuffer,
          target.storeMultisampledDepthBuffer,
          target.storeMultisampledStencilBuffer,
          target.samples,
          target.multiview,
          target.useArrayDepthTexture,
        ],
        [true, false, true, true, true, true, true, true, 0, false, false],
      );
    });
  });
}
