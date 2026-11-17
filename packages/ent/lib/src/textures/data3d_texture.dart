part of '../../ent.dart';

/// Creates a three-dimensional texture from raw data, with parameters to divide it into width, height, and
/// depth.
class Data3DTexture extends Texture {
  /// Constructs a new data array texture from [data] (a typed list or `null`) and its [width], [height] and
  /// [depth] (all default `1`).
  Data3DTexture([Object? data, int width = 1, int height = 1, int depth = 1]) : super(null) {
    // We're going to add .setXXX() methods for setting properties later.
    // Users can still set in Data3DTexture directly.
    //
    //	final texture = Data3DTexture(data, width, height, depth);
    // 	texture.anisotropy = 16;

    image = DataImage(data: data, width: width, height: height, depth: depth);

    magFilter = NearestFilter;

    minFilter = NearestFilter;

    generateMipmaps = false;

    flipY = false;

    unpackAlignment = 1;
  }

  /// This flag can be used for type testing.
  bool get isData3DTexture => true;

  /// This defines how the texture is wrapped in the depth and corresponds to *W*.
  int wrapR = ClampToEdgeWrapping;

  @override
  Data3DTexture clone() {
    return Data3DTexture().copy(this);
  }

  @override
  Data3DTexture copy(Texture source) {
    super.copy(source);

    wrapR = (source as Data3DTexture).wrapR;

    return this;
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isData3DTexture' => isData3DTexture,
      'wrapR' => wrapR,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    if (key == 'wrapR') {
      wrapR = value as int;
    } else {
      super._setValue(key, value);
    }
  }
}
