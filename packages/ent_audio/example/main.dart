// A tone panned from left to right and back, made in code and played on the output device: ent's Audio classes
// through NativeAudioContext.

import 'dart:math' as math;

import 'package:ent/ent.dart';
import 'package:ent_audio/ent_audio.dart';

Future<void> main() async {
  NativeAudioContext.install();

  final listener = AudioListener();
  final context = listener.context as NativeAudioContext;
  final buffer = context.createBuffer(1, context.sampleRate, context.sampleRate);
  final data = buffer.getChannelData(0);

  for (var i = 0; i < data.length; i++) {
    data[i] = 0.3 * math.sin(i * 2 * math.pi * 330 / context.sampleRate);
  }

  final holder = Object3D();
  final sound = PositionalAudio(listener)
    ..setBuffer(buffer)
    ..setLoop(true)
    ..setRefDistance(2);

  holder.add(sound);
  sound.play();

  for (var t = 0.0; t < 4; t += 1 / 30) {
    holder
      ..position.set(4 * math.sin(t * math.pi / 2), 0, -2)
      ..updateMatrixWorld(true);
    await Future<void>.delayed(const Duration(milliseconds: 33));
  }

  sound.stop();
  context.close();
}
