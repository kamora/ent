// Fixture codecs for the cameras group; state layouts follow tool/reference/js/types/cameras.mjs.

import 'package:ent/ent.dart';

import '../fixtures.dart';

/// Reads a state list front to back.
class _Reader {
  _Reader(this.state, [this.i = 0]);

  final List<Object?> state;
  int i;

  Object? next() => state[i++];

  double d() => next() as double;

  int n() => d().toInt();

  bool b() => next() as bool;

  List<double> list(int length) => [for (var k = 0; k < length; k++) d()];
}

// Object3D part: position, quaternion, scale, up, rotation (read back only: the quaternion sets it, as the reference's
// onChange callbacks do), matrix, matrixWorld, matrixAutoUpdate, matrixWorldNeedsUpdate, layers.
const int _object3dLength = 52;
const int _cameraLength = _object3dLength + 50;

void _readObject3D(Object3D o, _Reader r) {
  o.position.set(r.d(), r.d(), r.d());
  o.quaternion.set(r.d(), r.d(), r.d(), r.d());
  o.scale.set(r.d(), r.d(), r.d());
  o.up.set(r.d(), r.d(), r.d());
  r.i += 4;
  o.matrix.fromArray(r.list(16));
  o.matrixWorld.fromArray(r.list(16));
  o.matrixAutoUpdate = r.b();
  o.matrixWorldNeedsUpdate = r.b();
  o.layers.mask = r.n();
}

List<Object?> _object3d(Object3D o) {
  final q = o.quaternion, rotation = o.rotation;

  return [
    o.position.x,
    o.position.y,
    o.position.z,
    q.x,
    q.y,
    q.z,
    q.w,
    o.scale.x,
    o.scale.y,
    o.scale.z,
    o.up.x,
    o.up.y,
    o.up.z,
    rotation.x,
    rotation.y,
    rotation.z,
    rotation.order,
    ...o.matrix.elements,
    ...o.matrixWorld.elements,
    o.matrixAutoUpdate,
    o.matrixWorldNeedsUpdate,
    o.layers.mask,
  ];
}

void _readCamera(Camera c, _Reader r) {
  _readObject3D(c, r);
  c.matrixWorldInverse.fromArray(r.list(16));
  c.projectionMatrix.fromArray(r.list(16));
  c.projectionMatrixInverse.fromArray(r.list(16));
  c.coordinateSystem = r.n();
  c.reversedDepth = r.b();
}

List<Object?> _camera(Camera c) {
  return [
    ..._object3d(c),
    ...c.matrixWorldInverse.elements,
    ...c.projectionMatrix.elements,
    ...c.projectionMatrixInverse.elements,
    c.coordinateSystem,
    c.reversedDepth,
  ];
}

CameraView? _readView(_Reader r) {
  if (r.state[r.i] == null) {
    r.i += 7;
    return null;
  }

  return CameraView(
    enabled: r.b(),
    fullWidth: r.d(),
    fullHeight: r.d(),
    offsetX: r.d(),
    offsetY: r.d(),
    width: r.d(),
    height: r.d(),
  );
}

List<Object?> _view(CameraView? v) {
  if (v == null) {
    return List.filled(7, null);
  }

  return [v.enabled, v.fullWidth, v.fullHeight, v.offsetX, v.offsetY, v.width, v.height];
}

/// Applies a PerspectiveCamera state that starts at `r.i` to an existing camera.
void _readPerspective(PerspectiveCamera c, _Reader r) {
  _readCamera(c, r);
  c.fov = r.d();
  c.zoom = r.d();
  c.near = r.d();
  c.far = r.d();
  c.focus = r.d();
  c.aspect = r.d();
  c.filmGauge = r.d();
  c.filmOffset = r.d();
  c.view = _readView(r);
}

List<Object?> _perspective(PerspectiveCamera c) {
  return [..._camera(c), c.fov, c.zoom, c.near, c.far, c.focus, c.aspect, c.filmGauge, c.filmOffset, ..._view(c.view)];
}

const int _perspectiveLength = _cameraLength + 15;

PerspectiveCamera _newPerspective(List<Object?> s, int at) {
  final c = PerspectiveCamera();
  _readPerspective(c, _Reader(s, at));
  return c;
}

OrthographicCamera _newOrthographic(List<Object?> s) {
  final c = OrthographicCamera();
  final r = _Reader(s);
  _readCamera(c, r);
  c.left = r.d();
  c.right = r.d();
  c.top = r.d();
  c.bottom = r.d();
  c.near = r.d();
  c.far = r.d();
  c.zoom = r.d();
  c.view = _readView(r);
  return c;
}

List<Object?> _orthographic(OrthographicCamera c) {
  return [..._camera(c), c.left, c.right, c.top, c.bottom, c.near, c.far, c.zoom, ..._view(c.view)];
}

// StereoCamera: aspect, eyeSep, the private cache (7 nullable numbers), then cameraL and cameraR.
StereoCamera _newStereo(List<Object?> s) {
  final stereo = StereoCamera()
    ..aspect = s[0] as double
    ..eyeSep = s[1] as double
    ..cache = s.sublist(2, 9).cast<double?>();

  _readPerspective(stereo.cameraL, _Reader(s, 9));
  _readPerspective(stereo.cameraR, _Reader(s, 9 + _perspectiveLength));
  return stereo;
}

List<Object?> _stereo(StereoCamera s) {
  return [s.aspect, s.eyeSep, ...s.cache, ..._perspective(s.cameraL), ..._perspective(s.cameraR)];
}

// CubeCamera: coordinateSystem (or null), activeMipmapLevel, its own Object3D state, then 6 children.
CubeCamera _newCube(List<Object?> s) {
  const first = 2 + _object3dLength;
  final child = _newPerspective(s, first);
  final cube = CubeCamera(child.near, child.far);
  final r = _Reader(s);
  final system = r.next();

  cube.coordinateSystem = system == null ? null : (system as double).toInt();
  cube.activeMipmapLevel = r.n();
  _readObject3D(cube, r);

  for (final c in cube.children) {
    _readPerspective(c as PerspectiveCamera, r);
  }

  return cube;
}

List<Object?> _cube(CubeCamera c) {
  return [
    c.coordinateSystem,
    c.activeMipmapLevel,
    ..._object3d(c),
    for (final child in c.children) ..._perspective(child as PerspectiveCamera),
  ];
}

final Map<String, Codec> camerasCodecs = {
  'PerspectiveCamera': Codec((s) => _newPerspective(s, 0), (o) => _perspective(o as PerspectiveCamera)),
  'OrthographicCamera': Codec(_newOrthographic, (o) => _orthographic(o as OrthographicCamera)),
  'StereoCamera': Codec(_newStereo, (o) => _stereo(o as StereoCamera)),
  'CubeCamera': Codec(_newCube, (o) => _cube(o as CubeCamera)),
};
