part of '../../../ent.dart';

/// A track for Quaternion keyframe values.
class QuaternionKeyframeTrack extends KeyframeTrack {
  /// Constructs a new Quaternion keyframe track.
  QuaternionKeyframeTrack(super.name, super.times, super.values, [super.interpolation]);

  @override
  String get ValueTypeName => 'quaternion';

  @override
  KeyframeInterpolantFactory? get _factorySmooth => null;

  /// Overwritten so the method returns Quaternion based interpolant.
  @override
  Interpolant InterpolantFactoryMethodLinear([List<Object?>? result]) {
    return QuaternionLinearInterpolant(
      times,
      values as List<double>,
      _keyframeValueSize(this),
      result as List<double>?,
    );
  }

  @override
  QuaternionKeyframeTrack _create(String name, List<Object?> times, List<Object?> values) {
    return QuaternionKeyframeTrack(name, times, values);
  }

  @override
  QuaternionKeyframeTrack clone() => super.clone() as QuaternionKeyframeTrack;
}
