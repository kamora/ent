part of '../../ent.dart';

final _skeletonOffsetMatrix = Matrix4();

/// Class for representing armatures. The skeleton is defined by a hierarchy of bones.
///
/// ```dart
/// final shoulder = Bone();
/// final elbow = Bone();
/// final hand = Bone();
///
/// shoulder.add(elbow);
/// elbow.add(hand);
///
/// shoulder.position.y = -5;
/// elbow.position.y = 0;
/// hand.position.y = 5;
///
/// final armSkeleton = Skeleton([shoulder, elbow, hand]);
/// ```
///
/// The reference guards against missing entries in `bones` (sparse arrays); a Dart `List<Bone>` cannot hold them, so
/// those guards have no counterpart here.
class Skeleton {
  /// Constructs a new skeleton from the given bones (default: none) and bone inverse matrices. If no
  /// inverses are given, they are computed automatically via [calculateInverses].
  Skeleton([List<Bone>? bones, List<Matrix4>? boneInverses]) : bones = [...?bones], boneInverses = boneInverses ?? [] {
    init();
  }

  /// The UUID of the skeleton.
  String uuid = MathUtils.generateUUID();

  /// An array of bones defining the skeleton.
  List<Bone> bones;

  /// An array of bone inverse matrices.
  List<Matrix4> boneInverses;

  /// An array buffer holding the bone data. Input data for [boneTexture].
  Float32List? boneMatrices;

  /// An array buffer holding the bone data of the previous frame. Required for computing velocity.
  Float32List? previousBoneMatrices;

  /// A texture holding the bone data for use in the vertex shader.
  DataTexture? boneTexture;

  /// A texture holding the bone data of the previous frame. Required for computing velocity.
  DataTexture? previousBoneTexture;

  /// Initializes the skeleton. This method gets automatically called by the constructor but depending on
  /// how the skeleton is created it might be necessary to call this method manually.
  void init() {
    final bones = this.bones;
    final boneInverses = this.boneInverses;

    boneMatrices = Float32List(bones.length * 16);

    // calculate inverse bone matrices if necessary

    if (boneInverses.isEmpty) {
      calculateInverses();
    } else {
      // handle special case

      if (bones.length != boneInverses.length) {
        warn('Skeleton: Number of inverse bone matrices does not match amount of bones.');

        this.boneInverses = [];

        for (var i = 0, il = this.bones.length; i < il; i++) {
          this.boneInverses.add(Matrix4());
        }
      }
    }
  }

  /// Computes the bone inverse matrices. This method resets [boneInverses] and fills it with new matrices.
  void calculateInverses() {
    boneInverses.length = 0;

    for (var i = 0, il = bones.length; i < il; i++) {
      final inverse = Matrix4();

      inverse.copy(bones[i].matrixWorld).invert();

      boneInverses.add(inverse);
    }
  }

  /// Resets the skeleton to the base pose.
  void pose() {
    // recover the bind-time world matrices

    for (var i = 0, il = bones.length; i < il; i++) {
      final bone = bones[i];

      bone.matrixWorld.copy(boneInverses[i]).invert();
    }

    // compute the local matrices, positions, rotations and scales

    for (var i = 0, il = bones.length; i < il; i++) {
      final bone = bones[i];
      final parent = bone.parent;

      if (parent != null && parent is Bone) {
        bone.matrix.copy(parent.matrixWorld).invert();
        bone.matrix.multiply(bone.matrixWorld);
      } else {
        bone.matrix.copy(bone.matrixWorld);
      }

      bone.matrix.decompose(bone.position, bone.quaternion, bone.scale);
    }
  }

  /// Resets the skeleton to the base pose.
  void update() {
    final bones = this.bones;
    final boneInverses = this.boneInverses;
    final boneMatrices = this.boneMatrices!;
    final boneTexture = this.boneTexture;

    // flatten bone matrices to array

    for (var i = 0, il = bones.length; i < il; i++) {
      // compute the offset between the current and the original transform (the reference falls back to the identity for
      // a missing bone, which a List<Bone> cannot hold)

      _skeletonOffsetMatrix.multiplyMatrices(bones[i].matrixWorld, boneInverses[i]);
      _skeletonOffsetMatrix.toArray(boneMatrices, i * 16);
    }

    if (boneTexture != null) {
      boneTexture.needsUpdate = true;
    }
  }

  /// Returns a new skeleton with copied values from this instance.
  Skeleton clone() {
    return Skeleton(bones, boneInverses);
  }

  /// Computes a data texture for passing bone data to the vertex shader.
  Skeleton computeBoneTexture() {
    // layout (1 matrix = 4 pixels)
    //      RGBA RGBA RGBA RGBA (=> column1, column2, column3, column4)
    //  with  8x8  pixel texture max   16 bones * 4 pixels =  (8 * 8)
    //       16x16 pixel texture max   64 bones * 4 pixels = (16 * 16)
    //       32x32 pixel texture max  256 bones * 4 pixels = (32 * 32)
    //       64x64 pixel texture max 1024 bones * 4 pixels = (64 * 64)

    var size = math.sqrt(bones.length * 4); // 4 pixels needed for 1 matrix
    size = (size / 4).ceilToDouble() * 4;
    size = math.max(size, 4.0);

    final pixels = size.toInt();
    final boneMatrices = Float32List(pixels * pixels * 4); // 4 floats per RGBA pixel
    boneMatrices.setAll(0, this.boneMatrices!); // copy current values

    final boneTexture = DataTexture(boneMatrices, pixels, pixels, RGBAFormat, FloatType);
    boneTexture.needsUpdate = true;

    this.boneMatrices = boneMatrices;
    this.boneTexture = boneTexture;

    return this;
  }

  /// Searches through the skeleton's bone array and returns the first with a matching name, or `null` (`undefined` in
  /// the reference).
  Bone? getBoneByName(String name) {
    for (var i = 0, il = bones.length; i < il; i++) {
      final bone = bones[i];

      if (bone.name == name) {
        return bone;
      }
    }

    return null;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  void dispose() {
    if (boneTexture != null) {
      boneTexture!.dispose();

      boneTexture = null;
    }

    if (previousBoneTexture != null) {
      previousBoneTexture!.dispose();

      previousBoneTexture = null;
    }
  }

  /// Setups the skeleton by the given JSON and bones: `bones` maps bone UUIDs to bones.
  Skeleton fromJSON(Map<String, Object?> json, Map<String, Bone> bones) {
    uuid = json['uuid'] as String;

    final boneIds = json['bones'] as List<Object?>;
    final inverses = json['boneInverses'] as List<Object?>;

    for (var i = 0, l = boneIds.length; i < l; i++) {
      final uuid = boneIds[i] as String;
      var bone = bones[uuid];

      if (bone == null) {
        warn('Skeleton: No bone found with UUID:', [uuid]);
        bone = Bone();
      }

      this.bones.add(bone);
      boneInverses.add(Matrix4().fromArray((inverses[i] as List<Object?>).cast<num>()));
    }

    init();

    return this;
  }

  /// Serializes the skeleton into JSON. `meta` is accepted and ignored, as the reference ignores the argument
  /// `Object3D.toJSON` passes to every shared resource.
  Map<String, Object?> toJSON([Object? meta]) {
    final data = <String, Object?>{
      'metadata': <String, Object?>{'version': 4.7, 'type': 'Skeleton', 'generator': 'Skeleton.toJSON'},
      'bones': <Object?>[],
      'boneInverses': <Object?>[],
    };

    data['uuid'] = uuid;

    final bones = this.bones;
    final boneInverses = this.boneInverses;

    for (var i = 0, l = bones.length; i < l; i++) {
      final bone = bones[i];
      (data['bones'] as List<Object?>).add(bone.uuid);

      final boneInverse = boneInverses[i];
      (data['boneInverses'] as List<Object?>).add(boneInverse.toArray());
    }

    return data;
  }
}
