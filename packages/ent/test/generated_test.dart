// The generated support/library.g.dart must be what tool/generate.dart writes from the library now; after a change of
// the API, run dart run tool/generate.dart.

import 'dart:io';

import 'package:test/test.dart';

import '../tool/generate.dart';

void main() {
  test('support/library.g.dart is current', () async {
    expect(File(output).readAsStringSync(), await generate(), reason: 'run dart run tool/generate.dart');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
