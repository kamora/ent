// Dart tests derived from the reference source (no reference test covers them): toJSON/fromJSON of the geometries that
// reference shapes and curves, the map shapes they use (exception E-OBJECT), and clone() keeping the subclass
// (exception E-CLONE).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

Shape _square(double size) {
  return Shape()
    ..moveTo(0, 0)
    ..lineTo(0, size)
    ..lineTo(size, size)
    ..lineTo(size, 0)
    ..lineTo(0, 0);
}

List<num> _positions(BufferGeometry geometry) {
  return geometry.getAttribute('position')!.array;
}

void main() {
  group('Geometries serialization', () {
    test('ShapeGeometry toJSON lists shape uuids and fromJSON resolves them', () {
      final a = _square(1);
      final b = _square(2);
      final geometry = ShapeGeometry([a, b], 4);
      final json = geometry.toJSON();

      expect(json['shapes'], [a.uuid, b.uuid]);
      expect(json['curveSegments'], 4);

      final restored = ShapeGeometry.fromJSON(json, {a.uuid: a, b.uuid: b});
      expect(_positions(restored), _positions(geometry));
      expect(restored.groups.map((g) => [g.start, g.count, g.materialIndex]), [
        [0, 6, 0],
        [6, 6, 1],
      ]);
    });

    test('ShapeGeometry toJSON of a single shape', () {
      final shape = _square(1);

      expect(ShapeGeometry(shape).toJSON()['shapes'], [shape.uuid]);
    });

    test('ExtrudeGeometry toJSON serializes options and the extrude path', () {
      final shape = _square(0.5);
      final path = CatmullRomCurve3([Vector3(0, 0, 0), Vector3(1, 1, 0), Vector3(2, 0, 1)]);
      final options = <String, Object?>{'steps': 4, 'extrudePath': path};
      final geometry = ExtrudeGeometry(shape, options);
      final json = geometry.toJSON();

      expect(json['shapes'], [shape.uuid]);

      final jsonOptions = json['options'] as Map<String, Object?>;
      expect(jsonOptions['steps'], 4);
      expect((jsonOptions['extrudePath'] as Map)['type'], 'CatmullRomCurve3');
      expect(identical(options['extrudePath'], path), isTrue, reason: 'the geometry options are not modified');

      final restored = ExtrudeGeometry.fromJSON(json, {shape.uuid: shape});
      expect(
        jsonOptions['extrudePath'],
        isA<CatmullRomCurve3>(),
        reason: 'fromJSON replaces the path, as the reference does',
      );
      expect(_positions(restored), _positions(geometry));
    });

    test('TubeGeometry toJSON serializes the path and fromJSON rebuilds it', () {
      final geometry = TubeGeometry(LineCurve3(Vector3(0, 0, 0), Vector3(0, 2, 0)), 4, 0.5, 6, false);
      final json = geometry.toJSON();

      expect((json['path'] as Map)['type'], 'LineCurve3');

      final restored = TubeGeometry.fromJSON(json);
      expect(_positions(restored), _positions(geometry));
      expect(restored.tangents.length, 5);
    });

    test('LatheGeometry fromJSON accepts { x, y } maps', () {
      final geometry = LatheGeometry([Vector2(0.5, 0), Vector2(1, 1)], 4);
      final restored = LatheGeometry.fromJSON({
        'points': [
          {'x': 0.5, 'y': 0},
          {'x': 1, 'y': 1},
        ],
        'segments': 4,
      });

      expect(_positions(restored), _positions(geometry));
    });

    test('clone keeps the subclass and its parameters', () {
      final cone = ConeGeometry(2, 3, 5);
      final clone = cone.clone();

      expect(clone, isA<ConeGeometry>());
      expect(clone.parameters, cone.parameters);
      expect(_positions(clone), _positions(cone));

      final icosahedron = IcosahedronGeometry(2, 1).clone();
      expect(icosahedron, isA<IcosahedronGeometry>());
      expect(icosahedron.parameters, {'radius': 2, 'detail': 1});
    });

    test('fromJSON uses the constructor defaults for missing keys', () {
      final geometry = SphereGeometry.fromJSON({'radius': 2});

      expect(geometry.parameters, SphereGeometry(2).parameters);
    });
  });
}
