import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Loaders', () {
    group('ImageBitmapLoader', () {
      late FakeLoaderPlatform platform;
      late List<String> log;

      setUp(() {
        Loader.platform = platform = FakeLoaderPlatform();
        log = [];
        setConsoleFunction((type, message, params) => log.add(message));
      });

      tearDown(() {
        Loader.platform = null;
        Cache.enabled = false;
        Cache.clear();
        setConsoleFunction(null);
      });

      // INHERITANCE
      test('Extending', () {
        final object = ImageBitmapLoader();
        expect(object, isA<Loader<Object>>(), reason: 'ImageBitmapLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        final object = ImageBitmapLoader();
        expect(object, isNotNull, reason: 'Can instantiate an ImageBitmapLoader.');
      });

      // PROPERTIES
      test('options', () {
        expect(ImageBitmapLoader().options, {'premultiplyAlpha': 'none'}, reason: 'ImageBitmapLoader defines options.');
      });

      // PUBLIC
      test('isImageBitmapLoader', () {
        expect(
          ImageBitmapLoader().isImageBitmapLoader,
          isTrue,
          reason: 'ImageBitmapLoader.isImageBitmapLoader should be true',
        );
      });

      test('load', () async {
        platform.resources['data:image/png'] = FakeResource(Uint8List(8));
        Cache.enabled = true;

        final [first, second] = await Future.wait([
          ImageBitmapLoader().loadAsync('data:image/png'),
          ImageBitmapLoader().loadAsync('data:image/png'),
        ]);

        expect(first, {
          'bitmap': 8,
          'options': {'premultiplyAlpha': 'none', 'colorSpaceConversion': 'none'},
        }, reason: 'The first request resolves with an image bitmap.');
        expect(second, same(first), reason: 'The second request resolves with an image bitmap.');
        expect(platform.requests.length, 1);
      });

      // Dart: warnings, errors and options (as in the reference)
      test('warnings without support', () {
        platform.hasCreateImageBitmap = false;
        ImageBitmapLoader();
        Loader.platform = null;
        ImageBitmapLoader();

        expect(log, [
          'ENT.ImageBitmapLoader: createImageBitmap() not supported.',
          'ENT.ImageBitmapLoader: createImageBitmap() not supported.',
          'ENT.ImageBitmapLoader: fetch() not supported.',
        ]);
      });

      test('setOptions credentials errors', () async {
        platform.resources['empty.png'] = FakeResource(Uint8List(0));
        Cache.enabled = true;

        final loader = ImageBitmapLoader()..setCrossOrigin('use-credentials');
        expect(loader.setOptions({'imageOrientation': 'flipY'}), same(loader));

        final errors = <Object>[];
        loader.load('empty.png', null, null, errors.add);

        // a second load of the same URL waits for the cached request and receives its error
        loader.load('empty.png', null, null, errors.add);
        await settle();

        expect(platform.requests.single.credentials, 'include');
        expect(errors.length, 2);
        expect(errors.first, isA<StateError>());
        expect(Cache.get('image-bitmap:empty.png'), isNull);
      });
    });
  });
}
