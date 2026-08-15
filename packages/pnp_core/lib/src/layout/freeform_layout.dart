import '../models/geometry.dart';
import '../models/project.dart';
import 'mirror.dart';
import 'page_plan.dart';

const _cropMarkThicknessMm = 0.35;
const _cropMarkLengthMm = 3.0;
const _cropMarkGapMm = 1.0;

/// Lays out a freeform-mode project as alternating front/back [PagePlan]s.
/// Back pages are fully derived: every item with a back appears mirrored
/// horizontally so it lines up when the sheet is flipped on its long edge.
/// Back pages are emitted even when empty to keep duplex pairing intact.
List<PagePlan> planFreeform(PnpProject project) {
  assert(project.mode == ProjectMode.freeform);

  final page = project.pageSize;
  final plans = <PagePlan>[];

  for (var sheet = 0; sheet < project.pages.length; sheet++) {
    final items = project.pages[sheet].items;

    final frontRects = [for (final item in items) item.rect];
    final backRects = [
      for (final item in items)
        if (item.backRef != null) mirrorRect(item.rect, page.width),
    ];

    plans.add(PagePlan(
      pageSize: page,
      label: '${sheet + 1}',
      isBackPage: false,
      sheetNumber: sheet + 1,
      cutLines:
          project.drawCutLines ? _cropMarks(frontRects) : const <RectMm>[],
      images: [
        for (final item in items)
          PlacedImage(imageRef: item.frontRef, rect: item.rect, isBack: false),
      ],
    ));

    plans.add(PagePlan(
      pageSize: page,
      label: '${sheet + 1}b',
      isBackPage: true,
      sheetNumber: sheet + 1,
      cutLines:
          project.drawCutLines ? _cropMarks(backRects) : const <RectMm>[],
      images: [
        for (final item in items)
          if (item.backRef != null)
            PlacedImage(
              imageRef: item.backRef!,
              rect: mirrorRect(item.rect, page.width),
              isBack: true,
            ),
      ],
    ));
  }

  return plans;
}

/// Corner crop marks around each item: at every corner, one horizontal and
/// one vertical tick just outside the trim rectangle.
List<RectMm> _cropMarks(List<RectMm> rects) {
  const t = _cropMarkThicknessMm;
  const len = _cropMarkLengthMm;
  const gap = _cropMarkGapMm;

  final marks = <RectMm>[];
  for (final r in rects) {
    for (final (x, y, isLeft, isTop) in [
      (r.left, r.top, true, true),
      (r.right, r.top, false, true),
      (r.left, r.bottom, true, false),
      (r.right, r.bottom, false, false),
    ]) {
      // Horizontal tick extending away from the item.
      marks.add(RectMm(
          isLeft ? x - gap - len : x + gap, y - t / 2, len, t));
      // Vertical tick extending away from the item.
      marks.add(RectMm(
          x - t / 2, isTop ? y - gap - len : y + gap, t, len));
    }
  }
  return marks;
}
