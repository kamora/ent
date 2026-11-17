part of '../../../ent.dart';

/// A projector light version of [SpotLight]. Can only be used with `WebGPURenderer`.
class ProjectorLight extends SpotLight {
  /// Constructs a new projector light with the parameters of [SpotLight.new].
  ProjectorLight([super.color, super.intensity, super.distance, super.angle, super.penumbra, super.decay]);

  /// Aspect ratio of the light. Set to `null` to use the texture aspect ratio.
  double? aspect;

  @override
  ProjectorLight copy(covariant ProjectorLight source, [bool? recursive]) {
    super.copy(source, recursive);

    aspect = source.aspect;

    return this;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'aspect' => aspect,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'aspect':
        aspect = _jsDoubleOrNull(value);
      default:
        super[key] = value;
    }
  }

  @override
  ProjectorLight clone([bool? recursive]) {
    return ProjectorLight().copy(this, recursive);
  }
}
