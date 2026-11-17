// Fixture codecs for every value type, merged from one file per port group.

import 'fixtures.dart';

import 'codecs/materials.dart';
import 'codecs/meshes.dart';
import 'codecs/skinning.dart';
import 'codecs/lights.dart';
import 'codecs/curves.dart';
import 'codecs/geometries.dart';
import 'codecs/textures.dart';
import 'codecs/animation.dart';
import 'codecs/buffers.dart';
import 'codecs/cameras.dart';
import 'codecs/color.dart';
import 'codecs/core.dart';
import 'codecs/geometry.dart';
import 'codecs/interpolants.dart';
import 'codecs/objects.dart';

final Map<String, Codec> codecs = {
  ...coreCodecs,
  ...geometryCodecs,
  ...colorCodecs,
  ...interpolantsCodecs,
  ...buffersCodecs,
  ...objectsCodecs,
  ...camerasCodecs,
  ...materialsCodecs,
  ...meshesCodecs,
  ...skinningCodecs,
  ...lightsCodecs,
  ...curvesCodecs,
  ...geometriesCodecs,
  ...texturesCodecs,
  ...animationCodecs,
};
