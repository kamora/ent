import 'dart:convert';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../support/math_constants.dart';
import 'support.dart';

void main() {
  group('Loaders', () {
    group('ObjectLoader', () {
      late List<String> log;

      setUp(() {
        log = [];
        setConsoleFunction((type, message, params) => log.add([message, ...params].join(' ')));
      });

      tearDown(() {
        Loader.platform = null;
        setConsoleFunction(null);
      });

      // INHERITANCE
      test('Extending', () {
        expect(ObjectLoader(), isA<Loader<Object3D>>(), reason: 'ObjectLoader extends from Loader');
      });

      // INSTANCING
      test('Instancing', () {
        expect(ObjectLoader(), isNotNull, reason: 'Can instantiate an ObjectLoader.');
      });

      // PUBLIC
      test('parse (pivot)', () {
        final object = Object3D();
        object.position.set(1, 2, 3);
        object.rotation.set(0.3, -0.7, 1.2);
        object.scale.set(2, 3, 4);
        object.pivot = Vector3(1, -2, 3);
        object.updateMatrix();

        final loaded = ObjectLoader().parse(object.toJSON());

        expect(loaded.pivot!.equals(object.pivot!), isTrue, reason: 'Pivot is restored');
        expect(loaded.position.distanceTo(object.position) < eps, isTrue, reason: 'Position is restored');
      });

      test('parse (Sprite center)', () {
        final sprite = Sprite();
        sprite.center.set(0.5, 0);

        final loaded = ObjectLoader().parse(sprite.toJSON()) as Sprite;

        expect(loaded.center.equals(sprite.center), isTrue, reason: 'Center is restored');
      });

      // Dart: reference behaviour beyond the round trips (object_loader_reference_test.dart)
      test('parse onLoad bindLightTargets bindSkeletons', () {
        final scene = Scene();
        final target = Object3D()..name = 'target';
        final light = DirectionalLight()..target = target;
        final orphan = SpotLight();
        final bone = Bone();
        final mesh = SkinnedMesh(BufferGeometry(), MeshBasicMaterial())..add(bone);
        mesh.bind(Skeleton([bone]));
        scene
          ..add(target)
          ..add(light)
          ..add(orphan)
          ..add(mesh);

        Object3D? loadedObject;
        final loaded = ObjectLoader().parse(scene.toJSON(), (object) => loadedObject = object);

        expect(loadedObject, same(loaded), reason: 'no images: onLoad runs right away');

        final loadedLight = loaded.children[1] as DirectionalLight;
        expect(loadedLight.target.name, 'target');
        expect(loadedLight.target, same(loaded.children[0]));

        // the spot light's target was never added to the scene: a new object
        final loadedOrphan = loaded.children[2] as SpotLight;
        expect(loadedOrphan.target.parent, isNull);
        expect(loadedOrphan.target.uuid, isNot(orphan.target.uuid));

        final loadedMesh = loaded.children[3] as SkinnedMesh;
        expect(loadedMesh.skeleton!.bones.single, same(loadedMesh.children.single));

        // a skeleton uuid with no skeleton in the JSON
        final json = scene.toJSON();
        (json['skeletons']! as List).first = {...((json['skeletons']! as List).first as Map), 'uuid': 'other'};
        ObjectLoader().parse(json);
        expect(log.last, 'ENT.ObjectLoader: No skeleton found with UUID: ${mesh.skeleton!.uuid}');
      });

      test('parseTextures parseConstant', () {
        final textures = ObjectLoader().parseTextures(
          [
            {
              'uuid': 't',
              'image': 'i',
              'mapping': 'CubeReflectionMapping',
              'wrap': ['RepeatWrapping', 1001],
              'minFilter': 'LinearFilter',
            },
          ],
          {
            'i': TextureSource(DataImage(data: [1], width: 1, height: 1)),
          },
        );

        final texture = textures['t']!;
        expect(texture, isA<DataTexture>());
        expect(
          [texture.mapping, texture.wrapS, texture.wrapT, texture.minFilter],
          [CubeReflectionMapping, RepeatWrapping, ClampToEdgeWrapping, LinearFilter],
        );
        expect(
          log.where((l) => l.startsWith('ENT.ObjectLoader.parseTexture: Constant should be in numeric form.')).length,
          3,
        );

        expect(
          () => ObjectLoader().parseTextures([
            {'uuid': 'u'},
          ], {}),
          throwsA(isA<TypeError>()),
        );
        expect(log.reversed.take(2).toList().reversed, [
          'ENT.ObjectLoader: No "image" specified for u',
          'ENT.ObjectLoader: Undefined image null',
        ]);
      });

      test('parseGeometries registerGeometry', () {
        final shapes = <String, Shape>{};

        expect(
          () => ObjectLoader().parseGeometries([EdgesGeometry(BoxGeometry()).toJSON()], shapes),
          throwsA(isA<EntError>()),
          reason: 'EdgesGeometry has no fromJSON in the reference either',
        );

        expect(
          () => ObjectLoader().parseGeometries([
            {'type': 'Custom', 'uuid': 'c'},
          ], shapes),
          throwsA(isA<TypeError>()),
        );
        expect(
          log.last,
          'ENT.ObjectLoader: Unknown geometry type "Custom". Use .registerGeometry() before starting the deserialization process.',
        );

        ObjectLoader.registerGeometry('Custom', (data, shapes) => BoxGeometry((data['size']! as num).toDouble()));
        final geometry = ObjectLoader().parseGeometries([
          {'type': 'Custom', 'uuid': 'c', 'size': 3, 'name': 'n'},
        ], shapes)['c']!;
        expect([geometry.uuid, geometry.name, (geometry as BoxGeometry).parameters!['width']], ['c', 'n', 3.0]);
      });

      test('images by URL', () async {
        final platform = FakeLoaderPlatform();
        Loader.platform = platform;

        final texture = Texture();
        final material = MeshBasicMaterial({'map': texture});
        final json = Mesh(BoxGeometry(), material).toJSON();
        (json['images']! as List).first = {...((json['images']! as List).first as Map), 'url': 'grid.png'};

        Object3D? loaded;
        final object = (ObjectLoader()..setResourcePath('res/')).parse(json, (o) => loaded = o);

        expect(loaded, isNull, reason: 'onLoad waits for the image');

        final image = platform.images.single;
        expect(image.src, 'res/grid.png');
        expect(((object as Mesh).material! as MeshBasicMaterial).map!.image, same(image));

        image.finish();
        await settle();
        expect(loaded, same(object));

        // absolute URLs keep their path; parseAsync waits for the images
        (json['images']! as List).first = {...((json['images']! as List).first as Map), 'url': 'https://cdn/grid.png'};
        final future = ObjectLoader().parseAsync(json);
        await settle();
        platform.images.last.finish();
        expect(await future, isA<Mesh>());
        expect(platform.images.last.src, 'https://cdn/grid.png');
      });

      test('load loadAsync', () async {
        final platform = FakeLoaderPlatform();
        Loader.platform = platform;
        platform.resources['scenes/a.json'] = FakeResource.text(jsonEncode(Group().toJSON()));
        platform.resources['scenes/geometry.json'] = FakeResource.text('{"metadata":{"type":"Geometry"}}');
        platform.resources['scenes/bad.json'] = FakeResource.text('{');

        final loader = ObjectLoader();
        final group = await loader.loadAsync('scenes/a.json');
        expect(group, isA<Group>());
        expect(loader.resourcePath, 'scenes/', reason: 'resourcePath defaults to the URL base');

        await expectLater(ObjectLoader().loadAsync('scenes/geometry.json'), throwsA(isA<EntError>()));
        await expectLater(ObjectLoader().loadAsync('scenes/bad.json'), throwsA(isA<EntError>()));

        final errors = <Object>[];
        ObjectLoader()
          ..load('scenes/geometry.json', (_) => fail('geometry JSON'), null, errors.add)
          ..load('scenes/bad.json', (_) => fail('bad JSON'), null, errors.add);
        await settle();
        expect(errors.length, 2);
        expect(log, contains('ENT.ObjectLoader: Can\'t load scenes/geometry.json'));
      });
    });
  });
}
