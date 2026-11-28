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
  WebAudioListener get listener =>
      throw UnimplementedError('ENT.NativeAudioContext: the listener is not implemented yet.');

  /// A silent buffer, as Web Audio's `createBuffer`.
  AudioData createBuffer(int channels, int length, int sampleRate) {
    return AudioData(channels, length, sampleRate);
  }

  @override
  AudioBufferSource createBufferSource() {
    return AudioBufferSource._(this);
  }

  @override
  WebAudioGainNode createGain() {
    throw UnimplementedError('ENT.NativeAudioContext: gain nodes are not implemented yet.');
  }

  @override
  WebAudioPannerNode createPanner() {
    throw UnimplementedError('ENT.NativeAudioContext: panner nodes are not implemented yet.');
  }

  @override
  WebAudioAnalyserNode createAnalyser() {
    throw UnimplementedError('ENT.NativeAudioContext: analyser nodes are not implemented yet.');
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

  @override
  set value(double value) {
    native.paramSet(_node.pointer, _index, value);
  }

  @override
  void setTargetAtTime(double target, double startTime, double timeConstant) {
    throw UnimplementedError('ENT.AudioParam: automation is not implemented yet.');
  }

  @override
  void linearRampToValueAtTime(double value, double endTime) {
    throw UnimplementedError('ENT.AudioParam: automation is not implemented yet.');
  }
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
