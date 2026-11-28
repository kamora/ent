// The native functions of src/ent_audio.c, which the build hook compiles into this asset.
@DefaultAsset('package:ent_audio/src/bindings.dart')
library;

import 'dart:ffi';

@Native<
  Int Function(Pointer<Void>, Size, Uint32, Pointer<Uint32>, Pointer<Uint32>, Pointer<Uint64>, Pointer<Pointer<Float>>)
>(symbol: 'ent_audio_decode')
external int decode(
  Pointer<Void> data,
  int size,
  int rate,
  Pointer<Uint32> channels,
  Pointer<Uint32> rateOut,
  Pointer<Uint64> frames,
  Pointer<Pointer<Float>> samples,
);

/// Frees what [decode] allocated.
final Pointer<NativeFinalizerFunction> free = Native.addressOf<NativeFinalizerFunction>(_free);

@Native<Void Function(Pointer<Void>)>(symbol: 'ent_audio_free')
external void _free(Pointer<Void> pointer);
