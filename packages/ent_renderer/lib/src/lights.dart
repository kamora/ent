// The light uniforms of a frame, set up as the reference renderer does: colors times intensity, ambient light and
// light probes summed, positions and directions in view space. The shaders hold a fixed number of lights per type
// (shaders/lights.glsl, exception E-SHADERS); lights past it are dropped with a warning.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ent_renderer/gpu.dart' as gpu;
import 'package:ent/ent.dart';

import 'ltc_data.dart';
import 'programs.dart';
import 'shadows.dart';

/// The maximum count per light type, as `MAX_*_LIGHTS` in shaders/lights.glsl.
const int maxDirectionalLights = 4;

const int maxPointLights = 8;

const int maxSpotLights = 4;

const int maxHemisphereLights = 2;

const int maxRectAreaLights = 2;

/// RectAreaLightTexturesLib's LTC_HALF_1 and LTC_HALF_2 (tool/ltc.mjs): 64 × 64 RGBA half-float texels, LinearFilter
/// magnification, NearestFilter minification, clamped to the edge; the reference's choice without
/// OES_texture_float_linear, here on every platform, as the iPhone 11's A13 samples float32 textures with nearest
/// filtering. The physical program reads them in the fixed slots [ltcSlots] while a frame has rect area lights.
final List<DataTexture> ltcTextures = [
  for (final data in [ltc1, ltc2])
    DataTexture(
        Uint16List.view(base64Decode(data).buffer),
        64,
        64,
        RGBAFormat,
        HalfFloatType,
        UVMapping,
        ClampToEdgeWrapping,
        ClampToEdgeWrapping,
        LinearFilter,
        NearestFilter,
        1,
      )
      ..name = 'LTC_HALF'
      ..needsUpdate = true,
];

/// The shadow maps and spot light maps a lit program samples, together, as `MAX_LIGHT_TEXTURES` in
/// shaders/lights.glsl: MeshPhysicalMaterial's program reaches the 31 textures a Metal fragment stage binds with
/// six of them.
const int maxLightTextures = 6;

/// The lights of one frame, as the shaders' LightInfo block reads them.
class LightState {
  final List<double> ambient = [0, 0, 0];

  /// The summed spherical harmonics of the light probes, 9 × rgb.
  final List<double> probe = List.filled(27, 0);

  int probes = 0;

  /// Per type, 4 floats per light and vector: see shaders/lights.glsl.
  final List<double> directionalDirection = [];

  final List<double> directionalColor = [];

  final List<double> pointPosition = [];

  final List<double> pointColor = [];

  final List<double> spotPosition = [];

  final List<double> spotDirection = [];

  final List<double> spotColor = [];

  final List<double> spotCone = [];

  final List<double> hemiDirection = [];

  final List<double> hemiSky = [];

  final List<double> hemiGround = [];

  /// Per rect area light its view-space position, halfWidth and halfHeight, and color times intensity.
  final List<double> rectPosition = [];

  final List<double> rectHalfWidth = [];

  final List<double> rectHalfHeight = [];

  final List<double> rectColor = [];

  /// The shadows of the first directional lights (shadow-casting lights sort first): per light the shadow
  /// matrix (16 floats), intensity, bias, normalBias, radius, and the map size with the map's slot in
  /// [textures] (4 floats).
  final List<double> shadowMatrix = [];

  final List<double> shadow = [];

  final List<double> shadowSize = [];

  int directionalShadows = 0;

  /// Per spot light its spotLightMatrix (16 floats; the shadow camera's, for a shadow or a map); for the first
  /// ones (shadow-casting lights sort first) intensity, bias, normalBias and radius; per spot light the map size,
  /// the shadow map's slot in [textures] and its SpotLight.map's slot (−1 for none).
  final List<double> spotMatrix = [];

  final List<double> spotShadow = [];

  final List<double> spotShadowSize = [];

  int spotShadows = 0;

  /// For the first point lights (shadow-casting lights sort first) intensity, bias, normalBias and radius; the
  /// map size (mapSize.x, a cube face's), the map's slot in [textures], the shadow camera's near and far; and the
  /// light's world position (the reference's pointShadowMatrix, a translation to it).
  final List<double> pointShadow = [];

  final List<double> pointShadowSize = [];

  final List<double> pointShadowPosition = [];

  int pointShadows = 0;

  /// The shadow maps (`gpu.Texture`) and spot light maps ([Texture]) the lit programs sample, in their slots
  /// `light_texture_0` … (at most [maxLightTextures]).
  final List<Object> textures = [];

  /// The shadow map type the shaders filter with: 0 BasicShadowMap, 1 PCFShadowMap, 2 VSMShadowMap.
  int shadowType = 1;

  final Vector3 _vector = Vector3();

  final Vector3 _target = Vector3();

  final Matrix4 _matrix = Matrix4();

  final Matrix4 _rotation = Matrix4();

  int get directional => directionalColor.length ~/ 4;

  int get point => pointColor.length ~/ 4;

  int get spot => spotColor.length ~/ 4;

  int get hemisphere => hemiSky.length ~/ 4;

  int get rectArea => rectColor.length ~/ 4;

  /// Sets up the uniforms for [lights] (the render list's, in scene order) seen by [camera], as the reference does.
  /// [map] returns a shadow-casting light's shadow map, or `null` when shadows are not drawn.
  void setup(List<Light> lights, Camera camera, gpu.Texture? Function(Light light) map) {
    ambient.fillRange(0, 3, 0);
    probe.fillRange(0, 27, 0);
    probes = 0;

    for (final list in [
      directionalDirection,
      directionalColor,
      pointPosition,
      pointColor,
      spotPosition,
      spotDirection,
      spotColor,
      spotCone,
      hemiDirection,
      hemiSky,
      hemiGround,
      rectPosition,
      rectHalfWidth,
      rectHalfHeight,
      rectColor,
      shadowMatrix,
      shadow,
      shadowSize,
      spotMatrix,
      spotShadow,
      spotShadowSize,
      pointShadow,
      pointShadowSize,
      pointShadowPosition,
    ]) {
      list.clear();
    }

    textures.clear();
    directionalShadows = 0;
    spotShadows = 0;
    pointShadows = 0;

    final view = camera.matrixWorldInverse;
    final sorted = _sorted(lights);

    for (final light in sorted) {
      final color = light.color;
      final intensity = light.intensity;

      if (light is AmbientLight) {
        ambient[0] += color.r * intensity;
        ambient[1] += color.g * intensity;
        ambient[2] += color.b * intensity;
      } else if (light is LightProbe) {
        for (var j = 0; j < 9; j++) {
          final c = light.sh.coefficients[j];
          probe[j * 3] += c.x * intensity;
          probe[j * 3 + 1] += c.y * intensity;
          probe[j * 3 + 2] += c.z * intensity;
        }

        probes++;
      } else if (light is DirectionalLight) {
        if (_full(directional, maxDirectionalLights, 'DirectionalLight')) {
          continue;
        }

        directionalColor.addAll([color.r * intensity, color.g * intensity, color.b * intensity, 0]);
        _direction(light, light.target, view);
        directionalDirection.addAll([_vector.x, _vector.y, _vector.z, 0]);

        final texture = light.castShadow ? map(light) : null;

        if (texture != null && _slot(texture) >= 0) {
          final s = light.shadow;
          shadowMatrix.addAll(s.matrix.elements);
          shadow.addAll([s.intensity, s.bias, s.normalBias, s.radius]);
          shadowSize.addAll([s.mapSize.x, s.mapSize.y, textures.length - 1, 0]);
          directionalShadows++;
        }
      } else if (light is SpotLight) {
        if (_full(spot, maxSpotLights, 'SpotLight')) {
          continue;
        }

        _vector.setFromMatrixPosition(light.matrixWorld).applyMatrix4(view);
        spotPosition.addAll([_vector.x, _vector.y, _vector.z, light.distance]);
        _direction(light, light.target, view);
        spotDirection.addAll([_vector.x, _vector.y, _vector.z, light.decay]);
        spotColor.addAll([color.r * intensity, color.g * intensity, color.b * intensity, 0]);
        spotCone.addAll([math.cos(light.angle), math.cos(light.angle * (1 - light.penumbra)), 0, 0]);

        // The projected map needs the shadow camera's matrices, updated here as the reference does (the shadow
        // pass has updated those of a shadow-casting light).
        final s = light.shadow;
        final texture = light.castShadow ? map(light) : null;
        final projected = light.map;

        if (projected != null) {
          prepareShadow(s);
          s.updateMatrices(light);
        }

        final shadowed = texture != null && _slot(texture) >= 0;
        spotMatrix.addAll(s.matrix.elements);
        spotShadowSize.addAll([
          s.mapSize.x,
          s.mapSize.y,
          shadowed ? textures.length - 1 : -1,
          projected != null ? _slot(projected).toDouble() : -1,
        ]);

        if (shadowed) {
          spotShadow.addAll([s.intensity, s.bias, s.normalBias, s.radius]);
          spotShadows++;
        }
      } else if (light is PointLight) {
        if (_full(point, maxPointLights, 'PointLight')) {
          continue;
        }

        _vector.setFromMatrixPosition(light.matrixWorld).applyMatrix4(view);
        pointPosition.addAll([_vector.x, _vector.y, _vector.z, light.distance]);
        pointColor.addAll([color.r * intensity, color.g * intensity, color.b * intensity, light.decay]);

        final texture = light.castShadow ? map(light) : null;

        if (texture != null && _slot(texture) >= 0) {
          final s = light.shadow;
          final camera = s.camera as PerspectiveCamera;
          pointShadow.addAll([s.intensity, s.bias, s.normalBias, s.radius]);
          pointShadowSize.addAll([s.mapSize.x, textures.length - 1, camera.near, camera.far]);
          _vector.setFromMatrixPosition(light.matrixWorld);
          pointShadowPosition.addAll([_vector.x, _vector.y, _vector.z, 0]);
          pointShadows++;
        }
      } else if (light is HemisphereLight) {
        if (_full(hemisphere, maxHemisphereLights, 'HemisphereLight')) {
          continue;
        }

        final ground = light.groundColor;
        hemiSky.addAll([color.r * intensity, color.g * intensity, color.b * intensity, 0]);
        hemiGround.addAll([ground.r * intensity, ground.g * intensity, ground.b * intensity, 0]);
        _vector.setFromMatrixPosition(light.matrixWorld).transformDirection(view);
        hemiDirection.addAll([_vector.x, _vector.y, _vector.z, 0]);
      } else if (light is RectAreaLight) {
        // Only the physical program defines RE_Direct_RectArea; Lambert, Phong and Toon ignore these.
        if (_full(rectArea, maxRectAreaLights, 'RectAreaLight')) {
          continue;
        }

        rectColor.addAll([color.r * intensity, color.g * intensity, color.b * intensity, 0]);
        _vector.setFromMatrixPosition(light.matrixWorld).applyMatrix4(view);
        rectPosition.addAll([_vector.x, _vector.y, _vector.z, 0]);
        _rotation.extractRotation(_matrix.copy(light.matrixWorld).premultiply(view));
        _vector.set(light.width * 0.5, 0, 0).applyMatrix4(_rotation);
        rectHalfWidth.addAll([_vector.x, _vector.y, _vector.z, 0]);
        _vector.set(0, light.height * 0.5, 0).applyMatrix4(_rotation);
        rectHalfHeight.addAll([_vector.x, _vector.y, _vector.z, 0]);
      }
    }
  }

  /// Writes the lights into a program's LightInfo block, which [begin] has started, for a draw into a target
  /// [height] pixels high of a geometry with or without [normals].
  void write(UniformBlock block, Camera camera, Object3D object, {required int height, required bool normals}) {
    block
      ..floats('view_matrix', camera.matrixWorldInverse.elements)
      ..floats('ambient_light_color', ambient)
      ..flag('is_orthographic', camera is OrthographicCamera)
      ..floats('light_probe', [
        for (var j = 0; j < 9; j++) ...[probe[j * 3], probe[j * 3 + 1], probe[j * 3 + 2], 0],
      ])
      ..flag('light_probes', probes > 0)
      ..flag('receive_shadow', object.receiveShadow)
      ..floats('light_counts', [directional.toDouble(), point.toDouble(), spot.toDouble(), hemisphere.toDouble()])
      ..floats('directional_direction', directionalDirection)
      ..floats('directional_color', directionalColor)
      ..floats('point_position', pointPosition)
      ..floats('point_color', pointColor)
      ..floats('spot_position', spotPosition)
      ..floats('spot_direction', spotDirection)
      ..floats('spot_color', spotColor)
      ..floats('spot_cone', spotCone)
      ..floats('hemi_direction', hemiDirection)
      ..floats('hemi_sky_color', hemiSky)
      ..floats('hemi_ground_color', hemiGround)
      ..float('rect_areas', rectArea.toDouble())
      ..floats('rect_position', rectPosition)
      ..floats('rect_half_width', rectHalfWidth)
      ..floats('rect_half_height', rectHalfHeight)
      ..floats('rect_color', rectColor)
      ..floats('shadow_info', [
        directionalShadows.toDouble(),
        shadowType.toDouble(),
        height.toDouble(),
        normals ? 1 : 0,
      ])
      ..floats('directional_shadow_matrix', shadowMatrix)
      ..floats('directional_shadow', shadow)
      ..floats('directional_shadow_size', shadowSize)
      ..float('spot_shadows', spotShadows.toDouble())
      ..floats('spot_light_matrix', spotMatrix)
      ..floats('spot_shadow', spotShadow)
      ..floats('spot_shadow_size', spotShadowSize)
      ..float('point_shadows', pointShadows.toDouble())
      ..floats('point_shadow', pointShadow)
      ..floats('point_shadow_size', pointShadowSize)
      ..floats('point_shadow_position', pointShadowPosition);
  }

  // The view-space direction from the light's target to the light.
  void _direction(Light light, Object3D target, Matrix4 view) {
    _vector.setFromMatrixPosition(light.matrixWorld);
    _target.setFromMatrixPosition(target.matrixWorld);
    _vector.sub(_target).transformDirection(view);
  }

  // Puts [texture] in the next slot of [textures] and returns the slot, or −1 with a warning when they are full.
  int _slot(Object texture) {
    if (textures.length < maxLightTextures) {
      textures.add(texture);
      return textures.length - 1;
    }

    warnOnce(
      'FlutterGpuRenderer: more than $maxLightTextures shadow maps and spot light maps; the shaders hold '
      '$maxLightTextures (exception E-SHADERS), the others are ignored.',
    );
    return -1;
  }

  static bool _full(int count, int max, String type) {
    if (count < max) {
      return false;
    }

    warnOnce(
      'FlutterGpuRenderer: more than $max ${type}s in the scene; the shaders hold $max (exception E-SHADERS), '
      'the others are ignored.',
    );
    return true;
  }

  // shadowCastingAndTexturingLightsFirst, a stable sort as Array.prototype.sort.
  static List<Light> _sorted(List<Light> lights) {
    int rank(Light light) {
      final map = light is SpotLight && light.map != null;
      return (light.castShadow ? 2 : 0) + (map ? 1 : 0);
    }

    final indexed = [for (var i = 0; i < lights.length; i++) (i, lights[i])];
    indexed.sort((a, b) {
      final c = rank(b.$2) - rank(a.$2);
      return c != 0 ? c : a.$1 - b.$1;
    });

    return [for (final (_, light) in indexed) light];
  }
}
