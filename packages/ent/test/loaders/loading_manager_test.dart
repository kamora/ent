import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Loaders', () {
    group('LoadingManager', () {
      // INSTANCING
      test('Instancing', () {
        final object = LoadingManager();
        expect(object, isNotNull, reason: 'Can instantiate a LoadingManager.');
      });

      // PUBLIC
      test('addHandler/getHandler/removeHandler', () {
        final loadingManager = LoadingManager();
        final loader = Loader<Object?>();

        final regex1 = RegExp(r'\.jpg$', caseSensitive: false);

        // Dart RegExp has no `g` flag or lastIndex state (#17920 cannot happen)
        final regex2 = RegExp(r'\.jpg$', caseSensitive: false);

        loadingManager.addHandler(regex1, loader);

        expect(loadingManager.getHandler('foo.jpg'), same(loader), reason: 'Returns the expected loader.');
        expect(
          loadingManager.getHandler('foo.jpg.png'),
          isNull,
          reason: 'Returns null since the correct file extension is not at the end of the file name.',
        );
        expect(loadingManager.getHandler('foo.jpeg'), isNull, reason: 'Returns null since file extension is wrong.');

        loadingManager.removeHandler(regex1);
        loadingManager.addHandler(regex2, loader);

        expect(loadingManager.getHandler('foo.jpg'), same(loader), reason: 'Returns the expected loader.');
        expect(loadingManager.getHandler('foo.jpg'), same(loader), reason: 'Test twice, see #17920.');
      });

      test('abortController - lazy instantiation', () {
        // The reference also checks the private field: null at first, set on first access (E-PRIVATE); what shows
        // from outside is one instance per access until abort().
        final loadingManager = LoadingManager();
        final controller = loadingManager.abortController;
        expect(controller, isA<AbortController>(), reason: 'abortController returns an AbortController instance.');

        final controller2 = loadingManager.abortController;
        expect(controller2, same(controller), reason: 'Subsequent accesses return the same AbortController instance.');
      });

      test('abort() - aborts controller and resets', () {
        final loadingManager = LoadingManager();
        final controller = loadingManager.abortController;
        expect(controller.signal.aborted, isFalse, reason: 'Controller signal is not aborted initially.');

        expect(loadingManager.abort(), same(loadingManager));
        expect(controller.signal.aborted, isTrue, reason: 'Controller signal is aborted after calling abort().');
      });

      test('abortController - recreation after abort', () {
        final loadingManager = LoadingManager();
        final controller1 = loadingManager.abortController;
        loadingManager.abort();
        expect(controller1.signal.aborted, isTrue, reason: 'First controller is aborted.');

        final controller2 = loadingManager.abortController;
        expect(
          controller2,
          isNot(same(controller1)),
          reason: 'New controller is a different instance from the aborted one.',
        );
        expect(controller2.signal.aborted, isFalse, reason: 'New controller signal is not aborted.');
      });

      // Dart: item bookkeeping (as in the reference, which has no test for it)
      test('itemStart itemEnd itemError onStart onLoad onProgress onError', () {
        final log = <String>[];
        final manager = LoadingManager(
          () => log.add('load'),
          (url, loaded, total) => log.add('progress $url $loaded/$total'),
          (url) => log.add('error $url'),
        )..onStart = (url, loaded, total) => log.add('start $url $loaded/$total');

        manager
          ..itemStart('a')
          ..itemStart('b')
          ..itemError('b')
          ..itemEnd('a')
          ..itemEnd('b')
          ..itemStart('c')
          ..itemEnd('c');

        expect(log, [
          'start a 0/1',
          'error b',
          'progress a 1/2',
          'progress b 2/2',
          'load',
          'start c 2/3',
          'progress c 3/3',
          'load',
        ]);
      });

      test('resolveURL setURLModifier', () {
        final manager = LoadingManager();
        expect(manager.resolveURL('a.png'), 'a.png');
        expect(manager.setURLModifier((url) => 'cdn/$url'), same(manager));
        expect(manager.resolveURL('a.png'), 'cdn/a.png');
        manager.setURLModifier(null);
        expect(manager.resolveURL('a.png'), 'a.png');
      });
    });
  });
}
