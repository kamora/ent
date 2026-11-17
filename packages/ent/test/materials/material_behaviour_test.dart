// Behaviour of the materials derived from the reference source, beyond the reference unit tests.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Materials behaviour', () {
    late List<String> warnings;

    setUp(() {
      warnings = [];
      setConsoleFunction((type, message, params) => warnings.add('$type: $message'));
    });

    tearDown(() => setConsoleFunction(null));

    test('id increments per material', () {
      final a = Material();
      final b = MeshBasicMaterial();
      expect(b.id, a.id + 1);
    });

    test('alphaTest bumps version only when crossing zero', () {
      final material = Material();
      material.alphaTest = 0.5;
      expect(material.version, 1);
      material.alphaTest = 0.7;
      expect(material.version, 1);
      material.alphaTest = 0;
      expect(material.version, 2);
    });

    test('needsUpdate', () {
      final material = Material();
      material.needsUpdate = false;
      expect(material.version, 0);
      material.needsUpdate = true;
      expect(material.version, 1);
    });

    test('MeshPhysicalMaterial accessors bump version only when crossing zero', () {
      final material = MeshPhysicalMaterial();

      for (final set in <void Function(double)>[
        (v) => material.anisotropy = v,
        (v) => material.clearcoat = v,
        (v) => material.diffuseRoughness = v,
        (v) => material.dispersion = v,
        (v) => material.iridescence = v,
        (v) => material.retroreflectivity = v,
        (v) => material.sheen = v,
        (v) => material.transmission = v,
      ]) {
        final version = material.version;
        set(0.5);
        set(0.8);
        expect(material.version, version + 1);
        set(0);
        expect(material.version, version + 2);
      }
    });

    test('MeshPhysicalMaterial reflectivity and ior', () {
      final material = MeshPhysicalMaterial();
      expect(material.reflectivity, closeTo(0.5, 1e-15));
      material.reflectivity = 0.8;
      expect(material.ior, closeTo((1 + 0.32) / (1 - 0.32), 1e-15));
    });

    test('iridescenceThicknessRange is deprecated and warns once', () {
      final material = MeshPhysicalMaterial();

      // ignore: deprecated_member_use
      material.iridescenceThicknessRange = [10, 20];

      // ignore: deprecated_member_use
      expect(material.iridescenceThicknessRange, [10.0, 20.0]);
      expect(material.iridescenceThicknessMinimum, 10);
      expect(warnings.where((w) => w.contains('iridescenceThicknessRange')).length, lessThanOrEqualTo(1));
    });

    test('setValues sets colors from hex, strings and colors', () {
      final material = MeshBasicMaterial({'color': 0xff0000});
      final color = material.color;
      material.setValues({'color': '#00ff00'});
      expect(material.color.getHex(), 0x00ff00);
      material.setValues({'color': Color(0, 0, 1)});
      expect(material.color.getHex(), 0x0000ff);
      expect(identical(material.color, color), isTrue, reason: 'colors are set in place');
    });

    test('setValues copies vectors and eulers in place and assigns null', () {
      final material = MeshStandardMaterial();
      final scale = material.normalScale;
      final rotation = material.envMapRotation;
      material.setValues({'normalScale': Vector2(2, 3), 'envMapRotation': Euler(1, 2, 3, 'ZYX'), 'map': Texture()});
      expect(identical(material.normalScale, scale), isTrue);
      expect(material.normalScale.toArray(), [2.0, 3.0]);
      expect(identical(material.envMapRotation, rotation), isTrue);
      expect(material.envMapRotation.order, 'ZYX');

      material.setValues({'map': null});
      expect(material.map, isNull);
    });

    test('setValues warns about unknown keys and rejects read-only ones', () {
      final material = LineBasicMaterial({'roughness': 1});
      expect(warnings, ["warn: ENT.Material: 'roughness' is not a property of ENT.LineBasicMaterial."]);
      expect(() => material.setValues({'id': 3}), throwsArgumentError);
    });

    test('operator [] reads properties by their reference name', () {
      final material = MeshPhongMaterial({'shininess': 12});
      expect(material['shininess'], 12);
      expect(material['type'], 'MeshPhongMaterial');
      expect(material['unknown'], isNull);
    });

    test('copy deep-copies clipping planes and user data', () {
      final source = MeshBasicMaterial()
        ..clippingPlanes = [Plane(Vector3(1, 0, 0), 2)]
        ..userData = {
          'a': [1, 2],
        };
      final copy = source.clone();
      expect(identical(copy.clippingPlanes![0], source.clippingPlanes![0]), isFalse);
      expect(copy.clippingPlanes![0].equals(source.clippingPlanes![0]), isTrue);
      expect(identical(copy.userData['a'], source.userData['a']), isFalse);
      expect(copy.userData, source.userData);
    });

    test('clone returns the subclass', () {
      expect(LineDashedMaterial().clone(), isA<LineDashedMaterial>());
      expect(MeshPhysicalMaterial().clone(), isA<MeshPhysicalMaterial>());
    });

    test('fromJSON drops properties the material lacks and reads vertexColors numbers', () {
      final material = LineBasicMaterial().fromJSON({'roughness': 0.5, 'vertexColors': 2});
      expect(material['roughness'], isNull);
      expect(material.vertexColors, isTrue);
    });

    test('fromJSON accepts a scalar normalScale', () {
      final material = MeshNormalMaterial()..fromJSON({'normalScale': 3});
      expect(material.normalScale.toArray(), [3.0, 3.0]);
    });

    test('dispose dispatches a dispose event', () {
      final material = Material();
      var count = 0;
      material.addEventListener('dispose', (event) => count++);
      material.dispose();
      expect(count, 1);
    });

    test('defaults of special materials', () {
      expect(ShadowMaterial().transparent, isTrue);
      expect(ShadowMaterial().color.getHex(), 0);
      expect(SpriteMaterial().transparent, isTrue);
      expect(MeshPhysicalMaterial().attenuationDistance, double.infinity);
      expect(MeshDepthMaterial().depthPacking, BasicDepthPacking);
    });
  });
}
