// The reference unit tests of constants.
//
// The reference's single test, 'default values', asserts constant values one by one. The port checks every exported
// constant of the reference instead, against values Node read from that module (fixtures/values/constants.json, written
// by tool/reference/js/constants.mjs). That covers each reference assertion and also catches a missing or renamed
// constant.

import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

final LibraryMirror _library = reflectClass(MathUtils).owner as LibraryMirror;

/// The static constants of an object-valued export (`MOUSE`, `TimestampQuery`, ...), by name.
Map<String, Object?> staticValues(ClassMirror type) {
  return {
    for (final MapEntry(:key, :value) in type.declarations.entries)
      if (value is VariableMirror && value.isStatic) MirrorSystem.getName(key): type.getField(key).reflectee,
  };
}

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
        final declaration = _library.declarations[Symbol(name)];

        if (value is Map) {
          if (declaration is! ClassMirror) {
            errors.add('$name: missing (expected an object of constants)');
          } else if (!sameEntries(staticValues(declaration), value)) {
            errors.add('$name: ${staticValues(declaration)} != $value');
          }

          continue;
        }

        if (declaration is! VariableMirror || !declaration.isConst) {
          errors.add('$name: missing (expected a const)');
        } else if (_library.getField(Symbol(name)).reflectee != value) {
          errors.add('$name: ${_library.getField(Symbol(name)).reflectee} != $value');
        }
      }

      expect(expected.length, 211, reason: 'reference export count');
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  });
}
