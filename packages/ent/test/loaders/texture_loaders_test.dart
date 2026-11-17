import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

/// A data texture format: width, height, then RGBA bytes.
class _RawLoader extends DataTextureLoader {
  @override
  Map<String, Object?>? parse(covariant ByteBuffer buffer) {
    final bytes = buffer.asUint8List();

    if (bytes.length < 2) {
      throw StateError('truncated');
    }

    return {
      'width': bytes[0],
      'height': bytes[1],
      'data': Uint8List.sublistView(bytes, 2),
      'wrapS': RepeatWrapping,
      'flipY': true,
      'mipmapCount': 1,
      'generateMipmaps': false,
    };
  }
}

/// A compressed format: width, height, mipmap count, cube flag, then one byte per mipmap.
class _RawCompressedLoader extends CompressedTextureLoader {
  @override
  Map<String, Object?>? parse(covariant ByteBuffer buffer, [bool loadMipmaps = false]) {
    final bytes = buffer.asUint8List();
    final count = bytes[2];

    return {
      'width': bytes[0],
      'height': bytes[1],
      'format': RGBA_S3TC_DXT5_Format,
      'mipmapCount': count,
      'isCubemap': bytes[3] == 1,
      'mipmaps': [
        for (var i = 4; i < bytes.length; i++) {'data': bytes[i]},
      ],
    };
  }
}

void main() {
  late FakeLoaderPlatform platform;

  setUp(() => Loader.platform = platform = FakeLoaderPlatform());

  tearDown(() => Loader.platform = null);

  group('Loaders', () {
    group('TextureLoader', () {
      // INHERITANCE
      test('Extending', () {
        expect(TextureLoader(), isA<Loader<Texture>>(), reason: 'TextureLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        expect(TextureLoader(), isNotNull, reason: 'Can instantiate a TextureLoader.');
      });

      // Dart: behaviour through a fake platform
      test('load', () {
        final loaded = <Texture>[];
        final texture = (TextureLoader()..setPath('t/')).load('a.png', loaded.add);
        expect(texture.image, isNull);
        expect(texture.version, 0);

        final image = platform.images.single..finish();
        expect(image.src, 't/a.png');
        expect(texture.image, same(image));
        expect(texture.version, 1);
        expect(loaded.single, same(texture));
      });
    });

    group('CubeTextureLoader', () {
      // INHERITANCE
      test('Extending', () {
        expect(CubeTextureLoader(), isA<Loader<CubeTexture>>(), reason: 'CubeTextureLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        expect(CubeTextureLoader(), isNotNull, reason: 'Can instantiate a CubeTextureLoader.');
      });

      // Dart: behaviour through a fake platform
      test('load', () {
        final loaded = <CubeTexture>[];
        final texture = CubeTextureLoader().load(['px', 'nx', 'py', 'ny', 'pz', 'nz'], loaded.add);
        expect(texture.colorSpace, SRGBColorSpace);

        // faces arriving out of order land at their index
        for (final i in [5, 0, 3, 1, 4]) {
          platform.images[i].finish();
        }

        expect(loaded, isEmpty);
        expect((texture.images! as List)[5], same(platform.images[5]));

        platform.images[2].finish();
        expect(loaded.single, same(texture));
        expect(texture.version, 1);
        expect((texture.images! as List).map((i) => (i as FakeImage).src), ['px', 'nx', 'py', 'ny', 'pz', 'nz']);
      });
    });

    group('DataTextureLoader', () {
      // INHERITANCE
      test('Extending', () {
        expect(DataTextureLoader(), isA<Loader<DataTexture>>(), reason: 'DataTextureLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        expect(DataTextureLoader(), isNotNull, reason: 'Can instantiate a DataTextureLoader.');
      });

      // Dart: behaviour of _applyTexData through a subclass (as in the reference)
      test('load createDataTexture', () async {
        platform.resources['t.raw'] = FakeResource(Uint8List.fromList([2, 1, 9, 9, 9, 9, 8, 8, 8, 8]));
        platform.resources['bad.raw'] = FakeResource(Uint8List(1));

        final texture = await _RawLoader().loadAsync('t.raw');
        final image = texture.image! as DataImage;

        expect([image.width, image.height, (image.data! as Uint8List).length], [2, 1, 8]);
        expect([texture.wrapS, texture.wrapT], [RepeatWrapping, ClampToEdgeWrapping]);
        expect([texture.magFilter, texture.minFilter], [LinearFilter, LinearFilter]);
        expect([texture.anisotropy, texture.flipY, texture.generateMipmaps, texture.version], [1.0, true, false, 1]);

        final errors = <Object>[];
        _RawLoader().load('bad.raw', (t, [d]) => fail('parse failed'), null, errors.add);
        await settle();
        expect(errors.single, isA<StateError>());

        final direct = _RawLoader().createDataTexture(Uint8List.fromList([1, 1, 5, 5, 5, 5]).buffer);
        expect((direct.image! as DataImage).width, 1);
      });
    });

    group('CompressedTextureLoader', () {
      // INHERITANCE
      test('Extending', () {
        expect(
          CompressedTextureLoader(),
          isA<Loader<CompressedTexture>>(),
          reason: 'CompressedTextureLoader extends from Loader',
        );
      });

      // INSTANCING
      test('Instancing', () {
        expect(CompressedTextureLoader(), isNotNull, reason: 'Can instantiate a CompressedTextureLoader.');
      });

      // Dart: behaviour through a subclass (as in the reference)
      test('load single, cube file, six files', () async {
        platform.resources['flat.dds'] = FakeResource(Uint8List.fromList([4, 4, 1, 0, 7]));
        platform.resources['cube.dds'] = FakeResource(
          Uint8List.fromList([2, 2, 2, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
        );

        for (var i = 0; i < 6; i++) {
          platform.resources['f$i.dds'] = FakeResource(Uint8List.fromList([8, 8, 1, 0, i]));
        }

        final flat = await _RawCompressedLoader().loadAsync('flat.dds');
        expect(
          [(flat.image! as DataImage).width, flat.mipmaps.length, flat.minFilter, flat.format],
          [4, 1, LinearFilter, RGBA_S3TC_DXT5_Format],
        );

        final cube = await _RawCompressedLoader().loadAsync('cube.dds');
        final faces = cube.image! as List;
        expect(faces.length, 6);
        expect((faces[5] as Map)['mipmaps'], [
          {'data': 11},
          {'data': 12},
        ]);

        final six = await _RawCompressedLoader().loadAsync([
          'f0.dds',
          'f1.dds',
          'f2.dds',
          'f3.dds',
          'f4.dds',
          'f5.dds',
        ]);
        expect((six.image! as List).map((f) => ((f as Map)['mipmaps'] as List).single), [
          for (var i = 0; i < 6; i++) {'data': i},
        ]);
      });
    });

    group('AnimationLoader', () {
      // INHERITANCE
      test('Extending', () {
        expect(AnimationLoader(), isA<Loader<List<AnimationClip>>>(), reason: 'AnimationLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        expect(AnimationLoader(), isNotNull, reason: 'Can instantiate an AnimationLoader.');
      });

      // Dart: load and parse
      test('load parse', () async {
        final clip = AnimationClip('walk', 1, [
          NumberKeyframeTrack('.opacity', [0, 1], [1, 0]),
        ]);
        final json =
            '[{"name":"walk","duration":1,"tracks":[{"name":".opacity","times":[0,1],"values":[1,0],'
            '"type":"number"}],"uuid":"${clip.uuid}","blendMode":2500,"userData":"{}"}]';
        platform.resources['clips.json'] = FakeResource.text(json);
        platform.resources['broken.json'] = FakeResource.text('[');

        final clips = await AnimationLoader().loadAsync('clips.json');
        expect(clips.single.name, 'walk');
        expect(clips.single.uuid, clip.uuid);
        expect(clips.single.tracks.single.name, '.opacity');

        final errors = <Object>[];
        final failed = <String>[];
        AnimationLoader(LoadingManager(null, null, failed.add))
            .load('broken.json', (_) => fail('no clips'), null, errors.add);
        await settle();
        expect(errors.single, isA<FormatException>());
        expect(failed, ['broken.json']);
      });
    });

    group('AudioLoader', () {
      // INHERITANCE
      test('Extending', () {
        expect(AudioLoader(), isA<Loader<Object>>(), reason: 'AudioLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        expect(AudioLoader(), isNotNull, reason: 'Can instantiate an AudioLoader.');
      });
    });
  });
}
