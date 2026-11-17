part of '../../ent.dart';

final _line3StartP = Vector3();
final _line3StartEnd = Vector3();

final _line3D1 = Vector3();
final _line3D2 = Vector3();
final _line3R = Vector3();
final _line3C1 = Vector3();
final _line3C2 = Vector3();

/// An analytical line segment in 3D space represented by a start and end point.
class Line3 {
  /// Constructs a new line segment. `start` and `end` default to `(0,0,0)`.
  Line3([Vector3? start, Vector3? end]) : start = start ?? Vector3(), end = end ?? Vector3();

  /// Start of the line segment.
  Vector3 start;

  /// End of the line segment.
  Vector3 end;

  /// Sets the start and end values by copying the given vectors.
  Line3 set(Vector3 start, Vector3 end) {
    this.start.copy(start);
    this.end.copy(end);

    return this;
  }

  /// Copies the values of the given line segment to this instance.
  Line3 copy(Line3 line) {
    start.copy(line.start);
    end.copy(line.end);

    return this;
  }

  /// Returns the center of the line segment.
  Vector3 getCenter(Vector3 target) {
    return target.addVectors(start, end).multiplyScalar(0.5);
  }

  /// Returns the delta vector of the line segment's start and end point.
  Vector3 delta(Vector3 target) {
    return target.subVectors(end, start);
  }

  /// Returns the squared Euclidean distance between the line' start and end point.
  double distanceSq() {
    return start.distanceToSquared(end);
  }

  /// Returns the Euclidean distance between the line' start and end point.
  double distance() {
    return start.distanceTo(end);
  }

  /// Returns a vector at a certain position along the line segment; `t` in `[0,1]` represents the position.
  Vector3 at(double t, Vector3 target) {
    return delta(target).multiplyScalar(t).add(start);
  }

  /// Returns a point parameter based on the closest point as projected on the line segment; `clampToLine`
  /// clamps the result to the range `[0,1]`.
  double closestPointToPointParameter(Vector3 point, bool clampToLine) {
    _line3StartP.subVectors(point, start);
    _line3StartEnd.subVectors(end, start);

    final startEnd2 = _line3StartEnd.dot(_line3StartEnd);

    if (startEnd2 == 0) {
      return 0;
    }

    final startEnd_startP = _line3StartEnd.dot(_line3StartP);

    var t = startEnd_startP / startEnd2;

    if (clampToLine) {
      t = MathUtils.clamp(t, 0, 1);
    }

    return t;
  }

  /// Returns the closest point on the line for a given point; `clampToLine` clamps the result to the
  /// segment.
  Vector3 closestPointToPoint(Vector3 point, bool clampToLine, Vector3 target) {
    final t = closestPointToPointParameter(point, clampToLine);

    return delta(target).multiplyScalar(t).add(start);
  }

  /// Returns the closest squared distance between this line segment and the given one. The optional `c1`
  /// and `c2` receive the closest point on this line segment and on the given one.
  double distanceSqToLine3(Line3 line, [Vector3? c1, Vector3? c2]) {
    c1 ??= _line3C1;
    c2 ??= _line3C2;

    // from Real-Time Collision Detection by Christer Ericson, chapter 5.1.9

    // Computes closest points C1 and C2 of S1(s)=P1+s*(Q1-P1) and
    // S2(t)=P2+t*(Q2-P2), returning s and t. Function result is squared
    // distance between between S1(s) and S2(t)

    const EPSILON = 1e-8 * 1e-8; // must be squared since we compare squared length
    double s, t;

    final p1 = start;
    final p2 = line.start;
    final q1 = end;
    final q2 = line.end;

    _line3D1.subVectors(q1, p1); // Direction vector of segment S1
    _line3D2.subVectors(q2, p2); // Direction vector of segment S2
    _line3R.subVectors(p1, p2);

    final a = _line3D1.dot(_line3D1); // Squared length of segment S1, always nonnegative
    final e = _line3D2.dot(_line3D2); // Squared length of segment S2, always nonnegative
    final f = _line3D2.dot(_line3R);

    // Check if either or both segments degenerate into points

    if (a <= EPSILON && e <= EPSILON) {
      // Both segments degenerate into points

      c1.copy(p1);
      c2.copy(p2);

      return c1.distanceToSquared(c2);
    }

    if (a <= EPSILON) {
      // First segment degenerates into a point

      s = 0;
      t = f / e; // s = 0 => t = (b*s + f) / e = f / e
      t = MathUtils.clamp(t, 0, 1);
    } else {
      final c = _line3D1.dot(_line3R);

      if (e <= EPSILON) {
        // Second segment degenerates into a point

        t = 0;
        s = MathUtils.clamp(-c / a, 0, 1); // t = 0 => s = (b*t - c) / a = -c / a
      } else {
        // The general nondegenerate case starts here

        final b = _line3D1.dot(_line3D2);
        final denom = a * e - b * b; // Always nonnegative

        // If segments not parallel, compute closest point on L1 to L2 and
        // clamp to segment S1. Else pick arbitrary s (here 0)

        if (denom != 0) {
          s = MathUtils.clamp((b * f - c * e) / denom, 0, 1);
        } else {
          s = 0;
        }

        // Compute point on L2 closest to S1(s) using
        // t = Dot((P1 + D1*s) - P2,D2) / Dot(D2,D2) = (b*s + f) / e

        t = (b * s + f) / e;

        // If t in [0,1] done. Else clamp t, recompute s for the new value
        // of t using s = Dot((P2 + D2*t) - P1,D1) / Dot(D1,D1)= (t*b - c) / a
        // and clamp s to [0, 1]

        if (t < 0) {
          t = 0.0;
          s = MathUtils.clamp(-c / a, 0, 1);
        } else if (t > 1) {
          t = 1;
          s = MathUtils.clamp((b - c) / a, 0, 1);
        }
      }
    }

    c1.copy(p1).addScaledVector(_line3D1, s);
    c2.copy(p2).addScaledVector(_line3D2, t);

    return c1.distanceToSquared(c2);
  }

  /// Applies a 4x4 transformation matrix to this line segment.
  Line3 applyMatrix4(Matrix4 matrix) {
    start.applyMatrix4(matrix);
    end.applyMatrix4(matrix);

    return this;
  }

  /// Returns `true` if this line segment is equal with the given one.
  bool equals(Line3 line) {
    return line.start.equals(start) && line.end.equals(end);
  }

  /// Returns a new line segment with copied values from this instance.
  Line3 clone() {
    return Line3().copy(this);
  }
}
