import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Loaders', () {
    group('FileLoader', () {
      late FakeLoaderPlatform platform;
      late List<String> log;

      setUp(() {
        platform = FakeLoaderPlatform();
        Loader.platform = platform;
        log = [];
        setConsoleFunction((type, message, params) => log.add('$type $message'));
      });

      tearDown(() {
        Loader.platform = null;
        Cache.enabled = false;
        Cache.clear();
        setConsoleFunction(null);
      });

      // INHERITANCE
      test('Extending', () {
        final object = FileLoader();
        expect(object, isA<Loader<Object?>>(), reason: 'FileLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        final object = FileLoader();
        expect(object, isNotNull, reason: 'Can instantiate a FileLoader.');
      });

      // Dart: behaviour through a fake platform (the reference runs it against a browser only)
      test('load text json arraybuffer blob document', () async {
        platform.resources['a.txt'] = FakeResource.text('\u{FEFF}héllo');
        platform.resources['a.json'] = FakeResource.text('{"a": [1, 2]}');

        expect(await FileLoader().loadAsync('a.txt'), 'héllo');
        expect(await (FileLoader()..setResponseType('json')).loadAsync('a.json'), {
          'a': [1, 2],
        });

        final buffer = await (FileLoader()..setResponseType('arraybuffer')).loadAsync('a.json');
        expect(buffer, isA<ByteBuffer>());
        expect(utf8.decode((buffer! as ByteBuffer).asUint8List()), '{"a": [1, 2]}');

        expect(await (FileLoader()..setResponseType('blob')).loadAsync('a.txt'), isA<Uint8List>());
        expect(
          await (FileLoader()
                ..setResponseType('document')
                ..setMimeType('text/html'))
              .loadAsync('a.txt'),
          {'document': 'héllo', 'mimeType': 'text/html'},
        );
      });

      test('mimeType charset', () async {
        platform.resources['l.txt'] = FakeResource(Uint8List.fromList([0x63, 0x61, 0x66, 0xe9]));

        final latin1 = FileLoader()..setMimeType('text/plain; charset="ISO-8859-1"');
        expect(await latin1.loadAsync('l.txt'), 'café');

        final unknown = FileLoader()..setMimeType('text/plain; charset=klingon');
        await expectLater(unknown.loadAsync('l.txt'), throwsArgumentError);
      });

      test('setResponseType setMimeType', () {
        final loader = FileLoader();
        expect(loader.setResponseType('json'), same(loader));
        expect(loader.setMimeType('text/plain'), same(loader));
        expect([loader.responseType, loader.mimeType], ['json', 'text/plain']);
      });

      test('request', () async {
        platform.resources['p/a.txt'] = FakeResource.text('x');
        final loader = FileLoader()
          ..setPath('p/')
          ..setRequestHeader({'X-Test': '1'})
          ..setWithCredentials(true)
          ..setPriority('high')
          ..setCache('no-store');

        await loader.loadAsync('a.txt');

        final request = platform.requests.single;
        expect(
          [request.url, request.headers, request.credentials, request.priority, request.cache],
          [
            'p/a.txt',
            {'X-Test': '1'},
            'include',
            'high',
            'no-store',
          ],
        );
      });

      test('duplicate requests share one fetch', () async {
        platform.resources['d.txt'] = FakeResource.text('shared');
        final results = <Object?>[];
        final manager = LoadingManager();
        var started = 0;
        manager.onStart = (url, loaded, total) => started++;

        FileLoader(manager)
          ..load('d.txt', results.add)
          ..load('d.txt', results.add);

        await settle();
        expect(results, ['shared', 'shared']);
        expect(platform.requests.length, 1);
        expect(started, 1);
      });

      test('progress', () async {
        platform.resources['big.bin'] = FakeResource(Uint8List(10), headers: {'Content-Length': '10'}, chunks: [4, 6]);
        platform.resources['nginx.bin'] = FakeResource(
          Uint8List(3),
          headers: {'X-File-Size': '3', 'Content-Length': 'junk'},
          chunks: [3],
        );
        platform.resources['nan.bin'] = FakeResource(Uint8List(2), headers: {'Content-Length': 'junk'}, chunks: [2]);
        platform.resources['none.bin'] = FakeResource(Uint8List(2), chunks: [2]);

        Future<List<List<Object>>> events(String url) async {
          final list = <List<Object>>[];
          await FileLoader().loadAsync(url, (e) => list.add([e.type, e.lengthComputable, e.loaded, e.total]));
          return list;
        }

        expect(await events('big.bin'), [
          ['progress', true, 4, 10],
          ['progress', true, 10, 10],
        ]);
        expect(await events('nginx.bin'), [
          ['progress', true, 3, 3],
        ]);

        // parseInt( 'junk' ) is NaN: computable, total 0
        expect(await events('nan.bin'), [
          ['progress', true, 2, 0],
        ]);
        expect(await events('none.bin'), [
          ['progress', false, 2, 0],
        ]);
      });

      test('HTTP errors', () async {
        final errors = <Object>[];
        final ended = <String>[];
        final manager = LoadingManager(null, (url, loaded, total) => ended.add(url), (url) => ended.add('error $url'));

        FileLoader(manager).load('missing.txt', null, null, errors.add);
        await settle();

        expect(errors.single, isA<HttpError>());
        expect((errors.single as HttpError).message, 'fetch for "missing.txt" responded with 404: Not Found');
        expect((errors.single as HttpError).response.status, 404);
        expect(ended, ['error missing.txt', 'missing.txt']);
      });

      test('status 0', () async {
        platform.resources['file.txt'] = FakeResource.text('zero', status: 0);
        expect(await FileLoader().loadAsync('file.txt'), 'zero');
        expect(log, ['warn ENT.FileLoader: HTTP Status 0 received.']);
      });

      test('Cache', () async {
        Cache.enabled = true;
        platform.resources['c.txt'] = FakeResource.text('cached');

        expect(await FileLoader().loadAsync('c.txt'), 'cached');
        expect(Cache.get('file:c.txt'), 'cached');
        expect(await FileLoader().loadAsync('c.txt'), 'cached');
        expect(platform.requests.length, 1);
      });

      test('abort', () async {
        platform
          ..resources['slow.txt'] = FakeResource.text('late')
          ..autoRespond = false;

        final loader = FileLoader();
        final errors = <Object>[];
        loader.load('slow.txt', (_) => fail('aborted'), null, errors.add);
        expect(loader.abort(), same(loader));
        await settle();

        expect(errors.single, isA<AbortError>());

        // the loading manager aborts loaders that use it
        final manager = LoadingManager();
        FileLoader(manager).load('slow.txt', (_) => fail('aborted'), null, errors.add);
        manager.abort();
        platform.release();
        await settle();
        expect(errors.length, 2);
      });

      test('without a platform', () {
        Loader.platform = null;
        expect(() => FileLoader().load('nowhere.txt'), throwsStateError);
      });
    });
  });
}
