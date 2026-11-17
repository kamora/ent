part of '../../ent.dart';

/// Creates a texture 2D array based on data in compressed form.
///
/// These texture are usually loaded with [CompressedTextureLoader].
class CompressedArrayTexture extends CompressedTexture {
  /// Constructs a new compressed array texture from [mipmaps] (the data and dimensions of all mipmaps,
  /// including the base mip), the [width], [height] and [depth] of the biggest mipmap, and its [format] and
  /// [type].
  CompressedArrayTexture([List<Object?>? mipmaps, int? width, int? height, int? depth, int? format, int? type])
    : super(mipmaps, width, height, format, type) {
    // The image property of a compressed texture just defines its dimensions.
    (image as DataImage).depth = depth;
  }

  /// This flag can be used for type testing.
  bool get isCompressedArrayTexture => true;

  /// This defines how the texture is wrapped in the depth and corresponds to *W* in UVW mapping.
  int wrapR = ClampToEdgeWrapping;

  /// A set of all layers which need to be updated in the texture.
  Set<int> layerUpdates = <int>{};

  /// Returns a new compressed array texture with copied values from this instance (E-CLONE).
  @override
  CompressedArrayTexture clone() {
    return CompressedArrayTexture()..copy(this);
  }

  /// Copies the values of the given texture to this instance.
  @override
  CompressedArrayTexture copy(Texture source) {
    super.copy(source);

    wrapR = (source as CompressedArrayTexture).wrapR;

    return this;
  }

  /// Describes that a specific layer of the texture needs to be updated.
  ///
  /// Normally when [needsUpdate] is set to `true`, the entire compressed texture array is sent to the GPU.
  /// Marking specific layers will only transmit subsets of all mipmaps associated with a specific depth in
  /// the array which is often much more performant.
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
      'isCompressedArrayTexture' => isCompressedArrayTexture,
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
