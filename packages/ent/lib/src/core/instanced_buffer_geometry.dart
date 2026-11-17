part of '../../ent.dart';

/// An instanced version of a geometry.
class InstancedBufferGeometry extends BufferGeometry {
  /// Constructs a new instanced buffer geometry.
  InstancedBufferGeometry() {
    type = 'InstancedBufferGeometry';
  }

  /// This flag can be used for type testing.
  bool get isInstancedBufferGeometry => true;

  /// The instance count.
  double instanceCount = double.infinity;

  /// Returns a new instanced geometry with copied values from this instance. The reference inherits `clone()`, which
  /// builds `new this.constructor()`; Dart overrides it to keep the type (exception E-CLONE).
  @override
  InstancedBufferGeometry clone() {
    return InstancedBufferGeometry().copy(this);
  }

  @override
  InstancedBufferGeometry copy(BufferGeometry source) {
    super.copy(source);

    instanceCount = (source as InstancedBufferGeometry).instanceCount;

    return this;
  }

  @override
  Map<String, Object?> toJSON() {
    final data = super.toJSON();

    data['instanceCount'] = instanceCount;

    data['isInstancedBufferGeometry'] = true;

    return data;
  }
}
