part of '../../ent.dart';

final _arrowHelperAxis = Vector3();

// Shared by all arrow helpers, created by the first one (the reference's module-level `_lineGeometry`).
BufferGeometry? _arrowHelperLineGeometry;
BufferGeometry? _arrowHelperConeGeometry;

/// An 3D arrow object for visualizing directions.
///
/// ```dart
/// final dir = Vector3(1, 2, 0)..normalize();
/// final helper = ArrowHelper(dir, Vector3(0, 0, 0), 1, 0xffff00);
/// scene.add(helper);
/// ```
class ArrowHelper extends Object3D {
  /// Constructs a new arrow helper.
  ///
  /// `dir` is the (normalized) direction vector, default `(0, 0, 1)`; `origin` the point at which the arrow
  /// starts, default `(0, 0, 0)`; `length` the length of the arrow in world units; `color` a number, [Color]
  /// or string; `headLength` defaults to `length * 0.2`, `headWidth` to `headLength * 0.2`.
  ArrowHelper([
    Vector3? dir,
    Vector3? origin,
    double length = 1,
    Object? color = 0xffff00,
    double? headLength,
    double? headWidth,
  ]) {
    dir ??= Vector3(0, 0, 1);
    origin ??= Vector3(0, 0, 0);
    headLength ??= length * 0.2;
    headWidth ??= headLength * 0.2;

    type = 'ArrowHelper';

    if (_arrowHelperLineGeometry == null) {
      _arrowHelperLineGeometry = BufferGeometry()
        ..setAttribute('position', Float32BufferAttribute([0, 0, 0, 0, 1, 0], 3));

      _arrowHelperConeGeometry = ConeGeometry(0.5, 1, 5, 1)..translate(0, -0.5, 0);
    }

    position.copy(origin);

    line = Line(_arrowHelperLineGeometry, LineBasicMaterial({'color': color, 'toneMapped': false}))
      ..matrixAutoUpdate = false;
    add(line);

    cone = Mesh(_arrowHelperConeGeometry, MeshBasicMaterial({'color': color, 'toneMapped': false}))
      ..matrixAutoUpdate = false;
    add(cone);

    setDirection(dir);
    setLength(length, headLength, headWidth);
  }

  /// The line part of the arrow helper.
  late Line line;

  /// The cone part of the arrow helper.
  late Mesh cone;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'line' => line,
      'cone' => cone,
      _ => super[key],
    };
  }

  /// Sets the direction of the helper; `dir` is the normalized direction vector.
  void setDirection(Vector3 dir) {
    // dir is assumed to be normalized

    if (dir.y > 0.99999) {
      quaternion.set(0, 0, 0, 1);
    } else if (dir.y < -0.99999) {
      quaternion.set(1, 0, 0, 0);
    } else {
      _arrowHelperAxis.set(dir.z, 0, -dir.x).normalize();

      quaternion.setFromAxisAngle(_arrowHelperAxis, math.acos(dir.y));
    }
  }

  /// Sets the length of the helper in world units; `headLength` defaults to `length * 0.2`, `headWidth` to
  /// `headLength * 0.2`.
  void setLength(double length, [double? headLength, double? headWidth]) {
    headLength ??= length * 0.2;
    headWidth ??= headLength * 0.2;

    line.scale.set(1, math.max(0.0001, length - headLength), 1); // see #17458
    line.updateMatrix();

    cone.scale.set(headWidth, headLength, headWidth);
    cone.position.y = length;
    cone.updateMatrix();
  }

  /// Sets the color of the helper: a number, [Color] or string.
  void setColor(Object? color) {
    (line.material! as LineBasicMaterial).color.set(color);
    (cone.material! as MeshBasicMaterial).color.set(color);
  }

  /// Copies the transformation, the line and the cone of the given helper; children are not copied.
  @override
  ArrowHelper copy(covariant ArrowHelper source, [bool recursive = true]) {
    super.copy(source, false);

    line.copy(source.line);
    cone.copy(source.cone);

    return this;
  }

  @override
  ArrowHelper clone([bool recursive = true]) {
    return ArrowHelper().copy(this, recursive);
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    line.geometry.dispose();
    (line.material! as Material).dispose();
    cone.geometry.dispose();
    (cone.material! as Material).dispose();
  }
}
