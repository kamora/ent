// Tests of Earcut and the vendored earcut library against triangulations computed by the reference source
// (reference/extras_reference.mjs). The reference has no Earcut test.

import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

final LibraryMirror _library = reflectClass(Earcut).owner as LibraryMirror;

/// Calls a library-private function of the vendored earcut file.
Object? _private(String name, List<Object?> args) {
  return _library.invoke(MirrorSystem.getSymbol(name, _library), args).reflectee;
}

void main() {
  group('Extras', () {
    group('Earcut', () {
      final cases = (reference['earcut'] as Map<String, Object?>).cast<String, Map<String, Object?>>();

      for (final MapEntry(key: name, value: c) in cases.entries) {
        test('triangulate: $name', () {
          final data = (c['data'] as List).cast<num>();
          final holes = (c['holes'] as List?)?.cast<int>();
          final dim = c['dim'] as int;

          final triangles = Earcut.triangulate(data, holes, dim);
          expect(triangles, c['triangles'], reason: 'same triangles, same order');

          final deviation = _private('_earcutDeviation', [data, holes, dim, triangles]) as double;
          final expected = c['deviation'];

          if (expected is String) {
            expect(deviation.toString(), expected, reason: 'deviation');
          } else {
            close(deviation, expected as num, 'deviation');
          }
        });
      }

      test('flatten', () {
        final result = _private('_earcutFlatten', [
          [
            [
              [0, 0],
              [10, 0],
              [10, 10],
            ],
            [
              [1, 1],
              [2, 1],
              [1, 2],
            ],
          ],
        ]) as ({List<num> vertices, List<int> holes, int dimensions});

        final expected = reference['flatten'] as Map<String, Object?>;
        expect(result.vertices, expected['vertices']);
        expect(result.holes, expected['holes']);
        expect(result.dimensions, expected['dimensions']);
      });

      test('triangulate with dim defaulting to 2 and no holes', () {
        expect(Earcut.triangulate([0, 0, 1, 0, 1, 1, 0, 1]), (cases['square']!)['triangles']);
      });
    });
  });
}
