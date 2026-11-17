// The reference unit tests of PropertyBinding: the static methods. The 'Instancing' and 'setValue' tests bind to a Mesh
// and live in property_binding_mesh_test.dart. Dart-specific cases cover each binding type on Object3D properties.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Animation', () {
    group('PropertyBinding', () {
      // STATIC
      test('sanitizeNodeName', () {
        expect(
          PropertyBinding.sanitizeNodeName('valid-name-123_'),
          'valid-name-123_',
          reason: 'Leaves valid name intact.',
        );
        expect(PropertyBinding.sanitizeNodeName('急須'), '急須', reason: 'Leaves non-latin unicode characters intact.');
        expect(
          PropertyBinding.sanitizeNodeName('space separated name 123_ -'),
          'space_separated_name_123__-',
          reason: 'Replaces spaces with underscores.',
        );
        expect(
          PropertyBinding.sanitizeNodeName('"Mátyás" %_* 😇'),
          '"Mátyás"_%_*_😇',
          reason: 'Allows various punctuation and symbols.',
        );
        expect(
          PropertyBinding.sanitizeNodeName('/invalid: name ^123.[_]'),
          'invalid_name_^123_',
          reason: 'Strips reserved characters.',
        );
      });

      test('parseTrackName', () {
        Map<String, Object?> parsed(
          String? nodeName,
          String? objectName,
          String? objectIndex,
          String propertyName,
          String? propertyIndex,
        ) {
          return {
            'nodeName': nodeName,
            'objectName': objectName,
            'objectIndex': objectIndex,
            'propertyName': propertyName,
            'propertyIndex': propertyIndex,
          };
        }

        final paths = <(String, Map<String, Object?>)>[
          ('.property', parsed(null, null, null, 'property', null)),
          ('nodeName.property', parsed('nodeName', null, null, 'property', null)),
          ('a.property', parsed('a', null, null, 'property', null)),
          ('no.de.Name.property', parsed('no.de.Name', null, null, 'property', null)),
          ('no.d-e.Name.property', parsed('no.d-e.Name', null, null, 'property', null)),
          ('nodeName.property[accessor]', parsed('nodeName', null, null, 'property', 'accessor')),
          ('nodeName.material.property[accessor]', parsed('nodeName', 'material', null, 'property', 'accessor')),
          ('no.de.Name.material.property', parsed('no.de.Name', 'material', null, 'property', null)),
          (
            'no.de.Name.material[materialIndex].property',
            parsed('no.de.Name', 'material', 'materialIndex', 'property', null),
          ),
          ('uuid.property[accessor]', parsed('uuid', null, null, 'property', 'accessor')),
          (
            'uuid.objectName[objectIndex].propertyName[propertyIndex]',
            parsed('uuid', 'objectName', 'objectIndex', 'propertyName', 'propertyIndex'),
          ),

          // directoryName is currently unused.
          ('parentName/nodeName.property', parsed('nodeName', null, null, 'property', null)),
          ('parentName/no.de.Name.property', parsed('no.de.Name', null, null, 'property', null)),
          ('parentName/parentName/nodeName.property[index]', parsed('nodeName', null, null, 'property', 'index')),
          ('.bone[Armature.DEF_cog].position', parsed(null, 'bone', 'Armature.DEF_cog', 'position', null)),
          (
            'scene:helium_balloon_model:helium_balloon_model.position',
            parsed('helium_balloon_model', null, null, 'position', null),
          ),
          ('急須.材料[零]', parsed('急須', null, null, '材料', '零')),
          ('📦.🎨[🔴]', parsed('📦', null, null, '🎨', '🔴')),
        ];

        for (final (path, expected) in paths) {
          expect(PropertyBinding.parseTrackName(path), expected, reason: 'Parses track name: $path');
        }
      });

      // Dart-specific
      test('parseTrackName errors', () {
        expect(() => PropertyBinding.parseTrackName('noproperty'), throwsA(isA<EntError>()));
      });

      test('findNode', () {
        final root = Object3D()..name = 'root';
        final child = Object3D()..name = 'child';
        final leaf = Object3D()..name = 'leaf';
        root.add(child);
        child.add(leaf);

        expect(PropertyBinding.findNode(root, null), same(root));
        expect(PropertyBinding.findNode(root, ''), same(root));
        expect(PropertyBinding.findNode(root, 'root'), same(root));
        expect(PropertyBinding.findNode(root, 'leaf'), same(leaf));
        expect(PropertyBinding.findNode(root, leaf.uuid), same(leaf));
        expect(PropertyBinding.findNode(root, 'missing'), isNull);
      });

      test('binding types on Object3D', () {
        final object = Object3D();

        // HasFromToArray
        final position = PropertyBinding(object, '.position');
        position.setValue([1.0, 2.0, 3.0], 0);
        expect(object.position.toArray(), [1, 2, 3]);
        expect(object.matrixWorldNeedsUpdate, isTrue);

        final read = List<Object?>.filled(4, null);
        position.getValue(read, 1);
        expect(read, [null, 1, 2, 3]);

        // ArrayElement on a vector component, and on an Euler (which updates the quaternion)
        PropertyBinding(object, '.scale[y]').setValue([4.0], 0);
        expect(object.scale.y, 4);

        PropertyBinding(object, '.rotation[z]').setValue([1.0], 0);
        expect(object.rotation.z, 1);
        expect(object.quaternion.z, isNot(0));

        // Direct
        final visible = PropertyBinding(object, '.visible');
        visible.setValue([false], 0);
        expect(object.visible, isFalse);

        // Unknown property: the binding becomes a no-op and reports an error.
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add(message));
        addTearDown(() => setConsoleFunction(null));

        PropertyBinding(object, '.missing').setValue([1.0], 0);
        expect(messages.single, startsWith('ENT.PropertyBinding: Trying to update property for track'));
      });

      test('unbind', () {
        final object = Object3D();
        final binding = PropertyBinding(object, '.position')..bind();
        binding.unbind();
        expect(binding.node, isNull);

        binding.setValue([5.0, 0.0, 0.0], 0);
        expect(object.position.x, 5, reason: 'an unbound binding binds again on use');
      });

      test('create', () {
        expect(PropertyBinding.create(Object3D(), '.position'), isA<PropertyBinding>());
        expect(PropertyBinding.create(AnimationObjectGroup(), '.position'), isA<PropertyBindingComposite>());
      });
    });
  });
}
