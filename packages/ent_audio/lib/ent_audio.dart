/// The audio backend of Ent Engine, on miniaudio.
library;

export 'src/buffer.dart' show AudioData;
export 'src/context.dart'
    show
        AudioAnalyserNode,
        AudioBufferSource,
        AudioGain,
        AudioNode,
        AudioPanner,
        AudioParam,
        NativeAudioContext,
        NativeAudioListener;
