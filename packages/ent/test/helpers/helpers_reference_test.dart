// Every helper's geometry arrays, matrices and colors in representative setups, compared with values the reference
// source produces: tool/reference/js/helpers.mjs writes fixtures/values/helpers.json. Each setup here mirrors the one
// in that script.

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'helpers_support.dart';

List<double> array(BufferGeometry geometry, String name) {
  return (geometry.getAttribute(name)!.array as List<double>).toList();
}

List<double> xyz(Vector3 v) => [v.x, v.y, v.z];

List<double> quat(Quaternion q) => [q.x, q.y, q.z, q.w];

List<double> rgb(Color c) => [c.r, c.g, c.b];

List<double> sphere(Sphere s) => [...xyz(s.center), s.radius];

/// Float32 attribute arrays: see [expectClose].
void expectArray(Object? actual, List<String> path) =>
    expectClose(actual, refAt(path), tolerance: 1e-6, path: path.join('.'));

void expectValue(Object? actual, List<String> path) => expectClose(actual, refAt(path), path: path.join('.'));

void main() {
  group('Helpers reference', () {
    test('AxesHelper', () {
      final axes = AxesHelper(5);
      expectArray(array(axes.geometry, 'position'), ['axes', 'position']);
      expectArray(array(axes.geometry, 'color'), ['axes', 'color']);
      axes.setColors(0x123456, 'red', Color(0.1, 0.2, 0.3));
      expectArray(array(axes.geometry, 'color'), ['axes', 'setColors']);
    });

    test('GridHelper', () {
      final grid = GridHelper();
      expectArray(array(grid.geometry, 'position'), ['gridDefault', 'position']);
      expectArray(array(grid.geometry, 'color'), ['gridDefault', 'color']);

      final custom = GridHelper(7, 5, 0xff0000, 'blue');
      expectArray(array(custom.geometry, 'position'), ['grid', 'position']);
      expectArray(array(custom.geometry, 'color'), ['grid', 'color']);
    });

    test('PolarGridHelper', () {
      for (final (name, helper) in [
        ('polarDefault', PolarGridHelper()),
        ('polar', PolarGridHelper(3, 5, 3, 7, 0x00ff00, 0x0000ff)),
        ('polarOneSector', PolarGridHelper(2, 1, 2, 4)),
      ]) {
        expectArray(array(helper.geometry, 'position'), [name, 'position']);
        expectArray(array(helper.geometry, 'color'), [name, 'color']);
      }
    });

    test('ArrowHelper', () {
      void expectArrow(ArrowHelper a, List<String> path) {
        expectValue(xyz(a.position), [...path, 'position']);
        expectValue(quat(a.quaternion), [...path, 'quaternion']);
        expectValue(a.line.matrix.elements.toList(), [...path, 'line']);
        expectValue(a.cone.matrix.elements.toList(), [...path, 'cone']);
        expectValue(rgb((a.line.material! as LineBasicMaterial).color), [...path, 'lineColor']);
        expectValue(rgb((a.cone.material! as MeshBasicMaterial).color), [...path, 'coneColor']);
      }

      final arrow = ArrowHelper(Vector3(1, 2, 3).normalize(), Vector3(1, -2, 3), 4, 0xff00ff, 1, 0.5);
      expectArrow(arrow, ['arrow']);
      arrow.setDirection(Vector3(0, 1, 0));
      expectValue(quat(arrow.quaternion), ['arrow', 'up']);
      arrow.setDirection(Vector3(0, -1, 0));
      expectValue(quat(arrow.quaternion), ['arrow', 'down']);
      arrow.setLength(2);
      arrow.setColor('#00ff88');
      expectArrow(arrow, ['arrow', 'after']);
      expectArrow(ArrowHelper(), ['arrowDefault']);
      expectArrow(ArrowHelper(Vector3(1, 0, 0), null, 0.1), ['arrowShort']);
    });

    test('Box3Helper', () {
      final helper = Box3Helper(Box3(Vector3(-1, -2, -3), Vector3(4, 5, 6)), 0x00ffff)..updateMatrixWorld();
      expectValue(helper.matrixWorld.elements.toList(), ['box3', 'matrixWorld']);
      expectValue(sphere(helper.geometry.boundingSphere!), ['box3', 'boundingSphere']);
      expectValue(rgb((helper.material! as LineBasicMaterial).color), ['box3', 'color']);
    });

    test('BoxHelper', () {
      final mesh = Mesh(BoxGeometry(1, 2, 3));
      mesh.position.set(1, 2, 3);
      mesh.rotation.set(0.3, 0.5, 0.7);
      mesh.updateMatrixWorld();

      final helper = BoxHelper(mesh, 0xff0000);
      expectArray(array(helper.geometry, 'position'), ['boxHelper', 'position']);
      expectValue(sphere(helper.geometry.boundingSphere!), ['boxHelper', 'boundingSphere']);

      final sphereMesh = Mesh(SphereGeometry(2));
      sphereMesh.position.set(-3, 0, 1);
      sphereMesh.updateMatrixWorld();
      helper.setFromObject(sphereMesh);
      expectArray(array(helper.geometry, 'position'), ['boxHelper', 'setFromObject']);
    });

    test('CameraHelper', () {
      void expectCamera(CameraHelper h, String name) {
        expectArray(array(h.geometry, 'position'), [name, 'position']);
        expectArray(array(h.geometry, 'color'), [name, 'color']);
      }

      final perspective = PerspectiveCamera(50, 1.5, 0.1, 100);
      perspective.position.set(1, 2, 3);
      perspective.updateMatrixWorld();
      expectCamera(CameraHelper(perspective), 'cameraPerspective');

      final ortho = OrthographicCamera(-2, 3, 4, -1, 0.5, 20)..coordinateSystem = WebGPUCoordinateSystem;
      ortho.updateProjectionMatrix();
      expectCamera(CameraHelper(ortho), 'cameraOrthoWebGPU');

      // Node sets the private `_reversedDepth` that renderers set; the test sets it through the test-only setter.
      final reversed = PerspectiveCamera(70, 0.8, 1, 50)..reversedDepth = true;
      reversed.updateProjectionMatrix();
      expectCamera(CameraHelper(reversed), 'cameraReversed');
    });

    test('DirectionalLightHelper', () {
      void expectDirectional(DirectionalLightHelper h, String name) {
        expectValue(quat(h.lightPlane.quaternion), [name, 'plane']);
        expectValue(quat(h.targetLine.quaternion), [name, 'target']);
        expectValue(xyz(h.targetLine.scale), [name, 'targetScale']);
        expectArray(array(h.lightPlane.geometry, 'position'), [name, 'planePosition']);
        expectValue(rgb((h.lightPlane.material! as LineBasicMaterial).color), [name, 'color']);
      }

      final light = DirectionalLight(0x8899aa);
      light.position.set(3, 4, 5);
      light.target.position.set(1, 0, -1);
      expectDirectional(DirectionalLightHelper(light, 2), 'directional');
      expectDirectional(DirectionalLightHelper(light, null, 0xff0000), 'directionalColor');
    });

    test('HemisphereLightHelper', () {
      final light = HemisphereLight(0x123456, 0xabcdef);
      light.position.set(1, 2, 3);

      final helper = HemisphereLightHelper(light, 2);
      final mesh = helper.children[0] as Mesh;
      expectArray(array(mesh.geometry, 'color'), ['hemisphere', 'color']);
      expectValue(quat(mesh.quaternion), ['hemisphere', 'quaternion']);
      expect(helper.material.vertexColors, refAt(['hemisphere', 'vertexColors']));

      final colored = HemisphereLightHelper(light, 1, 0x00ff00);
      expectValue(rgb(colored.material.color), ['hemisphereColor', 'color']);
      expect(colored.material.vertexColors, refAt(['hemisphereColor', 'vertexColors']));
    });

    test('PointLightHelper', () {
      final light = PointLight(0xff0000);
      light.position.set(1, 2, 3);

      final helper = PointLightHelper(light, 3);
      expectValue(rgb((helper.material! as MeshBasicMaterial).color), ['point', 'color']);
      expectArray(array(helper.geometry, 'position'), ['point', 'position']);
      expectValue(rgb((PointLightHelper(light, 1, 'blue').material! as MeshBasicMaterial).color), ['pointColor']);
    });

    test('SpotLightHelper', () {
      void expectSpot(SpotLightHelper h, String name) {
        expectValue(h.matrix.elements.toList(), [name, 'matrix']);
        expectValue(xyz(h.cone.scale), [name, 'scale']);
        expectValue(quat(h.cone.quaternion), [name, 'quaternion']);
        expectValue(rgb((h.cone.material! as LineBasicMaterial).color), [name, 'color']);
      }

      final light = SpotLight(0x00ff00, 1, 10, math.pi / 6);
      light.position.set(1, 2, 3);

      final helper = SpotLightHelper(light);
      expectSpot(helper, 'spot');
      expectArray(array(helper.cone.geometry, 'position'), ['spot', 'position']);

      final group = Group();
      group.position.set(-1, 0.5, 2);
      group.rotation.set(0.2, -0.4, 0.1);

      final child = SpotLightHelper(light, 0xff00ff);
      group.add(child);
      light.distance = 0;
      light.target.position.set(2, -1, 0);
      child.update();
      expectSpot(child, 'spotParent');
    });

    test('PlaneHelper', () {
      final helper = PlaneHelper(Plane(Vector3(1, 1, 0.2).normalize(), 3), 2, 0xff0000)..updateMatrixWorld();
      expectValue(helper.matrixWorld.elements.toList(), ['plane', 'matrixWorld']);
      expectValue(helper.children[0].matrixWorld.elements.toList(), ['plane', 'child']);
    });

    test('SkeletonHelper', () {
      final root = Object3D();
      root.position.set(0.5, -1, 2);
      root.rotation.set(0, 0.3, 0);

      final b0 = Bone(), b1 = Bone(), b2 = Bone(), loose = Object3D(), b3 = Bone();
      b1.position.set(0, 1, 0);
      b2.position.set(0.5, 1, 0);
      b2.rotation.set(0.4, 0, 0.2);
      b3.position.set(1, 0, 0);
      root.add(b0);
      b0.add(b1);
      b1.add(b2);
      b2.add(loose);
      loose.add(b3);
      root.updateMatrixWorld(true);

      final helper = SkeletonHelper(root)..updateMatrixWorld();
      expect(helper.bones.length, refAt(['skeleton', 'bones']));
      expectArray(array(helper.geometry, 'position'), ['skeleton', 'position']);
      expectArray(array(helper.geometry, 'color'), ['skeleton', 'color']);
    });
  });
}
