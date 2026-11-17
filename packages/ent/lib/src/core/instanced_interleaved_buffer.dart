part of '../../ent.dart';

/// An instanced version of an interleaved buffer.
class InstancedInterleavedBuffer extends InterleavedBuffer {
  /// Constructs a new instanced interleaved buffer; [meshPerAttribute] defaults to `1`.
  InstancedInterleavedBuffer([super.array, super.stride, this.meshPerAttribute = 1]);

  /// This flag can be used for type testing.
  bool get isInstancedInterleavedBuffer => true;

  /// Defines how often a value of this buffer attribute should be repeated, see
  /// [InstancedBufferAttribute.meshPerAttribute].
  int meshPerAttribute;

  /// Copies the values of the given interleaved buffer to this instance. `meshPerAttribute` is copied
  /// when [source] is instanced.
  @override
  InstancedInterleavedBuffer copy(InterleavedBuffer source) {
    super.copy(source);

    if (source is InstancedInterleavedBuffer) {
      meshPerAttribute = source.meshPerAttribute;
    }

    return this;
  }

  @override
  InstancedInterleavedBuffer clone(Map<String, Object?> data) {
    final ib = super.clone(data) as InstancedInterleavedBuffer;

    ib.meshPerAttribute = meshPerAttribute;

    return ib;
  }

  @override
  InstancedInterleavedBuffer _cloneWith(List<num> array, int stride) {
    return InstancedInterleavedBuffer(array, stride);
  }

  @override
  Map<String, Object?> toJSON(Map<String, Object?> data) {
    final json = super.toJSON(data);

    json['isInstancedInterleavedBuffer'] = true;
    json['meshPerAttribute'] = meshPerAttribute;

    return json;
  }
}
