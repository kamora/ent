// Dart tests of ImageUtils (the reference has no unit test for it). Expected values were printed from the reference
// source in Node.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// A platform whose images are strings, recording what the core asks of it.
class _FakePlatform implements ImagePlatform {
  final calls = <String>[];

  @override
  bool isImage(Object image) => image is String;

  @override
  String getDataURL(Object image, String type) {
    calls.add('getDataURL $image $type');
    return 'data:$type;$image';
  }

  @override
  Object sRGBToLinear(Object image) {
    calls.add('sRGBToLinear $image');
    return 'linear $image';
  }

  @override
  ImageSize? getSize(Object image) => image is String ? (width: 5, height: 6, depth: 0) : null;
}

void main() {
  group('Extras', () {
    group('ImageUtils', () {
      test('sRGBToLinear on data images', () {
        final u8 = ImageUtils.sRGBToLinear(
          DataImage(data: Uint8List.fromList([0, 10, 128, 255]), width: 2, height: 1),
        ) as DataImage;
        expect(u8.data, isA<Uint8List>());
        expect(u8.data, [0, 0, 55, 255]);
        expect([u8.width, u8.height], [2, 1]);

        final f32 = ImageUtils.sRGBToLinear(DataImage(data: Float32List.fromList([0, 0.02, 0.5, 1]))) as DataImage;
        expect(f32.data, [0, 0.0015479875728487968, 0.21404114365577698, 1]);

        final u16 = ImageUtils.sRGBToLinear(DataImage(data: Uint16List.fromList([0, 3, 200, 1000]))) as DataImage;
        expect(u16.data, [0, 12, 30913, 46003], reason: 'floats stored into an integer array, wrapped as JS does');

        final plain = ImageUtils.sRGBToLinear(DataImage(data: <num>[0, 0.5, 1])) as DataImage;
        expect(plain.data, [0, 0.2140411404715882, 1]);
      });

      test('sRGBToLinear leaves the input untouched', () {
        final data = Uint8List.fromList([128]);
        ImageUtils.sRGBToLinear(DataImage(data: data));
        expect(data, [128]);
      });

      test('sRGBToLinear warns for an unsupported image', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        final image = DataImage(width: 1);
        expect(identical(ImageUtils.sRGBToLinear(image), image), isTrue);
        expect(messages, ['ENT.ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied.']);
      });

      test('getDataURL needs a platform', () {
        expect(() => ImageUtils.getDataURL('image'), throwsStateError);
      });

      test('platform adapter', () {
        final platform = _FakePlatform();
        ImageUtils.platform = platform;
        addTearDown(() => ImageUtils.platform = null);

        expect(ImageUtils.getDataURL('img'), 'data:image/png;img');
        expect(ImageUtils.sRGBToLinear('img'), 'linear img');
        expect(TextureSource('img').toJSON()['url'], 'data:image/png;img');
        expect(Texture('img').width, 5.0);
        expect(platform.calls, ['getDataURL img image/png', 'sRGBToLinear img', 'getDataURL img image/png']);
      });
    });
  });
}
