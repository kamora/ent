// Fixture codecs for the interpolants group; state layouts follow tool/reference/js/types/interpolants.mjs.

import 'dart:typed_data';

import 'package:ent/ent.dart';

import '../fixtures.dart';

List<double> _array(String kind, List<double> values) {
  return switch (kind) {
    'Float32Array' => Float32List.fromList(values),
    'Float64Array' => Float64List.fromList(values),
    _ => List<double>.of(values),
  };
}

typedef _Factory = Interpolant Function(List<double> pp, List<double> values, int size, List<double> result);

Codec _codec(_Factory create) {
  return Codec(
    (s) {
      var at = 0;
      Object? next() => s[at++];
      int count() => (next() as double).toInt();
      List<double> list() => [for (var i = count(); i > 0; i--) next() as double];

      final kind = next() as String;
      final size = count();
      final cached = count();
      final pp = list();
      final values = list();
      final result = list();
      final interpolant = create(_array(kind, pp), _array(kind, values), size, _array(kind, result));
      final start = next();
      final end = next();

      interpolant.cachedIndex = cached;

      if (start != null || end != null) {
        interpolant.settings = {'endingStart': (start as double?)?.toInt(), 'endingEnd': (end as double?)?.toInt()};
      }

      final weights = [next(), next(), next(), next()];

      if (interpolant is CubicInterpolant) {
        interpolant
          ..weightPrev = weights[0]! as double
          ..offsetPrev = (weights[1] as double).toInt()
          ..weightNext = weights[2]! as double
          ..offsetNext = (weights[3] as double).toInt();
      }

      List<double>? tangents() {
        if (s[at] == -1) {
          at++;
          return null;
        }

        return _array(kind, list());
      }

      final inTangents = tangents();
      final outTangents = tangents();

      if (interpolant is BezierInterpolant) {
        interpolant
          ..inTangents = inTangents
          ..outTangents = outTangents;
      }

      return interpolant;
    },
    (o) {
      final v = o as Interpolant;
      final kind = switch (v.sampleValues) {
        Float32List() => 'Float32Array',
        Float64List() => 'Float64Array',
        _ => 'Array',
      };
      List<Object?> list(List<double>? a) => a == null ? [-1] : [a.length, ...a];
      final cubic = v is CubicInterpolant;
      final bezier = v is BezierInterpolant;

      return [
        kind,
        v.valueSize,
        v.cachedIndex,
        ...list(v.parameterPositions),
        ...list(v.sampleValues),
        ...list(v.resultBuffer),
        v.settings?['endingStart'],
        v.settings?['endingEnd'],
        cubic ? v.weightPrev : null,
        cubic ? v.offsetPrev : null,
        cubic ? v.weightNext : null,
        cubic ? v.offsetNext : null,
        ...(bezier ? list(v.inTangents) : [-1]),
        ...(bezier ? list(v.outTangents) : [-1]),
      ];
    },
  );
}

final Map<String, Codec> interpolantsCodecs = {
  'LinearInterpolant': _codec(LinearInterpolant.new),
  'DiscreteInterpolant': _codec(DiscreteInterpolant.new),
  'CubicInterpolant': _codec(CubicInterpolant.new),
  'QuaternionLinearInterpolant': _codec(QuaternionLinearInterpolant.new),
  'BezierInterpolant': _codec(BezierInterpolant.new),
};
