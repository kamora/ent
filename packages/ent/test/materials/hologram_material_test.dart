// HologramMaterial, ent's own material: its defaults, parameters and copies.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials', () {
    group('HologramMaterial', () {
      test('type', () {
        final object = HologramMaterial();
        expect(object, isA<Material>());
        expect(object.type, 'HologramMaterial');
        expect(object.isHologramMaterial, isTrue);
      });

      test('blends additively, double-sided and transparent, without writing depth', () {
        final object = HologramMaterial();
        expect(object.blending, AdditiveBlending);
        expect(object.side, DoubleSide);
        expect(object.transparent, isTrue);
        expect(object.depthWrite, isFalse);
      });

      test('parameters override the defaults', () {
        final object = HologramMaterial({'blending': NormalBlending, 'rim': 2, 'flicker': 0.25});
        expect(object.blending, NormalBlending);
        expect(object.rim, 2.0);
        expect(object.flicker, 0.25);
      });

      test('copy and clone carry every property', () {
        final source = HologramMaterial({
          'color': Color(0xff0080),
          'opacity': 0.5,
          'fill': 0.3,
          'rim': 2,
          'rimPower': 4,
          'scanlines': 0.75,
          'scanlineDensity': 10,
          'scanlineSpeed': 2,
          'flicker': 0.25,
          'time': 3.5,
          'fog': false,
        });

        for (final copy in [source.clone(), HologramMaterial().copy(source)]) {
          expect(copy.color.getHex(), 0xff0080);
          expect(copy.color, isNot(same(source.color)));
          expect(copy.opacity, 0.5);
          expect(copy.fill, 0.3);
          expect(copy.rim, 2.0);
          expect(copy.rimPower, 4.0);
          expect(copy.scanlines, 0.75);
          expect(copy.scanlineDensity, 10.0);
          expect(copy.scanlineSpeed, 2.0);
          expect(copy.flicker, 0.25);
          expect(copy.time, 3.5);
          expect(copy.fog, isFalse);
        }
      });
    });
  });
}
