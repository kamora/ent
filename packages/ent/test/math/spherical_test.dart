// The reference unit tests of Spherical.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';

// QUnit's propEqual compares own enumerable properties.
List<double> _props(Spherical s) => [s.radius, s.phi, s.theta];

void main() {
  group('Maths', () {
    group('Spherical', () {
      // INSTANCING
      test('Instancing', () {
        var a = Spherical();
        const radius = 10.0;
        final phi = math.acos(-0.5);
        final theta = math.sqrt(math.pi) * phi;

        expect(a.radius, 1.0, reason: 'Default values: check radius');
        expect(a.phi, 0, reason: 'Default values: check phi');
        expect(a.theta, 0, reason: 'Default values: check theta');

        a = Spherical(radius, phi, theta);
        expect(a.radius, radius, reason: 'Custom values: check radius');
        expect(a.phi, phi, reason: 'Custom values: check phi');
        expect(a.theta, theta, reason: 'Custom values: check theta');
      });

      // PUBLIC STUFF
      test('set', () {
        final a = Spherical();
        const radius = 10.0;
        final phi = math.acos(-0.5);
        final theta = math.sqrt(math.pi) * phi;

        a.set(radius, phi, theta);
        expect(a.radius, radius, reason: 'Check radius');
        expect(a.phi, phi, reason: 'Check phi');
        expect(a.theta, theta, reason: 'Check theta');
      });

      test('clone', () {
        const radius = 10.0;
        final phi = math.acos(-0.5);
        final theta = math.sqrt(math.pi) * phi;
        final a = Spherical(radius, phi, theta);
        final b = a.clone();

        expect(_props(a), _props(b), reason: 'Check a and b are equal after clone()');

        a.radius = 2.0;
        expect(_props(a), isNot(_props(b)), reason: 'Check a and b are not equal after modification');
      });

      test('copy', () {
        const radius = 10.0;
        final phi = math.acos(-0.5);
        final theta = math.sqrt(math.pi) * phi;
        final a = Spherical(radius, phi, theta);
        final b = Spherical().copy(a);

        expect(_props(a), _props(b), reason: 'Check a and b are equal after copy()');

        a.radius = 2.0;
        expect(_props(a), isNot(_props(b)), reason: 'Check a and b are not equal after modification');
      });

      test('makeSafe', () {
        const EPS = 0.000001; // from source
        const tooLow = 0.0;
        const tooHigh = math.pi;
        const justRight = 1.5;
        final a = Spherical(1, tooLow, 0);

        a.makeSafe();
        expect(a.phi, EPS, reason: 'Check if small values are set to EPS');

        a.set(1, tooHigh, 0);
        a.makeSafe();
        expect(a.phi, math.pi - EPS, reason: 'Check if high values are set to (Math.PI - EPS)');

        a.set(1, justRight, 0);
        a.makeSafe();
        expect(a.phi, justRight, reason: "Check that valid values don't get changed");
      });

      test('setFromVector3', () {
        final a = Spherical(1, 1, 1);
        final b = Vector3(0, 0, 0);
        final c = Vector3(math.pi, 1, -math.pi);
        final expected = Spherical(4.554032147688322, 1.3494066171539107, 2.356194490192345);

        a.setFromVector3(b);
        expect(a.radius, 0, reason: 'Zero-length vector: check radius');
        expect(a.phi, 0, reason: 'Zero-length vector: check phi');
        expect(a.theta, 0, reason: 'Zero-length vector: check theta');

        a.setFromVector3(c);
        expect((a.radius - expected.radius).abs() <= eps, isTrue, reason: 'Normal vector: check radius');
        expect((a.phi - expected.phi).abs() <= eps, isTrue, reason: 'Normal vector: check phi');
        expect((a.theta - expected.theta).abs() <= eps, isTrue, reason: 'Normal vector: check theta');
      });

      test('setFromCartesianCoords', () {
        final a = Spherical(1, 1, 1);
        final expected = Spherical(4.554032147688322, 1.3494066171539107, 2.356194490192345);

        a.setFromCartesianCoords(0, 0, 0);
        expect(a.radius, 0, reason: 'Zero-length vector: check radius');
        expect(a.phi, 0, reason: 'Zero-length vector: check phi');
        expect(a.theta, 0, reason: 'Zero-length vector: check theta');

        a.setFromCartesianCoords(math.pi, 1, -math.pi);
        expect((a.radius - expected.radius).abs() <= eps, isTrue, reason: 'Normal vector: check radius');
        expect((a.phi - expected.phi).abs() <= eps, isTrue, reason: 'Normal vector: check phi');
        expect((a.theta - expected.theta).abs() <= eps, isTrue, reason: 'Normal vector: check theta');
      });
    });
  });
}
