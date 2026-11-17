part of '../../../ent.dart';

/// A curve representing an ellipse.
///
/// ```dart
/// final curve = EllipseCurve(0, 0, 10, 10, 0, 2 * math.pi, false, 0);
/// final points = curve.getPoints(50);
/// final geometry = BufferGeometry().setFromPoints(points);
/// ```
class EllipseCurve extends Curve<Vector2> {
  /// Constructs a new ellipse curve: center `aX`/`aY`, radii `xRadius`/`yRadius`, the start and end angles in
  /// radians, whether the ellipse is drawn clockwise, and its rotation in radians around the center.
  EllipseCurve([
    this.aX = 0,
    this.aY = 0,
    this.xRadius = 1,
    this.yRadius = 1,
    this.aStartAngle = 0,
    this.aEndAngle = math.pi * 2,
    this.aClockwise = false,
    this.aRotation = 0,
  ]) {
    type = 'EllipseCurve';
  }

  /// This flag can be used for type testing.
  bool get isEllipseCurve => true;

  /// The X center of the ellipse.
  double aX;

  /// The Y center of the ellipse.
  double aY;

  /// The radius of the ellipse in the x direction. Setting the this value equal to the [yRadius] will result
  /// in a circle.
  double xRadius;

  /// The radius of the ellipse in the y direction. Setting the this value equal to the [xRadius] will result
  /// in a circle.
  double yRadius;

  /// The start angle of the curve in radians starting from the positive X axis.
  double aStartAngle;

  /// The end angle of the curve in radians starting from the positive X axis.
  double aEndAngle;

  /// Whether the ellipse is drawn clockwise or not.
  bool aClockwise;

  /// The rotation angle of the ellipse in radians, counterclockwise from the positive X axis.
  double aRotation;

  /// Returns a point on the curve.
  @override
  Vector2 getPoint(double t, [Vector2? optionalTarget]) {
    final point = optionalTarget ?? Vector2();

    const twoPi = math.pi * 2;
    var deltaAngle = aEndAngle - aStartAngle;
    final samePoints = deltaAngle.abs() < _curveNumberEpsilon;

    // ensures that deltaAngle is 0 .. 2 PI
    while (deltaAngle < 0) {
      deltaAngle += twoPi;
    }

    while (deltaAngle > twoPi) {
      deltaAngle -= twoPi;
    }

    if (deltaAngle < _curveNumberEpsilon) {
      if (samePoints) {
        deltaAngle = 0;
      } else {
        deltaAngle = twoPi;
      }
    }

    if (aClockwise == true && !samePoints) {
      if (deltaAngle == twoPi) {
        deltaAngle = -twoPi;
      } else {
        deltaAngle = deltaAngle - twoPi;
      }
    }

    final angle = aStartAngle + t * deltaAngle;
    var x = aX + xRadius * math.cos(angle);
    var y = aY + yRadius * math.sin(angle);

    if (aRotation != 0) {
      final cos = math.cos(aRotation);
      final sin = math.sin(aRotation);

      final tx = x - aX;
      final ty = y - aY;

      // Rotate the point about the center of the ellipse.
      x = tx * cos - ty * sin + aX;
      y = tx * sin + ty * cos + aY;
    }

    return point.set(x, y);
  }

  @override
  Vector2 getPointAt(double u, [Vector2? optionalTarget]) {
    return super.getPointAt(u, optionalTarget)!;
  }

  @override
  EllipseCurve clone() {
    return EllipseCurve().copy(this);
  }

  @override
  EllipseCurve copy(EllipseCurve source) {
    super.copy(source);

    aX = source.aX;
    aY = source.aY;

    xRadius = source.xRadius;
    yRadius = source.yRadius;

    aStartAngle = source.aStartAngle;
    aEndAngle = source.aEndAngle;

    aClockwise = source.aClockwise;

    aRotation = source.aRotation;

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['aX'] = aX;
    data['aY'] = aY;

    data['xRadius'] = xRadius;
    data['yRadius'] = yRadius;

    data['aStartAngle'] = aStartAngle;
    data['aEndAngle'] = aEndAngle;

    data['aClockwise'] = aClockwise;

    data['aRotation'] = aRotation;

    return data;
  }

  @override
  EllipseCurve fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);

    aX = (json['aX'] as num).toDouble();
    aY = (json['aY'] as num).toDouble();

    xRadius = (json['xRadius'] as num).toDouble();
    yRadius = (json['yRadius'] as num).toDouble();

    aStartAngle = (json['aStartAngle'] as num).toDouble();
    aEndAngle = (json['aEndAngle'] as num).toDouble();

    aClockwise = json['aClockwise'] as bool;

    aRotation = (json['aRotation'] as num).toDouble();

    return this;
  }
}
