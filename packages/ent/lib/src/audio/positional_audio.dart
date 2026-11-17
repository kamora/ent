part of '../../ent.dart';

final _positionalAudioPosition = Vector3();
final _positionalAudioQuaternion = Quaternion();
final _positionalAudioScale = Vector3();
final _positionalAudioOrientation = Vector3();

/// Represents a positional audio object.
///
/// ```dart
/// // create an AudioListener and add it to the camera
/// final listener = AudioListener();
/// camera.add(listener);
///
/// // create the PositionalAudio object (passing in the listener)
/// final sound = PositionalAudio(listener);
///
/// // load a sound and set it as the PositionalAudio object's buffer
/// final audioLoader = AudioLoader();
/// audioLoader.load('sounds/song.ogg', (buffer) {
/// 	sound.setBuffer(buffer);
/// 	sound.setRefDistance(20);
/// 	sound.play();
/// });
///
/// // create an object for the sound to play from
/// final sphere = SphereGeometry(20, 32, 16);
/// final material = MeshPhongMaterial({'color': 0xff2200});
/// final mesh = Mesh(sphere, material);
/// scene.add(mesh);
///
/// // finally add the sound to the mesh
/// mesh.add(sound);
/// ```
class PositionalAudio extends Audio {
  /// Constructs a positional audio for the global audio [listener].
  PositionalAudio(super.listener) {
    panner = context.createPanner();
    panner.panningModel = 'HRTF';
    panner.connect(gain);
  }

  /// The panner node represents the location, direction, and behavior of an audio source in 3D space.
  late final WebAudioPannerNode panner;

  @override
  PositionalAudio connect() {
    super.connect();

    panner.connect(gain);

    return this;
  }

  @override
  PositionalAudio disconnect() {
    super.disconnect();

    panner.disconnect(gain);

    return this;
  }

  @override
  WebAudioNode getOutput() {
    return panner;
  }

  /// Returns the current reference distance.
  double getRefDistance() {
    return panner.refDistance;
  }

  /// Defines the reference distance for reducing volume as the audio source moves further from the listener
  /// – i.e. the distance at which the volume reduction starts taking effect.
  PositionalAudio setRefDistance(double value) {
    panner.refDistance = value;

    return this;
  }

  /// Returns the current rolloff factor.
  double getRolloffFactor() {
    return panner.rolloffFactor;
  }

  /// Defines how quickly the volume is reduced as the source moves away from the listener.
  PositionalAudio setRolloffFactor(double value) {
    panner.rolloffFactor = value;

    return this;
  }

  /// Returns the current distance model.
  String getDistanceModel() {
    return panner.distanceModel;
  }

  /// Defines which algorithm to use to reduce the volume of the audio source as it moves away from the
  /// listener: `'linear'`, `'inverse'` or `'exponential'`.
  ///
  /// Read [the spec](https://www.w3.org/TR/webaudio-1.1/#enumdef-distancemodeltype) for more details.
  PositionalAudio setDistanceModel(String value) {
    panner.distanceModel = value;

    return this;
  }

  /// Returns the current max distance.
  double getMaxDistance() {
    return panner.maxDistance;
  }

  /// Defines the maximum distance between the audio source and the listener, after which the volume is not
  /// reduced any further.
  ///
  /// This value is used only by the `linear` distance model.
  PositionalAudio setMaxDistance(double value) {
    panner.maxDistance = value;

    return this;
  }

  /// Sets the directional cone in which the audio can be listened.
  ///
  /// [coneInnerAngle]: an angle, in degrees, of a cone inside of which there will be no volume reduction.
  /// [coneOuterAngle]: an angle, in degrees, of a cone outside of which the volume will be reduced by a
  /// constant value, defined by [coneOuterGain]: the amount of volume reduction outside the cone defined by
  /// [coneOuterAngle]. When set to `0`, no sound can be heard.
  PositionalAudio setDirectionalCone(double coneInnerAngle, double coneOuterAngle, double coneOuterGain) {
    panner.coneInnerAngle = coneInnerAngle;
    panner.coneOuterAngle = coneOuterAngle;
    panner.coneOuterGain = coneOuterGain;

    return this;
  }

  @override
  void updateMatrixWorld([bool? force]) {
    super.updateMatrixWorld(force);

    if (hasPlaybackControl == true && isPlaying == false) {
      return;
    }

    matrixWorld.decompose(_positionalAudioPosition, _positionalAudioQuaternion, _positionalAudioScale);

    _positionalAudioOrientation.set(0, 0, 1).applyQuaternion(_positionalAudioQuaternion);

    final panner = this.panner;
    final positionX = panner.positionX;

    if (positionX != null) {
      // code path for Chrome and Firefox (see #14393)

      final endTime = context.currentTime + listener.timeDelta;

      positionX.linearRampToValueAtTime(_positionalAudioPosition.x, endTime);
      panner.positionY!.linearRampToValueAtTime(_positionalAudioPosition.y, endTime);
      panner.positionZ!.linearRampToValueAtTime(_positionalAudioPosition.z, endTime);
      panner.orientationX!.linearRampToValueAtTime(_positionalAudioOrientation.x, endTime);
      panner.orientationY!.linearRampToValueAtTime(_positionalAudioOrientation.y, endTime);
      panner.orientationZ!.linearRampToValueAtTime(_positionalAudioOrientation.z, endTime);
    } else {
      panner.setPosition(_positionalAudioPosition.x, _positionalAudioPosition.y, _positionalAudioPosition.z);
      panner.setOrientation(
        _positionalAudioOrientation.x,
        _positionalAudioOrientation.y,
        _positionalAudioOrientation.z,
      );
    }
  }

  /// Returns a new positional audio for the same listener with copied values from this instance (E-CLONE).
  @override
  PositionalAudio clone([bool recursive = true]) {
    return PositionalAudio(listener)..copy(this, recursive);
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'panner' => panner,
      _ => super[key],
    };
  }
}
