import '../models/geometry.dart';

/// An image placed on a page. [rect] is the trim rectangle in mm; bleed is
/// added around it by the renderer.
class PlacedImage {
  final String imageRef;
  final RectMm rect;
  final bool isBack;

  const PlacedImage({
    required this.imageRef,
    required this.rect,
    required this.isBack,
  });
}

/// Renderer-agnostic description of one output page. Produced by the layout
/// engine and consumed identically by the PDF generator and the app preview,
/// so what you see is what prints.
class PagePlan {
  final SizeMm pageSize;
  final List<PlacedImage> images;

  /// Cut/crop marks as thin rectangles in mm.
  final List<RectMm> cutLines;

  /// Page label, e.g. "1" for a front page and "1b" for its back.
  final String label;
  final bool isBackPage;

  /// 1-based physical sheet number (front and back share the same sheet).
  final int sheetNumber;

  const PagePlan({
    required this.pageSize,
    required this.images,
    this.cutLines = const [],
    required this.label,
    required this.isBackPage,
    required this.sheetNumber,
  });
}
