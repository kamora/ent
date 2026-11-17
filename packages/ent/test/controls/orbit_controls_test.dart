import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

// Replays fixtures/values/orbit_controls.json (the reference's OrbitControls and MapControls in Node, `node
// tool/reference/js/orbit_controls.mjs`) operation by operation, comparing the camera, the target, the angles, the
// state, the events fired and update()'s result after every step.

// V8 and the Dart VM differ in the last ulp of `sin`, `acos`, `pow`; chained over a scenario that stays far
// below this bound (docs/porting-conventions.md).
const _tolerance = 1e-9;

var _deviation = 0.0;

void _near(num actual, num expected, String what) {
  final d = (actual - expected).abs() / math.max(1, math.max(actual.abs(), expected.abs()));
  _deviation = math.max(_deviation, d);

  if (!(d <= _tolerance)) {
    fail('$what: $actual, expected $expected');
  }
}

void _list(List<double> actual, List<Object?> expected, String what) {
  for (var i = 0; i < expected.length; i++) {
    _near(actual[i], expected[i]! as num, '$what[$i]');
  }
}

ControlsPointerEvent _pointer(Map<String, Object?> op) => ControlsPointerEvent(
  pointerId: (op['id'] as int?) ?? 1,
  pointerType: (op['type'] as String?) ?? 'mouse',
  button: (op['button'] as int?) ?? 0,
  clientX: (op['x']! as num).toDouble(),
  clientY: (op['y']! as num).toDouble(),
  ctrlKey: (op['ctrl'] as bool?) ?? false,
  shiftKey: (op['shift'] as bool?) ?? false,
);

double _num(Object? v) => (v! as num).toDouble();

void _set(OrbitControls controls, String key, Object? value) {
  switch (key) {
    case 'rotateSpeed':
      controls.rotateSpeed = _num(value);
    case 'zoomSpeed':
      controls.zoomSpeed = _num(value);
    case 'panSpeed':
      controls.panSpeed = _num(value);
    case 'screenSpacePanning':
      controls.screenSpacePanning = value! as bool;
    case 'enableDamping':
      controls.enableDamping = value! as bool;
    case 'dampingFactor':
      controls.dampingFactor = _num(value);
    case 'minPolarAngle':
      controls.minPolarAngle = _num(value);
    case 'maxPolarAngle':
      controls.maxPolarAngle = _num(value);
    case 'minAzimuthAngle':
      controls.minAzimuthAngle = _num(value);
    case 'maxAzimuthAngle':
      controls.maxAzimuthAngle = _num(value);
    case 'minDistance':
      controls.minDistance = _num(value);
    case 'maxDistance':
      controls.maxDistance = _num(value);
    case 'maxZoom':
      controls.maxZoom = _num(value);
    case 'maxTargetRadius':
      controls.maxTargetRadius = _num(value);
    case 'autoRotate':
      controls.autoRotate = value! as bool;
    case 'autoRotateSpeed':
      controls.autoRotateSpeed = _num(value);
    case 'zoomToCursor':
      controls.zoomToCursor = value! as bool;
    case 'enabled':
      controls.enabled = value! as bool;
    case 'enableRotate':
      controls.enableRotate = value! as bool;
    case 'enableZoom':
      controls.enableZoom = value! as bool;
    default:
      fail('unknown property $key');
  }
}

Object? _apply(OrbitControls controls, Map<String, Object?> op) {
  final value = op['value'];

  switch (op['op']) {
    case 'down':
      controls.onPointerDown(_pointer(op));
    case 'move':
      controls.onPointerMove(_pointer(op));
    case 'up':
      controls.onPointerUp(_pointer(op));
    case 'wheel':
      controls.onMouseWheel(
        ControlsWheelEvent(
          clientX: _num(op['x']),
          clientY: _num(op['y']),
          deltaY: _num(op['deltaY']),
          deltaMode: (op['mode'] as int?) ?? 0,
          ctrlKey: (op['ctrl'] as bool?) ?? false,
        ),
      );
    case 'key':
      final code = op['code']! as String;
      controls.onKeyDown(ControlsKeyEvent(code: code, key: code, shiftKey: (op['shift'] as bool?) ?? false));
    case 'controlDown':
      controls.interceptControlDown(ControlsKeyEvent(key: 'Control'));
    case 'listenKeys':
      controls.listenToKeyEvents(controls.domElement! as ControlsElement);
    case 'set':
      _set(controls, op['key']! as String, value);
    case 'target':
      controls.target.fromArray((value! as List<Object?>).cast<num>());
    case 'update':
      return controls.update((op['dt'] as num?)?.toDouble());
    case 'saveState':
      controls.saveState();
    case 'reset':
      controls.reset();
    case 'rotateLeft':
      controls.rotateLeft(_num(value));
    case 'rotateUp':
      controls.rotateUp(_num(value));
    case 'pan':
      final v = value! as List<Object?>;
      controls.pan(_num(v[0]), _num(v[1]));
    case 'dollyIn':
      controls.dollyIn(_num(value));
    case 'dollyOut':
      controls.dollyOut(_num(value));
    default:
      fail('unknown op ${op['op']}');
  }

  return null;
}

void _check(OrbitControls controls, List<String> events, Object? result, Map<String, Object?> s, String at) {
  final camera = controls.object;
  _list(camera.position.toArray(), s['position']! as List<Object?>, '$at position');
  _list(camera.quaternion.toArray(), s['quaternion']! as List<Object?>, '$at quaternion');
  _list(controls.target.toArray(), s['target']! as List<Object?>, '$at target');

  final zoom = camera is OrthographicCamera ? camera.zoom : (camera as PerspectiveCamera).zoom;
  _near(zoom, s['zoom']! as num, '$at zoom');
  _near(controls.getPolarAngle(), s['polar']! as num, '$at polar');
  _near(controls.getAzimuthalAngle(), s['azimuth']! as num, '$at azimuth');
  _near(controls.getDistance(), s['distance']! as num, '$at distance');
  expect(controls.state, s['state'], reason: '$at state');
  expect(events, s['events'], reason: '$at events');
  expect(result is bool ? result : null, s['result'], reason: '$at update() result');
  events.clear();
}

void main() {
  final file = File('../../fixtures/values/orbit_controls.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final width = _num(json['width']);
  final height = _num(json['height']);

  for (final scenario in (json['scenarios']! as List<Object?>).cast<Map<String, Object?>>()) {
    test('reference fixture: ${scenario['name']}', () {
      final Camera camera = scenario['camera'] == 'ortho'
          ? OrthographicCamera(-4, 4, 3, -3, 0.1, 100)
          : PerspectiveCamera(50, width / height, 0.1, 100);
      final up = scenario['up'] as List<Object?>?;

      if (up != null) {
        camera.up.fromArray(up.cast<num>());
      }

      camera.position.set(1, 2, 5);
      camera.updateMatrixWorld();

      final element = ControlsElement(clientWidth: width, clientHeight: height);
      final controls = scenario['controls'] == 'map' ? MapControls(camera, element) : OrbitControls(camera, element);
      final events = <String>[];

      for (final type in ['change', 'start', 'end']) {
        controls.addEventListener(type, (e) => events.add(type));
      }

      _check(controls, events, null, scenario['initial']! as Map<String, Object?>, 'initial');

      final steps = (scenario['steps']! as List<Object?>).cast<Map<String, Object?>>();

      for (var i = 0; i < steps.length; i++) {
        final op = steps[i]['op']! as Map<String, Object?>;
        _check(controls, events, _apply(controls, op), steps[i], 'step $i (${op['op']})');
      }
    });
  }

  tearDownAll(() => print('orbit_controls fixtures: max relative deviation $_deviation'));

  test('defaults match the reference', () {
    final controls = OrbitControls(PerspectiveCamera(), ControlsElement());
    expect(controls.enableDamping, false);
    expect(controls.dampingFactor, 0.05);
    expect([controls.rotateSpeed, controls.zoomSpeed, controls.panSpeed, controls.keyPanSpeed], [1, 1, 1, 7]);
    expect([controls.minDistance, controls.maxDistance], [0, double.infinity]);
    expect([controls.minPolarAngle, controls.maxPolarAngle], [0, math.pi]);
    expect([controls.minAzimuthAngle, controls.maxAzimuthAngle], [double.negativeInfinity, double.infinity]);
    expect(controls.screenSpacePanning, true);
    expect(controls.keys, {'LEFT': 'ArrowLeft', 'UP': 'ArrowUp', 'RIGHT': 'ArrowRight', 'BOTTOM': 'ArrowDown'});
    expect(controls.mouseButtons, {'LEFT': MOUSE.ROTATE, 'MIDDLE': MOUSE.DOLLY, 'RIGHT': MOUSE.PAN});
    expect(controls.touches, {'ONE': TOUCH.ROTATE, 'TWO': TOUCH.DOLLY_PAN});
    expect(controls.domElement, isA<ControlsElement>());
    expect((controls.domElement! as ControlsElement).touchAction, 'none');

    final map = MapControls(PerspectiveCamera(), ControlsElement());
    expect(map.screenSpacePanning, false);
    expect(map.mouseButtons, {'LEFT': MOUSE.PAN, 'MIDDLE': MOUSE.DOLLY, 'RIGHT': MOUSE.ROTATE});
    expect(map.touches, {'ONE': TOUCH.PAN, 'TWO': TOUCH.DOLLY_ROTATE});
  });

  test('dispose stops input like removed listeners', () {
    final element = ControlsElement(clientWidth: 800, clientHeight: 600);
    final controls = OrbitControls(PerspectiveCamera()..position.set(0, 0, 5), element);
    final position = controls.object.position.clone();
    controls.dispose();
    controls.onPointerDown(ControlsPointerEvent(pointerId: 1, clientX: 0, clientY: 0));
    controls.onPointerMove(ControlsPointerEvent(pointerId: 1, clientX: 100, clientY: 0));
    controls.onMouseWheel(ControlsWheelEvent(clientX: 0, clientY: 0, deltaY: -100));
    expect(controls.object.position.equals(position), true);
    expect(element.touchAction, '');
  });
}
