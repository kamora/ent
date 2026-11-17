import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

/// A context that decodes by echoing the byte count, or fails for empty data.
class _DecodingContext implements WebAudioContext, WebAudioDecodingContext {
  final List<int> decoded = [];

  @override
  Future<Object> decodeAudioData(ByteBuffer data) async {
    if (data.lengthInBytes == 0) {
      throw StateError('EncodingError');
    }

    decoded.add(data.lengthInBytes);
    return {'audioBuffer': data.lengthInBytes};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A context without decodeAudioData.
class _PlainContext implements WebAudioContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Loaders', () {
    group('AudioLoader', () {
      late FakeLoaderPlatform platform;

      setUp(() => Loader.platform = platform = FakeLoaderPlatform());

      tearDown(() {
        Loader.platform = null;
        AudioContext.setContext(null);
        setConsoleFunction(null);
      });

      // Dart: behaviour through fake platforms (the reference tests only cover inheritance and instancing)
      test('load decodes a copy of the buffer', () async {
        final context = _DecodingContext();
        AudioContext.setContext(context);
        platform.resources['a.ogg'] = FakeResource(Uint8List(5));

        final log = <String>[];
        final manager = LoadingManager(() => log.add('done'), (url, loaded, total) => log.add('$url $loaded/$total'));

        final buffer = await AudioLoader(manager).loadAsync('a.ogg');
        await settle();

        expect(buffer, {'audioBuffer': 5});
        expect(context.decoded, [5]);

        // the decode is a separate manager item, so `done` waits for it (#33378)
        expect(log, ['a.ogg 1/2', 'a.ogg#decode 2/2', 'done']);
      });

      test('decoding errors', () async {
        AudioContext.setContext(_DecodingContext());
        platform.resources['empty.ogg'] = FakeResource(Uint8List(0));

        final errors = <Object>[];
        final failed = <String>[];
        AudioLoader(LoadingManager(null, null, failed.add)).load('empty.ogg', (_) => fail('decoded'), null, errors.add);
        await settle();

        expect(errors.single, isA<StateError>());
        expect(failed, ['empty.ogg']);

        // without onError the error is logged
        final logged = <String>[];
        setConsoleFunction((type, message, params) => logged.add('$type $message'));
        AudioContext.setContext(_PlainContext());
        platform.resources['a.ogg'] = FakeResource(Uint8List(2));
        AudioLoader().load('a.ogg', (_) => fail('decoded'));
        await settle();
        expect(logged.single, startsWith('error ENT.Bad state: ENT.AudioLoader: the audio context cannot decode'));
      });
    });
  });
}
