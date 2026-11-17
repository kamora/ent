// The subclass branches of Object3D.toJSON (Scene, Mesh/Line/Points geometry, SkinnedMesh skeleton, materials, morph
// targets). Expected keys and values were printed from the reference source in Node; the InstancedMesh and BatchedMesh
// branches are tested with their classes.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../objects/skinned_mesh_test.dart' show skinned;

const List<String> _base = [
  'uuid',
  'type',
  'name',
  'castShadow',
  'receiveShadow',
  'visible',
  'frustumCulled',
  'renderOrder',
  'static',
  'matrixAutoUpdate',
  'layers',
  'matrix',
  'up',
];

Map<String, Object?> objectOf(Map<String, Object?> json) => json['object'] as Map<String, Object?>;

void main() {
  group('Core', () {
    group('Object3D.toJSON', () {
      test('Mesh: morph targets, geometry and a material array', () {
        final geometry = BoxGeometry();
        geometry.morphAttributes['position'] = [Float32BufferAttribute(72, 3)];
        final shared = MeshBasicMaterial();
        final mesh = Mesh(geometry, [shared, MeshBasicMaterial(), shared]);
        mesh.morphTargetInfluences![0] = 0.25;

        final json = mesh.toJSON();
        final object = objectOf(json);

        expect(object.keys, [..._base, 'morphTargetDictionary', 'morphTargetInfluences', 'geometry', 'material']);
        expect(object['morphTargetDictionary'], {'0': 0});
        expect(object['morphTargetInfluences'], [0.25]);
        expect(object['material'], hasLength(3));
        expect((object['material'] as List)[0], (object['material'] as List)[2]);
        expect(json['materials'], hasLength(2));
        expect(json['geometries'], hasLength(1));
        expect(json.keys, ['metadata', 'geometries', 'materials', 'object']);
      });

      test('Mesh: shapes of the geometry parameters', () {
        final a = Shape()
          ..moveTo(0, 0)
          ..lineTo(1, 0)
          ..lineTo(0, 1);
        final b = Shape()
          ..moveTo(2, 0)
          ..lineTo(3, 0)
          ..lineTo(2, 1);

        final json = Mesh(ShapeGeometry([a, b])).toJSON();
        final shapes = json['shapes'] as List<Object?>;
        expect(json.keys, ['metadata', 'geometries', 'materials', 'shapes', 'object']);
        expect(shapes.map((s) => (s as Map)['uuid']), [a.uuid, b.uuid]);

        final single = Mesh(ShapeGeometry(a)).toJSON();
        expect(single['shapes'], hasLength(1));
      });

      test('Line and Points: geometry and material', () {
        for (final object in [Line(BoxGeometry(), LineBasicMaterial()), Points()]) {
          final json = object.toJSON();
          expect(objectOf(json).keys, [..._base, 'geometry', 'material']);
          expect(json.keys, ['metadata', 'geometries', 'materials', 'object']);
        }
      });

      test('Sprite: material, no geometry', () {
        final json = Sprite().toJSON();
        expect(objectOf(json).keys.take(_base.length + 1), [..._base, 'material']);
        expect(json.keys, ['metadata', 'materials', 'object']);
      });

      test('Scene: background color, environment texture', () {
        final geometry = BoxGeometry();
        final scene = Scene()
          ..background = Color(1, 0.5, 0)
          ..environment = Texture();
        scene.add(Mesh(geometry, MeshBasicMaterial()));

        final json = scene.toJSON();
        final object = objectOf(json);
        final textures = json['textures'] as List<Object?>;
        final children = object['children'] as List<Object?>;
        final geometries = json['geometries'] as List<Object?>;

        expect(object['background'], 16759808);
        expect(object['environment'], (textures[0] as Map)['uuid']);
        expect(object.keys.take(_base.length + 3), [..._base, 'background', 'environment', 'children']);
        expect(json.keys, ['metadata', 'geometries', 'materials', 'textures', 'images', 'object']);
        expect(children, hasLength(1));
        expect((children[0] as Map)['geometry'], (geometries[0] as Map)['uuid']);
      });

      test('Scene: background texture; render-target environment skipped', () {
        final textured = Scene()..background = Texture();
        final json = textured.toJSON();
        expect(objectOf(json)['background'], ((json['textures'] as List)[0] as Map)['uuid']);

        final target = Scene()..environment = (Texture()..isRenderTargetTexture = true);
        expect(objectOf(target.toJSON()).containsKey('environment'), isFalse);
      });

      test('SkinnedMesh: bind mode, bind matrix and skeleton', () {
        final mesh = skinned();
        final json = mesh.toJSON();
        final object = objectOf(json);
        final skeletons = json['skeletons'] as List<Object?>;

        expect(object['bindMode'], 'attached');
        expect(object['bindMatrix'], [
          1.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          0.5,
          0.0,
          -0.25,
          1.0,
        ]);
        expect(skeletons, hasLength(1));
        expect((skeletons[0] as Map)['bones'], hasLength(3));
        expect(object['skeleton'], (skeletons[0] as Map)['uuid']);
        expect(object['geometry'], ((json['geometries'] as List)[0] as Map)['uuid']);
        expect(object['material'], ((json['materials'] as List)[0] as Map)['uuid']);
      });
    });
  });
}
