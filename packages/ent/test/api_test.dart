// The public API of ent: every public top-level name of the library, against the list in test/api.txt. A name that
// appears or disappears fails here until the list is updated, so a change of the API is always deliberate. Run with
// API_WRITE=1 in the environment to rewrite the list from the library. Mirrors do not list typedefs, so those are read
// from the sources.

import 'dart:io';
import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  test('the public top-level names equal test/api.txt', () {
    final library = reflectClass(MathUtils).owner as LibraryMirror;
    final names = [
      for (final key in library.declarations.keys)
        if (!MirrorSystem.getName(key).startsWith('_')) MirrorSystem.getName(key),
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        for (final match in RegExp(r'^typedef ([A-Za-z]\w*)', multiLine: true).allMatches(file.readAsStringSync()))
          match[1]!,
    ]..sort();
    final file = File('test/api.txt');

    if (Platform.environment['API_WRITE'] == '1') {
      file.writeAsStringSync('${names.join('\n')}\n');
    }

    final listed = file.readAsLinesSync().where((line) => line.isNotEmpty).toList();
    expect(names.where((name) => !listed.contains(name)), isEmpty, reason: 'public, not listed');
    expect(listed.where((name) => !names.contains(name)), isEmpty, reason: 'listed, not public');
  });
}
