// Shared by the helper tests: the reference values and a tolerant comparison.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Values written by tool/reference/js/helpers.mjs from the reference source.
final Map<String, Object?> helpersReference =
    jsonDecode(File('../../fixtures/values/helpers.json').readAsStringSync()) as Map<String, Object?>;

/// Reads a nested reference value by its keys.
Object? refAt(List<String> path) {
  Object? value = helpersReference;

  for (final key in path) {
    value = (value as Map<String, Object?>)[key];
  }

  return value;
}

/// Compares numbers (recursively in lists) within `tolerance · max(1, |a|, |b|)`; booleans and strings exactly.
///
/// Float32 attribute arrays use 1e-6: a last-ulp difference between V8's and the Dart VM's `sin`/`cos` can
/// survive the conversion to float32. Matrices and quaternions are doubles and use the fixture tolerance 1e-9.
void expectClose(Object? actual, Object? expected, {double tolerance = 1e-9, String path = ''}) {
  switch (expected) {
    case num e:
      final a = (actual! as num).toDouble();
      final scale = [1.0, a.abs(), e.abs()].reduce((x, y) => x > y ? x : y);
      expect((a - e).abs() <= tolerance * scale, isTrue, reason: '$path: expected $e, got $a');
    case List<Object?> e:
      final list = actual! as List<Object?>;
      expect(list.length, e.length, reason: '$path length');

      for (var i = 0; i < e.length; i++) {
        expectClose(list[i], e[i], tolerance: tolerance, path: '$path[$i]');
      }
    default:
      expect(actual, expected, reason: path);
  }
}
