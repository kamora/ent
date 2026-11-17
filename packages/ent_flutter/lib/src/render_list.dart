// The backend-independent half of a frame, as the reference renderer projects objects and builds its render lists:
// cull, collect one item per drawable group, sort. A backend (Flutter GPU here) only executes the sorted items;
// nothing in this file depends on Flutter.

import 'package:ent/ent.dart';

/// One draw: an object's geometry range rendered with one material, the reference's render item.
class RenderItem {
  RenderItem(this.object, this.geometry, this.material, this.groupOrder, this.z, this.group)
    : id = object.id,
      renderOrder = object.renderOrder,
      materialVariant = (object is InstancedMesh ? 2 : 0) + (object is SkinnedMesh ? 1 : 0);

  /// The object's id, the last sort key.
  final int id;

  /// The object drawn.
  final Object3D object;

  /// The geometry drawn.
  final BufferGeometry geometry;

  /// The material drawn with.
  final Material material;

  /// 2 for an InstancedMesh, plus 1 for a SkinnedMesh: opaque items of one material sort by it.
  final int materialVariant;

  /// The renderOrder of the nearest Group above the object, or 0.
  final int groupOrder;

  /// The object's renderOrder, the sort key after [groupOrder].
  final int renderOrder;

  /// The clip-space z of the object's bounding-sphere center (sprites: its position), as the reference's `_vector4.z`;
  /// negated for a reversed depth buffer.
  final double z;

  /// The geometry group drawn, or `null` for the whole draw range.
  final GeometryGroup? group;
}

/// The items of one frame, sorted as the reference sorts them, and the lights found on the way.
class RenderList {
  /// The opaque items, drawn first.
  final List<RenderItem> opaque = [];

  /// The items with transmission, drawn after the opaque ones, which they show through.
  final List<RenderItem> transmissive = [];

  /// The transparent items, drawn last, back to front.
  final List<RenderItem> transparent = [];

  /// Visible lights, in scene order (the reference's `currentRenderState.pushLight`).
  final List<Light> lights = [];

  /// Visible lights that cast shadows.
  final List<Light> shadows = [];

  final Frustum _frustum = Frustum();

  final Matrix4 _projScreen = Matrix4();

  // Kept across objects and frames like the reference's module-level `_vector4`: without sorting it is not updated.
  final Vector4 _vector = Vector4();

  /// Collects what [scene] shows to [camera] (matrices must be up to date) and, when [sort] is set (the
  /// renderer's `sortObjects`), sorts it.
  void build(Object3D scene, Camera camera, {bool sort = true}) {
    clear();
    _projScreen.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
    _frustum.setFromProjectionMatrix(_projScreen, camera.coordinateSystem, camera.reversedDepth);
    _project(scene, camera, 0, sort);

    if (sort) {
      _stableSort(opaque, _painterSort);
      _stableSort(transmissive, _reversePainterSort);
      _stableSort(transparent, _reversePainterSort);
    }
  }

  /// Empties the lists.
  void clear() {
    opaque.clear();
    transmissive.clear();
    transparent.clear();
    lights.clear();
    shadows.clear();
  }

  void _project(Object3D object, Camera camera, int groupOrder, bool sort) {
    if (!object.visible) {
      return;
    }

    if (object.layers.test(camera.layers)) {
      if (object is Group) {
        groupOrder = object.renderOrder;
      } else if (object is LOD) {
        if (object.autoUpdate) {
          object.update(camera);
        }
      } else if (object is Light) {
        lights.add(object);

        if (object.castShadow) {
          shadows.add(object);
        }
      } else if (object is Sprite) {
        if (!object.frustumCulled || object.intersectsFrustum(_frustum)) {
          if (sort) {
            _vector.setFromMatrixPosition(object.matrixWorld).applyMatrix4(_projScreen);
          }

          final material = object.material;

          if (material.visible) {
            _push(object, object.geometry, material, groupOrder, null, camera);
          }
        }
      } else if (object is Mesh || object is Line || object is Points) {
        if (!object.frustumCulled || object.intersectsFrustum(_frustum)) {
          final (geometry, material) = switch (object) {
            Mesh o => (o.geometry, o.material),
            Line o => (o.geometry, o.material),
            Points o => (o.geometry, o.material),
            _ => throw StateError('unreachable'),
          };

          if (sort) {
            // The bounding-sphere center: the object's own for instanced, skinned and batched meshes.
            _vector
              ..copy(
                switch (object) {
                  InstancedMesh o => o.boundingSphere ?? (o..computeBoundingSphere()).boundingSphere,
                  SkinnedMesh o => o.boundingSphere ?? (o..computeBoundingSphere()).boundingSphere,
                  BatchedMesh o => o.boundingSphere ?? (o..computeBoundingSphere()).boundingSphere,
                  _ => geometry.boundingSphere ?? (geometry..computeBoundingSphere()).boundingSphere,
                }!.center,
              )
              ..applyMatrix4(object.matrixWorld)
              ..applyMatrix4(_projScreen);
          }

          if (material is List) {
            for (final group in geometry.groups) {
              final index = group.materialIndex;
              final groupMaterial = index is int && index >= 0 && index < material.length
                  ? material[index] as Material?
                  : null;

              if (groupMaterial != null && groupMaterial.visible) {
                _push(object, geometry, groupMaterial, groupOrder, group, camera);
              }
            }
          } else if (material is Material && material.visible) {
            _push(object, geometry, material, groupOrder, null, camera);
          }
        }
      }
    }

    for (final child in object.children) {
      _project(child, camera, groupOrder, sort);
    }
  }

  void _push(
    Object3D object,
    BufferGeometry geometry,
    Material material,
    int order,
    GeometryGroup? group,
    Camera camera,
  ) {
    final item = RenderItem(object, geometry, material, order, camera.reversedDepth ? -_vector.z : _vector.z, group);

    if (_transmission(material) > 0) {
      transmissive.add(item);
    } else if (material.transparent) {
      transparent.add(item);
    } else {
      opaque.add(item);
    }
  }
}

double _transmission(Material material) => material is MeshPhysicalMaterial ? material.transmission : 0;

int _painterSort(RenderItem a, RenderItem b) {
  if (a.groupOrder != b.groupOrder) {
    return a.groupOrder - b.groupOrder;
  } else if (a.renderOrder != b.renderOrder) {
    return a.renderOrder - b.renderOrder;
  } else if (a.material.id != b.material.id) {
    return a.material.id - b.material.id;
  } else if (a.materialVariant != b.materialVariant) {
    return a.materialVariant - b.materialVariant;
  } else if (a.z != b.z) {
    return a.z.compareTo(b.z);
  }

  return a.id - b.id;
}

int _reversePainterSort(RenderItem a, RenderItem b) {
  if (a.groupOrder != b.groupOrder) {
    return a.groupOrder - b.groupOrder;
  } else if (a.renderOrder != b.renderOrder) {
    return a.renderOrder - b.renderOrder;
  } else if (a.z != b.z) {
    return b.z.compareTo(a.z);
  }

  return a.id - b.id;
}

// List.sort is not guaranteed stable; the reference relies on a stable sort (E-STABLESORT).
void _stableSort(List<RenderItem> list, int Function(RenderItem a, RenderItem b) compare) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1 - b.$1;
  });

  for (var i = 0; i < list.length; i++) {
    list[i] = indexed[i].$2;
  }
}
