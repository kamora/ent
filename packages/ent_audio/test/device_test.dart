// Plays on this machine's default output device. It checks the device's clock and that a sound ends on time, not
// what is heard; on a machine without an output device the tests are skipped.

import 'dart:math' as math;

import 'package:ent_audio/ent_audio.dart';
import 'package:test/test.dart';

/// Waits up to [limit] for [done], checking every 10 ms; a device can take a while to start.
Future<bool> until(bool Function() done, [Duration limit = const Duration(seconds: 2)]) async {
  final watch = Stopwatch()..start();

  while (!done() && watch.elapsed < limit) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  return done();
}

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

    expect(await until(() => playing.currentTime > 0), isTrue, reason: 'the device never started');

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

    final start = playing.currentTime;

    playing.createBufferSource()
      ..buffer = buffer
      ..onended = (() => ended = true)
      ..connect(playing.destination)
      ..start();

    expect(await until(() => ended), isTrue);

    // It ended once the device had played its 0.2 seconds, not before.
    expect(playing.currentTime - start, greaterThanOrEqualTo(0.2 - 1e-9));
  }, skip: missing);

  test('a playing context does not render on demand', () {
    expect(() => context!.render(128), throwsStateError);
  }, skip: missing);
}
