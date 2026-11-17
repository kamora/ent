// The reference unit tests of DataTexture and DataArrayTexture, plus Dart tests of the source behaviour (expected
// values printed from the reference source in Node).

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

void main() {
  group('Textures', () {
    group('DataTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = DataTexture();
        expect(object is Texture, true, reason: 'DataTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = DataTexture();
        expect(object, isNotNull, reason: 'Can instantiate a DataTexture.');
      });

      // PUBLIC
      test('isDataTexture', () {
        final object = DataTexture();
        expect(object.isDataTexture, isTrue, reason: 'DataTexture.isDataTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: image generateMipmaps flipY unpackAlignment magFilter minFilter', () {
        final data = Uint8List(4);
        final texture = DataTexture(data, 2, 1);
        expectTextureState(
          texture,
          stateWith({
            'magFilter': 1003,
            'minFilter': 1003,
            'generateMipmaps': false,
            'flipY': false,
            'unpackAlignment': 1,
            'width': 2,
            'height': 1,
          }),
        );
        expect((texture.image as DataImage).data, same(data));
      });

      test('clone', () {
        final texture = DataTexture(Uint8List(4), 2, 1);
        final clone = texture.clone();
        expect(clone, isA<DataTexture>());
        expect(clone.source, same(texture.source));
      });
    });

    group('DataArrayTexture', () {
      // INHERITANCE
      test('Extending', () {
        final Object object = DataArrayTexture();
        expect(object is Texture, true, reason: 'DataArrayTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final object = DataArrayTexture();
        expect(object, isNotNull, reason: 'Can instantiate a DataArrayTexture.');
      });

      // PUBLIC
      test('isDataArrayTexture', () {
        final object = DataArrayTexture();
        expect(object.isDataArrayTexture, isTrue, reason: 'DataArrayTexture.isDataArrayTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: image wrapR generateMipmaps flipY unpackAlignment', () {
        final texture = DataArrayTexture(null, 2, 3, 4);
        expectTextureState(
          texture,
          stateWith({
            'magFilter': 1003,
            'minFilter': 1003,
            'generateMipmaps': false,
            'flipY': false,
            'unpackAlignment': 1,
            'width': 2,
            'height': 3,
            'depth': 4,
          }),
        );
        expect(texture.wrapR, 1001);
      });

      test('addLayerUpdate clearLayerUpdates layerUpdates', () {
        final texture = DataArrayTexture()
          ..addLayerUpdate(2)
          ..addLayerUpdate(2)
          ..addLayerUpdate(5);
        expect(texture.layerUpdates.toList(), [2, 5]);
        texture.clearLayerUpdates();
        expect(texture.layerUpdates, isEmpty);
      });

      test('copy clone', () {
        final texture = DataArrayTexture()..wrapR = 1000;
        final clone = texture.clone();
        expect(clone, isA<DataArrayTexture>());
        expect(clone.wrapR, 1000);
      });

      test('setValues', () {
        final texture = DataArrayTexture()..setValues({'wrapR': 1002});
        expect(texture.wrapR, 1002);
      });
    });
  });
}
