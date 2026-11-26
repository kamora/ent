// Tests of TextureUtils against values computed by the reference source (reference/extras_reference.mjs). The reference
// has no TextureUtils test.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/library.g.dart';
import 'support.dart';

int _constant(String name) => constants[name]! as int;

void main() {
  group('Extras', () {
    group('TextureUtils', () {
      test('getByteLength', () {
        for (final row in (reference['byteLength'] as List).cast<List<Object?>>()) {
          final format = row[0] as String, type = row[1] as String, expected = row[2];

          if (expected is String) {
            expect(
              () => TextureUtils.getByteLength(37, 21, _constant(format), _constant(type)),
              throwsA(isA<EntError>().having((e) => 'throws:${e.message}', 'message', expected)),
              reason: '$format $type',
            );
          } else {
            expect(
              TextureUtils.getByteLength(37, 21, _constant(format), _constant(type)),
              expected,
              reason: '$format $type',
            );
          }
        }
      });

      test('getByteLength with an unknown type', () {
        expect(
          () => TextureUtils.getByteLength(4, 4, RGBAFormat, 9999),
          throwsA(isA<EntError>().having((e) => e.message, 'message', reference['badType'])),
        );
      });

      test('contain cover fill', () {
        for (final row in (reference['fit'] as List).cast<Map<String, Object?>>()) {
          final w = row['w'] as int, h = row['h'] as int, a = (row['a'] as num).toDouble();

          final contained = TextureUtils.contain(Texture(DataImage(width: w, height: h)), a);
          final covered = TextureUtils.cover(Texture(DataImage(width: w, height: h)), a);

          final c = (row['contain'] as List).cast<num>(), v = (row['cover'] as List).cast<num>();
          expect(
            [contained.repeat.x, contained.repeat.y, contained.offset.x, contained.offset.y],
            c,
            reason: 'contain $w x $h @ $a',
          );
          expect(
            [covered.repeat.x, covered.repeat.y, covered.offset.x, covered.offset.y],
            v,
            reason: 'cover $w x $h @ $a',
          );
        }

        final texture = Texture()
          ..repeat.set(3, 4)
          ..offset.set(1, 2);
        expect(identical(TextureUtils.fill(texture), texture), isTrue);
        expect([texture.repeat.x, texture.repeat.y, texture.offset.x, texture.offset.y], [1.0, 1.0, 0.0, 0.0]);
      });

      test('contain with no image size uses an aspect of 1', () {
        final texture = TextureUtils.contain(Texture(), 2);
        expect([texture.repeat.x, texture.repeat.y, texture.offset.x, texture.offset.y], [2.0, 1.0, -0.5, 0.0]);
      });
    });
  });
}
