part of '../../ent.dart';

/// This class can be used as an alternative way to define video data. Instead of using an instance of
/// `HTMLVideoElement` like with [VideoTexture], `VideoFrameTexture` expects each frame is defined manually via
/// [setFrame]. A typical use case for this module is when video frames are decoded with the WebCodecs API.
///
/// ```dart
/// final texture = VideoFrameTexture();
/// texture.setFrame(frame);
/// ```
class VideoFrameTexture extends VideoTexture {
  /// Constructs a new video frame texture. The parameters default as in [VideoTexture].
  VideoFrameTexture([
    int? mapping,
    int? wrapS,
    int? wrapT,
    int magFilter = LinearFilter,
    int minFilter = LinearFilter,
    int? format,
    int? type,
    double? anisotropy,
  ]) : super(DataImage(), mapping, wrapS, wrapT, magFilter, minFilter, format, type, anisotropy);

  /// This flag can be used for type testing.
  bool get isVideoFrameTexture => true;

  /// This method overwritten with an empty implementation since this type of texture is updated via
  /// [setFrame].
  @override
  void update() {}

  /// Returns a new video frame texture with copied values from this instance (restoring Texture.clone()).
  @override
  VideoFrameTexture clone() {
    return VideoFrameTexture()..copy(this); // restoring Texture.clone()
  }

  /// Sets the current frame of the video (a platform `VideoFrame`). This will automatically update the
  /// texture so the data can be used for rendering.
  void setFrame(Object frame) {
    image = frame;
    needsUpdate = true;
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isVideoFrameTexture' => isVideoFrameTexture,
      _ => super._getValue(key),
    };
  }
}
