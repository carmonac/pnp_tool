import 'dart:io';
import 'dart:typed_data';

import 'package:nanoid2/nanoid2.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pnp_tool/image_extender.dart';

class Card {
  final String frontPath;
  final String backPath;
  final int count;

  Card({
    required this.frontPath,
    required this.backPath,
    required this.count,
  });
}

class PnPGenerator {
  // A4 size in mm: 210 x 297
  static const pageWidth = 210.0;
  static const pageHeight = 297.0;

  static const calibrHeight = 7.62;
  static const calibrWidth = 60.79;
  static const logoHeight = 7.72;
  static const logoWidth = 5.86;
  static const calibrPosHeight = 3.56;
  static const calibrPosWidth = 3.56;

  // Margins in mm
  static const marginLeft = 5.76;
  static const marginRight = 5.76;
  static const marginTop = 11.09;
  static const marginBottom = 11.09;
  static const cardSpacing = 4.06;
  static const bleed = 1.02;

  // Card dimensions
  static const cardWidth = 63.5; // Standard card width in mm
  static const cardHeight = 88.9; // Standard card height in mm

  static const drawCutLines = true;

  static late final Uint8List calibratingImage;
  static late final Uint8List logoImage;
  static late final Uint8List calibratingPosImage;

  static final uuid = nanoid();

  static Future<void> generatePdf({
    required String inputDir,
    required String outputPath,
  }) async {
    calibratingImage = await File('resources/calibr.png').readAsBytes();
    logoImage = await File('resources/logo.png').readAsBytes();
    calibratingPosImage = await File('resources/calibr_pos.png').readAsBytes();

    final pdf = pw.Document();
    final cards = await _loadCards(inputDir);

    const cardsPerPage = 9; // 3x3 grid
    final totalPages = (cards.length / cardsPerPage).ceil();

    for (var pageNum = 0; pageNum < totalPages; pageNum++) {
      final pageCards =
          cards.skip(pageNum * cardsPerPage).take(cardsPerPage).toList();

      // Generate front page
      pdf.addPage(await _createPage(
        pageCards: pageCards,
        pageNumber: pageNum + 1,
        isBack: false,
      ));

      // Generate back page
      pdf.addPage(await _createPage(
        pageCards: pageCards,
        pageNumber: pageNum + 1,
        isBack: true,
      ));
    }

    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
  }

  static Future<pw.Page> _createPage({
    required List<Card> pageCards,
    required int pageNumber,
    required bool isBack,
  }) async {
    final processedImages = await Future.wait(
      pageCards.map((card) async {
        final bytes =
            await File(isBack ? card.backPath : card.frontPath).readAsBytes();
        return await extendImageBorders(bytes, bleedMM: bleed);
      }),
    );

    return pw.Page(
      pageFormat: PdfPageFormat(
        pageWidth * PdfPageFormat.mm,
        pageHeight * PdfPageFormat.mm,
      ),
      build: (context) {
        return pw.Stack(
          children: [
            if (drawCutLines) ..._drawCutLines(),
            // id
            pw.Positioned(
              top: 4,
              left: 20,
              child: pw.Text(
                uuid,
                style: pw.TextStyle(
                  fontSize: 7,
                ),
              ),
            ),

            if (pageNumber == 1 && !isBack)
              pw.Positioned(
                top: 4,
                left: (pageWidth - calibrWidth) / 2 * PdfPageFormat.mm,
                child: pw.Image(
                  pw.MemoryImage(calibratingImage),
                  width: calibrWidth * PdfPageFormat.mm,
                  height: calibrHeight * PdfPageFormat.mm,
                ),
              ),

            // Cards
            ...List.generate(pageCards.length, (index) {
              final row = index ~/ 3;
              final col = isBack ? (2 - (index % 3)) : (index % 3);

              final x = marginLeft + (col * (cardWidth + cardSpacing));
              final y = marginTop + (row * (cardHeight + cardSpacing));

              return pw.Positioned(
                left: (x - bleed) * PdfPageFormat.mm,
                top: (y - bleed) * PdfPageFormat.mm,
                child: pw.Image(
                  pw.MemoryImage(processedImages[index]),
                  width: (cardWidth + (bleed * 2)) * PdfPageFormat.mm,
                  height: (cardHeight + (bleed * 2)) * PdfPageFormat.mm,
                ),
              );
            }),

            // Page number
            pw.Positioned(
              bottom: marginBottom / 2 * PdfPageFormat.mm,
              left: 0,
              right: 0,
              child: pw.Center(
                child: pw.Text(
                  isBack ? '${pageNumber}b' : pageNumber.toString(),
                  style: pw.TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
            ),

            // Logo
            pw.Positioned(
              bottom: 4,
              left: 20,
              child: pw.Row(
                children: [
                  pw.Image(
                    pw.MemoryImage(logoImage),
                    width: logoWidth * PdfPageFormat.mm,
                    height: logoHeight * PdfPageFormat.mm,
                  ),
                  pw.Text(
                    'Card Print & Play by careuno',
                    style: pw.TextStyle(
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),

            // Calibrating position
            ...List.from(_getCornerImages(calibratingPosImage)),
          ],
        );
      },
    );
  }

  static Future<List<Card>> _loadCards(String inputDir) async {
    final cards = <Card>[];
    final directory = Directory(inputDir);

    // Busca la ruta de global_back en cualquier formato de imagen
    String? globalBackPath;
    final potentialGlobalBack = directory.listSync().cast<File?>().firstWhere(
          (file) =>
              file != null &&
              path.basenameWithoutExtension(file.path).toLowerCase() ==
                  'global_back',
          orElse: () => null,
        );

    if (potentialGlobalBack != null) {
      globalBackPath = potentialGlobalBack.path;
    }

    final frontFiles = <String, String>{};
    final backFiles = <String, String>{};

    // Clasifica archivos en front y back
    await for (final entry in directory.list()) {
      if (entry is File) {
        final fileName =
            path.basenameWithoutExtension(entry.path).toLowerCase();
        if (fileName.endsWith('_front')) {
          frontFiles[fileName.replaceAll('_front', '')] = entry.path;
        } else if (fileName.endsWith('_back')) {
          backFiles[fileName.replaceAll('_back', '')] = entry.path;
        }
      }
    }

    // Comprobación 1: Si hay un back sin su correspondiente front
    for (final backName in backFiles.keys) {
      if (!frontFiles.containsKey(backName)) {
        throw Exception('font side not found for: ${backName}_back');
      }
    }

    // Procesa las cartas en orden numérico o alfabético
    final sortedFrontKeys = frontFiles.keys.toList()..sort();

    for (var i = 0; i < sortedFrontKeys.length; i++) {
      final frontName = sortedFrontKeys[i];
      final frontFilePath = frontFiles[frontName]!;
      final backFilePath = backFiles.containsKey(frontName)
          ? backFiles[frontName]!
          : globalBackPath;

      // Comprobación 2: Si un front no tiene back y tampoco global_back
      if (backFilePath == null) {
        throw Exception(
            'back side not found for: ${frontName}_front and global_back is not available.');
      }

      // Agrega la carta con el número correspondiente
      cards.add(Card(
        frontPath: frontFilePath,
        backPath: backFilePath,
        count: i + 1, // Enumera las cartas en orden
      ));
    }

    return cards;
  }

  static int _getCardCount(String name) {
    final match = RegExp(r'^(\d+)\s+').firstMatch(name);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  static List<pw.Widget> _drawCutLines() {
    List<pw.Widget> cutLines = [];
    // vertical lines
    var x = marginLeft;
    for (var i = 0; i < 6; i++) {
      cutLines.add(_getCutLine(
        width: 0.3527,
        height: marginTop,
        left: x,
        top: 0.0,
      ));
      cutLines.add(_getCutLine(
        width: 0.3527,
        height: marginBottom,
        left: x,
        top: pageHeight - marginBottom,
      ));

      final next = i + 1;
      x += (next % 2 != 0) ? cardWidth : cardSpacing;
    }

    // horizontal lines
    var y = marginTop;
    for (var i = 0; i < 6; i++) {
      cutLines.add(_getCutLine(
        width: marginLeft,
        height: 0.42,
        left: 0.0,
        top: y,
      ));
      cutLines.add(_getCutLine(
        width: marginRight,
        height: 0.42,
        left: pageWidth - marginRight,
        top: y,
      ));

      final next = i + 1;
      y += (next % 2 != 0) ? cardHeight : cardSpacing;
    }

    return cutLines;
  }

  // we have an issue drawing the cut lines with drawLine method so we use a container instead
  static pw.Widget _getCutLine({
    required double width,
    required double height,
    required double left,
    required double top,
  }) {
    return pw.Positioned(
      left: left * PdfPageFormat.mm,
      top: top * PdfPageFormat.mm,
      child: pw.Container(
        width: width * PdfPageFormat.mm,
        height: height * PdfPageFormat.mm,
        color: PdfColors.black,
      ),
    );
  }

  static List<pw.Widget> _getCornerImages(Uint8List image) {
    final positions = [
      // Top-left
      (left: 0.0, top: 0.0),
      // Top-right
      (left: pageWidth - calibrPosWidth, top: 0.0),
      // Bottom-left
      (left: 0.0, top: pageHeight - calibrPosHeight),
      // Bottom-right
      (left: pageWidth - calibrPosWidth, top: pageHeight - calibrPosHeight),
    ];

    return positions
        .map((pos) => pw.Positioned(
              left: pos.left * PdfPageFormat.mm,
              top: pos.top * PdfPageFormat.mm,
              child: pw.Image(
                pw.MemoryImage(image),
                width: calibrPosWidth * PdfPageFormat.mm,
                height: calibrPosHeight * PdfPageFormat.mm,
              ),
            ))
        .toList();
  }
}
