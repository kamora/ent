part of '../../ent.dart';

// HDRLoader and its deprecated alias RGBELoader.

/// A loader for the RGBE HDR texture format.
///
/// ```dart
/// final envMap = await HDRLoader().loadAsync('textures/equirectangular/blouberg_sunrise_2_1k.hdr');
/// envMap.mapping = EquirectangularReflectionMapping;
///
/// scene.environment = envMap;
/// ```
class HDRLoader extends DataTextureLoader {
  /// Constructs a new RGBE/HDR loader.
  HDRLoader([super.manager]);

  /// The texture type ([HalfFloatType] or [FloatType]).
  int type = HalfFloatType;

  /// Parses the given RGBE texture data.
  @override
  Map<String, Object?> parse(covariant ByteBuffer buffer) {
    // adapted from http://www.graphics.cornell.edu/~bjw/rgbe.html

    /* default error routine.  change this to change error handling */
    const readError = 1, writeError = 2, formatError = 3;

    Never rgbeError(int code, [String? msg]) {
      switch (code) {
        case readError:
          throw EntError('ENT.HDRLoader: Read Error: ${msg ?? ''}');
        case writeError:
          throw EntError('ENT.HDRLoader: Write Error: ${msg ?? ''}');
        case formatError:
          throw EntError('ENT.HDRLoader: Bad File Format: ${msg ?? ''}');
        default:
          throw EntError('ENT.HDRLoader: Memory Error: ${msg ?? ''}');
      }
    }

    /* flags indicating which fields in an rgbe_header_info are valid */
    const validProgramType = 1, validFormat = 2, validDimensions = 4;

    final bytes = buffer.asUint8List();
    var pos = 0;

    // fgets: one line from pos (without its newline), read in chunks of 128 bytes up to lineLimit; `null` (the
    // reference's false) when there is none.
    String? fgets([int lineLimit = 1024, bool consume = true]) {
      const chunkSize = 128;

      String chunk(int p) =>
          String.fromCharCodes(bytes.sublist(math.min(p, bytes.length), math.min(p + chunkSize, bytes.length)));

      var p = pos, i = -1, len = 0, s = '', c = chunk(p);

      while (0 > (i = c.indexOf('\n')) && len < lineLimit && p < bytes.length) {
        s += c;
        len += c.length;
        p += chunkSize;
        c = chunk(p);
      }

      if (-1 < i) {
        if (consume) {
          pos += len + i + 1;
        }

        return s + c.substring(0, i);
      }

      return null;
    }

    /* minimal header reading.  modify if you want to parse more information */
    ({
      int valid,
      String string,
      String comments,
      String programType,
      String format,
      double gamma,
      double exposure,
      int width,
      int height,
    })
    readHeader() {
      // regexes to parse header info fields
      final magic = RegExp(r'^#\?(\S+)'),
          gammaRe = RegExp(r'^\s*GAMMA\s*=\s*(\d+(\.\d+)?)\s*$'),
          exposureRe = RegExp(r'^\s*EXPOSURE\s*=\s*(\d+(\.\d+)?)\s*$'),
          formatRe = RegExp(r'^\s*FORMAT=(\S+)\s*$'),
          dimensionsRe = RegExp(r'^\s*\-Y\s+(\d+)\s+\+X\s+(\d+)\s*$');

      // RGBE format header struct
      var valid = 0, string = '', comments = '', format = '', gamma = 1.0, exposure = 1.0, width = 0, height = 0;

      String? line;

      // An empty line is falsy in the reference too.
      if (pos >= bytes.length || (line = fgets()) == null || line!.isEmpty) {
        rgbeError(readError, 'no header found');
      }

      /* if you want to require the magic token then uncomment the next line */
      final token = magic.firstMatch(line);

      if (token == null) {
        rgbeError(formatError, 'bad initial token');
      }

      valid |= validProgramType;
      string += '$line\n';

      while (true) {
        line = fgets();

        if (line == null) {
          break;
        }

        string += '$line\n';

        if (line.startsWith('#')) {
          comments += '$line\n';
          continue; // comment line
        }

        if (gammaRe.firstMatch(line) case final match?) {
          gamma = double.parse(match[1]!);
        }

        if (exposureRe.firstMatch(line) case final match?) {
          exposure = double.parse(match[1]!);
        }

        if (formatRe.firstMatch(line) case final match?) {
          valid |= validFormat;
          format = match[1]!; //'32-bit_rle_rgbe';
        }

        if (dimensionsRe.firstMatch(line) case final match?) {
          valid |= validDimensions;
          height = int.parse(match[1]!);
          width = int.parse(match[2]!);
        }

        if ((valid & validFormat) != 0 && (valid & validDimensions) != 0) {
          break;
        }
      }

      if ((valid & validFormat) == 0) {
        rgbeError(formatError, 'missing format specifier');
      }

      if ((valid & validDimensions) == 0) {
        rgbeError(formatError, 'missing image size specifier');
      }

      return (
        valid: valid,
        string: string,
        comments: comments,
        programType: token[1]!,
        format: format,
        gamma: gamma,
        exposure: exposure,
        width: width,
        height: height,
      );
    }

    Uint8List readPixelsRle(Uint8List buffer, int w, int h) {
      final width = w;

      if (
      // run length encoding is not allowed so read flat
      (width < 8 || width > 0x7fff) ||
          // this file is not run length encoded
          (buffer.length < 4 || 2 != buffer[0] || 2 != buffer[1] || (buffer[2] & 0x80) != 0)) {
        // return the flat buffer
        return Uint8List.fromList(buffer);
      }

      if (width != ((buffer[2] << 8) | buffer[3])) {
        rgbeError(formatError, 'wrong scanline width');
      }

      final rgba = Uint8List(4 * w * h);

      if (rgba.isEmpty) {
        rgbeError(4, 'unable to allocate buffer space');
      }

      var offset = 0, pos = 0;

      final end = 4 * width;
      final start = Uint8List(4);
      final scanline = Uint8List(end);
      var scanlines = h;

      // read in each successive scanline
      while (scanlines > 0 && pos < buffer.length) {
        if (pos + 4 > buffer.length) {
          rgbeError(readError);
        }

        start[0] = buffer[pos++];
        start[1] = buffer[pos++];
        start[2] = buffer[pos++];
        start[3] = buffer[pos++];

        if (2 != start[0] || 2 != start[1] || ((start[2] << 8) | start[3]) != width) {
          rgbeError(formatError, 'bad rgbe scanline format');
        }

        // read each of the four channels for the scanline into the buffer
        // first red, then green, then blue, then exponent
        var ptr = 0;

        while (ptr < end && pos < buffer.length) {
          var count = buffer[pos++];
          final run = count > 128;

          if (run) {
            count -= 128;
          }

          if (0 == count || ptr + count > end) {
            rgbeError(formatError, 'bad scanline data');
          }

          if (run) {
            // a (encoded) run of the same value
            final value = buffer[pos++];

            for (var i = 0; i < count; i++) {
              scanline[ptr++] = value;
            }
          } else {
            // a literal-run
            scanline.setRange(ptr, ptr + count, buffer, pos);
            ptr += count;
            pos += count;
          }
        }

        // now convert data from buffer into rgba
        // first red, then green, then blue, then exponent (alpha)
        for (var i = 0; i < width; i++) {
          rgba[offset] = scanline[i];
          rgba[offset + 1] = scanline[i + width];
          rgba[offset + 2] = scanline[i + 2 * width];
          rgba[offset + 3] = scanline[i + 3 * width];
          offset += 4;
        }

        scanlines--;
      }

      return rgba;
    }

    void toFloat(Uint8List source, int from, Float32List dest, int to) {
      final scale = math.pow(2.0, source[from + 3] - 128.0) / 255.0;

      dest[to + 0] = source[from + 0] * scale;
      dest[to + 1] = source[from + 1] * scale;
      dest[to + 2] = source[from + 2] * scale;
      dest[to + 3] = 1;
    }

    void toHalf(Uint8List source, int from, Uint16List dest, int to) {
      final scale = math.pow(2.0, source[from + 3] - 128.0) / 255.0;

      // clamping to 65504, the maximum representable value in float16
      dest[to + 0] = DataUtils.toHalfFloat(math.min(source[from + 0] * scale, 65504));
      dest[to + 1] = DataUtils.toHalfFloat(math.min(source[from + 1] * scale, 65504));
      dest[to + 2] = DataUtils.toHalfFloat(math.min(source[from + 2] * scale, 65504));
      dest[to + 3] = DataUtils.toHalfFloat(1);
    }

    final header = readHeader();
    final w = header.width, h = header.height, rgba = readPixelsRle(bytes.sublist(pos), w, h);

    // Whole RGBE texels; the reference's fractional count only differs for a flat file with trailing bytes.
    final count = rgba.length ~/ 4;
    final TypedData data;

    switch (type) {
      case FloatType:
        final floats = Float32List(count * 4);

        for (var j = 0; j < count; j++) {
          toFloat(rgba, j * 4, floats, j * 4);
        }

        data = floats;
      case HalfFloatType:
        final halves = Uint16List(count * 4);

        for (var j = 0; j < count; j++) {
          toHalf(rgba, j * 4, halves, j * 4);
        }

        data = halves;
      default:
        throw EntError('ENT.HDRLoader: Unsupported type: $type');
    }

    return {
      'width': w,
      'height': h,
      'data': data,
      'header': header.string,
      'gamma': header.gamma,
      'exposure': header.exposure,
      'type': type,
      'colorSpace': LinearSRGBColorSpace,
      'minFilter': LinearFilter,
      'magFilter': LinearFilter,
      'generateMipmaps': false,
      'flipY': true,
    };
  }

  /// Sets the texture type.
  HDRLoader setDataType(int value) {
    type = value;
    return this;
  }
}

/// The deprecated name of [HDRLoader].
@Deprecated('Use HDRLoader instead.')
class RGBELoader extends HDRLoader {
  /// Constructs a new loader with the given manager, with a deprecation warning.
  RGBELoader([super.manager]) {
    warn('RGBELoader has been deprecated. Please use HDRLoader instead.');
  }
}
