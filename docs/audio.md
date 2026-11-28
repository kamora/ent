# Audio

`ent` has the reference's audio classes (`AudioListener`, `Audio`, `PositionalAudio`, `AudioAnalyser`) over a Web
Audio surface (`lib/src/audio/audio_context.dart`) that a platform package implements and installs as
`AudioContext.platform`. This page compares the ways to implement it and records the choice: `ent_audio`, our own
package on miniaudio (Kai, 2026-11-28).

## What a backend must do

From `audio_context.dart` and the classes that use it:

- Decode sound files into buffers (`AudioLoader`), and play a buffer from a source node: start with a delay and an
  offset, stop, loop between two points, playback rate and detune, an `onended` callback.
- Gain nodes, with parameters that ramp (`setTargetAtTime`, `linearRampToValueAtTime`) on an audio clock
  (`currentTime`).
- A panner node per positional sound, with the Web Audio panner model: position and orientation, distance model
  (linear, inverse, exponential) with reference distance, maximum distance and rolloff, and a directional cone (inner
  angle, outer angle, outer gain).
- One listener: position, forward and up.
- An analyser: `frequencyBinCount` and `getByteFrequencyData`.

## Candidates

Facts from pub.dev's API and the projects' own repositories and source, checked 2026-11-28. Nothing below was built or
run.

| | Package | Maintainer | License | 3D | Fit |
|---|---|---|---|---|---|
| flutter_soloud | 5.4.0, 2026-11-26; 619 likes, 210k downloads in 30 days | Marco Bavagnoli (alnitak; 1,998 of 2,317 commits), publisher marcobavagnoli.com | MIT, SoLoud under zlib; VST3 hosting is opt-in and off by default | Positional, Doppler, the three distance models (clamped at the maximum distance); **no cones**: `soloud_core_3d.cpp` reads `// (todo) vol *= conev;` | Everything else is there: decoding (MP3, WAV, FLAC, OGG), loops, speed, faders, filters, buses, FFT data. Android, iOS, macOS, Windows, Linux, web |
| miniaudio, our own package | A single C file (`miniaudio.h`, 4 MB), not on pub.dev | David Reid (mackron; 7.7k stars, active this week) | Public domain or MIT-0, the reader's choice | Positional, Doppler, the three distance models with Web Audio's formulas (also clamped at the maximum distance), **cones** (`ma_sound_set_cone`), listener with world up | Decoding (WAV, FLAC, MP3 built in), loops, pitch, fades, seeking, a node graph. No FFT: the analyser would be ours, in Dart |
| just_audio, audioplayers | 0.10.6 and 6.8.1; the most used players | ryanheise.com; Blue Fire | Apache-2.0/MIT; MIT | None | Players only; positional sound would have to be built on top. Ruled out |
| Smaller packages (minisound, flutter_al, flutter3d_audio, just_audio_engine, ...) | 0 to 15 likes, under 1,000 downloads in 30 days | Not examined | MIT, MPL-2.0, BSD-3-Clause | Not examined | Too few users to depend on |

Both real options clamp distance at the maximum distance for every model, where Web Audio clamps it only for the
linear one: past `maxDistance`, an inverse or exponential sound stops getting quieter. That would be a recorded
compatibility exception (or a large maximum distance by default).

## The two ways

1. **On flutter_soloud.** The backend is an adapter: Web Audio's nodes mapped onto SoLoud's voices, buses and 3D
   parameters. Fastest to a sound playing, on every platform at once. Costs: a large native dependency maintained
   mostly by one person, and cones missing.
2. **Our own package on miniaudio**, the way `wrangle` carries ANGLE: the C file compiled by a build hook on each
   platform, our FFI bindings, our analyser. Its model matches the Web Audio panner more closely, cones included, and
   we own the stack, the source being ours to keep. Costs: more work (bindings, a build hook for four platforms,
   decoding of OGG through another single file, stb_vorbis, the analyser).

## Decision

Kai chose the second way on 2026-11-28: closer to Web Audio, cones included, and the source is ours, as ANGLE is in
`wrangle`. miniaudio 0.11.26 is vendored in `packages/ent_audio/third_party/miniaudio/` and compiled by the package's
build hook (Objective-C with the audio frameworks linked on Apple platforms).

miniaudio plays the device and decodes. The graph is ent_audio's own, in C (`src/ent_audio.c`): its Web Audio nodes
(buffer source, gain with parameter automation, panner, analyser) follow the Web Audio specification and Chrome's
behaviour rather than miniaudio's node graph and spatializer. The graph renders in Web Audio's quanta of 128 frames
and mixes channels by Web Audio's rules, which miniaudio's graph does not. So distance and cone gain can match Web
Audio exactly, and a graph rendered offline can be compared sample by sample with the same graph rendered by
Chrome's `OfflineAudioContext`.

## Steps

1. The package, the build hook, decoding into buffers (done: WAV checked sample for sample).
2. The buffer source: start with delay, offset and duration, stop, loop points, playback rate, detune, `onended`
   (done: 24 scenarios in `fixtures/audio/sources.json` equal Chrome 158's rendering sample for sample).
3. Gain and parameter automation (`value`, `setTargetAtTime`, `linearRampToValueAtTime`) on the audio clock (done: 23
   scenarios in `fixtures/audio/params.json`, including changes made while rendering, equal Chrome's rendering and
   its parameter values).
4. The panner and the listener: equal-power panning, the three distance models, the cone.
5. The analyser: captured samples, the specification's windowed FFT and smoothing.
6. Device output in a Flutter app on macOS, iOS and Android, and sound in the voxels demo.

Each of steps 2 to 5 is checked against Chrome's offline rendering of the same graph.

## What matching Chrome takes

- The graph renders in quanta of 128 frames; playback rate and detune are read once per quantum.
- Every started source renders, connected or not: Chrome ends an unconnected source on time and fires its `onended`.
- Parameter values are 32-bit floats, and Chrome computes `detune / 1200` in that precision.
- A start between two frames begins at the next frame with the playhead moved on by the difference; reading between
  frames interpolates linearly, and past the last frame extrapolates from the last two.
- The C is compiled with `-ffp-contract=off`: a fused multiply-add rounds the interpolation differently by one bit.
- Parameter automation is a port of Chromium's timeline for the three kinds of event ent uses: setting the value
  schedules it at the current time, a ramp with nothing before it starts from the value it was scheduled at, an
  approach to a target steps by a discrete time constant and snaps once it converges, and a parameter read once per
  quantum (playback rate, detune) uses the quantum rate for that constant. Exponential ramps, value curves and
  cancelling are not ported: ent's audio classes do not use them.
