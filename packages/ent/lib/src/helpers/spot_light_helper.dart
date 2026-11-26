part of '../../ent.dart';

final _spotLightHelperVector = Vector3();

/// This displays a cone shaped helper object for a [SpotLight].
///
/// When the spot light or its target are transformed or light properties are changed, it's necessary to call
/// the `update()` method of the respective helper.
///
/// ```dart
/// final spotLight = SpotLight(0xffffff);
/// spotLight.position.set(10, 10, 10);
/// scene.add(spotLight);
///
/// final spotLightHelper = SpotLightHelper(spotLight);
/// scene.add(spotLightHelper);
/// ```
class SpotLightHelper extends Object3D {
  /// Constructs a new spot light helper for `light`; `color` is a number, [Color] or string; if not set, the
  /// helper takes the color of the light.
  SpotLightHelper(this.light, [this.color]) {
    matrixAutoUpdate = false;

    type = 'SpotLightHelper';

    final positions = <double>[
      0, 0, 0, 0, 0, 1, //
      0, 0, 0, 1, 0, 1, //
      0, 0, 0, -1, 0, 1, //
      0, 0, 0, 0, 1, 1, //
      0, 0, 0, 0, -1, 1, //
    ];

    for (var i = 0, j = 1, l = 32; i < l; i++, j++) {
      final p1 = (i / l) * math.pi * 2;
      final p2 = (j / l) * math.pi * 2;

      positions.addAll([math.cos(p1), math.sin(p1), 1, math.cos(p2), math.sin(p2), 1]);
    }

    cone = LineSegments(
      BufferGeometry()..setAttribute('position', Float32BufferAttribute(positions, 3)),
      LineBasicMaterial({'fog': false, 'toneMapped': false}),
    );
    add(cone);

    update();
  }

  /// The light being visualized.
  SpotLight light;

  /// The color parameter passed in the constructor. If not set, the helper will take the color of the light.
  Object? color;

  /// The cone showing the light.
  late LineSegments cone;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'light' => light,
      'color' => color,
      'cone' => cone,
      _ => super[key],
    };
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    cone.geometry.dispose();
    (cone.material! as Material).dispose();
  }

  /// Updates the helper to match the position and direction of the light being visualized.
  void update() {
    light.updateWorldMatrix(true, false);
    light.target.updateWorldMatrix(true, false);

    // update the local matrix based on the parent and light target transforms
    final parent = this.parent;

    if (parent != null) {
      parent.updateWorldMatrix(true);

      matrix.copy(parent.matrixWorld).invert().multiply(light.matrixWorld);
    } else {
      matrix.copy(light.matrixWorld);
    }

    matrixWorldNeedsUpdate = true;

    // the reference: `this.light.distance ? this.light.distance : 1000` (0 and NaN are falsy)
    final coneLength = _jsOr(light.distance, 1000);
    final coneWidth = coneLength * math.tan(light.angle);

    cone.scale.set(coneWidth, coneWidth, coneLength);

    _spotLightHelperVector.setFromMatrixPosition(light.target.matrixWorld);

    cone.lookAt(_spotLightHelperVector);

    final color = this.color;

    if (color != null) {
      (cone.material! as LineBasicMaterial).color.set(color);
    } else {
      (cone.material! as LineBasicMaterial).color.copy(light.color);
    }
  }

  /// The reference's `clone()` builds the copy without a light and throws (exception E-CLONE); this one visualizes the
  /// source's light.
  @override
  SpotLightHelper clone([bool recursive = true]) {
    return SpotLightHelper(light, color).copy(this, recursive) as SpotLightHelper;
  }
}
