// Regression tests for the objects (Mesh, Line, LineSegments, LineLoop, Points, Sprite, LOD) against the reference:
// tool/reference/js/objects_raycast.mjs builds these scenes in Node and writes fixtures/values/objects_raycast.json;
// each test here builds the same scene and compares.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

final Map<String, Object?> reference =
    (jsonDecode(File('../../fixtures/values/objects_raycast.json').readAsStringSync())
            as Map<String, Object?>)['results']
        as Map<String, Object?>;

/// Numbers match exactly or within the fixture tolerance, `1e-9 · max(1, |a|, |b|)`.
void expectNumber(Object? actual, Object? expected, String at) {
  final a = (actual as num).toDouble();
  final e = (expected as num).toDouble();
  final scale = [1.0, a.abs(), e.abs()].reduce((x, y) => x > y ? x : y);
  expect((a - e).abs() <= 1e-9 * scale, isTrue, reason: '$at: expected $e, got $a');
}

void expectVector(Object? actual, Object? expected, String at) {
  if (expected == null) {
    expect(actual, isNull, reason: at);
    return;
  }

  final values = switch (actual) {
    Vector2 v => [v.x, v.y],
    Vector3 v => [v.x, v.y, v.z],
    _ => throw StateError('$at: expected a vector, got $actual'),
  };
  final list = expected as List<Object?>;
  expect(values.length, list.length, reason: at);

  for (var i = 0; i < list.length; i++) {
    expectNumber(values[i], list[i], '$at[$i]');
  }
}

/// Compares intersections with the reference shape written by objects_raycast.mjs.
void expectHits(List<Intersection> hits, String name) {
  final expected = (reference[name] as List<Object?>).cast<Map<String, Object?>>();
  expect(hits.length, expected.length, reason: '$name: hit count');

  for (var i = 0; i < hits.length; i++) {
    final hit = hits[i];
    final e = expected[i];
    final at = '$name[$i]';

    expectNumber(hit.distance, e['d'], '$at.distance');
    expectVector(hit.point, e['p'], '$at.point');
    expectVector(hit.uv, e['uv'], '$at.uv');
    expectVector(hit.uv1, e['uv1'], '$at.uv1');
    expectVector(hit.normal, e['n'], '$at.normal');
    expectVector(hit.barycoord, e['b'], '$at.barycoord');
    expect(hit.faceIndex, e['fi'], reason: '$at.faceIndex');

    if (e.containsKey('i')) {
      expect(hit.index, e['i'], reason: '$at.index');
    }

    if (e['dr'] != null) {
      expectNumber(hit.distanceToRay, e['dr'], '$at.distanceToRay');
    }

    final face = e['f'] as List<Object?>?;

    if (face == null) {
      expect(hit.face, isNull, reason: '$at.face');
    } else {
      expect([hit.face!.a, hit.face!.b, hit.face!.c], face.sublist(0, 3), reason: '$at.face');
      expectVector(hit.face!.normal, face[3], '$at.face.normal');
      expect(hit.face!.materialIndex, face[4], reason: '$at.face.materialIndex');
    }
  }
}

Raycaster ray(List<double> origin, List<double> direction) {
  return Raycaster(
    Vector3(origin[0], origin[1], origin[2]),
    Vector3(direction[0], direction[1], direction[2]).normalize(),
  );
}

List<double> repeat(List<double> item, int times) {
  return [for (var i = 0; i < times; i++) ...item];
}

/// Two quads in the z=0 and z=-1 planes, non-indexed, with uv, uv1 and normals.
BufferGeometry quads() {
  return BufferGeometry()
    ..setAttribute(
      'position',
      Float32BufferAttribute([
        -1, -1, 0, 1, -1, 0, 1, 1, 0, -1, -1, 0, 1, 1, 0, -1, 1, 0, //
        -1, -1, -1, 1, -1, -1, 1, 1, -1, -1, -1, -1, 1, 1, -1, -1, 1, -1, //
      ], 3),
    )
    ..setAttribute(
      'uv',
      Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1], 2),
    )
    ..setAttribute(
      'uv1',
      Float32BufferAttribute([0.5, 0, 1, 0, 1, 0.5, 0.5, 0, 1, 0.5, 0.5, 0.5, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1], 2),
    )
    ..setAttribute('normal', Float32BufferAttribute(repeat([0.2, 0.1, 1], 12), 3));
}

BufferGeometry lineGeometry() {
  return BufferGeometry()
    ..setAttribute('position', Float32BufferAttribute([-1, 0, -5, 1, 0, -5, 1, 1, -5, -1, 1, -5], 3));
}

void main() {
  group('Objects', () {
    group('reference', () {
      test('Mesh raycast', () {
        final m = Mesh(quads());
        m.position.set(0.1, 0.2, -3);
        m.rotation.y = 0.3;
        m.updateMatrixWorld();
        expectHits(ray([0.2, 0.3, 0], [0, 0, -1]).intersectObject(m), 'meshFront');
      });

      test('Mesh raycast DoubleSide', () {
        final m = Mesh(quads(), MeshBasicMaterial()..side = DoubleSide);
        m.position.set(0, 0, -3);
        m.updateMatrixWorld();
        expectHits(ray([0.3, -0.4, -10], [0, 0, 1]).intersectObject(m), 'meshDoubleFromBehind');
      });

      test('Mesh raycast BackSide', () {
        final m = Mesh(quads(), MeshBasicMaterial()..side = BackSide);
        m.position.set(0, 0, -3);
        m.updateMatrixWorld();
        expectHits(ray([0.3, -0.4, 0], [0, 0, -1]).intersectObject(m), 'meshBackFront');
        expectHits(ray([0.3, -0.4, -10], [0, 0, 1]).intersectObject(m), 'meshBackBehind');
      });

      test('Mesh raycast groups with a material array', () {
        final g = quads()
          ..addGroup(0, 3, 1)
          ..addGroup(3, 3, 0)
          ..addGroup(6, 6, 1);
        final m = Mesh(g, [MeshBasicMaterial(), MeshBasicMaterial()..side = DoubleSide]);
        m.position.set(0, 0, -3);
        m.updateMatrixWorld();
        expectHits(ray([0.5, -0.2, 0], [0, 0, -1]).intersectObject(m), 'meshGroups');
        expectHits(ray([0.5, -0.2, -10], [0, 0, 1]).intersectObject(m), 'meshGroupsBehind');
      });

      test('Mesh raycast drawRange', () {
        final g = quads()..setDrawRange(3, 6);
        final m = Mesh(g);
        m.position.set(0, 0, -3);
        m.updateMatrixWorld();
        expectHits(ray([-0.5, 0.5, 0], [0, 0, -1]).intersectObject(m), 'meshDrawRange');
      });

      test('Mesh raycast indexed', () {
        final idx = BufferGeometry()
          ..setAttribute('position', Float32BufferAttribute([-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0], 3))
          ..setAttribute('uv', Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 1], 2))
          ..setIndex(<int>[0, 1, 2, 0, 2, 3])
          ..addGroup(0, 3, 0)
          ..addGroup(3, 3, 1);

        final m = Mesh(idx, [MeshBasicMaterial(), MeshBasicMaterial()]);
        m.position.set(0, 0, -2);
        m.scale.set(2, 1, 1);
        m.updateMatrixWorld();
        expectHits(ray([-0.5, 0.5, 0], [0.05, 0, -1]).intersectObject(m), 'meshIndexedGroups');

        final m2 = Mesh(idx);
        m2.position.set(0, 0, -2);
        m2.updateMatrixWorld();
        expectHits(ray([0.6, -0.1, 0], [0, 0.02, -1]).intersectObject(m2), 'meshIndexed');
      });

      test('Mesh morph targets', () {
        final g = quads();
        g.morphAttributes['position'] = [
          Float32BufferAttribute(repeat([0, 0, 1], 12), 3),
        ];
        g.morphTargetsRelative = true;

        final m = Mesh(g);
        m.morphTargetInfluences![0] = 0.5;
        m.position.set(0, 0, -3);
        m.updateMatrixWorld();
        expectHits(ray([0.2, 0.3, 0], [0, 0, -1]).intersectObject(m), 'meshMorphRelative');
        expectVector(m.getVertexPosition(4, Vector3()), reference['vertexMorphRelative'], 'vertexMorphRelative');

        final g2 = quads();
        g2.morphAttributes['position'] = [
          Float32BufferAttribute([
            for (var i = 0; i < 12; i++) ...[i * 0.1, 0, 2],
          ], 3),
        ];

        final m2 = Mesh(g2);
        m2.morphTargetInfluences![0] = 0.25;
        expectVector(m2.getVertexPosition(7, Vector3()), reference['vertexMorphAbsolute'], 'vertexMorphAbsolute');
      });

      test('Mesh raycast near/far', () {
        final m = Mesh(quads());
        m.position.set(0, 0, -50);
        m.updateMatrixWorld();

        final rc = ray([0, 0, 0], [0, 0, -1]);
        rc.far = 40;
        expectHits(rc.intersectObject(m), 'meshFar');

        rc.far = 100;
        rc.near = 49.5;
        expectHits(rc.intersectObject(m), 'meshNear');
      });

      test('Line, LineSegments, LineLoop raycast', () {
        final l = Line(lineGeometry());
        l.updateMatrixWorld();

        final rc = ray([0, 0.5, 0], [0, 0, -1]);
        rc.params['Line']!['threshold'] = 0.6;
        expectHits(rc.intersectObject(l), 'line');
        expectHits(rc.intersectObject(LineSegments(lineGeometry())), 'lineSegments');
        expectHits(rc.intersectObject(LineLoop(lineGeometry())), 'lineLoop');

        final gi = lineGeometry()..setIndex(<int>[3, 2, 1, 0]);
        expectHits(rc.intersectObject(LineLoop(gi)), 'lineLoopIndexed');

        final closing = ray([-0.95, 0.5, 0], [0, 0, -1]);
        closing.params['Line']!['threshold'] = 0.3;
        expectHits(closing.intersectObject(LineLoop(lineGeometry())), 'lineLoopClosing');
        expectHits(closing.intersectObject(LineLoop(gi)), 'lineLoopClosingIndexed');
        expectHits(closing.intersectObject(Line(lineGeometry())), 'lineClosingNotLoop');

        final ls = LineSegments(gi);
        ls.scale.set(2, 2, 2);
        ls.updateMatrixWorld();
        expectHits(rc.intersectObject(ls), 'lineSegmentsIndexedScaled');
      });

      test('computeLineDistances', () {
        final g = lineGeometry();
        Line(g).computeLineDistances();
        expect(g.attributes['lineDistance']!.array.toList(), reference['lineDistances']);

        final g2 = lineGeometry();
        LineSegments(g2).computeLineDistances();
        expect(g2.attributes['lineDistance']!.array.toList(), reference['segmentDistances']);
      });

      test('Points raycast', () {
        final g = lineGeometry();
        final p = Points(g);
        p.position.set(0.1, 0, 0);
        p.updateMatrixWorld();

        final rc = ray([0.6, 0.4, 0], [0, 0.02, -1]);
        rc.params['Points']!['threshold'] = 1;
        expectHits(rc.intersectObject(p), 'points');

        g.setIndex(<int>[2, 1]);
        expectHits(rc.intersectObject(p), 'pointsIndexed');
      });

      test('Sprite raycast', () {
        final cam = PerspectiveCamera(60, 1, 0.1, 100);
        cam.position.set(0, 0, 5);
        cam.updateMatrixWorld();

        final s = Sprite();
        s.scale.set(2, 1, 1);
        s.center.set(0.25, 0.5);
        s.position.set(0.2, 0, 0);
        s.updateMatrixWorld();

        final rc = Raycaster();
        rc.setFromCamera(Vector2(0.05, 0.02), cam);
        expectHits(rc.intersectObject(s), 'sprite');

        final material = SpriteMaterial()
          ..rotation = 0.7
          ..sizeAttenuation = false;
        final s2 = Sprite(material);
        s2.position.set(0, 0.1, 0);
        s2.updateMatrixWorld();
        expectHits(rc.intersectObject(s2), 'spriteRotatedNoAttenuation');

        final ocam = OrthographicCamera(-2, 2, 2, -2, 0.1, 100);
        ocam.position.set(0, 0, 5);
        ocam.updateMatrixWorld();

        rc.setFromCamera(Vector2(0.2, 0.1), ocam);
        expectHits(rc.intersectObject(s2), 'spriteOrtho');

        rc.setFromCamera(Vector2(0.9, 0.9), ocam);
        expectHits(rc.intersectObject(s2), 'spriteMiss');

        expect((s.toJSON()['object'] as Map<String, Object?>)['center'], reference['spriteJSON']);
      });

      test('LOD update, removeLevel, toJSON', () {
        final lod = LOD();
        final a = Object3D(), b = Object3D(), c = Object3D();
        lod.addLevel(c, 50, 0.1);
        lod.addLevel(a, -5);
        lod.addLevel(b, 20, 0.25);

        final cam = PerspectiveCamera();
        final sequence = <List<Object>>[];

        for (final z in [0.0, 19.0, 21.0, 16.0, 14.0, 46.0, 55.0, 30.0, 100.0]) {
          cam.position.set(0, 0, z);
          cam.zoom = z == 30 ? 2 : 1;
          cam.updateMatrixWorld();
          lod.update(cam);
          sequence.add([lod.getCurrentLevel(), a.visible, b.visible, c.visible]);
        }

        expect(sequence, reference['lodSequence']);
        expect([
          for (final l in lod.levels) [l.distance, l.hysteresis],
        ], reference['lodDistances']);
        expect([
          lod.removeLevel(20),
          lod.removeLevel(7),
          lod.levels.length,
          lod.children.length,
        ], reference['lodRemove']);

        final json = lod.toJSON()['object'] as Map<String, Object?>;
        expect([
          json['autoUpdate'],
          [
            for (final l in (json['levels'] as List<Object?>).cast<Map<String, Object?>>())
              [l['distance'], l['hysteresis']],
          ],
        ], reference['lodJSON']);
      });
    });
  });
}
