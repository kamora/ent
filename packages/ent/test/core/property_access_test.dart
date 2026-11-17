// `operator []` and `operator []=` are symmetric (exception E-PROPERTY): every property a class writes by
// name can be read back by name, and the properties the reference exposes only through getters stay read-only.

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import '../audio/fake_web_audio.dart';

/// Writes each property's current value back by name and checks that the same value reads back.
void _roundTrip(Object? Function(String) read, void Function(String, Object?) write, List<String> keys) {
  for (final key in keys) {
    final value = read(key);
    write(key, value);
    expect(identical(read(key), value) || read(key) == value, isTrue, reason: key);
  }
}

void _object(Object3D object, List<String> writable, [List<String> readOnly = const []]) {
  _roundTrip((k) => object[k], (k, v) => object[k] = v, writable);

  for (final key in readOnly) {
    expect(object[key], isNotNull, reason: '$key is readable');
    expect(() => object[key] = object[key], throwsArgumentError, reason: '$key is read-only');
  }
}

void main() {
  group('property access by name', () {
    test('Object3D', () {
      _object(
        Object3D(),
        [
          'name',
          'up',
          'matrix',
          'matrixWorld',
          'children',
          'animations',
          'layers',
          'visible',
          'renderOrder',
          'userData',
        ],
        ['position', 'rotation', 'quaternion', 'scale', 'id'],
      );
    });

    test('cameras', () {
      _object(PerspectiveCamera(), [
        'fov',
        'zoom',
        'near',
        'far',
        'focus',
        'aspect',
        'view',
        'filmGauge',
        'filmOffset',
      ]);
      _object(OrthographicCamera(), ['zoom', 'view', 'left', 'right', 'top', 'bottom', 'near', 'far']);
      _object(
        Camera(),
        ['matrixWorldInverse', 'projectionMatrix', 'projectionMatrixInverse', 'coordinateSystem'],
        ['reversedDepth'],
      );
      _object(CubeCamera(1, 10), ['renderTarget', 'coordinateSystem', 'activeMipmapLevel']);
      _object(ArrayCamera(), ['isMultiViewCamera', 'cameras', 'perCameraFrustumCulled']);
    });

    test('lights', () {
      _object(AmbientLight(), ['color', 'intensity'], ['isAmbientLight']);
      _object(SpotLight(), ['target', 'distance', 'angle', 'penumbra', 'decay', 'map', 'shadow', 'power']);
      _object(PointLight(), ['distance', 'decay', 'shadow', 'power']);
      _object(RectAreaLight(), ['width', 'height', 'power']);
      _object(DirectionalLight(), ['target', 'shadow']);
      _object(HemisphereLight(), ['groundColor']);
      _object(LightProbe(), ['sh']);
      _object(IESSpotLight(), ['iesMap']);
      _object(ProjectorLight(), ['aspect']);
    });

    test('scenes and objects', () {
      _object(Scene()..fog = Fog(), [
        'background',
        'environment',
        'fog',
        'backgroundBlurriness',
        'backgroundIntensity',
        'backgroundRotation',
        'environmentIntensity',
        'environmentRotation',
        'overrideMaterial',
      ]);
      _object(Mesh(), ['geometry', 'material', 'morphTargetDictionary', 'morphTargetInfluences', 'count']);
      _object(Points(), ['geometry', 'material', 'morphTargetDictionary', 'morphTargetInfluences']);
      _object(Line(), ['geometry', 'material', 'morphTargetDictionary', 'morphTargetInfluences']);
      _object(Sprite(), ['geometry', 'material', 'center', 'count']);
      _object(LOD(), ['autoUpdate'], ['levels']);
      _object(ClippingGroup(), ['clippingPlanes', 'enabled', 'clipIntersection', 'clipShadows']);
      _object(SkinnedMesh(), [
        'bindMode',
        'bindMatrix',
        'bindMatrixInverse',
        'boundingBox',
        'boundingSphere',
        'skeleton',
      ]);
      _object(InstancedMesh(BufferGeometry(), MeshBasicMaterial(), 2), [
        'instanceMatrix',
        'instanceColor',
        'morphTexture',
        'boundingBox',
        'boundingSphere',
      ]);
      _object(
        BatchedMesh(2, 8),
        ['perObjectFrustumCulled', 'sortObjects', 'boundingBox', 'boundingSphere', 'customSort'],
        ['maxInstanceCount', 'instanceCount', 'unusedVertexCount', 'unusedIndexCount'],
      );
    });

    test('audio', () {
      AudioContext.setContext(FakeContext());
      addTearDown(() => AudioContext.setContext(null));

      final listener = AudioListener();
      _object(listener, ['filter', 'timeDelta'], ['context', 'gain']);
      _object(
        Audio(listener),
        [
          'autoplay',
          'buffer',
          'detune',
          'loop',
          'loopStart',
          'loopEnd',
          'offset',
          'duration',
          'playbackRate',
          'isPlaying',
          'hasPlaybackControl',
          'source',
          'sourceType',
          'filters',
        ],
        ['listener', 'context', 'gain'],
      );
      _object(PositionalAudio(listener), [], ['panner']);
    });

    test('fog and shadows', () {
      final fog = Fog(0xffffff, 1, 100);
      _roundTrip((k) => fog[k], (k, v) => fog[k] = v, ['name', 'color', 'near', 'far']);
      expect(fog['isFog'], isTrue);
      expect(() => fog['isFog'] = true, throwsArgumentError);

      final exp = FogExp2(0xffffff, 0.1);
      _roundTrip((k) => exp[k], (k, v) => exp[k] = v, ['name', 'color', 'density']);

      final shadow = SpotLightShadow();
      _roundTrip((k) => shadow[k], (k, v) => shadow[k] = v, [
        'camera',
        'intensity',
        'bias',
        'biasNode',
        'normalBias',
        'radius',
        'blurSamples',
        'mapSize',
        'mapType',
        'map',
        'mapPass',
        'matrix',
        'autoUpdate',
        'needsUpdate',
        'focus',
        'aspect',
      ]);
      expect(shadow['unknown'], isNull);
    });

    test('numbers are converted as a JS number assigned to the property would be', () {
      final camera = PerspectiveCamera();
      camera['fov'] = 30;
      expect(camera.fov, 30.0);

      final shadow = DirectionalLight().shadow;
      shadow['blurSamples'] = 4.0;
      expect(shadow.blurSamples, 4);
    });
  });
}
