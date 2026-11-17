part of '../../ent.dart';

final _directionalLightHelperV1 = Vector3();
final _directionalLightHelperV2 = Vector3();
final _directionalLightHelperV3 = Vector3();

/// Helper object to assist with visualizing a [DirectionalLight]'s effect on the scene. This consists of a
/// plane and a line representing the light's position and direction.
///
/// When the directional light or its target are transformed or light properties are changed, it's necessary
/// to call the `update()` method of the respective helper.
///
/// ```dart
/// final light = DirectionalLight(0xFFFFFF);
/// scene.add(light);
///
/// final helper = DirectionalLightHelper(light, 5);
/// scene.add(helper);
/// ```
class DirectionalLightHelper extends Object3D {
  /// Constructs a new directional light helper for `light`; `size` is the dimension of the plane (default
  /// `1`), `color` a number, [Color] or string; if not set, the helper takes the color of the light.
  DirectionalLightHelper(this.light, [double? size, this.color]) {
    matrix = light.matrixWorld;
    matrixAutoUpdate = false;

    type = 'DirectionalLightHelper';

    size ??= 1;

    final material = LineBasicMaterial({'fog': false, 'toneMapped': false});

    lightPlane = Line(
      BufferGeometry()..setAttribute(
        'position',
        Float32BufferAttribute(<double>[
          -size,
          size,
          0,
          size,
          size,
          0,
          size,
          -size,
          0,
          -size,
          -size,
          0,
          -size,
          size,
          0,
        ], 3),
      ),
      material,
    );
    add(lightPlane);

    targetLine = Line(
      BufferGeometry()..setAttribute('position', Float32BufferAttribute(<double>[0, 0, 0, 0, 0, 1], 3)),
      material,
    );
    add(targetLine);

    update();
  }

  /// The light being visualized.
  DirectionalLight light;

  /// The color parameter passed in the constructor. If not set, the helper will take the color of the light.
  Object? color;

  /// Contains the line showing the location of the directional light.
  late Line lightPlane;

  /// Represents the target line of the directional light.
  late Line targetLine;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'light' => light,
      'color' => color,
      'lightPlane' => lightPlane,
      'targetLine' => targetLine,
      _ => super[key],
    };
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    lightPlane.geometry.dispose();
    (lightPlane.material! as Material).dispose();
    targetLine.geometry.dispose();
    (targetLine.material! as Material).dispose();
  }

  /// Updates the helper to match the position and direction of the light being visualized.
  void update() {
    matrixWorldNeedsUpdate = true;

    light.updateWorldMatrix(true, false);
    light.target.updateWorldMatrix(true, false);

    _directionalLightHelperV1.setFromMatrixPosition(light.matrixWorld);
    _directionalLightHelperV2.setFromMatrixPosition(light.target.matrixWorld);
    _directionalLightHelperV3.subVectors(_directionalLightHelperV2, _directionalLightHelperV1);

    lightPlane.lookAt(_directionalLightHelperV2);

    final color = this.color;

    if (color != null) {
      (lightPlane.material! as LineBasicMaterial).color.set(color);
      (targetLine.material! as LineBasicMaterial).color.set(color);
    } else {
      (lightPlane.material! as LineBasicMaterial).color.copy(light.color);
      (targetLine.material! as LineBasicMaterial).color.copy(light.color);
    }

    targetLine.lookAt(_directionalLightHelperV2);
    targetLine.scale.z = _directionalLightHelperV3.length();
  }

  /// The reference's `clone()` builds the copy without a light and throws (exception E-CLONE); this one visualizes the
  /// source's light.
  @override
  DirectionalLightHelper clone([bool recursive = true]) {
    return DirectionalLightHelper(light, null, color).copy(this, recursive) as DirectionalLightHelper;
  }
}
