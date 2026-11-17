part of '../../ent.dart';

// Fast Half Float Conversions, http://www.fox-toolkit.org/ftp/fasthalffloatconversion.pdf

final _DataUtilsTables _dataUtilsTables = _DataUtilsTables();

class _DataUtilsTables {
  _DataUtilsTables() {
    // float32 to float16 helpers

    for (var i = 0; i < 256; ++i) {
      final e = i - 127;

      // very small number (0, -0)

      if (e < -27) {
        baseTable[i] = 0x0000;
        baseTable[i | 0x100] = 0x8000;
        shiftTable[i] = 24;
        shiftTable[i | 0x100] = 24;

        // small number (denorm)
      } else if (e < -14) {
        baseTable[i] = 0x0400 >> (-e - 14);
        baseTable[i | 0x100] = (0x0400 >> (-e - 14)) | 0x8000;
        shiftTable[i] = -e - 1;
        shiftTable[i | 0x100] = -e - 1;

        // normal number
      } else if (e <= 15) {
        baseTable[i] = (e + 15) << 10;
        baseTable[i | 0x100] = ((e + 15) << 10) | 0x8000;
        shiftTable[i] = 13;
        shiftTable[i | 0x100] = 13;

        // large number (Infinity, -Infinity)
      } else if (e < 128) {
        baseTable[i] = 0x7c00;
        baseTable[i | 0x100] = 0xfc00;
        shiftTable[i] = 24;
        shiftTable[i | 0x100] = 24;

        // stay (NaN, Infinity, -Infinity)
      } else {
        baseTable[i] = 0x7c00;
        baseTable[i | 0x100] = 0xfc00;
        shiftTable[i] = 13;
        shiftTable[i | 0x100] = 13;
      }
    }

    // float16 to float32 helpers

    for (var i = 1; i < 1024; ++i) {
      var m = i << 13; // zero pad mantissa bits
      var e = 0; // zero exponent

      // normalized
      while ((m & 0x00800000) == 0) {
        m <<= 1;
        e -= 0x00800000; // decrement exponent
      }

      m &= ~0x00800000; // clear leading 1 bit
      e += 0x38800000; // adjust bias

      mantissaTable[i] = _jsToUint32(m | e);
    }

    for (var i = 1024; i < 2048; ++i) {
      mantissaTable[i] = 0x38000000 + ((i - 1024) << 13);
    }

    for (var i = 1; i < 31; ++i) {
      exponentTable[i] = i << 23;
    }

    exponentTable[31] = 0x47800000;
    exponentTable[32] = 0x80000000;

    for (var i = 33; i < 63; ++i) {
      exponentTable[i] = 0x80000000 + ((i - 32) << 23);
    }

    exponentTable[63] = 0xc7800000;

    for (var i = 1; i < 64; ++i) {
      if (i != 32) {
        offsetTable[i] = 1024;
      }
    }
  }

  final Float32List floatView = Float32List(1);

  late final Uint32List uint32View = Uint32List.view(floatView.buffer);

  final Uint32List baseTable = Uint32List(512);

  final Uint32List shiftTable = Uint32List(512);

  final Uint32List mantissaTable = Uint32List(2048);

  final Uint32List exponentTable = Uint32List(64);

  final Uint32List offsetTable = Uint32List(64);
}

/// Returns a half precision floating point value (FP16) from the given single precision floating point
/// value (FP32), as an integer holding the 16 bits.
int _dataUtilsToHalfFloat(double val) {
  if (val.abs() > 65504) {
    warn('DataUtils.toHalfFloat(): Value out of range.');
  }

  val = MathUtils.clamp(val, -65504, 65504);

  final tables = _dataUtilsTables;
  tables.floatView[0] = val;
  final f = tables.uint32View[0];
  final e = (f >> 23) & 0x1ff;
  return tables.baseTable[e] + ((f & 0x007fffff) >> tables.shiftTable[e]);
}

/// Returns a single precision floating point value (FP32) from the given half precision floating point
/// value (FP16).
double _dataUtilsFromHalfFloat(int val) {
  final tables = _dataUtilsTables;
  final m = val >> 10;
  tables.uint32View[0] = tables.mantissaTable[tables.offsetTable[m] + (val & 0x3ff)] + tables.exponentTable[m];
  return tables.floatView[0];
}

/// A class containing utility functions for data.
abstract final class DataUtils {
  /// Returns a half precision floating point value (FP16) from the given single precision floating point
  /// value (FP32).
  static int toHalfFloat(double val) {
    return _dataUtilsToHalfFloat(val);
  }

  /// Returns a single precision floating point value (FP32) from the given half precision floating point
  /// value (FP16).
  static double fromHalfFloat(int val) {
    return _dataUtilsFromHalfFloat(val);
  }
}
