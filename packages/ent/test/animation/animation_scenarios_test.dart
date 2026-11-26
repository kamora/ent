// Replays the animation scenarios of tool/reference/js/animation_scenarios.mjs, which ran the same operations on the
// reference source, and compares the sampled scene state after every mixer operation: object transforms and flags,
// action state, events and memory statistics.

import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/dispatch.dart';

const String _path = '../../fixtures/values/animation_scenarios.json';

final LibraryMirror _library = reflectClass(MathUtils).owner as LibraryMirror;

double _number(Object? v) {
  return switch (v) {
    'NaN' => double.nan,
    'Infinity' => double.infinity,
    '-Infinity' => double.negativeInfinity,
    '-0' => -0.0,
    num n => n.toDouble(),
    _ => throw StateError('not a number: $v'),
  };
}

bool _isNumber(Object? v) => v is num || v == 'NaN' || v == 'Infinity' || v == '-Infinity' || v == '-0';

/// Compares a Dart value with the reference JSON: numbers exactly or within 1e-9 relative, recursively.
void _compare(Object? actual, Object? expected, String at, List<String> errors) {
  if (_isNumber(expected) && (actual is num)) {
    final a = actual.toDouble();
    final e = _number(expected);

    if (a == e || (a.isNaN && e.isNaN)) {
      return;
    }

    final scale = [1.0, a.abs(), e.abs()].reduce((x, y) => x > y ? x : y);

    if ((a - e).abs() > 1e-9 * scale) {
      errors.add('$at: expected $e, got $a');
    }

    return;
  }

  if (expected is List) {
    if (actual is! List || actual.length != expected.length) {
      errors.add('$at: expected $expected, got $actual');
      return;
    }

    for (var i = 0; i < expected.length; i++) {
      _compare(actual[i], expected[i], '$at[$i]', errors);
    }

    return;
  }

  if (expected is Map) {
    if (actual is! Map) {
      errors.add('$at: expected $expected, got $actual');
      return;
    }

    for (final key in expected.keys) {
      _compare(actual[key], expected[key], '$at.$key', errors);
    }

    return;
  }

  if (actual != expected) {
    errors.add('$at: expected $expected, got $actual');
  }
}

KeyframeTrack _track(Map<String, Object?> t) {
  final name = t['name'] as String;
  final times = t['times'] as List<Object?>;
  final values = t['values'] as List<Object?>;
  final interpolation = t['interpolation'] as int?;

  final track = switch (t['type']) {
    'Vector' => VectorKeyframeTrack(name, times, values, interpolation),
    'Quaternion' => QuaternionKeyframeTrack(name, times, values, interpolation),
    'Number' => NumberKeyframeTrack(name, times, values, interpolation),
    'Color' => ColorKeyframeTrack(name, times, values, interpolation),
    'Boolean' => BooleanKeyframeTrack(name, times, values),
    'String' => StringKeyframeTrack(name, times, values),
    _ => throw StateError('track type ${t['type']}'),
  };

  final settings = t['settings'] as Map<String, Object?>?;

  if (settings != null) {
    List<double> floats(Object? list) => Float32List.fromList([for (final v in list as List) _number(v)]);
    track.settings = {'inTangents': floats(settings['inTangents']), 'outTangents': floats(settings['outTangents'])};
  }

  return track;
}

Map<String, Object?> _objectState(Object3D o) {
  return {
    'position': o.position.toArray(),
    'quaternion': o.quaternion.toArray(),
    'rotation': [o.rotation.x, o.rotation.y, o.rotation.z],
    'scale': o.scale.toArray(),
    'visible': o.visible,
    'type': o.type,
  };
}

Map<String, Object?> _actionState(AnimationAction a) {
  return {
    'time': a.time,
    'timeScale': a.timeScale,
    'weight': a.weight,
    'effectiveWeight': a.getEffectiveWeight(),
    'effectiveTimeScale': a.getEffectiveTimeScale(),
    'enabled': a.enabled,
    'paused': a.paused,
    'loopCount': reflect(a).getField(MirrorSystem.getSymbol('_loopCount', _library)).reflectee,
    'running': a.isRunning(),
    'scheduled': a.isScheduled(),
  };
}

void _scenario(Map<String, Object?> scenario) {
  final errors = <String>[];

  final root = Object3D()..name = 'root';
  final child = Object3D()..name = 'child';
  final leaf = Object3D()..name = 'leaf';
  root.add(child);
  child.add(leaf);
  final extra = [for (var i = 0; i < 3; i++) Object3D()..name = 'extra$i'];

  final objects = {
    'root': root,
    'child': child,
    'leaf': leaf,
    'extra0': extra[0],
    'extra1': extra[1],
    'extra2': extra[2],
  };
  final group = scenario['group'] == true ? AnimationObjectGroup(extra) : null;
  final mixer = AnimationMixer(group ?? root);
  final tracks = <String, KeyframeTrack>{};
  final clips = <String, AnimationClip>{};
  final actions = <String, AnimationAction>{};
  final events = <List<Object?>>[];
  final snapshots = <Map<String, Object?>>[];
  final throwsLog = <bool>[];

  for (final t in (scenario['tracks'] as List).cast<Map<String, Object?>>()) {
    tracks[t['id'] as String] = _track(t);
  }

  for (final c in (scenario['clips'] as List).cast<Map<String, Object?>>()) {
    clips[c['id'] as String] = AnimationClip(c['name'] as String, (c['duration'] as num?)?.toDouble() ?? -1, [
      for (final id in c['tracks'] as List) tracks[id]!,
    ], c['blendMode'] as int? ?? NormalAnimationBlendMode);
  }

  String? actionId(Object? action) => actions.entries.where((e) => identical(e.value, action)).firstOrNull?.key;

  mixer.addEventListener('finished', (e) => events.add(['finished', actionId(e['action']), e['direction']]));
  mixer.addEventListener('loop', (e) => events.add(['loop', actionId(e['action']), e['loopDelta']]));

  Object? arg(Object? a) {
    if (a is Map) {
      return a.containsKey('action') ? actions[a['action']] : a['int'];
    }

    return a is num ? a.toDouble() : a;
  }

  void snapshot() {
    snapshots.add({
      'mixerTime': mixer.time,
      'objects': {for (final e in objects.entries) e.key: _objectState(e.value)},
      'actions': {for (final e in actions.entries) e.key: _actionState(e.value)},
      'events': [...events],
      'stats': [
        mixer.stats.actions.total,
        mixer.stats.actions.inUse,
        mixer.stats.bindings.total,
        mixer.stats.bindings.inUse,
        mixer.stats.controlInterpolants.total,
        mixer.stats.controlInterpolants.inUse,
      ],
    });
    events.clear();
  }

  for (final op in (scenario['ops'] as List).cast<List<Object?>>()) {
    final kind = op[0];
    final rest = op.sublist(1);

    switch (kind) {
      case 'action':
        final rootName = rest.length > 2 ? rest[2] as String? : null;
        actions[rest[0] as String] = mixer.clipAction(
          clips[rest[1]]!,
          rootName == null ? null : objects[rootName],
          rest.length > 3 ? rest[3] as int? : null,
        )!;
      case 'call':
        invoke(actions[rest[0]]!, rest[1] as String, rest.sublist(2).map(arg).toList());
      case 'throws':
        var threw = false;

        try {
          invoke(actions[rest[0]]!, rest[1] as String, rest.sublist(2).map(arg).toList());
        } catch (_) {
          threw = true;
        }

        throwsLog.add(threw);
      case 'set':
        setField(actions[rest[0]]!, rest[1] as String, arg(rest[2]));
      case 'mixer':
        final method = rest[0] as String;
        final args = rest.sublist(1).map((a) => method.startsWith('uncache') ? clips[a] ?? objects[a] : arg(a));
        invoke(mixer, method, args.toList());
        snapshot();
      case 'mixerSet':
        setField(mixer, rest[0] as String, arg(rest[1]));
      case 'clip':
        invoke(clips[rest[0]]!, rest[1] as String, rest.sublist(2).map(arg).toList());
      case 'additive':
        final referenceClip = rest[2] == null ? null : clips[rest[2]];
        AnimationUtils.makeClipAdditive(
          clips[rest[0]]!,
          (rest[1] as num).toDouble(),
          referenceClip,
          (rest[3] as num).toDouble(),
        );
      case 'subclip':
        clips[rest[0] as String] = AnimationUtils.subclip(
          clips[rest[1]]!,
          rest[2] as String,
          (rest[3] as num).toDouble(),
          (rest[4] as num).toDouble(),
          (rest[5] as num).toDouble(),
        );
      case 'group':
        final targets = [for (final n in rest.sublist(1)) objects[n]!];

        if (rest[0] == 'add') {
          group!.add(targets);
        } else {
          group!.remove(targets);
        }
      default:
        throw StateError('unknown op $kind');
    }
  }

  _compare(snapshots, scenario['snapshots'], 'snapshots', errors);
  _compare(throwsLog, scenario['throws'], 'throws', errors);

  final clipData = {
    for (final e in clips.entries)
      e.key: {
        'duration': e.value.duration,
        'blendMode': e.value.blendMode,
        'tracks': [
          for (final t in e.value.tracks)
            {'name': t.name, 'times': t.times, 'values': t.values, 'interpolation': t.getInterpolation()},
        ],
      },
  };

  _compare(clipData, scenario['clipData'], 'clipData', errors);

  expect(errors, isEmpty, reason: errors.take(15).join('\n'));
}

Map<String, Object?> _clipData(AnimationClip c) {
  return {
    'name': c.name,
    'duration': c.duration,
    'tracks': [
      for (final t in c.tracks) {'name': t.name, 'type': t.ValueTypeName, 'times': t.times, 'values': t.values},
    ],
  };
}

void main() {
  final fixture = jsonDecode(File(_path).readAsStringSync()) as Map<String, Object?>;

  group('Animation scenarios (reference)', () {
    for (final scenario in (fixture['scenarios'] as List).cast<Map<String, Object?>>()) {
      test(scenario['name'] as String, () => _scenario(scenario));
    }
  });

  group('Animation data (reference)', () {
    final data = fixture['data'] as Map<String, Object?>;
    final morph = [
      for (final name in ['Walk_001', 'Walk_002', 'Run_001', 'Run_002', 'Run_003', 'crdeath0059']) {'name': name},
    ];

    void check(Object? actual, Object? expected) {
      final errors = <String>[];
      _compare(actual, expected, 'value', errors);
      expect(errors, isEmpty, reason: errors.take(15).join('\n'));
    }

    test('CreateFromMorphTargetSequence', () {
      check(
        _clipData(AnimationClip.CreateFromMorphTargetSequence('seq', morph.sublist(0, 3), 10)),
        data['morphSequence'],
      );
      check(
        _clipData(AnimationClip.CreateFromMorphTargetSequence('seq', morph.sublist(0, 3), 10, true)),
        data['morphSequenceNoLoop'],
      );
    });

    test('CreateClipsFromMorphTargetSequences', () {
      check(AnimationClip.CreateClipsFromMorphTargetSequences(morph, 24).map(_clipData).toList(), data['morphClips']);
    });

    test('toJSON', () {
      final clip = AnimationClip('j', -1, [
        VectorKeyframeTrack('.position', [0, 1], [1, 2, 3, 4, 5, 6], InterpolateSmooth),
        StringKeyframeTrack('.name', [0, 2], ['a', 'b']),
        NumberKeyframeTrack('.opacity', [0, 3], [0, 1]),
      ]);
      clip.tracks[2].setInterpolation(InterpolateBezier);
      clip.tracks[2].settings = {
        'inTangents': Float32List.fromList([-1, 0, 2, 1]),
        'outTangents': Float32List.fromList([1, 0, 4, 1]),
      };
      clip.userData = {'tag': 'x', 'n': 2.5};

      final json = clip.toJSON()..remove('uuid');
      final expected = data['clipJSON'] as Map<String, Object?>;

      check(json..remove('userData'), {...expected}..remove('userData'));

      // JSON.stringify writes 2.5 as "2.5", like jsonEncode; both decode to the same map.
      expect(jsonDecode(clip.toJSON()['userData'] as String), jsonDecode(expected['userData'] as String));
    });

    test('parse', () {
      final parsed = AnimationClip.parse({
        'name': 'p',
        'fps': 10,
        'uuid': 'fixed-uuid',
        'userData': '{"a":1}',
        'tracks': [
          {
            'name': '.position',
            'type': 'vector3',
            'times': [0, 10],
            'values': [0, 0, 0, 1, 1, 1],
          },
          {
            'name': '.visible',
            'type': 'boolean',
            'keys': [
              {'time': 0, 'value': true},
              {'time': 5},
              {'time': 10, 'value': false},
            ],
          },
          {
            'name': '.quaternion',
            'type': 'quaternion',
            'keys': [
              {
                'time': 0,
                'value': [0, 0, 0, 1],
              },
              {
                'time': 20,
                'value': [0, 1, 0, 0],
              },
            ],
            'interpolation': InterpolateDiscrete,
          },
          {
            'name': '.scale[x]',
            'type': 'number',
            'times': [0, 10],
            'values': [1, 2],
            'interpolation': InterpolateBezier,
            'settings': {
              'inTangents': [0, 1, 5, 2],
              'outTangents': [5, 1, 10, 2],
            },
          },
        ],
      });

      check({
        ..._clipData(parsed),
        'uuid': parsed.uuid,
        'userData': parsed.userData,
        'interpolations': [for (final t in parsed.tracks) t.getInterpolation()],
        'tangents': parsed.tracks[3].settings!['inTangents'],
      }, data['parsed']);
    });

    test('validate', () {
      final messages = <String>[];
      setConsoleFunction((type, message, params) => messages.add('$type: $message'));
      addTearDown(() => setConsoleFunction(null));

      check([
        NumberKeyframeTrack('a', [0, 1], [0, 1]).validate(),
        NumberKeyframeTrack('b', [1, 0], [0, 1]).validate(),
        NumberKeyframeTrack('c', [0, double.nan], [0, 1]).validate(),
        VectorKeyframeTrack('d', [0, 1], [0, 1, 2]).validate(),
        NumberKeyframeTrack('e', [0, 1], [0, double.nan]).validate(),
      ], data['validation']);

      check(messages, (data['warnings'] as List).sublist(0, 4));
    });

    test('getInterpolation/setInterpolation', () {
      final messages = <String>[];
      setConsoleFunction((type, message, params) => messages.add('$type: $message'));
      addTearDown(() => setConsoleFunction(null));

      check([
        NumberKeyframeTrack('a', [0], [0]).getInterpolation(),
        QuaternionKeyframeTrack('b', [0], [0, 0, 0, 1], InterpolateSmooth).getInterpolation(),
        StringKeyframeTrack('c', [0], ['x']).setInterpolation(InterpolateLinear).getInterpolation(),
        BooleanKeyframeTrack('d', [0], [true]).setInterpolation(InterpolateBezier).getInterpolation(),
        NumberKeyframeTrack('e', [0], [0]).setInterpolation(9999).getInterpolation(),
      ], data['interpolations']);

      check(messages, (data['warnings'] as List).sublist(4));
    });

    test('trim', () {
      check([
        for (final range in [
          [0.5, 2.5],
          [3.0, 4.0],
          [-2.0, -1.0],
          [1.0, 1.0],
        ])
          () {
            final t = VectorKeyframeTrack('t', [0, 1, 2, 3], [0, 0, 1, 1, 2, 2, 3, 3]).trim(range[0], range[1]);
            return [t.times, t.values];
          }(),
      ], data['trimmed']);
    });

    test('flattenJSON', () {
      final times = <Object?>[];
      final values = <Object?>[];

      AnimationUtils.flattenJSON(
        [
          {'time': 0},
          {'time': 1, 'value': Vector3(1, 2, 3)},
          {'time': 2},
          {'time': 3, 'value': Vector3(4, 5, 6)},
        ],
        times,
        values,
        'value',
      );

      check([times, values], data['flatten']);
    });

    test('getKeyframeOrder/sortedArray', () {
      final order = AnimationUtils.getKeyframeOrder([3, 1, 2, 1, 0]);
      check(order, data['order']);
      check(
        AnimationUtils.sortedArray(Float32List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]), 2, order),
        data['sorted'],
      );
    });
  });
}
