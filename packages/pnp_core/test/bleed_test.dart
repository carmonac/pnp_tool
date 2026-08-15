import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pnp_core/pnp_core.dart';
import 'package:test/test.dart';

Uint8List syntheticPng({int width = 100, int height = 140, int channels = 3}) {
  final image = img.Image(width: width, height: height, numChannels: channels);
  // Distinct edge colors so mirroring is verifiable.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x % 256, y % 256, 128, 255);
    }
  }
  return img.encodePng(image);
}

void main() {
  test('adds the requested bleed in pixels', () {
    // 100px over 50mm -> 2 px/mm; 2mm bleed -> 4px per side.
    final out = prepareImage(
      syntheticPng(),
      targetSize: const SizeMm(50, 70),
      bleedMm: 2,
      jpegQuality: null,
    );
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 100 + 8);
    expect(decoded.height, 140 + 8);
  });

  test('bleed border mirrors the edge content', () {
    final out = prepareImage(
      syntheticPng(),
      targetSize: const SizeMm(50, 70),
      bleedMm: 2,
      jpegQuality: null,
    );
    final decoded = img.decodeImage(out)!;
    const b = 4;

    // Left border column b-1 mirrors source column 0; b-2 mirrors column 1.
    final source = img.decodeImage(syntheticPng())!;
    for (final (borderX, srcX) in [(b - 1, 0), (b - 2, 1)]) {
      final borderPixel = decoded.getPixel(borderX, b + 10);
      final srcPixel = source.getPixel(srcX, 10);
      expect(borderPixel.r, srcPixel.r);
      expect(borderPixel.g, srcPixel.g);
    }
  });

  test('downscales images above maxDpi', () {
    // 1000px for 50mm ≈ 508 DPI -> capped to 300 DPI ≈ 590px.
    final out = prepareImage(
      syntheticPng(width: 1000, height: 1400),
      targetSize: const SizeMm(50, 70),
      bleedMm: 0,
      maxDpi: 300,
      jpegQuality: null,
    );
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, (50 / 25.4 * 300).round());
  });

  test('opaque images encode as JPEG, alpha keeps PNG', () {
    final jpeg = prepareImage(
      syntheticPng(channels: 3),
      targetSize: const SizeMm(50, 70),
      bleedMm: 0,
      jpegQuality: 90,
    );
    // JPEG magic bytes.
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);

    final png = prepareImage(
      syntheticPng(channels: 4),
      targetSize: const SizeMm(50, 70),
      bleedMm: 0,
      jpegQuality: 90,
    );
    expect(png[1], 0x50); // 'P' of PNG signature
  });

  test('cover fit crops to the target aspect ratio', () {
    // Square source into 1:2 target -> width halves.
    final out = prepareImage(
      syntheticPng(width: 200, height: 200),
      targetSize: const SizeMm(50, 100),
      bleedMm: 0,
      jpegQuality: null,
    );
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 100);
    expect(decoded.height, 200);
  });

  test('stretch fit keeps source dimensions', () {
    final out = prepareImage(
      syntheticPng(width: 200, height: 200),
      targetSize: const SizeMm(50, 100),
      bleedMm: 0,
      fitMode: FitMode.stretch,
      jpegQuality: null,
    );
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 200);
    expect(decoded.height, 200);
  });

  test('undecodable input throws', () {
    expect(
      () => prepareImage(Uint8List.fromList([1, 2, 3]),
          targetSize: const SizeMm(50, 70), bleedMm: 1),
      throwsFormatException,
    );
  });
}
