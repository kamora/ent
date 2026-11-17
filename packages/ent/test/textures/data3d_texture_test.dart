// The reference unit tests of Data3DTexture, plus Dart tests of members the reference does not test.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Textures', () {
    group('Data3DTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = Data3DTexture();
        expect(object is Texture, true, reason: 'Data3DTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Data3DTexture();
        expect(object, isNotNull, reason: 'Can instantiate a Data3DTexture.');
      });

      // PUBLIC
      test('isData3DTexture', () {
        final object = Data3DTexture();
        expect(object.isData3DTexture, isTrue, reason: 'Data3DTexture.isData3DTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults', () {
        final data = Uint8List(24);
        final t = Data3DTexture(data, 2, 3, 4);
        final image = t.image as DataImage;
        expect(identical(image.data, data), isTrue);
        expect([t.width, t.height, t.depth], [2.0, 3.0, 4.0]);
        expect(
          [t.magFilter, t.minFilter, t.wrapR, t.generateMipmaps, t.flipY, t.unpackAlignment],
          [NearestFilter, NearestFilter, ClampToEdgeWrapping, false, false, 1],
        );
        expect(t.isArrayTexture, isFalse, reason: 'the base constructor sees a null image');
      });

      test('clone/copy keep wrapR', () {
        final t = Data3DTexture()..wrapR = RepeatWrapping;
        final copy = t.clone();
        expect(copy, isA<Data3DTexture>());
        expect(copy.wrapR, RepeatWrapping);
      });

      test('setValues knows wrapR', () {
        final t = Data3DTexture()..setValues({'wrapR': MirroredRepeatWrapping});
        expect(t.wrapR, MirroredRepeatWrapping);
      });
    });
  });
}
