import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// Loads the glTF assets of fixtures/gltf/ (tool/reference/js/gltf_files.mjs) with the Dart GLTFLoader and compares what
// it builds with fixtures/values/gltf_loader.json, the reference GLTFLoader loading the same files in Node (`node
// tool/reference/js/gltf_loader.mjs`): the scene trees, geometries (typed arrays, interleaving, index, groups, bounds),
// materials, cameras, lights, user data and the parser's associations, textures (samplers, color space, channel,
// transform, image size and source-byte hash) and the materials' texture slots and extension properties, morph
// attributes and influences, skins, and animation clips (tracks, interpolation, values sampled through each
// interpolant, cubic splines included). Integers, strings and booleans match exactly, floats within a relative 1e-9.

const _tolerance = 1e-9;

/// The times at which each animation track's interpolant is sampled, in order through one interpolant.
const _samples = [0, 0.1, 0.25, 0.5, 0.7, 0.95, 1, 1.3];

var _deviation = 0.0;

/// Data URIs and file: URLs, as Node's fetch (plus the runner's file reader) serves them.
class _Platform extends LoaderPlatform {
  @override
  Future<LoaderResponse> fetch(LoaderRequest request) async {
    final url = request.url;

    if (url.startsWith('data:')) {
      return LoaderResponse(status: 200, url: url, data: UriData.parse(url).contentAsBytes());
    }

    return LoaderResponse(status: 200, url: url, data: File.fromUri(Uri.parse(url)).readAsBytesSync());
  }

  @override
  LoaderImage createImage() => _Image();
}

/// The stand-in image of gltf_loader.mjs: it reads its src through the platform's fetch, takes its size from the
/// PNG header and a 32-bit FNV-1a hash of the encoded bytes as its identity (Node has no image decoder).
class _Image implements LoaderImage {
  int width = 0;

  int height = 0;

  int hash = 0;

  String _src = '';

  bool _done = false;

  final _listeners = <String, List<void Function(Object? event)>>{};

  @override
  bool get complete => _done;

  @override
  set crossOrigin(String? value) {}

  @override
  String fetchPriority = 'auto';

  @override
  String get src => _src;

  @override
  set src(String value) {
    _src = value;

    Loader.platform!.fetch(LoaderRequest(url: value)).then((response) async {
      final bytes = await response.bytes();
      final view = ByteData.sublistView(bytes);

      width = view.getUint32(16);
      height = view.getUint32(20);
      hash = 0x811C9DC5;

      for (final b in bytes) {
        hash = ((hash ^ b) * 0x01000193) & 0xFFFFFFFF;
      }

      _done = true;

      for (final listener in [...?_listeners['load']]) {
        listener(null);
      }
    });
  }

  @override
  void addEventListener(String type, void Function(Object? event) listener) {
    (_listeners[type] ??= []).add(listener);
  }

  @override
  void removeEventListener(String type, void Function(Object? event) listener) {
    _listeners[type]?.remove(listener);
  }
}

/// The texture slots and the extension properties of the materials glTF makes, as gltf_loader.mjs lists them.
const _maps = [
  'map',
  'metalnessMap',
  'roughnessMap',
  'normalMap',
  'aoMap',
  'emissiveMap',
  'clearcoatMap',
  'clearcoatRoughnessMap',
  'clearcoatNormalMap',
  'sheenColorMap',
  'sheenRoughnessMap',
  'transmissionMap',
  'thicknessMap',
  'specularIntensityMap',
  'specularColorMap',
  'iridescenceMap',
  'iridescenceThicknessMap',
  'anisotropyMap',
  'diffuseRoughnessMap',
  'bumpMap',
];

const _properties = [
  'aoMapIntensity',
  'clearcoat',
  'clearcoatRoughness',
  'clearcoatNormalScale',
  'sheen',
  'sheenColor',
  'sheenRoughness',
  'transmission',
  'thickness',
  'attenuationDistance',
  'attenuationColor',
  'ior',
  'specularIntensity',
  'specularColor',
  'iridescence',
  'iridescenceIOR',
  'iridescenceThicknessMinimum',
  'iridescenceThicknessMaximum',
  'anisotropy',
  'anisotropyRotation',
  'dispersion',
  'diffuseRoughness',
  'bumpScale',
  'size',
  'sizeAttenuation',
];

String _arrayType(List<num> array) => switch (array) {
  Float32List() => 'Float32Array',
  Uint32List() => 'Uint32Array',
  Uint16List() => 'Uint16Array',
  Uint8List() => 'Uint8Array',
  Int16List() => 'Int16Array',
  Int8List() => 'Int8Array',
  _ => array.runtimeType.toString(),
};

Map<String, Object?>? _attribute(BufferAttributeLike? a) {
  if (a == null) {
    return null;
  }

  return {
    'itemSize': a.itemSize,
    'count': a.count,
    'normalized': a.normalized,
    'interleaved': a is InterleavedBufferAttribute,
    'stride': a is InterleavedBufferAttribute ? a.data.stride : null,
    'offset': a is InterleavedBufferAttribute ? a.offset : null,
    'arrayType': _arrayType(a.array),
    'array': a.array,
  };
}

/// The track's values at [_samples], each copied out of one interpolant's result buffer.
List<List<double>> _sample(KeyframeTrack track) {
  final interpolant = track.createInterpolant();

  return [for (final t in _samples) List.of(interpolant.evaluate(t.toDouble()))];
}

Map<String, Object?> _dump(GLTF gltf) {
  final geometries = <BufferGeometry>[];
  final materials = <Material>[];
  final textures = <Texture>[];

  int? texture(Object? t) {
    if (t is! Texture) {
      return null;
    }

    if (!textures.contains(t)) {
      textures.add(t);
    }

    return textures.indexOf(t);
  }

  List<double>? box(Box3? b) => b == null ? null : [...b.min.toArray(), ...b.max.toArray()];

  Map<String, Object?> object(Object3D o) {
    final d = <String, Object?>{
      'name': o.name,
      'type': o.type,
      'matrix': o.matrix.toArray(),
      'userData': o.userData,
      'association': gltf.parser.associations[o],
      'pivot': o.pivot?.toArray(),
    };

    final (geometry, material) = switch (o) {
      Mesh(:final geometry, :final material) ||
      Line(:final geometry, :final material) ||
      Points(:final geometry, :final material) => (geometry, material),
      _ => (null, null),
    };

    if (geometry != null) {
      if (!geometries.contains(geometry)) {
        geometries.add(geometry);
      }

      if (!materials.contains(material)) {
        materials.add(material! as Material);
      }

      d['geometry'] = geometries.indexOf(geometry);
      d['material'] = materials.indexOf(material! as Material);
    }

    final (influences, dictionary) = switch (o) {
      Mesh(:final morphTargetInfluences, :final morphTargetDictionary) ||
      Line(:final morphTargetInfluences, :final morphTargetDictionary) ||
      Points(
        :final morphTargetInfluences,
        :final morphTargetDictionary,
      ) => (morphTargetInfluences, morphTargetDictionary),
      _ => (null, null),
    };

    if (influences != null) {
      d['morph'] = {'influences': influences, 'dictionary': dictionary};
    }

    if (o is SkinnedMesh) {
      d['skin'] = {
        'bindMode': o.bindMode,
        'bindMatrix': o.bindMatrix.toArray(),
        'bindMatrixInverse': o.bindMatrixInverse.toArray(),
        'bones': [
          for (final b in o.skeleton!.bones) [b.name, b.type, gltf.scenes.any((s) => s.getObjectById(b.id) == b)],
        ],
        'boneInverses': [for (final m in o.skeleton!.boneInverses) m.toArray()],
      };
    }

    if (o case PerspectiveCamera(:final fov, :final aspect, :final near, :final far)) {
      d['camera'] = [fov, aspect, near, far];
    } else if (o case OrthographicCamera(
      :final left,
      :final right,
      :final top,
      :final bottom,
      :final near,
      :final far,
    )) {
      d['camera'] = [left, right, top, bottom, near, far];
    }

    if (o is Light) {
      d['light'] = {
        'color': o.color.toArray(),
        'intensity': o.intensity,
        'distance': switch (o) {
          PointLight(:final distance) || SpotLight(:final distance) => distance,
          _ => null,
        },
        'angle': o is SpotLight ? o.angle : null,
        'penumbra': o is SpotLight ? o.penumbra : null,
        'decay': switch (o) {
          PointLight(:final decay) || SpotLight(:final decay) => decay,
          _ => null,
        },
      };
    }

    d['children'] = [for (final c in o.children) object(c)];

    return d;
  }

  final scenes = [for (final s in gltf.scenes) object(s)];

  return {
    'scene': gltf.scene == null ? -1 : gltf.scenes.indexOf(gltf.scene!),
    'scenes': scenes,
    'cameras': [
      for (final c in gltf.cameras) [c!.name, c.type],
    ],
    'asset': gltf.asset,
    'userData': gltf.userData,
    'animations': [
      for (final clip in gltf.animations)
        {
          'name': clip.name,
          'duration': clip.duration,
          'blendMode': clip.blendMode,
          'userData': clip.userData,
          'tracks': [
            for (final track in clip.tracks)
              {
                'name': track.name,
                'type': track.runtimeType.toString(),
                'times': _attribute(BufferAttribute(track.times as Float32List, 1)),
                'values': _attribute(BufferAttribute(track.values as Float32List, 1)),
                'interpolation': track.getInterpolation(),
                'cubicSpline': track.getInterpolation() == null,
                'samples': _sample(track),
              },
          ],
        },
    ],
    'geometries': [
      for (final g in geometries)
        {
          'attributes': {for (final k in g.attributes.keys.toList()..sort()) k: _attribute(g.attributes[k])},
          'index': _attribute(g.index),
          'groups': [
            for (final r in g.groups) [r.start, r.count, r.materialIndex ?? 0],
          ],
          'drawRange': [g.drawRange.start, g.drawRange.count],
          'boundingBox': box(g.boundingBox),
          'boundingSphere': g.boundingSphere == null
              ? null
              : [...g.boundingSphere!.center.toArray(), g.boundingSphere!.radius],
          'userData': g.userData,
          'morphAttributes': {
            for (final k in g.morphAttributes.keys.toList()..sort())
              k: [for (final a in g.morphAttributes[k]!) _attribute(a)],
          },
          'morphTargetsRelative': g.morphTargetsRelative,
        },
    ],
    'materials': [
      for (final m in materials)
        {
          'type': m.type,
          'name': m.name,
          'color': switch (m) {
            MeshStandardMaterial(:final color) ||
            MeshBasicMaterial(:final color) ||
            LineBasicMaterial(:final color) ||
            PointsMaterial(:final color) => color.toArray(),
            _ => null,
          },
          'emissive': m is MeshStandardMaterial ? m.emissive.toArray() : null,
          'emissiveIntensity': m is MeshStandardMaterial ? m.emissiveIntensity : null,
          'metalness': m is MeshStandardMaterial ? m.metalness : null,
          'roughness': m is MeshStandardMaterial ? m.roughness : null,
          'opacity': m.opacity,
          'transparent': m.transparent,
          'depthWrite': m.depthWrite,
          'depthTest': m.depthTest,
          'alphaTest': m.alphaTest,
          'side': m.side,
          'vertexColors': m.vertexColors,
          'flatShading': m is MeshStandardMaterial ? m.flatShading : null,
          'normalScale': m is MeshStandardMaterial ? m.normalScale.toArray() : null,
          'userData': m.userData,
          'association': gltf.parser.associations[m],
          'maps': {for (final k in _maps) k: texture(m[k])},
          'properties': {
            for (final k in _properties)
              k: switch (m[k]) {
                final Vector2 v => v.toArray(),
                final Color v => v.toArray(),
                final v => v,
              },
          },
        },
    ],
    'textures': [
      for (final t in textures)
        {
          'name': t.name,
          'type': t.type,
          'image': switch (t.image) {
            final _Image i => [i.width, i.height, i.hash],
            _ => null,
          },
          'wrapS': t.wrapS,
          'wrapT': t.wrapT,
          'magFilter': t.magFilter,
          'minFilter': t.minFilter,
          'generateMipmaps': t.generateMipmaps,
          'flipY': t.flipY,
          'colorSpace': t.colorSpace,
          'channel': t.channel,
          'offset': t.offset.toArray(),
          'repeat': t.repeat.toArray(),
          'rotation': t.rotation,
          'center': t.center.toArray(),
          'matrixAutoUpdate': t.matrixAutoUpdate,
          'matrix': t.matrix.toArray(),
          'userData': t.userData,
          'association': gltf.parser.associations[t],
        },
    ],
  };
}

/// Node associations in assets with several scenes: each loadScene() replaces `parser.associations` with those
/// of its own scene, so the result depends on which scene finishes last, and Dart futures finish in another
/// order than JS promises (exception E-GLTF).
var _skipNodeAssociations = false;

void _compare(Object? actual, Object? expected, String path) {
  if (_skipNodeAssociations && path.contains('.scenes[') && path.endsWith('.association')) {
    return;
  }

  switch (expected) {
    case null:
      // JSON.stringify writes Infinity (drawRange.count) as null.
      if (actual is double && actual.isInfinite) {
        return;
      }

      expect(actual, isNull, reason: path);

    case final num e:
      expect(actual, isA<num>(), reason: path);

      final a = actual! as num;

      if (e is int && a is int) {
        expect(a, e, reason: path);
        return;
      }

      final d = (a - e).abs() / math.max(1, math.max(a.abs(), e.abs()));
      _deviation = math.max(_deviation, d);

      if (!(d <= _tolerance)) {
        fail('$path: $a, expected $e');
      }

    case final List<Object?> e:
      expect(actual, isA<List<Object?>>(), reason: path);

      final a = actual! as List<Object?>;
      expect(a.length, e.length, reason: '$path.length');

      for (var i = 0; i < e.length; i++) {
        _compare(a[i], e[i], '$path[$i]');
      }

    case final Map<String, Object?> e:
      expect(actual, isA<Map<Object?, Object?>>(), reason: path);

      final a = (actual! as Map<Object?, Object?>).cast<String, Object?>();

      for (final key in {...e.keys, ...a.keys}) {
        _compare(a[key], e[key], '$path.$key');
      }

    default:
      expect(actual, expected, reason: path);
  }
}

void main() {
  final root = Directory.current.uri.resolve('../../');
  final dir = root.resolve('fixtures/gltf/');
  final values = jsonDecode(File.fromUri(root.resolve('fixtures/values/gltf_loader.json')).readAsStringSync());
  final files = ((values as Map<String, Object?>)['files']! as Map<String, Object?>);

  setUpAll(() => Loader.platform = _Platform());
  tearDownAll(() {
    Loader.platform = null;

    // ignore: avoid_print
    print('gltf_loader: max relative float deviation $_deviation');
  });

  for (final MapEntry(key: file, value: expected) in files.entries) {
    test('$file matches the reference', () async {
      final bytes = File.fromUri(dir.resolve(file)).readAsBytesSync();
      final gltf = await GLTFLoader().parseAsync(bytes.buffer, dir.toString());

      _skipNodeAssociations = ((expected! as Map<String, Object?>)['scenes']! as List<Object?>).length > 1;
      _compare(_dump(gltf), expected, file);
    });
  }

  test('load() fetches the file and its external buffer through FileLoader', () async {
    final gltf = await GLTFLoader().setPath(dir.toString()).loadAsync('external.gltf');
    final mesh = gltf.scene!.children.single as Mesh;

    expect(mesh.name, 'Tri');
    expect(mesh.geometry.getAttribute('position')!.array, [0, 0, 0, 1, 0, 0, 0, 1, 0]);
  });

  test('an asset below glTF 2.0 fails', () async {
    await expectLater(
      GLTFLoader().parseAsync('{"asset": {"version": "1.0"}}'),
      throwsA(isA<EntError>().having((e) => e.message, 'message', contains('glTF versions >=2.0'))),
    );
  });
}
