part of '../../ent.dart';

int _textureId = 0;

final _textureTempVec3 = Vector3();

/// What `this[ key ]` reads for a key that is not a property: the reference's `undefined`.
const Object _textureUndefined = Object();

/// Base class for all textures.
///
/// Note: After the initial use of a texture, its dimensions, format, and type cannot be changed. Instead, call
/// [dispose] on the texture and instantiate a new one.
class Texture extends EventDispatcher {
  /// Constructs a new texture.
  ///
  /// Defaults: [image] [DEFAULT_IMAGE], [mapping] [DEFAULT_MAPPING], wrapping [ClampToEdgeWrapping],
  /// [magFilter] [LinearFilter], [minFilter] [LinearMipmapLinearFilter], [format] [RGBAFormat], [type]
  /// [UnsignedByteType], [anisotropy] [DEFAULT_ANISOTROPY], [colorSpace] [NoColorSpace].
  Texture([
    Object? image = _textureUndefined,
    int? mapping,
    this.wrapS = ClampToEdgeWrapping,
    this.wrapT = ClampToEdgeWrapping,
    this.magFilter = LinearFilter,
    this.minFilter = LinearMipmapLinearFilter,
    this.format = RGBAFormat,
    this.type = UnsignedByteType,
    double? anisotropy,
    this.colorSpace = NoColorSpace,
  ]) : source = TextureSource(identical(image, _textureUndefined) ? DEFAULT_IMAGE : image),
       mapping = mapping ?? DEFAULT_MAPPING,
       anisotropy = anisotropy ?? DEFAULT_ANISOTROPY {
    final image = this.image;
    isArrayTexture = image is DataImage && (image.depth ?? 0) > 1;
  }

  /// The default image for all textures.
  static Object? DEFAULT_IMAGE;

  /// The default mapping for all textures.
  static int DEFAULT_MAPPING = UVMapping;

  /// The default anisotropic filtering value for all textures.
  static double DEFAULT_ANISOTROPY = 1;

  /// This flag can be used for type testing.
  bool get isTexture => true;

  /// The ID of the texture.
  final int id = _textureId++;

  /// The UUID of the texture.
  String uuid = MathUtils.generateUUID();

  /// The name of the texture.
  String name = '';

  /// The data definition of a texture. A reference to the data source can be shared across textures. This
  /// is often useful in context of spritesheets where multiple textures render the same data but with
  /// different texture transformations.
  TextureSource source;

  /// An array holding user-defined mipmaps.
  List<Object?> mipmaps = [];

  /// How the texture is applied to the object. The value [UVMapping] is the default, where texture or uv
  /// coordinates are used to apply the map.
  int mapping;

  /// Lets you select the uv attribute to map the texture to. `0` for `uv`, `1` for `uv1`, `2` for `uv2` and
  /// `3` for `uv3`.
  int channel = 0;

  /// This defines how the texture is wrapped horizontally and corresponds to *U* in UV mapping.
  int wrapS;

  /// This defines how the texture is wrapped horizontally and corresponds to *V* in UV mapping.
  int wrapT;

  /// How the texture is sampled when a texel covers more than one pixel.
  int magFilter;

  /// How the texture is sampled when a texel covers less than one pixel.
  int minFilter;

  /// The number of samples taken along the axis through the pixel that has the highest density of texels.
  double anisotropy;

  /// The format of the texture.
  int format;

  /// The default internal format is derived from [format] and [type] and defines how the texture data is
  /// going to be stored on the GPU. This property allows to overwrite the default format.
  String? internalFormat;

  /// The data type of the texture.
  int type;

  /// How much a single repetition of the texture is offset from the beginning, in each direction U and V.
  Vector2 offset = Vector2(0, 0);

  /// How many times the texture is repeated across the surface, in each direction U and V.
  Vector2 repeat = Vector2(1, 1);

  /// The point around which rotation occurs. A value of `(0.5, 0.5)` corresponds to the center of the
  /// texture. Default is `(0, 0)`, the lower left.
  Vector2 center = Vector2(0, 0);

  /// How much the texture is rotated around the center point, in radians.
  double rotation = 0;

  /// Whether to update the texture's uv-transformation [matrix] from the properties [offset], [repeat],
  /// [rotation], and [center]. Set this to `false` if you are specifying the matrix directly.
  bool matrixAutoUpdate = true;

  /// The uv-transformation matrix of the texture.
  Matrix3 matrix = Matrix3();

  /// Whether to generate mipmaps (if possible) for a texture.
  bool generateMipmaps = true;

  /// Whether mipmaps should be generated automatically after each texture update.
  bool mipmapsAutoUpdate = true;

  /// If set to `true`, the alpha channel, if present, is multiplied into the color channels when the texture
  /// is uploaded to the GPU.
  bool premultiplyAlpha = false;

  /// If set to `true`, the texture is flipped along the vertical axis when uploaded to the GPU.
  bool flipY = true;

  /// Specifies the alignment requirements for the start of each pixel row in memory. The allowable values
  /// are `1` (byte-alignment), `2` (rows aligned to even-numbered bytes), `4` (word-alignment), and `8` (rows
  /// start on double-word boundaries).
  int unpackAlignment =
      4; // valid values: 1, 2, 4, 8 (see http://www.khronos.org/opengles/sdk/docs/man/xhtml/glPixelStorei.xml)

  /// Textures containing color data should be annotated with [SRGBColorSpace] or [LinearSRGBColorSpace].
  String colorSpace;

  /// An object that can be used to store custom data about the texture. It should not hold references to
  /// functions as these will not be cloned.
  Map<String, Object?> userData = {};

  /// This can be used to only update a subregion or specific rows of the texture (for example, just the first 3 rows).
  /// Use the [addUpdateRange] function to add ranges to this array. Each range is an [UpdateRange], the reference's
  /// `{ start, count }` object (shared with [BufferAttribute.updateRanges]).
  List<UpdateRange> updateRanges = [];

  /// This starts at `0` and counts how many times [needsUpdate] is set to `true`.
  int version = 0;

  /// A callback function, called when the texture is updated (e.g., when [needsUpdate] has been set to true
  /// and then the texture is used).
  void Function(Texture texture)? onUpdate;

  /// An optional back reference to the textures render target.
  RenderTarget? renderTarget;

  /// Indicates whether a texture belongs to a render target or not.
  bool isRenderTargetTexture = false;

  /// Indicates if a texture should be handled like a texture array.
  late bool isArrayTexture;

  /// Indicates whether this texture should be processed by `PMREMGenerator` or not (only relevant for
  /// render target textures).
  int pmremVersion = 0;

  /// Whether this texture is a PMREM texture.
  bool isPMREMTexture = false;

  /// Whether the data of an integer texture should be normalized when sampled.
  bool normalized = false;

  /// The width of the texture in pixels.
  double get width {
    return source.getSize(_textureTempVec3).x;
  }

  /// The height of the texture in pixels.
  double get height {
    return source.getSize(_textureTempVec3).y;
  }

  /// The depth of the texture in pixels.
  double get depth {
    return source.getSize(_textureTempVec3).z;
  }

  /// The image object holding the texture data.
  Object? get image {
    return source.data;
  }

  set image(Object? value) {
    source.data = value;
  }

  /// Updates the texture transformation matrix from the from the properties [offset], [repeat], [rotation],
  /// and [center].
  void updateMatrix() {
    matrix.setUvTransform(offset.x, offset.y, repeat.x, repeat.y, rotation, center.x, center.y);
  }

  /// Adds a range of data in the data texture to be updated on the GPU.
  void addUpdateRange(int start, int count) {
    updateRanges.add(UpdateRange(start, count));
  }

  /// Clears the update ranges.
  void clearUpdateRanges() {
    updateRanges.length = 0;
  }

  /// Returns a new texture with copied values from this instance.
  Texture clone() {
    return Texture().copy(this);
  }

  /// Copies the values of the given texture to this instance.
  Texture copy(Texture source) {
    name = source.name;

    this.source = source.source;
    mipmaps = source.mipmaps.toList();

    mapping = source.mapping;
    channel = source.channel;

    wrapS = source.wrapS;
    wrapT = source.wrapT;

    magFilter = source.magFilter;
    minFilter = source.minFilter;

    anisotropy = source.anisotropy;

    format = source.format;
    internalFormat = source.internalFormat;
    type = source.type;
    normalized = source.normalized;

    offset.copy(source.offset);
    repeat.copy(source.repeat);
    center.copy(source.center);
    rotation = source.rotation;

    matrixAutoUpdate = source.matrixAutoUpdate;
    matrix.copy(source.matrix);

    generateMipmaps = source.generateMipmaps;
    mipmapsAutoUpdate = source.mipmapsAutoUpdate;
    premultiplyAlpha = source.premultiplyAlpha;
    flipY = source.flipY;
    unpackAlignment = source.unpackAlignment;
    colorSpace = source.colorSpace;

    renderTarget = source.renderTarget;
    isRenderTargetTexture = source.isRenderTargetTexture;
    isPMREMTexture = source.isPMREMTexture;
    isArrayTexture = source.isArrayTexture;

    userData = _textureJsonCopy(source.userData) as Map<String, Object?>;

    needsUpdate = true;

    return this;
  }

  /// Sets this texture's properties based on [values], keyed by property name.
  ///
  /// As in the reference: a `null` value (there: `undefined`) or an unknown key logs a warning and is skipped; a
  /// Vector2, Vector3 or Matrix3 property is copied into rather than replaced.
  void setValues(Map<String, Object?> values) {
    // A Dart map has no `undefined` values, so the reference's "has value of undefined" warning cannot occur; `null` is
    // assigned as the reference assigns it, except to a property Dart types as non-nullable (exception E-UNDEFINED).
    for (final MapEntry(:key, value: newValue) in values.entries) {
      final currentValue = _getValue(key);

      if (identical(currentValue, _textureUndefined)) {
        warn("Texture.setValues(): property '$key' does not exist.");
        continue;
      }

      if (newValue == null) {
        try {
          _setValue(key, null);
        } on TypeError {
          warn("Texture.setValues(): property '$key' is not nullable in Dart; null is ignored.");
        }

        continue;
      }

      if (currentValue is Vector2 && newValue is Vector2) {
        currentValue.copy(newValue);
      } else if (currentValue is Vector3 && newValue is Vector3) {
        currentValue.copy(newValue);
      } else if (currentValue is Matrix3 && newValue is Matrix3) {
        currentValue.copy(newValue);
      } else {
        _setValue(key, newValue);
      }
    }
  }

  /// `this[ key ]` for [setValues]: the property value, or [_textureUndefined] when there is no such
  /// property (methods and write-only accessors read `undefined` there too, as far as setValues cares).
  Object? _getValue(String key) {
    return switch (key) {
      'isTexture' => isTexture,
      'id' => id,
      'uuid' => uuid,
      'name' => name,
      'source' => source,
      'mipmaps' => mipmaps,
      'mapping' => mapping,
      'channel' => channel,
      'wrapS' => wrapS,
      'wrapT' => wrapT,
      'magFilter' => magFilter,
      'minFilter' => minFilter,
      'anisotropy' => anisotropy,
      'format' => format,
      'internalFormat' => internalFormat,
      'type' => type,
      'offset' => offset,
      'repeat' => repeat,
      'center' => center,
      'rotation' => rotation,
      'matrixAutoUpdate' => matrixAutoUpdate,
      'matrix' => matrix,
      'generateMipmaps' => generateMipmaps,
      'mipmapsAutoUpdate' => mipmapsAutoUpdate,
      'premultiplyAlpha' => premultiplyAlpha,
      'flipY' => flipY,
      'unpackAlignment' => unpackAlignment,
      'colorSpace' => colorSpace,
      'userData' => userData,
      'updateRanges' => updateRanges,
      'version' => version,
      'onUpdate' => onUpdate,
      'renderTarget' => renderTarget,
      'isRenderTargetTexture' => isRenderTargetTexture,
      'isArrayTexture' => isArrayTexture,
      'pmremVersion' => pmremVersion,
      'isPMREMTexture' => isPMREMTexture,
      'normalized' => normalized,
      'width' => width,
      'height' => height,
      'depth' => depth,
      'image' => image,
      _ => _textureUndefined,
    };
  }

  /// `this[ key ] = value` for [setValues]. Read-only properties throw an [ArgumentError], where the reference's
  /// strict-mode assignment to a getter-only or non-writable property throws a `TypeError`.
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'uuid':
        uuid = value as String;
      case 'name':
        name = value as String;
      case 'source':
        source = value as TextureSource;
      case 'mipmaps':
        mipmaps = value as List<Object?>;
      case 'mapping':
        mapping = value as int;
      case 'channel':
        channel = value as int;
      case 'wrapS':
        wrapS = value as int;
      case 'wrapT':
        wrapT = value as int;
      case 'magFilter':
        magFilter = value as int;
      case 'minFilter':
        minFilter = value as int;
      case 'anisotropy':
        anisotropy = (value as num).toDouble();
      case 'format':
        format = value as int;
      case 'internalFormat':
        internalFormat = value as String?;
      case 'type':
        type = value as int;
      case 'offset':
        offset = value as Vector2;
      case 'repeat':
        repeat = value as Vector2;
      case 'center':
        center = value as Vector2;
      case 'rotation':
        rotation = (value as num).toDouble();
      case 'matrixAutoUpdate':
        matrixAutoUpdate = value as bool;
      case 'matrix':
        matrix = value as Matrix3;
      case 'generateMipmaps':
        generateMipmaps = value as bool;
      case 'mipmapsAutoUpdate':
        mipmapsAutoUpdate = value as bool;
      case 'premultiplyAlpha':
        premultiplyAlpha = value as bool;
      case 'flipY':
        flipY = value as bool;
      case 'unpackAlignment':
        unpackAlignment = value as int;
      case 'colorSpace':
        colorSpace = value as String;
      case 'userData':
        userData = value as Map<String, Object?>;
      case 'updateRanges':
        updateRanges = value as List<UpdateRange>;
      case 'version':
        version = value as int;
      case 'onUpdate':
        onUpdate = value as void Function(Texture)?;
      case 'renderTarget':
        renderTarget = value as RenderTarget?;
      case 'isRenderTargetTexture':
        isRenderTargetTexture = value as bool;
      case 'isArrayTexture':
        isArrayTexture = value as bool;
      case 'pmremVersion':
        pmremVersion = value as int;
      case 'isPMREMTexture':
        isPMREMTexture = value as bool;
      case 'normalized':
        normalized = value as bool;
      case 'image':
        image = value;
      default:
        throw ArgumentError.value(key, 'key', 'read-only property of $runtimeType');
    }
  }

  /// Returns a JSON object representing the texture.
  ///
  /// [meta] is `null` or a string for a root object, or a map holding the collected serialization data
  /// (`meta['textures']` and `meta['images']` keyed by UUID), as the reference's meta object.
  Map<String, Object?> toJSON([Object? meta]) {
    final isRootObject = meta == null || meta is String;
    final textures = isRootObject ? null : (meta as Map<String, Object?>)['textures'] as Map<String, Object?>;

    if (textures != null && textures[uuid] != null) {
      return textures[uuid] as Map<String, Object?>;
    }

    final output = <String, Object?>{
      'metadata': {'version': 4.7, 'type': 'Texture', 'generator': 'Texture.toJSON'},

      'uuid': uuid,
      'name': name,

      'image': source.toJSON(meta)['uuid'],

      'mapping': mapping,
      'channel': channel,

      'repeat': [repeat.x, repeat.y],
      'offset': [offset.x, offset.y],
      'center': [center.x, center.y],
      'rotation': rotation,

      'wrap': [wrapS, wrapT],

      'format': format,
      'internalFormat': internalFormat,
      'type': type,
      'normalized': normalized,
      'colorSpace': colorSpace,

      'minFilter': minFilter,
      'magFilter': magFilter,
      'anisotropy': anisotropy,

      'flipY': flipY,

      'generateMipmaps': generateMipmaps,
      'mipmapsAutoUpdate': mipmapsAutoUpdate,
      'premultiplyAlpha': premultiplyAlpha,
      'unpackAlignment': unpackAlignment,
    };

    if (userData.isNotEmpty) {
      output['userData'] = userData;
    }

    if (textures != null) {
      textures[uuid] = output;
    }

    return output;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  void dispose() {
    dispatchEvent(Event('dispose'));
  }

  /// Transforms the given uv vector with the textures uv transformation matrix.
  Vector2 transformUv(Vector2 uv) {
    if (mapping != UVMapping) {
      return uv;
    }

    uv.applyMatrix3(matrix);

    if (uv.x < 0 || uv.x > 1) {
      switch (wrapS) {
        case RepeatWrapping:
          uv.x = uv.x - uv.x.floorToDouble();

        case ClampToEdgeWrapping:
          uv.x = uv.x < 0 ? 0.0 : 1.0;

        case MirroredRepeatWrapping:
          if (uv.x.floorToDouble().remainder(2).abs() == 1) {
            uv.x = uv.x.ceilToDouble() - uv.x;
          } else {
            uv.x = uv.x - uv.x.floorToDouble();
          }
      }
    }

    if (uv.y < 0 || uv.y > 1) {
      switch (wrapT) {
        case RepeatWrapping:
          uv.y = uv.y - uv.y.floorToDouble();

        case ClampToEdgeWrapping:
          uv.y = uv.y < 0 ? 0.0 : 1.0;

        case MirroredRepeatWrapping:
          if (uv.y.floorToDouble().remainder(2).abs() == 1) {
            uv.y = uv.y.ceilToDouble() - uv.y;
          } else {
            uv.y = uv.y - uv.y.floorToDouble();
          }
      }
    }

    if (flipY) {
      uv.y = 1 - uv.y;
    }

    return uv;
  }

  /// Setting this property to `true` indicates the engine the texture must be updated in the next render.
  /// This triggers a texture upload to the GPU and ensures correct texture parameter configuration.
  set needsUpdate(bool value) {
    if (value == true) {
      version++;
      source.needsUpdate = true;
    }
  }

  /// Setting this property to `true` indicates the engine the PMREM must be regenerated.
  set needsPMREMUpdate(bool value) {
    if (value == true) {
      pmremVersion++;
    }
  }
}

/// `JSON.parse( JSON.stringify( value ) )` for userData: a deep copy of maps and lists; other values are
/// kept (numbers, strings, booleans and null are what JSON carries).
Object? _textureJsonCopy(Object? value) {
  return switch (value) {
    Map<String, Object?> m => <String, Object?>{for (final e in m.entries) e.key: _textureJsonCopy(e.value)},
    List<Object?> l => [for (final e in l) _textureJsonCopy(e)],
    _ => value,
  };
}
