// The Flutter adapters of ent's platform services (exception E-PLATFORM): images decoded to straight RGBA,
// data URLs served by fetch, ImageUtils on FlutterImage. No GPU needed.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

void main() {
  setUpAll(() => FlutterPlatform.install(replace: true));

  // 2×2 straight RGBA, with one translucent and one transparent texel.
  final pixels = Uint8List.fromList([255, 0, 0, 255, 201, 99, 51, 128, 0, 0, 255, 255, 10, 20, 30, 0]);

  test('getDataURL encodes a PNG that the ImageLoader decodes to the same pixels', () async {
    final url = ImageUtils.getDataURL(FlutterImage.fromPixels(2, 2, pixels));
    expect(url, startsWith('data:image/png;base64,'));

    final image = await ImageLoader().loadAsync(url) as FlutterImage;
    expect(image.complete, isTrue);
    expect([image.width, image.height], [2, 2]);

    // The PNG decoder keeps straight colors as stored, translucent and transparent texels included, as a browser
    // hands them to WebGL (dart:ui would premultiply them).
    expect(image.pixels, pixels);
    expect(ImageUtils.getDataURL(image), url, reason: 'a loaded data URL is returned as it is');
  });

  test('a failing load fires error and completes', () async {
    final image = FlutterImage();
    Object? failure;
    image.addEventListener('error', (event) => failure = event);
    image.src = 'data:image/png;base64,AAAA';

    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(image.complete, isTrue);
    expect(failure, isNotNull);
    expect(image.pixels, isNull);
  });

  test('fetch serves data URLs; TextureSource sizes and sRGBToLinear use the image', () async {
    final response = await Loader.platform!.fetch(LoaderRequest(url: 'data:text/plain;base64,aGk='));
    expect(response.status, 200);
    expect(String.fromCharCodes(await response.bytes()), 'hi');

    final image = FlutterImage.fromPixels(2, 2, pixels);
    expect(TextureSource(image).getSize(Vector2()).toArray(), [2.0, 2.0]);

    final linear = ImageUtils.sRGBToLinear(image) as FlutterImage;
    expect(linear.pixels!.sublist(0, 8), [255, 0, 0, 255, 149, 32, 8, 55]);
  });
}
