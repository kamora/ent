part of '../../../ent.dart';

/// A track for boolean keyframe values.
class BooleanKeyframeTrack extends KeyframeTrack {
  /// Constructs a new boolean keyframe track. It has no interpolation parameter: its interpolation is always
  /// discrete.
  BooleanKeyframeTrack(super.name, super.times, super.values);

  @override
  String get ValueTypeName => 'bool';

  @override
  String get ValueBufferType => 'Array';

  @override
  int get DefaultInterpolation => InterpolateDiscrete;

  @override
  KeyframeInterpolantFactory? get _factoryLinear => null;

  @override
  KeyframeInterpolantFactory? get _factorySmooth => null;

  @override
  BooleanKeyframeTrack _create(String name, List<Object?> times, List<Object?> values) {
    return BooleanKeyframeTrack(name, times, values);
  }

  @override
  BooleanKeyframeTrack clone() => super.clone() as BooleanKeyframeTrack;
}
