part of '../../ent.dart';

/// This class can be used to automatically save the depth information of a rendering into a texture.
class DepthTexture extends Texture {
  /// Constructs a new depth texture of the given [width], [height] and [depth] (default `1`).
  ///
  /// [type] defaults to [UnsignedIntType], [magFilter] and [minFilter] to [NearestFilter], and [format] to
  /// [DepthFormat]; a [format] other than [DepthFormat] or [DepthStencilFormat] throws a [EntError]. The
  /// other parameters default as in [Texture].
  DepthTexture([
    int? width,
    int? height,
    int type = UnsignedIntType,
    int? mapping,
    int? wrapS,
    int? wrapT,
    int magFilter = NearestFilter,
    int minFilter = NearestFilter,
    double? anisotropy,
    int format = DepthFormat,
    int depth = 1,
  ]) : super(
         _depthTextureImage(width, height, depth, format),
         mapping,
         wrapS ?? ClampToEdgeWrapping,
         wrapT ?? ClampToEdgeWrapping,
         magFilter,
         minFilter,
         format,
         type,
         anisotropy,
       ) {
    // If set to `true`, the texture is flipped along the vertical axis when uploaded to the GPU.
    // Overwritten and set to `false` by default.
    flipY = false;

    // Whether to generate mipmaps (if possible) for a texture. Overwritten and set to `false` by default.
    generateMipmaps = false;
  }

  /// This flag can be used for type testing.
  bool get isDepthTexture => true;

  /// Code corresponding to the depth compare function (`NeverCompare`, `LessCompare`, ...), or `null`.
  int? compareFunction;

  /// Returns a new depth texture with copied values from this instance (E-CLONE).
  @override
  DepthTexture clone() {
    return DepthTexture()..copy(this);
  }

  /// Copies the values of the given texture to this instance. The copy gets its own source holding a
  /// shallow copy of the image (see #30540).
  @override
  DepthTexture copy(Texture source) {
    super.copy(source);

    this.source = TextureSource(_textureAssign(source.image)); // see #30540
    compareFunction = (source as DepthTexture).compareFunction;

    return this;
  }

  /// Returns a JSON object representing the texture, with its [compareFunction].
  @override
  Map<String, Object?> toJSON([Object? meta]) {
    final data = super.toJSON(meta);

    data['compareFunction'] = compareFunction;

    return data;
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isDepthTexture' => isDepthTexture,
      'compareFunction' => compareFunction,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    if (key == 'compareFunction') {
      compareFunction = value as int?;
    } else {
      super._setValue(key, value);
    }
  }
}

/// The image of a depth texture; validates [format] first, as the reference does before calling `super`.
DataImage _depthTextureImage(int? width, int? height, int depth, int format) {
  if (format != DepthFormat && format != DepthStencilFormat) {
    throw EntError('ENT.DepthTexture: format must be either ENT.DepthFormat or ENT.DepthStencilFormat');
  }

  return DataImage(width: width, height: height, depth: depth);
}

/// `Object.assign( {}, image )`: a shallow copy of a texture image.
///
/// A [DataImage] copies its fields; a map copies its entries; a list (a cube's images) becomes a map keyed
/// `'0'`, `'1'`, ... as `Object.assign` makes of an array; a platform image or `null` has no own enumerable
/// data fields here and becomes an empty [DataImage].
Object _textureAssign(Object? image) {
  return switch (image) {
    DataImage d => d.copy(),
    Map<String, Object?> m => Map<String, Object?>.of(m),
    List<Object?> l => <String, Object?>{for (var i = 0; i < l.length; i++) '$i': l[i]},
    _ => DataImage(),
  };
}
