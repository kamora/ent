part of '../../ent.dart';

final _hemisphereLightHelperVector = Vector3();
final _hemisphereLightHelperColor1 = Color();
final _hemisphereLightHelperColor2 = Color();

/// Creates a visual aid consisting of a spherical mesh for a given [HemisphereLight].
///
/// When the hemisphere light is transformed or its light properties are changed, it's necessary to call the
/// `update()` method of the respective helper.
///
/// ```dart
/// final light = HemisphereLight(0xffffbb, 0x080820, 1);
/// final helper = HemisphereLightHelper(light, 5);
/// scene.add(helper);
/// ```
class HemisphereLightHelper extends Object3D {
  /// Constructs a new hemisphere light helper for `light`; `size` is the size of the mesh used to visualize
  /// the light (default `1`), `color` a number, [Color] or string; if not set, the helper takes the color of
  /// the light.
  HemisphereLightHelper(this.light, [double? size, this.color])
    : material = MeshBasicMaterial({'wireframe': true, 'fog': false, 'toneMapped': false}) {
    matrix = light.matrixWorld;
    matrixAutoUpdate = false;

    type = 'HemisphereLightHelper';

    final geometry = OctahedronGeometry(size ?? 1)..rotateY(math.pi * 0.5);

    if (color == null) {
      material.vertexColors = true;
    }

    geometry.setAttribute('color', BufferAttribute(Float32List(geometry.getAttribute('position')!.count * 3), 3));

    add(Mesh(geometry, material));

    update();
  }

  /// The light being visualized.
  HemisphereLight light;

  /// The color parameter passed in the constructor. If not set, the helper will take the color of the light.
  Object? color;

  /// The material of the helper's mesh.
  MeshBasicMaterial material;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'light' => light,
      'color' => color,
      'material' => material,
      _ => super[key],
    };
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    final mesh = children[0] as Mesh;

    mesh.geometry.dispose();
    (mesh.material! as Material).dispose();
  }

  /// Updates the helper to match the position and direction of the light being visualized.
  void update() {
    final mesh = children[0] as Mesh;
    final color = this.color;

    if (color != null) {
      material.color.set(color);
    } else {
      final colors = mesh.geometry.getAttribute('color')!;

      _hemisphereLightHelperColor1.copy(light.color);
      _hemisphereLightHelperColor2.copy(light.groundColor);

      for (var i = 0, l = colors.count; i < l; i++) {
        final color = (i < (l / 2)) ? _hemisphereLightHelperColor1 : _hemisphereLightHelperColor2;

        colors.setXYZ(i, color.r, color.g, color.b);
      }

      colors.needsUpdate = true;
    }

    matrixWorldNeedsUpdate = true;

    light.updateWorldMatrix(true, false);

    mesh.lookAt(_hemisphereLightHelperVector.setFromMatrixPosition(light.matrixWorld).negate());
  }

  /// The reference's `clone()` builds the copy without a light and throws (exception E-CLONE); this one visualizes the
  /// source's light.
  @override
  HemisphereLightHelper clone([bool recursive = true]) {
    return HemisphereLightHelper(light, null, color).copy(this, recursive) as HemisphereLightHelper;
  }
}
