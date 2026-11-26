// Replays reference fixtures written by tool/reference/js/generate.mjs against the Dart port. Each case calls the
// method by its reference name through dispatch.dart, so a renamed or missing method fails here the same way a wrong
// result does.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'codecs.dart';
import 'dispatch.dart';
import 'library.g.dart';

/// Rebuilds a value type from its fixture state and reads that state back.
class Codec {
  const Codec(this.decode, this.encode, {this.list});

  /// Builds an instance from the decoded state list (numbers are `double`, strings stay strings).
  final Object Function(List<Object?> state) decode;

  /// Reads the state list of an instance, in the layout of tool/reference/js/types/.
  final List<Object?> Function(Object value) encode;

  /// Builds a typed list (`List<Vector3>`) from decoded items, for parameters like `setFromPoints(points)`.
  final List<Object> Function(List<Object?> items)? list;
}

/// Relative tolerance for numbers that differ from the reference; see docs/porting-conventions.md.
const double tolerance = 1e-9;

/// Counts how numbers matched, over the whole run.
final Map<String, int> numberMatches = {'exact': 0, 'tolerance': 0};

const String fixtureDir = '../../fixtures/specs';

/// All fixture files, sorted by name.
List<File> fixtureFiles() {
  return Directory(fixtureDir).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

double _number(Object? v) {
  return switch (v) {
    'NaN' => double.nan,
    'Infinity' => double.infinity,
    '-Infinity' => double.negativeInfinity,
    '-0' => -0.0,
    num n => n.toDouble(),
    _ => throw StateError('fixture: not a number: $v'),
  };
}

bool _isNumber(Object? v) => v is num || v == 'NaN' || v == 'Infinity' || v == '-Infinity' || v == '-0';

/// Turns fixture JSON into the Dart value to pass as an argument or receiver.
Object? decode(Object? json) {
  if (json == null || json is bool) {
    return json;
  }

  if (_isNumber(json)) {
    return _number(json);
  }

  if (json is String) {
    return json;
  }

  final map = json as Map<String, Object?>;

  if (map.containsKey('int')) {
    return (map['int'] as num).toInt();
  }

  if (map.containsKey('undefined')) {
    return null;
  }

  if (map.containsKey('array')) {
    final json = (map['array'] as List<Object?>);
    final items = json.map(decode).toList();
    final types = json.map((j) => j is Map ? j['type'] : null).toSet();
    List<Object> Function(List<Object?> items)? list;

    if (types.length == 1 && types.first != null) {
      list = codecs[types.first]?.list;
    }

    if (items.isNotEmpty && list != null) {
      return list(items);
    }

    return items.every((i) => i is double) ? items.cast<double>().toList() : items;
  }

  if (map.containsKey('typed')) {
    final values = (map['values'] as List<Object?>).map(_number).toList();
    return switch (map['typed']) {
      'Float32Array' => Float32List.fromList(values),
      'Float64Array' => Float64List.fromList(values),
      'Int8Array' => Int8List.fromList(values.map((v) => v.toInt()).toList()),
      'Uint8Array' => Uint8List.fromList(values.map((v) => v.toInt()).toList()),
      'Uint8ClampedArray' => Uint8ClampedList.fromList(values.map((v) => v.toInt()).toList()),
      'Int16Array' => Int16List.fromList(values.map((v) => v.toInt()).toList()),
      'Uint16Array' => Uint16List.fromList(values.map((v) => v.toInt()).toList()),
      'Int32Array' => Int32List.fromList(values.map((v) => v.toInt()).toList()),
      'Uint32Array' => Uint32List.fromList(values.map((v) => v.toInt()).toList()),
      _ => throw StateError('fixture: unknown typed array ${map['typed']}'),
    };
  }

  if (map.containsKey('type')) {
    final codec = codecs[map['type']];

    if (codec == null) {
      throw StateError('fixture: no Dart codec for ${map['type']}');
    }

    return codec.decode((map['value'] as List<Object?>).map(decode).toList());
  }

  throw StateError('fixture: cannot decode $json');
}

/// The registered type name of [value]: its class or the nearest superclass with a codec.
String? _typeOf(Object value) {
  for (final name in classChain(value)) {
    if (codecs.containsKey(name)) {
      return name;
    }
  }

  return null;
}

void _compareNumber(Object? actual, Object? expected, String path, List<String> errors) {
  if (actual is! num) {
    errors.add('$path: expected number $expected, got $actual');
    return;
  }

  final a = actual.toDouble();
  final e = _number(expected);

  if (a == e || (a.isNaN && e.isNaN)) {
    numberMatches['exact'] = numberMatches['exact']! + 1;
    return;
  }

  final scale = [1.0, a.abs(), e.abs()].reduce((x, y) => x > y ? x : y);

  if ((a - e).abs() <= tolerance * scale) {
    numberMatches['tolerance'] = numberMatches['tolerance']! + 1;
    return;
  }

  errors.add('$path: expected $e, got $a');
}

/// Compares a Dart value with the fixture's expected JSON, adding a message per mismatch to [errors].
void compare(Object? actual, Object? expected, String path, List<String> errors) {
  if (_isNumber(expected)) {
    _compareNumber(actual, expected, path, errors);
    return;
  }

  if (expected == null || expected is bool || expected is String) {
    if (actual != expected) {
      errors.add('$path: expected $expected, got $actual');
    }

    return;
  }

  final map = expected as Map<String, Object?>;

  if (map.containsKey('int')) {
    _compareNumber(actual, map['int'], path, errors);
  } else if (map.containsKey('undefined')) {
    if (actual != null) {
      errors.add('$path: expected undefined (null), got $actual');
    }
  } else if (map.containsKey('array') || map.containsKey('typed')) {
    final items = (map['array'] ?? map['values']) as List<Object?>;

    if (actual is! List || actual.length != items.length) {
      errors.add('$path: expected a list of ${items.length}, got $actual');
      return;
    }

    for (var i = 0; i < items.length; i++) {
      compare(actual[i], items[i], '$path[$i]', errors);
    }
  } else if (map.containsKey('type')) {
    final type = actual == null ? null : _typeOf(actual);

    if (type != map['type']) {
      errors.add('$path: expected a ${map['type']}, got ${actual?.runtimeType}');
      return;
    }

    final state = codecs[type]!.encode(actual!);
    final values = map['value'] as List<Object?>;

    for (var i = 0; i < values.length; i++) {
      compare(state[i], values[i], '$path.$type[$i]', errors);
    }
  } else {
    throw StateError('fixture: cannot compare with $expected');
  }
}

/// Registers a test group replaying one fixture file.
void replay(File file) {
  final fixture = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final name = fixture['name'] as String;
  final isStatic = fixture['static'] as bool;

  group(name, () {
    for (final method in (fixture['methods'] as List<Object?>).cast<Map<String, Object?>>()) {
      final label = method['label'] == null ? '' : ' (${method['label']})';

      test('${method['name']}$label', () {
        final errors = <String>[];
        final cases = (method['cases'] as List<Object?>).cast<Map<String, Object?>>();

        for (var i = 0; i < cases.length; i++) {
          _case(name, isStatic, (method['dart'] ?? method['name']) as String, cases[i], 'case $i', errors);
        }

        expect(errors, isEmpty, reason: errors.take(20).join('\n'));
      });
    }
  });
}

void _case(String name, bool isStatic, String method, Map<String, Object?> c, String at, List<String> errors) {
  final self = isStatic ? null : decode(c['self']);
  final args = (c['args'] as List<Object?>).map(decode).toList();
  final out = c['out'] as Map<String, Object?>;
  Object? result;

  try {
    if (isStatic) {
      if (!statics.containsKey(name)) {
        errors.add('$at: class $name is missing');
        return;
      }

      result = invokeStatic(name, method, args);
    } else {
      result = invoke(self!, method, args);
    }
  } on NoSuchMethodError catch (e) {
    errors.add('$at: $name.$method is missing or has another signature: $e');
    return;
  } on TypeError catch (e) {
    errors.add('$at: $name.$method rejected the arguments: $e');
    return;
  } catch (e) {
    final message = out['throws'];

    if (message == null) {
      errors.add('$at: threw $e, expected no error');
    } else if (message is String && message.startsWith('ENT.') && (e is! EntError || e.message != message)) {
      // The engine's own errors must say what the reference says; others (a RangeError) only have to throw.
      errors.add('$at: threw $e, expected "$message"');
    }

    return;
  }

  if (out.containsKey('throws')) {
    errors.add('$at: expected an error "${out['throws']}", returned $result');
    return;
  }

  if (!isStatic) {
    compare(self, out['self'], '$at self', errors);
  }

  final expected = out['args'] as List<Object?>;

  for (var i = 0; i < expected.length; i++) {
    compare(args[i], expected[i], '$at arg $i', errors);
  }

  final ret = out['return'];

  if (ret is Map && ret.containsKey('this')) {
    if (!identical(result, self)) {
      errors.add('$at: expected `this` returned, got $result');
    }
  } else if (ret is Map && ret.containsKey('arg')) {
    if (!identical(result, args[(ret['arg'] as num).toInt()])) {
      errors.add('$at: expected argument ${ret['arg']} returned, got $result');
    }
  } else {
    compare(result, ret, '$at return', errors);
  }
}
