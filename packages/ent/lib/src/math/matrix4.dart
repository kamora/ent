part of '../../ent.dart';

/// Represents a 4x4 matrix.
///
/// The most common use of a 4x4 matrix in 3D computer graphics is as a transformation matrix. For an
/// introduction to transformation matrices as used in WebGL, check out
/// [this tutorial](https://www.opengl-tutorial.org/beginners-tutorials/tutorial-3-matrices).
///
/// This allows a 3D vector representing a point in 3D space to undergo transformations such as translation,
/// rotation, shear, scale, reflection, orthogonal or perspective projection and so on, by being multiplied by
/// the matrix. This is known as `applying` the matrix to the vector.
///
/// A Note on Row-Major and Column-Major Ordering:
///
/// The constructor and [set] method take arguments in
/// [row-major](https://en.wikipedia.org/wiki/Row-_and_column-major_order#Column-major_order) order, while
/// internally they are stored in the [elements] array in column-major order. This means that calling:
///
/// ```dart
/// final m = Matrix4();
/// m.set(11, 12, 13, 14,
///       21, 22, 23, 24,
///       31, 32, 33, 34,
///       41, 42, 43, 44);
/// ```
///
/// will result in the elements array containing:
///
/// ```dart
/// m.elements == [11, 21, 31, 41,
///                12, 22, 32, 42,
///                13, 23, 33, 43,
///                14, 24, 34, 44];
/// ```
///
/// and internally all calculations are performed using column-major ordering. However, as the actual ordering makes no
/// difference mathematically and most people are used to thinking about matrices in row-major order, this documentation
/// shows matrices in row-major order. Just bear in mind that if you are reading the source code, you'll have to take
/// the transpose of any matrices outlined here to make sense of the calculations.
class Matrix4 {
  /// Constructs a new 4x4 matrix. The arguments are supposed to be in row-major order. If no arguments are
  /// provided, the constructor initializes the matrix as an identity matrix.
  Matrix4([
    double? n11,
    double? n12,
    double? n13,
    double? n14,
    double? n21,
    double? n22,
    double? n23,
    double? n24,
    double? n31,
    double? n32,
    double? n33,
    double? n34,
    double? n41,
    double? n42,
    double? n43,
    double? n44,
  ]) {
    if (n11 != null) {
      set(n11, n12!, n13!, n14!, n21!, n22!, n23!, n24!, n31!, n32!, n33!, n34!, n41!, n42!, n43!, n44!);
    }
  }

  /// This flag can be used for type testing.
  bool get isMatrix4 => true;

  /// A column-major list of matrix values.
  List<double> elements = Float64List.fromList(const [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

  /// Sets the elements of the matrix. The arguments are supposed to be in row-major order.
  Matrix4 set(
    double n11,
    double n12,
    double n13,
    double n14,
    double n21,
    double n22,
    double n23,
    double n24,
    double n31,
    double n32,
    double n33,
    double n34,
    double n41,
    double n42,
    double n43,
    double n44,
  ) {
    final te = elements;

    te[0] = n11;
    te[4] = n12;
    te[8] = n13;
    te[12] = n14;
    te[1] = n21;
    te[5] = n22;
    te[9] = n23;
    te[13] = n24;
    te[2] = n31;
    te[6] = n32;
    te[10] = n33;
    te[14] = n34;
    te[3] = n41;
    te[7] = n42;
    te[11] = n43;
    te[15] = n44;

    return this;
  }

  /// Sets this matrix to the 4x4 identity matrix.
  Matrix4 identity() {
    set(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);

    return this;
  }

  /// Returns a matrix with copied values from this instance.
  Matrix4 clone() {
    return Matrix4().fromArray(elements);
  }

  /// Copies the values of the given matrix to this instance.
  Matrix4 copy(Matrix4 m) {
    final te = elements;
    final me = m.elements;

    for (var i = 0; i < 16; i++) {
      te[i] = me[i];
    }

    return this;
  }

  /// Copies the translation component of the given matrix into this matrix's translation component.
  Matrix4 copyPosition(Matrix4 m) {
    final te = elements, me = m.elements;

    te[12] = me[12];
    te[13] = me[13];
    te[14] = me[14];

    return this;
  }

  /// Set the upper 3x3 elements of this matrix to the values of given 3x3 matrix.
  Matrix4 setFromMatrix3(Matrix3 m) {
    final me = m.elements;

    set(me[0], me[3], me[6], 0, me[1], me[4], me[7], 0, me[2], me[5], me[8], 0, 0, 0, 0, 1);

    return this;
  }

  /// Extracts the basis vectors of this matrix into the three vectors provided.
  Matrix4 extractBasis(Vector3 xAxis, Vector3 yAxis, Vector3 zAxis) {
    if (determinantAffine() == 0) {
      xAxis.set(1, 0, 0);
      yAxis.set(0, 1, 0);
      zAxis.set(0, 0, 1);

      return this;
    }

    xAxis.setFromMatrixColumn(this, 0);
    yAxis.setFromMatrixColumn(this, 1);
    zAxis.setFromMatrixColumn(this, 2);

    return this;
  }

  /// Sets the given basis vectors to this matrix.
  Matrix4 makeBasis(Vector3 xAxis, Vector3 yAxis, Vector3 zAxis) {
    set(xAxis.x, yAxis.x, zAxis.x, 0, xAxis.y, yAxis.y, zAxis.y, 0, xAxis.z, yAxis.z, zAxis.z, 0, 0, 0, 0, 1);

    return this;
  }

  /// Extracts the rotation component of the given matrix into this matrix's rotation component.
  ///
  /// Note: This method does not support reflection matrices.
  Matrix4 extractRotation(Matrix4 m) {
    if (m.determinantAffine() == 0) {
      return identity();
    }

    final te = elements;
    final me = m.elements;

    final scaleX = 1 / _matrix4V1.setFromMatrixColumn(m, 0).length();
    final scaleY = 1 / _matrix4V1.setFromMatrixColumn(m, 1).length();
    final scaleZ = 1 / _matrix4V1.setFromMatrixColumn(m, 2).length();

    te[0] = me[0] * scaleX;
    te[1] = me[1] * scaleX;
    te[2] = me[2] * scaleX;
    te[3] = 0;

    te[4] = me[4] * scaleY;
    te[5] = me[5] * scaleY;
    te[6] = me[6] * scaleY;
    te[7] = 0;

    te[8] = me[8] * scaleZ;
    te[9] = me[9] * scaleZ;
    te[10] = me[10] * scaleZ;
    te[11] = 0;

    te[12] = 0;
    te[13] = 0;
    te[14] = 0;
    te[15] = 1;

    return this;
  }

  /// Sets the rotation component (the upper left 3x3 matrix) of this matrix to the rotation specified by the
  /// given Euler angles. The rest of the matrix is set to the identity. Depending on the [Euler.order], there
  /// are six possible outcomes. See [this page](https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix)
  /// for a complete list.
  Matrix4 makeRotationFromEuler(Euler euler) {
    final te = elements;

    final x = euler.x, y = euler.y, z = euler.z;
    final a = math.cos(x), b = math.sin(x);
    final c = math.cos(y), d = math.sin(y);
    final e = math.cos(z), f = math.sin(z);

    if (euler.order == 'XYZ') {
      final ae = a * e, af = a * f, be = b * e, bf = b * f;

      te[0] = c * e;
      te[4] = -c * f;
      te[8] = d;

      te[1] = af + be * d;
      te[5] = ae - bf * d;
      te[9] = -b * c;

      te[2] = bf - ae * d;
      te[6] = be + af * d;
      te[10] = a * c;
    } else if (euler.order == 'YXZ') {
      final ce = c * e, cf = c * f, de = d * e, df = d * f;

      te[0] = ce + df * b;
      te[4] = de * b - cf;
      te[8] = a * d;

      te[1] = a * f;
      te[5] = a * e;
      te[9] = -b;

      te[2] = cf * b - de;
      te[6] = df + ce * b;
      te[10] = a * c;
    } else if (euler.order == 'ZXY') {
      final ce = c * e, cf = c * f, de = d * e, df = d * f;

      te[0] = ce - df * b;
      te[4] = -a * f;
      te[8] = de + cf * b;

      te[1] = cf + de * b;
      te[5] = a * e;
      te[9] = df - ce * b;

      te[2] = -a * d;
      te[6] = b;
      te[10] = a * c;
    } else if (euler.order == 'ZYX') {
      final ae = a * e, af = a * f, be = b * e, bf = b * f;

      te[0] = c * e;
      te[4] = be * d - af;
      te[8] = ae * d + bf;

      te[1] = c * f;
      te[5] = bf * d + ae;
      te[9] = af * d - be;

      te[2] = -d;
      te[6] = b * c;
      te[10] = a * c;
    } else if (euler.order == 'YZX') {
      final ac = a * c, ad = a * d, bc = b * c, bd = b * d;

      te[0] = c * e;
      te[4] = bd - ac * f;
      te[8] = bc * f + ad;

      te[1] = f;
      te[5] = a * e;
      te[9] = -b * e;

      te[2] = -d * e;
      te[6] = ad * f + bc;
      te[10] = ac - bd * f;
    } else if (euler.order == 'XZY') {
      final ac = a * c, ad = a * d, bc = b * c, bd = b * d;

      te[0] = c * e;
      te[4] = -f;
      te[8] = d * e;

      te[1] = ac * f + bd;
      te[5] = a * e;
      te[9] = ad * f - bc;

      te[2] = bc * f - ad;
      te[6] = b * e;
      te[10] = bd * f + ac;
    }

    // bottom row
    te[3] = 0;
    te[7] = 0;
    te[11] = 0;

    // last column
    te[12] = 0;
    te[13] = 0;
    te[14] = 0;
    te[15] = 1;

    return this;
  }

  /// Sets the rotation component of this matrix to the rotation specified by the given Quaternion as outlined
  /// [here](https://en.wikipedia.org/wiki/Rotation_matrix#Quaternion). The rest of the matrix is set to the
  /// identity.
  Matrix4 makeRotationFromQuaternion(Quaternion q) {
    return compose(_matrix4Zero, q, _matrix4One);
  }

  /// Sets the rotation component of the transformation matrix, looking from `eye` towards `target`, and
  /// oriented by the up-direction.
  Matrix4 lookAt(Vector3 eye, Vector3 target, Vector3 up) {
    final te = elements;

    _matrix4Z.subVectors(eye, target);

    if (_matrix4Z.lengthSq() == 0) {
      // eye and target are in the same position

      _matrix4Z.z = 1;
    }

    _matrix4Z.normalize();
    _matrix4X.crossVectors(up, _matrix4Z);

    if (_matrix4X.lengthSq() == 0) {
      // up and z are parallel

      if (up.z.abs() == 1) {
        _matrix4Z.x += 0.0001;
      } else {
        _matrix4Z.z += 0.0001;
      }

      _matrix4Z.normalize();
      _matrix4X.crossVectors(up, _matrix4Z);
    }

    _matrix4X.normalize();
    _matrix4Y.crossVectors(_matrix4Z, _matrix4X);

    te[0] = _matrix4X.x;
    te[4] = _matrix4Y.x;
    te[8] = _matrix4Z.x;
    te[1] = _matrix4X.y;
    te[5] = _matrix4Y.y;
    te[9] = _matrix4Z.y;
    te[2] = _matrix4X.z;
    te[6] = _matrix4Y.z;
    te[10] = _matrix4Z.z;

    return this;
  }

  /// Post-multiplies this matrix by the given 4x4 matrix.
  Matrix4 multiply(Matrix4 m) {
    return multiplyMatrices(this, m);
  }

  /// Pre-multiplies this matrix by the given 4x4 matrix.
  Matrix4 premultiply(Matrix4 m) {
    return multiplyMatrices(m, this);
  }

  /// Multiples the given 4x4 matrices and stores the result in this matrix.
  Matrix4 multiplyMatrices(Matrix4 a, Matrix4 b) {
    final ae = a.elements;
    final be = b.elements;
    final te = elements;

    final a11 = ae[0], a12 = ae[4], a13 = ae[8], a14 = ae[12];
    final a21 = ae[1], a22 = ae[5], a23 = ae[9], a24 = ae[13];
    final a31 = ae[2], a32 = ae[6], a33 = ae[10], a34 = ae[14];
    final a41 = ae[3], a42 = ae[7], a43 = ae[11], a44 = ae[15];

    final b11 = be[0], b12 = be[4], b13 = be[8], b14 = be[12];
    final b21 = be[1], b22 = be[5], b23 = be[9], b24 = be[13];
    final b31 = be[2], b32 = be[6], b33 = be[10], b34 = be[14];
    final b41 = be[3], b42 = be[7], b43 = be[11], b44 = be[15];

    te[0] = a11 * b11 + a12 * b21 + a13 * b31 + a14 * b41;
    te[4] = a11 * b12 + a12 * b22 + a13 * b32 + a14 * b42;
    te[8] = a11 * b13 + a12 * b23 + a13 * b33 + a14 * b43;
    te[12] = a11 * b14 + a12 * b24 + a13 * b34 + a14 * b44;

    te[1] = a21 * b11 + a22 * b21 + a23 * b31 + a24 * b41;
    te[5] = a21 * b12 + a22 * b22 + a23 * b32 + a24 * b42;
    te[9] = a21 * b13 + a22 * b23 + a23 * b33 + a24 * b43;
    te[13] = a21 * b14 + a22 * b24 + a23 * b34 + a24 * b44;

    te[2] = a31 * b11 + a32 * b21 + a33 * b31 + a34 * b41;
    te[6] = a31 * b12 + a32 * b22 + a33 * b32 + a34 * b42;
    te[10] = a31 * b13 + a32 * b23 + a33 * b33 + a34 * b43;
    te[14] = a31 * b14 + a32 * b24 + a33 * b34 + a34 * b44;

    te[3] = a41 * b11 + a42 * b21 + a43 * b31 + a44 * b41;
    te[7] = a41 * b12 + a42 * b22 + a43 * b32 + a44 * b42;
    te[11] = a41 * b13 + a42 * b23 + a43 * b33 + a44 * b43;
    te[15] = a41 * b14 + a42 * b24 + a43 * b34 + a44 * b44;

    return this;
  }

  /// Multiplies every component of the matrix by the given scalar.
  Matrix4 multiplyScalar(double s) {
    final te = elements;

    for (var i = 0; i < 16; i++) {
      te[i] *= s;
    }

    return this;
  }

  /// Computes and returns the determinant of this matrix.
  double determinant() {
    final te = elements;

    final n11 = te[0], n12 = te[4], n13 = te[8], n14 = te[12];
    final n21 = te[1], n22 = te[5], n23 = te[9], n24 = te[13];
    final n31 = te[2], n32 = te[6], n33 = te[10], n34 = te[14];
    final n41 = te[3], n42 = te[7], n43 = te[11], n44 = te[15];

    final t11 = n23 * n34 - n24 * n33;
    final t12 = n22 * n34 - n24 * n32;
    final t13 = n22 * n33 - n23 * n32;

    final t21 = n21 * n34 - n24 * n31;
    final t22 = n21 * n33 - n23 * n31;
    final t23 = n21 * n32 - n22 * n31;

    return n11 * (n42 * t11 - n43 * t12 + n44 * t13) -
        n12 * (n41 * t11 - n43 * t21 + n44 * t22) +
        n13 * (n41 * t12 - n42 * t21 + n44 * t23) -
        n14 * (n41 * t13 - n42 * t22 + n43 * t23);
  }

  /// Computes and returns the determinant of the 4x4 matrix, but assumes the matrix is affine, saving some
  /// computations.
  ///
  /// For affine matrices (like an object's world matrix), this value equals the full 4x4 [determinant] but
  /// is cheaper to compute. Assumes the bottom row is (0, 0, 0, 1).
  double determinantAffine() {
    final te = elements;

    final n11 = te[0], n12 = te[4], n13 = te[8];
    final n21 = te[1], n22 = te[5], n23 = te[9];
    final n31 = te[2], n32 = te[6], n33 = te[10];

    return n11 * (n22 * n33 - n23 * n32) - n12 * (n21 * n33 - n23 * n31) + n13 * (n21 * n32 - n22 * n31);
  }

  /// Transposes this matrix in place.
  Matrix4 transpose() {
    final te = elements;
    double tmp;

    tmp = te[1];
    te[1] = te[4];
    te[4] = tmp;
    tmp = te[2];
    te[2] = te[8];
    te[8] = tmp;
    tmp = te[6];
    te[6] = te[9];
    te[9] = tmp;

    tmp = te[3];
    te[3] = te[12];
    te[12] = tmp;
    tmp = te[7];
    te[7] = te[13];
    te[13] = tmp;
    tmp = te[11];
    te[11] = te[14];
    te[14] = tmp;

    return this;
  }

  /// Sets the position component for this matrix from the given vector, without affecting the rest of the
  /// matrix.
  ///
  /// `x` is the x component of the vector (a number) or alternatively the vector object ([Vector3]);
  /// `y` and `z` are used only with a number.
  Matrix4 setPosition(Object x, [double? y, double? z]) {
    final te = elements;

    if (x is Vector3) {
      te[12] = x.x;
      te[13] = x.y;
      te[14] = x.z;
    } else {
      te[12] = (x as num).toDouble();
      te[13] = y!;
      te[14] = z!;
    }

    return this;
  }

  /// Inverts this matrix, using the
  /// [analytic method](https://en.wikipedia.org/wiki/Invertible_matrix#Analytic_solution). You can not
  /// invert with a determinant of zero. If you attempt this, the method produces a zero matrix instead.
  Matrix4 invert() {
    // based on https://github.com/toji/gl-matrix
    final te = elements,
        n11 = te[0],
        n21 = te[1],
        n31 = te[2],
        n41 = te[3],
        n12 = te[4],
        n22 = te[5],
        n32 = te[6],
        n42 = te[7],
        n13 = te[8],
        n23 = te[9],
        n33 = te[10],
        n43 = te[11],
        n14 = te[12],
        n24 = te[13],
        n34 = te[14],
        n44 = te[15],
        t1 = n11 * n22 - n21 * n12,
        t2 = n11 * n32 - n31 * n12,
        t3 = n11 * n42 - n41 * n12,
        t4 = n21 * n32 - n31 * n22,
        t5 = n21 * n42 - n41 * n22,
        t6 = n31 * n42 - n41 * n32,
        t7 = n13 * n24 - n23 * n14,
        t8 = n13 * n34 - n33 * n14,
        t9 = n13 * n44 - n43 * n14,
        t10 = n23 * n34 - n33 * n24,
        t11 = n23 * n44 - n43 * n24,
        t12 = n33 * n44 - n43 * n34;

    final det = t1 * t12 - t2 * t11 + t3 * t10 + t4 * t9 - t5 * t8 + t6 * t7;

    if (det == 0) {
      return set(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    }

    final detInv = 1 / det;

    te[0] = (n22 * t12 - n32 * t11 + n42 * t10) * detInv;
    te[1] = (n31 * t11 - n21 * t12 - n41 * t10) * detInv;
    te[2] = (n24 * t6 - n34 * t5 + n44 * t4) * detInv;
    te[3] = (n33 * t5 - n23 * t6 - n43 * t4) * detInv;

    te[4] = (n32 * t9 - n12 * t12 - n42 * t8) * detInv;
    te[5] = (n11 * t12 - n31 * t9 + n41 * t8) * detInv;
    te[6] = (n34 * t3 - n14 * t6 - n44 * t2) * detInv;
    te[7] = (n13 * t6 - n33 * t3 + n43 * t2) * detInv;

    te[8] = (n12 * t11 - n22 * t9 + n42 * t7) * detInv;
    te[9] = (n21 * t9 - n11 * t11 - n41 * t7) * detInv;
    te[10] = (n14 * t5 - n24 * t3 + n44 * t1) * detInv;
    te[11] = (n23 * t3 - n13 * t5 - n43 * t1) * detInv;

    te[12] = (n22 * t8 - n12 * t10 - n32 * t7) * detInv;
    te[13] = (n11 * t10 - n21 * t8 + n31 * t7) * detInv;
    te[14] = (n24 * t2 - n14 * t4 - n34 * t1) * detInv;
    te[15] = (n13 * t4 - n23 * t2 + n33 * t1) * detInv;

    return this;
  }

  /// Scales each of the first three columns of this matrix by the corresponding component of the given
  /// vector.
  Matrix4 scale(Vector3 v) {
    final te = elements;
    final x = v.x, y = v.y, z = v.z;

    te[0] *= x;
    te[4] *= y;
    te[8] *= z;
    te[1] *= x;
    te[5] *= y;
    te[9] *= z;
    te[2] *= x;
    te[6] *= y;
    te[10] *= z;
    te[3] *= x;
    te[7] *= y;
    te[11] *= z;

    return this;
  }

  /// Gets the maximum scale value of the three axes.
  double getMaxScaleOnAxis() {
    final te = elements;

    final scaleXSq = te[0] * te[0] + te[1] * te[1] + te[2] * te[2];
    final scaleYSq = te[4] * te[4] + te[5] * te[5] + te[6] * te[6];
    final scaleZSq = te[8] * te[8] + te[9] * te[9] + te[10] * te[10];

    return math.sqrt(math.max(math.max(scaleXSq, scaleYSq), scaleZSq));
  }

  /// Sets this matrix as a translation transform from the given vector.
  ///
  /// `x` is the amount to translate in the X axis (a number) or alternatively a translation vector
  /// ([Vector3]); `y` and `z` are used only with a number.
  Matrix4 makeTranslation(Object x, [double? y, double? z]) {
    if (x is Vector3) {
      set(1, 0, 0, x.x, 0, 1, 0, x.y, 0, 0, 1, x.z, 0, 0, 0, 1);
    } else {
      set(1, 0, 0, (x as num).toDouble(), 0, 1, 0, y!, 0, 0, 1, z!, 0, 0, 0, 1);
    }

    return this;
  }

  /// Sets this matrix as a rotational transformation around the X axis by the given angle (in radians).
  Matrix4 makeRotationX(double theta) {
    final c = math.cos(theta), s = math.sin(theta);

    set(1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0, 0, 0, 0, 1);

    return this;
  }

  /// Sets this matrix as a rotational transformation around the Y axis by the given angle (in radians).
  Matrix4 makeRotationY(double theta) {
    final c = math.cos(theta), s = math.sin(theta);

    set(c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0, 0, 0, 0, 1);

    return this;
  }

  /// Sets this matrix as a rotational transformation around the Z axis by the given angle (in radians).
  Matrix4 makeRotationZ(double theta) {
    final c = math.cos(theta), s = math.sin(theta);

    set(c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);

    return this;
  }

  /// Sets this matrix as a rotational transformation around the given (normalized) axis by the given angle
  /// (in radians).
  Matrix4 makeRotationAxis(Vector3 axis, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    final t = 1 - c;
    final x = axis.x, y = axis.y, z = axis.z;
    final tx = t * x, ty = t * y;

    set(
      tx * x + c,
      tx * y - s * z,
      tx * z + s * y,
      0,
      tx * y + s * z,
      ty * y + c,
      ty * z - s * x,
      0,
      tx * z - s * y,
      ty * z + s * x,
      t * z * z + c,
      0,
      0,
      0,
      0,
      1,
    );

    return this;
  }

  /// Sets this matrix as a scale transformation.
  Matrix4 makeScale(double x, double y, double z) {
    set(x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0, 0, 0, 0, 1);

    return this;
  }

  /// Sets this matrix as a shear transformation: `xy` shears X by Y, `xz` X by Z, `yx` Y by X, `yz` Y by Z,
  /// `zx` Z by X and `zy` Z by Y.
  Matrix4 makeShear(double xy, double xz, double yx, double yz, double zx, double zy) {
    set(1, yx, zx, 0, xy, 1, zy, 0, xz, yz, 1, 0, 0, 0, 0, 1);

    return this;
  }

  /// Sets this matrix to the transformation composed of the given position, rotation (Quaternion) and scale.
  Matrix4 compose(Vector3 position, Quaternion quaternion, Vector3 scale) {
    final te = elements;

    final x = quaternion._x, y = quaternion._y, z = quaternion._z, w = quaternion._w;
    final x2 = x + x, y2 = y + y, z2 = z + z;
    final xx = x * x2, xy = x * y2, xz = x * z2;
    final yy = y * y2, yz = y * z2, zz = z * z2;
    final wx = w * x2, wy = w * y2, wz = w * z2;

    final sx = scale.x, sy = scale.y, sz = scale.z;

    te[0] = (1 - (yy + zz)) * sx;
    te[1] = (xy + wz) * sx;
    te[2] = (xz - wy) * sx;
    te[3] = 0;

    te[4] = (xy - wz) * sy;
    te[5] = (1 - (xx + zz)) * sy;
    te[6] = (yz + wx) * sy;
    te[7] = 0;

    te[8] = (xz + wy) * sz;
    te[9] = (yz - wx) * sz;
    te[10] = (1 - (xx + yy)) * sz;
    te[11] = 0;

    te[12] = position.x;
    te[13] = position.y;
    te[14] = position.z;
    te[15] = 1;

    return this;
  }

  /// Decomposes this matrix into its position, rotation and scale components and provides the result in the
  /// given objects.
  ///
  /// Note: Not all matrices are decomposable in this way. For example, if an object has a non-uniformly
  /// scaled parent, then the object's world matrix may not be decomposable, and this method may not be
  /// appropriate.
  Matrix4 decompose(Vector3 position, Quaternion quaternion, Vector3 scale) {
    final te = elements;

    position.x = te[12];
    position.y = te[13];
    position.z = te[14];

    final det = determinantAffine();

    if (det == 0) {
      scale.set(1, 1, 1);
      quaternion.identity();

      return this;
    }

    var sx = _matrix4V1.set(te[0], te[1], te[2]).length();
    final sy = _matrix4V1.set(te[4], te[5], te[6]).length();
    final sz = _matrix4V1.set(te[8], te[9], te[10]).length();

    // if determinant is negative, we need to invert one scale
    if (det < 0) {
      sx = -sx;
    }

    // scale the rotation part
    _matrix4M1.copy(this);

    final invSX = 1 / sx;
    final invSY = 1 / sy;
    final invSZ = 1 / sz;

    _matrix4M1.elements[0] *= invSX;
    _matrix4M1.elements[1] *= invSX;
    _matrix4M1.elements[2] *= invSX;

    _matrix4M1.elements[4] *= invSY;
    _matrix4M1.elements[5] *= invSY;
    _matrix4M1.elements[6] *= invSY;

    _matrix4M1.elements[8] *= invSZ;
    _matrix4M1.elements[9] *= invSZ;
    _matrix4M1.elements[10] *= invSZ;

    quaternion.setFromRotationMatrix(_matrix4M1);

    scale.x = sx;
    scale.y = sy;
    scale.z = sz;

    return this;
  }

  /// Creates a perspective projection matrix. This is used internally by
  /// `PerspectiveCamera.updateProjectionMatrix()`.
  ///
  /// `left`, `right`, `top` and `bottom` are the boundaries of the viewing frustum at the near plane; `near`
  /// and `far` the distances from the camera to the near and far planes. `coordinateSystem` is
  /// [WebGLCoordinateSystem] (default) or [WebGPUCoordinateSystem]; `reversedDepth` (default `false`)
  /// selects a reversed depth. Throws a [EntError] for any other coordinate system.
  Matrix4 makePerspective(
    double left,
    double right,
    double top,
    double bottom,
    double near,
    double far, [
    int coordinateSystem = WebGLCoordinateSystem,
    bool reversedDepth = false,
  ]) {
    final te = elements;

    final x = 2 * near / (right - left);
    final y = 2 * near / (top - bottom);

    final a = (right + left) / (right - left);
    final b = (top + bottom) / (top - bottom);

    double c, d;

    if (reversedDepth) {
      c = near / (far - near);
      d = (far * near) / (far - near);
    } else {
      if (coordinateSystem == WebGLCoordinateSystem) {
        c = -(far + near) / (far - near);
        d = (-2 * far * near) / (far - near);
      } else if (coordinateSystem == WebGPUCoordinateSystem) {
        c = -far / (far - near);
        d = (-far * near) / (far - near);
      } else {
        throw EntError('ENT.Matrix4.makePerspective(): Invalid coordinate system: $coordinateSystem');
      }
    }

    te[0] = x;
    te[4] = 0;
    te[8] = a;
    te[12] = 0;
    te[1] = 0;
    te[5] = y;
    te[9] = b;
    te[13] = 0;
    te[2] = 0;
    te[6] = 0;
    te[10] = c;
    te[14] = d;
    te[3] = 0;
    te[7] = 0;
    te[11] = -1;
    te[15] = 0;

    return this;
  }

  /// Creates a orthographic projection matrix. This is used internally by
  /// `OrthographicCamera.updateProjectionMatrix()`.
  ///
  /// `left`, `right`, `top` and `bottom` are the boundaries of the viewing frustum at the near plane; `near`
  /// and `far` the distances from the camera to the near and far planes. `coordinateSystem` is
  /// [WebGLCoordinateSystem] (default) or [WebGPUCoordinateSystem]; `reversedDepth` (default `false`)
  /// selects a reversed depth. Throws a [EntError] for any other coordinate system.
  Matrix4 makeOrthographic(
    double left,
    double right,
    double top,
    double bottom,
    double near,
    double far, [
    int coordinateSystem = WebGLCoordinateSystem,
    bool reversedDepth = false,
  ]) {
    final te = elements;

    final x = 2 / (right - left);
    final y = 2 / (top - bottom);

    final a = -(right + left) / (right - left);
    final b = -(top + bottom) / (top - bottom);

    double c, d;

    if (reversedDepth) {
      c = 1 / (far - near);
      d = far / (far - near);
    } else {
      if (coordinateSystem == WebGLCoordinateSystem) {
        c = -2 / (far - near);
        d = -(far + near) / (far - near);
      } else if (coordinateSystem == WebGPUCoordinateSystem) {
        c = -1 / (far - near);
        d = -near / (far - near);
      } else {
        throw EntError('ENT.Matrix4.makeOrthographic(): Invalid coordinate system: $coordinateSystem');
      }
    }

    te[0] = x;
    te[4] = 0;
    te[8] = 0;
    te[12] = a;
    te[1] = 0;
    te[5] = y;
    te[9] = 0;
    te[13] = b;
    te[2] = 0;
    te[6] = 0;
    te[10] = c;
    te[14] = d;
    te[3] = 0;
    te[7] = 0;
    te[11] = 0;
    te[15] = 1;

    return this;
  }

  /// Returns `true` if this matrix is equal with the given one.
  bool equals(Matrix4 matrix) {
    final te = elements;
    final me = matrix.elements;

    for (var i = 0; i < 16; i++) {
      if (te[i] != me[i]) {
        return false;
      }
    }

    return true;
  }

  /// Sets the elements of the matrix from the given array (column-major order), starting at `offset`.
  Matrix4 fromArray(List<num> array, [int offset = 0]) {
    for (var i = 0; i < 16; i++) {
      elements[i] = array[i + offset].toDouble();
    }

    return this;
  }

  /// Writes the elements of this matrix (column-major order) to the given array, starting at `offset`. If no
  /// array is provided, the method returns a new one.
  List<double> toArray([List<double>? array, int offset = 0]) {
    array ??= <double>[];
    final te = elements;

    for (var i = 0; i < 16; i++) {
      _jsArraySet(array, offset + i, te[i]);
    }

    return array;
  }
}

final _matrix4V1 = Vector3();
final _matrix4M1 = Matrix4();
final _matrix4Zero = Vector3(0, 0, 0);
final _matrix4One = Vector3(1, 1, 1);
final _matrix4X = Vector3();
final _matrix4Y = Vector3();
final _matrix4Z = Vector3();
