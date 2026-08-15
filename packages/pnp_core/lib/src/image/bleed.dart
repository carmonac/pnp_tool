import 'dart:typed_data';

import 'package:image/image.dart';

Future<Uint8List> extendImageBorders(Uint8List inputBytes,
    {double bleedMM = 1.02}) async {
  final originalImage = decodeImage(inputBytes);

  if (originalImage == null) {
    throw Exception('No se pudo cargar la imagen');
  }

  // Convertir el sangrado de mm a píxeles (asumiendo 300 DPI)
  final dpi = 300;
  final mmToInch = 25.4;
  final bleedPixels = (bleedMM * dpi / mmToInch).round();

  // Crear una nueva imagen con el tamaño extendido
  final newWidth = originalImage.width + (bleedPixels * 2);
  final newHeight = originalImage.height + (bleedPixels * 2);

  final newImage = Image(
    width: newWidth,
    height: newHeight,
    numChannels: originalImage.numChannels,
  );

  // Copiar la imagen original al centro
  for (int y = 0; y < originalImage.height; y++) {
    for (int x = 0; x < originalImage.width; x++) {
      final pixel = originalImage.getPixel(x, y);
      newImage.setPixel(x + bleedPixels, y + bleedPixels, pixel);
    }
  }

  // Copiar y reflejar los bordes
  // Borde superior
  for (int x = 0; x < originalImage.width; x++) {
    for (int y = 0; y < bleedPixels; y++) {
      final sourcePixel = originalImage.getPixel(x, y);
      newImage.setPixel(x + bleedPixels, bleedPixels - 1 - y, sourcePixel);
    }
  }

  // Borde inferior
  for (int x = 0; x < originalImage.width; x++) {
    for (int y = 0; y < bleedPixels; y++) {
      final sourcePixel =
          originalImage.getPixel(x, originalImage.height - 1 - y);
      newImage.setPixel(
          x + bleedPixels, originalImage.height + bleedPixels + y, sourcePixel);
    }
  }

  // Borde izquierdo
  for (int y = 0; y < originalImage.height; y++) {
    for (int x = 0; x < bleedPixels; x++) {
      final sourcePixel = originalImage.getPixel(x, y);
      newImage.setPixel(bleedPixels - 1 - x, y + bleedPixels, sourcePixel);
    }
  }

  // Borde derecho
  for (int y = 0; y < originalImage.height; y++) {
    for (int x = 0; x < bleedPixels; x++) {
      final sourcePixel =
          originalImage.getPixel(originalImage.width - 1 - x, y);
      newImage.setPixel(
          originalImage.width + bleedPixels + x, y + bleedPixels, sourcePixel);
    }
  }

  // Esquinas
  for (int y = 0; y < bleedPixels; y++) {
    for (int x = 0; x < bleedPixels; x++) {
      // Superior izquierda
      final topLeftPixel = originalImage.getPixel(x, y);
      newImage.setPixel(bleedPixels - 1 - x, bleedPixels - 1 - y, topLeftPixel);

      // Superior derecha
      final topRightPixel =
          originalImage.getPixel(originalImage.width - 1 - x, y);
      newImage.setPixel(originalImage.width + bleedPixels + x,
          bleedPixels - 1 - y, topRightPixel);

      // Inferior izquierda
      final bottomLeftPixel =
          originalImage.getPixel(x, originalImage.height - 1 - y);
      newImage.setPixel(bleedPixels - 1 - x,
          originalImage.height + bleedPixels + y, bottomLeftPixel);

      // Inferior derecha
      final bottomRightPixel = originalImage.getPixel(
          originalImage.width - 1 - x, originalImage.height - 1 - y);
      newImage.setPixel(originalImage.width + bleedPixels + x,
          originalImage.height + bleedPixels + y, bottomRightPixel);
    }
  }

  // Guardar la imagen como PNG para mantener la calidad
  final encodedImage = encodePng(newImage);
  return encodedImage;
}
