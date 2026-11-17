part of '../../ent.dart';

/// This is almost identical to an [Object3D]. Its purpose is to make working with groups of objects
/// syntactically clearer.
///
/// ```dart
/// // Create a group and add the two cubes.
/// // These cubes can now be rotated / scaled etc as a group.
/// final group = Group();
///
/// group.add(meshA);
/// group.add(meshB);
///
/// scene.add(group);
/// ```
class Group extends Object3D {
  /// Constructs a new group.
  Group() {
    type = 'Group';
  }

  /// This flag can be used for type testing.
  bool get isGroup => true;

  @override
  Object? operator [](String key) {
    return key == 'isGroup' ? isGroup : super[key];
  }

  @override
  Group clone([bool recursive = true]) {
    return Group().copy(this, recursive) as Group;
  }
}
