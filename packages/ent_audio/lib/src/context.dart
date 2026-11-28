import 'dart:ffi';
import 'dart:typed_data';

import 'package:ent/ent.dart';
import 'package:ffi/ffi.dart';

import 'bindings.dart' as native;
import 'buffer.dart';

/// A Web Audio context on ent_audio's native graph.
///
/// [NativeAudioContext.offline] renders on demand with [render] instead of playing on a device.
final class NativeAudioContext implements WebAudioContext, WebAudioDecodingContext, Finalizable {
  /// A context that renders [channels] channels at [sampleRate] frames per second only when [render] asks.
  NativeAudioContext.offline({this.sampleRate = 48000, this.channels = 2}) {
    _ended = NativeCallable<Void Function(Int32)>.listener(_end)..keepIsolateAlive = false;
    pointer = native.contextCreate(sampleRate, channels, _ended.nativeFunction);

    if (pointer == nullptr) {
      _ended.close();
      throw StateError('ENT.NativeAudioContext: out of memory.');
    }

    _finalizer.attach(this, pointer.cast(), detach: this);
    destination = AudioNode._(this, native.contextDestination(pointer), held: false);
    listener = NativeAudioListener._(AudioNode._(this, native.contextListener(pointer), held: false));
  }

  static final _finalizer = NativeFinalizer(native.contextRelease);

  /// The frames per second.
  final int sampleRate;

  /// The number of output channels.
  final int channels;

  /// The native context.
  late final Pointer<native.Context> pointer;

  late final NativeCallable<Void Function(Int32)> _ended;

  /// The sources started and not ended yet, by id: held here so that they play to their end.
  final Map<int, AudioBufferSource> _playing = {};

  bool _closed = false;

  @override
  late final AudioNode destination;

  @override
  double get currentTime => native.contextTime(pointer);

  @override
  late final NativeAudioListener listener;

  /// A silent buffer, as Web Audio's `createBuffer`.
  AudioData createBuffer(int channels, int length, int sampleRate) {
    return AudioData(channels, length, sampleRate);
  }

  @override
  AudioBufferSource createBufferSource() {
    return AudioBufferSource._(this);
  }

  @override
  AudioGain createGain() {
    return AudioGain._(this);
  }

  @override
  AudioPanner createPanner() {
    return AudioPanner._(this);
  }

  @override
  AudioAnalyserNode createAnalyser() {
    return AudioAnalyserNode._(this);
  }

  @override
  WebAudioNode createMediaElementSource(Object mediaElement) {
    throw UnsupportedError('ENT.NativeAudioContext: there are no media elements outside a browser.');
  }

  @override
  WebAudioNode createMediaStreamSource(Object mediaStream) {
    throw UnsupportedError('ENT.NativeAudioContext: there are no media streams outside a browser.');
  }

  /// Decodes WAV, FLAC or MP3 [data] at the context's rate.
  @override
  Future<AudioData> decodeAudioData(ByteBuffer data) async {
    return AudioData.decode(data.asUint8List(), sampleRate);
  }

  /// Renders the next [frames] frames, rounded up to whole quanta of 128, and returns each channel's first [frames].
  /// Sources that end meanwhile call their `onended` once the caller yields to the event loop.
  List<Float32List> render(int frames) {
    final quanta = (frames + 127) ~/ 128;

    return using((arena) {
      final out = arena<Float>(quanta * 128 * channels);
      native.contextRender(pointer, out, quanta);

      final all = out.asTypedList(quanta * 128 * channels);
      return [for (var c = 0; c < channels; c++) all.sublist(c * quanta * 128, c * quanta * 128 + frames)];
    });
  }

  /// Releases the native context; the context cannot be used afterwards.
  void close() {
    if (_closed) {
      return;
    }

    _closed = true;
    _finalizer.detach(this);
    native.contextRelease.asFunction<void Function(Pointer<Void>)>()(pointer.cast());
    _ended.close();
    _playing.clear();
  }

  void _end(int id) {
    final source = _playing.remove(id);

    if (source != null) {
      source.onended?.call();
    }
  }
}

/// A node of a [NativeAudioContext]'s graph.
class AudioNode implements WebAudioNode, Finalizable {
  AudioNode._(this.context, this.pointer, {bool held = true}) {
    if (held) {
      _finalizer.attach(this, pointer.cast());
    }
  }

  static final _finalizer = NativeFinalizer(native.nodeRelease);

  /// The context the node belongs to.
  final NativeAudioContext context;

  /// The native node.
  final Pointer<native.Node> pointer;

  @override
  void connect(WebAudioNode destination) {
    if (destination is! AudioNode || destination.context != context) {
      throw ArgumentError('ENT.AudioNode: the destination belongs to another context.');
    }

    if (native.nodeConnect(pointer, destination.pointer) != 0) {
      throw StateError('ENT.AudioNode: out of memory.');
    }
  }

  @override
  void disconnect([WebAudioNode? destination]) {
    if (destination == null) {
      native.nodeDisconnect(pointer, nullptr);
      return;
    }

    if (destination is! AudioNode || destination.context != context) {
      throw ArgumentError('ENT.AudioNode: the destination belongs to another context.');
    }

    native.nodeDisconnect(pointer, destination.pointer);
  }
}

/// A parameter of a node.
class AudioParam implements WebAudioParam {
  AudioParam._(this._node, this._index);

  final AudioNode _node;
  final int _index;

  @override
  double get value => native.paramGet(_node.pointer, _index);

  /// Sets the value now, which also schedules it at the current time, as Web Audio does.
  @override
  set value(double value) {
    _check(native.paramSet(_node.pointer, _index, value));
  }

  /// Approaches [target] from [startTime], by `1 - 1/e` of the remaining distance every [timeConstant] seconds.
  @override
  void setTargetAtTime(double target, double startTime, double timeConstant) {
    if (startTime < 0 || timeConstant < 0) {
      throw RangeError('ENT.AudioParam: setTargetAtTime() takes no negative time.');
    }

    _check(native.paramTarget(_node.pointer, _index, target, startTime, timeConstant));
  }

  /// Ramps linearly from the previous event to [value], reached at [endTime].
  @override
  void linearRampToValueAtTime(double value, double endTime) {
    if (endTime < 0) {
      throw RangeError('ENT.AudioParam: linearRampToValueAtTime() takes no negative time.');
    }

    _check(native.paramRamp(_node.pointer, _index, value, endTime));
  }

  /// `setValueAtTime( value, currentTime )`.
  void _at(double value) {
    _check(native.paramAt(_node.pointer, _index, value, _node.context.currentTime));
  }

  void _check(int result) {
    if (result != 0) {
      throw StateError('ENT.AudioParam: out of memory.');
    }
  }
}

/// A Web Audio `GainNode`.
class AudioGain extends AudioNode implements WebAudioGainNode {
  AudioGain._(NativeAudioContext context) : super._(context, native.gainCreate(context.pointer)) {
    gain = AudioParam._(this, 0);
  }

  @override
  late final AudioParam gain;
}

/// A Web Audio `AudioBufferSourceNode`.
class AudioBufferSource extends AudioNode implements WebAudioBufferSourceNode {
  AudioBufferSource._(NativeAudioContext context) : super._(context, native.sourceCreate(context.pointer)) {
    playbackRate = AudioParam._(this, 0);
    detune = AudioParam._(this, 1);
  }

  @override
  late final AudioParam playbackRate;

  @override
  late final AudioParam detune;

  @override
  void Function()? onended;

  AudioData? _buffer;
  bool _loop = false;
  double _loopStart = 0;
  double _loopEnd = 0;
  bool _started = false;

  @override
  AudioData? get buffer => _buffer;

  /// Web Audio lets a source's buffer be set only once.
  @override
  set buffer(WebAudioBuffer? value) {
    if (value == null) {
      if (_buffer != null) {
        throw StateError('ENT.AudioBufferSource: the buffer cannot be removed once set.');
      }

      return;
    }

    if (value is! AudioData) {
      throw ArgumentError('ENT.AudioBufferSource: the buffer is not an AudioData.');
    }

    if (_buffer != null) {
      throw StateError('ENT.AudioBufferSource: the buffer can be set only once.');
    }

    _buffer = value;
    native.sourceBuffer(pointer, value.pointer);
  }

  @override
  bool get loop => _loop;

  @override
  set loop(bool value) {
    _loop = value;
    _sendLoop();
  }

  @override
  double get loopStart => _loopStart;

  @override
  set loopStart(double value) {
    _loopStart = value;
    _sendLoop();
  }

  @override
  double get loopEnd => _loopEnd;

  @override
  set loopEnd(double value) {
    _loopEnd = value;
    _sendLoop();
  }

  void _sendLoop() {
    native.sourceLoop(pointer, _loop ? 1 : 0, _loopStart, _loopEnd);
  }

  @override
  void start([double when = 0, double offset = 0, double? duration]) {
    if (_started) {
      throw StateError('ENT.AudioBufferSource: start() can be called only once.');
    }

    if (when < 0 || offset < 0 || (duration != null && duration < 0)) {
      throw RangeError('ENT.AudioBufferSource: start() takes no negative time.');
    }

    _started = true;
    context._playing[native.nodeId(pointer)] = this;
    native.sourceStart(pointer, when, offset, duration ?? -1);
  }

  @override
  void stop([double? when]) {
    if (!_started) {
      throw StateError('ENT.AudioBufferSource: stop() needs start() first.');
    }

    if (when != null && when < 0) {
      throw RangeError('ENT.AudioBufferSource: stop() takes no negative time.');
    }

    native.sourceStop(pointer, when ?? 0);
  }
}

/// A Web Audio `AudioListener`: where the context's panners are heard from.
class NativeAudioListener implements WebAudioListener {
  NativeAudioListener._(AudioNode node)
    : positionX = AudioParam._(node, 0),
      positionY = AudioParam._(node, 1),
      positionZ = AudioParam._(node, 2),
      forwardX = AudioParam._(node, 3),
      forwardY = AudioParam._(node, 4),
      forwardZ = AudioParam._(node, 5),
      upX = AudioParam._(node, 6),
      upY = AudioParam._(node, 7),
      upZ = AudioParam._(node, 8);

  @override
  final AudioParam positionX;

  @override
  final AudioParam positionY;

  @override
  final AudioParam positionZ;

  @override
  final AudioParam forwardX;

  @override
  final AudioParam forwardY;

  @override
  final AudioParam forwardZ;

  @override
  final AudioParam upX;

  @override
  final AudioParam upY;

  @override
  final AudioParam upZ;

  /// Sets the position at the current time.
  @override
  void setPosition(double x, double y, double z) {
    positionX._at(x);
    positionY._at(y);
    positionZ._at(z);
  }

  /// Sets the forward and up directions at the current time.
  @override
  void setOrientation(double x, double y, double z, double xUp, double yUp, double zUp) {
    forwardX._at(x);
    forwardY._at(y);
    forwardZ._at(z);
    upX._at(xUp);
    upY._at(yUp);
    upZ._at(zUp);
  }
}

/// A Web Audio `PannerNode`, with the equal-power panning model.
///
/// [panningModel] keeps `'HRTF'` when set to it, but the node pans by equal power either way.
class AudioPanner extends AudioNode implements WebAudioPannerNode {
  AudioPanner._(NativeAudioContext context) : super._(context, native.pannerCreate(context.pointer)) {
    positionX = AudioParam._(this, 0);
    positionY = AudioParam._(this, 1);
    positionZ = AudioParam._(this, 2);
    orientationX = AudioParam._(this, 3);
    orientationY = AudioParam._(this, 4);
    orientationZ = AudioParam._(this, 5);
  }

  static const _models = ['linear', 'inverse', 'exponential'];

  @override
  late final AudioParam positionX;

  @override
  late final AudioParam positionY;

  @override
  late final AudioParam positionZ;

  @override
  late final AudioParam orientationX;

  @override
  late final AudioParam orientationY;

  @override
  late final AudioParam orientationZ;

  String _panningModel = 'equalpower';
  String _distanceModel = 'inverse';
  double _refDistance = 1;
  double _maxDistance = 10000;
  double _rolloffFactor = 1;
  double _coneInnerAngle = 360;
  double _coneOuterAngle = 360;
  double _coneOuterGain = 0;

  @override
  String get panningModel => _panningModel;

  @override
  set panningModel(String value) {
    if (value != 'equalpower' && value != 'HRTF') {
      throw ArgumentError.value(value, 'panningModel');
    }

    _panningModel = value;
  }

  @override
  String get distanceModel => _distanceModel;

  @override
  set distanceModel(String value) {
    if (!_models.contains(value)) {
      throw ArgumentError.value(value, 'distanceModel');
    }

    _distanceModel = value;
    _send();
  }

  @override
  double get refDistance => _refDistance;

  @override
  set refDistance(double value) {
    if (value < 0) {
      throw RangeError('ENT.AudioPanner: refDistance cannot be negative.');
    }

    _refDistance = value;
    _send();
  }

  @override
  double get maxDistance => _maxDistance;

  @override
  set maxDistance(double value) {
    if (value <= 0) {
      throw RangeError('ENT.AudioPanner: maxDistance must be positive.');
    }

    _maxDistance = value;
    _send();
  }

  @override
  double get rolloffFactor => _rolloffFactor;

  @override
  set rolloffFactor(double value) {
    if (value < 0) {
      throw RangeError('ENT.AudioPanner: rolloffFactor cannot be negative.');
    }

    _rolloffFactor = value;
    _send();
  }

  @override
  double get coneInnerAngle => _coneInnerAngle;

  @override
  set coneInnerAngle(double value) {
    _coneInnerAngle = value;
    _send();
  }

  @override
  double get coneOuterAngle => _coneOuterAngle;

  @override
  set coneOuterAngle(double value) {
    _coneOuterAngle = value;
    _send();
  }

  @override
  double get coneOuterGain => _coneOuterGain;

  @override
  set coneOuterGain(double value) {
    if (value < 0 || value > 1) {
      throw StateError('ENT.AudioPanner: coneOuterGain must be between 0 and 1.');
    }

    _coneOuterGain = value;
    _send();
  }

  void _send() {
    native.pannerSet(
      pointer,
      _models.indexOf(_distanceModel),
      _refDistance,
      _maxDistance,
      _rolloffFactor,
      _coneInnerAngle,
      _coneOuterAngle,
      _coneOuterGain,
    );
  }

  /// Sets the position at the current time.
  @override
  void setPosition(double x, double y, double z) {
    positionX._at(x);
    positionY._at(y);
    positionZ._at(z);
  }

  /// Sets the direction the source faces at the current time.
  @override
  void setOrientation(double x, double y, double z) {
    orientationX._at(x);
    orientationY._at(y);
    orientationZ._at(z);
  }
}

/// A Web Audio `AnalyserNode`: passes its input through and analyses its frequencies.
class AudioAnalyserNode extends AudioNode implements WebAudioAnalyserNode {
  AudioAnalyserNode._(NativeAudioContext context) : super._(context, native.analyserCreate(context.pointer));

  int _fftSize = 2048;
  double _smoothingTimeConstant = 0.8;
  double _minDecibels = -100;
  double _maxDecibels = -30;

  /// The FFT size: a power of two from 32 to 32768.
  @override
  int get fftSize => _fftSize;

  @override
  set fftSize(int value) {
    if (value < 32 || value > 32768 || value & (value - 1) != 0) {
      throw RangeError('ENT.AudioAnalyserNode: fftSize must be a power of two from 32 to 32768.');
    }

    _check(native.analyserSize(pointer, value));
    _fftSize = value;
  }

  @override
  int get frequencyBinCount => _fftSize ~/ 2;

  /// How much of the previous analysis each new one keeps, from 0 to 1.
  double get smoothingTimeConstant => _smoothingTimeConstant;

  set smoothingTimeConstant(double value) {
    if (value < 0 || value > 1) {
      throw RangeError('ENT.AudioAnalyserNode: smoothingTimeConstant must be between 0 and 1.');
    }

    _smoothingTimeConstant = value;
  }

  /// The decibels that [getByteFrequencyData] maps to 0.
  double get minDecibels => _minDecibels;

  set minDecibels(double value) {
    if (value >= _maxDecibels) {
      throw RangeError('ENT.AudioAnalyserNode: minDecibels must be below maxDecibels.');
    }

    _minDecibels = value;
  }

  /// The decibels that [getByteFrequencyData] maps to 255.
  double get maxDecibels => _maxDecibels;

  set maxDecibels(double value) {
    if (value <= _minDecibels) {
      throw RangeError('ENT.AudioAnalyserNode: maxDecibels must be above minDecibels.');
    }

    _maxDecibels = value;
  }

  /// Copies the magnitude of each frequency, scaled from [minDecibels] to [maxDecibels] into 0 to 255, into [array].
  @override
  void getByteFrequencyData(Uint8List array) {
    using((arena) {
      final out = arena<Uint8>(array.length);

      _check(native.analyserBytes(pointer, _smoothingTimeConstant, _minDecibels, _maxDecibels, out, array.length));
      array.setAll(0, out.asTypedList(array.length).take(frequencyBinCount));
    });
  }

  /// Copies the magnitude of each frequency in decibels into [array].
  void getFloatFrequencyData(Float32List array) {
    using((arena) {
      final out = arena<Float>(array.length);

      _check(native.analyserDecibels(pointer, _smoothingTimeConstant, out, array.length));
      array.setAll(0, out.asTypedList(array.length).take(frequencyBinCount));
    });
  }

  void _check(int result) {
    if (result != 0) {
      throw StateError('ENT.AudioAnalyserNode: out of memory.');
    }
  }
}
