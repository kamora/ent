// Shared helpers for the texture tests.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// The properties compared with values printed from the reference source in Node.
Map<String, Object?> textureState(Texture t) {
  return {
    'version': t.version,
    'magFilter': t.magFilter,
    'minFilter': t.minFilter,
    'wrapS': t.wrapS,
    'wrapT': t.wrapT,
    'format': t.format,
    'type': t.type,
    'mapping': t.mapping,
    'generateMipmaps': t.generateMipmaps,
    'flipY': t.flipY,
    'unpackAlignment': t.unpackAlignment,
    'colorSpace': t.colorSpace,
    'isArrayTexture': t.isArrayTexture,
    'width': t.width,
    'height': t.height,
    'depth': t.depth,
  };
}

/// Expects [t] to have the [expected] subset of [textureState].
void expectTextureState(Texture t, Map<String, Object?> expected) {
  final state = textureState(t);
  expect({for (final key in expected.keys) key: state[key]}, expected);
}

/// The defaults the reference prints for a texture built with no special parameters: only differences are listed by the
/// tests.
const Map<String, Object?> baseState = {
  'version': 0,
  'magFilter': 1006,
  'minFilter': 1008,
  'wrapS': 1001,
  'wrapT': 1001,
  'format': 1023,
  'type': 1009,
  'mapping': 300,
  'generateMipmaps': true,
  'flipY': true,
  'unpackAlignment': 4,
  'colorSpace': '',
  'isArrayTexture': false,
  'width': 0,
  'height': 0,
  'depth': 0,
};

/// [baseState] with [changes] applied.
Map<String, Object?> stateWith(Map<String, Object?> changes) {
  return {...baseState, ...changes};
}
