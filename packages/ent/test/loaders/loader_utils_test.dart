import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Loaders', () {
    group('LoaderUtils', () {
      // STATIC
      test('extractUrlBase', () {
        expect(LoaderUtils.extractUrlBase('/path/to/model.glb'), '/path/to/');
        expect(LoaderUtils.extractUrlBase('model.glb'), './');
        expect(LoaderUtils.extractUrlBase('/model.glb'), '/');
      });

      // Dart: values printed from the reference in Node
      test('resolveURL', () {
        const cases = [
          ['model.bin', 'http://a.com/x/', 'http://a.com/x/model.bin'],
          ['/model.bin', 'https://a.com/x/y/', 'https://a.com/model.bin'],
          ['//cdn.com/m.bin', 'p/', '//cdn.com/m.bin'],
          ['https://b.com/m.bin', 'p/', 'https://b.com/m.bin'],
          ['data:image/png;base64,AAA', 'p/', 'data:image/png;base64,AAA'],
          ['blob:http://a/123', 'p/', 'blob:http://a/123'],
          ['', '', ''],
          ['textures/t.png', './', './textures/t.png'],
          ['/abs.png', 'rel/', 'rel//abs.png'],
          ['HTTP://UP.COM/a', 'p/', 'HTTP://UP.COM/a'],
          ['/x', 'HTTPS://Host.Com/a/b', 'HTTPS://Host.Com/x'],
        ];

        for (final [url, path, expected] in cases) {
          expect(LoaderUtils.resolveURL(url, path), expected, reason: '$url + $path');
        }

        expect(LoaderUtils.resolveURL(null, 'p/'), '');
        expect(LoaderUtils.resolveURL(5, 'p/'), '');
      });
    });
  });
}
