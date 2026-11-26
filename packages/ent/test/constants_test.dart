// The reference unit tests of constants.
//
// The reference's single test, 'default values', asserts constant values one by one. The port checks every exported
// constant of the reference instead, against values Node read from that module (fixtures/values/constants.json, written
// by tool/reference/js/constants.mjs). That covers each reference assertion and also catches a missing or renamed
// constant.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/library.g.dart';

/// Whether two maps of numbers and strings hold the same entries.
bool sameEntries(Map<String, Object?> a, Map<Object?, Object?> b) {
  return a.length == b.length && a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
}

void main() {
  final file = File('../../fixtures/values/constants.json');
  final expected = (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['constants'] as Map<String, Object?>;

  group('Constants', () {
    test('default values', () {
      final errors = <String>[];

      for (final MapEntry(key: name, :value) in expected.entries) {
        if (value is Map) {
          final type = constantClasses[name];

          if (type == null) {
            errors.add('$name: missing (expected an object of constants)');
          } else if (!sameEntries(type, value)) {
            errors.add('$name: $type != $value');
          }

          continue;
        }

        if (!constants.containsKey(name)) {
          errors.add('$name: missing (expected a const)');
        } else if (constants[name] != value) {
          errors.add('$name: ${constants[name]} != $value');
        }
      }

      expect(expected.length, 211, reason: 'reference export count');
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  });
}
