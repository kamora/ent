import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Loaders', () {
    group('Cache', () {
      tearDown(() {
        Cache.enabled = false;
        Cache.clear();
      });

      // PROPERTIES
      test('enabled', () {
        expect(Cache.enabled, false, reason: 'Cache defines enabled.');
      });

      test('files', () {
        expect(Cache.files, <String, Object?>{}, reason: 'Cache defines files.');
      });

      // Dart: values printed from the reference in Node (blob URLs are never cached)
      test('add get remove clear', () {
        Cache.add('file:a', 1);
        expect(Cache.get('file:a'), isNull, reason: 'disabled');

        Cache.enabled = true;

        for (final MapEntry(:key, :value) in {
          'file:blob:http://a/1': null,
          'file:http://a/1': 1,
          'image:blob:null/abc': null,
          'file:rel/blob:x': 1,
          'nocolon': 1,
        }.entries) {
          Cache.add(key, 1);
          expect(Cache.get(key), value, reason: key);
        }

        Cache.remove('file:http://a/1');
        expect(Cache.get('file:http://a/1'), isNull);
        Cache.clear();
        expect(Cache.files, isEmpty);
      });
    });
  });
}
