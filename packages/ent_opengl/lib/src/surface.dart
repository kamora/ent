// What Flutter shows of the GL renderer: a texture of the Flutter engine that EGL draws into. On macOS it is backed by
// an IOSurface (macos/ent_opengl/Sources/ent_opengl/EntOpenGlPlugin.swift), which ANGLE wraps as a pbuffer; on
// Android by a SurfaceProducer (android/src/main/kotlin/.../EntOpenGlPlugin.kt), whose native window becomes a window
// surface. Presenting a frame blits it into the surface and tells Flutter the texture changed.

part of 'backend.dart';

const MethodChannel _channel = MethodChannel('ent_opengl');

/// A texture Flutter shows ([textureId], for a `Texture` widget) that [present] draws frames into.
final class GlSurface {
  GlSurface._(this._context, this.textureId, this.width, this.height, this._native, this._surface);

  /// A [width] × [height] surface of [context]. Throws a [StateError] when EGL cannot draw into it.
  static Future<GlSurface> create(GlContext context, int width, int height) async {
    final created = (await _channel.invokeMapMethod<String, Object?>('create', {'width': width, 'height': height}))!;
    final native = Pointer<Void>.fromAddress((created['surface'] ?? created['window'])! as int);
    final surface = Platform.isAndroid ? _window(context, native) : _ioSurface(context, native, width, height);

    if (surface == nullptr) {
      throw StateError(
        'ent_opengl: EGL cannot draw into the surface (EGL error 0x${eglGetError().toRadixString(16)}).',
      );
    }

    return GlSurface._(context, created['texture']! as int, width, height, native, surface);
  }

  // A window surface of an Android native window, which presents without waiting for the display.
  static Pointer<Void> _window(GlContext context, Pointer<Void> window) {
    return using((arena) {
      final surface = eglCreateWindowSurface(
        context._display,
        context._config,
        window,
        arena<Int32>()..value = eglNone,
      );

      if (surface != nullptr && eglMakeCurrent(context._display, surface, surface, context._context) != 0) {
        eglSwapInterval(context._display, 0);
        context._current();
      }

      return surface;
    });
  }

  // A pbuffer ANGLE draws into an IOSurface through (EGL_ANGLE_iosurface_client_buffer).
  static Pointer<Void> _ioSurface(GlContext context, Pointer<Void> ioSurface, int width, int height) {
    return using((arena) {
      final target = arena<Int32>();
      eglGetConfigAttrib(context._display, context._config, eglBindToTextureTargetAngle, target);
      final attributes = arena<Int32>(15);

      for (final (i, value) in [
        eglWidth,
        width,
        eglHeight,
        height,
        eglIosurfacePlaneAngle,
        0,
        eglTextureTarget,
        target.value,
        eglTextureInternalFormatAngle,
        glBgraExt,
        eglTextureFormat,
        eglTextureRgba,
        eglTextureTypeAngle,
        glUnsignedByte,
        eglNone,
      ].indexed) {
        attributes[i] = value;
      }

      return eglCreatePbufferFromClientBuffer(
        context._display,
        eglIosurfaceAngle,
        ioSurface,
        context._config,
        attributes,
      );
    });
  }

  final GlContext _context;

  /// The texture id of a `Texture` widget showing this surface.
  final int textureId;

  final int width;

  final int height;

  // The IOSurface (macOS) or native window (Android), kept by the plugin until dispose.
  final Pointer<Void> _native;

  final Pointer<Void> _surface;

  /// The IOSurface on macOS, for tests that read its pixels.
  Pointer<Void> get ioSurface => _native;

  /// Draws [frame] (a texture of this surface's size, row 0 the top, as the renderer draws it) into the surface once
  /// the GPU has finished, and tells Flutter the texture changed.
  Future<void> present(GlTexture frame) async {
    _context._present(_surface, frame, width, height, window: Platform.isAndroid);
    await _channel.invokeMethod<void>('frame', {'texture': textureId});
  }

  Future<void> dispose() async {
    eglDestroySurface(_context._display, _surface);
    await _channel.invokeMethod<void>('dispose', {'texture': textureId});
  }
}
