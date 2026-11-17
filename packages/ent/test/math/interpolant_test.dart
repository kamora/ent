// The reference unit tests of Interpolant.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

/// Since this is an abstract base class, we have to make it concrete in order to test its functionality.
class Mock extends Interpolant {
  Mock(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]);

  /// Call capturing facility.
  static List<Map<String, Object>>? calls;

  @override
  void intervalChanged_(int i1, double t0, double t1) {
    calls?.add({
      'func': 'intervalChanged',
      'args': [i1, t0, t1],
    });
  }

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    calls?.add({
      'func': 'interpolate',
      'args': [i1, t0, t, t1],
    });

    return copySampleValue_(i1 - 1);
  }
}

void main() {
  group('Maths', () {
    group('Interpolant', () {
      // INSTANCING
      test('Instancing', () {
        final interpolant = Mock(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);
        expect(interpolant, isA<Interpolant>(), reason: 'Mock extends from Interpolant');
      });

      // PRIVATE
      test('copySampleValue_', () {
        final interpolant = Mock(<double>[], [1, 11, 2, 22, 3, 33], 2, <double>[]);

        expect(interpolant.copySampleValue_(0), [1, 11], reason: 'sample fetch (0)');
        expect(interpolant.copySampleValue_(1), [2, 22], reason: 'sample fetch (1)');
        expect(interpolant.copySampleValue_(2), [3, 33], reason: 'first sample (2)');
      });

      test('evaluate -> intervalChanged_ / interpolate_', () {
        final interpolant = Mock([11, 22, 33, 44, 55, 66, 77, 88, 99], <double>[], 0);

        // Evaluates at `t` and checks the captured calls: the interval change (when expected) and the
        // interpolation, nothing more.
        void check(double t, List<num>? changed, List<num> interpolated) {
          Mock.calls = [];
          interpolant.evaluate(t);

          final expected = [
            if (changed != null) {'func': 'intervalChanged', 'args': changed},
            {'func': 'interpolate', 'args': interpolated},
          ];

          expect(Mock.calls, expected, reason: 'evaluate( $t )');
        }

        check(11, [1, 11, 22], [1, 11, 11, 22]);
        check(12, null, [1, 11, 12, 22]); // same interval
        check(22, [2, 22, 33], [2, 22, 22, 33]); // step forward
        check(21, [1, 11, 22], [1, 11, 21, 22]); // step back
        check(20, null, [1, 11, 20, 22]); // same interval
        check(43, [3, 33, 44], [3, 33, 43, 44]); // two steps forward
        check(12, [1, 11, 22], [1, 11, 12, 22]); // two steps back
        check(77, [7, 77, 88], [7, 77, 77, 88]); // random access
        check(80, null, [7, 77, 80, 88]); // same interval
        check(36, [3, 33, 44], [3, 33, 36, 44]); // random access
        check(24, [2, 22, 33], [2, 22, 24, 33]); // fast reset / loop (2nd)
        check(16, [1, 11, 22], [1, 11, 16, 22]); // fast reset / loop (2nd)

        Mock.calls = null;
      });

      // Dart-specific: the base class is instantiable as in JS, and its template method throws.
      test('interpolate_ is abstract', () {
        final interpolant = Interpolant([0, 1], [0, 1], 1);

        expect(
          () => interpolant.evaluate(0.5),
          throwsA(isA<EntError>().having((e) => e.message, 'message', 'ENT.Interpolant: Call to abstract method.')),
        );
      });

      // Dart-specific: `new sampleValues.constructor( sampleSize )` for the default result buffer.
      test('resultBuffer follows sampleValues', () {
        expect(Mock([0], Float32List(3), 3).resultBuffer, isA<Float32List>());
        expect(Mock([0], Float64List(3), 3).resultBuffer, isA<Float64List>());

        final plain = Mock([0], <double>[1, 2, 3], 3).resultBuffer;
        expect(plain, isNot(isA<TypedData>()));
        expect(plain.length, 3);
      });

      // Dart-specific: settings default to DefaultSettings_ like `this.settings || this.DefaultSettings_`.
      test('getSettings_', () {
        final interpolant = Mock([0], [0], 1);
        expect(interpolant.settings, isNull);
        expect(identical(interpolant.getSettings_(), interpolant.DefaultSettings_), isTrue);

        interpolant.settings = {'endingStart': ZeroSlopeEnding};
        expect(identical(interpolant.getSettings_(), interpolant.settings), isTrue);
      });
    });
  });
}
