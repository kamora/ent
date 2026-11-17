// A widget that sizes a FlutterGpuRenderer to its layout and shows a frame per tick.

import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:ent/ent.dart';

import 'flutter_gpu_renderer.dart';

/// Called before each frame with the time since the view started, to animate the scene. As with a Flutter
/// [Ticker], the time keeps running while the view is paused, so a scene driven by it jumps ahead on resume.
typedef EntFrameCallback = void Function(Duration elapsed);

/// Called with a pointer event over the view and its position in normalized device coordinates, ready for
/// `Raycaster.setFromCamera`.
typedef EntPointerCallback = void Function(PointerEvent event, Vector2 ndc);

/// Renders [scene] through [camera] every frame. On resize it updates the renderer size and pixel ratio and, for a
/// PerspectiveCamera, the aspect ratio and projection, as the reference's examples do in their resize handler;
/// other cameras are left to the app. An empty layout renders nothing. The frame is shown at one image pixel per
/// physical pixel.
///
/// It does not render while muted by [TickerMode] (a covered route, an inactive tab) or while the app is paused or
/// hidden. The widget does not own [renderer]: it never disposes it, so one renderer can outlive or be shared by
/// views; the app disposes it.
///
/// The pointer callbacks give each event's position as normalized device coordinates ([ndc]), for picking with a
/// [Raycaster] as the reference's examples do; hover comes only from a mouse.
class EntView extends StatefulWidget {
  /// A view that draws [scene] through [camera] with [renderer].
  const EntView({
    super.key,
    required this.renderer,
    required this.scene,
    required this.camera,
    this.onFrame,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerHover,
  });

  /// The renderer that draws the frames; the app owns and disposes it.
  final FlutterGpuRenderer renderer;

  /// The scene drawn.
  final Object3D scene;

  /// The camera the scene is drawn through.
  final Camera camera;

  /// Called before each frame.
  final EntFrameCallback? onFrame;

  /// Called when a pointer touches the view.
  final EntPointerCallback? onPointerDown;

  /// Called when a pointer that touches the view moves.
  final EntPointerCallback? onPointerMove;

  /// Called when a pointer stops touching the view.
  final EntPointerCallback? onPointerUp;

  /// Called when a mouse moves over the view without a button pressed.
  final EntPointerCallback? onPointerHover;

  /// The normalized device coordinates of [local], a position in a view of [size], both in logical pixels as the
  /// reference uses CSS pixels: x from -1 at the left to 1 at the right, y from -1 at the bottom to 1 at the top.
  static Vector2 ndc(Offset local, Size size) {
    return Vector2(local.dx / size.width * 2 - 1, -local.dy / size.height * 2 + 1);
  }

  @override
  State<EntView> createState() => _EntViewState();
}

class _EntViewState extends State<EntView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  ui.Image? _image;

  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(EntView old) {
    super.didUpdateWidget(old);

    // A new renderer or camera is sized on the next layout.
    if (widget.renderer != old.renderer || widget.camera != old.camera) {
      _size = Size.zero;
    }
  }

  void _tick(Duration elapsed) {
    if (_size.isEmpty || !SchedulerBinding.instance.framesEnabled) {
      return;
    }

    widget.onFrame?.call(elapsed);
    setState(() {
      _image?.dispose();
      _image = widget.renderer.render(widget.scene, widget.camera);
    });
  }

  void _resize(Size size, double pixelRatio) {
    if (size.isEmpty || size.isInfinite) {
      _size = Size.zero;
      return;
    }

    if (size == _size && widget.renderer.getPixelRatio() == pixelRatio) {
      return;
    }

    _size = size;
    widget.renderer
      ..setPixelRatio(pixelRatio)
      ..setSize(size.width, size.height);
    final camera = widget.camera;

    if (camera is PerspectiveCamera) {
      camera.aspect = size.width / size.height;
      camera.updateProjectionMatrix();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _image?.dispose();
    super.dispose();
  }

  // Wraps [callback] to pass the event's NDC in the current layout; none while the view is empty.
  void Function(T)? _pointer<T extends PointerEvent>(EntPointerCallback? callback) {
    if (callback == null) {
      return null;
    }

    return (event) {
      if (!_size.isEmpty) {
        callback(event, EntView.ndc(event.localPosition, _size));
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Listener(
      onPointerDown: _pointer(widget.onPointerDown),
      onPointerMove: _pointer(widget.onPointerMove),
      onPointerUp: _pointer(widget.onPointerUp),
      onPointerHover: _pointer(widget.onPointerHover),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _resize(constraints.biggest, pixelRatio);

          // The image is floor(size * pixelRatio) pixels: drawn unscaled from the top left, unfiltered.
          return RawImage(
            image: _image,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            scale: pixelRatio,
            fit: BoxFit.none,
            alignment: Alignment.topLeft,
            filterQuality: FilterQuality.none,
          );
        },
      ),
    );
  }
}
