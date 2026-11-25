// Shader variants: a material kind with a set of flags, compiled at build time into the bundle under its key. Pure
// Dart, so the build hook shares it with the renderers.

import 'dart:convert';

// The flags of the shared chunks: maps.glsl, normals.glsl and offset.glsl. A kind accepts only the flags its shader
// reads: a variant declaring a sampler it never reads crashes flutter_tester (impellerc drops it, its reflection not).
const _diffuse = {'map': ('USE_MAP', 'map'), 'alpha_map': ('USE_ALPHAMAP', 'alpha_map')};
const _surface = {..._diffuse, 'ao_map': ('USE_AOMAP', 'ao_map'), 'light_map': ('USE_LIGHTMAP', 'light_map')};
const _specular = {'specular_map': ('USE_SPECULARMAP', 'specular_map')};
const _normals = {
  'normal_map': ('USE_NORMALMAP_TANGENTSPACE', 'normal_map'),
  'object_normal_map': ('USE_NORMALMAP_OBJECTSPACE', 'normal_map'),
  'bump_map': ('USE_BUMPMAP', 'bump_map'),
};
const _offset = {'polygon_offset': ('POLYGON_OFFSET', null)};

// The physical maps (PHYSICAL_MAP:i, bit i of PHYSICAL_MAPS: the indices of UvInfo in shaders/physical.glsl) and
// layers (LAYER_*); a layer or a specular map turns on the physical stage (PHYSICAL). Transmission (TRANSMISSION)
// also reads the scene behind the object (transmission_sampler_map); dispersion and its maps exist only with it.
const _physical = {
  'roughness_map': ('PHYSICAL_MAP:0', 'roughness_map'),
  'metalness_map': ('PHYSICAL_MAP:1', 'metalness_map'),
  'clearcoat': ('PHYSICAL LAYER_CLEARCOAT', null),
  'clearcoat_map': ('PHYSICAL_MAP:2', 'clearcoat_map'),
  'clearcoat_roughness_map': ('PHYSICAL_MAP:3', 'clearcoat_roughness_map'),
  'clearcoat_normal_map': ('PHYSICAL_MAP:4', 'clearcoat_normal_map'),
  'sheen': ('PHYSICAL LAYER_SHEEN', null),
  'sheen_color_map': ('PHYSICAL_MAP:5', 'sheen_color_map'),
  'sheen_roughness_map': ('PHYSICAL_MAP:6', 'sheen_roughness_map'),
  'iridescence': ('PHYSICAL LAYER_IRIDESCENCE', null),
  'iridescence_map': ('PHYSICAL_MAP:7', 'iridescence_map'),
  'iridescence_thickness_map': ('PHYSICAL_MAP:8', 'iridescence_thickness_map'),
  'anisotropy': ('PHYSICAL LAYER_ANISOTROPY', null),
  'anisotropy_map': ('PHYSICAL_MAP:9', 'anisotropy_map'),
  'specular_intensity_map': ('PHYSICAL PHYSICAL_MAP:10', 'specular_intensity_map'),
  'specular_color_map': ('PHYSICAL PHYSICAL_MAP:11', 'specular_color_map'),
  'diffuse_roughness': ('PHYSICAL LAYER_DIFFUSE_ROUGHNESS', null),
  'diffuse_roughness_map': ('PHYSICAL_MAP:12', 'diffuse_roughness_map'),
  'transmission': ('PHYSICAL TRANSMISSION', 'transmission_sampler_map'),
  'dispersion': ('DISPERSION', null),
  'transmission_map': ('PHYSICAL_MAP:13', 'transmission_map'),
  'thickness_map': ('PHYSICAL_MAP:14', 'thickness_map'),
};
const _lit = {..._surface, 'emissive_map': ('USE_EMISSIVEMAP', 'emissive_map'), ..._normals, ..._offset};

/// The GLSL a kind's fragment variants include and the flags they accept, each with the define it sets and the
/// sampler it adds (null for none).
const kinds = {
  'basic': (source: 'shaders/basic.glsl', flags: {..._surface, ..._specular, ..._offset}),
  'dashed': (source: 'shaders/dashed.glsl', flags: {..._surface, ..._specular, ..._offset}),
  'depth': (
    source: 'shaders/depth.glsl',
    flags: {
      ..._diffuse,
      'rgba_packing': ('DEPTH_PACKING_RGBA', null),
      'rgb_packing': ('DEPTH_PACKING_RGB', null),
      'rg_packing': ('DEPTH_PACKING_RG', null),
      ..._offset,
    },
  ),
  'distance': (source: 'shaders/distance.glsl', flags: {..._diffuse, ..._offset}),
  'points': (source: 'shaders/points.glsl', flags: {..._diffuse, ..._offset}),
  'sprite': (source: 'shaders/sprite.glsl', flags: {..._diffuse, ..._offset}),
  'normal': (source: 'shaders/normal.glsl', flags: {..._normals, ..._offset}),
  'lambert': (source: 'shaders/lambert.glsl', flags: {..._lit, ..._specular}),
  'phong': (source: 'shaders/phong.glsl', flags: {..._lit, ..._specular}),
  'toon': (source: 'shaders/toon.glsl', flags: {..._lit, 'gradient_map': ('USE_GRADIENTMAP', 'gradient_map')}),
  'physical': (source: 'shaders/physical.glsl', flags: {..._lit, ..._physical}),
  'matcap': (
    source: 'shaders/matcap.glsl',
    flags: {..._diffuse, ..._normals, 'matcap': ('USE_MATCAP', 'matcap'), ..._offset},
  ),
  'hologram': (source: 'shaders/hologram.glsl', flags: _offset),
};

/// The key of the [kind] variant with [flags]: the kind, then the flags sorted, separated by spaces.
String keyOf(String kind, Iterable<String> flags) => [kind, ...flags.toList()..sort()].join(' ');

/// The kind and flags of [key]; a [FormatException] for an unknown kind or flag.
({String kind, List<String> flags}) parseKey(String key) {
  final [kind, ...flags] = key.trim().split(RegExp(r'\s+'));
  final accepted = kinds[kind]?.flags;

  if (accepted == null) {
    throw FormatException('ent_shaders: unknown shader kind "$kind" in "$key"; known: ${kinds.keys.join(', ')}.');
  }

  for (final flag in flags) {
    if (!accepted.containsKey(flag)) {
      throw FormatException('ent_shaders: "$kind" has no flag "$flag" in "$key"; known: ${accepted.keys.join(', ')}.');
    }
  }

  // A normal map takes precedence over a bump map, so with both the bump map's code and sampler would be dead.
  if (flags.contains('bump_map') && flags.any(const {'normal_map', 'object_normal_map'}.contains)) {
    throw FormatException('ent_shaders: "$key" has a normal map, which takes precedence over bump_map; leave it out.');
  }

  // Without transmission its code is left out, and these would declare samplers nothing reads.
  if (!flags.contains('transmission') &&
      flags.any(const {'dispersion', 'transmission_map', 'thickness_map'}.contains)) {
    throw FormatException('ent_shaders: "$key" has dispersion or a transmission map without transmission.');
  }

  return (kind: kind, flags: flags);
}

/// The platforms a registry's `renderers` map can name, as the hooks API names them.
const platforms = ['android', 'ios', 'macos', 'windows', 'linux'];

/// The renderer package a registry file assigns to each platform (`"renderers": {"android": "ent_opengl", ...}`), or
/// null when it has no map, in which case every renderer builds for every platform it supports. A [FormatException]
/// for a malformed map or an unknown platform.
Map<String, String>? readRenderers(String text) {
  final renderers = switch (json.decode(text)) {
    {'renderers': final Object? map} => map,
    _ => null,
  };

  if (renderers == null) {
    return null;
  }

  if (renderers is! Map<String, Object?>) {
    throw const FormatException('ent_shaders: "renderers" maps a platform to a package, as {"ios": "ent_flutter"}.');
  }

  final assigned = <String, String>{};

  for (final MapEntry(key: platform, value: package) in renderers.entries) {
    if (!platforms.contains(platform)) {
      throw FormatException(
        'ent_shaders: unknown platform "$platform" in "renderers"; known: ${platforms.join(', ')}.',
      );
    }

    if (package is! String) {
      throw FormatException('ent_shaders: the renderer of "$platform" is a package name, not $package.');
    }

    assigned[platform] = package;
  }

  return assigned;
}

/// The variant keys a registry file lists, normalized; a [FormatException] for a malformed file or key.
List<String> readRegistry(String text) {
  final variants = switch (json.decode(text)) {
    {'variants': List<Object?> list} => list,
    _ => throw const FormatException('ent_shaders: a shader registry is {"variants": ["basic map", ...]}.'),
  };

  final keys = <String>{};

  for (final key in variants) {
    if (key is! String) {
      throw FormatException('ent_shaders: a shader variant is a string, not $key.');
    }

    final (:kind, :flags) = parseKey(key);
    keys.add(keyOf(kind, flags));
  }

  return keys.toList();
}

/// The fragment source of the variant [key]: VARIANT and its flags' defines, then its kind's GLSL. A flag's
/// `PHYSICAL_MAP:i` sets bit i of PHYSICAL_MAPS, which a physical variant always defines.
String sourceOf(String key) {
  final (:kind, :flags) = parseKey(key);
  final spec = kinds[kind]!;
  final defines = <String>{};
  var maps = 0;

  for (final flag in flags) {
    for (final define in spec.flags[flag]!.$1.split(' ')) {
      if (define.startsWith('PHYSICAL_MAP:')) {
        maps |= 1 << int.parse(define.substring(13));
      } else {
        defines.add(define);
      }
    }
  }

  return [
    '#version 460 core',
    '',
    '#define VARIANT',
    for (final define in defines) '#define $define',
    if (kind == 'physical') '#define PHYSICAL_MAPS $maps',
    '#include "${spec.source}"',
    '',
  ].join('\n');
}

/// The file name of the variant [key]'s generated source. impellerc names a shader's entry point after its file
/// (letters, digits and underscores kept), and the engine registers shaders by entry point: a variant named like a
/// fixed shader (`physical.frag`) would replace it. So `variant__`, then the key with `__` between its words; a stem
/// past 100 characters (a file name holds 255 bytes) becomes the kind and an FNV-1a hash of the key instead.
String fileOf(String key) {
  final stem = 'variant__${key.replaceAll(' ', '__')}';

  if (stem.length <= 100) {
    return '$stem.frag';
  }

  var hash = 0xcbf29ce484222325;

  for (final unit in key.codeUnits) {
    hash = (hash ^ unit) * 0x100000001b3;
  }

  // The 64 bits as two unsigned halves: a Dart int is signed.
  String half(int bits) => bits.toRadixString(16).padLeft(8, '0');
  return 'variant__${parseKey(key).kind}__x${half(hash >>> 32)}${half(hash & 0xffffffff)}.frag';
}

/// The samplers the variant [key] reads, from its flags.
Set<String> samplersOf(String key) {
  final (:kind, :flags) = parseKey(key);
  return {for (final flag in flags) ?kinds[kind]!.flags[flag]!.$2};
}
