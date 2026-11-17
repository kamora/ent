part of '../../ent.dart';

/// Represents a 2x2 matrix.
///
/// A Note on Row-Major and Column-Major Ordering:
///
/// The constructor and [set] method take arguments in
/// [row-major](https://en.wikipedia.org/wiki/Row-_and_column-major_order#Column-major_order) order, while
/// internally they are stored in the [elements] array in column-major order. This means that calling:
///
/// ```dart
/// final m = Matrix2();
/// m.set(11, 12,
///       21, 22);
/// ```
///
/// will result in the elements array containing:
///
/// ```dart
/// m.elements = [11, 21,
///               12, 22];
/// ```
///
/// and internally all calculations are performed using column-major ordering. However, as the actual ordering makes no
/// difference mathematically and most people are used to thinking about matrices in row-major order, this documentation
/// shows matrices in row-major order. Just bear in mind that if you are reading the source code, you'll have to take
/// the transpose of any matrices outlined here to make sense of the calculations.
class Matrix2 {
  /// This flag can be used for type testing.
  bool get isMatrix2 => true;

  /// Constructs a new 2x2 matrix. The arguments are supposed to be in row-major order. If no arguments are
  /// provided, the constructor initializes the matrix as an identity matrix.
  Matrix2([double? n11, double? n12, double? n21, double? n22]) {
    if (n11 != null) {
      set(n11, n12!, n21!, n22!);
    }
  }

  /// A column-major list of matrix values.
  List<double> elements = Float64List.fromList([1, 0, 0, 1]);

  /// Sets this matrix to the 2x2 identity matrix.
  Matrix2 identity() {
    set(1, 0, 0, 1);

    return this;
  }

  /// Sets the elements of the matrix from the given array (column-major), starting at `offset`.
  Matrix2 fromArray(List<num> array, [int offset = 0]) {
    for (var i = 0; i < 4; i++) {
      elements[i] = array[i + offset].toDouble();
    }

    return this;
  }

  /// Sets the elements of the matrix. The arguments are supposed to be in row-major order.
  Matrix2 set(double n11, double n12, double n21, double n22) {
    final te = elements;

    te[0] = n11;
    te[2] = n12;
    te[1] = n21;
    te[3] = n22;

    return this;
  }
}
