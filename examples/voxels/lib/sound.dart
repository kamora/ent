// The sound of a blast, made here rather than loaded: a burst of noise that falls from a crack to a rumble over a low
// thump, played from where the crater opens.

import 'dart:math' as math;

import 'package:ent_audio/ent_audio.dart';
import 'package:ent_flutter/ent_flutter.dart';

/// Blasts heard by a listener on the camera.
class Blasts {
  Blasts._(this.listener, this.buffer);

  /// Blasts heard from [camera], or `null` when there is no output device to play on.
  static Blasts? create(Camera camera) {
    try {
      final listener = AudioListener();
      camera.add(listener);
      return Blasts._(listener, _boom(listener.context as NativeAudioContext));
    } on StateError {
      return null;
    }
  }

  /// The length of a blast, in seconds.
  static const duration = 1.6;

  final AudioListener listener;

  final AudioData buffer;

  /// Plays a blast at [at] in [parent]'s space, louder the more [voxels] flew, and removes it from [game] once it has
  /// played.
  void play(Game game, Object3D parent, Vector3 at, int voxels) {
    final sound = PositionalAudio(listener)
      ..setBuffer(buffer)
      ..setRefDistance(30)
      ..setVolume(math.min(1, 0.35 + voxels / 800))
      ..setPlaybackRate(0.85 + math.Random().nextDouble() * 0.3);

    sound.position.copy(at);
    parent.add(sound);
    sound.play();
    game.after(duration + 0.2, () => parent.remove(sound));
  }

  static AudioData _boom(NativeAudioContext context) {
    final rate = context.sampleRate;
    final buffer = context.createBuffer(1, (duration * rate).round(), rate);
    final data = buffer.getChannelData(0);
    final random = math.Random(7);
    var low = 0.0;
    var phase = 0.0;

    for (var i = 0; i < data.length; i++) {
      final t = i / rate;

      // Noise through a low-pass filter whose cutoff falls from 3 kHz to about 150 Hz.
      final cutoff = 150 + 2850 * math.exp(-t * 6);
      low += (1 - math.exp(-2 * math.pi * cutoff / rate)) * (random.nextDouble() * 2 - 1 - low);

      // A thump sliding down from 90 Hz.
      phase += 2 * math.pi * (40 + 50 * math.exp(-t * 8)) / rate;

      final attack = math.min(1.0, t / 0.004);
      data[i] = attack * (1.6 * low * math.exp(-t * 2.2) + 0.7 * math.sin(phase) * math.exp(-t * 4));
    }

    return buffer;
  }
}
