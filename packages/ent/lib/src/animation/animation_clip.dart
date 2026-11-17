part of '../../ent.dart';

/// A reusable set of keyframe tracks which represent an animation.
class AnimationClip {
  /// Constructs a new animation clip.
  ///
  /// Note: Instead of instantiating an AnimationClip directly with the constructor, you can use the static
  /// interface of this class for creating clips. In most cases though, animation clips will automatically
  /// be created by loaders when importing animated 3D assets. With a negative [duration] (the default) the
  /// duration is calculated from the passed keyframes. [blendMode] defines how the animation is
  /// blended/combined when two or more animations are simultaneously played.
  AnimationClip([
    this.name = '',
    this.duration = -1,
    List<KeyframeTrack>? tracks,
    this.blendMode = NormalAnimationBlendMode,
  ]) : tracks = tracks ?? [] {
    // this means it should figure out its duration by scanning the tracks
    if (duration < 0) {
      resetDuration();
    }
  }

  /// The clip's name.
  String name;

  /// An array of keyframe tracks.
  List<KeyframeTrack> tracks;

  /// The clip's duration in seconds.
  double duration;

  /// Defines how the animation is blended/combined when two or more animations are simultaneously played.
  int blendMode;

  /// The UUID of the animation clip.
  String uuid = MathUtils.generateUUID();

  /// An object that can be used to store custom data about the animation clip. It should not hold
  /// references to functions as these will not be cloned.
  Map<String, Object?> userData = {};

  /// Factory method for creating an animation clip from the given JSON.
  static AnimationClip parse(Map<String, Object?> json) {
    final tracks = <KeyframeTrack>[];
    final jsonTracks = json['tracks'] as List<Object?>;
    final fps = json['fps'] as num?;
    final frameTime = 1.0 / (fps == null || fps == 0 || fps.isNaN ? 1.0 : fps);

    for (var i = 0, n = jsonTracks.length; i != n; ++i) {
      tracks.add(_animationClipParseKeyframeTrack(jsonTracks[i] as Map<String, Object?>).scale(frameTime));
    }

    final clip = AnimationClip(
      json['name'] as String? ?? '',
      (json['duration'] as num?)?.toDouble() ?? -1,
      tracks,
      json['blendMode'] as int? ?? NormalAnimationBlendMode,
    );

    final uuid = json['uuid'];

    if (uuid is String) {
      clip.uuid = uuid;
    }

    final userData = json['userData'] as String?;
    clip.userData = jsonDecode(userData == null || userData.isEmpty ? '{}' : userData) as Map<String, Object?>;

    return clip;
  }

  /// Serializes the given animation clip into JSON; the reference's static `AnimationClip.toJSON( clip )`, renamed
  /// because a Dart class cannot declare a static and an instance member with the same name (E-STATIC).
  static Map<String, Object?> toJSONStatic(AnimationClip clip) {
    final tracks = <Object?>[];
    final clipTracks = clip.tracks;

    final json = <String, Object?>{
      'name': clip.name,
      'duration': clip.duration,
      'tracks': tracks,
      'uuid': clip.uuid,
      'blendMode': clip.blendMode,
      'userData': jsonEncode(clip.userData),
    };

    for (var i = 0, n = clipTracks.length; i != n; ++i) {
      tracks.add(KeyframeTrack.toJSON(clipTracks[i]));
    }

    return json;
  }

  /// Returns a new animation clip from the passed morph targets array of a geometry, taking a name and the
  /// number of frames per second.
  ///
  /// Note: The fps parameter is required, but the animation speed can be overridden via
  /// [AnimationAction.setDuration]. Each morph target needs a `name` (a buffer attribute, or a map with a
  /// `'name'` entry).
  static AnimationClip CreateFromMorphTargetSequence(
    String name,
    List<Object> morphTargetSequence,
    double fps, [
    bool noLoop = false,
  ]) {
    final numMorphTargets = morphTargetSequence.length;
    final tracks = <KeyframeTrack>[];

    for (var i = 0; i < numMorphTargets; i++) {
      List<Object?> times = <Object?>[];
      List<Object?> values = <Object?>[];

      times.addAll([
        ((i + numMorphTargets - 1) % numMorphTargets).toDouble(),
        i.toDouble(),
        ((i + 1) % numMorphTargets).toDouble(),
      ]);

      values.addAll([0.0, 1.0, 0.0]);

      final order = AnimationUtils.getKeyframeOrder(times.cast<num>());
      times = AnimationUtils.sortedArray(times, 1, order);
      values = AnimationUtils.sortedArray(values, 1, order);

      // if there is a key at the first frame, duplicate it as the
      // last frame as well for perfect loop.
      if (!noLoop && times[0] == 0) {
        times.add(numMorphTargets.toDouble());
        values.add(values[0]);
      }

      tracks.add(
        NumberKeyframeTrack(
          '.morphTargetInfluences[${_animationGet(morphTargetSequence[i], 'name')}]',
          times,
          values,
        ).scale(1.0 / fps),
      );
    }

    return AnimationClip(name, -1, tracks);
  }

  /// Searches for an animation clip by name, taking as its first parameter either an array of clips, or a
  /// mesh or geometry that contains an array named "animations" property.
  static AnimationClip? findByName(Object objectOrClipArray, String name) {
    Object? clipArray = objectOrClipArray;

    if (objectOrClipArray is! List) {
      final o = objectOrClipArray;
      final geometry = _animationGet(o, 'geometry');
      final geometryAnimations = geometry == null ? null : _animationGet(geometry, 'animations');
      clipArray = geometryAnimations ?? _animationGet(o, 'animations');
    }

    for (final clip in clipArray as List) {
      if (clip is AnimationClip && clip.name == name) {
        return clip;
      }
    }

    return null;
  }

  /// Returns an array of new AnimationClips created from the morph target sequences of a geometry, trying
  /// to sort morph target names into animation-group-based patterns like "Walk_001, Walk_002, Run_001,
  /// Run_002...".
  static List<AnimationClip> CreateClipsFromMorphTargetSequences(
    List<Object> morphTargets,
    double fps, [
    bool noLoop = false,
  ]) {
    final animationToMorphTargets = <String, List<Object>>{};

    // tested with https://regex101.com/ on trick sequences
    // such flamingo_flyA_003, flamingo_run1_003, crdeath0059
    final pattern = RegExp(r'^([\w-]*?)([\d]+)$');

    // sort morph target names into animation groups based
    // patterns like Walk_001, Walk_002, Run_001, Run_002
    for (var i = 0, il = morphTargets.length; i < il; i++) {
      final morphTarget = morphTargets[i];
      final parts = pattern.firstMatch('${_animationGet(morphTarget, 'name')}');

      if (parts != null) {
        animationToMorphTargets.putIfAbsent(parts[1]!, () => []).add(morphTarget);
      }
    }

    final clips = <AnimationClip>[];

    for (final name in _animationObjectKeyOrder(animationToMorphTargets.keys)) {
      clips.add(CreateFromMorphTargetSequence(name, animationToMorphTargets[name]!, fps, noLoop));
    }

    return clips;
  }

  /// Sets the duration of this clip to the duration of its longest keyframe track.
  AnimationClip resetDuration() {
    final tracks = this.tracks;
    var duration = 0.0;

    for (var i = 0, n = tracks.length; i != n; ++i) {
      final track = this.tracks[i];

      duration = math.max(duration, track.times[track.times.length - 1]);
    }

    this.duration = duration;

    return this;
  }

  /// Trims all tracks to the clip's duration.
  AnimationClip trim() {
    for (var i = 0; i < tracks.length; i++) {
      tracks[i].trim(0, duration);
    }

    return this;
  }

  /// Performs minimal validation on each track in the clip. Returns `true` if all tracks are valid.
  bool validate() {
    var valid = true;

    for (var i = 0; i < tracks.length; i++) {
      valid = valid && tracks[i].validate();
    }

    return valid;
  }

  /// Optimizes each track by removing equivalent sequential keys (which are common in morph target
  /// sequences).
  AnimationClip optimize() {
    for (var i = 0; i < tracks.length; i++) {
      tracks[i].optimize();
    }

    return this;
  }

  /// Returns a new animation clip with copied values from this instance.
  AnimationClip clone() {
    final tracks = <KeyframeTrack>[];

    for (var i = 0; i < this.tracks.length; i++) {
      tracks.add(this.tracks[i].clone());
    }

    final clip = AnimationClip(name, duration, tracks, blendMode);

    clip.userData = _object3dJsonCopy(userData) as Map<String, Object?>;

    return clip;
  }

  /// Serializes this animation clip into JSON.
  Map<String, Object?> toJSON() {
    return AnimationClip.toJSONStatic(this);
  }
}

/// The order of `for ( key in object )`: integer-like keys first in ascending order, then the others in
/// insertion order.
List<String> _animationObjectKeyOrder(Iterable<String> keys) {
  final index = RegExp(r'^(0|[1-9][0-9]*)$');
  final integers = keys.where((k) => index.hasMatch(k) && int.parse(k) < 4294967295).toList()
    ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  return [...integers, ...keys.where((k) => !integers.contains(k))];
}

/// The reference's `getTrackTypeForValueTypeName`: the track class for a JSON type name, as a constructor.
KeyframeTrack Function(String name, List<Object?> times, List<Object?> values, int? interpolation)
_animationClipTrackType(String typeName) {
  switch (typeName.toLowerCase()) {
    case 'scalar':
    case 'double':
    case 'float':
    case 'number':
    case 'integer':
      return NumberKeyframeTrack.new;

    case 'vector':
    case 'vector2':
    case 'vector3':
    case 'vector4':
      return VectorKeyframeTrack.new;

    case 'color':
      return ColorKeyframeTrack.new;

    case 'quaternion':
      return QuaternionKeyframeTrack.new;

    case 'bool':
    case 'boolean':
      return (name, times, values, interpolation) => BooleanKeyframeTrack(name, times, values);

    case 'string':
      return (name, times, values, interpolation) => StringKeyframeTrack(name, times, values);
  }

  throw EntError('ENT.KeyframeTrack: Unsupported typeName: $typeName');
}

KeyframeTrack _animationClipParseKeyframeTrack(Map<String, Object?> json) {
  final type = json['type'];

  if (type == null) {
    throw EntError('ENT.KeyframeTrack: track type undefined, can not parse');
  }

  final trackType = _animationClipTrackType(type as String);

  if (json['times'] == null) {
    final times = <Object?>[];
    final values = <Object?>[];

    AnimationUtils.flattenJSON(json['keys'] as List<Object?>, times, values, 'value');

    json['times'] = times;
    json['values'] = values;
  }

  // by default, we assume a constructor compatible with the base
  final track = trackType(
    json['name'] as String,
    json['times'] as List<Object?>,
    json['values'] as List<Object?>,
    json['interpolation'] as int?,
  );

  final settings = json['settings'] as Map<String, Object?>?;

  if (AnimationUtils.hasTangents(settings)) {
    track.settings = {
      'inTangents': AnimationUtils.convertArray(settings!['inTangents'] as List<Object?>?, 'Float32Array'),
      'outTangents': AnimationUtils.convertArray(settings['outTangents'] as List<Object?>?, 'Float32Array'),
    };
  }

  return track;
}
