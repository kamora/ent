part of '../../../ent.dart';

/// A track for color keyframe values.
class ColorKeyframeTrack extends KeyframeTrack {
  /// Constructs a new color keyframe track.
  ColorKeyframeTrack(super.name, super.times, super.values, [super.interpolation]);

  @override
  String get ValueTypeName => 'color';

  @override
  ColorKeyframeTrack _create(String name, List<Object?> times, List<Object?> values) {
    return ColorKeyframeTrack(name, times, values);
  }

  @override
  ColorKeyframeTrack clone() => super.clone() as ColorKeyframeTrack;
}
