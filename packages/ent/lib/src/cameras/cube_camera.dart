part of '../../ent.dart';

// negative fov is not an error
const double _cubeCameraFov = -90;
const double _cubeCameraAspect = 1;

/// A special type of camera that is positioned in 3D space to render its surroundings into a cube render
/// target. The render target can then be used as an environment map for rendering realtime reflections in
/// your scene.
///
/// `update( renderer, scene )` takes a [CubeCameraRenderer], the part of the renderer it uses.
class CubeCamera extends Object3D {
  /// Constructs a new cube camera with the [near] and [far] planes of its six perspective cameras (`undefined` in the
  /// reference gives the [PerspectiveCamera] defaults, as `null` does here) and the cube render target it renders into.
  CubeCamera([double? near, double? far, this.renderTarget]) {
    type = 'CubeCamera';

    for (var i = 0; i < 6; i++) {
      final camera = PerspectiveCamera(_cubeCameraFov, _cubeCameraAspect, near ?? 0.1, far ?? 2000);
      camera.layers = layers;
      add(camera);
    }
  }

  /// A reference to the cube render target.
  RenderTarget? renderTarget;

  /// The current active coordinate system ([WebGLCoordinateSystem], [WebGPUCoordinateSystem] or `null`).
  int? coordinateSystem;

  /// The current active mipmap level
  int activeMipmapLevel = 0;

  /// Must be called when the coordinate system of the cube camera is changed.
  void updateCoordinateSystem() {
    final coordinateSystem = this.coordinateSystem;

    final cameras = List<Object3D>.of(children);

    // The reference destructures `[ cameraPX, … ] = cameras`: any number of children, `undefined` for missing ones,
    // which fail only when used. Indexing keeps that order of errors.
    Object3D? at(int i) => i < cameras.length ? cameras[i] : null;
    final cameraPX = at(0), cameraNX = at(1), cameraPY = at(2), cameraNY = at(3), cameraPZ = at(4), cameraNZ = at(5);

    for (final camera in cameras) {
      remove(camera);
    }

    if (coordinateSystem == WebGLCoordinateSystem) {
      cameraPX!.up.set(0, 1, 0);
      cameraPX.lookAt(1.0, 0.0, 0.0);

      cameraNX!.up.set(0, 1, 0);
      cameraNX.lookAt(-1.0, 0.0, 0.0);

      cameraPY!.up.set(0, 0, -1);
      cameraPY.lookAt(0.0, 1.0, 0.0);

      cameraNY!.up.set(0, 0, 1);
      cameraNY.lookAt(0.0, -1.0, 0.0);

      cameraPZ!.up.set(0, 1, 0);
      cameraPZ.lookAt(0.0, 0.0, 1.0);

      cameraNZ!.up.set(0, 1, 0);
      cameraNZ.lookAt(0.0, 0.0, -1.0);
    } else if (coordinateSystem == WebGPUCoordinateSystem) {
      cameraPX!.up.set(0, -1, 0);
      cameraPX.lookAt(-1.0, 0.0, 0.0);

      cameraNX!.up.set(0, -1, 0);
      cameraNX.lookAt(1.0, 0.0, 0.0);

      cameraPY!.up.set(0, 0, 1);
      cameraPY.lookAt(0.0, 1.0, 0.0);

      cameraNY!.up.set(0, 0, -1);
      cameraNY.lookAt(0.0, -1.0, 0.0);

      cameraPZ!.up.set(0, -1, 0);
      cameraPZ.lookAt(0.0, 0.0, 1.0);

      cameraNZ!.up.set(0, -1, 0);
      cameraNZ.lookAt(0.0, 0.0, -1.0);
    } else {
      throw EntError('ENT.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: $coordinateSystem');
    }

    for (final camera in cameras) {
      add(camera);

      camera.updateMatrixWorld();
    }
  }

  /// Calling this method will render the given scene with the given renderer into the cube render target of the
  /// camera. WebXR and the reversed depth buffer do not exist in this port; their steps are left out.
  void update(CubeCameraRenderer renderer, Object3D scene) {
    if (parent == null) {
      updateMatrixWorld();
    }

    final renderTarget = this.renderTarget!;

    if (coordinateSystem != renderer.coordinateSystem) {
      coordinateSystem = renderer.coordinateSystem;

      updateCoordinateSystem();
    }

    final current = renderer.getRenderTarget();
    final face = renderer.getActiveCubeFace();
    final level = renderer.getActiveMipmapLevel();
    final mipmapsAutoUpdate = renderTarget.texture.mipmapsAutoUpdate;

    renderTarget.texture.mipmapsAutoUpdate = false;

    for (var i = 0; i < 6; i++) {
      // mipmaps are generated during the last call of render()
      // at this point, all sides of the cube render target are defined
      if (i == 5) {
        renderTarget.texture.mipmapsAutoUpdate = mipmapsAutoUpdate;
      }

      renderer.setRenderTarget(renderTarget, i, activeMipmapLevel);
      renderer.render(scene, children[i] as Camera);
    }

    renderer.setRenderTarget(current, face, level);

    renderTarget.texture.needsPMREMUpdate = true;
  }

  @override
  Object? operator [](String key) {
    return switch (key) {
      'renderTarget' => renderTarget,
      'coordinateSystem' => coordinateSystem,
      'activeMipmapLevel' => activeMipmapLevel,
      _ => super[key],
    };
  }

  /// Writes a property by its name, like `object[ name ] = value` in JavaScript; the counterpart of `operator []`
  /// (exception E-PROPERTY), used by [PropertyBinding] to animate these properties.
  @override
  void operator []=(String key, Object? value) {
    switch (key) {
      case 'renderTarget':
        renderTarget = value as RenderTarget?;
      case 'coordinateSystem':
        coordinateSystem = value == null ? null : _jsInt(value);
      case 'activeMipmapLevel':
        activeMipmapLevel = _jsInt(value);
      default:
        super[key] = value;
    }
  }

  /// Returns a new cube camera with copied values from this instance. The reference builds `new this.constructor()`,
  /// which creates six default cameras before `copy()` adds clones of this instance's children; this override does the
  /// same (E-CLONE).
  @override
  CubeCamera clone([bool? recursive]) {
    return CubeCamera()..copy(this, recursive ?? true);
  }
}

/// What [CubeCamera.update] calls on a renderer (the reference passes the renderer itself).
abstract interface class CubeCameraRenderer {
  /// The coordinate system the renderer's cameras use ([WebGLCoordinateSystem] or [WebGPUCoordinateSystem]).
  int get coordinateSystem;

  /// The current render target, or `null` while drawing to the screen.
  RenderTarget? getRenderTarget();

  /// The face of a cube render target being drawn, 0 to 5.
  int getActiveCubeFace();

  /// The mip level of the render target being drawn.
  int getActiveMipmapLevel();

  /// Draws into [target] (its [activeCubeFace] and [activeMipmapLevel]) from now on, or to the screen when `null`.
  void setRenderTarget(RenderTarget? target, [int activeCubeFace = 0, int activeMipmapLevel = 0]);

  /// Draws [scene] as seen by [camera] into the current target.
  Object? render(Object3D scene, Camera camera);
}
