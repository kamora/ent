# Third-party notices

## miniaudio

ent_audio compiles [miniaudio](https://github.com/mackron/miniaudio) 0.11.26 (`third_party/miniaudio/`), by David Reid,
used under the MIT No Attribution alternative of its license (`third_party/miniaudio/LICENSE`).

## Chromium

`src/ent_audio.c` follows Chromium's Web Audio implementation: the buffer source follows the behaviour of
`audio_buffer_source_handler.cc` and `audio_scheduled_source_handler.cc` (the start and stop frames, the loop and the
linear interpolation), the parameter automation is ported from `audio_param_handler.cc`, with the gain node of
`gain_handler.cc`, and the panner and listener from `panner_handler.cc`, `audio_listener_handler.cc`,
`equal_power_panner.cc`, `distance_effect.cc`, `cone_effect.cc` and `ui/gfx/geometry/vector3d_f.cc`.

```
Copyright 2015 The Chromium Authors

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

   * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
   * Neither the name of Google LLC nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
