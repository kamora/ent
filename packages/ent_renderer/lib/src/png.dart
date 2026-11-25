// A PNG decoder to straight RGBA bytes, as the browser hands an image to WebGL with `premultiplyAlpha: 'none'` and
// `colorSpaceConversion: 'none'` (the reference's ImageBitmapLoader): dart:ui premultiplies on decoding, which loses
// the color of transparent texels (exception E-DECODE). Every color type and bit depth, tRNS, the five filters,
// Adam7 and split IDAT data; 16-bit samples keep their high byte; gAMA, iCCP and sRGB are ignored and CRCs are not
// checked.

import 'dart:io';
import 'dart:typed_data';

/// Whether [bytes] start with PNG's signature.
bool isPng(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  return bytes.length >= 8 && !Iterable.generate(8, (i) => bytes[i] == signature[i]).contains(false);
}

/// Decodes PNG [bytes] to straight RGBA, top row first, or returns `null` when they are not a PNG. Throws a
/// [FormatException] for a broken one.
({int width, int height, Uint8List pixels})? decodePng(Uint8List bytes) {
  if (!isPng(bytes)) {
    return null;
  }

  final data = ByteData.sublistView(bytes);
  final idat = BytesBuilder(copy: false);
  var (width, height, depth, type, interlace) = (0, 0, 0, -1, 0);
  Uint8List? palette;
  Uint8List? trns;

  for (var at = 8; at + 8 <= bytes.length;) {
    final end = at + 8 + data.getUint32(at);

    if (end + 4 > bytes.length) {
      throw const FormatException('PNG: truncated chunk');
    }

    final body = Uint8List.sublistView(bytes, at + 8, end);

    switch (String.fromCharCodes(bytes, at + 4, at + 8)) {
      case 'IHDR':
        (width, height) = (data.getUint32(at + 8), data.getUint32(at + 12));
        (depth, type, interlace) = (body[8], body[9], body[12]);
      case 'PLTE':
        palette = body;
      case 'tRNS':
        trns = body;
      case 'IDAT':
        idat.add(body);
      case 'IEND':
        at = bytes.length;
        continue;
    }

    at = end + 4;
  }

  // Samples per pixel and the bit depths allowed, by color type.
  final format = const {
    0: (1, [1, 2, 4, 8, 16]),
    2: (3, [8, 16]),
    3: (1, [1, 2, 4, 8]),
    4: (2, [8, 16]),
    6: (4, [8, 16]),
  }[type];

  if (format == null || !format.$2.contains(depth) || width == 0 || height == 0 || (type == 3 && palette == null)) {
    throw const FormatException('PNG: unsupported header');
  }

  final channels = format.$1;
  final raw = Uint8List.fromList(ZLibCodec().decode(idat.takeBytes()));
  final bits = channels * depth;
  final max = (1 << depth) - 1;
  final pixels = Uint8List(width * height * 4);

  // The tRNS key of a gray or RGB image, in raw samples.
  List<int>? key;

  if (trns != null && type != 3) {
    key = [for (var i = 0; i + 1 < trns.length; i += 2) trns[i] << 8 | trns[i + 1]];
  }

  int sample(Uint8List row, int i) => switch (depth) {
    16 => row[i * 2] << 8 | row[i * 2 + 1],
    8 => row[i],
    _ => row[(i * depth) >> 3] >> (8 - depth - (i * depth & 7)) & max,
  };

  int scale(int v) => depth == 16 ? v >> 8 : (depth == 8 ? v : v * 255 ~/ max);

  // A plain image's one pass, then Adam7's seven, as [x0, y0, dx, dy].
  const passes = [
    [0, 0, 1, 1],
    [0, 0, 8, 8],
    [4, 0, 8, 8],
    [0, 4, 4, 8],
    [2, 0, 4, 4],
    [0, 2, 2, 4],
    [1, 0, 2, 2],
    [0, 1, 1, 2],
  ];

  var at = 0;

  for (final [x0, y0, dx, dy] in interlace == 1 ? passes.skip(1) : passes.take(1)) {
    final w = (width - x0 + dx - 1) ~/ dx;
    final h = (height - y0 + dy - 1) ~/ dy;

    if (w <= 0 || h <= 0) {
      continue;
    }

    final stride = (w * bits + 7) >> 3;
    var prior = Uint8List(stride);

    for (var y = 0; y < h; y++) {
      if (at + 1 + stride > raw.length) {
        throw const FormatException('PNG: truncated image data');
      }

      final row = Uint8List.sublistView(raw, at + 1, at + 1 + stride);

      // The filters' byte distance to the pixel on the left is a whole pixel, at least one byte.
      _unfilter(raw[at], row, prior, (bits + 7) >> 3);
      at += 1 + stride;
      prior = row;

      // 8-bit RGBA rows of full width are already the output.
      if (type == 6 && depth == 8 && dx == 1) {
        pixels.setRange((y0 + y * dy) * width * 4, (y0 + y * dy + 1) * width * 4, row);
        continue;
      }

      // 8-bit RGB rows without a key only gain an opaque alpha.
      if (type == 2 && depth == 8 && key == null) {
        for (var x = 0, o = ((y0 + y * dy) * width + x0) * 4; x < w; x++, o += dx * 4) {
          pixels
            ..[o] = row[x * 3]
            ..[o + 1] = row[x * 3 + 1]
            ..[o + 2] = row[x * 3 + 2]
            ..[o + 3] = 255;
        }

        continue;
      }

      for (var x = 0; x < w; x++) {
        final o = ((y0 + y * dy) * width + x0 + x * dx) * 4;
        final s = x * channels;

        if (type == 3) {
          final index = sample(row, s);

          if (index * 3 + 2 < palette!.length) {
            pixels.setRange(o, o + 3, palette, index * 3);
          }

          if (trns != null && index < trns.length) {
            pixels[o + 3] = trns[index];
          } else {
            pixels[o + 3] = 255;
          }
        } else if (type == 0 || type == 4) {
          final gray = sample(row, s);
          pixels.fillRange(o, o + 3, scale(gray));

          if (type == 4) {
            pixels[o + 3] = scale(sample(row, s + 1));
          } else if (key != null && gray == key[0]) {
            pixels[o + 3] = 0;
          } else {
            pixels[o + 3] = 255;
          }
        } else {
          final r = sample(row, s);
          final g = sample(row, s + 1);
          final b = sample(row, s + 2);
          pixels
            ..[o] = scale(r)
            ..[o + 1] = scale(g)
            ..[o + 2] = scale(b);

          if (type == 6) {
            pixels[o + 3] = scale(sample(row, s + 3));
          } else if (key != null && key.length == 3 && r == key[0] && g == key[1] && b == key[2]) {
            pixels[o + 3] = 0;
          } else {
            pixels[o + 3] = 255;
          }
        }
      }
    }
  }

  return (width: width, height: height, pixels: pixels);
}

// Reverses a row's filter in place, given the row above (zeros for a pass's first row).
void _unfilter(int filter, Uint8List row, Uint8List prior, int step) {
  switch (filter) {
    case 0:
      return;
    case 1:
      for (var i = step; i < row.length; i++) {
        row[i] += row[i - step];
      }
    case 2:
      for (var i = 0; i < row.length; i++) {
        row[i] += prior[i];
      }
    case 3:
      for (var i = 0; i < row.length; i++) {
        row[i] += ((i < step ? 0 : row[i - step]) + prior[i]) >> 1;
      }
    case 4:
      for (var i = 0; i < row.length; i++) {
        final a = i < step ? 0 : row[i - step];
        final b = prior[i];
        final c = i < step ? 0 : prior[i - step];

        // Paeth's predictor: the neighbour closest to a + b - c, ties to a, then b.
        final pa = (b - c).abs();
        final pb = (a - c).abs();
        final pc = (a + b - c - c).abs();

        if (pa <= pb && pa <= pc) {
          row[i] += a;
        } else if (pb <= pc) {
          row[i] += b;
        } else {
          row[i] += c;
        }
      }
    default:
      throw FormatException('PNG: unknown filter $filter');
  }
}
