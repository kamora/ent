part of '../../../ent.dart';

// Bezier curves:
// https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Specific_cases
// The module exports are not part of the reference's public entry point, so they are library-private here.

/// Computes a point on a Catmull-Rom spline.
double _catmullRom(double t, double p0, double p1, double p2, double p3) {
  final v0 = (p2 - p0) * 0.5;
  final v1 = (p3 - p1) * 0.5;
  final t2 = t * t;
  final t3 = t * t2;
  return (2 * p1 - 2 * p2 + v0 + v1) * t3 + (-3 * p1 + 3 * p2 - 2 * v0 - v1) * t2 + v0 * t + p1;
}

double _quadraticBezierP0(double t, double p) {
  final k = 1 - t;
  return k * k * p;
}

double _quadraticBezierP1(double t, double p) {
  return 2 * (1 - t) * t * p;
}

double _quadraticBezierP2(double t, double p) {
  return t * t * p;
}

/// Computes a point on a Quadratic Bezier curve.
double _quadraticBezier(double t, double p0, double p1, double p2) {
  return _quadraticBezierP0(t, p0) + _quadraticBezierP1(t, p1) + _quadraticBezierP2(t, p2);
}

double _cubicBezierP0(double t, double p) {
  final k = 1 - t;
  return k * k * k * p;
}

double _cubicBezierP1(double t, double p) {
  final k = 1 - t;
  return 3 * k * k * t * p;
}

double _cubicBezierP2(double t, double p) {
  return 3 * (1 - t) * t * t * p;
}

double _cubicBezierP3(double t, double p) {
  return t * t * t * p;
}

/// Computes a point on a Cubic Bezier curve.
double _cubicBezier(double t, double p0, double p1, double p2, double p3) {
  return _cubicBezierP0(t, p0) + _cubicBezierP1(t, p1) + _cubicBezierP2(t, p2) + _cubicBezierP3(t, p3);
}
