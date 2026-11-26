// The public API of ent: every public top-level name of the library, against the list in test/api.txt. A name that
// appears or disappears fails here until the list is updated, so a change of the API is always deliberate. The names
// come from support/library.g.dart, which tool/generate.dart writes from the library (generated_test.dart keeps it
// current). Run with API_WRITE=1 in the environment to rewrite the list.

import 'dart:io';

import 'package:test/test.dart';

import 'support/library.g.dart';

void main() {
  test('the public top-level names equal test/api.txt', () {
    final file = File('test/api.txt');

    if (Platform.environment['API_WRITE'] == '1') {
      file.writeAsStringSync('${publicNames.join('\n')}\n');
    }

    final listed = file.readAsLinesSync().where((line) => line.isNotEmpty).toList();
    expect(publicNames.where((name) => !listed.contains(name)), isEmpty, reason: 'public, not listed');
    expect(listed.where((name) => !publicNames.contains(name)), isEmpty, reason: 'listed, not public');
  });
}
