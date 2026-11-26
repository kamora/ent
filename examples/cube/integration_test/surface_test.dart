// A frame presented to a GlSurface lands in its IOSurface as Flutter reads it: BGRA, row 0 the top. Runs in the
// example app (`flutter test integration_test -d macos`): the plugin's native side does not run under flutter_tester.
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:typed_data';

import 'package:ent/ent.dart' as ent;
import 'package:ent_opengl/ent_opengl.dart' hide Texture;
import 'package:flutter/widgets.dart';
import 'package:ent_renderer/gpu.dart' as gpu;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final _io = DynamicLibrary.open('/System/Library/Frameworks/IOSurface.framework/IOSurface');
final _lock = _io
    .lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Pointer<Uint32>),
      int Function(Pointer<Void>, int, Pointer<Uint32>)
    >('IOSurfaceLock');
final _unlock = _io
    .lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Pointer<Uint32>),
      int Function(Pointer<Void>, int, Pointer<Uint32>)
    >('IOSurfaceUnlock');
final _base = _io.lookupFunction<Pointer<Uint8> Function(Pointer<Void>), Pointer<Uint8> Function(Pointer<Void>)>(
  'IOSurfaceGetBaseAddress',
);
final _stride = _io.lookupFunction<IntPtr Function(Pointer<Void>), int Function(Pointer<Void>)>(
  'IOSurfaceGetBytesPerRow',
);

/// The surface's rows as stored, each [width] BGRA pixels.
List<List<int>> rows(Pointer<Void> surface, int width, int height) {
  _lock(surface, 1, nullptr);

  try {
    final base = _base(surface);
    final stride = _stride(surface);
    return [for (var y = 0; y < height; y++) (base + y * stride).asTypedList(width * 4).toList()];
  } finally {
    _unlock(surface, 1, nullptr);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // An IOSurface backs a GlSurface on macOS only.
  testWidgets('a presented frame is stored as BGRA, top row first', skip: !Platform.isMacOS, (tester) async {
    final context = GlContext.shared;
    final red = [255, 0, 0, 255];
    final blue = [0, 0, 255, 255];
    final frame = context.createTexture(gpu.StorageMode.hostVisible, 4, 2) as GlTexture
      ..overwrite(
        ByteData.sublistView(
          Uint8List.fromList([for (var i = 0; i < 4; i++) ...red, for (var i = 0; i < 4; i++) ...blue]),
        ),
      );
    final surface = await GlSurface.create(context, 4, 2);
    addTearDown(surface.dispose);
    await surface.present(frame);

    final [top, bottom] = rows(surface.ioSurface, 4, 2);
    expect(top.sublist(0, 4), [0, 0, 255, 255], reason: 'top row: red as BGRA');
    expect(top.sublist(12, 16), [0, 0, 255, 255]);
    expect(bottom.sublist(0, 4), [255, 0, 0, 255], reason: 'bottom row: blue as BGRA');
  });

  testWidgets('an EntView shows the GL frames in a texture of its pixel size, made again on resize', (tester) async {
    final renderer = await tester.runAsync(() => OpenGlRenderer.create());
    final scene = ent.Scene()..add(ent.Mesh(ent.BoxGeometry(1, 1, 1), ent.MeshNormalMaterial()));
    final camera = ent.PerspectiveCamera(50, 1, 0.1, 100)..position.z = 3;
    addTearDown(renderer!.dispose);

    // Frames are shown once the surface is made and presented, which takes real time.
    Future<Texture> shown(double width, double height) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: EntView(renderer: renderer, scene: scene, camera: camera),
            ),
          ),
        ),
      );

      final ratio = tester.view.devicePixelRatio;
      final expected = Size((width * ratio).floor() / ratio, (height * ratio).floor() / ratio);

      for (var i = 0; i < 20; i++) {
        if (find.byType(Texture).evaluate().isNotEmpty && tester.getSize(find.byType(Texture)) == expected) {
          break;
        }

        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.getSize(find.byType(Texture)), expected);
      return tester.widget<Texture>(find.byType(Texture));
    }

    final first = await shown(120, 80);
    final again = await shown(120, 80);
    expect(again.textureId, first.textureId, reason: 'the same size keeps its surface');

    // A layout change of the same view: its display makes a surface of the new size.
    final resized = await shown(60, 90);
    expect(resized.textureId, isNot(first.textureId));
  });
}
