import 'dart:ffi';
import 'dart:typed_data';

import 'package:ent/ent.dart';
import 'package:ffi/ffi.dart';

import 'bindings.dart' as native;

/// Decoded or created audio: one plane of 32-bit float frames per channel, in native memory that lives while this
/// buffer, a channel view of it or a source playing it is held.
final class AudioData implements WebAudioBuffer, Finalizable {
  AudioData._(this.pointer)
    : channels = native.bufferChannels(pointer),
      sampleRate = native.bufferRate(pointer),
      length = native.bufferLength(pointer) {
    _finalizer.attach(this, pointer.cast(), detach: this);
  }

  /// A silent buffer of [channels] channels of [length] frames at [sampleRate], as Web Audio's `createBuffer`.
  factory AudioData(int channels, int length, int sampleRate) {
    if (channels < 1 || length < 1 || sampleRate < 1) {
      throw RangeError('ENT.AudioData: channels, length and sample rate must be positive.');
    }

    final pointer = native.bufferCreate(channels, length, sampleRate);

    if (pointer == nullptr) {
      throw StateError('ENT.AudioData: out of memory.');
    }

    return AudioData._(pointer);
  }

  /// Decodes WAV, FLAC or MP3 [data], keeping its channels and converting it to [sampleRate] (0 keeps the file's).
  /// Throws a [FormatException] when the data cannot be decoded.
  factory AudioData.decode(Uint8List data, [int sampleRate = 0]) {
    return using((arena) {
      final bytes = arena<Uint8>(data.length);
      final out = arena<Pointer<native.Buffer>>();

      bytes.asTypedList(data.length).setAll(0, data);

      final result = native.bufferDecode(bytes.cast(), data.length, sampleRate, out);

      if (result != 0) {
        throw FormatException('ENT.AudioData: the audio data cannot be decoded (miniaudio error $result).');
      }

      return AudioData._(out.value);
    });
  }

  static final _finalizer = NativeFinalizer(native.bufferRelease);

  /// The native buffer.
  final Pointer<native.Buffer> pointer;

  /// The number of channels.
  final int channels;

  /// The frames per second.
  final int sampleRate;

  /// The number of frames.
  final int length;

  @override
  double get duration => length / sampleRate;

  /// The samples of [channel], as Web Audio's `getChannelData`: a view of the buffer, so writing to it changes the
  /// buffer.
  Float32List getChannelData(int channel) {
    RangeError.checkValidIndex(channel, this, 'channel', channels);
    native.bufferRetain(pointer);

    return (native.bufferData(pointer) + channel * length).asTypedList(
      length,
      finalizer: native.bufferRelease.cast(),
      token: pointer.cast(),
    );
  }
}
