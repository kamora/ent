// Tests of Earcut and the vendored earcut library against triangulations computed by the reference source
// (reference/extras_reference.mjs). The reference has no Earcut test.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

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

          final deviation = Earcut.deviation(data, holes, dim, triangles);
          final expected = c['deviation'];

          if (expected is String) {
            expect(deviation.toString(), expected, reason: 'deviation');
          } else {
            close(deviation, expected as num, 'deviation');
          }
        });
      }

      test('flatten', () {
        final result = Earcut.flatten([
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
        ]);

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
