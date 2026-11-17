import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Loaders', () {
    group('ImageLoader', () {
      late FakeLoaderPlatform platform;

      setUp(() => Loader.platform = platform = FakeLoaderPlatform());

      tearDown(() {
        Loader.platform = null;
        Cache.enabled = false;
        Cache.clear();
      });

      test('image request priority', () async {
        final future = ImageLoader().setPriority('high').loadAsync('/examples/textures/uv_grid_opengl.jpg');
        platform.images.single.finish();
        final image = await future;
        expect(image.fetchPriority, 'high');
      });

      // INHERITANCE
      test('Extending', () {
        final object = ImageLoader();
        expect(object, isA<Loader<LoaderImage>>(), reason: 'ImageLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        final object = ImageLoader();
        expect(object, isNotNull, reason: 'Can instantiate an ImageLoader.');
      });

      // Dart: behaviour through a fake platform
      test('load', () {
        final log = <String>[];
        final manager = LoadingManager(() => log.add('done'), null, (url) => log.add('error $url'));
        final loader = ImageLoader(manager)
          ..setPath('img/')
          ..setCrossOrigin('use-credentials');

        final image = loader.load('a.png', (image) => log.add('load ${image.src}'), null, (e) => log.add('fail $e'));
        // the data: check runs on the URL after the path is prepended, so this loader has no path
        final data = (ImageLoader(
          manager,
        )..setCrossOrigin('use-credentials')).load('data:x', (image) => log.add('load data'));

        expect((image as FakeImage).crossOriginValue, 'use-credentials');
        expect((data as FakeImage).crossOriginValue, isNull, reason: 'no CORS for data: URLs');

        image.finish();
        data.finish(error: true);

        expect(log, ['load img/a.png', 'error data:x', 'done']);
        expect(image.listeners['load'], isEmpty, reason: 'listeners removed');
      });

      test('cached image', () async {
        Cache.enabled = true;
        final log = <String>[];
        final loader = ImageLoader();

        final first = loader.load('c.png', (image) => log.add('first'));

        // still loading: the cached element is returned and waits for it
        final second = loader.load('c.png', (image) => log.add('second'));
        expect(second, same(first));

        (first as FakeImage).finish();
        expect(log, ['first', 'second']);

        // complete: answered a turn later
        loader.load('c.png', (image) => log.add('third'));
        expect(log.length, 2);
        await settle();
        expect(log, ['first', 'second', 'third']);
        expect(platform.images.length, 1);
      });

      test('failed image leaves the cache', () {
        Cache.enabled = true;
        final loader = ImageLoader();
        final image = loader.load('bad.png') as FakeImage;
        image.finish(error: true);
        expect(Cache.get('image:bad.png'), isNull);
      });
    });
  });
}
