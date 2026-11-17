part of '../../ent.dart';

// Only clone is here (used by GLTFLoader for nodes shared between scenes); retarget, retargetClip and their helpers are
// not ported.

/// Utility functions for skeletons, skinned meshes and bones.
abstract final class SkeletonUtils {
  /// Clones the given 3D object and its descendants, ensuring that any `SkinnedMesh` instances are correctly
  /// associated with their bones. Bones are also cloned, and must be descendants of the object passed to this
  /// method. Other data, like geometries and materials, are reused by reference.
  static Object3D clone(Object3D source) {
    final sourceLookup = <Object3D, Object3D>{};
    final cloneLookup = <Object3D, Object3D>{};

    final clone = source.clone();

    _skeletonUtilsParallelTraverse(source, clone, (sourceNode, clonedNode) {
      sourceLookup[clonedNode] = sourceNode;
      cloneLookup[sourceNode] = clonedNode;
    });

    clone.traverse((node) {
      if (node is! SkinnedMesh) {
        return;
      }

      final clonedMesh = node;
      final sourceMesh = sourceLookup[node]! as SkinnedMesh;
      final sourceBones = sourceMesh.skeleton!.bones;

      clonedMesh.skeleton = sourceMesh.skeleton!.clone();
      clonedMesh.bindMatrix.copy(sourceMesh.bindMatrix);

      clonedMesh.skeleton!.bones = [for (final bone in sourceBones) cloneLookup[bone]! as Bone];

      clonedMesh.bind(clonedMesh.skeleton!, clonedMesh.bindMatrix);
    });

    return clone;
  }
}

// internal helper

void _skeletonUtilsParallelTraverse(Object3D a, Object3D b, void Function(Object3D a, Object3D b) callback) {
  callback(a, b);

  for (var i = 0; i < a.children.length; i++) {
    _skeletonUtilsParallelTraverse(a.children[i], b.children[i], callback);
  }
}
