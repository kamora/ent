part of '../../ent.dart';

final _cameraHelperVector = Vector3();
final _cameraHelperCamera = Camera();

/// This helps with visualizing what a camera contains in its frustum. It visualizes the frustum of a camera
/// using a line segments.
///
/// Based on frustum visualization in
/// [lightgl.js shadowmap example](https://github.com/evanw/lightgl.js/blob/master/tests/shadowmap.html).
///
/// `CameraHelper` must be a child of the scene.
///
/// When the camera is transformed or its projection matrix is changed, it's necessary to call the
/// `update()` method of the respective helper.
///
/// ```dart
/// final camera = PerspectiveCamera(75, width / height, 0.1, 1000);
/// final helper = CameraHelper(camera);
/// scene.add(helper);
/// ```
class CameraHelper extends LineSegments {
  /// Constructs a new camera helper for `camera`.
  CameraHelper(Camera camera) : this._(camera, <String, List<int>>{});

  CameraHelper._(this.camera, this.pointMap)
    : super(
        _cameraHelperGeometry(pointMap),
        LineBasicMaterial({'color': 0xffffff, 'vertexColors': true, 'toneMapped': false}),
      ) {
    type = 'CameraHelper';

    final camera = this.camera;

    // the reference: `if ( this.camera.updateProjectionMatrix ) this.camera.updateProjectionMatrix();`
    if (camera is PerspectiveCamera) {
      camera.updateProjectionMatrix();
    } else if (camera is OrthographicCamera) {
      camera.updateProjectionMatrix();
    }

    matrix = camera.matrixWorld;
    matrixAutoUpdate = false;

    update();

    // colors

    setColors(Color(0xffaa00), Color(0xff0000), Color(0x00aaff), Color(0xffffff), Color(0x333333));
  }

  /// The camera being visualized.
  Camera camera;

  /// This contains the points used to visualize the camera: point name → vertex indices.
  Map<String, List<int>> pointMap;

  @override
  Object? operator [](String key) {
    return switch (key) {
      'camera' => camera,
      'pointMap' => pointMap,
      _ => super[key],
    };
  }

  /// Defines the colors of the helper.
  CameraHelper setColors(Color frustum, Color cone, Color up, Color target, Color cross) {
    final colorAttribute = geometry.getAttribute('color')!;

    // near

    colorAttribute.setXYZ(0, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(1, frustum.r, frustum.g, frustum.b); // n1, n2
    colorAttribute.setXYZ(2, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(3, frustum.r, frustum.g, frustum.b); // n2, n4
    colorAttribute.setXYZ(4, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(5, frustum.r, frustum.g, frustum.b); // n4, n3
    colorAttribute.setXYZ(6, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(7, frustum.r, frustum.g, frustum.b); // n3, n1

    // far

    colorAttribute.setXYZ(8, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(9, frustum.r, frustum.g, frustum.b); // f1, f2
    colorAttribute.setXYZ(10, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(11, frustum.r, frustum.g, frustum.b); // f2, f4
    colorAttribute.setXYZ(12, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(13, frustum.r, frustum.g, frustum.b); // f4, f3
    colorAttribute.setXYZ(14, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(15, frustum.r, frustum.g, frustum.b); // f3, f1

    // sides

    colorAttribute.setXYZ(16, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(17, frustum.r, frustum.g, frustum.b); // n1, f1
    colorAttribute.setXYZ(18, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(19, frustum.r, frustum.g, frustum.b); // n2, f2
    colorAttribute.setXYZ(20, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(21, frustum.r, frustum.g, frustum.b); // n3, f3
    colorAttribute.setXYZ(22, frustum.r, frustum.g, frustum.b);
    colorAttribute.setXYZ(23, frustum.r, frustum.g, frustum.b); // n4, f4

    // cone

    colorAttribute.setXYZ(24, cone.r, cone.g, cone.b);
    colorAttribute.setXYZ(25, cone.r, cone.g, cone.b); // p, n1
    colorAttribute.setXYZ(26, cone.r, cone.g, cone.b);
    colorAttribute.setXYZ(27, cone.r, cone.g, cone.b); // p, n2
    colorAttribute.setXYZ(28, cone.r, cone.g, cone.b);
    colorAttribute.setXYZ(29, cone.r, cone.g, cone.b); // p, n3
    colorAttribute.setXYZ(30, cone.r, cone.g, cone.b);
    colorAttribute.setXYZ(31, cone.r, cone.g, cone.b); // p, n4

    // up

    colorAttribute.setXYZ(32, up.r, up.g, up.b);
    colorAttribute.setXYZ(33, up.r, up.g, up.b); // u1, u2
    colorAttribute.setXYZ(34, up.r, up.g, up.b);
    colorAttribute.setXYZ(35, up.r, up.g, up.b); // u2, u3
    colorAttribute.setXYZ(36, up.r, up.g, up.b);
    colorAttribute.setXYZ(37, up.r, up.g, up.b); // u3, u1

    // target

    colorAttribute.setXYZ(38, target.r, target.g, target.b);
    colorAttribute.setXYZ(39, target.r, target.g, target.b); // c, t
    colorAttribute.setXYZ(40, cross.r, cross.g, cross.b);
    colorAttribute.setXYZ(41, cross.r, cross.g, cross.b); // p, c

    // cross

    colorAttribute.setXYZ(42, cross.r, cross.g, cross.b);
    colorAttribute.setXYZ(43, cross.r, cross.g, cross.b); // cn1, cn2
    colorAttribute.setXYZ(44, cross.r, cross.g, cross.b);
    colorAttribute.setXYZ(45, cross.r, cross.g, cross.b); // cn3, cn4

    colorAttribute.setXYZ(46, cross.r, cross.g, cross.b);
    colorAttribute.setXYZ(47, cross.r, cross.g, cross.b); // cf1, cf2
    colorAttribute.setXYZ(48, cross.r, cross.g, cross.b);
    colorAttribute.setXYZ(49, cross.r, cross.g, cross.b); // cf3, cf4

    colorAttribute.needsUpdate = true;

    return this;
  }

  /// Updates the helper based on the projection matrix of the camera.
  void update() {
    const w = 1.0, h = 1.0;

    double nearZ, farZ;

    // we need just camera projection matrix inverse
    // world matrix must be identity

    _cameraHelperCamera.projectionMatrixInverse.copy(camera.projectionMatrixInverse);

    // Adjust z values based on coordinate system

    if (camera.reversedDepth == true) {
      nearZ = 1;
      farZ = 0;
    } else {
      if (camera.coordinateSystem == WebGLCoordinateSystem) {
        nearZ = -1;
        farZ = 1;
      } else if (camera.coordinateSystem == WebGPUCoordinateSystem) {
        nearZ = 0;
        farZ = 1;
      } else {
        throw EntError('ENT.CameraHelper.update(): Invalid coordinate system: ${camera.coordinateSystem}');
      }
    }

    // center / target
    _cameraHelperSetPoint('c', pointMap, geometry, _cameraHelperCamera, 0, 0, nearZ);
    _cameraHelperSetPoint('t', pointMap, geometry, _cameraHelperCamera, 0, 0, farZ);

    // near

    _cameraHelperSetPoint('n1', pointMap, geometry, _cameraHelperCamera, -w, -h, nearZ);
    _cameraHelperSetPoint('n2', pointMap, geometry, _cameraHelperCamera, w, -h, nearZ);
    _cameraHelperSetPoint('n3', pointMap, geometry, _cameraHelperCamera, -w, h, nearZ);
    _cameraHelperSetPoint('n4', pointMap, geometry, _cameraHelperCamera, w, h, nearZ);

    // far

    _cameraHelperSetPoint('f1', pointMap, geometry, _cameraHelperCamera, -w, -h, farZ);
    _cameraHelperSetPoint('f2', pointMap, geometry, _cameraHelperCamera, w, -h, farZ);
    _cameraHelperSetPoint('f3', pointMap, geometry, _cameraHelperCamera, -w, h, farZ);
    _cameraHelperSetPoint('f4', pointMap, geometry, _cameraHelperCamera, w, h, farZ);

    // up

    _cameraHelperSetPoint('u1', pointMap, geometry, _cameraHelperCamera, w * 0.7, h * 1.1, nearZ);
    _cameraHelperSetPoint('u2', pointMap, geometry, _cameraHelperCamera, -w * 0.7, h * 1.1, nearZ);
    _cameraHelperSetPoint('u3', pointMap, geometry, _cameraHelperCamera, 0, h * 2, nearZ);

    // cross

    _cameraHelperSetPoint('cf1', pointMap, geometry, _cameraHelperCamera, -w, 0, farZ);
    _cameraHelperSetPoint('cf2', pointMap, geometry, _cameraHelperCamera, w, 0, farZ);
    _cameraHelperSetPoint('cf3', pointMap, geometry, _cameraHelperCamera, 0, -h, farZ);
    _cameraHelperSetPoint('cf4', pointMap, geometry, _cameraHelperCamera, 0, h, farZ);

    _cameraHelperSetPoint('cn1', pointMap, geometry, _cameraHelperCamera, -w, 0, nearZ);
    _cameraHelperSetPoint('cn2', pointMap, geometry, _cameraHelperCamera, w, 0, nearZ);
    _cameraHelperSetPoint('cn3', pointMap, geometry, _cameraHelperCamera, 0, -h, nearZ);
    _cameraHelperSetPoint('cn4', pointMap, geometry, _cameraHelperCamera, 0, h, nearZ);

    geometry.getAttribute('position')!.needsUpdate = true;
  }

  /// The reference's `clone()` builds the copy without a camera and throws (exception E-CLONE); this one visualizes the
  /// source's camera.
  @override
  CameraHelper clone([bool recursive = true]) {
    return CameraHelper(camera).copy(this, recursive) as CameraHelper;
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever this instance is
  /// no longer used in your app.
  @override
  void dispose() {
    super.dispose();

    geometry.dispose();
    (material! as Material).dispose();
  }
}

// Builds the line list the reference's constructor builds, filling `pointMap` with point name → vertex indices.
BufferGeometry _cameraHelperGeometry(Map<String, List<int>> pointMap) {
  final vertices = <double>[];
  final colors = <double>[];

  void addPoint(String id) {
    vertices.addAll([0, 0, 0]);
    colors.addAll([0, 0, 0]);

    pointMap.putIfAbsent(id, () => []).add((vertices.length ~/ 3) - 1);
  }

  void addLine(String a, String b) {
    addPoint(a);
    addPoint(b);
  }

  // near

  addLine('n1', 'n2');
  addLine('n2', 'n4');
  addLine('n4', 'n3');
  addLine('n3', 'n1');

  // far

  addLine('f1', 'f2');
  addLine('f2', 'f4');
  addLine('f4', 'f3');
  addLine('f3', 'f1');

  // sides

  addLine('n1', 'f1');
  addLine('n2', 'f2');
  addLine('n3', 'f3');
  addLine('n4', 'f4');

  // cone

  addLine('p', 'n1');
  addLine('p', 'n2');
  addLine('p', 'n3');
  addLine('p', 'n4');

  // up

  addLine('u1', 'u2');
  addLine('u2', 'u3');
  addLine('u3', 'u1');

  // target

  addLine('c', 't');
  addLine('p', 'c');

  // cross

  addLine('cn1', 'cn2');
  addLine('cn3', 'cn4');

  addLine('cf1', 'cf2');
  addLine('cf3', 'cf4');

  return BufferGeometry()
    ..setAttribute('position', Float32BufferAttribute(vertices, 3))
    ..setAttribute('color', Float32BufferAttribute(colors, 3));
}

void _cameraHelperSetPoint(
  String point,
  Map<String, List<int>> pointMap,
  BufferGeometry geometry,
  Camera camera,
  double x,
  double y,
  double z,
) {
  _cameraHelperVector.set(x, y, z).unproject(camera);

  final points = pointMap[point];

  if (points != null) {
    final position = geometry.getAttribute('position')!;

    for (var i = 0, l = points.length; i < l; i++) {
      position.setXYZ(points[i], _cameraHelperVector.x, _cameraHelperVector.y, _cameraHelperVector.z);
    }
  }
}
