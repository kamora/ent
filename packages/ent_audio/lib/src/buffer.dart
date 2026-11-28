import 'dart:ffi';
import 'dart:typed_data';

import 'package:ent/ent.dart';
import 'package:ffi/ffi.dart';

import 'bindings.dart' as native;

/// Decoded audio: interleaved 32-bit float frames held in native memory, freed when the buffer is collected.
final class AudioData implements WebAudioBuffer, Finalizable {
  AudioData._(this.samples, this.channels, this.sampleRate, this.length) {
    _finalizer.attach(this, samples.cast(), detach: this);
  }

  /// Decodes WAV, FLAC or MP3 [data], keeping its channels and converting it to [sampleRate] (0 keeps the file's).
  /// Throws a [FormatException] when the data cannot be decoded.
  factory AudioData.decode(Uint8List data, [int sampleRate = 0]) {
    return using((arena) {
      final bytes = arena<Uint8>(data.length);
      final channels = arena<Uint32>();
      final rate = arena<Uint32>();
      final frames = arena<Uint64>();
      final samples = arena<Pointer<Float>>();

      bytes.asTypedList(data.length).setAll(0, data);

      final result = native.decode(bytes.cast(), data.length, sampleRate, channels, rate, frames, samples);

      if (result != 0) {
        throw FormatException('ENT.AudioData: the audio data cannot be decoded (miniaudio error $result).');
      }

      return AudioData._(samples.value, channels.value, rate.value, frames.value);
    });
  }

  static final _finalizer = NativeFinalizer(native.free);

  /// The frames, `channels` samples each.
  final Pointer<Float> samples;

  /// The number of channels.
  final int channels;

  /// The frames per second.
  final int sampleRate;

  /// The number of frames.
  final int length;

  @override
  double get duration => length / sampleRate;

  /// A copy of one channel's samples, as Web Audio's `getChannelData` returns them.
  Float32List getChannelData(int channel) {
    final all = samples.asTypedList(length * channels);
    return Float32List.fromList([for (var i = channel; i < all.length; i += channels) all[i]]);
  }
}
