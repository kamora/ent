## 0.1.0-dev.1

- First release: `NativeAudioContext`, a Web Audio context on miniaudio that plays on the output device (or renders
  offline), and `NativeAudioContext.install()` for `ent`'s audio classes. Buffer sources, gains, parameter automation
  (`value`, `linearRampToValueAtTime`, `setTargetAtTime`), equal-power panners with the three distance models and
  cones, the listener and analysers, equal to Chrome's rendering; WAV, FLAC and MP3 decoding.
