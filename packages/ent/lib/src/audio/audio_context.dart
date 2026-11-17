part of '../../ent.dart';

// The Web Audio API surface the engine uses, as interfaces a platform package implements (E-PLATFORM). Names carry a
// `WebAudio` prefix because the engine already uses `AudioContext`, `AudioListener` and `Audio`; members keep the Web
// Audio names. An optional member the reference tests for (`listener.positionX`, `source.detune`) is nullable here.

/// A Web Audio `AudioNode`.
abstract class WebAudioNode {
  /// `node.connect( destination )`.
  void connect(WebAudioNode destination);

  /// `node.disconnect( destination )`; without [destination], all outgoing connections.
  void disconnect([WebAudioNode? destination]);
}

/// A Web Audio `AudioParam`.
abstract class WebAudioParam {
  /// The current value.
  double get value;

  set value(double value);

  /// Starts an exponential approach to [target] at [startTime] with [timeConstant].
  void setTargetAtTime(double target, double startTime, double timeConstant);

  /// Schedules a linear ramp to [value], reached at [endTime].
  void linearRampToValueAtTime(double value, double endTime);
}

/// A Web Audio `GainNode`.
abstract class WebAudioGainNode implements WebAudioNode {
  /// The amount of gain to apply.
  WebAudioParam get gain;
}

/// A Web Audio `AudioBuffer`: decoded audio data.
abstract class WebAudioBuffer {
  /// The duration of the PCM audio data in seconds.
  double get duration;
}

/// A Web Audio `AudioBufferSourceNode`.
abstract class WebAudioBufferSourceNode implements WebAudioNode {
  /// The audio played.
  WebAudioBuffer? buffer;

  /// Whether playback repeats between [loopStart] and [loopEnd].
  bool loop = false;

  /// Where a loop starts, in seconds.
  double loopStart = 0;

  /// Where a loop ends, in seconds; 0 loops the whole buffer.
  double loopEnd = 0;

  /// Called when playback ends (`source.onended`).
  void Function()? onended;

  /// The detune parameter, or `null` where the platform lacks it (the reference tests `source.detune !== undefined`).
  WebAudioParam? get detune;

  /// The playback rate parameter.
  WebAudioParam get playbackRate;

  /// `source.start( when, offset, duration )`; a `null` [duration] (`undefined` in the reference) plays to the end.
  void start([double when = 0, double offset = 0, double? duration]);

  /// `source.stop( when )`; the reference's `pause()` calls it with no argument (`null`), which Web Audio reads as `0`.
  void stop([double? when]);
}

/// A Web Audio `PannerNode`.
abstract class WebAudioPannerNode implements WebAudioNode {
  /// The spatialization algorithm: `'equalpower'` or `'HRTF'`.
  String panningModel = 'equalpower';

  /// How volume falls with distance: `'linear'`, `'inverse'` or `'exponential'`.
  String distanceModel = 'inverse';

  /// The distance at which volume starts to fall.
  double refDistance = 1;

  /// The distance past which volume falls no further.
  double maxDistance = 10000;

  /// How quickly volume falls with distance.
  double rolloffFactor = 1;

  /// The angle, in degrees, of the cone inside which the volume is full.
  double coneInnerAngle = 360;

  /// The angle, in degrees, of the cone outside which the volume is [coneOuterGain].
  double coneOuterAngle = 360;

  /// The volume outside [coneOuterAngle].
  double coneOuterGain = 0;

  /// The position and orientation parameters, or `null` where the platform only has the deprecated
  /// [setPosition]/[setOrientation] (the reference tests `panner.positionX`).
  WebAudioParam? get positionX;

  /// The y position; see [positionX].
  WebAudioParam? get positionY;

  /// The z position; see [positionX].
  WebAudioParam? get positionZ;

  /// The x of the direction the source faces; see [positionX].
  WebAudioParam? get orientationX;

  /// The y of the direction the source faces; see [positionX].
  WebAudioParam? get orientationY;

  /// The z of the direction the source faces; see [positionX].
  WebAudioParam? get orientationZ;

  /// The deprecated `panner.setPosition( x, y, z )`.
  void setPosition(double x, double y, double z);

  /// The deprecated `panner.setOrientation( x, y, z )`.
  void setOrientation(double x, double y, double z);
}

/// A Web Audio `AnalyserNode`.
abstract class WebAudioAnalyserNode implements WebAudioNode {
  /// The window size of the FFT.
  int fftSize = 2048;

  /// Half of [fftSize]: the number of data values for the visualization.
  int get frequencyBinCount;

  /// Copies the current frequency data into [array].
  void getByteFrequencyData(Uint8List array);
}

/// A Web Audio `AudioListener`: the position and orientation of the listener in the audio scene.
abstract class WebAudioListener {
  /// The position, forward and up parameters, or `null` where the platform only has the deprecated
  /// [setPosition]/[setOrientation] (the reference tests `listener.positionX`).
  WebAudioParam? get positionX;

  /// The y position; see [positionX].
  WebAudioParam? get positionY;

  /// The z position; see [positionX].
  WebAudioParam? get positionZ;

  /// The x of the direction the listener faces; see [positionX].
  WebAudioParam? get forwardX;

  /// The y of the direction the listener faces; see [positionX].
  WebAudioParam? get forwardY;

  /// The z of the direction the listener faces; see [positionX].
  WebAudioParam? get forwardZ;

  /// The x of the listener's up direction; see [positionX].
  WebAudioParam? get upX;

  /// The y of the listener's up direction; see [positionX].
  WebAudioParam? get upY;

  /// The z of the listener's up direction; see [positionX].
  WebAudioParam? get upZ;

  /// The deprecated `listener.setPosition( x, y, z )`.
  void setPosition(double x, double y, double z);

  /// The deprecated `listener.setOrientation( x, y, z, xUp, yUp, zUp )`.
  void setOrientation(double x, double y, double z, double xUp, double yUp, double zUp);
}

/// A Web Audio `AudioContext` (in the reference: `window.AudioContext`).
abstract class WebAudioContext {
  /// The final destination of all audio in the context.
  WebAudioNode get destination;

  /// The time in seconds of the context's audio clock.
  double get currentTime;

  /// The listener used for 3D spatialization.
  WebAudioListener get listener;

  /// A new gain node.
  WebAudioGainNode createGain();

  /// A new node that plays a [WebAudioBuffer].
  WebAudioBufferSourceNode createBufferSource();

  /// A new panner node, for positional audio.
  WebAudioPannerNode createPanner();

  /// A new analyser node, for frequency data.
  WebAudioAnalyserNode createAnalyser();

  /// `context.createMediaElementSource( mediaElement )` for a platform media element.
  WebAudioNode createMediaElementSource(Object mediaElement);

  /// `context.createMediaStreamSource( mediaStream )` for a platform media stream.
  WebAudioNode createMediaStreamSource(Object mediaStream);
}

WebAudioContext? _audioContext;

/// Manages the global audio context in the engine.
abstract final class AudioContext {
  /// Creates the platform audio context on first use (in the reference:
  /// `new ( window.AudioContext || window.webkitAudioContext )()`); `null` until a platform package installs it
  /// (E-PLATFORM).
  static WebAudioContext Function()? platform;

  /// Returns the global native audio context, creating it on first use. Without a context set by [setContext] and
  /// without a [platform], this throws a [StateError] (the reference throws a `TypeError` where `window.AudioContext`
  /// does not exist).
  static WebAudioContext getContext() {
    if (_audioContext == null) {
      final create = platform;

      if (create == null) {
        throw StateError('ENT.AudioContext: getContext() needs a platform (AudioContext.platform).');
      }

      _audioContext = create();
    }

    return _audioContext!;
  }

  /// Allows to set the global native audio context from outside; `null` makes [getContext] create a new one
  /// (`undefined` in the reference).
  static void setContext(WebAudioContext? value) {
    _audioContext = value;
  }
}
