// Shadow maps for directional and spot lights. The reference renderer draws the casters into a depth texture and
// samples it with a comparison sampler (PCFShadowMap) or nearest filtering (BasicShadowMap); Flutter GPU has
// neither comparison samplers nor a sampleable depth format here, so each map is a float color target holding the
// fragment's depth (MeshDepthMaterial with packing 0, shaders/depth.glsl), drawn with a depth buffer, and
// shaders/lights.glsl filters the comparisons itself. A VSMShadowMap blurs that depth (shaders/vsm.frag) into two
// more targets, [ShadowTarget.pass] and [ShadowTarget.map] (the reference's `shadow.mapPass` and `shadow.map`), RGBA
// half floats where the reference's are RG ones; the receivers read [ShadowTarget.map], one light texture slot.

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:ent/ent.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// The renderer's shadow settings, `renderer.shadowMap` in the reference (its shadow map's public properties).
class ShadowMap {
  /// Whether lights with `castShadow` render shadow maps and lit materials receive them.
  bool enabled = false;

  /// Whether the maps are rendered every frame; otherwise only when [needsUpdate] is set.
  bool autoUpdate = true;

  /// Renders the maps once in the next frame while [autoUpdate] is off; reset after that frame.
  bool needsUpdate = false;

  /// [BasicShadowMap], [PCFShadowMap] (the default) or [VSMShadowMap] (directional and spot lights; point lights
  /// cast none, with the reference's warning); [PCFSoftShadowMap] falls back to PCF with a warning, as there.
  int type = PCFShadowMap;
}

/// Switches [shadow]'s camera to Impeller's depth range, the WebGPU coordinate system, and updates its projection, as
/// the reference does when a map is [created] (and here also the first time a SpotLight.map projects through it);
/// SpotLightShadow.updateMatrices then rebuilds it in that system when the light's angle, the map's aspect or the
/// distance change. LightShadow's shadow matrix keeps z for this system instead of mapping [−1, 1] to [0, 1], so the
/// depth a map stores and the depth compared with it are both z / w here, as both are 0.5 × z / w + 0.5 in the
/// reference: the same value, rounded differently.
void prepareShadow(LightShadow shadow, {bool created = false}) {
  final camera = shadow.camera;

  if (camera.coordinateSystem == WebGPUCoordinateSystem && !created) {
    return;
  }

  camera.coordinateSystem = WebGPUCoordinateSystem;

  if (camera is PerspectiveCamera) {
    camera.updateProjectionMatrix();
  } else if (camera is OrthographicCamera) {
    camera.updateProjectionMatrix();
  }
}

/// One light's shadow map: the depth per texel in [texture], cleared to 1 (the far plane), and the depth buffer
/// it is drawn with; for VSM ([vsm]) also the blur's targets.
class ShadowTarget {
  ShadowTarget(this.width, this.height, {bool vsm = false})
    : pass = vsm ? _half(width, height) : null,
      map = vsm ? _half(width, height) : null,
      texture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate,
        width,
        height,
        format: gpu.PixelFormat.r32Float,
      ),
      _depth = gpu.gpuContext.createTexture(
        gpu.StorageMode.deviceTransient,
        width,
        height,
        format: gpu.gpuContext.defaultDepthStencilFormat,
        enableShaderReadUsage: false,
      );

  final int width;

  final int height;

  final gpu.Texture texture;

  final gpu.Texture _depth;

  /// The vertical blur's mean and standard deviation in rg (the reference's `shadow.mapPass`), VSM only.
  final gpu.Texture? pass;

  /// The blurred mean and standard deviation the receivers sample (the reference's `shadow.map`), VSM only.
  final gpu.Texture? map;

  /// The blur's targets: RGBA half floats (Flutter GPU has no RG half-float format).
  static gpu.Texture _half(int width, int height) {
    return gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      format: gpu.PixelFormat.r16g16b16a16Float,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: true,
    );
  }

  /// The depth texture's sampling (the reference: NearestFilter for BasicShadowMap; PCF's LinearFilter is applied by
  /// the shader over nearest reads), clamped to the edge.
  static final gpu.SamplerOptions sampler = gpu.SamplerOptions();

  /// LinearFilter, clamped to the edge: the VSM blur targets.
  static final gpu.SamplerOptions linear = gpu.SamplerOptions(
    minFilter: gpu.MinMagFilter.linear,
    magFilter: gpu.MinMagFilter.linear,
  );

  gpu.RenderTarget attachments() {
    return gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: texture, clearValue: vm.Vector4(1, 1, 1, 1)),
      depthStencilAttachment: gpu.DepthStencilAttachment(texture: _depth, depthClearValue: 1),
    );
  }
}
