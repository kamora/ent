part of '../../ent.dart';

int _textureSourceId = 0;

/// Represents the data source of a texture.
///
/// The main purpose of this class is to decouple the data definition from the texture definition so the same
/// data can be used with multiple texture instances.
class TextureSource {
  /// Constructs a new texture source with the given data definition (default `null`).
  TextureSource([this.data]);

  /// This flag can be used for type testing.
  bool get isTextureSource => true;

  /// The ID of the source.
  final int id = _textureSourceId++;

  /// The UUID of the source.
  String uuid = MathUtils.generateUUID();

  /// The data definition of a texture: a [DataImage], a platform image (see [ImagePlatform]), a list of
  /// images (cube textures) or `null`.
  Object? data;

  /// This property is only relevant when [needsUpdate] is set to `true` and provides more control on how
  /// texture data should be processed. When `dataReady` is set to `false`, the engine performs the memory
  /// allocation (if necessary) but does not transfer the data into the GPU memory.
  bool dataReady = true;

  /// This starts at `0` and counts how many times [needsUpdate] is set to `true`.
  int version = 0;

  /// Returns the dimensions of the source into the given target vector (a [Vector2] or a [Vector3]).
  T getSize<T extends Object>(T target) {
    final data = this.data;
    final size = data == null ? null : ImageUtils.platform?.getSize(data);

    if (size != null) {
      _textureSourceSet(target, size.width.toDouble(), size.height.toDouble(), size.depth.toDouble());
    } else if (data is DataImage) {
      _textureSourceSet(
        target,
        (data.width ?? 0).toDouble(),
        (data.height ?? 0).toDouble(),
        (data.depth ?? 0).toDouble(),
      );
    } else {
      // null data, or data without dimensions (in the reference: `data.width || 0` reads undefined).

      _textureSourceSet(target, 0, 0, 0);
    }

    return target;
  }

  /// When the property is set to `true`, the engine allocates the memory for the texture (if necessary) and
  /// triggers the actual texture upload to the GPU next time the source is used.
  set needsUpdate(bool value) {
    if (value == true) {
      version++;
    }
  }

  /// Serializes the source into JSON.
  ///
  /// [meta] is `null` or a string for a root object, or a map holding the collected serialization data
  /// (`meta['images']` keyed by UUID), as the reference's meta object.
  Map<String, Object?> toJSON([Object? meta]) {
    final isRootObject = meta == null || meta is String;
    final images = isRootObject ? null : (meta as Map<String, Object?>)['images'] as Map<String, Object?>;

    if (images != null && images[uuid] != null) {
      return images[uuid] as Map<String, Object?>;
    }

    final output = <String, Object?>{'uuid': uuid, 'url': ''};

    final data = this.data;

    if (data != null) {
      Object? url;

      if (data is List) {
        // cube texture

        url = [
          for (final image in data)
            if (image is DataTexture)
              _textureSourceSerializeImage(image.image!)
            else
              _textureSourceSerializeImage(image as Object),
        ];
      } else {
        // texture

        url = _textureSourceSerializeImage(data);
      }

      output['url'] = url;
    }

    if (images != null) {
      images[uuid] = output;
    }

    return output;
  }
}

/// `target.set( x, y, z )` on a Vector2 (which ignores `z`) or a Vector3.
void _textureSourceSet(Object target, double x, double y, double z) {
  switch (target) {
    case Vector3 v:
      v.set(x, y, z);
    case Vector2 v:
      v.set(x, y);
    default:
      throw ArgumentError.value(target, 'target', 'expected a Vector2 or a Vector3');
  }
}

Object _textureSourceSerializeImage(Object image) {
  if (ImageUtils.platform?.isImage(image) ?? false) {
    // default images

    return ImageUtils.getDataURL(image);
  } else {
    if (image is DataImage && image.data != null) {
      // images of DataTexture

      final data = image.data!;

      return {
        'data': List<num>.of(data as List<num>),
        'width': image.width,
        'height': image.height,
        'type': _imageUtilsArrayName(data),
      };
    } else {
      warn('Texture: Unable to serialize Texture.');
      return <String, Object?>{};
    }
  }
}

/// Deprecated: `Source` has been renamed to [TextureSource].
@Deprecated('Use TextureSource instead.')
class Source extends TextureSource {
  /// Constructs a new texture source with the given data definition (default `null`).
  Source([super.data]) {
    warnOnce(
      'Source: "Source" has been renamed to "TextureSource". Please update your code to use "ENT.TextureSource" instead.',
    ); // @deprecated
  }

  /// This flag can be used for type testing.
  bool get isSource => true;
}
