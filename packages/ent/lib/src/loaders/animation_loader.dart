part of '../../ent.dart';

/// Class for loading animation clips in the JSON format. The files are internally loaded via [FileLoader].
class AnimationLoader extends Loader<List<AnimationClip>> {
  /// Constructs a new animation loader.
  AnimationLoader([super.manager]);

  /// Starts loading from the given URL and pass the loaded animations as an array holding instances of
  /// [AnimationClip] to the [onLoad] callback.
  @override
  void load(
    covariant String url, [
    void Function(List<AnimationClip> animations)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setPath(path)
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    loader.load(
      url,
      (text) {
        try {
          onLoad!(parse(jsonDecode(text! as String) as List<Object?>));
        } catch (e) {
          if (onError != null) {
            onError(e);
          } else {
            error(e);
          }

          manager.itemError(url);
        }
      },
      onProgress,
      onError,
    );
  }

  /// Parses the given JSON object and returns an array of animation clips.
  @override
  List<AnimationClip> parse(covariant List<Object?> json) {
    final animations = <AnimationClip>[];

    for (var i = 0; i < json.length; i++) {
      final clip = AnimationClip.parse((json[i]! as Map).cast<String, Object?>());

      animations.add(clip);
    }

    return animations;
  }
}
