part of '../../ent.dart';

/// This displays a helper object consisting of a spherical mesh for visualizing an instance of [PointLight].
///
/// ```dart
/// final pointLight = PointLight(0xff0000, 1, 100);
/// pointLight.position.set(10, 10, 10);
/// scene.add(pointLight);
///
/// final sphereSize = 1.0;
/// final pointLightHelper = PointLightHelper(pointLight, sphereSize);
/// scene.add(pointLightHelper);
/// ```
class PointLightHelper extends Mesh {
  /// Constructs a new point light helper for `light`; `sphereSize` is the size of the sphere helper
  /// (default `1`), `color` a number, [Color] or string; if not set, the helper takes the color of the light.
  PointLightHelper(this.light, [double? sphereSize, this.color])
    : super(
        SphereGeometry(sphereSize ?? 1, 4, 2),
        MeshBasicMaterial({'wireframe': true, 'fog': false, 'toneMapped': false}),
      ) {
    type = 'PointLightHelper';

    matrix = light.matrixWorld;
    matrixAutoUpdate = false;

    update();
  }

  /// The light being visualized.
  PointLight light;

  /// The color parameter passed in the constructor. If not set, the helper will take the color of the light.
  Object? color;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'light' => light,
      'color' => color,
      _ => super[key],
    };
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    geometry.dispose();
    (material! as Material).dispose();
  }

  /// Updates the helper to match the position of the light being visualized.
  void update() {
    matrixWorldNeedsUpdate = true;

    light.updateWorldMatrix(true, false);

    final color = this.color;

    if (color != null) {
      (material! as MeshBasicMaterial).color.set(color);
    } else {
      (material! as MeshBasicMaterial).color.copy(light.color);
    }

    /*
		const d = this.light.distance;

		if ( d === 0.0 ) {

			this.lightDistance.visible = false;

		} else {

			this.lightDistance.visible = true;
			this.lightDistance.scale.set( d, d, d );

		}
		*/
  }

  /// The reference's `clone()` builds the copy without a light and throws (exception E-CLONE); this one visualizes the
  /// source's light.
  @override
  PointLightHelper clone([bool recursive = true]) {
    return PointLightHelper(light, null, color).copy(this, recursive) as PointLightHelper;
  }
}
