import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ent/ent.dart';

/// Feeds Flutter pointer input to an [OrbitControls] (or [MapControls]) the way a browser feeds the reference's
/// listeners: every pointer goes through the controls' own pointer handling, so one finger rotates, two fingers
/// pinch to dolly and move to pan, the left mouse button rotates, the right one (or shift + left) pans and the
/// wheel dollies, with the reference's arithmetic. Logical pixels stand for CSS pixels; the child's size is the
/// element's `clientWidth` and `clientHeight`.
///
/// Damping and auto-rotation need `controls.update()` every frame, as in the reference: call it from
/// `EntView.onFrame`.
class OrbitControlsListener extends StatefulWidget {
  /// Feeds the pointer events over [child] to [controls].
  const OrbitControlsListener({super.key, required this.controls, required this.child});

  /// The controls; connected to a [ControlsElement] here when they have none.
  final OrbitControls controls;

  /// The view the controls move the camera of, usually a `EntView`.
  final Widget child;

  @override
  State<OrbitControlsListener> createState() => _OrbitControlsListenerState();
}

class _OrbitControlsListenerState extends State<OrbitControlsListener> {
  // The scale of the trackpad pinch in progress, per pointer.
  final Map<int, double> _scales = {};

  OrbitControls get _controls => widget.controls;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(OrbitControlsListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _connect();
  }

  void _connect() {
    if (_controls.domElement == null) {
      _controls.connect(ControlsElement());
    }
  }

  // Keeps the element the size of the child, as the DOM keeps clientWidth and clientHeight.
  void _resize() {
    final size = (context.findRenderObject()! as RenderBox).size;
    (_controls.domElement! as ControlsElement)
      ..clientWidth = size.width
      ..clientHeight = size.height;
  }

  ControlsPointerEvent _event(PointerEvent event, [int? buttons]) {
    _resize();

    final keyboard = HardwareKeyboard.instance;
    final pressed = buttons ?? event.buttons;
    return ControlsPointerEvent(
      pointerId: event.pointer,
      pointerType: switch (event.kind) {
        PointerDeviceKind.touch => 'touch',
        PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => 'pen',
        _ => 'mouse',
      },

      // DOM `button`: 0 main, 1 middle, 2 secondary.
      button: pressed & kSecondaryButton != 0
          ? 2
          : pressed & kMiddleMouseButton != 0
          ? 1
          : 0,
      clientX: event.localPosition.dx,
      clientY: event.localPosition.dy,
      ctrlKey: keyboard.isControlPressed,
      metaKey: keyboard.isMetaPressed,
      shiftKey: keyboard.isShiftPressed,
    );
  }

  void _signal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Claims the scroll for the controls, as their preventDefault() does in a browser.
      GestureBinding.instance.pointerSignalResolver.register(event, (event) {
        _resize();
        _controls.onMouseWheel(
          ControlsWheelEvent(
            clientX: event.localPosition.dx,
            clientY: event.localPosition.dy,
            deltaY: (event as PointerScrollEvent).scrollDelta.dy,
            ctrlKey: HardwareKeyboard.instance.isControlPressed,
          ),
        );
      });
    }
  }

  // A trackpad pinch (macOS) dollies by the ratio of its scales, as a two-finger touch pinch does in the reference.
  void _panZoom(PointerPanZoomUpdateEvent event) {
    final previous = _scales[event.pointer] ?? 1;
    _scales[event.pointer] = event.scale;

    final controls = _controls;

    if (!controls.enabled || !controls.enableZoom || event.scale == previous) {
      return;
    }

    _resize();
    controls.dollyOut(math.pow(event.scale / previous, controls.zoomSpeed).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _controls.onPointerDown(_event(event)),
      onPointerMove: (event) => _controls.onPointerMove(_event(event)),
      onPointerUp: (event) => _controls.onPointerUp(_event(event, 0)),
      onPointerCancel: (event) => _controls.onPointerCancel(_event(event, 0)),
      onPointerSignal: _signal,
      onPointerPanZoomStart: (event) => _scales[event.pointer] = 1,
      onPointerPanZoomUpdate: _panZoom,
      onPointerPanZoomEnd: (event) => _scales.remove(event.pointer),
      child: widget.child,
    );
  }
}
