part of '../../ent.dart';

/// A bone which is part of a [Skeleton]. The skeleton in turn is used by the [SkinnedMesh].
///
/// ```dart
/// final root = Bone();
/// final child = Bone();
///
/// root.add(child);
/// child.position.y = 5;
/// ```
class Bone extends Object3D {
  /// Constructs a new bone.
  Bone() {
    type = 'Bone';
  }

  /// This flag can be used for type testing.
  bool get isBone => true;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'isBone' => isBone,
      _ => super[key],
    };
  }

  @override
  Bone clone([bool? recursive]) {
    return Bone().copy(this, recursive ?? true) as Bone;
  }
}
