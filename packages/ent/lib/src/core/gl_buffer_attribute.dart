part of '../../ent.dart';

/// An alternative version of a buffer attribute with more control over the VBO.
///
/// The renderer does not construct a VBO for this kind of attribute. Instead, it uses whatever VBO is
/// passed in constructor and can later be altered via the `buffer` property.
///
/// The most common use case for this class is when some kind of GPGPU calculation interferes or even
/// produces the VBOs in question.
///
/// Notice that this class can only be used with the reference renderer. The buffer is a handle of the platform's GL
/// binding, so it is typed `Object` here (exception E-PLATFORM).
class GLBufferAttribute {
  /// Constructs a new GL buffer attribute. Omitted numbers (`undefined` in the reference) are `0`, an omitted buffer is
  /// `null`.
  GLBufferAttribute([this.buffer, int? type, int? itemSize, int? elementSize, int? count, this.normalized = false])
    : type = type ?? 0,
      itemSize = itemSize ?? 0,
      elementSize = elementSize ?? 0,
      count = count ?? 0;

  /// This flag can be used for type testing.
  bool get isGLBufferAttribute => true;

  /// The name of the buffer attribute.
  String name = '';

  /// The native WebGL buffer.
  Object? buffer;

  /// The native data type.
  int type;

  /// The item size, see [BufferAttribute.itemSize].
  int itemSize;

  /// The corresponding size (in bytes) for the given `type` parameter.
  int elementSize;

  /// The expected number of vertices in VBO.
  int count;

  /// Applies to integer data only. Indicates how the underlying data in the buffer maps to the values in
  /// the GLSL code. For instance, if `buffer` contains data of `gl.UNSIGNED_SHORT`, and `normalized` is
  /// `true`, the values `0 - +65535` in the buffer data will be mapped to `0.0f - +1.0f` in the GLSL
  /// attribute. If `normalized` is `false`, the values will be converted to floats unmodified, i.e. `65535`
  /// becomes `65535.0f`.
  bool normalized;

  /// A version number, incremented every time the `needsUpdate` is set to `true`.
  int version = 0;

  /// Flag to indicate that this attribute has changed and should be re-sent to the GPU. Set this to `true`
  /// when you modify the value of the array.
  set needsUpdate(bool value) {
    if (value == true) {
      version++;
    }
  }

  /// Sets the given native WebGL buffer.
  GLBufferAttribute setBuffer(Object? buffer) {
    this.buffer = buffer;

    return this;
  }

  /// Sets the given native data type and element size.
  GLBufferAttribute setType(int type, int elementSize) {
    this.type = type;
    this.elementSize = elementSize;

    return this;
  }

  /// Sets the item size.
  GLBufferAttribute setItemSize(int itemSize) {
    this.itemSize = itemSize;

    return this;
  }

  /// Sets the count (the expected number of vertices in VBO).
  GLBufferAttribute setCount(int count) {
    this.count = count;

    return this;
  }
}
