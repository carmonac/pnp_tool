import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/geometry.dart';
import '../models/project.dart';

const mmPerInch = 25.4;

/// Prepares a source image for placement at [targetSize] (trim size, mm):
/// applies [fitMode], optionally downscales to [maxDpi], extends the borders
/// with a mirrored bleed of [bleedMm], and encodes the result (JPEG at
/// [jpegQuality] for opaque images, PNG otherwise or when quality is null).
Uint8List prepareImage(
  Uint8List inputBytes, {
  required SizeMm targetSize,
  required double bleedMm,
  FitMode fitMode = FitMode.cover,
  int maxDpi = 300,
  int? jpegQuality = 90,
}) {
  img.Image? image;
  try {
    image = img.decodeImage(inputBytes);
  } catch (_) {
    image = null;
  }
  if (image == null) {
    throw const FormatException('Could not decode image');
  }

  image = _applyFit(image, targetSize, fitMode);

  // Downscale if the image resolves above maxDpi for its printed size.
  final maxWidthPx = (targetSize.width / mmPerInch * maxDpi).round();
  if (image.width > maxWidthPx) {
    image = img.copyResize(
      image,
      width: maxWidthPx,
      interpolation: img.Interpolation.average,
    );
  }

  final pxPerMm = image.width / targetSize.width;
  final bleedPx = (bleedMm * pxPerMm).round();
  if (bleedPx > 0) {
    image = _extendWithMirroredBleed(image, bleedPx);
  }

  final hasAlpha = image.numChannels == 4;
  if (jpegQuality != null && !hasAlpha) {
    return img.encodeJpg(image, quality: jpegQuality);
  }
  return img.encodePng(image);
}

img.Image _applyFit(img.Image image, SizeMm targetSize, FitMode fitMode) {
  final targetAspect = targetSize.width / targetSize.height;
  final imageAspect = image.width / image.height;
  if (fitMode == FitMode.stretch ||
      (imageAspect - targetAspect).abs() < 0.001) {
    return image;
  }

  if (fitMode == FitMode.cover) {
    // Center-crop to the target aspect ratio.
    int cropWidth, cropHeight;
    if (imageAspect > targetAspect) {
      cropHeight = image.height;
      cropWidth = (image.height * targetAspect).round();
    } else {
      cropWidth = image.width;
      cropHeight = (image.width / targetAspect).round();
    }
    return img.copyCrop(
      image,
      x: (image.width - cropWidth) ~/ 2,
      y: (image.height - cropHeight) ~/ 2,
      width: cropWidth,
      height: cropHeight,
    );
  }

  // contain: pad with transparency to the target aspect ratio.
  int canvasWidth, canvasHeight;
  if (imageAspect > targetAspect) {
    canvasWidth = image.width;
    canvasHeight = (image.width / targetAspect).round();
  } else {
    canvasHeight = image.height;
    canvasWidth = (image.height * targetAspect).round();
  }
  final canvas = img.Image(
    width: canvasWidth,
    height: canvasHeight,
    numChannels: 4,
  );
  return img.compositeImage(
    canvas,
    image,
    dstX: (canvasWidth - image.width) ~/ 2,
    dstY: (canvasHeight - image.height) ~/ 2,
  );
}

/// Extends the image by [bleedPx] on every side, filling the border with a
/// mirror of the adjacent edge content.
img.Image _extendWithMirroredBleed(img.Image src, int bleedPx) {
  final b = bleedPx.clamp(1, src.width < src.height ? src.width : src.height);
  final w = src.width;
  final h = src.height;

  final result = img.Image(
    width: w + 2 * b,
    height: h + 2 * b,
    numChannels: src.numChannels,
  );

  img.Image crop(int x, int y, int cw, int ch) =>
      img.copyCrop(src, x: x, y: y, width: cw, height: ch);

  void put(img.Image piece, int dstX, int dstY) =>
      img.compositeImage(result, piece, dstX: dstX, dstY: dstY);

  put(src, b, b);

  // Edges, mirrored outward.
  put(img.flipVertical(crop(0, 0, w, b)), b, 0);
  put(img.flipVertical(crop(0, h - b, w, b)), b, h + b);
  put(img.flipHorizontal(crop(0, 0, b, h)), 0, b);
  put(img.flipHorizontal(crop(w - b, 0, b, h)), w + b, b);

  // Corners, mirrored in both directions.
  put(img.flip(crop(0, 0, b, b), direction: img.FlipDirection.both), 0, 0);
  put(img.flip(crop(w - b, 0, b, b), direction: img.FlipDirection.both),
      w + b, 0);
  put(img.flip(crop(0, h - b, b, b), direction: img.FlipDirection.both),
      0, h + b);
  put(img.flip(crop(w - b, h - b, b, b), direction: img.FlipDirection.both),
      w + b, h + b);

  return result;
}
