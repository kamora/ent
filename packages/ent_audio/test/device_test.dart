// Plays on this machine's default output device. It checks the device's clock and that a sound ends on time, not
// what is heard; on a machine without an output device the tests are skipped.

import 'dart:math' as math;

import 'package:ent_audio/ent_audio.dart';
import 'package:test/test.dart';

void main() {
  NativeAudioContext? context;
  Object? missing;

  try {
    context = NativeAudioContext();
  } on StateError catch (e) {
    missing = e;
  }

  tearDownAll(() {
    context?.close();
  });

  test('the device clock follows real time', () async {
    final playing = context!;
    final watch = Stopwatch()..start();
    final start = playing.currentTime;

    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(playing.sampleRate, greaterThan(0));
    expect(playing.currentTime - start, closeTo(watch.elapsedMilliseconds / 1000, 0.1));
  }, skip: missing);

  test('a sound plays on the device and ends', () async {
    final playing = context!;
    final buffer = playing.createBuffer(1, playing.sampleRate ~/ 5, playing.sampleRate);
    final data = buffer.getChannelData(0);
    var ended = false;

    for (var i = 0; i < data.length; i++) {
      data[i] = 0.1 * math.sin(i * 2 * math.pi * 440 / playing.sampleRate);
    }

    playing.createBufferSource()
      ..buffer = buffer
      ..onended = (() => ended = true)
      ..connect(playing.destination)
      ..start();

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(ended, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(ended, isTrue);
  }, skip: missing);

  test('a playing context does not render on demand', () {
    expect(() => context!.render(128), throwsStateError);
  }, skip: missing);
}
