// The native functions of src/ent_audio.c, which the build hook compiles into this asset.
@DefaultAsset('package:ent_audio/src/bindings.dart')
library;

import 'dart:ffi';

/// A native buffer (`ent_buffer`).
final class Buffer extends Opaque {}

/// A native context (`ent_context`).
final class Context extends Opaque {}

/// A native node (`ent_node`).
final class Node extends Opaque {}

@Native<Pointer<Buffer> Function(Uint32, Uint64, Uint32)>(symbol: 'ent_buffer_create')
external Pointer<Buffer> bufferCreate(int channels, int length, int rate);

@Native<Int Function(Pointer<Void>, Size, Uint32, Pointer<Pointer<Buffer>>)>(symbol: 'ent_buffer_decode')
external int bufferDecode(Pointer<Void> data, int size, int rate, Pointer<Pointer<Buffer>> out);

@Native<Void Function(Pointer<Buffer>)>(symbol: 'ent_buffer_retain')
external void bufferRetain(Pointer<Buffer> buffer);

@Native<Pointer<Float> Function(Pointer<Buffer>)>(symbol: 'ent_buffer_data')
external Pointer<Float> bufferData(Pointer<Buffer> buffer);

@Native<Uint32 Function(Pointer<Buffer>)>(symbol: 'ent_buffer_channels')
external int bufferChannels(Pointer<Buffer> buffer);

@Native<Uint32 Function(Pointer<Buffer>)>(symbol: 'ent_buffer_rate')
external int bufferRate(Pointer<Buffer> buffer);

@Native<Uint64 Function(Pointer<Buffer>)>(symbol: 'ent_buffer_length')
external int bufferLength(Pointer<Buffer> buffer);

/// Drops one hold on a buffer.
final Pointer<NativeFinalizerFunction> bufferRelease = Native.addressOf<NativeFinalizerFunction>(_bufferRelease);

@Native<Void Function(Pointer<Void>)>(symbol: 'ent_buffer_release')
external void _bufferRelease(Pointer<Void> pointer);

@Native<Pointer<Context> Function(Uint32, Uint32, Pointer<NativeFunction<Void Function(Int32)>>)>(
  symbol: 'ent_context_create',
)
external Pointer<Context> contextCreate(int rate, int channels, Pointer<NativeFunction<Void Function(Int32)>> ended);

/// Drops the Dart hold on a context.
final Pointer<NativeFinalizerFunction> contextRelease = Native.addressOf<NativeFinalizerFunction>(_contextRelease);

@Native<Void Function(Pointer<Void>)>(symbol: 'ent_context_release')
external void _contextRelease(Pointer<Void> pointer);

@Native<Pointer<Node> Function(Pointer<Context>)>(symbol: 'ent_context_destination')
external Pointer<Node> contextDestination(Pointer<Context> context);

@Native<Double Function(Pointer<Context>)>(symbol: 'ent_context_time')
external double contextTime(Pointer<Context> context);

@Native<Void Function(Pointer<Context>, Pointer<Float>, Uint32)>(symbol: 'ent_context_render')
external void contextRender(Pointer<Context> context, Pointer<Float> out, int quanta);

/// Drops the Dart handle of a node.
final Pointer<NativeFinalizerFunction> nodeRelease = Native.addressOf<NativeFinalizerFunction>(_nodeRelease);

@Native<Void Function(Pointer<Void>)>(symbol: 'ent_node_release')
external void _nodeRelease(Pointer<Void> pointer);

@Native<Int32 Function(Pointer<Node>)>(symbol: 'ent_node_id')
external int nodeId(Pointer<Node> node);

@Native<Int Function(Pointer<Node>, Pointer<Node>)>(symbol: 'ent_node_connect')
external int nodeConnect(Pointer<Node> node, Pointer<Node> destination);

@Native<Void Function(Pointer<Node>, Pointer<Node>)>(symbol: 'ent_node_disconnect')
external void nodeDisconnect(Pointer<Node> node, Pointer<Node> destination);

@Native<Void Function(Pointer<Node>, Int32, Double)>(symbol: 'ent_param_set')
external void paramSet(Pointer<Node> node, int param, double value);

@Native<Double Function(Pointer<Node>, Int32)>(symbol: 'ent_param_get')
external double paramGet(Pointer<Node> node, int param);

@Native<Pointer<Node> Function(Pointer<Context>)>(symbol: 'ent_source_create')
external Pointer<Node> sourceCreate(Pointer<Context> context);

@Native<Void Function(Pointer<Node>, Pointer<Buffer>)>(symbol: 'ent_source_buffer')
external void sourceBuffer(Pointer<Node> node, Pointer<Buffer> buffer);

@Native<Void Function(Pointer<Node>, Int32, Double, Double)>(symbol: 'ent_source_loop')
external void sourceLoop(Pointer<Node> node, int loop, double start, double end);

@Native<Void Function(Pointer<Node>, Double, Double, Double)>(symbol: 'ent_source_start')
external void sourceStart(Pointer<Node> node, double when, double offset, double duration);

@Native<Void Function(Pointer<Node>, Double)>(symbol: 'ent_source_stop')
external void sourceStop(Pointer<Node> node, double when);
