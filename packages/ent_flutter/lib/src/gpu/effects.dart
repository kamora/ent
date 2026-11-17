// Effects: the precompiled program of each effect material of ent (exception E-POSTPROCESSING), found by the
// material's class, and how its fields fill the program's blocks.

import 'package:ent/ent.dart';

import 'programs.dart';

/// The vertex layout of the effect programs (`EffectVertex`).
const List<VertexSlot> effectSlots = [VertexSlot('position', 3), VertexSlot('uv', 2)];

/// A registered effect: its fragment stage in the bundle (over `EffectVertex`), how a material's fields fill its
/// blocks (FragInfo and OutputInfo, both begun), its samplers and the texture each reads (FragInfo's `flip` follows
/// the first).
class Effect<M extends EffectMaterial> {
  const Effect(this.fragment, this._write, [this.samplers = const ['t_diffuse'], this._textures = _map]);

  final String fragment;

  final void Function(ProgramVariant variant, M material) _write;

  final List<String> samplers;

  final List<Texture?> Function(M material) _textures;

  static List<Texture?> _map(EffectMaterial material) => [material.map];

  void write(ProgramVariant variant, EffectMaterial material) => _write(variant, material as M);

  List<Texture?> textures(EffectMaterial material) => _textures(material as M);
}

/// The registered effects, by their material's class.
final Map<Type, Effect> effects = {
  CopyMaterial: Effect<CopyMaterial>('CopyFragment', (variant, m) => variant.fragInfo.float('opacity', m.opacity)),
  OutputMaterial: Effect<OutputMaterial>('OutputPassFragment', (variant, m) {
    variant.outputInfo
      ..float('tone_mapping', m.toneMapping.toDouble())
      ..float('tone_mapping_exposure', m.toneMappingExposure)
      ..flag('output_srgb', ColorManagement.getTransfer(m.outputColorSpace) == SRGBTransfer);
  }),
  VignetteMaterial: Effect<VignetteMaterial>('VignetteFragment', (variant, m) {
    variant.fragInfo
      ..float('offset', m.offset)
      ..float('darkness', m.darkness);
  }),
  FXAAMaterial: Effect<FXAAMaterial>(
    'FXAAFragment',
    (variant, m) => variant.fragInfo.floats('resolution', [m.resolution.x, m.resolution.y]),
  ),
  HighPassMaterial: Effect<HighPassMaterial>('LuminosityHighPassFragment', (variant, m) {
    variant.fragInfo
      ..floats('default_color', [m.defaultColor.r, m.defaultColor.g, m.defaultColor.b])
      ..float('default_opacity', m.defaultOpacity)
      ..float('luminosity_threshold', m.threshold)
      ..float('smooth_width', m.smoothWidth);
  }),

  // One program for every kernel radius: the loop is bounded by the number of tap pairs, a uniform.
  BlurMaterial: Effect<BlurMaterial>(
    'BloomBlurFragment',
    (variant, m) {
      variant.fragInfo
        ..floats('inv_size', [m.invSize.x, m.invSize.y])
        ..floats('direction', [m.direction.x, m.direction.y])
        ..float('center_weight', m.centerWeight)
        ..float('kernel_pairs', m.offsets.length.toDouble())
        ..floats('gaussian_offsets', m.offsets)
        ..floats('gaussian_weights', m.weights);
    },
    const ['color_texture'],
    (m) => [m.map],
  ),
  BloomMaterial: Effect<BloomMaterial>(
    'BloomCompositeFragment',
    (variant, m) {
      variant.fragInfo
        ..float('bloom_strength', m.strength)
        ..float('bloom_radius', m.radius)
        ..floats('bloom_factors', m.factors);

      for (final (i, tint) in m.tints.indexed) {
        variant.fragInfo.floats('bloom_tint_colors', [tint.x, tint.y, tint.z], i * 4);
      }
    },
    const ['blur_texture1', 'blur_texture2', 'blur_texture3', 'blur_texture4', 'blur_texture5'],
    (m) => m.maps,
  ),
};
