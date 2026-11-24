// The renderer core's GPU interface on OpenGL ES 3 (lib/src/backend.dart), on ANGLE on the host; ANGLE is bundled
// for macOS only so far.
@TestOn('mac-os')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ent_opengl/ent_opengl.dart';
import 'package:ent_renderer/gpu.dart' as ent;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  late final GlContext context;

  setUpAll(() => context = GlContext());

  test('a render pass clears a texture, and read returns its pixels', () async {
    final texture = context.createTexture(ent.StorageMode.devicePrivate, 4, 2);
    final commands = context.createCommandBuffer();
    commands.createRenderPass(
      ent.RenderTarget.singleColor(ent.ColorAttachment(texture: texture, clearValue: vm.Vector4(1, 0.5, 0, 1))),
    );
    commands.submit();

    final rgba = (await texture.read()).buffer.asUint8List();
    expect(rgba.length, 4 * 2 * 4);
    expect(rgba.sublist(0, 4), [255, 128, 0, 255]);
    expect(rgba.sublist(28), [255, 128, 0, 255]);
  });

  test('a pass with a depth attachment clears both, and one that loads keeps the color', () async {
    final texture = context.createTexture(ent.StorageMode.devicePrivate, 2, 2);
    final depth = context.createTexture(
      ent.StorageMode.deviceTransient,
      2,
      2,
      format: context.defaultDepthStencilFormat,
    );
    final commands = context.createCommandBuffer();
    commands.createRenderPass(
      ent.RenderTarget.singleColor(
        ent.ColorAttachment(texture: texture, clearValue: vm.Vector4(0, 0, 1, 1)),
        depthStencilAttachment: ent.DepthStencilAttachment(texture: depth, depthClearValue: 1),
      ),
    );
    commands.createRenderPass(
      ent.RenderTarget.singleColor(ent.ColorAttachment(texture: texture, loadAction: ent.LoadAction.load)),
    );

    var done = false;
    commands.submit(completionCallback: (success) => done = success);
    expect(done, isFalse, reason: 'reported asynchronously');
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
    expect((await texture.read()).buffer.asUint8List().sublist(0, 4), [0, 0, 255, 255]);
    expect(commands.submit, throwsStateError);
  });

  test('overwrite writes a level, row 0 first, and refuses the wrong size', () async {
    final texture = context.createTexture(ent.StorageMode.hostVisible, 2, 2);
    final rows = Uint8List.fromList([for (var i = 0; i < 16; i++) i * 10]);
    texture.overwrite(ByteData.sublistView(rows));
    expect((await texture.read()).buffer.asUint8List(), rows);
    expect(() => texture.overwrite(ByteData(4)), throwsArgumentError);
  });

  test('overwrite reads only the bytes of a view into a larger buffer', () async {
    final bytes = Uint8List.fromList([for (var i = 0; i < 40; i++) i]);
    final texture = context.createTexture(ent.StorageMode.hostVisible, 2, 2)
      ..overwrite(ByteData.sublistView(bytes, 8, 24));
    expect((await texture.read()).buffer.asUint8List(), bytes.sublist(8, 24));
    expect(
      context.createDeviceBuffer(ent.StorageMode.hostVisible, 16).overwrite(ByteData.sublistView(bytes, 8, 24)),
      isTrue,
    );
  });

  test('a buffer takes what fits and refuses the rest', () {
    final buffer = context.createDeviceBuffer(ent.StorageMode.hostVisible, 8);
    expect(buffer.sizeInBytes, 8);
    expect(buffer.overwrite(ByteData(8)), isTrue);
    expect(buffer.overwrite(ByteData(8), destinationOffsetInBytes: 4), isFalse);
    expect(context.createDeviceBufferWithCopy(ByteData(12)).sizeInBytes, 12);
  });

  test('the context reports its limits', () {
    // Our ANGLE on Metal on macOS; the system's OpenGL ES elsewhere.
    if (Platform.isMacOS) {
      expect(context.renderer, allOf(contains('ANGLE'), contains('Metal')));
    }

    expect(context.minimumUniformByteAlignment, greaterThan(0));
    expect(context.supportsTextureFormat(ent.PixelFormat.r16g16b16a16Float), isTrue);
    expect(context.supportsTextureFormat(ent.PixelFormat.unknown), isFalse);
  });
}
