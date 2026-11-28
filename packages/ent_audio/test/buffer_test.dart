import 'dart:typed_data';

import 'package:ent_audio/ent_audio.dart';
import 'package:test/test.dart';

/// A 16-bit PCM WAV file holding [samples], interleaved over [channels].
Uint8List wav(List<int> samples, {int channels = 1, int rate = 48000}) {
  final data = ByteData(44 + samples.length * 2);
  final text = 'RIFF....WAVEfmt ';

  for (var i = 0; i < text.length; i++) {
    data.setUint8(i, text.codeUnitAt(i));
  }

  data
    ..setUint32(4, 36 + samples.length * 2, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * channels * 2, Endian.little)
    ..setUint16(32, channels * 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little)
    ..setUint32(40, samples.length * 2, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  return data.buffer.asUint8List();
}

void main() {
  test('decodes 16-bit samples exactly at the file rate', () {
    final samples = [0, 16384, -16384, 32767, -32768, 1, -1, 1000];
    final buffer = AudioData.decode(wav(samples, channels: 2, rate: 44100));

    expect(buffer.channels, 2);
    expect(buffer.sampleRate, 44100);
    expect(buffer.length, 4);
    expect(buffer.duration, 4 / 44100);
    expect(buffer.getChannelData(0), [for (var i = 0; i < 8; i += 2) samples[i] / 32768]);
    expect(buffer.getChannelData(1), [for (var i = 1; i < 8; i += 2) samples[i] / 32768]);
  });

  test('converts to the asked rate and keeps the channels', () {
    final buffer = AudioData.decode(wav(List.filled(24000, 8192)), 48000);

    expect(buffer.channels, 1);
    expect(buffer.sampleRate, 48000);
    expect(buffer.length, 24000);
    expect(buffer.duration, 0.5);

    final low = AudioData.decode(wav(List.filled(24000, 8192)), 24000);

    expect(low.length, 12000);
    expect(low.getChannelData(0)[6000], closeTo(0.25, 1e-6));
  });

  test('throws on data that is not audio', () {
    expect(() => AudioData.decode(Uint8List.fromList(List.filled(64, 7))), throwsFormatException);
  });
}
