// ObjectLoader round trips against the reference: tool/reference/js/loaders.mjs serializes scenes with the reference
// source, parses them with the reference ObjectLoader and serializes again. The port parses the same JSON and must
// serialize to the same result (uuids compared by order of appearance).

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  final values = jsonDecode(File('../../fixtures/values/loaders.json').readAsStringSync()) as Map<String, Object?>;
  final scenarios = (values['scenarios']! as Map).cast<String, Object?>();

  group('ObjectLoader reference', () {
    for (final MapEntry(key: name, value: scenario) in scenarios.entries) {
      test(name, () {
        final data = (scenario! as Map).cast<String, Object?>();
        final object = ObjectLoader().parse((data['json']! as Map).cast<String, Object?>());
        final errors = jsonDifferences(canonical(object.toJSON()), canonical(data['roundtrip']));

        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  });
}
