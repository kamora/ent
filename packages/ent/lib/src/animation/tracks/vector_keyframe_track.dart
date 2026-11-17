part of '../../../ent.dart';

/// A track for vector keyframe values.
class VectorKeyframeTrack extends KeyframeTrack {
  /// Constructs a new vector keyframe track.
  VectorKeyframeTrack(super.name, super.times, super.values, [super.interpolation]);

  @override
  String get ValueTypeName => 'vector';

  @override
  VectorKeyframeTrack _create(String name, List<Object?> times, List<Object?> values) {
    return VectorKeyframeTrack(name, times, values);
  }

  @override
  VectorKeyframeTrack clone() => super.clone() as VectorKeyframeTrack;
}
