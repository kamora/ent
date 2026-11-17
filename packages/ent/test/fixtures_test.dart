// Replays every reference fixture produced from the reference source.

import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  for (final file in fixtureFiles()) {
    replay(file);
  }

  tearDownAll(() {
    print('fixture numbers: ${numberMatches['exact']} exact, ${numberMatches['tolerance']} within tolerance');
  });
}
