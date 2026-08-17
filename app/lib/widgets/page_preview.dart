import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pnp_core/pnp_core.dart';

import '../util/mm_scale.dart';

/// Loads and caches decoded thumbnails for preview painting. Notifies when a
/// new image finishes decoding so previews repaint.
class PreviewImageCache extends ChangeNotifier {
  static const _thumbnailMaxPx = 600;

  final _images = <String, ui.Image?>{};
  final _pending = <String>{};

  /// Returns the cached image, scheduling a load when absent.
  ui.Image? imageFor(String ref) {
    if (_images.containsKey(ref)) return _images[ref];
    if (!_pending.contains(ref)) {
      _pending.add(ref);
      unawaited(_load(ref));
    }
    return null;
  }

  Future<void> _load(String ref) async {
    try {
      final bytes = await File(ref).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _thumbnailMaxPx,
      );
      final frame = await codec.getNextFrame();
      _images[ref] = frame.image;
    } catch (_) {
      _images[ref] = null; // Decode failed; remember to avoid retry loops.
    } finally {
      _pending.remove(ref);
      notifyListeners();
    }
  }

  /// Forgets a ref (e.g. when the file changed on disk).
  void evict(String ref) {
    _images.remove(ref)?.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final image in _images.values) {
      image?.dispose();
    }
    super.dispose();
  }
}

/// Paints a [PagePlan] exactly as the PDF generator renders it: same rects,
/// same cut lines, because both consume the same layout engine output.
class PagePlanPainter extends CustomPainter {
  final PagePlan plan;
  final FitMode fitMode;
  final PreviewImageCache imageCache;

  /// Source id (card/item) to outline as selected.
  final String? highlightedImageId;

  PagePlanPainter({
    required this.plan,
    required this.fitMode,
    required this.imageCache,
    this.highlightedImageId,
  }) : super(repaint: imageCache);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = fitPageScale(plan.pageSize, size);
    final pageRect = Rect.fromLTWH(
        0, 0, plan.pageSize.width * scale, plan.pageSize.height * scale);

    // Nothing paints outside the page, matching the printed result.
    canvas.clipRect(pageRect);
    canvas.drawRect(pageRect, Paint()..color = Colors.white);

    for (final line in plan.cutLines) {
      canvas.drawRect(rectMmToPx(line, scale), Paint()..color = Colors.black);
    }

    for (var i = 0; i < plan.images.length; i++) {
      final placed = plan.images[i];
      final rect = rectMmToPx(placed.rect, scale);
      final image = imageCache.imageFor(placed.imageRef);

      if (image == null) {
        canvas.drawRect(rect, Paint()..color = Colors.grey.shade300);
      } else {
        _drawFitted(canvas, image, rect);
      }

      if (placed.sourceId != null && placed.sourceId == highlightedImageId) {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.blueAccent,
        );
      }
    }

    canvas.drawRect(
      pageRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.grey.shade400,
    );
  }

  void _drawFitted(Canvas canvas, ui.Image image, Rect rect) {
    final imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    final fit = switch (fitMode) {
      FitMode.cover => BoxFit.cover,
      FitMode.contain => BoxFit.contain,
      FitMode.stretch => BoxFit.fill,
    };
    final sizes = applyBoxFit(fit, imageSize, rect.size);
    final source = Alignment.center.inscribe(
        sizes.source, Offset.zero & imageSize);
    final destination = Alignment.center.inscribe(sizes.destination, rect);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawImageRect(
        image, source, destination, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PagePlanPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.fitMode != fitMode ||
      oldDelegate.highlightedImageId != highlightedImageId;
}

/// A page rendered at its aspect ratio, e.g. for thumbnails or the main
/// preview. [onImageTap] reports the tapped placed image's source id (the
/// card/item it came from), or null for taps on empty page area.
class PagePreview extends StatelessWidget {
  final PagePlan plan;
  final FitMode fitMode;
  final PreviewImageCache imageCache;
  final String? highlightedImageId;
  final void Function(String? sourceId)? onImageTap;

  const PagePreview({
    super.key,
    required this.plan,
    required this.fitMode,
    required this.imageCache,
    this.highlightedImageId,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: plan.pageSize.width / plan.pageSize.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final paint = CustomPaint(
            painter: PagePlanPainter(
              plan: plan,
              fitMode: fitMode,
              imageCache: imageCache,
              highlightedImageId: highlightedImageId,
            ),
          );
          if (onImageTap == null) return paint;
          return GestureDetector(
            onTapUp: (details) {
              final scale = fitPageScale(plan.pageSize, constraints.biggest);
              final x = details.localPosition.dx / scale;
              final y = details.localPosition.dy / scale;
              // Topmost image wins.
              for (final placed in plan.images.reversed) {
                final r = placed.rect;
                if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) {
                  onImageTap!(placed.sourceId);
                  return;
                }
              }
              onImageTap!(null);
            },
            child: paint,
          );
        },
      ),
    );
  }
}
