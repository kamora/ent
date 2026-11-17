part of '../ent.dart';

// All 211 constants of the reference, with its names, values and order. The object-valued exports (MOUSE, TOUCH,
// TimestampQuery, ...) become classes with static constants, so `MOUSE.LEFT` reads as it does in the reference.

/// The revision of the reference this engine follows.
const String REVISION = '187';

/// Represents mouse buttons and interaction types in context of controls.
abstract final class MOUSE {
  /// The left button.
  static const int LEFT = 0;

  /// The middle button (or wheel).
  static const int MIDDLE = 1;

  /// The right button.
  static const int RIGHT = 2;

  /// The rotate action, for a controls' `mouseButtons`.
  static const int ROTATE = 0;

  /// The dolly (zoom) action, for a controls' `mouseButtons`.
  static const int DOLLY = 1;

  /// The pan action, for a controls' `mouseButtons`.
  static const int PAN = 2;
}

/// Represents touch interaction types in context of controls.
abstract final class TOUCH {
  /// Rotate, for a controls' `touches`.
  static const int ROTATE = 0;

  /// Pan, for a controls' `touches`.
  static const int PAN = 1;

  /// Dolly and pan with two fingers, for a controls' `touches`.
  static const int DOLLY_PAN = 2;

  /// Dolly and rotate with two fingers, for a controls' `touches`.
  static const int DOLLY_ROTATE = 3;
}

/// Disables face culling.
const int CullFaceNone = 0;

/// Culls back faces.
const int CullFaceBack = 1;

/// Culls front faces.
const int CullFaceFront = 2;

/// Culls both front and back faces.
const int CullFaceFrontBack = 3;

/// Gives unfiltered shadow maps - fastest, but lowest quality.
const int BasicShadowMap = 0;

/// Filters shadow maps using the Percentage-Closer Filtering (PCF) algorithm.
const int PCFShadowMap = 1;

/// Filters shadow maps using the Percentage-Closer Filtering (PCF) algorithm with better soft shadows
/// especially when using low-resolution shadow maps.
const int PCFSoftShadowMap = 2;

/// Filters shadow maps using the Variance Shadow Map (VSM) algorithm. When using VSMShadowMap all shadow
/// receivers will also cast shadows.
const int VSMShadowMap = 3;

/// Only front faces are rendered.
const int FrontSide = 0;

/// Only back faces are rendered.
const int BackSide = 1;

/// Both front and back faces are rendered.
const int DoubleSide = 2;

/// No blending is performed which effectively disables alpha transparency.
const int NoBlending = 0;

/// The default blending.
const int NormalBlending = 1;

/// Represents additive blending.
const int AdditiveBlending = 2;

/// Represents subtractive blending.
const int SubtractiveBlending = 3;

/// Represents multiply blending.
const int MultiplyBlending = 4;

/// Represents custom blending.
const int CustomBlending = 5;

/// Represents material blending.
const int MaterialBlending = 6;

/// A `source + destination` blending equation.
const int AddEquation = 100;

/// A `source - destination` blending equation.
const int SubtractEquation = 101;

/// A `destination - source` blending equation.
const int ReverseSubtractEquation = 102;

/// A blend equation that uses the minimum of source and destination.
const int MinEquation = 103;

/// A blend equation that uses the maximum of source and destination.
const int MaxEquation = 104;

/// Multiplies all colors by `0`.
const int ZeroFactor = 200;

/// Multiplies all colors by `1`.
const int OneFactor = 201;

/// Multiplies all colors by the source colors.
const int SrcColorFactor = 202;

/// Multiplies all colors by `1` minus each source color.
const int OneMinusSrcColorFactor = 203;

/// Multiplies all colors by the source alpha value.
const int SrcAlphaFactor = 204;

/// Multiplies all colors by 1 minus the source alpha value.
const int OneMinusSrcAlphaFactor = 205;

/// Multiplies all colors by the destination alpha value.
const int DstAlphaFactor = 206;

/// Multiplies all colors by `1` minus the destination alpha value.
const int OneMinusDstAlphaFactor = 207;

/// Multiplies all colors by the destination color.
const int DstColorFactor = 208;

/// Multiplies all colors by `1` minus each destination color.
const int OneMinusDstColorFactor = 209;

/// Multiplies the RGB colors by the smaller of either the source alpha value or the value of `1` minus the
/// destination alpha value. The alpha value is multiplied by `1`.
const int SrcAlphaSaturateFactor = 210;

/// Multiplies all colors by a constant color.
const int ConstantColorFactor = 211;

/// Multiplies all colors by `1` minus a constant color.
const int OneMinusConstantColorFactor = 212;

/// Multiplies all colors by a constant alpha value.
const int ConstantAlphaFactor = 213;

/// Multiplies all colors by 1 minus a constant alpha value.
const int OneMinusConstantAlphaFactor = 214;

/// Never pass.
const int NeverDepth = 0;

/// Always pass.
const int AlwaysDepth = 1;

/// Pass if the incoming value is less than the depth buffer value.
const int LessDepth = 2;

/// Pass if the incoming value is less than or equal to the depth buffer value.
const int LessEqualDepth = 3;

/// Pass if the incoming value equals the depth buffer value.
const int EqualDepth = 4;

/// Pass if the incoming value is greater than or equal to the depth buffer value.
const int GreaterEqualDepth = 5;

/// Pass if the incoming value is greater than the depth buffer value.
const int GreaterDepth = 6;

/// Pass if the incoming value is not equal to the depth buffer value.
const int NotEqualDepth = 7;

/// Multiplies the environment map color with the surface color.
const int MultiplyOperation = 0;

/// Uses reflectivity to blend between the two colors.
const int MixOperation = 1;

/// Adds the two colors.
const int AddOperation = 2;

/// No tone mapping is applied.
const int NoToneMapping = 0;

/// Linear tone mapping.
const int LinearToneMapping = 1;

/// Reinhard tone mapping.
const int ReinhardToneMapping = 2;

/// Cineon tone mapping.
const int CineonToneMapping = 3;

/// ACES Filmic tone mapping.
const int ACESFilmicToneMapping = 4;

/// Custom tone mapping. Expects a custom implementation by modifying shader code of the material's fragment
/// shader.
const int CustomToneMapping = 5;

/// AgX tone mapping.
const int AgXToneMapping = 6;

/// Neutral tone mapping. Implementation based on the Khronos 3D Commerce Group standard tone mapping.
const int NeutralToneMapping = 7;

/// The skinned mesh shares the same world space as the skeleton.
const String AttachedBindMode = 'attached';

/// The skinned mesh does not share the same world space as the skeleton. This is useful when a skeleton is
/// shared across multiple skinned meshes.
const String DetachedBindMode = 'detached';

/// Maps textures using the geometry's UV coordinates.
const int UVMapping = 300;

/// Reflection mapping for cube textures.
const int CubeReflectionMapping = 301;

/// Refraction mapping for cube textures.
const int CubeRefractionMapping = 302;

/// Reflection mapping for equirectangular textures.
const int EquirectangularReflectionMapping = 303;

/// Refraction mapping for equirectangular textures.
const int EquirectangularRefractionMapping = 304;

/// The texture will simply repeat to infinity.
const int RepeatWrapping = 1000;

/// The last pixel of the texture stretches to the edge of the mesh.
const int ClampToEdgeWrapping = 1001;

/// The texture will repeats to infinity, mirroring on each repeat.
const int MirroredRepeatWrapping = 1002;

/// Returns the value of the texture element that is nearest (in Manhattan distance) to the specified texture
/// coordinates.
const int NearestFilter = 1003;

/// Chooses the mipmap that most closely matches the size of the pixel being textured and uses the
/// `NearestFilter` criterion (the texel nearest to the center of the pixel) to produce a texture value.
const int NearestMipmapNearestFilter = 1004;

/// Alias of [NearestMipmapNearestFilter].
const int NearestMipMapNearestFilter = 1004;

/// Chooses the two mipmaps that most closely match the size of the pixel being textured and uses the
/// `NearestFilter` criterion to produce a texture value from each mipmap. The final texture value is a
/// weighted average of those two values.
const int NearestMipmapLinearFilter = 1005;

/// Alias of [NearestMipmapLinearFilter].
const int NearestMipMapLinearFilter = 1005;

/// Returns the weighted average of the four texture elements that are closest to the specified texture
/// coordinates, and can include items wrapped or repeated from other parts of a texture, depending on the
/// values of `wrapS` and `wrapT`, and on the exact mapping.
const int LinearFilter = 1006;

/// Chooses the mipmap that most closely matches the size of the pixel being textured and uses the
/// `LinearFilter` criterion (a weighted average of the four texels that are closest to the center of the
/// pixel) to produce a texture value.
const int LinearMipmapNearestFilter = 1007;

/// Alias of [LinearMipmapNearestFilter].
const int LinearMipMapNearestFilter = 1007;

/// Chooses the two mipmaps that most closely match the size of the pixel being textured and uses the
/// `LinearFilter` criterion to produce a texture value from each mipmap. The final texture value is a
/// weighted average of those two values.
const int LinearMipmapLinearFilter = 1008;

/// Alias of [LinearMipmapLinearFilter].
const int LinearMipMapLinearFilter = 1008;

/// An unsigned byte data type for textures.
const int UnsignedByteType = 1009;

/// A byte data type for textures.
const int ByteType = 1010;

/// A short data type for textures.
const int ShortType = 1011;

/// An unsigned short data type for textures.
const int UnsignedShortType = 1012;

/// An int data type for textures.
const int IntType = 1013;

/// An unsigned int data type for textures.
const int UnsignedIntType = 1014;

/// A float data type for textures.
const int FloatType = 1015;

/// A half float data type for textures.
const int HalfFloatType = 1016;

/// An unsigned short 4_4_4_4 (packed) data type for textures.
const int UnsignedShort4444Type = 1017;

/// An unsigned short 5_5_5_1 (packed) data type for textures.
const int UnsignedShort5551Type = 1018;

/// An unsigned int 24_8 data type for textures.
const int UnsignedInt248Type = 1020;

/// An unsigned int 5_9_9_9 (packed) data type for textures.
const int UnsignedInt5999Type = 35902;

/// An unsigned int 10_11_11 (packed) data type for textures.
const int UnsignedInt101111Type = 35899;

/// Discards the red, green and blue components and reads just the alpha component.
const int AlphaFormat = 1021;

/// Discards the alpha component and reads the red, green and blue component.
const int RGBFormat = 1022;

/// Reads the red, green, blue and alpha components.
const int RGBAFormat = 1023;

/// Reads each element as a single depth value, converts it to floating point, and clamps to the range
/// `[0,1]`.
const int DepthFormat = 1026;

/// Reads each element is a pair of depth and stencil values. The depth component of the pair is interpreted
/// as in `DepthFormat`. The stencil component is interpreted based on the depth + stencil internal format.
const int DepthStencilFormat = 1027;

/// Discards the green, blue and alpha components and reads just the red component.
const int RedFormat = 1028;

/// Discards the green, blue and alpha components and reads just the red component. The texels are read as
/// integers instead of floating point.
const int RedIntegerFormat = 1029;

/// Discards the alpha, and blue components and reads the red, and green components.
const int RGFormat = 1030;

/// Discards the alpha, and blue components and reads the red, and green components. The texels are read as
/// integers instead of floating point.
const int RGIntegerFormat = 1031;

/// Discards the alpha component and reads the red, green and blue component. The texels are read as integers
/// instead of floating point.
const int RGBIntegerFormat = 1032;

/// Reads the red, green, blue and alpha components. The texels are read as integers instead of floating
/// point.
const int RGBAIntegerFormat = 1033;

/// A DXT1-compressed image in an RGB image format.
const int RGB_S3TC_DXT1_Format = 33776;

/// A DXT1-compressed image in an RGB image format with a simple on/off alpha value.
const int RGBA_S3TC_DXT1_Format = 33777;

/// A DXT3-compressed image in an RGBA image format. Compared to a 32-bit RGBA texture, it offers 4:1
/// compression.
const int RGBA_S3TC_DXT3_Format = 33778;

/// A DXT5-compressed image in an RGBA image format. It also provides a 4:1 compression, but differs to the
/// DXT3 compression in how the alpha compression is done.
const int RGBA_S3TC_DXT5_Format = 33779;

/// PVRTC RGB compression in 4-bit mode. One block for each 4×4 pixels.
const int RGB_PVRTC_4BPPV1_Format = 35840;

/// PVRTC RGB compression in 2-bit mode. One block for each 8×4 pixels.
const int RGB_PVRTC_2BPPV1_Format = 35841;

/// PVRTC RGBA compression in 4-bit mode. One block for each 4×4 pixels.
const int RGBA_PVRTC_4BPPV1_Format = 35842;

/// PVRTC RGBA compression in 2-bit mode. One block for each 8×4 pixels.
const int RGBA_PVRTC_2BPPV1_Format = 35843;

/// ETC1 RGB format.
const int RGB_ETC1_Format = 36196;

/// ETC2 RGB format.
const int RGB_ETC2_Format = 37492;

/// ETC2 RGBA format.
const int RGBA_ETC2_EAC_Format = 37496;

/// EAC R11 UNORM format.
const int R11_EAC_Format = 37488;

/// EAC R11 SNORM format.
const int SIGNED_R11_EAC_Format = 37489;

/// EAC RG11 UNORM format.
const int RG11_EAC_Format = 37490;

/// EAC RG11 SNORM format.
const int SIGNED_RG11_EAC_Format = 37491;

/// ASTC RGBA 4x4 format.
const int RGBA_ASTC_4x4_Format = 37808;

/// ASTC RGBA 5x4 format.
const int RGBA_ASTC_5x4_Format = 37809;

/// ASTC RGBA 5x5 format.
const int RGBA_ASTC_5x5_Format = 37810;

/// ASTC RGBA 6x5 format.
const int RGBA_ASTC_6x5_Format = 37811;

/// ASTC RGBA 6x6 format.
const int RGBA_ASTC_6x6_Format = 37812;

/// ASTC RGBA 8x5 format.
const int RGBA_ASTC_8x5_Format = 37813;

/// ASTC RGBA 8x6 format.
const int RGBA_ASTC_8x6_Format = 37814;

/// ASTC RGBA 8x8 format.
const int RGBA_ASTC_8x8_Format = 37815;

/// ASTC RGBA 10x5 format.
const int RGBA_ASTC_10x5_Format = 37816;

/// ASTC RGBA 10x6 format.
const int RGBA_ASTC_10x6_Format = 37817;

/// ASTC RGBA 10x8 format.
const int RGBA_ASTC_10x8_Format = 37818;

/// ASTC RGBA 10x10 format.
const int RGBA_ASTC_10x10_Format = 37819;

/// ASTC RGBA 12x10 format.
const int RGBA_ASTC_12x10_Format = 37820;

/// ASTC RGBA 12x12 format.
const int RGBA_ASTC_12x12_Format = 37821;

/// BPTC RGBA format.
const int RGBA_BPTC_Format = 36492;

/// BPTC Signed RGB format.
const int RGB_BPTC_SIGNED_Format = 36494;

/// BPTC Unsigned RGB format.
const int RGB_BPTC_UNSIGNED_Format = 36495;

/// RGTC1 Red format.
const int RED_RGTC1_Format = 36283;

/// RGTC1 Signed Red format.
const int SIGNED_RED_RGTC1_Format = 36284;

/// RGTC2 Red Green format.
const int RED_GREEN_RGTC2_Format = 36285;

/// RGTC2 Signed Red Green format.
const int SIGNED_RED_GREEN_RGTC2_Format = 36286;

/// Animations are played once.
const int LoopOnce = 2200;

/// Animations are played with a chosen number of repetitions, each time jumping from the end of the clip
/// directly to its beginning.
const int LoopRepeat = 2201;

/// Animations are played with a chosen number of repetitions, alternately playing forward and backward.
const int LoopPingPong = 2202;

/// Discrete interpolation mode for keyframe tracks.
const int InterpolateDiscrete = 2300;

/// Linear interpolation mode for keyframe tracks.
const int InterpolateLinear = 2301;

/// Smooth interpolation mode for keyframe tracks.
const int InterpolateSmooth = 2302;

/// Bezier interpolation mode for keyframe tracks. Uses cubic Bezier curves with explicit 2D control points.
/// Requires tangent data to be set on the track.
const int InterpolateBezier = 2303;

/// Zero curvature ending for animations.
const int ZeroCurvatureEnding = 2400;

/// Zero slope ending for animations.
const int ZeroSlopeEnding = 2401;

/// Wrap around ending for animations.
const int WrapAroundEnding = 2402;

/// Default animation blend mode.
const int NormalAnimationBlendMode = 2500;

/// Additive animation blend mode. Can be used to layer motions on top of each other to build complex
/// performances from smaller re-usable assets.
const int AdditiveAnimationBlendMode = 2501;

/// For every three vertices draw a single triangle.
const int TrianglesDrawMode = 0;

/// For each vertex draw a triangle from the last three vertices.
const int TriangleStripDrawMode = 1;

/// For each vertex draw a triangle from the first vertex and the last two vertices.
const int TriangleFanDrawMode = 2;

/// The depth value is inverted (1.0 - z) for visualization purposes.
const int BasicDepthPacking = 3200;

/// The depth value is packed into 32 bit RGBA.
const int RGBADepthPacking = 3201;

/// The depth value is packed into 24 bit RGB.
const int RGBDepthPacking = 3202;

/// The depth value is packed into 16 bit RG.
const int RGDepthPacking = 3203;

/// Normal information is relative to the underlying surface.
const int TangentSpaceNormalMap = 0;

/// Normal information is relative to the object orientation.
const int ObjectSpaceNormalMap = 1;

/// No color space.
const String NoColorSpace = '';

/// sRGB color space.
const String SRGBColorSpace = 'srgb';

/// sRGB-linear color space.
const String LinearSRGBColorSpace = 'srgb-linear';

/// Linear transfer function.
const String LinearTransfer = 'linear';

/// sRGB transfer function.
const String SRGBTransfer = 'srgb';

/// No normal map packing.
const String NoNormalPacking = '';

/// Normal RG packing.
const String NormalRGPacking = 'rg';

/// Normal GA packing.
const String NormalGAPacking = 'ga';

/// Sets the stencil buffer value to `0`.
const int ZeroStencilOp = 0;

/// Keeps the current value.
const int KeepStencilOp = 7680;

/// Sets the stencil buffer value to the specified reference value.
const int ReplaceStencilOp = 7681;

/// Increments the current stencil buffer value. Clamps to the maximum representable unsigned value.
const int IncrementStencilOp = 7682;

/// Decrements the current stencil buffer value. Clamps to `0`.
const int DecrementStencilOp = 7683;

/// Increments the current stencil buffer value. Wraps stencil buffer value to zero when incrementing the
/// maximum representable unsigned value.
const int IncrementWrapStencilOp = 34055;

/// Decrements the current stencil buffer value. Wraps stencil buffer value to the maximum representable
/// unsigned value when decrementing a stencil buffer value of `0`.
const int DecrementWrapStencilOp = 34056;

/// Inverts the current stencil buffer value bitwise.
const int InvertStencilOp = 5386;

/// Will never return true.
const int NeverStencilFunc = 512;

/// Will return true if the stencil reference value is less than the current stencil value.
const int LessStencilFunc = 513;

/// Will return true if the stencil reference value is equal to the current stencil value.
const int EqualStencilFunc = 514;

/// Will return true if the stencil reference value is less than or equal to the current stencil value.
const int LessEqualStencilFunc = 515;

/// Will return true if the stencil reference value is greater than the current stencil value.
const int GreaterStencilFunc = 516;

/// Will return true if the stencil reference value is not equal to the current stencil value.
const int NotEqualStencilFunc = 517;

/// Will return true if the stencil reference value is greater than or equal to the current stencil value.
const int GreaterEqualStencilFunc = 518;

/// Will always return true.
const int AlwaysStencilFunc = 519;

/// Never pass.
const int NeverCompare = 512;

/// Pass if the incoming value is less than the texture value.
const int LessCompare = 513;

/// Pass if the incoming value equals the texture value.
const int EqualCompare = 514;

/// Pass if the incoming value is less than or equal to the texture value.
const int LessEqualCompare = 515;

/// Pass if the incoming value is greater than the texture value.
const int GreaterCompare = 516;

/// Pass if the incoming value is not equal to the texture value.
const int NotEqualCompare = 517;

/// Pass if the incoming value is greater than or equal to the texture value.
const int GreaterEqualCompare = 518;

/// Always pass.
const int AlwaysCompare = 519;

/// The contents are intended to be specified once by the application, and used many times as the source for
/// drawing and image specification commands.
const int StaticDrawUsage = 35044;

/// The contents are intended to be respecified repeatedly by the application, and used many times as the
/// source for drawing and image specification commands.
const int DynamicDrawUsage = 35048;

/// The contents are intended to be specified once by the application, and used at most a few times as the
/// source for drawing and image specification commands.
const int StreamDrawUsage = 35040;

/// The contents are intended to be specified once by reading data from the 3D API, and queried many times by
/// the application.
const int StaticReadUsage = 35045;

/// The contents are intended to be respecified repeatedly by reading data from the 3D API, and queried many
/// times by the application.
const int DynamicReadUsage = 35049;

/// The contents are intended to be specified once by reading data from the 3D API, and queried at most a few
/// times by the application
const int StreamReadUsage = 35041;

/// The contents are intended to be specified once by reading data from the 3D API, and used many times as
/// the source for WebGL drawing and image specification commands.
const int StaticCopyUsage = 35046;

/// The contents are intended to be respecified repeatedly by reading data from the 3D API, and used many
/// times as the source for WebGL drawing and image specification commands.
const int DynamicCopyUsage = 35050;

/// The contents are intended to be specified once by reading data from the 3D API, and used at most a few
/// times as the source for WebGL drawing and image specification commands.
const int StreamCopyUsage = 35042;

/// GLSL 1 shader code.
const String GLSL1 = '100';

/// GLSL 3 shader code.
const String GLSL3 = '300 es';

/// WebGL coordinate system.
const int WebGLCoordinateSystem = 2000;

/// WebGPU coordinate system.
const int WebGPUCoordinateSystem = 2001;

/// Represents the different timestamp query types.
abstract final class TimestampQuery {
  /// Times compute passes.
  static const String COMPUTE = 'compute';

  /// Times render passes.
  static const String RENDER = 'render';
}

/// Represents the interpolation sampling types of shader varyings.
abstract final class InterpolationSamplingType {
  /// Interpolated with perspective correction.
  static const String PERSPECTIVE = 'perspective';

  /// Interpolated linearly in screen space.
  static const String LINEAR = 'linear';

  /// Not interpolated: the value of one vertex.
  static const String FLAT = 'flat';
}

/// Represents the different interpolation sampling modes.
abstract final class InterpolationSamplingMode {
  /// Sampled at the pixel center.
  static const String NORMAL = 'normal';

  /// Sampled at a point inside the primitive's coverage of the pixel.
  static const String CENTROID = 'centroid';

  /// Sampled per sample.
  static const String SAMPLE = 'sample';

  /// For flat interpolation: the value of the primitive's first vertex.
  static const String FIRST = 'first';

  /// For flat interpolation: the value of the first or the last vertex.
  static const String EITHER = 'either';
}

/// Compatibility flags for features that may not be supported across all platforms.
abstract final class Compatibility {
  /// Depth textures sampled with a comparison.
  static const String TEXTURE_COMPARE = 'depthTextureCompare';
}

/// Represents the refresh types of render objects.
abstract final class RenderObjectRefreshType {
  /// Nothing is refreshed.
  static const int NONE = 0;

  /// The data shared between render objects is refreshed.
  static const int SHARED = 1;

  /// Everything is refreshed.
  static const int FULL = 2;
}
