part of '../../../ent.dart';

/// A curve representing an arc.
class ArcCurve extends EllipseCurve {
  /// Constructs a new arc curve: center `aX`/`aY`, radius, start and end angles in radians, and whether the
  /// arc is drawn clockwise.
  ArcCurve([
    double aX = 0,
    double aY = 0,
    double aRadius = 1,
    double aStartAngle = 0,
    double aEndAngle = math.pi * 2,
    bool aClockwise = false,
  ]) : super(aX, aY, aRadius, aRadius, aStartAngle, aEndAngle, aClockwise) {
    type = 'ArcCurve';
  }

  /// This flag can be used for type testing.
  bool get isArcCurve => true;

  @override
  ArcCurve clone() {
    return ArcCurve().copy(this);
  }

  @override
  ArcCurve copy(EllipseCurve source) {
    super.copy(source);
    return this;
  }

  @override
  ArcCurve fromJSON(Map<String, Object?> json) {
    super.fromJSON(json);
    return this;
  }
}
