part of '../../../ent.dart';

/// A track for string keyframe values.
class StringKeyframeTrack extends KeyframeTrack {
  /// Constructs a new string keyframe track. It has no interpolation parameter: its interpolation is always
  /// discrete.
  StringKeyframeTrack(super.name, super.times, super.values);

  @override
  String get ValueTypeName => 'string';

  @override
  String get ValueBufferType => 'Array';

  @override
  int get DefaultInterpolation => InterpolateDiscrete;

  @override
  KeyframeInterpolantFactory? get _factoryLinear => null;

  @override
  KeyframeInterpolantFactory? get _factorySmooth => null;

  @override
  StringKeyframeTrack _create(String name, List<Object?> times, List<Object?> values) {
    return StringKeyframeTrack(name, times, values);
  }

  @override
  StringKeyframeTrack clone() => super.clone() as StringKeyframeTrack;
}
