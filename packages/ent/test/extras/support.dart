// Assertions of the reference test utilities used by the extras tests.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// `assert.numEqual`: the difference is below 0.1.
void numEqual(double actual, double expected, [String? reason]) {
  expect((actual - expected).abs() < 0.1, isTrue, reason: reason ?? '$actual should be equal to $expected');
}

List<double> _components(Object v) {
  return switch (v) {
    Vector2 p => [p.x, p.y],
    Vector3 p => [p.x, p.y, p.z],
    _ => throw ArgumentError('not a vector: $v'),
  };
}

/// `assert.deepEqual` on lists of vectors: same length, same type and exactly the same components.
void deepEqualPoints(List<Object> actual, List<Object> expected, [String? reason]) {
  expect(actual.length, expected.length, reason: reason);

  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].runtimeType, expected[i].runtimeType, reason: reason);
    expect(_components(actual[i]), _components(expected[i]), reason: '${reason ?? ''} [$i]');
  }
}

/// The values reference/extras_reference.mjs computed with the reference source.
final Map<String, Object?> reference =
    jsonDecode(File('test/extras/reference/extras_reference.json').readAsStringSync()) as Map<String, Object?>;

/// Equal, or within `1e-9 · max(1, |a|, |b|)` (the libm tolerance of docs/porting-conventions.md).
void close(num actual, num expected, [String? reason]) {
  final scale = [1.0, actual.abs(), expected.abs()].reduce((a, b) => a > b ? a : b);
  expect(
    actual == expected || (actual - expected).abs() <= 1e-9 * scale,
    isTrue,
    reason: '${reason ?? ''} $actual vs $expected',
  );
}

/// Compares vectors with the reference's `[ x, y ]` / `[ x, y, z ]` arrays.
void closePoints(List<Object> actual, Object? expected, [String? reason]) {
  final list = (expected as List).cast<List<Object?>>();
  expect(actual.length, list.length, reason: '$reason: count');

  for (var i = 0; i < actual.length; i++) {
    final c = _components(actual[i]);
    expect(c.length, list[i].length, reason: '$reason[$i]: dimension');

    for (var k = 0; k < c.length; k++) {
      close(c[k], list[i][k] as num, '$reason[$i][$k]');
    }
  }
}
