part of '../../ent.dart';

// The reference also exports contain/cover/fill/getByteLength at module level but publishes only TextureUtils, and so
// does this engine.

double _textureUtilsFloor(num v) => v.floorToDouble();

double _textureUtilsCeil(num v) => v.ceilToDouble();

/// `texture.image.width / texture.image.height` when the image has a non-zero width, else `1`.
double _textureUtilsImageAspect(Texture texture) {
  final image = texture.image;
  int? width, height;

  if (image is DataImage) {
    width = image.width;
    height = image.height;
  } else if (image != null) {
    final size = ImageUtils.platform?.getSize(image);
    width = size?.width;
    height = size?.height;
  }

  return width != null && width != 0 ? width / (height ?? double.nan) : 1;
}

/// A class containing utility functions for textures.
abstract final class TextureUtils {
  /// Scales the texture as large as possible within its surface without cropping or stretching the texture.
  /// The method preserves the original aspect ratio of the texture. Akin to CSS `object-fit: contain`.
  static Texture contain(Texture texture, double aspect) {
    final imageAspect = _textureUtilsImageAspect(texture);

    if (imageAspect > aspect) {
      texture.repeat.x = 1;
      texture.repeat.y = imageAspect / aspect;

      texture.offset.x = 0;
      texture.offset.y = (1 - texture.repeat.y) / 2;
    } else {
      texture.repeat.x = aspect / imageAspect;
      texture.repeat.y = 1;

      texture.offset.x = (1 - texture.repeat.x) / 2;
      texture.offset.y = 0;
    }

    return texture;
  }

  /// Scales the texture to the smallest possible size to fill the surface, leaving no empty space. The method
  /// preserves the original aspect ratio of the texture. Akin to CSS `object-fit: cover`.
  static Texture cover(Texture texture, double aspect) {
    final imageAspect = _textureUtilsImageAspect(texture);

    if (imageAspect > aspect) {
      texture.repeat.x = aspect / imageAspect;
      texture.repeat.y = 1;

      texture.offset.x = (1 - texture.repeat.x) / 2;
      texture.offset.y = 0;
    } else {
      texture.repeat.x = 1;
      texture.repeat.y = imageAspect / aspect;

      texture.offset.x = 0;
      texture.offset.y = (1 - texture.repeat.y) / 2;
    }

    return texture;
  }

  /// Configures the texture to the default transformation. Akin to CSS `object-fit: fill`.
  static Texture fill(Texture texture) {
    texture.repeat.x = 1;
    texture.repeat.y = 1;

    texture.offset.x = 0;
    texture.offset.y = 0;

    return texture;
  }

  /// Determines how many bytes must be used to represent the texture of the given size, format and type.
  /// The result is a JavaScript number: a `double`, fractional for some packed types (exception E-NUM).
  static double getByteLength(int width, int height, int format, int type) {
    final typeByteLength = _textureUtilsGetTextureTypeByteLength(type);

    switch (format) {
      // https://registry.khronos.org/OpenGL-Refpages/es3.0/html/glTexImage2D.xhtml
      case AlphaFormat:
        return (width * height).toDouble();
      case RedFormat:
        return (((width * height) / typeByteLength.components) * typeByteLength.byteLength).toDouble();
      case RedIntegerFormat:
        return (((width * height) / typeByteLength.components) * typeByteLength.byteLength).toDouble();
      case RGFormat:
        return (((width * height * 2) / typeByteLength.components) * typeByteLength.byteLength).toDouble();
      case RGIntegerFormat:
        return (((width * height * 2) / typeByteLength.components) * typeByteLength.byteLength).toDouble();
      case RGBFormat:
        return (((width * height * 3) / typeByteLength.components) * typeByteLength.byteLength).toDouble();
      case RGBAFormat:
        return (((width * height * 4) / typeByteLength.components) * typeByteLength.byteLength).toDouble();
      case RGBAIntegerFormat:
        return (((width * height * 4) / typeByteLength.components) * typeByteLength.byteLength).toDouble();

      // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_s3tc_srgb/
      case RGB_S3TC_DXT1_Format:
      case RGBA_S3TC_DXT1_Format:
        return (_textureUtilsFloor((width + 3) / 4) * _textureUtilsFloor((height + 3) / 4) * 8).toDouble();
      case RGBA_S3TC_DXT3_Format:
      case RGBA_S3TC_DXT5_Format:
        return (_textureUtilsFloor((width + 3) / 4) * _textureUtilsFloor((height + 3) / 4) * 16).toDouble();

      // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_pvrtc/
      case RGB_PVRTC_2BPPV1_Format:
      case RGBA_PVRTC_2BPPV1_Format:
        return ((math.max(width, 16) * math.max(height, 8)) / 4).toDouble();
      case RGB_PVRTC_4BPPV1_Format:
      case RGBA_PVRTC_4BPPV1_Format:
        return ((math.max(width, 8) * math.max(height, 8)) / 2).toDouble();

      // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_etc/
      case RGB_ETC1_Format:
      case RGB_ETC2_Format:
      case R11_EAC_Format:
      case SIGNED_R11_EAC_Format:
        return (_textureUtilsFloor((width + 3) / 4) * _textureUtilsFloor((height + 3) / 4) * 8).toDouble();
      case RGBA_ETC2_EAC_Format:
      case RG11_EAC_Format:
      case SIGNED_RG11_EAC_Format:
        return (_textureUtilsFloor((width + 3) / 4) * _textureUtilsFloor((height + 3) / 4) * 16).toDouble();

      // https://registry.khronos.org/webgl/extensions/WEBGL_compressed_texture_astc/
      case RGBA_ASTC_4x4_Format:
        return (_textureUtilsFloor((width + 3) / 4) * _textureUtilsFloor((height + 3) / 4) * 16).toDouble();
      case RGBA_ASTC_5x4_Format:
        return (_textureUtilsFloor((width + 4) / 5) * _textureUtilsFloor((height + 3) / 4) * 16).toDouble();
      case RGBA_ASTC_5x5_Format:
        return (_textureUtilsFloor((width + 4) / 5) * _textureUtilsFloor((height + 4) / 5) * 16).toDouble();
      case RGBA_ASTC_6x5_Format:
        return (_textureUtilsFloor((width + 5) / 6) * _textureUtilsFloor((height + 4) / 5) * 16).toDouble();
      case RGBA_ASTC_6x6_Format:
        return (_textureUtilsFloor((width + 5) / 6) * _textureUtilsFloor((height + 5) / 6) * 16).toDouble();
      case RGBA_ASTC_8x5_Format:
        return (_textureUtilsFloor((width + 7) / 8) * _textureUtilsFloor((height + 4) / 5) * 16).toDouble();
      case RGBA_ASTC_8x6_Format:
        return (_textureUtilsFloor((width + 7) / 8) * _textureUtilsFloor((height + 5) / 6) * 16).toDouble();
      case RGBA_ASTC_8x8_Format:
        return (_textureUtilsFloor((width + 7) / 8) * _textureUtilsFloor((height + 7) / 8) * 16).toDouble();
      case RGBA_ASTC_10x5_Format:
        return (_textureUtilsFloor((width + 9) / 10) * _textureUtilsFloor((height + 4) / 5) * 16).toDouble();
      case RGBA_ASTC_10x6_Format:
        return (_textureUtilsFloor((width + 9) / 10) * _textureUtilsFloor((height + 5) / 6) * 16).toDouble();
      case RGBA_ASTC_10x8_Format:
        return (_textureUtilsFloor((width + 9) / 10) * _textureUtilsFloor((height + 7) / 8) * 16).toDouble();
      case RGBA_ASTC_10x10_Format:
        return (_textureUtilsFloor((width + 9) / 10) * _textureUtilsFloor((height + 9) / 10) * 16).toDouble();
      case RGBA_ASTC_12x10_Format:
        return (_textureUtilsFloor((width + 11) / 12) * _textureUtilsFloor((height + 9) / 10) * 16).toDouble();
      case RGBA_ASTC_12x12_Format:
        return (_textureUtilsFloor((width + 11) / 12) * _textureUtilsFloor((height + 11) / 12) * 16).toDouble();

      // https://registry.khronos.org/webgl/extensions/EXT_texture_compression_bptc/
      case RGBA_BPTC_Format:
      case RGB_BPTC_SIGNED_Format:
      case RGB_BPTC_UNSIGNED_Format:
        return (_textureUtilsCeil(width / 4) * _textureUtilsCeil(height / 4) * 16).toDouble();

      // https://registry.khronos.org/webgl/extensions/EXT_texture_compression_rgtc/
      case RED_RGTC1_Format:
      case SIGNED_RED_RGTC1_Format:
        return (_textureUtilsCeil(width / 4) * _textureUtilsCeil(height / 4) * 8).toDouble();
      case RED_GREEN_RGTC2_Format:
      case SIGNED_RED_GREEN_RGTC2_Format:
        return (_textureUtilsCeil(width / 4) * _textureUtilsCeil(height / 4) * 16).toDouble();
    }

    throw EntError('Unable to determine texture byte length for $format format.');
  }
}

({int byteLength, int components}) _textureUtilsGetTextureTypeByteLength(int type) {
  switch (type) {
    case UnsignedByteType:
    case ByteType:
      return (byteLength: 1, components: 1);
    case UnsignedShortType:
    case ShortType:
    case HalfFloatType:
      return (byteLength: 2, components: 1);
    case UnsignedShort4444Type:
    case UnsignedShort5551Type:
      return (byteLength: 2, components: 4);
    case UnsignedIntType:
    case IntType:
    case FloatType:
      return (byteLength: 4, components: 1);
    case UnsignedInt5999Type:
    case UnsignedInt101111Type:
      return (byteLength: 4, components: 3);
  }

  throw EntError('ENT.TextureUtils: Unknown texture type $type.');
}
