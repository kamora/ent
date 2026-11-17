part of '../../ent.dart';

/// An instanced version of a buffer attribute.
class InstancedBufferAttribute extends BufferAttribute {
  /// Constructs a new instanced buffer attribute; [meshPerAttribute] defaults to `1`.
  InstancedBufferAttribute([super.array, super.itemSize, super.normalized, this.meshPerAttribute = 1]);

  /// This flag can be used for type testing.
  bool get isInstancedBufferAttribute => true;

  /// Defines how often a value of this buffer attribute should be repeated. A value of one means that each
  /// value of the instanced attribute is used for a single instance. A value of two means that each value
  /// is used for two consecutive instances (and so on).
  int meshPerAttribute;

  /// Copies the values of the given buffer attribute to this instance. `meshPerAttribute` is copied when [source] is
  /// instanced (the reference reads it from any source, getting `undefined` otherwise).
  @override
  InstancedBufferAttribute copy(BufferAttribute source) {
    super.copy(source);

    if (source is InstancedBufferAttribute) {
      meshPerAttribute = source.meshPerAttribute;
    }

    return this;
  }

  @override
  InstancedBufferAttribute clone([Map<String, Object?>? data]) {
    return InstancedBufferAttribute(array, itemSize).copy(this);
  }

  @override
  Map<String, Object?> toJSON([Map<String, Object?>? data]) {
    final json = super.toJSON();

    json['meshPerAttribute'] = meshPerAttribute;

    json['isInstancedBufferAttribute'] = true;

    return json;
  }
}
