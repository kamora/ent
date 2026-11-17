// Fixture codecs for the color group; state layouts follow tool/reference/js/types/math.mjs
// (Color, SphericalHarmonics3) and types/color.mjs (HSL).

import 'package:ent/ent.dart';

import '../fixtures.dart';

double _d(Object? v) => v as double;

final Map<String, Codec> colorCodecs = {
  'Color': Codec((s) => Color(_d(s[0]), _d(s[1]), _d(s[2])), (o) => [(o as Color).r, o.g, o.b]),
  'SphericalHarmonics3': Codec(
    (s) => SphericalHarmonics3().fromArray(s.map(_d).toList()),
    (o) => (o as SphericalHarmonics3).toArray(),
  ),
  'HSL': Codec((s) => HSL(h: _d(s[0]), s: _d(s[1]), l: _d(s[2])), (o) => [(o as HSL).h, o.s, o.l]),
};
