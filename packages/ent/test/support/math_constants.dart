// The shared values of the reference math unit tests. As in the reference, the vectors are shared instances; tests must
// not mutate them.

import 'package:ent/ent.dart';

const double x = 2;
const double y = 3;
const double z = 4;
const double w = 5;

final Vector2 negInf2 = Vector2(double.negativeInfinity, double.negativeInfinity);
final Vector2 posInf2 = Vector2(double.infinity, double.infinity);

final Vector2 negOne2 = Vector2(-1, -1);

final Vector2 zero2 = Vector2();
final Vector2 one2 = Vector2(1, 1);
final Vector2 two2 = Vector2(2, 2);

final Vector3 negInf3 = Vector3(double.negativeInfinity, double.negativeInfinity, double.negativeInfinity);
final Vector3 posInf3 = Vector3(double.infinity, double.infinity, double.infinity);

final Vector3 zero3 = Vector3();
final Vector3 one3 = Vector3(1, 1, 1);
final Vector3 two3 = Vector3(2, 2, 2);

const double eps = 0.0001;
