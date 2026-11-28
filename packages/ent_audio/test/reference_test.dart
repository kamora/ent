// Renders the scenarios of fixtures/audio/*.json and compares them with Chrome's rendering of the same graphs
// (tool/reference/audio/render.mjs): the output sample for sample, the sources that ended and the values read.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ent_audio/ent_audio.dart';
import 'package:test/test.dart';

final _root = '../../fixtures/audio';

/// Sample i of channel c of a scenario's buffer, as render.mjs fills it.
double signal(int c, int i) => ((i * 7919 + c * 104729) % 2003) / 1001.5 - 1;

/// Renders [scenario] and returns its channels, the sources that ended and the parameter values it read.
Future<(List<Float32List>, Set<String>, List<double>)> run(
  Map<String, dynamic> doc,
  Map<String, dynamic> scenario,
) async {
  final rate = doc['rate'] as int;
  final context = NativeAudioContext.offline(sampleRate: rate, channels: doc['channels'] as int);

  double time(Object? frames) => (frames as num) / rate;
  final buffers = <String, AudioData>{};
  final nodes = <String, AudioNode>{};
  final ended = <String>{};
  final values = <double>[];

  for (final MapEntry(:key, :value) in (scenario['buffers'] as Map<String, dynamic>).entries) {
    final b = value as Map<String, dynamic>;
    final buffer = context.createBuffer(b['channels'] as int, b['length'] as int, b['rate'] as int);

    for (var c = 0; c < buffer.channels; c++) {
      final data = buffer.getChannelData(c);

      for (var i = 0; i < buffer.length; i++) {
        data[i] = (b['fill'] as num?)?.toDouble() ?? signal(c, i);
      }
    }

    buffers[key] = buffer;
  }

  AudioParam param(Object? node, Object? name) {
    return switch ((node, name)) {
      (AudioPanner node, 'positionX') => node.positionX,
      (AudioPanner node, 'positionY') => node.positionY,
      (AudioPanner node, 'positionZ') => node.positionZ,
      (AudioPanner node, 'orientationX') => node.orientationX,
      (AudioPanner node, 'orientationY') => node.orientationY,
      (AudioPanner node, 'orientationZ') => node.orientationZ,
      (NativeAudioListener node, 'positionX') => node.positionX,
      (NativeAudioListener node, 'positionY') => node.positionY,
      (NativeAudioListener node, 'positionZ') => node.positionZ,
      (NativeAudioListener node, 'forwardX') => node.forwardX,
      (NativeAudioListener node, 'forwardY') => node.forwardY,
      (NativeAudioListener node, 'forwardZ') => node.forwardZ,
      (NativeAudioListener node, 'upX') => node.upX,
      (NativeAudioListener node, 'upY') => node.upY,
      (NativeAudioListener node, 'upZ') => node.upZ,
      (AudioGain node, 'gain') => node.gain,
      (AudioBufferSource node, 'playbackRate') => node.playbackRate,
      (AudioBufferSource node, 'detune') => node.detune,
      _ => throw ArgumentError('no parameter $name'),
    };
  }

  final channels = <Float32List>[for (var c = 0; c < context.channels; c++) Float32List(scenario['frames'] as int)];
  var rendered = 0;

  void render(int to) {
    final out = context.render(to - rendered);

    for (var c = 0; c < channels.length; c++) {
      channels[c].setAll(rendered, out[c]);
    }

    rendered = to;
  }

  for (final op in (scenario['ops'] as List).cast<List<dynamic>>()) {
    if (op[0] == 'at') {
      render(op[1] as int);
      continue;
    }

    final name = op[1] as String;
    final args = op.sublist(2);
    final Object? node = name == 'listener' ? context.listener : nodes[name];
    final source = node is AudioBufferSource ? node : null;

    switch (op[0]) {
      case 'source':
        final source = context.createBufferSource();

        if (args[0] != null) {
          source.buffer = buffers[args[0]];
        }

        source.onended = () => ended.add(name);
        nodes[name] = source;
      case 'gain':
        nodes[name] = context.createGain();
      case 'panner':
        nodes[name] = context.createPanner();
      case 'attr':
        final panner = node! as AudioPanner;
        final value = args[1];

        switch (args[0]) {
          case 'distanceModel':
            panner.distanceModel = value as String;
          case 'refDistance':
            panner.refDistance = (value as num).toDouble();
          case 'maxDistance':
            panner.maxDistance = (value as num).toDouble();
          case 'rolloffFactor':
            panner.rolloffFactor = (value as num).toDouble();
          case 'coneInnerAngle':
            panner.coneInnerAngle = (value as num).toDouble();
          case 'coneOuterAngle':
            panner.coneOuterAngle = (value as num).toDouble();
          case 'coneOuterGain':
            panner.coneOuterGain = (value as num).toDouble();
        }
      case 'set':
        switch (args[0]) {
          case 'loop':
            source!.loop = args[1] as bool;
          case 'loopStart':
            source!.loopStart = time(args[1]);
          case 'loopEnd':
            source!.loopEnd = time(args[1]);
        }
      case 'param':
        param(node, args[0]).value = (args[1] as num).toDouble();
      case 'ramp':
        param(node, args[0]).linearRampToValueAtTime((args[1] as num).toDouble(), time(args[2]));
      case 'target':
        param(node, args[0]).setTargetAtTime((args[1] as num).toDouble(), time(args[2]), time(args[3]));
      case 'read':
        values.add(param(node, args[0]).value);
      case 'connect':
        (node! as AudioNode).connect(args.isEmpty ? context.destination : nodes[args[0]]!);
      case 'start':
        final times = args.map(time).toList();

        switch (times.length) {
          case 0:
            source!.start();
          case 1:
            source!.start(times[0]);
          case 2:
            source!.start(times[0], times[1]);
          default:
            source!.start(times[0], times[1], times[2]);
        }
      case 'stop':
        source!.stop(time(args[0]));
    }
  }

  render(scenario['frames'] as int);

  await Future<void>.delayed(Duration.zero);
  context.close();

  return (channels, ended, values);
}

void main() {
  for (final file in ['sources', 'params', 'panner']) {
    group(file, () {
      compare(file);
    });
  }
}

/// One test per scenario of fixtures/audio/[file].json.
void compare(String file) {
  final doc = jsonDecode(File('$_root/$file.json').readAsStringSync()) as Map<String, dynamic>;
  final meta = jsonDecode(File('$_root/$file/meta.json').readAsStringSync()) as Map<String, dynamic>;

  for (final MapEntry(:key, :value) in (doc['scenarios'] as Map<String, dynamic>).entries) {
    test(key, () async {
      final scenario = value as Map<String, dynamic>;
      final frames = scenario['frames'] as int;
      final expected = File('$_root/$file/$key.f32').readAsBytesSync().buffer.asFloat32List();
      final (channels, ended, values) = await run(doc, scenario);
      var worst = 0.0;
      var at = '';

      for (var c = 0; c < channels.length; c++) {
        for (var i = 0; i < frames; i++) {
          final d = (channels[c][i] - expected[c * frames + i]).abs();

          if (d > worst) {
            worst = d;
            at = 'channel $c frame $i: ${channels[c][i]} vs ${expected[c * frames + i]}';
          }
        }
      }

      print('$key: worst $worst $at');
      expect(ended, (meta['ended'][key] as List).toSet());
      expect(values, meta['values'][key]);
      expect(worst, 0, reason: at);
    });
  }
}
