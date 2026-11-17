part of '../../ent.dart';

/// Creates an array of textures directly from raw buffer data.
class DataArrayTexture extends Texture {
  /// Constructs a new data array texture from [data] (a typed list or `null`) and its [width], [height] and
  /// [depth] (all default `1`).
  DataArrayTexture([Object? data, int width = 1, int height = 1, int depth = 1]) : super(null) {
    // The image definition of a data texture.
    image = DataImage(data: data, width: width, height: height, depth: depth);

    // How the texture is sampled when a texel covers more than one pixel. Overwritten and set to
    // `NearestFilter` by default.
    magFilter = NearestFilter;

    // How the texture is sampled when a texel covers less than one pixel. Overwritten and set to
    // `NearestFilter` by default.
    minFilter = NearestFilter;

    // Whether to generate mipmaps (if possible) for a texture. Overwritten and set to `false` by default.
    generateMipmaps = false;

    // If set to `true`, the texture is flipped along the vertical axis when uploaded to the GPU.
    // Overwritten and set to `false` by default.
    flipY = false;

    // Specifies the alignment requirements for the start of each pixel row in memory. Overwritten and set to
    // `1` by default.
    unpackAlignment = 1;
  }

  /// This flag can be used for type testing.
  bool get isDataArrayTexture => true;

  /// This defines how the texture is wrapped in the depth and corresponds to *W* in UVW mapping.
  int wrapR = ClampToEdgeWrapping;

  /// A set of all layers which need to be updated in the texture.
  Set<int> layerUpdates = <int>{};

  /// Returns a new data array texture with copied values from this instance (E-CLONE).
  @override
  DataArrayTexture clone() {
    return DataArrayTexture()..copy(this);
  }

  /// Copies the values of the given texture to this instance.
  @override
  DataArrayTexture copy(Texture source) {
    super.copy(source);

    wrapR = (source as DataArrayTexture).wrapR;

    return this;
  }

  /// Describes that a specific layer of the texture needs to be updated.
  ///
  /// Normally when [needsUpdate] is set to `true`, the entire data texture array is sent to the GPU. Marking
  /// specific layers will only transmit subsets of all mipmaps associated with a specific depth in the array
  /// which is often much more performant.
  void addLayerUpdate(int layerIndex) {
    layerUpdates.add(layerIndex);
  }

  /// Resets the layer updates registry.
  void clearLayerUpdates() {
    layerUpdates.clear();
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isDataArrayTexture' => isDataArrayTexture,
      'wrapR' => wrapR,
      'layerUpdates' => layerUpdates,
      _ => super._getValue(key),
    };
  }

  @override
  void _setValue(String key, Object? value) {
    switch (key) {
      case 'wrapR':
        wrapR = value as int;
      case 'layerUpdates':
        layerUpdates = value as Set<int>;
      default:
        super._setValue(key, value);
    }
  }
}
