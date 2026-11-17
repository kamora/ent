// The reference unit tests of Sprite.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

void main() {
  group('Objects', () {
    group('Sprite', () {
      // INHERITANCE
      test('Extending', () {
        final sprite = Sprite();
        expect(sprite, isA<Object3D>(), reason: 'Sprite extends from Object3D');
      });

      // INSTANCING
      test('Instancing', () {
        final object = Sprite();
        expect(object, isNotNull, reason: 'Can instantiate a Sprite.');
      });

      // PROPERTIES
      test('type', () {
        final object = Sprite();
        expect(object.type == 'Sprite', isTrue, reason: 'Sprite.type should be Sprite');
      });

      // PUBLIC
      test('isSprite', () {
        final object = Sprite();
        expect(object.isSprite, isTrue, reason: 'Sprite.isSprite should be true');
      });
    });

    group('Sprite (Dart)', () {
      test('defaults: geometry material center count', () {
        final sprite = Sprite();
        expect(sprite.material, isA<SpriteMaterial>());
        expect(sprite.center.toArray(), [0.5, 0.5]);
        expect(sprite.count, 1);
        expect(identical(sprite.geometry, Sprite().geometry), isTrue, reason: 'all sprites share one quad');
        expect(sprite.geometry.index!.array.toList(), [0, 1, 2, 0, 2, 3]);
        expect(sprite.geometry.attributes['position'], isA<InterleavedBufferAttribute>());
        expect(sprite.geometry.attributes['uv']!.itemSize, 2);
      });

      test('copy', () {
        final material = SpriteMaterial();
        final source = Sprite(material)..center.set(0.1, 0.9);
        final copy = Sprite().copy(source);
        expect(copy.center.toArray(), [0.1, 0.9]);
        expect(identical(copy.material, material), isTrue);
        expect(source.clone(), isA<Sprite>());
      });

      test('raycast without a camera logs an error and throws', () {
        final messages = <String>[];
        setConsoleFunction((type, message, params) => messages.add('$type $message'));
        addTearDown(() => setConsoleFunction(null));

        expect(() => Sprite().raycast(Raycaster(), []), throwsA(isA<TypeError>()));
        expect(messages, ['error ENT.Sprite: "Raycaster.camera" needs to be set in order to raycast against sprites.']);
      });

      test('intersectsFrustum', () {
        final frustum = Frustum().setFromProjectionMatrix(Matrix4().makePerspective(-1, 1, 1, -1, 1, 100));
        final sprite = Sprite();
        expect(sprite.intersectsFrustum(frustum), isFalse);

        sprite.position.set(0, 0, -5);
        sprite.updateMatrixWorld();
        expect(sprite.intersectsFrustum(frustum), isTrue);
      });

      test('toJSON', () {
        final sprite = Sprite()..center.set(0.25, 0.75);
        expect((sprite.toJSON()['object'] as Map<String, Object?>)['center'], [0.25, 0.75]);
      });
    });
  });
}
