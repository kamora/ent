part of '../../../ent.dart';

/// A track for numeric keyframe values.
class NumberKeyframeTrack extends KeyframeTrack {
  /// Constructs a new number keyframe track.
  NumberKeyframeTrack(super.name, super.times, super.values, [super.interpolation]);

  @override
  String get ValueTypeName => 'number';

  @override
  NumberKeyframeTrack _create(String name, List<Object?> times, List<Object?> values) {
    return NumberKeyframeTrack(name, times, values);
  }

  @override
  NumberKeyframeTrack clone() => super.clone() as NumberKeyframeTrack;
}
