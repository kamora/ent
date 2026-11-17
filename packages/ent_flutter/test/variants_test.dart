import 'dart:convert';
import 'dart:io';

import 'package:ent_flutter/src/gpu/variants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a key sorts its flags, so one variant has one name', () {
    expect(keyOf('basic', ['map', 'alpha_map']), 'basic alpha_map map');
    expect(readRegistry('{"variants": ["basic map alpha_map", "basic  alpha_map map", "basic"]}'), [
      'basic alpha_map map',
      'basic',
    ]);
  });

  test('an unknown kind or flag names itself and what is known', () {
    expect(
      () => parseKey('lava map'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('unknown shader kind "lava"'))),
    );
    expect(
      () => parseKey('basic map glow'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"basic" has no flag "glow"'))),
    );
    expect(() => readRegistry('["basic"]'), throwsFormatException);
    expect(
      () => parseKey('normal bump_map normal_map'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('leave it out'))),
    );
    expect(parseKey('physical bump_map clearcoat clearcoat_normal_map').flags, contains('bump_map'));
    expect(
      () => parseKey('physical dispersion'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('without transmission'))),
    );
    expect(() => parseKey('physical thickness_map'), throwsFormatException);
  });

  test('a variant source defines its flags before its kind', () {
    expect(
      sourceOf('basic map polygon_offset'),
      '#version 460 core\n\n#define VARIANT\n#define USE_MAP\n#define POLYGON_OFFSET\n#include "shaders/basic.glsl"\n',
    );
    expect(fileOf('basic map polygon_offset'), 'variant__basic__map__polygon_offset.frag');
    expect(
      fileOf(
        keyOf(
          'physical',
          kinds['physical']!.flags.keys.where((flag) => !flag.contains('bump') && !flag.contains('object')),
        ),
      ),
      matches(RegExp(r'^variant__physical__x[0-9a-f]+\.frag$')),
    );
  });

  test('a variant reads the samplers of its flags only', () {
    expect(samplersOf('basic map polygon_offset'), {'map'});
    expect(samplersOf('normal object_normal_map'), {'normal_map'});
    expect(samplersOf('normal'), isEmpty);
    expect(samplersOf('physical dispersion thickness_map transmission'), {'thickness_map', 'transmission_sampler_map'});
  });

  test('depth packing is a flag of the depth kind; dashed lines are a kind of their own', () {
    expect(
      sourceOf('depth map rgba_packing'),
      '#version 460 core\n\n#define VARIANT\n#define USE_MAP\n#define DEPTH_PACKING_RGBA\n#include "shaders/depth.glsl"\n',
    );
    expect(sourceOf('dashed map'), endsWith('#include "shaders/dashed.glsl"\n'));
    expect(samplersOf('distance alpha_map polygon_offset'), {'alpha_map'});
  });

  test('transmission and its maps are flags of the physical kind', () {
    expect(
      sourceOf('physical dispersion thickness_map transmission transmission_map'),
      '#version 460 core\n\n#define VARIANT\n#define DISPERSION\n#define PHYSICAL\n#define TRANSMISSION\n'
      '#define PHYSICAL_MAPS 24576\n#include "shaders/physical.glsl"\n',
    );
  });

  test('every variant has its own entry point, unlike any fixed shader (the engine registers shaders by it)', () {
    // impellerc's entry point: the file's stem with only letters, digits and underscores.
    String entry(String file) => file.split('/').last.split('.').first.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');

    final fixed = (json.decode(File('ent.shaderbundle.json').readAsStringSync()) as Map<String, Object?>).values;
    final names = {for (final shader in fixed) entry((shader as Map)['file'] as String)};

    for (final key in readRegistry(File('test/ent_shaders.json').readAsStringSync())) {
      expect(names.add(entry(fileOf(key))), isTrue, reason: '"$key" shares its entry point');
    }
  });
}
