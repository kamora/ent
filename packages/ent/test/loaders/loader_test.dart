import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Loaders', () {
    group('Loader', () {
      // INSTANCING
      test('request settings', () {
        final loader = Loader<Object?>();
        expect(loader.priority, 'auto');
        expect(loader.cache, 'default');
        expect(loader.setPriority('high'), same(loader));
        expect(loader.setCache('no-store'), same(loader));
        expect(loader.priority, 'high');
        expect(loader.cache, 'no-store');
      });

      test('Instancing', () {
        final object = Loader<Object?>();
        expect(object, isNotNull, reason: 'Can instantiate a Loader.');
      });

      // PROPERTIES
      test('manager', () {
        final object = Loader<Object?>().manager;
        expect(
          object,
          isA<LoadingManager>(),
          reason: 'Loader defines a default manager if not supplied in constructor.',
        );
        expect(object, same(DefaultLoadingManager));
      });

      test('crossOrigin', () {
        expect(Loader<Object?>().crossOrigin, 'anonymous', reason: 'Loader defines crossOrigin.');
      });

      test('withCredentials', () {
        expect(Loader<Object?>().withCredentials, false, reason: 'Loader defines withCredentials.');
      });

      test('path', () {
        expect(Loader<Object?>().path, '', reason: 'Loader defines path.');
      });

      test('resourcePath', () {
        expect(Loader<Object?>().resourcePath, '', reason: 'Loader defines resourcePath.');
      });

      test('requestHeader', () {
        expect(Loader<Object?>().requestHeader, <String, String>{}, reason: 'Loader defines requestHeader.');
      });

      // Dart: the base methods and setters (the reference has no tests for them)
      test('load parse abort', () {
        final loader = Loader<Object?>();
        expect(loader.load('x'), isNull);
        expect(loader.parse('data'), isNull);
        expect(loader.abort(), same(loader));
      });

      test('setCrossOrigin setWithCredentials setPath setResourcePath setRequestHeader', () {
        final loader = Loader<Object?>();
        expect(loader.setCrossOrigin('use-credentials'), same(loader));
        expect(loader.setWithCredentials(true), same(loader));
        expect(loader.setPath('assets/'), same(loader));
        expect(loader.setResourcePath('textures/'), same(loader));
        expect(loader.setRequestHeader({'Accept': 'json'}), same(loader));
        expect(
          [loader.crossOrigin, loader.withCredentials, loader.path, loader.resourcePath, loader.requestHeader],
          [
            'use-credentials',
            true,
            'assets/',
            'textures/',
            {'Accept': 'json'},
          ],
        );
      });

      test('DEFAULT_MATERIAL_NAME', () {
        expect(Loader.DEFAULT_MATERIAL_NAME, '__DEFAULT');
      });

      test('AbortController AbortSignal any', () {
        final a = AbortController();
        final b = AbortController();
        final any = AbortSignal.any([a.signal, b.signal]);
        var heard = 0;
        any.addListener(() => heard++);
        expect(any.aborted, isFalse);
        b.abort();
        expect(any.aborted, isTrue);
        expect(any.reason, isA<AbortError>());
        a.abort();
        expect(heard, 1);
        expect(AbortSignal.any([b.signal]).aborted, isTrue);
      });
    });
  });
}
