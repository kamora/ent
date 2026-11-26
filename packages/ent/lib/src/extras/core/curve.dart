part of '../../../ent.dart';

//
// The reference's Curve works on Vector2 or Vector3 points depending on the subclass, by duck typing. The port makes
// that explicit: `Curve<T>` where `T` is the point type, `Vector2` for 2D curves (EllipseCurve, LineCurve, Path, Shape,
// ...) and `Vector3` for 3D curves (LineCurve3, CatmullRomCurve3, ...). The few operations the base class needs on
// points (distance, equality, tangent difference) dispatch on the runtime type (exception E-CURVE).

/// `Number.EPSILON`.
const double _curveNumberEpsilon = 2.220446049250313e-16;

/// The Frenet frames of a 3D curve, as returned by [Curve.computeFrenetFrames]: the reference's
/// `{ tangents, normals, binormals }` object as a record with the same field names (E-OBJECT).
typedef FrenetFrames = ({List<Vector3> tangents, List<Vector3> normals, List<Vector3> binormals});

double _curveDistance(Object a, Object b) {
  return switch (a) {
    Vector2 v => v.distanceTo(b as Vector2),
    Vector3 v => v.distanceTo(b as Vector3),
    _ => throw ArgumentError('Curve points must be Vector2 or Vector3, got ${a.runtimeType}'),
  };
}

bool _curveEquals(Object a, Object b) {
  return switch (a) {
    Vector2 v => b is Vector2 && v.equals(b),
    Vector3 v => b is Vector3 && v.equals(b),
    _ => throw ArgumentError('Curve points must be Vector2 or Vector3, got ${a.runtimeType}'),
  };
}

/// A list element as JavaScript reads it: `NaN` (in the reference: `undefined`, which turns arithmetic into NaN) for an
/// index outside the list.
double _curveAt(List<double> list, int index) {
  if (index < 0 || index >= list.length) {
    return double.nan;
  }

  return list[index];
}

/// An abstract base class for creating an analytic curve object that contains methods for interpolation.
///
/// `T` is the point type: [Vector2] for curves in 2D space, [Vector3] for curves in 3D space.
class Curve<T extends Object> {
  /// Constructs a new curve.
  Curve();

  /// The type property is used for detecting the object type in context of serialization/deserialization.
  String type = 'Curve';

  /// This value determines the amount of divisions when calculating the cumulative segment lengths of a curve
  /// via [getLengths]. To ensure precision when using methods like [getSpacedPoints], it is recommended to
  /// increase the value of this property if the curve is very large.
  int arcLengthDivisions = 200;

  /// Must be set to `true` if the curve parameters have changed.
  bool needsUpdate = false;

  /// An internal cache that holds precomputed curve length values.
  List<double>? cacheArcLengths;

  /// This method returns a vector in 2D or 3D space (depending on the curve definition) for the given
  /// interpolation factor.
  ///
  /// The base class has no curve definition: it warns and returns `null` (`undefined` in the reference). Subclasses
  /// return a non-null point.
  T? getPoint(double t, [T? optionalTarget]) {
    warn('Curve: .getPoint() not implemented.');
    return null;
  }

  /// This method returns a vector in 2D or 3D space (depending on the curve definition) for the given
  /// interpolation factor. Unlike [getPoint], this method honors the length of the curve which equidistant
  /// samples.
  T? getPointAt(double u, [T? optionalTarget]) {
    final t = getUtoTmapping(u);
    return getPoint(t, optionalTarget);
  }

  /// This method samples the curve via [getPoint] and returns an array of points representing the curve
  /// shape.
  List<T> getPoints([int divisions = 5]) {
    final points = <T>[];

    for (var d = 0; d <= divisions; d++) {
      points.add(getPoint(d / divisions) as T);
    }

    return points;
  }

  // Get sequence of points using getPointAt( u )

  /// This method samples the curve via [getPointAt] and returns an array of points representing the curve
  /// shape. Unlike [getPoints], this method returns equi-spaced points across the entire curve.
  List<T> getSpacedPoints([int divisions = 5]) {
    final points = <T>[];

    for (var d = 0; d <= divisions; d++) {
      points.add(getPointAt(d / divisions) as T);
    }

    return points;
  }

  /// Returns the total arc length of the curve.
  double getLength() {
    final lengths = getLengths();
    return lengths[lengths.length - 1];
  }

  /// Returns an array of cumulative segment lengths of the curve. `divisions` defaults to
  /// [arcLengthDivisions].
  List<double> getLengths([int? divisions]) {
    divisions ??= arcLengthDivisions;

    final cache = cacheArcLengths;

    if (cache != null && cache.length == divisions + 1 && !needsUpdate) {
      return cache;
    }

    needsUpdate = false;

    final lengths = <double>[];
    Object current;
    var last = getPoint(0) as Object;
    var sum = 0.0;

    lengths.add(0);

    for (var p = 1; p <= divisions; p++) {
      current = getPoint(p / divisions) as Object;
      sum += _curveDistance(current, last);
      lengths.add(sum);
      last = current;
    }

    cacheArcLengths = lengths;

    return lengths; // { sums: cache, sum: sum }; Sum is in the last element.
  }

  /// Update the cumulative segment distance cache. The method must be called every time curve parameters are
  /// changed. If an updated curve is part of a composed curve like [CurvePath], this method must be called on
  /// the composed curve, too.
  void updateArcLengths() {
    needsUpdate = true;
    getLengths();
  }

  /// Given an interpolation factor in the range `[0,1]`, this method returns an updated interpolation factor
  /// in the same range that can be ued to sample equidistant points from a curve.
  ///
  /// A non-zero `distance` is used as the targeted arc length instead of `u`.
  double getUtoTmapping(double u, [double? distance]) {
    final arcLengths = getLengths();

    var i = 0;
    final il = arcLengths.length;

    double targetArcLength; // The targeted u distance value to get

    // The reference tests `if ( distance )`: null, 0 and NaN fall back to u.
    if (distance != null && distance != 0 && !distance.isNaN) {
      targetArcLength = distance;
    } else {
      targetArcLength = u * arcLengths[il - 1];
    }

    // binary search for the index with largest value smaller than target u distance

    var low = 0, high = il - 1;
    double comparison;

    while (low <= high) {
      i = low + (high - low) ~/ 2; // less likely to overflow, though probably not issue here, JS doesn't really have integers, all numbers are floats

      comparison = arcLengths[i] - targetArcLength;

      if (comparison < 0) {
        low = i + 1;
      } else if (comparison > 0) {
        high = i - 1;
      } else {
        high = i;
        break;

        // DONE
      }
    }

    i = high;

    if (_curveAt(arcLengths, i) == targetArcLength) {
      return i / (il - 1);
    }

    // we could get finer grain at lengths, or use simple interpolation between two points

    final lengthBefore = _curveAt(arcLengths, i);
    final lengthAfter = _curveAt(arcLengths, i + 1);

    final segmentLength = lengthAfter - lengthBefore;

    // determine where we are between the 'before' and 'after' points

    final segmentFraction = (targetArcLength - lengthBefore) / segmentLength;

    // add that fractional amount to t

    final t = (i + segmentFraction) / (il - 1);

    return t;
  }

  /// Returns a unit vector tangent for the given interpolation factor. If the derived curve does not implement
  /// its tangent derivation, two points a small delta apart will be used to find its gradient which seems to
  /// give a reasonable approximation.
  T getTangent(double t, [T? optionalTarget]) {
    const delta = 0.0001;
    var t1 = t - delta;
    var t2 = t + delta;

    // Capping in case of danger

    if (t1 < 0) {
      t1 = 0;
    }

    if (t2 > 1) {
      t2 = 1;
    }

    final pt1 = getPoint(t1) as Object;
    final pt2 = getPoint(t2) as Object;

    final tangent = optionalTarget ?? (pt1 is Vector2 ? Vector2() : Vector3()) as T;

    switch (tangent) {
      case Vector2 v:
        v.copy(pt2 as Vector2).sub(pt1 as Vector2).normalize();
      case Vector3 v:
        v.copy(pt2 as Vector3).sub(pt1 as Vector3).normalize();
    }

    return tangent;
  }

  /// Same as [getTangent] but with equidistant samples (see [getPointAt]).
  T getTangentAt(double u, [T? optionalTarget]) {
    final t = getUtoTmapping(u);
    return getTangent(t, optionalTarget);
  }

  /// Generates the Frenet Frames. Requires a curve definition in 3D space (`Curve<Vector3>`). Used in
  /// geometries like [TubeGeometry] or [ExtrudeGeometry].
  FrenetFrames computeFrenetFrames(int segments, [bool closed = false]) {
    // see http://www.cs.indiana.edu/pub/techreports/TR425.pdf

    final normal = Vector3();

    final tangents = <Vector3>[];
    final normals = <Vector3>[];
    final binormals = <Vector3>[];

    final vec = Vector3();
    final mat = Matrix4();

    // compute the tangent vectors for each segment on the curve

    for (var i = 0; i <= segments; i++) {
      final u = i / segments;

      tangents.add(getTangentAt(u, Vector3() as T) as Vector3);
    }

    // select an initial normal vector perpendicular to the first tangent vector,
    // and in the direction of the minimum tangent xyz component

    normals.add(Vector3());
    binormals.add(Vector3());
    var min = double.maxFinite;
    final tx = tangents[0].x.abs();
    final ty = tangents[0].y.abs();
    final tz = tangents[0].z.abs();

    if (tx <= min) {
      min = tx;
      normal.set(1, 0, 0);
    }

    if (ty <= min) {
      min = ty;
      normal.set(0, 1, 0);
    }

    if (tz <= min) {
      normal.set(0, 0, 1);
    }

    vec.crossVectors(tangents[0], normal).normalize();

    normals[0].crossVectors(tangents[0], vec);
    binormals[0].crossVectors(tangents[0], normals[0]);

    // compute the slowly-varying normal and binormal vectors for each segment on the curve

    for (var i = 1; i <= segments; i++) {
      normals.add(normals[i - 1].clone());

      binormals.add(binormals[i - 1].clone());

      vec.crossVectors(tangents[i - 1], tangents[i]);

      if (vec.length() > _curveNumberEpsilon) {
        vec.normalize();

        final theta = math.acos(
          MathUtils.clamp(tangents[i - 1].dot(tangents[i]), -1, 1),
        ); // clamp for floating pt errors

        normals[i].applyMatrix4(mat.makeRotationAxis(vec, theta));
      }

      binormals[i].crossVectors(tangents[i], normals[i]);
    }

    // if the curve is closed, postprocess the vectors so the first and last normal vectors are the same

    if (closed == true) {
      var theta = math.acos(MathUtils.clamp(normals[0].dot(normals[segments]), -1, 1));
      theta /= segments;

      if (tangents[0].dot(vec.crossVectors(normals[0], normals[segments])) > 0) {
        theta = -theta;
      }

      for (var i = 1; i <= segments; i++) {
        // twist a little...
        normals[i].applyMatrix4(mat.makeRotationAxis(tangents[i], theta * i));
        binormals[i].crossVectors(tangents[i], normals[i]);
      }
    }

    return (tangents: tangents, normals: normals, binormals: binormals);
  }

  /// Returns a new curve with copied values from this instance. Subclasses override it (E-CLONE).
  Curve<T> clone() {
    return Curve<T>().copy(this);
  }

  /// Copies the values of the given curve to this instance.
  Curve<T> copy(covariant Curve<T> source) {
    arcLengthDivisions = source.arcLengthDivisions;

    cacheArcLengths = null;

    return this;
  }

  /// Serializes the curve into JSON (see [ObjectLoader.parse]).
  Map<String, Object?> toJSON() {
    final data = <String, Object?>{
      'metadata': <String, Object?>{'version': 4.7, 'type': 'Curve', 'generator': 'Curve.toJSON'},
    };

    data['arcLengthDivisions'] = arcLengthDivisions;
    data['type'] = type;

    return data;
  }

  /// Deserializes the curve from the given JSON.
  Curve<T> fromJSON(Map<String, Object?> json) {
    arcLengthDivisions = (json['arcLengthDivisions'] as num).toInt();

    cacheArcLengths = null;

    return this;
  }
}
