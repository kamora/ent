// Renders the scenarios of fixtures/audio/sources.json and compares them with Chrome's rendering of the same graphs
// (tool/reference/audio/render.mjs).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ent_audio/ent_audio.dart';
import 'package:test/test.dart';

final _root = '../../fixtures/audio';

/// Sample i of channel c of a scenario's buffer, as render.mjs fills it.
double signal(int c, int i) => ((i * 7919 + c * 104729) % 2003) / 1001.5 - 1;

/// Renders [scenario] and returns its channels and the sources that ended.
Future<(List<Float32List>, Set<String>)> run(Map<String, dynamic> doc, Map<String, dynamic> scenario) async {
  final rate = doc['rate'] as int;
  final context = NativeAudioContext.offline(sampleRate: rate, channels: doc['channels'] as int);

  double time(Object? frames) => (frames as num) / rate;
  final buffers = <String, AudioData>{};
  final nodes = <String, AudioBufferSource>{};
  final ended = <String>{};

  for (final MapEntry(:key, :value) in (scenario['buffers'] as Map<String, dynamic>).entries) {
    final b = value as Map<String, dynamic>;
    final buffer = context.createBuffer(b['channels'] as int, b['length'] as int, b['rate'] as int);

    for (var c = 0; c < buffer.channels; c++) {
      final data = buffer.getChannelData(c);

      for (var i = 0; i < buffer.length; i++) {
        data[i] = signal(c, i);
      }
    }

    buffers[key] = buffer;
  }

  for (final op in (scenario['ops'] as List).cast<List<dynamic>>()) {
    final name = op[1] as String;
    final args = op.sublist(2);
    final node = nodes[name];

    switch (op[0]) {
      case 'source':
        final source = context.createBufferSource();

        if (args[0] != null) {
          source.buffer = buffers[args[0]];
        }

        source.onended = () => ended.add(name);
        nodes[name] = source;
      case 'set':
        switch (args[0]) {
          case 'loop':
            node!.loop = args[1] as bool;
          case 'loopStart':
            node!.loopStart = time(args[1]);
          case 'loopEnd':
            node!.loopEnd = time(args[1]);
        }
      case 'param':
        (args[0] == 'playbackRate' ? node!.playbackRate : node!.detune).value = (args[1] as num).toDouble();
      case 'connect':
        node!.connect(context.destination);
      case 'start':
        final times = args.map(time).toList();

        switch (times.length) {
          case 0:
            node!.start();
          case 1:
            node!.start(times[0]);
          case 2:
            node!.start(times[0], times[1]);
          default:
            node!.start(times[0], times[1], times[2]);
        }
      case 'stop':
        node!.stop(time(args[0]));
    }
  }

  final channels = context.render(scenario['frames'] as int);

  await Future<void>.delayed(Duration.zero);
  context.close();

  return (channels, ended);
}

void main() {
  final doc = jsonDecode(File('$_root/sources.json').readAsStringSync()) as Map<String, dynamic>;
  final meta = jsonDecode(File('$_root/sources/meta.json').readAsStringSync()) as Map<String, dynamic>;

  for (final MapEntry(:key, :value) in (doc['scenarios'] as Map<String, dynamic>).entries) {
    test(key, () async {
      final scenario = value as Map<String, dynamic>;
      final frames = scenario['frames'] as int;
      final expected = File('$_root/sources/$key.f32').readAsBytesSync().buffer.asFloat32List();
      final (channels, ended) = await run(doc, scenario);
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
      expect(worst, 0, reason: at);
    });
  }
}
