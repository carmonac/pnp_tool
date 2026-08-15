import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../image/bleed.dart';
import '../io/image_resolver.dart';
import '../layout/layout.dart';
import '../models/geometry.dart';
import '../models/project.dart';
import 'resources.g.dart';

const _calibrSize = SizeMm(60.79, 7.62);
const _calibrPosSize = SizeMm(3.56, 3.56);
const _logoSize = SizeMm(5.86, 7.72);

String generateJobId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(8, (_) => alphabet[random.nextInt(alphabet.length)])
      .join();
}

/// Renders a project's [PagePlan]s into a PDF document. Contains no layout
/// math: everything it draws comes from the layout engine.
class PdfGenerator {
  final PnpProject project;
  final ImageResolver resolver;

  PdfGenerator({required this.project, required this.resolver});

  Future<Uint8List> generate({
    void Function(int page, int totalPages)? onProgress,
  }) async {
    final plans = planProject(project);
    final jobId = generateJobId();
    final doc = pw.Document();

    // Process each distinct (image, printed size) pair once; shared backs are
    // by far the common case.
    final processed = <String, pw.MemoryImage>{};
    Future<pw.MemoryImage> imageFor(PlacedImage placed) async {
      final key = '${placed.imageRef}'
          '@${placed.rect.width.toStringAsFixed(2)}'
          'x${placed.rect.height.toStringAsFixed(2)}';
      return processed[key] ??= pw.MemoryImage(prepareImage(
        await resolver.readBytes(placed.imageRef),
        targetSize: placed.rect.size,
        bleedMm: project.bleedMm,
        fitMode: project.fitMode,
        jpegQuality: project.jpegQuality,
      ));
    }

    for (var i = 0; i < plans.length; i++) {
      final plan = plans[i];
      final images = [
        for (final placed in plan.images) (placed, await imageFor(placed)),
      ];
      doc.addPage(_buildPage(plan, images, jobId));
      onProgress?.call(i + 1, plans.length);
    }

    return doc.save();
  }

  pw.Page _buildPage(
    PagePlan plan,
    List<(PlacedImage, pw.MemoryImage)> images,
    String jobId,
  ) {
    final page = plan.pageSize;
    final bleed = project.bleedMm;

    return pw.Page(
      pageFormat: PdfPageFormat(
        page.width * PdfPageFormat.mm,
        page.height * PdfPageFormat.mm,
      ),
      build: (context) => pw.Stack(
        children: [
          for (final line in plan.cutLines)
            pw.Positioned(
              left: line.x * PdfPageFormat.mm,
              top: line.y * PdfPageFormat.mm,
              child: pw.Container(
                width: line.width * PdfPageFormat.mm,
                height: line.height * PdfPageFormat.mm,
                color: PdfColors.black,
              ),
            ),

          // Job id
          pw.Positioned(
            top: 4,
            left: 20,
            child: pw.Text(jobId, style: const pw.TextStyle(fontSize: 7)),
          ),

          // Calibration ruler on the first front page only
          if (project.drawCalibration &&
              plan.sheetNumber == 1 &&
              !plan.isBackPage)
            pw.Positioned(
              top: 4,
              left: (page.width - _calibrSize.width) / 2 * PdfPageFormat.mm,
              child: pw.Image(
                pw.MemoryImage(calibrPng),
                width: _calibrSize.width * PdfPageFormat.mm,
                height: _calibrSize.height * PdfPageFormat.mm,
              ),
            ),

          // Card images, enlarged by the bleed on every side
          for (final (placed, memoryImage) in images)
            pw.Positioned(
              left: (placed.rect.x - bleed) * PdfPageFormat.mm,
              top: (placed.rect.y - bleed) * PdfPageFormat.mm,
              child: pw.Image(
                memoryImage,
                width: (placed.rect.width + 2 * bleed) * PdfPageFormat.mm,
                height: (placed.rect.height + 2 * bleed) * PdfPageFormat.mm,
              ),
            ),

          // Page label
          pw.Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: pw.Center(
              child: pw.Text(plan.label,
                  style: const pw.TextStyle(fontSize: 10)),
            ),
          ),

          // Logo
          pw.Positioned(
            bottom: 4,
            left: 20,
            child: pw.Row(children: [
              pw.Image(
                pw.MemoryImage(logoPng),
                width: _logoSize.width * PdfPageFormat.mm,
                height: _logoSize.height * PdfPageFormat.mm,
              ),
              pw.Text('Cards Print & Play',
                  style: const pw.TextStyle(fontSize: 7)),
            ]),
          ),

          // Corner registration marks
          if (project.drawCalibration)
            for (final (x, y) in [
              (0.0, 0.0),
              (page.width - _calibrPosSize.width, 0.0),
              (0.0, page.height - _calibrPosSize.height),
              (
                page.width - _calibrPosSize.width,
                page.height - _calibrPosSize.height
              ),
            ])
              pw.Positioned(
                left: x * PdfPageFormat.mm,
                top: y * PdfPageFormat.mm,
                child: pw.Image(
                  pw.MemoryImage(calibrPosPng),
                  width: _calibrPosSize.width * PdfPageFormat.mm,
                  height: _calibrPosSize.height * PdfPageFormat.mm,
                ),
              ),
        ],
      ),
    );
  }
}
