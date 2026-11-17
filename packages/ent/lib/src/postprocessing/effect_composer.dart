part of '../../ent.dart';

/// Used to implement post-processing effects. The class manages a chain of post-processing passes to produce the final
/// visual result. Post-processing passes are executed in order of their addition/insertion. The last pass is
/// automatically rendered to screen.
///
/// `MaskPass` is not ported, so the composer never copies through a stencil mask (exception E-POSTPROCESSING).
class EffectComposer {
  /// Constructs a new effect composer; without [renderTarget], two HalfFloatType targets of the renderer's
  /// drawing-buffer size.
  EffectComposer(this.renderer, [WebGLRenderTarget? renderTarget]) : _pixelRatio = renderer.getPixelRatio() {
    if (renderTarget == null) {
      final size = renderer.getSize(Vector2());
      _width = size.width;
      _height = size.height;

      renderTarget = WebGLRenderTarget((_width * _pixelRatio).toInt(), (_height * _pixelRatio).toInt(), {
        'type': HalfFloatType,
      });
      renderTarget.texture.name = 'EffectComposer.rt1';
    } else {
      _width = renderTarget.width.toDouble();
      _height = renderTarget.height.toDouble();
    }

    renderTarget1 = renderTarget;
    renderTarget2 = renderTarget.clone();
    renderTarget2.texture.name = 'EffectComposer.rt2';

    writeBuffer = renderTarget1;
    readBuffer = renderTarget2;
  }

  /// The renderer.
  final EffectComposerRenderer renderer;

  double _pixelRatio;

  late double _width;

  late double _height;

  /// A reference to the first internal render target.
  late WebGLRenderTarget renderTarget1;

  /// A reference to the second internal render target.
  late WebGLRenderTarget renderTarget2;

  /// A reference to the internal write buffer. Passes usually write their result into this buffer.
  late WebGLRenderTarget writeBuffer;

  /// A reference to the internal read buffer. Passes usually read the previous render result from this buffer.
  late WebGLRenderTarget readBuffer;

  /// Whether the final pass is rendered to the screen (default framebuffer) or not.
  bool renderToScreen = true;

  /// An array representing the (ordered) chain of post-processing passes.
  final List<Pass> passes = [];

  /// The internal timer.
  final Timer timer = Timer();

  /// Swaps the internal read/write buffers.
  void swapBuffers() {
    final read = readBuffer;
    readBuffer = writeBuffer;
    writeBuffer = read;
  }

  /// Adds the given pass to the pass chain.
  void addPass(Pass pass) {
    passes.add(pass);
    pass.setSize((_width * _pixelRatio).toInt(), (_height * _pixelRatio).toInt());
  }

  /// Inserts the given pass at a given index.
  void insertPass(Pass pass, int index) {
    passes.insert(index, pass);
    pass.setSize((_width * _pixelRatio).toInt(), (_height * _pixelRatio).toInt());
  }

  /// Removes the given pass from the pass chain.
  void removePass(Pass pass) {
    final index = passes.indexOf(pass);

    if (index != -1) {
      passes.removeAt(index);
    }
  }

  /// Returns `true` if the pass for the given index is the last enabled pass in the pass chain.
  bool isLastEnabledPass(int passIndex) {
    for (var i = passIndex + 1; i < passes.length; i++) {
      if (passes[i].enabled) {
        return false;
      }
    }

    return true;
  }

  /// Executes all enabled post-processing passes in order to produce the final frame. [deltaTime] is in seconds;
  /// without it, the timer's delta.
  void render([double? deltaTime]) {
    timer.update();

    deltaTime ??= timer.getDelta();

    final currentRenderTarget = renderer.getRenderTarget();

    for (var i = 0, il = passes.length; i < il; i++) {
      final pass = passes[i];

      if (!pass.enabled) {
        continue;
      }

      pass.renderToScreen = renderToScreen && isLastEnabledPass(i);
      pass.render(renderer, writeBuffer, readBuffer, deltaTime, false);

      if (pass.needsSwap) {
        swapBuffers();
      }
    }

    renderer.setRenderTarget(currentRenderTarget);
  }

  /// Resets the internal state of the EffectComposer.
  void reset([WebGLRenderTarget? renderTarget]) {
    if (renderTarget == null) {
      final size = renderer.getSize(Vector2());
      _pixelRatio = renderer.getPixelRatio();
      _width = size.width;
      _height = size.height;

      renderTarget = renderTarget1.clone();
      renderTarget.setSize((_width * _pixelRatio).toInt(), (_height * _pixelRatio).toInt());
    }

    renderTarget1.dispose();
    renderTarget2.dispose();
    renderTarget1 = renderTarget;
    renderTarget2 = renderTarget.clone();

    writeBuffer = renderTarget1;
    readBuffer = renderTarget2;
  }

  /// Resizes the internal read and write buffers as well as all passes. Like the renderer's setSize, this method honors
  /// the current pixel ratio.
  void setSize(double width, double height) {
    _width = width;
    _height = height;

    final effectiveWidth = (_width * _pixelRatio).toInt();
    final effectiveHeight = (_height * _pixelRatio).toInt();

    renderTarget1.setSize(effectiveWidth, effectiveHeight);
    renderTarget2.setSize(effectiveWidth, effectiveHeight);

    for (var i = 0; i < passes.length; i++) {
      passes[i].setSize(effectiveWidth, effectiveHeight);
    }
  }

  /// Sets device pixel ratio. This is usually used for HiDPI device to prevent blurring output.
  void setPixelRatio(double pixelRatio) {
    _pixelRatio = pixelRatio;

    setSize(_width, _height);
  }

  /// Frees the GPU-related resources allocated by this instance. Call this method whenever the composer is no
  /// longer used in your app.
  void dispose() {
    renderTarget1.dispose();
    renderTarget2.dispose();
  }
}
