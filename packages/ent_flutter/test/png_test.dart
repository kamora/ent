// The PNG decoder against the fixtures of tool/png_fixtures.mjs: every color type and bit depth, tRNS, the five
// filters, Adam7 and split IDAT data, each compared with the straight RGBA bytes the generator wrote (which headless
// Chrome decodes identically: `node tool/png_fixtures.mjs --chrome`).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/src/png.dart';

void main() {
  final fixtures = Directory('test/png').listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the fixtures are there', () => expect(fixtures, hasLength(55)));

  for (final file in fixtures) {
    test(file.uri.pathSegments.last, () {
      final png = decodePng(file.readAsBytesSync())!;
      final expected = File(file.path.replaceFirst(RegExp(r'\.png$'), '.rgba')).readAsBytesSync();
      expect(png.width * png.height * 4, expected.length);
      expect(png.pixels, expected);
    });
  }

  test('anything but a PNG is left to dart:ui', () {
    expect(decodePng(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0, 16, 74, 70, 73, 70])), isNull);
    expect(decodePng(Uint8List(0)), isNull);
  });

  test('a broken PNG throws a FormatException', () {
    final bytes = File('test/png/t6_d8.png').readAsBytesSync();
    expect(() => decodePng(Uint8List.sublistView(bytes, 0, bytes.length ~/ 2)), throwsFormatException);
  });
}
