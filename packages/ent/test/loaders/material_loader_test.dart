import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

class _GlowMaterial extends MeshBasicMaterial {
  _GlowMaterial([super.parameters]) {
    type = 'GlowMaterial';
  }
}

void main() {
  group('Loaders', () {
    group('MaterialLoader', () {
      tearDown(() {
        Loader.platform = null;
        setConsoleFunction(null);
      });

      // INHERITANCE
      test('Extending', () {
        expect(MaterialLoader(), isA<Loader<Material>>(), reason: 'MaterialLoader extends from Loader');
      });

      // PROPERTIES
      test('textures', () {
        expect(MaterialLoader().textures, <String, Texture>{}, reason: 'MaterialLoader defines textures.');
      });

      // INSTANCING
      test('Instancing', () {
        expect(MaterialLoader(), isNotNull, reason: 'Can instantiate a MaterialLoader.');
      });

      // Dart: parse, the type table, registration and unknown types
      test('parse setTextures createMaterialFromType', () {
        final map = Texture();
        final material = MeshStandardMaterial({'color': Color(0xff0000), 'roughness': 0.25, 'map': map});
        final json = material.toJSON();
        json.remove('textures');
        json.remove('images');

        final loader = MaterialLoader();
        expect(loader.setTextures({map.uuid: map}), same(loader));

        final parsed = loader.parse(json) as MeshStandardMaterial;
        expect([parsed.uuid, parsed.color.getHex(), parsed.roughness], [material.uuid, 0xff0000, 0.25]);
        expect(parsed.map, same(map));

        for (final type in [
          'ShadowMaterial',
          'SpriteMaterial',
          'PointsMaterial',
          'MeshPhysicalMaterial',
          'MeshStandardMaterial',
          'MeshPhongMaterial',
          'MeshToonMaterial',
          'MeshNormalMaterial',
          'MeshLambertMaterial',
          'MeshDepthMaterial',
          'MeshDistanceMaterial',
          'MeshBasicMaterial',
          'MeshMatcapMaterial',
          'LineDashedMaterial',
          'LineBasicMaterial',
          'Material',
        ]) {
          expect(loader.createMaterialFromType(type).type, type);
        }
      });

      test('registerMaterial unknown type', () {
        final log = <String>[];
        setConsoleFunction((type, message, params) => log.add('$type $message'));

        expect(MaterialLoader.createMaterialFromTypeStatic('NoSuchMaterial').runtimeType, Material);
        expect(MaterialLoader.createMaterialFromTypeStatic('NoSuchMaterial').runtimeType, Material);
        expect(log, [
          'warn ENT.MaterialLoader: Unknown material type "NoSuchMaterial". Use .registerMaterial() before starting the deserialization process.',
        ], reason: 'warned once');

        MaterialLoader.registerMaterial('GlowMaterial', _GlowMaterial.new);
        expect(MaterialLoader().parse({'type': 'GlowMaterial', 'uuid': 'u'}), isA<_GlowMaterial>());
      });

      // ent has no shader materials (exception E-SHADERS): one in a scene file loads as a plain Material, with a
      // warning.
      test('a shader material loads as a plain Material', () {
        final log = <String>[];
        setConsoleFunction((type, message, params) => log.add('$type $message'));

        final material = MaterialLoader().parse({'type': 'ShaderMaterial', 'uuid': 's', 'name': 'glow'});
        expect([material.runtimeType, material.uuid, material.name], [Material, 's', 'glow']);
        expect(log, [
          'warn ENT.MaterialLoader: Unknown material type "ShaderMaterial". Use .registerMaterial() before starting the deserialization process.',
        ]);
      });

      test('load', () async {
        final platform = FakeLoaderPlatform();
        Loader.platform = platform;
        platform.resources['m.json'] = FakeResource.text('{"type":"MeshPhongMaterial","shininess":7}');

        final material = await MaterialLoader().loadAsync('m.json');
        expect((material as MeshPhongMaterial).shininess, 7);
      });
    });
  });
}
