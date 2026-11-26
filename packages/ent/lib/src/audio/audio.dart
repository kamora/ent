part of '../../ent.dart';

/// Represents a non-positional ( global ) audio object.
///
/// This and related audio modules make use of the [Web Audio API](https://www.w3.org/TR/webaudio-1.1/),
/// reached through the [WebAudioContext] a platform package supplies (E-PLATFORM).
///
/// ```dart
/// // create an AudioListener and add it to the camera
/// final listener = AudioListener();
/// camera.add(listener);
///
/// // create a global audio source
/// final sound = Audio(listener);
///
/// // load a sound and set it as the Audio object's buffer
/// final audioLoader = AudioLoader();
/// audioLoader.load('sounds/ambient.ogg', (buffer) {
/// 	sound.setBuffer(buffer);
/// 	sound.setLoop(true);
/// 	sound.setVolume(0.5);
/// 	sound.play();
/// });
/// ```
class Audio extends Object3D {
  /// Constructs a new audio for the global audio [listener].
  Audio(this.listener) : context = listener.context {
    type = 'Audio';

    gain = context.createGain();
    gain.connect(listener.getInput());
  }

  /// The global audio listener.
  final AudioListener listener;

  /// The audio context.
  final WebAudioContext context;

  /// The gain node used for volume control.
  late final WebAudioGainNode gain;

  /// Whether to start playback automatically or not.
  bool autoplay = false;

  /// A reference to an audio buffer. Defined via [setBuffer].
  WebAudioBuffer? buffer;

  /// Modify pitch, measured in cents. +/- 100 is a semitone. +/- 1200 is an octave. Defined via [setDetune].
  double detune = 0;

  /// Whether the audio should loop or not. Defined via [setLoop].
  bool loop = false;

  /// Defines where in the audio buffer the replay should start, in seconds.
  double loopStart = 0;

  /// Defines where in the audio buffer the replay should stop, in seconds.
  double loopEnd = 0;

  /// An offset to the time within the audio buffer the playback should begin, in seconds.
  double offset = 0;

  /// Overrides the default duration of the audio; `null` (`undefined` in the reference) plays the whole buffer.
  double? duration;

  /// The playback speed. Defined via [setPlaybackRate].
  double playbackRate = 1;

  /// Indicates whether the audio is playing or not.
  ///
  /// This flag will be automatically set when using [play], [pause], [stop].
  bool isPlaying = false;

  /// Indicates whether the audio playback can be controlled with method like [play] or [pause].
  ///
  /// This flag will be automatically set when audio sources are defined.
  bool hasPlaybackControl = true;

  /// Holds a reference to the current audio source.
  ///
  /// The property is automatically by one of the `set*()` methods.
  WebAudioNode? source;

  /// Defines the source type.
  ///
  /// The property is automatically set by one of the `set*()` methods: `'empty'`, `'audioNode'`,
  /// `'mediaNode'`, `'mediaStreamNode'` or `'buffer'`.
  String sourceType = 'empty';

  double _startedAt = 0;
  double _progress = 0;

  /// For tests: the playback position kept while paused, in seconds.
  @visibleForTesting
  double get progress => _progress;
  bool _connected = false;

  /// Can be used to apply a variety of low-order filters to create more complex sound effects e.g. via
  /// `BiquadFilterNode`.
  ///
  /// The property is automatically set by [setFilters].
  List<WebAudioNode> filters = [];

  /// Returns the output audio node.
  WebAudioNode getOutput() {
    return gain;
  }

  /// Sets the given audio node as the source of this instance.
  ///
  /// [sourceType] is set to `audioNode` and [hasPlaybackControl] to `false`.
  Audio setNodeSource(WebAudioNode audioNode) {
    hasPlaybackControl = false;
    sourceType = 'audioNode';
    source = audioNode;
    connect();

    return this;
  }

  /// Sets the given platform media element as the source of this instance.
  ///
  /// [sourceType] is set to `mediaNode` and [hasPlaybackControl] to `false`.
  Audio setMediaElementSource(Object mediaElement) {
    hasPlaybackControl = false;
    sourceType = 'mediaNode';
    source = context.createMediaElementSource(mediaElement);
    connect();

    return this;
  }

  /// Sets the given platform media stream as the source of this instance.
  ///
  /// [sourceType] is set to `mediaStreamNode` and [hasPlaybackControl] to `false`.
  Audio setMediaStreamSource(Object mediaStream) {
    hasPlaybackControl = false;
    sourceType = 'mediaStreamNode';
    source = context.createMediaStreamSource(mediaStream);
    connect();

    return this;
  }

  /// Sets the given audio buffer as the source of this instance.
  ///
  /// [sourceType] is set to `buffer` and [hasPlaybackControl] to `true`.
  Audio setBuffer(WebAudioBuffer audioBuffer) {
    buffer = audioBuffer;
    sourceType = 'buffer';

    if (autoplay) {
      play();
    }

    return this;
  }

  /// Starts the playback of the audio after [delay] seconds (default `0`).
  ///
  /// Can only be used with compatible audio sources that allow playback control. Returns `null` (in the reference:
  /// `undefined`) with a warning when the audio is already playing or has no playback control.
  Audio? play([double delay = 0]) {
    if (isPlaying == true) {
      warn('Audio: Audio is already playing.');
      return null;
    }

    if (hasPlaybackControl == false) {
      warn('Audio: this Audio has no playback control.');
      return null;
    }

    _startedAt = context.currentTime + delay;

    final source = context.createBufferSource();
    source.buffer = buffer;
    source.loop = loop;
    source.loopStart = loopStart;
    source.loopEnd = loopEnd;
    source.onended = onEnded;
    source.start(_startedAt, _progress + offset, duration);

    isPlaying = true;

    this.source = source;

    setDetune(detune);
    setPlaybackRate(playbackRate);

    return connect();
  }

  /// Pauses the playback of the audio.
  ///
  /// Can only be used with compatible audio sources that allow playback control; otherwise warns and
  /// returns `null`.
  Audio? pause() {
    if (hasPlaybackControl == false) {
      warn('Audio: this Audio has no playback control.');
      return null;
    }

    if (isPlaying == true) {
      // update current progress

      _progress += math.max(context.currentTime - _startedAt, 0.0) * playbackRate;

      if (loop == true) {
        // ensure _progress does not exceed duration with looped audios

        final duration = this.duration;
        _progress = _progress.remainder(
          duration == null || duration == 0 || duration.isNaN ? buffer!.duration : duration,
        );
      }

      final source = this.source as WebAudioBufferSourceNode;
      source.stop();
      source.onended = null;

      isPlaying = false;
    }

    return this;
  }

  /// Stops the playback of the audio after [delay] seconds (default `0`).
  ///
  /// Can only be used with compatible audio sources that allow playback control; otherwise warns and
  /// returns `null`.
  Audio? stop([double delay = 0]) {
    if (hasPlaybackControl == false) {
      warn('Audio: this Audio has no playback control.');
      return null;
    }

    _progress = 0;

    final source = this.source;

    if (source != null) {
      source as WebAudioBufferSourceNode;
      source.stop(context.currentTime + delay);
      source.onended = null;
    }

    isPlaying = false;

    return this;
  }

  /// Connects to the audio source. This is used internally on initialisation and when setting / removing
  /// filters.
  Audio connect() {
    final source = this.source!;

    if (filters.isNotEmpty) {
      source.connect(filters[0]);

      for (var i = 1, l = filters.length; i < l; i++) {
        filters[i - 1].connect(filters[i]);
      }

      filters[filters.length - 1].connect(getOutput());
    } else {
      source.connect(getOutput());
    }

    _connected = true;

    return this;
  }

  /// Disconnects to the audio source. This is used internally on initialisation and when setting / removing filters.
  /// Returns `null` (`undefined` in the reference) when not connected.
  Audio? disconnect() {
    if (_connected == false) {
      return null;
    }

    final source = this.source!;

    if (filters.isNotEmpty) {
      source.disconnect(filters[0]);

      for (var i = 1, l = filters.length; i < l; i++) {
        filters[i - 1].disconnect(filters[i]);
      }

      filters[filters.length - 1].disconnect(getOutput());
    } else {
      source.disconnect(getOutput());
    }

    _connected = false;

    return this;
  }

  /// Returns the current set filters.
  List<WebAudioNode> getFilters() {
    return filters;
  }

  /// Sets an array of filters and connects them with the audio source; `null` clears them.
  Audio setFilters([List<WebAudioNode>? value]) {
    value ??= [];

    if (_connected == true) {
      disconnect();
      filters = value.toList();
      connect();
    } else {
      filters = value.toList();
    }

    return this;
  }

  /// Defines the detuning of oscillation in cents.
  Audio setDetune(double value) {
    detune = value;

    if (isPlaying == true) {
      final param = (source as WebAudioBufferSourceNode).detune;

      if (param != null) {
        param.setTargetAtTime(detune, context.currentTime, 0.01);
      }
    }

    return this;
  }

  /// Returns the detuning of oscillation in cents.
  double getDetune() {
    return detune;
  }

  /// Returns the first filter in the list of filters, or `null` (`undefined` in the reference) when there is none.
  WebAudioNode? getFilter() {
    final filters = getFilters();
    return filters.isEmpty ? null : filters[0];
  }

  /// Applies a single filter node to the audio; `null` removes the filters.
  Audio setFilter([WebAudioNode? filter]) {
    return setFilters(filter != null ? [filter] : []);
  }

  /// Sets the playback rate.
  ///
  /// Can only be used with compatible audio sources that allow playback control; otherwise warns and
  /// returns `null`.
  Audio? setPlaybackRate(double value) {
    if (hasPlaybackControl == false) {
      warn('Audio: this Audio has no playback control.');
      return null;
    }

    playbackRate = value;

    if (isPlaying == true) {
      (source as WebAudioBufferSourceNode).playbackRate.setTargetAtTime(playbackRate, context.currentTime, 0.01);
    }

    return this;
  }

  /// Returns the current playback rate.
  double getPlaybackRate() {
    return playbackRate;
  }

  /// Automatically called when playback finished.
  void onEnded() {
    isPlaying = false;
    _progress = 0;
  }

  /// Returns the loop flag.
  ///
  /// Can only be used with compatible audio sources that allow playback control; otherwise warns and
  /// returns `false`.
  bool getLoop() {
    if (hasPlaybackControl == false) {
      warn('Audio: this Audio has no playback control.');
      return false;
    }

    return loop;
  }

  /// Sets the loop flag.
  ///
  /// Can only be used with compatible audio sources that allow playback control; otherwise warns and
  /// returns `null`.
  Audio? setLoop(bool value) {
    if (hasPlaybackControl == false) {
      warn('Audio: this Audio has no playback control.');
      return null;
    }

    loop = value;

    if (isPlaying == true) {
      (source as WebAudioBufferSourceNode).loop = loop;
    }

    return this;
  }

  /// Sets the loop start value which defines where in the audio buffer the replay should start, in seconds.
  Audio setLoopStart(double value) {
    loopStart = value;

    return this;
  }

  /// Sets the loop end value which defines where in the audio buffer the replay should stop, in seconds.
  Audio setLoopEnd(double value) {
    loopEnd = value;

    return this;
  }

  /// Returns the volume.
  double getVolume() {
    return gain.gain.value;
  }

  /// Sets the volume.
  Audio setVolume(double value) {
    gain.gain.setTargetAtTime(value, context.currentTime, 0.01);

    return this;
  }

  @override
  Audio copy(covariant Audio source, [bool recursive = true]) {
    super.copy(source, recursive);

    if (source.sourceType != 'buffer') {
      warn('Audio: Audio source type cannot be copied.');

      return this;
    }

    autoplay = source.autoplay;

    buffer = source.buffer;
    detune = source.detune;
    loop = source.loop;
    loopStart = source.loopStart;
    loopEnd = source.loopEnd;
    offset = source.offset;
    duration = source.duration;
    playbackRate = source.playbackRate;
    hasPlaybackControl = source.hasPlaybackControl;
    sourceType = source.sourceType;

    filters = source.filters.toList();

    return this;
  }

  /// Returns a new audio for the same listener with copied values from this instance. The reference builds
  /// `new this.constructor( this.listener )`; Dart subclasses override this method (E-CLONE).
  @override
  Audio clone([bool recursive = true]) {
    return Audio(listener).copy(this, recursive);
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'listener' => listener,
      'context' => context,
      'gain' => gain,
      'autoplay' => autoplay,
      'buffer' => buffer,
      'detune' => detune,
      'loop' => loop,
      'loopStart' => loopStart,
      'loopEnd' => loopEnd,
      'offset' => offset,
      'duration' => duration,
      'playbackRate' => playbackRate,
      'isPlaying' => isPlaying,
      'hasPlaybackControl' => hasPlaybackControl,
      'source' => source,
      'sourceType' => sourceType,
      'filters' => filters,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'autoplay':
        autoplay = value as bool;
      case 'buffer':
        buffer = value as WebAudioBuffer?;
      case 'detune':
        detune = _jsDouble(value);
      case 'loop':
        loop = value as bool;
      case 'loopStart':
        loopStart = _jsDouble(value);
      case 'loopEnd':
        loopEnd = _jsDouble(value);
      case 'offset':
        offset = _jsDouble(value);
      case 'duration':
        duration = _jsDoubleOrNull(value);
      case 'playbackRate':
        playbackRate = _jsDouble(value);
      case 'isPlaying':
        isPlaying = value as bool;
      case 'hasPlaybackControl':
        hasPlaybackControl = value as bool;
      case 'source':
        source = value as WebAudioNode?;
      case 'sourceType':
        sourceType = value as String;
      case 'filters':
        filters = value is List<WebAudioNode> ? value : (value as List).cast<WebAudioNode>();
      default:
        super[key] = value;
    }
  }
}
