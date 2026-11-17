// A fake Web Audio platform that records every call in the format of the Node scenario that drove the reference audio
// classes through the same fake (see audio_test.dart).

import 'dart:typed_data';

import 'package:ent/ent.dart';

/// The call log shared by every fake node.
final List<String> audioLog = [];

final Map<String, int> _counts = {};

/// `gain1`, `gain2`, ...: node names numbered per kind, as the Node scenario numbers them.
String _id(String kind) {
  _counts[kind] = (_counts[kind] ?? 0) + 1;
  return '$kind${_counts[kind]}';
}

/// Resets the log and the node numbering.
void resetAudioLog() {
  audioLog.clear();
  _counts.clear();
}

/// A number as JavaScript prints it in a template string (`2` not `2.0`, `undefined` for `null`).
String js(num? v) {
  if (v == null) {
    return 'undefined';
  }

  if (v is double && v == v.truncateToDouble() && v.abs() < 1e21) {
    return v.toInt().toString();
  }

  return v.toString();
}

class FakeNode implements WebAudioNode {
  FakeNode(this.id);

  final String id;

  @override
  void connect(WebAudioNode destination) {
    audioLog.add('connect $id ${(destination as FakeNode).id}');
  }

  @override
  void disconnect([WebAudioNode? destination]) {
    audioLog.add('disconnect $id ${destination == null ? '' : (destination as FakeNode).id}');
  }
}

class FakeParam implements WebAudioParam {
  FakeParam(this.id);

  final String id;

  @override
  double value = 1;

  @override
  void setTargetAtTime(double target, double startTime, double timeConstant) {
    audioLog.add('$id.setTargetAtTime ${js(target)} ${js(startTime)} ${js(timeConstant)}');
  }

  @override
  void linearRampToValueAtTime(double value, double endTime) {
    audioLog.add('$id.ramp ${js(value)} ${js(endTime)}');
  }
}

class FakeGain extends FakeNode implements WebAudioGainNode {
  FakeGain(super.id) : gain = FakeParam('$id.gain');

  @override
  final WebAudioParam gain;
}

class FakeBuffer implements WebAudioBuffer {
  FakeBuffer(this.duration);

  @override
  final double duration;
}

class FakeSource extends FakeNode implements WebAudioBufferSourceNode {
  FakeSource(super.id) : detune = FakeParam('$id.detune'), playbackRate = FakeParam('$id.playbackRate');

  @override
  WebAudioBuffer? buffer;

  @override
  bool loop = false;

  @override
  double loopStart = 0;

  @override
  double loopEnd = 0;

  @override
  void Function()? onended;

  @override
  final WebAudioParam? detune;

  @override
  final WebAudioParam playbackRate;

  @override
  void start([double when = 0, double offset = 0, double? duration]) {
    audioLog.add('start $id ${js(when)} ${js(offset)} ${js(duration)}');
  }

  @override
  void stop([double? when]) {
    audioLog.add('stop $id ${js(when)}');
  }
}

class FakePanner extends FakeNode implements WebAudioPannerNode {
  FakePanner(super.id, bool params)
    : positionX = params ? FakeParam('$id.positionX') : null,
      positionY = params ? FakeParam('$id.positionY') : null,
      positionZ = params ? FakeParam('$id.positionZ') : null,
      orientationX = params ? FakeParam('$id.orientationX') : null,
      orientationY = params ? FakeParam('$id.orientationY') : null,
      orientationZ = params ? FakeParam('$id.orientationZ') : null;

  @override
  String panningModel = 'equalpower';

  @override
  String distanceModel = 'inverse';

  @override
  double refDistance = 1;

  @override
  double maxDistance = 10000;

  @override
  double rolloffFactor = 1;

  @override
  double coneInnerAngle = 360;

  @override
  double coneOuterAngle = 360;

  @override
  double coneOuterGain = 0;

  @override
  final WebAudioParam? positionX, positionY, positionZ, orientationX, orientationY, orientationZ;

  @override
  void setPosition(double x, double y, double z) {
    audioLog.add('$id.setPosition ${js(x)} ${js(y)} ${js(z)}');
  }

  @override
  void setOrientation(double x, double y, double z) {
    audioLog.add('$id.setOrientation ${js(x)} ${js(y)} ${js(z)}');
  }
}

class FakeAnalyser extends FakeNode implements WebAudioAnalyserNode {
  FakeAnalyser(super.id);

  @override
  int fftSize = 2048;

  @override
  int get frequencyBinCount => fftSize ~/ 2;

  @override
  void getByteFrequencyData(Uint8List array) {
    for (var i = 0; i < array.length; i++) {
      array[i] = (i * 37) % 256;
    }
  }
}

class FakeListener implements WebAudioListener {
  FakeListener(bool params)
    : positionX = params ? FakeParam('listener.positionX') : null,
      positionY = params ? FakeParam('listener.positionY') : null,
      positionZ = params ? FakeParam('listener.positionZ') : null,
      forwardX = params ? FakeParam('listener.forwardX') : null,
      forwardY = params ? FakeParam('listener.forwardY') : null,
      forwardZ = params ? FakeParam('listener.forwardZ') : null,
      upX = params ? FakeParam('listener.upX') : null,
      upY = params ? FakeParam('listener.upY') : null,
      upZ = params ? FakeParam('listener.upZ') : null;

  @override
  final WebAudioParam? positionX, positionY, positionZ, forwardX, forwardY, forwardZ, upX, upY, upZ;

  @override
  void setPosition(double x, double y, double z) {
    audioLog.add('listener.setPosition ${js(x)} ${js(y)} ${js(z)}');
  }

  @override
  void setOrientation(double x, double y, double z, double xUp, double yUp, double zUp) {
    audioLog.add('listener.setOrientation ${[x, y, z, xUp, yUp, zUp].map(js).join(' ')}');
  }
}

/// A fake context; [params] selects the `AudioParam` code paths (Chrome) over `setPosition`/`setOrientation`.
class FakeContext implements WebAudioContext {
  FakeContext({bool params = true}) : _params = params, listener = FakeListener(params);

  final bool _params;

  @override
  double currentTime = 0;

  @override
  final WebAudioNode destination = FakeNode('destination');

  @override
  final WebAudioListener listener;

  @override
  WebAudioGainNode createGain() => FakeGain(_id('gain'));

  @override
  WebAudioBufferSourceNode createBufferSource() => FakeSource(_id('source'));

  @override
  WebAudioPannerNode createPanner() => FakePanner(_id('panner'), _params);

  @override
  WebAudioAnalyserNode createAnalyser() => FakeAnalyser(_id('analyser'));

  @override
  WebAudioNode createMediaElementSource(Object mediaElement) => FakeNode(_id('mediaElement'));

  @override
  WebAudioNode createMediaStreamSource(Object mediaStream) => FakeNode(_id('mediaStream'));
}
