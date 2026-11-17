// Host-visible memory for per-frame data (uniforms, generated indices), recycled only after the GPU has finished
// with it. Flutter GPU's HostBuffer cycles through 4 frames, one per reset(), and the GPU reads its memory at
// execution: a fifth reset while an earlier frame is still in flight rewrites what that frame's draws are about
// to read (it also adds a block on every overflow and never reuses it). Here each frame writes into blocks of its
// own, which return to a capped pool when every command buffer submitted with them has completed
// (docs/flutter-gpu.md, Host buffers).

import 'dart:typed_data';

import 'package:flutter_gpu/gpu.dart' as gpu;

// One frame's blocks and its command buffers in flight.
class _Frame {
  final List<gpu.DeviceBuffer> blocks = [];

  int flight = 0;

  bool ended = false;
}

/// A bump allocator over pooled host-visible blocks, one frame at a time: [emplace] writes the current frame's
/// data, [submit] submits a command buffer that reads it, [next] ends the frame.
class HostBuffers {
  /// The length of each block; larger data gets a buffer of its own, dropped after its frame.
  static const int block = 64 * 1024;

  // The most free blocks kept for later frames; the rest are released.
  static const int _spare = 64;

  final List<gpu.DeviceBuffer> _free = [];

  _Frame _frame = _Frame();

  int _offset = 0;

  /// The current frame's number: a view [emplace] returns stays valid while it is unchanged.
  int frame = 0;

  /// Whether [view] lies in a block of the current frame (the reuse check of [UniformBlock]).
  bool holds(gpu.BufferView view) => _frame.blocks.any((block) => identical(block, view.buffer));

  /// Copies [bytes] into the current frame, aligned for a uniform binding, and returns the view.
  gpu.BufferView emplace(ByteData bytes) {
    final context = gpu.gpuContext;
    final length = bytes.lengthInBytes;
    final align = context.minimumUniformByteAlignment;
    var offset = (_offset + align - 1) ~/ align * align;

    if (length > block) {
      final buffer = context.createDeviceBuffer(gpu.StorageMode.hostVisible, length);
      _frame.blocks.add(buffer);
      _write(buffer, bytes, 0);
      return gpu.BufferView(buffer, offsetInBytes: 0, lengthInBytes: length);
    }

    if (_frame.blocks.isEmpty || _frame.blocks.last.sizeInBytes != block || offset + length > block) {
      _frame.blocks.add(
        _free.isEmpty ? context.createDeviceBuffer(gpu.StorageMode.hostVisible, block) : _free.removeLast(),
      );
      offset = 0;
    }

    _write(_frame.blocks.last, bytes, offset);
    _offset = offset + length;
    return gpu.BufferView(_frame.blocks.last, offsetInBytes: offset, lengthInBytes: length);
  }

  /// Ends the current frame: its blocks return to the pool now if nothing that reads them is in flight, else when
  /// the last such command buffer completes.
  void next() {
    final frame = _frame..ended = true;
    _frame = _Frame();
    _offset = 0;
    this.frame++;

    if (frame.flight == 0) {
      _release(frame);
    }
  }

  /// Submits [commands], which read the current frame's data, with [done] as the completion callback.
  void submit(gpu.CommandBuffer commands, [gpu.CompletionCallback? done]) {
    final frame = _frame..flight += 1;
    commands.submit(
      completionCallback: (success) {
        frame.flight -= 1;

        if (frame.flight == 0 && frame.ended) {
          _release(frame);
        }

        done?.call(success);
      },
    );
  }

  void _release(_Frame frame) {
    for (final buffer in frame.blocks) {
      if (buffer.sizeInBytes == block && _free.length < _spare) {
        _free.add(buffer);
      }
    }

    frame.blocks.clear();
  }

  static void _write(gpu.DeviceBuffer buffer, ByteData bytes, int offset) {
    if (!buffer.overwrite(bytes, destinationOffsetInBytes: offset)) {
      throw StateError('HostBuffers: writing ${bytes.lengthInBytes} bytes at $offset failed.');
    }
  }
}
