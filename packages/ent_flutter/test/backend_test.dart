// The renderer core's GPU interface over Flutter GPU (lib/src/gpu/backend.dart). The GPU tests need `flutter test
// --enable-impeller --enable-flutter-gpu`.
import 'dart:typed_data';

import 'package:ent_flutter/src/gpu/backend.dart';
import 'package:ent_renderer/gpu.dart' as ent;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

List<String> _names(List<Enum> values) => [for (final value in values) value.name];

void main() {
  test('every enum starts as Flutter GPU\'s does, so values map by index', () {
    final pairs = <(List<Enum>, List<Enum>)>[
      (ent.StorageMode.values, gpu.StorageMode.values),
      (ent.PixelFormat.values, gpu.PixelFormat.values),
      (ent.TextureType.values, gpu.TextureType.values),
      (ent.LoadAction.values, gpu.LoadAction.values),
      (ent.StoreAction.values, gpu.StoreAction.values),
      (ent.BlendFactor.values, gpu.BlendFactor.values),
      (ent.BlendOperation.values, gpu.BlendOperation.values),
      (ent.CompareFunction.values, gpu.CompareFunction.values),
      (ent.CullMode.values, gpu.CullMode.values),
      (ent.WindingOrder.values, gpu.WindingOrder.values),
      (ent.PrimitiveType.values, gpu.PrimitiveType.values),
      (ent.IndexType.values, gpu.IndexType.values),
      (ent.MinMagFilter.values, gpu.MinMagFilter.values),
      (ent.MipFilter.values, gpu.MipFilter.values),
      (ent.SamplerAddressMode.values, gpu.SamplerAddressMode.values),
      (ent.VertexFormat.values, gpu.VertexFormat.values),
      (ent.VertexStepMode.values, gpu.VertexStepMode.values),
    ];
    for (final (ours, theirs) in pairs) {
      expect(_names(ours), _names(theirs).take(ours.length));
    }
  });

  test('a render pass clears a texture, and read returns its pixels', () async {
    final context = FlutterGpuContext();
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

  test('a buffer takes what fits and refuses the rest', () {
    final buffer = FlutterGpuContext().createDeviceBuffer(ent.StorageMode.hostVisible, 8);
    expect(buffer.sizeInBytes, 8);
    expect(buffer.overwrite(ByteData(8)), isTrue);
    expect(buffer.overwrite(ByteData(8), destinationOffsetInBytes: 4), isFalse);
  });

  test('the shader bundle loads, and each shader keeps one handle', () async {
    final library = (await FlutterGpuLibrary.fromAsset('build/shaderbundles/ent.shaderbundle'))!;
    expect(library['missing shader'], isNull);

    final copy = library['CopyFragment']!;
    expect(identical(library['CopyFragment'], copy), isTrue);

    final slot = copy.getUniformSlot('FragInfo');
    expect(slot.sizeInBytes, isNotNull);
    expect(slot.getMemberOffsetInBytes('opacity'), 0);
    expect(slot.getMemberOffsetInBytes('flip'), 4);
    expect(slot.getMemberOffsetInBytes('missing'), isNull);
  });
}
