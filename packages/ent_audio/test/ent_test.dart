// ent's own audio classes on this backend: they build the same graphs as in a browser, so this only checks that they
// play, pan and end; the nodes themselves are compared with Chrome in reference_test.dart.

import 'dart:math' as math;

import 'package:ent/ent.dart';
import 'package:ent_audio/ent_audio.dart';
import 'package:test/test.dart';

/// The root mean square of [samples].
double rms(List<double> samples) => math.sqrt(samples.fold(0.0, (sum, s) => sum + s * s) / samples.length);

void main() {
  late NativeAudioContext context;

  setUp(() {
    context = NativeAudioContext.offline();
    AudioContext.setContext(context);
  });

  tearDown(() {
    AudioContext.setContext(null);
    context.close();
  });

  AudioData tone() {
    final buffer = context.createBuffer(1, 4800, 48000);
    final data = buffer.getChannelData(0);

    for (var i = 0; i < data.length; i++) {
      data[i] = math.sin(i * 2 * math.pi * 440 / 48000);
    }

    return buffer;
  }

  test('Audio plays at its volume and ends', () async {
    final listener = AudioListener();
    final sound = Audio(listener)
      ..setBuffer(tone())
      ..setVolume(0.5)
      ..play();

    final out = context.render(4800);

    expect(rms(out[0].sublist(2400)), closeTo(0.5 / math.sqrt2, 1e-3));
    expect(out[0], out[1]);

    context.render(256);
    await Future<void>.delayed(Duration.zero);
    expect(sound.isPlaying, isFalse);
  });

  test('PositionalAudio to the listener\'s right is louder on the right', () {
    final camera = PerspectiveCamera();
    final listener = AudioListener();
    final mesh = Object3D()..position.set(3, 0, -1);
    final sound = PositionalAudio(listener)..setBuffer(tone());

    camera.add(listener);
    mesh.add(sound);
    sound.play();
    camera.updateMatrixWorld(true);
    mesh.updateMatrixWorld(true);

    final out = context.render(2048);

    expect(rms(out[1].sublist(1024)), greaterThan(rms(out[0].sublist(1024)) * 3));
  });

  test('turning the listener around swaps the sides', () {
    final camera = PerspectiveCamera()..rotation.y = math.pi;
    final listener = AudioListener();
    final mesh = Object3D()..position.set(3, 0, -1);
    final sound = PositionalAudio(listener)..setBuffer(tone());

    camera.add(listener);
    mesh.add(sound);
    sound.play();
    camera.updateMatrixWorld(true);
    mesh.updateMatrixWorld(true);

    final out = context.render(2048);

    expect(rms(out[0].sublist(1024)), greaterThan(rms(out[1].sublist(1024)) * 3));
  });

  test('a distant PositionalAudio is quieter', () {
    final listener = AudioListener();
    final near = Object3D()..position.set(0, 0, -2);
    final far = Object3D()..position.set(0, 0, -20);
    final a = PositionalAudio(listener)..setBuffer(tone());
    final b = PositionalAudio(listener)..setBuffer(tone());

    near.add(a);
    far.add(b);
    listener.updateMatrixWorld(true);
    a.play();
    near.updateMatrixWorld(true);

    final loud = rms(context.render(2048)[0].sublist(1024));

    a.stop();
    b.play();
    far.updateMatrixWorld(true);
    context.render(2048);

    final quiet = rms(context.render(1024)[0]);

    expect(quiet, closeTo(loud / 10, loud / 100));
  });
}
