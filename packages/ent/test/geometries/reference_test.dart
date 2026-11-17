// Rebuilds every geometry recipe of fixtures/values/geometries.json (written by tool/reference/js/geometries.mjs from
// the reference source) and compares the index, every attribute and the groups with what the reference generated.
//
// Float32 attribute values match exactly unless V8 and the Dart VM round a libm result (sin, cos, atan2, pow)
// differently in the last double ulp and that difference survives the conversion to float32. Such values must
// agree to 1e-6 relative to max(1, |value|): about 8 float32 ulps at magnitude 1. Exact and tolerated matches
// are counted and printed.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

const double _tolerance = 1e-6;

final Map<String, int> _matches = {'exact': 0, 'tolerance': 0};

double _d(Object? v) {
  return switch (v) {
    'NaN' => double.nan,
    'Infinity' => double.infinity,
    '-Infinity' => double.negativeInfinity,
    '-0' => -0.0,
    num n => n.toDouble(),
    _ => throw StateError('not a number: $v'),
  };
}

/// Converts recipe arguments to the Dart parameter types of a constructor: `d` double, `i` int, `b` bool.
List<Object?> _convert(List<Object?> args, String kinds) {
  return [
    for (var i = 0; i < args.length; i++)
      switch (kinds[i]) {
        'd' => _d(args[i]),
        'i' => (args[i] as num).toInt(),
        'b' => args[i] as bool,
        _ => throw StateError('unknown kind ${kinds[i]}'),
      },
  ];
}

T _draw<T extends Path>(T path, List<Object?> commands) {
  for (final command in commands.cast<List<Object?>>()) {
    final name = command[0] as String;
    final a = command.skip(1).toList();

    switch (name) {
      case 'moveTo':
        path.moveTo(_d(a[0]), _d(a[1]));
      case 'lineTo':
        path.lineTo(_d(a[0]), _d(a[1]));
      case 'quadraticCurveTo':
        path.quadraticCurveTo(_d(a[0]), _d(a[1]), _d(a[2]), _d(a[3]));
      case 'bezierCurveTo':
        path.bezierCurveTo(_d(a[0]), _d(a[1]), _d(a[2]), _d(a[3]), _d(a[4]), _d(a[5]));
      case 'absarc':
        path.absarc(_d(a[0]), _d(a[1]), _d(a[2]), _d(a[3]), _d(a[4]), a[5] as bool);
      case 'splineThru':
        path.splineThru([for (final p in (a[0] as List).cast<List<Object?>>()) Vector2(_d(p[0]), _d(p[1]))]);
      default:
        throw StateError('unknown path command $name');
    }
  }

  return path;
}

Shape _shape(Map<String, Object?> recipe) {
  final shape = _draw(Shape(), recipe['commands'] as List<Object?>);

  for (final hole in (recipe['holes'] as List? ?? []).cast<List<Object?>>()) {
    shape.holes.add(_draw(Path(), hole));
  }

  return shape;
}

Curve<Vector3> _curve(Map<String, Object?> recipe) {
  final points = [
    for (final p in (recipe['points'] as List? ?? []).cast<List<Object?>>()) Vector3(_d(p[0]), _d(p[1]), _d(p[2])),
  ];

  return switch (recipe['type']) {
    'CatmullRomCurve3' => CatmullRomCurve3(
      points,
      recipe['closed'] as bool,
      recipe['curveType'] as String,
      _d(recipe['tension']),
    ),
    'LineCurve3' => LineCurve3(points[0], points[1]),
    'QuadraticBezierCurve3' => QuadraticBezierCurve3(points[0], points[1], points[2]),
    'CubicBezierCurve3' => CubicBezierCurve3(points[0], points[1], points[2], points[3]),
    _ => throw StateError('unknown curve ${recipe['type']}'),
  };
}

Object? _shapes(Map<String, Object?> recipe) {
  if (recipe['shapes'] != null) {
    return [for (final s in (recipe['shapes'] as List).cast<Map<String, Object?>>()) _shape(s)];
  }

  return recipe['shape'] == null ? null : _shape(recipe['shape'] as Map<String, Object?>);
}

BufferGeometry _build(Map<String, Object?> recipe) {
  final args = (recipe['args'] as List?)?.cast<Object?>() ?? <Object?>[];

  return switch (recipe['class']) {
    'BoxGeometry' => Function.apply(BoxGeometry.new, _convert(args, 'dddiii')),
    'CapsuleGeometry' => Function.apply(CapsuleGeometry.new, _convert(args, 'ddiii')),
    'CircleGeometry' => Function.apply(CircleGeometry.new, _convert(args, 'didd')),
    'ConeGeometry' => Function.apply(ConeGeometry.new, _convert(args, 'ddiibdd')),
    'CylinderGeometry' => Function.apply(CylinderGeometry.new, _convert(args, 'dddiibdd')),
    'DodecahedronGeometry' => Function.apply(DodecahedronGeometry.new, _convert(args, 'di')),
    'IcosahedronGeometry' => Function.apply(IcosahedronGeometry.new, _convert(args, 'di')),
    'OctahedronGeometry' => Function.apply(OctahedronGeometry.new, _convert(args, 'di')),
    'TetrahedronGeometry' => Function.apply(TetrahedronGeometry.new, _convert(args, 'di')),
    'PlaneGeometry' => Function.apply(PlaneGeometry.new, _convert(args, 'ddii')),
    'PolyhedronGeometry' => PolyhedronGeometry(
      (args[0] as List).cast<num>(),
      (args[1] as List).map((i) => (i as num).toInt()).toList(),
      _d(args[2]),
      (args[3] as num).toInt(),
    ),
    'RingGeometry' => Function.apply(RingGeometry.new, _convert(args, 'ddiidd')),
    'SphereGeometry' => Function.apply(SphereGeometry.new, _convert(args, 'diidddd')),
    'TorusGeometry' => Function.apply(TorusGeometry.new, _convert(args, 'ddiiddd')),
    'TorusKnotGeometry' => Function.apply(TorusKnotGeometry.new, _convert(args, 'ddiidd')),
    'LatheGeometry' => Function.apply(LatheGeometry.new, [
      (recipe['points'] as List?)?.cast<List<Object?>>().map((p) => Vector2(_d(p[0]), _d(p[1]))).toList(),
      ..._convert(args, 'idd'),
    ]),
    'ShapeGeometry' => Function.apply(ShapeGeometry.new, [_shapes(recipe), ..._convert(args, 'i')]),
    'ExtrudeGeometry' => ExtrudeGeometry(_shapes(recipe), {
      for (final MapEntry(:key, :value) in (recipe['options'] as Map<String, Object?>? ?? {}).entries)
        key: key == 'extrudePath' ? _curve(value as Map<String, Object?>) : value,
    }),
    'TubeGeometry' => Function.apply(TubeGeometry.new, [
      recipe['path'] == null ? null : _curve(recipe['path'] as Map<String, Object?>),
      ..._convert(args, 'idib'),
    ]),
    'EdgesGeometry' => Function.apply(EdgesGeometry.new, [
      _build(recipe['of'] as Map<String, Object?>),
      ..._convert(args, 'd'),
    ]),
    'WireframeGeometry' => WireframeGeometry(_build(recipe['of'] as Map<String, Object?>)),
    'toNonIndexed' => _build(recipe['of'] as Map<String, Object?>).toNonIndexed(),
    _ => throw StateError('unknown recipe ${recipe['class']}'),
  } as BufferGeometry;
}

String _typedName(List<num> array) {
  return switch (array) {
    Float32List() => 'Float32Array',
    Uint16List() => 'Uint16Array',
    Uint32List() => 'Uint32Array',
    _ => array.runtimeType.toString(),
  };
}

void _compareNumbers(List<num> actual, List<Object?> expected, String at, List<String> errors) {
  if (actual.length != expected.length) {
    errors.add('$at: length ${actual.length}, expected ${expected.length}');
    return;
  }

  for (var i = 0; i < expected.length; i++) {
    final a = actual[i].toDouble();
    final e = _d(expected[i]);

    if (a == e && a.isNegative == e.isNegative || a.isNaN && e.isNaN) {
      _matches['exact'] = _matches['exact']! + 1;
    } else if ((a - e).abs() <= _tolerance * [1.0, a.abs(), e.abs()].reduce((x, y) => x > y ? x : y)) {
      _matches['tolerance'] = _matches['tolerance']! + 1;
    } else {
      errors.add('$at[$i]: $a, expected $e');
    }
  }
}

void main() {
  final file = File('../../fixtures/values/geometries.json');
  final cases = ((jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['cases'] as List)
      .cast<Map<String, Object?>>();

  group('Geometries reference', () {
    for (var n = 0; n < cases.length; n++) {
      final recipe = cases[n]['recipe'] as Map<String, Object?>;
      final expected = cases[n]['expected'] as Map<String, Object?>;

      test('$n ${recipe['class']} ${jsonEncode(recipe['args'] ?? recipe['options'] ?? '')}', () {
        final geometry = _build(recipe);
        final errors = <String>[];

        expect(geometry.type, expected['type']);

        final index = geometry.getIndex();
        final expectedIndex = expected['index'] as Map<String, Object?>?;

        if (expectedIndex == null) {
          expect(index, isNull);
        } else {
          expect(_typedName(index!.array), expectedIndex['type']);
          expect(index.array, (expectedIndex['array'] as List).cast<num>());
        }

        final attributes = expected['attributes'] as Map<String, Object?>;

        expect(geometry.attributes.keys.toSet(), attributes.keys.toSet());

        for (final MapEntry(:key, :value) in attributes.entries) {
          final attribute = geometry.getAttribute(key)!;
          final spec = value as Map<String, Object?>;

          expect(attribute.itemSize, spec['itemSize'], reason: key);
          expect(_typedName(attribute.array), spec['type'], reason: key);
          _compareNumbers(attribute.array, spec['array'] as List<Object?>, key, errors);
        }

        expect(geometry.groups.map((g) => [g.start, g.count, g.materialIndex]).toList(), expected['groups']);
        expect(errors, isEmpty, reason: errors.take(10).join('\n'));
      });
    }

    tearDownAll(() {
      print('geometry numbers: ${_matches['exact']} exact, ${_matches['tolerance']} within tolerance');
    });
  });
}
