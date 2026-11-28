# ent_audio

The audio backend of Ent Engine: it plays the engine's `AudioListener`, `Audio`, `PositionalAudio` and
`AudioAnalyser` on the device's sound output. It is a Web Audio graph in C (buffer sources, gains with parameter
automation, equal-power panners with distance and cone gains, analysers) on [miniaudio], which plays the device and
decodes sound files. The C is compiled into the app by the package's build hook; there is nothing to install.

The graph follows Chrome's Web Audio implementation, and its tests compare it with Chrome: the same graphs rendered by
Chrome's `OfflineAudioContext` and by this package are equal sample for sample.

## Use

Install it once, before the first `AudioListener`:

```dart
import 'package:ent_audio/ent_audio.dart';
import 'package:ent_flutter/ent_flutter.dart';

void main() {
  NativeAudioContext.install();

  final listener = AudioListener();
  camera.add(listener);

  final sound = PositionalAudio(listener);
  mesh.add(sound);

  AudioLoader().load('sounds/hit.wav', (buffer) {
    sound
      ..setBuffer(buffer as WebAudioBuffer)
      ..setRefDistance(20)
      ..play();
  });
}
```

`NativeAudioContext()` opens the default output device in stereo at its own rate and plays until `close()`.
`NativeAudioContext.offline()` renders on demand with `render()`, for tests. `AudioData` holds decoded sound:
`AudioLoader` decodes WAV, FLAC and MP3 through it, at the context's rate.

## Platforms

macOS, iOS and Android, as the renderers. Verified on macOS (an M1's output device); iOS and Android builds compile,
not yet run on a device.

## Limits

- The `HRTF` panning model, which `PositionalAudio` asks for, pans by equal power: left and right are right, but
  there are no cues for front, back and height.
- OGG Vorbis files are not decoded.
- No media elements or streams (`setMediaElementSource`, `setMediaStreamSource`): there are none outside a browser.

## License

MIT, © 2026 KAMORA Ltd.; see `LICENSE`.

It compiles miniaudio, and its graph follows Chromium's Web Audio code; their notices are in `THIRD_PARTY_NOTICES.md`.

[miniaudio]: https://github.com/mackron/miniaudio
