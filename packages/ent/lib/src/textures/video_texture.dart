part of '../../ent.dart';

/// The `HTMLVideoElement` operations [VideoTexture] performs, supplied by a platform package (E-PLATFORM).
abstract class VideoTexturePlatform {
  /// `'requestVideoFrameCallback' in video`.
  bool hasVideoFrameCallback(Object video);

  /// `video.requestVideoFrameCallback( callback )`: schedules [callback] for the next presented frame and
  /// returns its non-zero handle.
  int requestVideoFrameCallback(Object video, void Function() callback);

  /// `video.cancelVideoFrameCallback( handle )`.
  void cancelVideoFrameCallback(Object video, int handle);

  /// `video.readyState >= video.HAVE_CURRENT_DATA`.
  bool hasCurrentData(Object video);
}

/// A texture for use with a video.
///
/// ```dart
/// // assuming you have created a platform video element `video`
/// final texture = VideoTexture(video);
/// ```
///
/// Note: When using video textures with `WebGPURenderer`, [Texture.colorSpace] must be set to
/// [SRGBColorSpace].
///
/// Note: After the initial use of a texture, its dimensions, format, and type cannot be changed. Instead,
/// call [dispose] on the texture and instantiate a new one.
class VideoTexture extends Texture {
  /// Constructs a new video texture for the platform [video]. [magFilter] and [minFilter] default to
  /// [LinearFilter]; the other parameters default as in [Texture].
  ///
  /// When the video supports `requestVideoFrameCallback`, the texture is marked for update on every
  /// presented frame.
  VideoTexture(
    Object video, [
    int? mapping,
    int? wrapS,
    int? wrapT,
    int magFilter = LinearFilter,
    int minFilter = LinearFilter,
    int? format,
    int? type,
    double? anisotropy,
  ]) : super(
         video,
         mapping,
         wrapS ?? ClampToEdgeWrapping,
         wrapT ?? ClampToEdgeWrapping,
         magFilter,
         minFilter,
         format ?? RGBAFormat,
         type ?? UnsignedByteType,
         anisotropy,
       ) {
    // Whether to generate mipmaps (if possible) for a texture. Overwritten and set to `false` by default.
    generateMipmaps = false;

    void updateVideo() {
      needsUpdate = true;
      _requestVideoFrameCallbackId = platform!.requestVideoFrameCallback(video, updateVideo);
    }

    if (platform?.hasVideoFrameCallback(video) ?? false) {
      _requestVideoFrameCallbackId = platform!.requestVideoFrameCallback(video, updateVideo);
    }
  }

  /// The video operations; `null` until a platform package installs them. Without them a video has no frame
  /// callback and never reports current data, so the texture is not updated by itself.
  static VideoTexturePlatform? platform;

  /// This flag can be used for type testing.
  bool get isVideoTexture => true;

  /// The video frame request callback identifier, which is a positive integer. Value of 0 represents no
  /// scheduled rVFC.
  int _requestVideoFrameCallbackId = 0;

  /// Returns a new video texture for the same video with copied values from this instance (E-CLONE).
  @override
  VideoTexture clone() {
    return VideoTexture(image!)..copy(this);
  }

  /// This method is called automatically by the renderer and sets [needsUpdate] to `true` every time a new
  /// frame is available.
  ///
  /// Only relevant if `requestVideoFrameCallback` is not supported in the browser.
  void update() {
    final video = image!;
    final hasVideoFrameCallback = platform?.hasVideoFrameCallback(video) ?? false;

    if (hasVideoFrameCallback == false && (platform?.hasCurrentData(video) ?? false)) {
      needsUpdate = true;
    }
  }

  /// Cancels the pending frame callback, then frees the GPU-related resources.
  @override
  void dispose() {
    if (_requestVideoFrameCallbackId != 0) {
      platform!.cancelVideoFrameCallback(source.data!, _requestVideoFrameCallbackId);

      _requestVideoFrameCallbackId = 0;
    }

    super.dispose();
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isVideoTexture' => isVideoTexture,
      _ => super._getValue(key),
    };
  }
}
