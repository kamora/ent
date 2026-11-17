part of '../../ent.dart';

final _audioListenerPosition = Vector3();
final _audioListenerQuaternion = Quaternion();
final _audioListenerScale = Vector3();

final _audioListenerForward = Vector3();
final _audioListenerUp = Vector3();

/// The class represents a virtual listener of the all positional and non-positional audio effects in the scene. An
/// application usually creates a single listener. It is a mandatory constructor parameter for audios entities like
/// [Audio] and [PositionalAudio].
///
/// In most cases, the listener object is a child of the camera. So the 3D transformation of the camera
/// represents the 3D transformation of the listener.
class AudioListener extends Object3D {
  /// Constructs a new audio listener on the global context of [AudioContext.getContext].
  AudioListener() : context = AudioContext.getContext() {
    type = 'AudioListener';

    gain = context.createGain();
    gain.connect(context.destination);
  }

  /// The native audio context.
  final WebAudioContext context;

  /// The gain node used for volume control.
  late final WebAudioGainNode gain;

  /// An optional filter. Defined via [setFilter].
  WebAudioNode? filter;

  /// Time delta values required for `linearRampToValueAtTime()` usage.
  double timeDelta = 0;

  // private

  final Timer _timer = Timer();

  /// Returns the listener's input node.
  ///
  /// This method is used by other audio nodes to connect to this listener.
  WebAudioNode getInput() {
    return gain;
  }

  /// Removes the current filter from this listener.
  AudioListener removeFilter() {
    final filter = this.filter;

    if (filter != null) {
      gain.disconnect(filter);
      filter.disconnect(context.destination);
      gain.connect(context.destination);
      this.filter = null;
    }

    return this;
  }

  /// Returns the current set filter.
  WebAudioNode? getFilter() {
    return filter;
  }

  /// Sets the given filter to this listener.
  AudioListener setFilter(WebAudioNode value) {
    final filter = this.filter;

    if (filter != null) {
      gain.disconnect(filter);
      filter.disconnect(context.destination);
    } else {
      gain.disconnect(context.destination);
    }

    this.filter = value;
    gain.connect(value);
    value.connect(context.destination);

    return this;
  }

  /// Returns the applications master volume.
  double getMasterVolume() {
    return gain.gain.value;
  }

  /// Sets the applications master volume. This volume setting affects all audio nodes in the scene.
  AudioListener setMasterVolume(double value) {
    gain.gain.setTargetAtTime(value, context.currentTime, 0.01);

    return this;
  }

  @override
  void updateMatrixWorld([bool? force]) {
    super.updateMatrixWorld(force);

    _timer.update();

    final listener = context.listener;

    timeDelta = _timer.getDelta();

    matrixWorld.decompose(_audioListenerPosition, _audioListenerQuaternion, _audioListenerScale);

    // the initial forward and up directions must be orthogonal
    _audioListenerForward.set(0, 0, -1).applyQuaternion(_audioListenerQuaternion);
    _audioListenerUp.set(0, 1, 0).applyQuaternion(_audioListenerQuaternion);

    final positionX = listener.positionX;

    if (positionX != null) {
      // code path for Chrome (see #14393)

      final endTime = context.currentTime + timeDelta;

      positionX.linearRampToValueAtTime(_audioListenerPosition.x, endTime);
      listener.positionY!.linearRampToValueAtTime(_audioListenerPosition.y, endTime);
      listener.positionZ!.linearRampToValueAtTime(_audioListenerPosition.z, endTime);
      listener.forwardX!.linearRampToValueAtTime(_audioListenerForward.x, endTime);
      listener.forwardY!.linearRampToValueAtTime(_audioListenerForward.y, endTime);
      listener.forwardZ!.linearRampToValueAtTime(_audioListenerForward.z, endTime);
      listener.upX!.linearRampToValueAtTime(_audioListenerUp.x, endTime);
      listener.upY!.linearRampToValueAtTime(_audioListenerUp.y, endTime);
      listener.upZ!.linearRampToValueAtTime(_audioListenerUp.z, endTime);
    } else {
      listener.setPosition(_audioListenerPosition.x, _audioListenerPosition.y, _audioListenerPosition.z);
      listener.setOrientation(
        _audioListenerForward.x,
        _audioListenerForward.y,
        _audioListenerForward.z,
        _audioListenerUp.x,
        _audioListenerUp.y,
        _audioListenerUp.z,
      );
    }
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'context' => context,
      'gain' => gain,
      'filter' => filter,
      'timeDelta' => timeDelta,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'filter':
        filter = value as WebAudioNode?;
      case 'timeDelta':
        timeDelta = _jsDouble(value);
      default:
        super[key] = value;
    }
  }
}
