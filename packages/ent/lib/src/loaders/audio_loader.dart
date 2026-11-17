part of '../../ent.dart';

/// An audio context that can decode audio data, the reference's `BaseAudioContext.decodeAudioData()`. The [AudioLoader]
/// needs the context from [AudioContext.getContext] to implement it (exception E-PLATFORM).
abstract interface class WebAudioDecodingContext {
  /// Decodes encoded audio [data] into an audio buffer; fails if the data cannot be decoded.
  Future<Object> decodeAudioData(ByteBuffer data);
}

/// Class for loading audio buffers. Audios are internally loaded via [FileLoader].
class AudioLoader extends Loader<Object> {
  /// Constructs a new audio loader.
  AudioLoader([super.manager]);

  /// Starts loading from the given URL and passes the loaded audio buffer to the [onLoad] callback.
  @override
  void load(
    covariant String url, [
    void Function(Object audioBuffer)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    void handleError(Object e) {
      if (onError != null) {
        onError(e);
      } else {
        error(e);
      }

      manager.itemError(url);
    }

    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setResponseType('arraybuffer')
      ..setPath(path)
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    loader.load(
      url,
      (buffer) {
        try {
          // Create a copy of the buffer. The `decodeAudioData` method
          // detaches the buffer when complete, preventing reuse.
          final bufferCopy = Uint8List.fromList((buffer! as ByteBuffer).asUint8List()).buffer;

          final context = AudioContext.getContext();

          if (context is! WebAudioDecodingContext) {
            throw StateError('ENT.AudioLoader: the audio context cannot decode audio data.');
          }

          final decodeUrl = '$url#decode';
          manager.itemStart(decodeUrl); // prevent loading manager from completing too early, see #33378

          // The reference passes onLoad as decodeAudioData's success callback: an error it throws is not a decoding
          // error, so it is not caught here either.
          (context as WebAudioDecodingContext)
              .decodeAudioData(bufferCopy)
              .then(
                (audioBuffer) {
                  onLoad!(audioBuffer);
                  manager.itemEnd(decodeUrl);
                },
                onError: (Object e) {
                  handleError(e);
                  manager.itemEnd(decodeUrl);
                },
              );
        } catch (e) {
          handleError(e);
        }
      },
      onProgress,
      onError,
    );
  }
}
