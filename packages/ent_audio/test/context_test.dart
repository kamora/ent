import 'dart:typed_data';

import 'package:ent_audio/ent_audio.dart';
import 'package:test/test.dart';

void main() {
  late NativeAudioContext context;

  setUp(() {
    context = NativeAudioContext.offline();
  });

  tearDown(() {
    context.close();
  });

  test('the clock advances by whole quanta', () {
    expect(context.currentTime, 0);
    context.render(100);
    expect(context.currentTime, 128 / 48000);
    context.render(256);
    expect(context.currentTime, 384 / 48000);
  });

  test('parameters hold 32-bit floats', () {
    final source = context.createBufferSource();

    expect(source.playbackRate.value, 1);
    expect(source.detune.value, 0);

    source.playbackRate.value = 1.1;
    expect(source.playbackRate.value, (Float32List(1)..[0] = 1.1)[0]);
  });

  test('a buffer is written through its channel views', () {
    final buffer = context.createBuffer(2, 4, 48000);
    final source = context.createBufferSource();

    buffer.getChannelData(1).setAll(0, [0.25, 0.5, 0.75, 1]);
    source
      ..buffer = buffer
      ..connect(context.destination)
      ..start();

    final out = context.render(4);

    expect(out[0], [0, 0, 0, 0]);
    expect(out[1], [0.25, 0.5, 0.75, 1]);
  });

  test('onended fires once the event loop turns', () async {
    final source = context.createBufferSource();
    var ended = 0;

    source
      ..buffer = context.createBuffer(1, 10, 48000)
      ..onended = (() => ended++)
      ..start();

    context.render(128);
    expect(ended, 0);

    await Future<void>.delayed(Duration.zero);
    context.render(128);
    await Future<void>.delayed(Duration.zero);
    expect(ended, 1);
  });

  test('start, stop and buffer follow Web Audio\'s rules', () {
    final source = context.createBufferSource();
    final buffer = context.createBuffer(1, 10, 48000);

    expect(() => source.stop(), throwsStateError);
    expect(() => source.start(-1), throwsRangeError);
    expect(() => source.start(0, -1), throwsRangeError);
    expect(() => source.start(0, 0, -1), throwsRangeError);

    source.buffer = buffer;
    expect(() => source.buffer = buffer, throwsStateError);
    expect(() => source.buffer = null, throwsStateError);

    source.start();
    expect(() => source.start(), throwsStateError);
    expect(() => source.stop(-1), throwsRangeError);
    source.stop();
  });

  test('nodes connect only within their context', () {
    final other = NativeAudioContext.offline();
    addTearDown(other.close);

    expect(() => context.createBufferSource().connect(other.destination), throwsArgumentError);
  });

  test('decodeAudioData converts to the context rate', () async {
    final wav = ByteData(44 + 200)
      ..setUint32(0, 0x46464952, Endian.little)
      ..setUint32(4, 236, Endian.little)
      ..setUint32(8, 0x45564157, Endian.little)
      ..setUint32(12, 0x20746d66, Endian.little)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, 24000, Endian.little)
      ..setUint32(28, 48000, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x61746164, Endian.little)
      ..setUint32(40, 200, Endian.little);
    final buffer = await context.decodeAudioData(wav.buffer);

    expect(buffer.sampleRate, 48000);
    expect(buffer.length, 200);
  });

  test('media elements and streams are not supported', () {
    expect(() => context.createMediaElementSource(Object()), throwsUnsupportedError);
    expect(() => context.createMediaStreamSource(Object()), throwsUnsupportedError);
  });
}
