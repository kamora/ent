// The reference unit tests of Raycaster. Dart tests also cover the traversal, sorting, layer filtering and propagation
// through a test object whose raycast() reports its own world position.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void checkRayDirectionAgainstReferenceVector(Vector3 rayDirection, Vector3 refVector) {
  const epsilon = 2.220446049250313e-16; // Number.EPSILON

  expect(
    refVector.x - rayDirection.x <= epsilon &&
        refVector.y - rayDirection.y <= epsilon &&
        refVector.z - rayDirection.z <= epsilon,
    isTrue,
    reason: 'camera is pointing to the same direction as expected',
  );
}

/// Reports a hit at its world position when that lies on the ray within near/far; returns [result].
class _Target extends Object3D {
  _Target(this.label, [this.result]);

  final String label;

  final bool? result;

  @override
  bool? raycast(Raycaster raycaster, List<Intersection> intersects) {
    final point = getWorldPosition(Vector3());
    final distance = raycaster.ray.origin.distanceTo(point);

    if (raycaster.ray.distanceSqToPoint(point) < 1e-12 && distance >= raycaster.near && distance <= raycaster.far) {
      intersects.add(Intersection(distance: distance, point: point, object: this));
    }

    return result;
  }
}

Raycaster getRaycaster() {
  return Raycaster(Vector3(0, 0, 0), Vector3(0, 0, -1), 1, 100);
}

List<Object3D> getObjectsToCheck() {
  final objects = <Object3D>[];

  final sphere1 = getSphere();
  sphere1.position.set(0, 0, -10);
  sphere1.name = '1';
  objects.add(sphere1);

  final sphere11 = getSphere();
  sphere11.position.set(0, 0, 1);
  sphere11.name = '11';
  sphere1.add(sphere11);

  final sphere12 = getSphere();
  sphere12.position.set(0, 0, -1);
  sphere12.name = '12';
  sphere1.add(sphere12);

  final sphere2 = getSphere();
  sphere2.position.set(-5, 0, -5);
  sphere2.name = '2';
  objects.add(sphere2);

  for (var i = 0; i < objects.length; i++) {
    objects[i].updateMatrixWorld();
  }

  return objects;
}

Mesh getSphere() {
  return Mesh(SphereGeometry(1, 100, 100));
}

void main() {
  group('Core', () {
    group('Raycaster', () {
      // INSTANCING
      test('Instancing', () {
        // no params
        final object = Raycaster();
        expect(object, isNotNull, reason: 'Can instantiate a Raycaster.');
      });

      // PUBLIC
      test('set', () {
        final origin = Vector3(0, 0, 0);
        final direction = Vector3(0, 0, -1);
        final a = Raycaster(origin.clone(), direction.clone());

        expect(a.ray.origin.equals(origin), isTrue, reason: 'Origin is correct');
        expect(a.ray.direction.equals(direction), isTrue, reason: 'Direction is correct');

        origin.set(1, 1, 1);
        direction.set(-1, 0, 0);
        a.set(origin, direction);

        expect(a.ray.origin.equals(origin), isTrue, reason: 'Origin was set correctly');
        expect(a.ray.direction.equals(direction), isTrue, reason: 'Direction was set correctly');
      });

      test('setFromCamera (Perspective)', () {
        final raycaster = Raycaster();
        final rayDirection = raycaster.ray.direction;
        final camera = PerspectiveCamera(90, 1, 1, 1000);

        raycaster.setFromCamera(Vector2(0, 0), camera);
        expect(
          rayDirection.x == 0 && rayDirection.y == 0 && rayDirection.z == -1,
          isTrue,
          reason: 'camera is looking straight to -z and so does the ray in the middle of the screen',
        );

        const step = 0.1;

        for (var x = -1.0; x <= 1; x += step) {
          for (var y = -1.0; y <= 1; y += step) {
            raycaster.setFromCamera(Vector2(x, y), camera);

            final refVector = Vector3(x, y, -1).normalize();

            checkRayDirectionAgainstReferenceVector(rayDirection, refVector);
          }
        }
      });

      test('setFromCamera (Orthographic)', () {
        final raycaster = Raycaster();
        final rayOrigin = raycaster.ray.origin;
        final rayDirection = raycaster.ray.direction;
        final camera = OrthographicCamera(-1, 1, 1, -1, 0, 1000);
        final expectedOrigin = Vector3(0, 0, 0);
        final expectedDirection = Vector3(0, 0, -1);

        raycaster.setFromCamera(Vector2(0, 0), camera);
        expect(rayOrigin.equals(expectedOrigin), isTrue, reason: 'Ray origin has the right coordinates');
        expect(rayDirection.equals(expectedDirection), isTrue, reason: 'Camera and Ray are pointing towards -z');
      });

      test('intersectObject', () {
        final raycaster = getRaycaster();
        final objectsToCheck = getObjectsToCheck();

        expect(
          raycaster.intersectObject(objectsToCheck[0], false).length,
          1,
          reason: 'no recursive search should lead to one hit',
        );
        expect(
          raycaster.intersectObject(objectsToCheck[0]).length,
          3,
          reason: 'recursive search should lead to three hits',
        );

        final intersections = raycaster.intersectObject(objectsToCheck[0]);

        for (var i = 0; i < intersections.length - 1; i++) {
          expect(
            intersections[i].distance <= intersections[i + 1].distance,
            isTrue,
            reason: 'intersections are sorted',
          );
        }
      });

      test('intersectObjects', () {
        final raycaster = getRaycaster();
        final objectsToCheck = getObjectsToCheck();

        expect(
          raycaster.intersectObjects(objectsToCheck, false).length,
          1,
          reason: 'no recursive search should lead to one hit',
        );
        expect(
          raycaster.intersectObjects(objectsToCheck).length,
          3,
          reason: 'recursive search should lead to three hits',
        );

        final intersections = raycaster.intersectObjects(objectsToCheck);

        for (var i = 0; i < intersections.length - 1; i++) {
          expect(
            intersections[i].distance <= intersections[i + 1].distance,
            isTrue,
            reason: 'intersections are sorted',
          );
        }
      });

      test('intersectObject (Perspective, WebGPU coordinate system)', () {
        final camera = PerspectiveCamera(90, 1, 0.1, 100);
        camera.coordinateSystem = WebGPUCoordinateSystem;
        camera.updateProjectionMatrix();

        final front = getSphere();
        front.position.set(0, 0, -5);
        front.updateMatrixWorld();

        final behind = getSphere();
        behind.position.set(0, 0, 5);
        behind.updateMatrixWorld();

        final raycaster = Raycaster();
        raycaster.setFromCamera(Vector2(0, 0), camera);

        expect(
          raycaster.intersectObject(front).length,
          1,
          reason: 'Sphere in front of the perspective camera is intersected under WebGPU coordinate system.',
        );
        expect(
          raycaster.intersectObject(behind).length,
          0,
          reason: 'Sphere behind the perspective camera is not intersected under WebGPU coordinate system.',
        );
      });

      test('intersectObject (Orthographic, WebGPU coordinate system)', () {
        final camera = OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
        camera.coordinateSystem = WebGPUCoordinateSystem;
        camera.updateProjectionMatrix();

        final front = getSphere();
        front.position.set(0, 0, -5);
        front.updateMatrixWorld();

        final behind = getSphere();
        behind.position.set(0, 0, 5);
        behind.updateMatrixWorld();

        final raycaster = Raycaster();
        raycaster.setFromCamera(Vector2(0, 0), camera);

        expect(
          raycaster.intersectObject(front).length,
          1,
          reason: 'Sphere in front of the orthographic camera is intersected under WebGPU coordinate system.',
        );
        expect(
          raycaster.intersectObject(behind).length,
          0,
          reason: 'Sphere behind the orthographic camera is not intersected under WebGPU coordinate system.',
        );
      });

      test('intersectObject (Perspective, reversed depth)', () {
        final camera = PerspectiveCamera(90, 1, 0.1, 100);
        camera.reversedDepth = true;
        camera.updateProjectionMatrix();

        final front = getSphere();
        front.position.set(0, 0, -5);
        front.updateMatrixWorld();

        final behind = getSphere();
        behind.position.set(0, 0, 5);
        behind.updateMatrixWorld();

        final raycaster = Raycaster();
        raycaster.setFromCamera(Vector2(0, 0), camera);

        expect(
          raycaster.intersectObject(front).length,
          1,
          reason: 'Sphere in front of the perspective camera is intersected with reversed depth.',
        );
        expect(
          raycaster.intersectObject(behind).length,
          0,
          reason: 'Sphere behind the perspective camera is not intersected with reversed depth.',
        );
      });

      test('intersectObject (Orthographic, reversed depth)', () {
        final camera = OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
        camera.reversedDepth = true;
        camera.updateProjectionMatrix();

        final front = getSphere();
        front.position.set(0, 0, -5);
        front.updateMatrixWorld();

        final behind = getSphere();
        behind.position.set(0, 0, 5);
        behind.updateMatrixWorld();

        final raycaster = Raycaster();
        raycaster.setFromCamera(Vector2(0, 0), camera);

        expect(
          raycaster.intersectObject(front).length,
          1,
          reason: 'Sphere in front of the orthographic camera is intersected with reversed depth.',
        );
        expect(
          raycaster.intersectObject(behind).length,
          0,
          reason: 'Sphere behind the orthographic camera is not intersected with reversed depth.',
        );
      });

      test('Line intersection threshold', () {
        final raycaster = getRaycaster();
        final points = [Vector3(-2, -10, -5), Vector3(-2, 10, -5)];
        final geometry = BufferGeometry().setFromPoints(points);
        final line = Line(geometry, null);

        raycaster.params['Line']!['threshold'] = 1.999;
        expect(
          raycaster.intersectObject(line).length,
          0,
          reason: 'no Line intersection with a not-large-enough threshold',
        );

        raycaster.params['Line']!['threshold'] = 2.001;
        expect(
          raycaster.intersectObject(line).length,
          1,
          reason: 'successful Line intersection with a large-enough threshold',
        );
      });

      test('Points intersection threshold', () {
        final raycaster = getRaycaster();
        final coordinates = [Vector3(-2, 0, -5)];
        final geometry = BufferGeometry().setFromPoints(coordinates);
        final points = Points(geometry, null);

        raycaster.params['Points']!['threshold'] = 1.999;
        expect(
          raycaster.intersectObject(points).length,
          0,
          reason: 'no Points intersection with a not-large-enough threshold',
        );

        raycaster.params['Points']!['threshold'] = 2.001;
        expect(
          raycaster.intersectObject(points).length,
          1,
          reason: 'successful Points intersection with a large-enough threshold',
        );
      });
    });

    group('Raycaster (Dart)', () {
      List<_Target> targets() {
        // The reference layout: sphere1 at z = -10 with children at local z = +1 and -1, sphere2 off the ray.
        final sphere1 = _Target('1')..position.set(0, 0, -10);
        final sphere11 = _Target('11')..position.set(0, 0, 1);
        final sphere12 = _Target('12')..position.set(0, 0, -1);
        sphere1
          ..add(sphere11)
          ..add(sphere12);
        final sphere2 = _Target('2')..position.set(-5, 0, -5);

        final objects = [sphere1, sphere2];

        for (final o in objects) {
          o.updateMatrixWorld();
        }

        return objects;
      }

      List<String> labels(List<Intersection> list) => [for (final i in list) (i.object as _Target).label];

      test('intersectObject: recursion and sorting', () {
        final raycaster = getRaycaster();
        final objects = targets();

        expect(labels(raycaster.intersectObject(objects[0], false)), ['1'], reason: 'no recursion: one hit');
        expect(labels(raycaster.intersectObject(objects[0])), ['11', '1', '12'], reason: 'sorted by distance');
      });

      test('intersectObjects: recursion and sorting', () {
        final raycaster = getRaycaster();
        final objects = targets();

        expect(labels(raycaster.intersectObjects(objects, false)), ['1']);
        expect(labels(raycaster.intersectObjects(objects)), ['11', '1', '12']);
      });

      test('intersect results are appended to the given list and sorted with it', () {
        final raycaster = getRaycaster();
        final objects = targets();
        final existing = [Intersection(distance: 9.5, point: Vector3(), object: Object3D())];
        final result = raycaster.intersectObject(objects[0], true, existing);

        expect(identical(result, existing), isTrue);
        expect([for (final i in result) i.distance], [9, 9.5, 10, 11]);
      });

      test('equal distances keep their order (stable sort)', () {
        final raycaster = getRaycaster();
        final a = _Target('a')..position.set(0, 0, -5);
        final b = _Target('b')..position.set(0, 0, -5);
        final c = _Target('c')..position.set(0, 0, -2);
        final root = Object3D()
          ..add(a)
          ..add(b)
          ..add(c);
        root.updateMatrixWorld();

        expect(labels(raycaster.intersectObject(root)), ['c', 'a', 'b']);
      });

      test('raycast returning false stops descending into the children', () {
        final raycaster = getRaycaster();
        final parent = _Target('p', false)..position.set(0, 0, -10);
        parent.add(_Target('child')..position.set(0, 0, 1));
        parent.updateMatrixWorld();

        expect(labels(raycaster.intersectObject(parent)), ['p']);
      });

      test('layers filter objects but not their children', () {
        final raycaster = getRaycaster();
        final objects = targets();
        objects[0].layers.set(2);

        expect(labels(raycaster.intersectObject(objects[0])), ['11', '12']);

        raycaster.layers.enable(2);
        expect(labels(raycaster.intersectObject(objects[0])), ['11', '1', '12']);
      });

      test('params defaults', () {
        final params = Raycaster().params;
        expect(params.keys, ['Mesh', 'Line', 'LOD', 'Points', 'Sprite']);
        expect(params['Line']!['threshold'], 1);
        expect(params['Points']!['threshold'], 1);
      });

      test('constructor defaults', () {
        final raycaster = Raycaster();
        expect(raycaster.near, 0);
        expect(raycaster.far, double.infinity);
        expect(raycaster.camera, isNull);
        expect(raycaster.ray.origin.toArray(), [0, 0, 0]);
        expect(raycaster.ray.direction.toArray(), [0, 0, -1]);
      });

      test('setFromXRController', () {
        final controller = Object3D();
        controller.position.set(1, 2, 3);
        controller.rotation.set(0, 1.5707963267948966, 0);
        controller.updateMatrixWorld();

        final raycaster = Raycaster();
        expect(raycaster.setFromXRController(controller), same(raycaster));
        expect(raycaster.ray.origin.toArray(), [1, 2, 3]);

        // Rotated a quarter turn around +y, -z becomes -x.
        expect(raycaster.ray.direction.x, closeTo(-1, 1e-15));
        expect(raycaster.ray.direction.y, closeTo(0, 1e-15));
        expect(raycaster.ray.direction.z, closeTo(0, 1e-15));
      });

      test('setFromCamera with another camera logs an error', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$type $message'));

        try {
          final raycaster = Raycaster();
          raycaster.setFromCamera(Vector2(0, 0), Camera());
          expect(messages, ['error ENT.Raycaster: Unsupported camera type: Camera']);
          expect(raycaster.camera, isNull);
        } finally {
          setConsoleFunction(null);
        }
      });

      test('setFromCamera sets the camera field', () {
        final raycaster = Raycaster();
        final camera = PerspectiveCamera(50, 1, 0.1, 10);
        raycaster.setFromCamera(Vector2(0.5, -0.5), camera);
        expect(raycaster.camera, same(camera));
      });
    });
  });

  // Named coverage tests: expected values printed from the reference source in Node.
  group('Raycaster coverage', () {
    test('defaults: ray near far', () {
      final raycaster = Raycaster();
      expect(raycaster.ray.origin.toArray(), [0, 0, 0]);
      expect(raycaster.ray.direction.toArray(), [0, 0, -1]);
      expect([raycaster.near, raycaster.far], [0, double.infinity]);
    });
  });
}
