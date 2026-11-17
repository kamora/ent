// The reference unit tests of Cylindrical.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

// QUnit's propEqual compares own enumerable properties.
List<double> _props(Cylindrical c) => [c.radius, c.theta, c.y];

void main() {
  group('Maths', () {
    group('Cylindrical', () {
      // INSTANCING
      test('Instancing', () {
        var a = Cylindrical();
        const radius = 10.0;
        const theta = math.pi;
        const y = 5.0;

        expect(a.radius, 1.0, reason: 'Default values: check radius');
        expect(a.theta, 0, reason: 'Default values: check theta');
        expect(a.y, 0, reason: 'Default values: check y');

        a = Cylindrical(radius, theta, y);
        expect(a.radius, radius, reason: 'Custom values: check radius');
        expect(a.theta, theta, reason: 'Custom values: check theta');
        expect(a.y, y, reason: 'Custom values: check y');
      });

      // PUBLIC
      test('set', () {
        final a = Cylindrical();
        const radius = 10.0;
        const theta = math.pi;
        const y = 5.0;

        a.set(radius, theta, y);
        expect(a.radius, radius, reason: 'Check radius');
        expect(a.theta, theta, reason: 'Check theta');
        expect(a.y, y, reason: 'Check y');
      });

      test('clone', () {
        const radius = 10.0;
        const theta = math.pi;
        const y = 5.0;
        final a = Cylindrical(radius, theta, y);
        final b = a.clone();

        expect(_props(a), _props(b), reason: 'Check a and b are equal after clone()');

        a.radius = 1;
        expect(_props(a), isNot(_props(b)), reason: 'Check a and b are not equal after modification');
      });

      test('copy', () {
        const radius = 10.0;
        const theta = math.pi;
        const y = 5.0;
        final a = Cylindrical(radius, theta, y);
        final b = Cylindrical().copy(a);

        expect(_props(a), _props(b), reason: 'Check a and b are equal after copy()');

        a.radius = 1;
        expect(_props(a), isNot(_props(b)), reason: 'Check a and b are not equal after modification');
      });

      test('setFromVector3', () {
        final a = Cylindrical(1, 1, 1);
        final b = Vector3(0, 0, 0);
        final c = Vector3(3, -1, -3);
        final expected = Cylindrical(math.sqrt(9 + 9), math.atan2(3, -3), -1);

        a.setFromVector3(b);
        expect(a.radius, 0, reason: 'Zero-length vector: check radius');
        expect(a.theta, 0, reason: 'Zero-length vector: check theta');
        expect(a.y, 0, reason: 'Zero-length vector: check y');

        a.setFromVector3(c);
        expect((a.radius - expected.radius).abs() <= eps, isTrue, reason: 'Normal vector: check radius');
        expect((a.theta - expected.theta).abs() <= eps, isTrue, reason: 'Normal vector: check theta');
        expect((a.y - expected.y).abs() <= eps, isTrue, reason: 'Normal vector: check y');
      });
    });
  });
}
